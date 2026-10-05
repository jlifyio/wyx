# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**wyx** is a Claude Code plugin that provides architecture guardrails for LLM-assisted development. The core mechanism: when Claude writes code near a module with a spec, the PreToolUse hook adds boundary declarations to Claude's context with the edit's result, intended to reduce cross-module violations (pilot-01: no measurable reduction — DEC-025).

Adapts ideas from **WYSIWID** (Meng & Jackson, MIT): the concept spec format and the concept/sync vocabulary. The injected boundary sections, calls between concepts, documentation-only syncs and the absence of a runtime are wyx's own departures — README §Background and DEC-022 record them. WYWIWID (Dr. Ernie) is cited as see-also only (DEC-022).

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

Each skill is fully described in its own `SKILL.md`; CLAUDE.md keeps only one-line invocation summaries. For Five Design Rules, drift calibration, retrofit guidance, and per-skill internals, read `skills/<name>/SKILL.md` (and `skills/<name>/references/` where present).

**`/wyx:audit`** — Read-only project scanner. Reports spec coverage gaps, pipeline/sync candidates, and a dependency-ordered TODO list of skill commands. Filters non-concept directories (types, utilities, schemas, thin store wrappers) before flagging. Does not generate specs.

**`/wyx:concept`** — Generates `CONCEPT.md` (purpose + state + actions + operational principle + interactions + dependencies). Four modes: Retrofit (path), Greenfield (text), Drift (`drift [path]`), Discovery (no args). Embodies the Five Design Rules and drift calibration — full definitions in `skills/concept/SKILL.md`.

**`/wyx:pipeline`** — Generates `PIPELINE.md` (sources, stages, outputs, quality invariants). Three modes: Retrofit / Greenfield / Discovery.

**`/wyx:map`** — Generates `ARCHITECTURE.md` from all wyx specs (Mermaid graph, dependency matrix, data flow, coverage). Single mode with optional path scoping. 8 determinism constraints for reproducible Mermaid (incl. matrix per-cell enumeration — DEC-020). Visual density at scale is an accepted limitation; scoped mode is the escape hatch.

**`/wyx:sync`** — Generates `SYNCS.md` documenting concept coordination through sync handlers (timing, qualification, error isolation, data flow). Three modes: Retrofit / Greenfield / Discovery.

### Hooks

**SessionStart** (command): Scans project for existing wyx artifacts (CONCEPT.md, PIPELINE.md, SYNCS.md) and reports coverage in sorted order. Warns if `jq` is missing. Suggests `/wyx:audit` if none found — but **only when the hook `source` is `startup`** (or empty/unparseable, the safe degrade); on `resume`/`clear`/`compact` the no-specs hint stays silent so a globally-enabled wyx does not nag in every spec-less project (DEC-021). Also reports last drift check date from `.claude/wyx-drift-history.jsonl` (if exists), warns if specs modified since last drift check (`find -newer`), checks ARCHITECTURE.md freshness, lists uncovered modules (directories with >2 source files lacking CONCEPT.md, PIPELINE.md, or SYNCS.md), and reports code directories modified since last drift check. Non-concept directories (`tests/`, `docs/`, `migrations/`, `components/ui/`, `types/`, `e2e/`, `cypress/`, `fixtures/`, `stubs/`, `mocks/`, `utils/`, `util/`, `helpers/`, `scripts/`, `schema/`, `schemas/`, `constants/`, `config/`) are excluded at any path depth (matched against `"/$rel/"`, so a bare top-level `tests` is excluded too), and build/dependency/hidden directories are pruned during the walk (how and why: the `PRUNE_DIRS` comments in `scripts/session-start.sh`). Shadowing detection flags PIPELINE.md-only directories (not SYNCS.md — SYNCS.md does not stop hook traversal).

