---
name: audit
description: >
  This skill should be used when the user asks to "audit spec coverage",
  "find uncovered modules", "scan for missing specs", "check wyx coverage",
  "get spec TODO list", "wyx audit", "wyx", or wants a prioritized list
  of wyx skill commands for uncovered modules. Scans for coverage gaps,
  pipeline/sync candidates, and outputs dependency-ordered commands.
argument-hint: "e.g. src/lib/ to scope subtree, or leave empty for full project"
allowed-tools: Read, Glob, Grep
---

# Project Audit & Command Planner

Scan project for wyx spec coverage and generate a prioritized action plan.
This skill does NOT generate specs — it identifies what needs specs and outputs commands to run.
Unlike SessionStart (which reports counts), this adds: pattern-based pipeline/sync
candidate detection and dependency-ordered command sequences.

**Tool constraint**: Use only Glob, Grep, and Read. Do NOT use Bash, shell commands,
`find`, or subagents for any step. File discovery and counting must use Glob results.

## How to interpret $ARGUMENTS

- **Path** (e.g. `src/lib/server/`): Scope the audit to this subtree only.
- **No arguments**: Audit the entire project.

## Step 1: Discover Existing Specs

Glob for all wyx spec files (scoped to path if given):
- `**/CONCEPT.md`
- `**/PIPELINE.md`
- `**/SYNCS.md`

Read each spec's first heading to extract the concept/pipeline/sync name.

For each spec, also check for boundary-contributing sections (the sections the PreToolUse
hook extracts): CONCEPT.md should have `## interactions` or `## dependencies`; PIPELINE.md
should have `## data boundary`. Note any spec missing all its expected boundary sections.

## Step 2: Identify Uncovered Modules

Find directories with more than 2 source files lacking any colocated spec (CONCEPT.md, PIPELINE.md, or SYNCS.md). This matches the SessionStart hook's exclusion set — any of the three spec types protects a directory from being flagged.
**Use Glob only** — never use Bash/find/shell commands for file discovery.

How to count source files per directory using Glob:
1. Run Glob for `**/*.{ts,js,tsx,jsx,svelte,vue,py,rs,go,java}` (scoped to path if given)
2. From the results, group files by their parent directory and count per directory
3. Directories with more than 2 source files and no colocated spec are candidates

Exclude directories matching: `tests/`, `test/`, `docs/`, `migrations/`, `node_modules/`,
`.git/`, `dist/`, `build/`, `components/ui/`, `__pycache__/`, `.svelte-kit/`, `target/`,
`.claude/`, `types/`, `e2e/`, `cypress/`, `fixtures/`, `stubs/`, `mocks/`.

Before flagging a directory, evaluate for behavioral cohesion — directories containing
only type definitions, stateless utility functions, thin store wrappers, or schema
definitions rarely warrant concept specs (no state ownership + actions + operational principle).
When evaluating cohesion, look for concrete signals: mutable state ownership (e.g. class fields,
instance variables, module-level state), lifecycle methods (init/reset/destroy), persistence
logic (database, file I/O, caching), or event emission (emit/dispatch/publish). Directories
with multiple signals are stronger concept candidates; directories with none are likely
support code — note the reason when skipping.

## Step 3: Detect Pipeline Candidates

Search uncovered directories for data transformation patterns:
- Aggregation: `GROUP BY`, `.groupBy(`, `.agg(`, `.reduce(`
- Multi-stage / ETL: pipe chains, files named `*etl*`/`*pipeline*`/`*transform*`
- Query builders with joins across 2+ tables/sources

Pipeline candidate = directory with 2+ transformation stages.

## Step 4: Detect Sync Candidates

Search for cross-concept coordination patterns:
- Event handlers/listeners bridging 2+ concept-covered modules
- Files importing from 3+ different module directories
- Webhook/callback handlers, message queue consumers
- Scheduled jobs / cron patterns
- Directories named `*sync*`, `*handler*`, `*dispatch*`, `*orchestrat*`

Sync candidate = handler coordinating actions across 2+ concepts.

## Step 5: Determine Priority Order

Order uncovered modules by dependency depth:
1. Find import/require statements in each uncovered module
2. Modules that import NOTHING from other uncovered modules = Phase 1 (leaf)
3. Modules importing Phase 1 modules = Phase 2
4. Continue until all modules assigned a phase
5. Within a phase, sort alphabetically

Pipeline candidates come after the concepts that own their source data.
Sync candidates come after the concepts they coordinate.

## Step 6: Output Action Plan

Present in this exact format:

### Existing Specs ({N} found)

| Spec | Type |
|------|------|
| `path/CONCEPT.md` | concept |
| `path/PIPELINE.md` | pipeline |

If any specs from Step 1 lack boundary-contributing sections, note after the table:
"{N} spec(s) provide no boundary declarations — the PreToolUse hook injects nothing
for these directories. Consider adding `## interactions`/`## dependencies` (CONCEPT.md)
or `## data boundary` (PIPELINE.md)."

**If no uncovered modules were found** in Step 2, output instead:

```
### Coverage Status
All {N} domain modules have specs. No uncovered modules found.

Next steps:
- `/wyx:concept drift` — check spec freshness (semantic analysis)
- `/wyx:map` — regenerate ARCHITECTURE.md if specs have changed
```

Then skip to Suggested Documentation Updates (omit Recommended Commands and drift line).

**Otherwise**, include the drift recommendation and continue with the sections below.

Run `/wyx:concept drift` to check spec freshness (semantic analysis, not mtime).

### Recommended Commands (dependency order)

Output a command list grouped by phase:

```
# Phase 1: Leaf concepts (no deps on other uncovered modules)
/wyx:concept src/lib/auth/
/wyx:concept src/lib/db/
# Phase 2: Depends on Phase 1
/wyx:concept src/lib/api/
# Phase 3: Data pipelines
/wyx:pipeline src/lib/analytics/
# Phase 4: Sync coordination
/wyx:sync src/lib/handlers/
# Phase 5: Drift checks (existing specs flagged stale)
/wyx:concept drift
# Phase 6: Architecture map (after all specs)
/wyx:map
```

### Suggested Documentation Updates

Suggest (do NOT auto-update) only what is relevant:
- "Update CLAUDE.md: add/revise module descriptions"
- "Update README.md: refresh architecture overview"
- "Run `/wyx:map` to regenerate ARCHITECTURE.md"
