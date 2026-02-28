# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**wyx** is a Claude Code plugin that provides architecture guardrails for LLM-assisted development. The core mechanism: when Claude writes code near a module with a spec, the PreToolUse hook automatically injects boundary declarations into Claude's context, reducing cross-module violations.

Adapts ideas from two sources:
- **WYSIWID** (Meng & Jackson, MIT) — concept spec format and boundary declarations
- **WYWIWID** (Dr. Ernie) — evidence-based legibility concepts (concept drift detection, pipeline invariants)

This is a Claude Code plugin (4 SKILL.md files + 2 hooks), not a CLI tool or runtime engine. The primary differentiator is the hooks — the skills are convenience packaging for generating the specs that fuel the hooks.

## Architecture

```
.claude-plugin/
├── plugin.json             # Plugin manifest (name: "wyx")
hooks/
└── hooks.json              # SessionStart + PreToolUse hooks (command type only)
scripts/
├── session-start.sh        # Artifact coverage + drift/ARCHITECTURE.md staleness + uncovered modules (with exclusions)
└── drift-context.sh        # Boundary injection near specs + CRLF handling + shadowing mitigation
skills/
├── concept/SKILL.md        # /wyx:concept — bounded concept design + drift detection
├── map/SKILL.md            # /wyx:map — architecture visualization from specs
├── pipeline/SKILL.md       # /wyx:pipeline — data pipeline specs with quality invariants
└── sync/SKILL.md           # /wyx:sync — sync coordination maps
```

### Skills

**`/wyx:concept`** — Generates structured concept specs (CONCEPT.md) as compressed context for code generation. Four modes: Retrofit (path arg), Greenfield (text arg), Drift (`drift [path]`), Discovery (no args). Format: purpose + state + actions + operational principle + interactions + dependencies. Retrofit mode guides authors to focus on public contract fields (omit implementation details from `## state`). Drift mode includes cross-spec reference validation (PIPELINE/SYNCS→CONCEPT name matching), systemic pattern aggregation, cross-cutting parameter detection, `## known gaps` resolution checking, and calibration rules (type wrapper differences = Low, implementation-detail fields = Low, private helper methods = Low, grep-verify before Medium+ reporting).

**`/wyx:pipeline`** — Data pipeline specialization. Produces `PIPELINE.md` with sources, stages, outputs, quality invariants. Three modes: Retrofit (path arg), Greenfield (text arg), Discovery (no args).

**`/wyx:map`** — Generates `ARCHITECTURE.md` from all wyx specs in a project. Reads CONCEPT.md, PIPELINE.md, and SYNCS.md to produce a Mermaid relationship graph, dependency matrix, data flow paths, and coverage report. Single mode: Generate (optional path arg for subtree scoping). Output follows 7 determinism constraints for reproducible Mermaid across invocations.

**`/wyx:sync`** — Documents concept coordination through sync handlers. Where CONCEPT.md `## interactions` declares relationships, `SYNCS.md` specifies execution mechanics: timing, qualification, error isolation, data flow. Three modes: Retrofit (path arg), Greenfield (text arg), Discovery (no args).

### Hooks

**SessionStart** (command): Scans project for existing wyx artifacts (CONCEPT.md, PIPELINE.md, SYNCS.md) and reports coverage in sorted order. Warns if `jq` is missing. Suggests `/wyx:concept` if none found. Also reports last drift check date from `.claude/wyx-drift-history.jsonl` (if exists), warns if specs modified since last drift check (`find -newer`), checks ARCHITECTURE.md freshness, and lists uncovered modules (directories with >5 files lacking CONCEPT.md). Well-known non-concept directories (`tests/`, `docs/`, `migrations/`, `components/ui/`) are excluded from uncovered module detection.

**PreToolUse** (command, matcher: `Write|Edit|NotebookEdit`): When writing near a spec file, outputs boundary declarations via `hookSpecificOutput.additionalContext`. Extracts `## interactions` and `## dependencies` from CONCEPT.md, and `## data boundary` from PIPELINE.md. Resolves relative file paths to absolute. Handles both `file_path` (Write/Edit) and `notebook_path` (NotebookEdit) via jq fallback chain. Skips inert files (`.json`, `.jsonl`, `.lock`, `.log`, `.txt`) — no context injection for non-code files. Handles CRLF line endings via `tr -d '\r'` in extract_section. When a non-CONCEPT spec (PIPELINE.md/SYNCS.md) shadows an ancestor CONCEPT.md, injects ancestor boundaries with a `[SHADOWED]` caveat instead of providing zero boundary context. Enables LLM self-checking against declared boundaries. **This is the core differentiator of wyx** — concept specs are the fuel, this hook is the engine.

### Key Constraints

- Each skill is a single self-contained SKILL.md (YAML frontmatter + markdown body)
- Artifacts are colocated with code: CONCEPT.md, PIPELINE.md, SYNCS.md next to implementation; drift history in `.claude/wyx-drift-history.jsonl`
- **One spec per directory**: Only `CONCEPT.md`, `PIPELINE.md`, `SYNCS.md` are recognized (no `CONCEPT-*.md` glob patterns). Each concept gets its own subdirectory. This ensures the PreToolUse hook injects only relevant boundary declarations.
- **Stop-at-first traversal**: `drift-context.sh` walks upward from the edited file and stops at the first directory containing any spec. CONCEPT.md boundary sections (`## interactions`, `## dependencies`) and PIPELINE.md boundary sections (`## data boundary`) are extracted. SYNCS.md signals the hook to stop traversal but does not inject boundary declarations. If a non-CONCEPT spec shadows an ancestor CONCEPT.md (resulting in zero boundary context), the hook continues upward to find and inject ancestor boundaries with a `[SHADOWED]` caveat (see anti-patterns in concept/SKILL.md).
- Specs are documentation, not enforcement — drift detection catches divergence
- Both hooks are `type: "command"` only (no prompt or agent hooks)