**PreToolUse** (command, matcher: `Write|Edit|NotebookEdit`): When writing near a spec file, outputs boundary declarations via `hookSpecificOutput.additionalContext`. Extracts `## purpose` from all co-located specs (CONCEPT/PIPELINE/SYNCS) for the spec listing, plus boundary declarations: `## interactions` and `## dependencies` from CONCEPT.md, and `## data boundary` from PIPELINE.md. (Traversal rule: Key Constraints.) Resolves relative file paths to absolute. Handles both `file_path` (Write/Edit) and `notebook_path` (NotebookEdit) via jq fallback chain. Skips inert files (`.json`, `.jsonl`, `.lock`, `.log`, `.txt`) — no context injection for non-code files. Handles CRLF line endings via `tr -d '\r'` in extract_section. Enables LLM self-checking against declared boundaries. **This is the core differentiator of wyx** — concept specs are the fuel, this hook is the engine.

**PostToolUse** (command, matcher: `Write|Edit|NotebookEdit`): After a file edit near a CONCEPT.md, reinjects the `## dependencies` list as a focused reminder. Complements PreToolUse; both reach Claude with the edit's result, never before the edit that triggers them (DEC-025): PreToolUse carries the full boundary context, PostToolUse the dependency list. Walks upward to find the nearest CONCEPT.md only (not PIPELINE.md or SYNCS.md — they lack dependency lists). Silent when: no spec found, no `## dependencies` section, editing inert files, or editing spec files themselves. Language-agnostic, no import parsing. Design principle: **hooks extract and inject; the LLM judges**.

### Key Constraints

- Each skill is a self-contained SKILL.md (YAML frontmatter + markdown body), with optional references/ for detailed content loaded on demand (progressive disclosure)
- Artifacts are colocated with code: CONCEPT.md, PIPELINE.md, SYNCS.md next to implementation; drift history in `.claude/wyx-drift-history.jsonl`
- **One spec per directory**: Only `CONCEPT.md`, `PIPELINE.md`, `SYNCS.md` are recognized (no `CONCEPT-*.md` glob patterns). Each concept gets its own subdirectory. This ensures the PreToolUse hook injects only relevant boundary declarations.
- **Stop-at-first traversal**: `drift-context.sh` walks upward from the edited file and stops at the first directory containing a boundary-contributing spec (CONCEPT.md or PIPELINE.md). SYNCS.md is listed in spec context but does not stop traversal or inject boundary declarations. If no CONCEPT.md is co-located with the stopping spec (e.g., PIPELINE.md-only directory), the hook continues upward to find an ancestor CONCEPT.md and injects its boundaries with a `[SHADOWED]` caveat (see anti-patterns in concept/SKILL.md).
- Specs are documentation, not enforcement — drift detection catches divergence
- All three hooks are `type: "command"` only (no prompt or agent hooks)

### Agent dispatch: always pin the model

Every `Agent` dispatch in this plugin passes an explicit `model:` naming `opus`,
`sonnet` or `haiku` — `opus` for judgment, `sonnet` or `haiku` only for read-only
lookup. wyx dispatches only the **built-in `Explore` agent**, which carries no
frontmatter of its own, so an unpinned dispatch **inherits the session model**. Pin it
at the call site; the callee cannot.

The owner's agent policy behind this pin (Opus for judgment and code, effort by role, Haiku/Sonnet only for read-only lookup) and why `Explore` runs at the session's effort: `docs/agent-dispatch.md`.

**Enforced**, not remembered: `scripts/check-rules.sh` fails when a `subagent_type`
line under `skills/` has no `model:` naming `opus`, `sonnet` or `haiku` in its section,
wired as `gates.rules`. Add the check in the same change that adds a rule. This section
(with `docs/agent-dispatch.md` for the reasoning) is the single source — skill references carry the pin and a one-line why, nothing more.

Tell judgment from lookup by **which way a wrong answer fails**, not by how hard it feels:

| Fan-out | Model | Role — failure direction |
|---|---|---|
| `/wyx:map` spec reading | `sonnet` | Lookup — extracts *declared* sections; a wrong extraction is visible in the graph |
| `/wyx:concept drift` scanning | `opus` | Judgment — emits **absence claims** (`✓ clean`); a wrong verdict produces no output |

