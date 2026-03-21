# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**wyx** is a Claude Code plugin that provides architecture guardrails for LLM-assisted development. The core mechanism: when Claude writes code near a module with a spec, the PreToolUse hook automatically injects boundary declarations into Claude's context, reducing cross-module violations.

Adapts ideas from two sources:
- **WYSIWID** (Meng & Jackson, MIT) — concept spec format and boundary declarations
- **WYWIWID** (Dr. Ernie) — evidence-based legibility concepts (concept drift detection, pipeline invariants)

This is a Claude Code plugin (5 SKILL.md files + 3 hooks), not a CLI tool or runtime engine. The primary differentiator is the hooks — the skills are convenience packaging for generating the specs that fuel the hooks.

## Architecture

```
.claude-plugin/
├── plugin.json             # Plugin manifest (name: "wyx")
hooks/
└── hooks.json              # SessionStart + PreToolUse + PostToolUse hooks (command type only)
scripts/
├── session-start.sh        # Artifact coverage + drift/ARCHITECTURE.md staleness + uncovered modules (with exclusions)
├── drift-context.sh        # Boundary injection near specs + CRLF handling + shadowing mitigation
└── post-check.sh           # Post-edit dependency list reinforcement (silent when no spec/deps)
skills/
├── audit/SKILL.md          # /wyx:audit — project audit & command planner
├── concept/SKILL.md        # /wyx:concept — bounded concept design + drift detection
├── map/SKILL.md            # /wyx:map — architecture visualization from specs
├── pipeline/SKILL.md       # /wyx:pipeline — data pipeline specs with quality invariants
└── sync/SKILL.md           # /wyx:sync — sync coordination maps
```

### Skills

**`/wyx:audit`** — Discovery-only project scanner (~155 lines, read-only). Scans for spec coverage gaps, detects pipeline/sync candidates via code pattern analysis, and outputs a dependency-ordered TODO list of individual skill commands. Uses Glob+Grep directly (no subagents). Evaluates directories for behavioral cohesion before flagging — type definitions, stateless utilities, thin store wrappers, and schema-only directories are filtered, with concrete signal examples (state ownership, lifecycle, persistence, events) guiding the evaluation. Checks each spec for boundary-contributing sections (`## interactions`/`## dependencies`/`## data boundary`) and flags specs providing zero hook protection. When all modules have specs, outputs a concise coverage status instead of empty tables. Does not generate specs or modify files.

**`/wyx:concept`** — Generates structured concept specs (CONCEPT.md) as compressed context for code generation. Four modes: Retrofit (path arg), Greenfield (text arg), Drift (`drift [path]`), Discovery (no args). Format: purpose + state + actions + operational principle + interactions + dependencies. Five Design Rules: (1) single purpose, (2) concept independence, (3) state ownership, (4) actions as interface, (5) actions as declarations not events (cross-cutting infrastructure should be its own concept). Retrofit mode guides authors to focus on public contract fields (omit implementation details from `## state`) and cross-references state with other CONCEPT.md specs to flag Rule 3 overlaps. Drift mode includes cross-spec reference validation (PIPELINE/SYNCS→CONCEPT name matching), systemic pattern aggregation, cross-cutting parameter detection, `## known gaps` resolution checking, and calibration rules (type wrapper differences = Low, implementation-detail fields = Low, private helper methods = Low, naming convention differences = Low, repeated identical Lows deduplicated, grep-verify before Medium+ reporting, >5 Low per spec triggers re-evaluation advisory). Drift history JSONL tracks Low counts for accumulation trending.

**`/wyx:pipeline`** — Data pipeline specialization. Produces `PIPELINE.md` with sources, stages, outputs, quality invariants. Three modes: Retrofit (path arg), Greenfield (text arg), Discovery (no args).

**`/wyx:map`** — Generates `ARCHITECTURE.md` from all wyx specs in a project. Reads CONCEPT.md, PIPELINE.md, and SYNCS.md to produce a Mermaid relationship graph, dependency matrix, data flow paths, and coverage report. Single mode: Generate (optional path arg for subtree scoping). Output follows 7 determinism constraints for reproducible Mermaid across invocations.

