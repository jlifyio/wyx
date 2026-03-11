---
name: audit
description: >
  Scan project for wyx spec coverage gaps, detect pipeline/sync candidates,
  and output a prioritized TODO list of individual wyx skill commands.
argument-hint: "e.g. src/lib/ to scope subtree, or leave empty for full project"
allowed-tools: Read, Glob, Grep
---

# Project Audit & Command Planner

Scan project for wyx spec coverage and generate a prioritized action plan.
You do NOT generate specs — you identify what needs specs and output commands to run.
Unlike SessionStart (which reports counts), this adds: pattern-based pipeline/sync
candidate detection and dependency-ordered command sequences.

## How to interpret $ARGUMENTS

- **Path** (e.g. `src/lib/server/`): Scope the audit to this subtree only.
- **No arguments**: Audit the entire project.

## Step 1: Discover Existing Specs

Glob for all wyx spec files (scoped to path if given):
- `**/CONCEPT.md`
- `**/PIPELINE.md`
- `**/SYNCS.md`

Read each spec's first heading to extract the concept/pipeline/sync name.

## Step 2: Identify Uncovered Modules

Find directories with 3+ source files (`.ts`, `.js`, `.tsx`, `.jsx`, `.svelte`, `.vue`,
`.py`, `.rs`, `.go`, `.java`, `.jl`) lacking a colocated CONCEPT.md. Exclude: `tests/`,
`test/`, `docs/`, `migrations/`, `node_modules/`, `.git/`, `dist/`, `build/`,
`components/ui/`, `__pycache__/`, `.svelte-kit/`, `target/`, `.claude/`,
`types/`, `e2e/`, `cypress/`, `fixtures/`, `stubs/`, `mocks/`.

Before flagging a directory, evaluate for behavioral cohesion — directories containing
only type definitions, stateless utility functions, thin store wrappers, or schema
definitions rarely warrant concept specs (no state ownership + actions + operational principle).

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