Two corollaries: a silent failure mode cannot use "start cheap, promote on a demonstrated miss", and the tier is not derived from whether the agent assigns severity or from its read-only tools. Reasons: `docs/agent-dispatch.md`.

## Working in This Repository

This is a plugin repository. There is no build step, test suite, or package.json.

**Deliverables**: `.claude-plugin/plugin.json` + `hooks/hooks.json` + `scripts/` + 5 SKILL.md files in `skills/`.

**Marketplace**: Hosted separately at [jlifyio/claude-plugins](https://github.com/jlifyio/claude-plugins). Install: `/plugin marketplace add jlifyio/claude-plugins` then `/plugin install wyx@jlifyio`.

**Runtime dependency**: `jq` — used by `drift-context.sh` and `post-check.sh` for JSON parsing. Without it, drift context and post-edit checks are no-ops (the SessionStart hook warns users). Users lose boundary checking.

**Editing skills**: Each SKILL.md is self-contained. Edit the markdown body for behavior changes; edit YAML frontmatter for metadata (name, description, argument-hint, allowed-tools).

**Version**: Update in `.claude-plugin/plugin.json` only. The marketplace ([jlifyio/claude-plugins](https://github.com/jlifyio/claude-plugins)) does not duplicate the version — plugin.json is the authority per official docs. Use `/release-kit:release X.Y.Z` to bump version across all files, commit, tag, push, and create a GitHub release.

**Plugin structure rules**:
- `plugin.json` goes inside `.claude-plugin/`
- `hooks.json` goes at plugin root in `hooks/`, not inside `.claude-plugin/`
- Hook scripts use `$CLAUDE_PLUGIN_ROOT` to resolve paths. In `hooks.json`, the command quotes it — `bash "${CLAUDE_PLUGIN_ROOT}/scripts/x.sh"` — because the install path lives under the user's home and an unquoted expansion breaks on any username with a space (`/Users/John Smith/…` → exit 127, all hooks dead)

## Testing

No traditional test suite — behaviour is tested by running skills against real
projects. The one automated gate is `bash scripts/check-rules.sh` (structural rule
checks + `bash -n` over every shell script); run it before every release.

```bash
# Test a single skill (non-interactive)
# Works from inside a Claude Code session too: nested `claude -p` runs with CLAUDECODE=1 set (verified on 2.1.289)
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
claude plugin validate .   # plugin.json + hooks.json + each present SKILL.md (passes; the CLAUDE.md-not-loaded warning is expected)
# Skill presence: validate passes with a skill directory missing, so always run this too
for s in audit concept map pipeline sync; do test -f skills/$s/SKILL.md && echo "$s OK"; done
```

## Shell Script Conventions

`drift-context.sh` and `post-check.sh` use `set -euo pipefail`. `session-start.sh` uses `set -eu` (no `pipefail` — internal pipes with `head -N` cause benign SIGPIPE). Key patterns to preserve when editing:

**Trailing slash stripping**: `PROJECT_DIR="${CLAUDE_PROJECT_DIR%/}"` — double-slash breaks `case` pattern matching against `$PROJECT_DIR/`.

**Case-insensitive heading extraction**: `extract_section_ci` tries lowercase first, then Capitalized as fallback. Some projects use `## Purpose`; others use `## purpose`. Capitalize with `tr`, not the `${var^}` expansion — `${var^}` is bash 4+ and macOS ships bash 3.2, where it errors and silently disables the fallback for legacy capitalized-heading specs.

```bash
# extract_section uses sed address ranges between ## headings
# [^#] prevents matching ### subheadings
sed -n "/^## ${section}[[:space:]]*$/,/^## [^#]/{...}" "$file"
```

**Upward directory traversal**: `drift-context.sh` walks up from the edited file's directory, stops at project root via `case "$dir/" in "$PROJECT_DIR/"*) ;; *) break ;; esac` (which spec stops the walk: Key Constraints).

**Relative path resolution**: Files from tool input may be relative — resolve with `case "$file_path" in /*) ;; *) file_path="$PROJECT_DIR/$file_path" ;; esac`.

**Directory membership by fixed string, not regex**: When testing whether a discovered directory belongs to a known set (e.g. `session-start.sh` uncovered-modules detection), keep the candidate paths newline-delimited and match with `grep -qxF` (fixed-string, whole-line) — do not interpolate paths into an ERE like `grep -qE "^($dirs)$"`. Directory paths legitimately contain regex metacharacters (SvelteKit route groups `(app)`, dotted dirs `v1.2`), which an ERE misinterprets, causing a spec'd directory to be misreported as uncovered.

**PreToolUse/PostToolUse output format**: Must use `hookSpecificOutput.additionalContext` (structured JSON via `jq -n`). For these events, plain-text stdout on exit 0 goes only to the debug log and never reaches Claude (hooks reference, "Exit code 0").

**JSONL reading**: Use `grep -v '^[[:space:]]*$' file | tail -1` instead of `tail -1` — a hand-edited or appended file can end in blank lines, and `tail -1` would return one. (The Write tool itself appends no trailing blank line; checked on 2.1.289.)

**`set -eu` + command substitution**: `var=$(cmd | jq ...)` aborts the script when jq exits non-zero, even without `pipefail`. Use `var=$(...) || var="fallback"` on every command-sub that can fail — this covers jq parses (the `hook_source` parse at the top of `session-start.sh`; `grep -n '|| ' scripts/*.sh` lists every guard), stdin reads (`input=$(cat) || input=""` at the top of `drift-context.sh` and `post-check.sh`), and the load-bearing final emit (`jq -n ... || true`). A single unguarded line can silently kill a hook after partial output.

## Known Limitations

- **Advisory by decision**: The hooks only add context and never deny an edit, although a PreToolUse hook could (exit 2 or `permissionDecision: "deny"`); DEC-026 keeps wyx advisory so an explicit user instruction wins, and `scripts/check-rules.sh` ("hooks stay advisory") fails on a blocking output. Compliance relies on the LLM respecting the context. Tested with Opus-class models; behavior with less capable models is unknown.
- **Matcher coverage**: PreToolUse matches `Write|Edit|NotebookEdit`. File writes via `Bash` (e.g. `echo > file`, `sed -i`) or via MCP file-write tools (`mcp__server__*`) bypass the hook entirely.
- **Harness tool availability**: Skills declare `Glob`/`Grep` in `allowed-tools`, but Claude Code leaves both tools out by default on macOS, Linux and WSL (Claude searches with `find`/`grep` through Bash instead), and `allowed-tools` pre-approves tools without adding or removing any. `/wyx:audit` falls back to read-only shell discovery (DEC-019); `/wyx:map` already lists `Bash`. `/wyx:pipeline` and `/wyx:sync` *Discovery* mode (no-arg) then searches through Bash; neither skill lists `Bash`, but read-only commands such as `find` and `grep` run without a permission prompt (Claude Code permissions docs; in Manual mode `find` with an unquoted glob still prompts); `/wyx:concept` Discovery can also delegate to its `Agent` tool.
- **Spec heading format**: Some projects use capitalized headings (`## Purpose`, `## Actions`); others use lowercase (`## purpose`, `## actions`). The drift context hook handles both via fallback extraction.
- **Delivery timing and size**: `hookSpecificOutput.additionalContext` is added next to the tool result, so the triggering edit and every other tool call in the same response are written without it (DEC-025). wyx never trims boundaries, but Claude Code moves any context over 10,000 characters into a file and passes a 2,000-character preview.
- **Stale spec risk**: Outdated or incorrect specs can be worse than no specs — the hook injects boundary declarations verbatim without validation, which may guide Claude away from correct approaches toward spec-declared-but-nonexistent APIs. Run `/wyx:concept drift` regularly to catch divergence.
- **Claude-only testing**: All testing used Claude. Other LLMs may respond differently to CONCEPT.md specs.

## Documentation

- `docs/DECISIONS.md` — Architecture Decision Records (DEC-001〜DEC-027). Check before making architectural changes.
- `docs/evaluation-protocol.md` — Concurrent A/B protocol for re-measuring boundary-violation rates (DEC-022).
- `docs/agent-dispatch.md` — The agent policy and tier reasoning behind "Agent dispatch: always pin the model".

## Design Decisions

- **Hook type: command only** — prompt hooks lack spec access; agent hooks were put at 10-30s per edit in early 2026, against about 2s for the command hooks (DEC-010; no measurement recorded).
- **No truncation**: wyx never trims boundary declarations — incomplete boundaries defeat boundary checking (Claude Code's own 10,000-character cap still applies; see Known Limitations).
- **No qualification, no shouting**: Boundary declarations are injected without caveats like "these might be stale" — qualified boundaries defeat boundary checking (same principle as no truncation). The instructions wrapped around them give the reason and carry no capitalised NEVER/MUST (rationale: DEC-024; `scripts/check-rules.sh` checks the per-edit hooks it lists).
- **Drift stays in `/wyx:concept`**: `/wyx:concept drift` checks all 3 spec types (CONCEPT, PIPELINE, SYNCS) including cross-spec reference validation and SYNCS graph consistency. Extracting into a separate `/wyx:drift` skill was deferred — no functional conflict yet.
- **Read-only subagents only**: Concept drift and map generation use Explore-type subagents (structurally read-only — Write/Edit unavailable) for parallel scanning. Audit discovers directly with no subagents (YAGNI at current scale, and subagent Bash commands caused approval fatigue) — Glob+Grep where the session has them; where it has none (the default on macOS, Linux and WSL), audit uses read-only shell (Bash `find`/`ls`/`grep -r`) for discovery only — never for writes, preserving the read-only invariant (DEC-019). Full plugin agents remain excluded.
- **One spec per directory**: Multi-file patterns (`CONCEPT-*.md`) were removed — they caused 83% irrelevant boundary context injection in flat directories.
- **No SYNCS.md splitting**: The `## coordination graph` requires a complete view of all sync flows; partial graphs give false confidence.
- **Audit is discovery-only**: `/wyx:audit` scans and reports but does not generate specs or check staleness (defers to `/wyx:concept drift` for semantic analysis — mtime-based staleness produced 100% false positives in testing). No orchestrator (DEC-001, DEC-011).
- **Skills stay independent**: The 5 skills do not invoke each other. Claude Code allows it — the Skill tool can run one skill from another, as workflow-kit's `closing` does with `/wyx:audit`, `/wyx:concept drift` and `/wyx:map` — but an orchestrator was rejected for context exhaustion, template drift and quality loss (DEC-001).
- **No auto-invocation rules**: wyx adds no CLAUDE.md or `.claude/rules/` files of its own; its hooks deliver boundaries after each edit (DEC-025). In pilot-02, launch-loaded rules were followed by Claude ranking the import rules above the user's scope request, so the README offers them as the user's choice, not a wyx default (DEC-027).
- **PostToolUse = context reinforcement, not import checking**: PostToolUse reinjects the dependency list only — no import parsing, no language-specific code. Mechanical import checking was rejected: concept-name-to-import-path mapping has no clean bash solution, and language-specific code violates wyx's language-agnostic principle (DEC-014). Architectural rule: **hooks extract and inject; the LLM judges**.
- **Both per-edit hooks arrive with the edit's result** and differ only in content (full boundaries vs the dependency list with a check-this-edit instruction); the history of the PostToolUse decision is in DEC-010, DEC-014 and DEC-025.

## Test Results

README §Test results and methodology holds the sample, significance and confounds. Do not restate its numbers here. Not in the README: drift and coverage were additionally validated on a third project (WineLevel3, 10 concepts), and the redundant data store anti-pattern was found in 3/3 audited projects — addressed by Design Rule 5 and Retrofit step 4 in v0.16.3.