**`/wyx:sync`** — Documents concept coordination through sync handlers. Where CONCEPT.md `## interactions` declares relationships, `SYNCS.md` specifies execution mechanics: timing, qualification, error isolation, data flow. Three modes: Retrofit (path arg), Greenfield (text arg), Discovery (no args).

### Hooks

**SessionStart** (command): Scans project for existing wyx artifacts (CONCEPT.md, PIPELINE.md, SYNCS.md) and reports coverage in sorted order. Warns if `jq` is missing. Suggests `/wyx:audit` if none found. Also reports last drift check date from `.claude/wyx-drift-history.jsonl` (if exists), warns if specs modified since last drift check (`find -newer`), checks ARCHITECTURE.md freshness, lists uncovered modules (directories with >2 source files lacking CONCEPT.md or PIPELINE.md), and reports code directories modified since last drift check. Non-concept directories (`tests/`, `docs/`, `migrations/`, `components/ui/`, `types/`, `e2e/`, `cypress/`, `fixtures/`, `stubs/`, `mocks/`) are excluded from uncovered module detection. Shadowing detection flags PIPELINE.md-only directories (not SYNCS.md — SYNCS.md does not stop hook traversal).

**PreToolUse** (command, matcher: `Write|Edit|NotebookEdit`): When writing near a spec file, outputs boundary declarations via `hookSpecificOutput.additionalContext`. Extracts `## interactions` and `## dependencies` from CONCEPT.md, and `## data boundary` from PIPELINE.md. SYNCS.md is listed in spec context but does not stop traversal or inject boundaries. Resolves relative file paths to absolute. Handles both `file_path` (Write/Edit) and `notebook_path` (NotebookEdit) via jq fallback chain. Skips inert files (`.json`, `.jsonl`, `.lock`, `.log`, `.txt`) — no context injection for non-code files. Handles CRLF line endings via `tr -d '\r'` in extract_section. When no CONCEPT.md is co-located with the stopping spec (e.g., PIPELINE.md-only directory), looks for an ancestor CONCEPT.md and injects its boundaries with a `[SHADOWED]` caveat. Enables LLM self-checking against declared boundaries. **This is the core differentiator of wyx** — concept specs are the fuel, this hook is the engine.

**PostToolUse** (command, matcher: `Write|Edit|NotebookEdit`): After a file edit near a CONCEPT.md, reinjects the `## dependencies` list as a focused reminder. Complements PreToolUse: PreToolUse provides full boundary context before the edit (guidance), PostToolUse provides the dependency list after (verification prompt). Walks upward to find the nearest CONCEPT.md only (not PIPELINE.md or SYNCS.md — they lack dependency lists). Silent when: no spec found, no `## dependencies` section, editing inert files, or editing spec files themselves. ~90 lines, language-agnostic, no import parsing. Design principle: **hooks extract and inject; the LLM judges**.

### Key Constraints

- Each skill is a self-contained SKILL.md (YAML frontmatter + markdown body), with optional references/ for detailed content loaded on demand (progressive disclosure)
- Artifacts are colocated with code: CONCEPT.md, PIPELINE.md, SYNCS.md next to implementation; drift history in `.claude/wyx-drift-history.jsonl`
- **One spec per directory**: Only `CONCEPT.md`, `PIPELINE.md`, `SYNCS.md` are recognized (no `CONCEPT-*.md` glob patterns). Each concept gets its own subdirectory. This ensures the PreToolUse hook injects only relevant boundary declarations.
- **Stop-at-first traversal**: `drift-context.sh` walks upward from the edited file and stops at the first directory containing a boundary-contributing spec (CONCEPT.md or PIPELINE.md). SYNCS.md is listed in spec context but does not stop traversal or inject boundary declarations. If no CONCEPT.md is co-located with the stopping spec (e.g., PIPELINE.md-only directory), the hook continues upward to find an ancestor CONCEPT.md and injects its boundaries with a `[SHADOWED]` caveat (see anti-patterns in concept/SKILL.md).
- Specs are documentation, not enforcement — drift detection catches divergence
- All three hooks are `type: "command"` only (no prompt or agent hooks)

## Working in This Repository

This is a plugin repository. There is no build step, test suite, or package.json.

**Deliverables**: `.claude-plugin/plugin.json` + `hooks/hooks.json` + `scripts/` + 5 SKILL.md files in `skills/`.