## Working in This Repository

This is a plugin repository. There is no build step, test suite, or package.json.

**Deliverables**: `.claude-plugin/plugin.json` + `hooks/hooks.json` + `scripts/` + 4 SKILL.md files in `skills/`.

**Marketplace**: Hosted separately at [jlifyio/claude-plugins](https://github.com/jlifyio/claude-plugins). Install: `/plugin marketplace add jlifyio/claude-plugins` then `/plugin install wyx@jlifyio`.

**Runtime dependency**: `jq` — used by `drift-context.sh` for JSON parsing. Without it, drift context is a no-op (the SessionStart hook warns users). Users lose boundary checking.

**Editing skills**: Each SKILL.md is self-contained. Edit the markdown body for behavior changes; edit YAML frontmatter for metadata (name, description, argument-hint, allowed-tools).

**Version**: Update in `.claude-plugin/plugin.json` only. The marketplace ([jlifyio/claude-plugins](https://github.com/jlifyio/claude-plugins)) does not duplicate the version — plugin.json is the authority per official docs.

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

# Validate plugin structure
python3 -c "import json; json.load(open('.claude-plugin/plugin.json'))" && echo "plugin.json OK"
python3 -c "import json; json.load(open('hooks/hooks.json'))" && echo "hooks.json OK"
for s in concept map pipeline sync; do test -f skills/$s/SKILL.md && echo "$s OK"; done
```

## Shell Script Conventions

Both scripts use `set -euo pipefail`. Key patterns to preserve when editing:

**Trailing slash stripping**: `PROJECT_DIR="${CLAUDE_PROJECT_DIR%/}"` — double-slash breaks `case` pattern matching against `$PROJECT_DIR/`.

**Case-insensitive heading extraction**: `extract_section` tries lowercase first, then Capitalized as fallback. Some projects use `## Purpose`; others use `## purpose`.

```bash
# extract_section uses sed address ranges between ## headings
# [^#] prevents matching ### subheadings
sed -n "/^## ${section}[[:space:]]*$/,/^## [^#]/{...}" "$file"
```

**Upward directory traversal**: `drift-context.sh` walks up from the edited file's directory, stops at project root via `case "$dir/" in "$PROJECT_DIR/"*) ;; *) break ;; esac`. Stops at the first directory containing any spec.

**Relative path resolution**: Files from tool input may be relative — resolve with `case "$file_path" in /*) ;; *) file_path="$PROJECT_DIR/$file_path" ;; esac`.

**PreToolUse output format**: Must use `hookSpecificOutput.additionalContext` (structured JSON via `jq -n`). Plain text stdout is only shown in verbose mode per official docs.

**JSONL reading**: Use `grep -v '^[[:space:]]*$' file | tail -1` instead of `tail -1` — Claude's Write tool may append trailing empty lines.

## Known Limitations

- **Context-only enforcement**: The PreToolUse hook outputs boundary context but cannot block edits. Enforcement relies on the LLM respecting the context. Tested with Opus-class models; behavior with less capable models is unknown.
- **Matcher coverage**: PreToolUse matches `Write|Edit|NotebookEdit`. File writes via `Bash` (e.g. `echo > file`, `sed -i`) bypass the hook entirely.
- **Spec heading format**: Some projects use capitalized headings (`## Purpose`, `## Actions`); others use lowercase (`## purpose`, `## actions`). The drift context hook handles both via fallback extraction.
- **PreToolUse context delivery**: Uses `hookSpecificOutput.additionalContext` (structured JSON) per the official hooks reference. Boundary declarations are delivered in full without truncation — completeness is prioritized over context savings.
- **Stale spec risk**: Outdated or incorrect specs can be worse than no specs — the hook injects boundary declarations verbatim without validation, which may guide Claude away from correct approaches toward spec-declared-but-nonexistent APIs. Run `/wyx:concept drift` regularly to catch divergence.
- **Claude-only testing**: All testing used Claude. Other LLMs may respond differently to CONCEPT.md specs.

## Design Decisions

- **Hook type: command only** — prompt hooks lack spec access, agent hooks add 10-30s latency. Command hooks extract boundaries in ~2s.
- **No truncation**: Boundary declarations delivered in full — incomplete boundaries defeat boundary checking.
- **No qualification**: Boundary declarations are injected without caveats like "these might be stale" — qualified boundaries defeat boundary checking (same principle as no truncation).
- **Drift stays in `/wyx:concept`**: `/wyx:concept drift` checks all 3 spec types (CONCEPT, PIPELINE, SYNCS) including cross-spec reference validation and SYNCS graph consistency. Extracting into a separate `/wyx:drift` skill was deferred — no functional conflict yet.
- **No plugin agents**: Isolated context is net-negative; skill namespace resolution undocumented. Drift-history + uncovered module detection implemented instead.
- **One spec per directory**: Multi-file patterns (`CONCEPT-*.md`) were removed — they caused 83% irrelevant boundary context injection in flat directories.
- **No SYNCS.md splitting**: The `## coordination graph` requires a complete view of all sync flows; partial graphs give false confidence.
- **Integration is a platform constraint**: The 4 skills operate independently (no skill-to-skill invocation in Claude Code). This is structural, not a bug.
- **No auto-invocation rules**: CLAUDE.md rules telling users to "check specs before imports" are redundant — the PreToolUse hook does this automatically.

## Test Results

Boundary violations: 33% → 0% (N=6 features, 2 projects). Note: before/after methodology with the same developer writing specs and testing features — the developer's improved architectural understanding from writing specs may independently contribute to fewer violations.