**Marketplace**: Hosted separately at [jlifyio/claude-plugins](https://github.com/jlifyio/claude-plugins). Install: `/plugin marketplace add jlifyio/claude-plugins` then `/plugin install wyx@jlifyio`.

**Runtime dependency**: `jq` — used by `drift-context.sh` and `post-check.sh` for JSON parsing. Without it, drift context and post-edit checks are no-ops (the SessionStart hook warns users). Users lose boundary checking.

**Editing skills**: Each SKILL.md is self-contained. Edit the markdown body for behavior changes; edit YAML frontmatter for metadata (name, description, argument-hint, allowed-tools).

**Version**: Update in `.claude-plugin/plugin.json` only. The marketplace ([jlifyio/claude-plugins](https://github.com/jlifyio/claude-plugins)) does not duplicate the version — plugin.json is the authority per official docs. Use `/jlify-utils:release X.Y.Z` to bump version across all files, commit, tag, push, and create a GitHub release.

**Plugin structure rules**:
- `plugin.json` goes inside `.claude-plugin/`
- `hooks.json` goes at plugin root in `hooks/`, NOT inside `.claude-plugin/`
- Hook scripts use `$CLAUDE_PLUGIN_ROOT` to resolve paths

## Testing

No traditional test suite. Test by running skills against real projects.

```bash
# Test a single skill (non-interactive)
unset CLAUDECODE  # required if running from within a Claude Code session
cd /path/to/project && claude --plugin-dir /path/to/wyx -p "/wyx:concept"

# Verify plugin loads correctly
cd /path/to/project && claude --plugin-dir /path/to/wyx -p "List the wyx skills available"

# Test SessionStart hook standalone
CLAUDE_PROJECT_DIR=/path/to/project bash scripts/session-start.sh

# Test drift context (simulated PreToolUse input)
echo '{"tool_name":"Write","tool_input":{"file_path":"/path/to/project/src/module/service.ts","content":"code"}}' \
  | CLAUDE_PROJECT_DIR=/path/to/project bash scripts/drift-context.sh

# Test post-edit check (simulated PostToolUse input)
echo '{"tool_name":"Write","tool_input":{"file_path":"/path/to/project/src/module/service.ts","content":"code"},"tool_response":{"success":true}}' \
  | CLAUDE_PROJECT_DIR=/path/to/project bash scripts/post-check.sh

# Validate plugin structure
python3 -c "import json; json.load(open('.claude-plugin/plugin.json'))" && echo "plugin.json OK"
python3 -c "import json; json.load(open('hooks/hooks.json'))" && echo "hooks.json OK"
for s in audit concept map pipeline sync; do test -f skills/$s/SKILL.md && echo "$s OK"; done
```

## Shell Script Conventions

All three scripts use `set -euo pipefail`. Key patterns to preserve when editing:

**Trailing slash stripping**: `PROJECT_DIR="${CLAUDE_PROJECT_DIR%/}"` — double-slash breaks `case` pattern matching against `$PROJECT_DIR/`.

**Case-insensitive heading extraction**: `extract_section` tries lowercase first, then Capitalized as fallback. Some projects use `## Purpose`; others use `## purpose`.

```bash
# extract_section uses sed address ranges between ## headings
# [^#] prevents matching ### subheadings
sed -n "/^## ${section}[[:space:]]*$/,/^## [^#]/{...}" "$file"
```

**Upward directory traversal**: `drift-context.sh` walks up from the edited file's directory, stops at project root via `case "$dir/" in "$PROJECT_DIR/"*) ;; *) break ;; esac`. Stops at the first directory containing a boundary-contributing spec (CONCEPT.md or PIPELINE.md). SYNCS.md does not stop traversal.

**Relative path resolution**: Files from tool input may be relative — resolve with `case "$file_path" in /*) ;; *) file_path="$PROJECT_DIR/$file_path" ;; esac`.

**PreToolUse/PostToolUse output format**: Must use `hookSpecificOutput.additionalContext` (structured JSON via `jq -n`). Plain text stdout is only shown in verbose mode per official docs.

**JSONL reading**: Use `grep -v '^[[:space:]]*$' file | tail -1` instead of `tail -1` — Claude's Write tool may append trailing empty lines.

## Known Limitations

- **Context-only enforcement**: The PreToolUse hook outputs boundary context but cannot block edits. Enforcement relies on the LLM respecting the context. Tested with Opus-class models; behavior with less capable models is unknown.
- **Matcher coverage**: PreToolUse matches `Write|Edit|NotebookEdit`. File writes via `Bash` (e.g. `echo > file`, `sed -i`) bypass the hook entirely.
- **Spec heading format**: Some projects use capitalized headings (`## Purpose`, `## Actions`); others use lowercase (`## purpose`, `## actions`). The drift context hook handles both via fallback extraction.
- **PreToolUse context delivery**: Uses `hookSpecificOutput.additionalContext` (structured JSON) per the official hooks reference. Boundary declarations are delivered in full without truncation — completeness is prioritized over context savings.
- **Stale spec risk**: Outdated or incorrect specs can be worse than no specs — the hook injects boundary declarations verbatim without validation, which may guide Claude away from correct approaches toward spec-declared-but-nonexistent APIs. Run `/wyx:concept drift` regularly to catch divergence.
- **Claude-only testing**: All testing used Claude. Other LLMs may respond differently to CONCEPT.md specs.

## Documentation

- `docs/DECISIONS.md` — Architecture Decision Records (DEC-001〜DEC-014). Check before making architectural changes.

## Design Decisions

- **Hook type: command only** — prompt hooks lack spec access, agent hooks add 10-30s latency. Command hooks extract boundaries in ~2s.
- **No truncation**: Boundary declarations delivered in full — incomplete boundaries defeat boundary checking.
- **No qualification**: Boundary declarations are injected without caveats like "these might be stale" — qualified boundaries defeat boundary checking (same principle as no truncation).
- **Drift stays in `/wyx:concept`**: `/wyx:concept drift` checks all 3 spec types (CONCEPT, PIPELINE, SYNCS) including cross-spec reference validation and SYNCS graph consistency. Extracting into a separate `/wyx:drift` skill was deferred — no functional conflict yet.
- **Read-only subagents only**: Concept drift and map generation use Explore-type subagents (structurally read-only — Write/Edit unavailable) for parallel scanning. Audit uses direct Glob+Grep (no subagents — YAGNI at current scale, and subagent Bash commands caused approval fatigue). Full plugin agents remain excluded.
- **One spec per directory**: Multi-file patterns (`CONCEPT-*.md`) were removed — they caused 83% irrelevant boundary context injection in flat directories.
- **No SYNCS.md splitting**: The `## coordination graph` requires a complete view of all sync flows; partial graphs give false confidence.
- **Audit is discovery-only**: `/wyx:audit` scans and reports but does not generate specs or check staleness (defers to `/wyx:concept drift` for semantic analysis — mtime-based staleness produced 100% false positives in testing). A full orchestrator was rejected (3-agent debate) for context window exhaustion, template drift, and quality degradation.
- **Integration is a platform constraint**: The 5 skills operate independently (no skill-to-skill invocation in Claude Code). This is structural, not a bug.
- **No auto-invocation rules**: CLAUDE.md rules telling users to "check specs before imports" are redundant — the PreToolUse hook does this automatically.
- **PostToolUse = context reinforcement, not import checking**: PostToolUse reinjects the dependency list only — no import parsing, no language-specific code. Previous proposals for mechanical import checking were rejected (3-agent debate): concept-name-to-import-path mapping has no clean bash solution, and language-specific code violates wyx's language-agnostic principle. Architectural rule: **hooks extract and inject; the LLM judges**.
- **PostToolUse "contradictory signals" overturned**: The v0.20.0/v0.21.0 rejection was withdrawn (3-agent debate). PreToolUse=guidance, PostToolUse=verification is complementary, not contradictory. The previous DA attacked the concept instead of the mechanism.

## Test Results

Boundary violations: 33% → 0% (N=6 features, 2 projects). Drift and coverage additionally validated on a third project (WineLevel3, 10 concepts). Before/after methodology — developer learning from spec-writing may confound. Redundant data store anti-pattern found in 3/3 audited projects — addressed by Design Rule 5 and Retrofit step 4 in v0.16.3.
