# /wyx:audit Skill Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a discovery-only audit skill that scans projects for wyx spec coverage, detects pipeline/sync candidates, and outputs a prioritized TODO list of individual skill commands.

**Architecture:** Single read-only SKILL.md (~100-120 lines) with optional parallel scanning via Explore-type Agent subagents. No spec generation, no template duplication, no document auto-updating.

**Tech Stack:** SKILL.md (YAML frontmatter + markdown), bash for manual testing

**Design source:** Agent team debate (2026-03-11, 3 agents × 3 rounds). Unanimous convergence on discovery-only approach after full orchestrator rejected for context window exhaustion, template drift, and quality degradation.

---

## Chunk 1: Create the Skill

### Task 1: Create `skills/audit/SKILL.md`

**Files:**
- Create: `skills/audit/SKILL.md`

- [ ] **Step 1: Create the skill directory**

```bash
ls skills/  # verify parent exists
mkdir -p skills/audit
```

- [ ] **Step 2: Write the SKILL.md**

Create `skills/audit/SKILL.md` with the following exact content:

```markdown
---
name: audit
description: >
  Scan project for wyx spec coverage gaps, detect pipeline/sync candidates,
  and output a prioritized TODO list of individual wyx skill commands.
argument-hint: "e.g. src/lib/ to scope subtree, or leave empty for full project"
allowed-tools: Read, Glob, Grep, Agent
---

# Project Audit & Command Planner

You are scanning a project to assess wyx spec coverage and generate a prioritized
action plan. You do NOT generate specs — you identify what needs specs and output
the exact commands the user should run.

**Differentiation from SessionStart hook**: SessionStart reports existing spec counts
and uncovered module names. This skill adds: pipeline/sync candidate detection via
code pattern analysis, dependency-ordered command sequences, and spec staleness checks.

## How to interpret $ARGUMENTS

- **Path** (e.g. `src/lib/server/`): Scope the audit to this subtree only.
- **No arguments**: Audit the entire project.

## Step 1: Discover Existing Specs

Glob for all wyx spec files (scoped to path if given):
- `**/CONCEPT.md`
- `**/PIPELINE.md`
- `**/SYNCS.md`

Read each spec's first heading line to extract the concept/pipeline/sync name.

## Step 2: Identify Uncovered Modules

Find directories with 3+ source files (`.ts`, `.js`, `.svelte`, `.py`, `.rs`, `.go`,
`.java`, `.jl`) that lack a colocated CONCEPT.md.

Exclude well-known non-concept directories:
`tests/`, `test/`, `docs/`, `migrations/`, `node_modules/`, `.git/`, `dist/`, `build/`,
`components/ui/`, `__pycache__/`, `.svelte-kit/`, `target/`, `.claude/`.

## Step 3: Detect Pipeline Candidates

Search uncovered directories for data transformation patterns:
- Aggregation: `GROUP BY`, `.groupBy(`, `.agg(`, `.reduce(`
- Multi-stage processing: pipe chains, sequential transforms
- Batch/ETL: files named `*etl*`, `*pipeline*`, `*transform*`, `*ingest*`
- Query builders with joins across 2+ tables/sources

A pipeline candidate = directory where data flows through 2+ transformation stages.

## Step 4: Detect Sync Candidates

Search for cross-concept coordination patterns:
- Event handlers/listeners bridging 2+ concept-covered modules
- Files importing from 3+ different module directories
- Webhook/callback handlers, message queue consumers
- Scheduled jobs / cron patterns
- Directories named `*sync*`, `*handler*`, `*dispatch*`, `*orchestrat*`

A sync candidate = handler coordinating actions across 2+ concepts.

## Step 5: Parallel Scanning (5+ uncovered modules)

When the project has 5+ uncovered modules, dispatch 3 Agent subagents
(subagent_type: "Explore") in parallel for Steps 2-4:

1. **Concept scanner**: identify uncovered modules, note import relationships
2. **Pipeline scanner**: grep for data transformation patterns
3. **Sync scanner**: grep for cross-concept coordination patterns

Merge results before proceeding to Step 6. For smaller projects, run sequentially.

## Step 6: Determine Priority Order

Order uncovered modules by dependency depth:
1. Find import/require statements in each uncovered module
2. Modules that import NOTHING from other uncovered modules = Phase 1 (leaf)
3. Modules importing Phase 1 modules = Phase 2
4. Continue until all modules assigned a phase
5. Within a phase, sort alphabetically

Pipeline candidates come after the concepts that own their source data.
Sync candidates come after the concepts they coordinate.

## Step 7: Output Action Plan

Present in this exact format:

### Existing Specs ({N} found)

| Spec | Type | Staleness |
|------|------|-----------|
| `path/CONCEPT.md` | concept | ⚠️ Code modified since spec — suggest `/wyx:concept drift path/` |
| `path/PIPELINE.md` | pipeline | ✓ Current |

For staleness: compare spec path's sibling code files. If any `.ts`/`.py`/etc file
in the same directory has a newer mtime than the spec, flag as potentially stale.

### Recommended Commands (dependency order)

Output a numbered command list grouped by phase:

```
# Phase 1: Leaf concepts (no dependencies on other uncovered modules)
/wyx:concept src/lib/auth/
/wyx:concept src/lib/db/

# Phase 2: Depends on Phase 1
/wyx:concept src/lib/api/

# Phase 3: Data pipelines
/wyx:pipeline src/lib/analytics/

# Phase 4: Sync coordination
/wyx:sync src/lib/handlers/

# Phase 5: Drift checks (existing specs flagged as stale)
/wyx:concept drift

# Phase 6: Architecture map (after all specs complete)
/wyx:map
```

### Suggested Documentation Updates

After completing the above commands, suggest (do NOT auto-update):
- "Update CLAUDE.md: add/revise module descriptions in architecture section"
- "Update README.md: refresh architecture overview if it exists"
- "Run `/wyx:map` to regenerate ARCHITECTURE.md"

Only list suggestions relevant to what was found.
```

- [ ] **Step 3: Verify line count is ≤120 lines**

```bash
wc -l skills/audit/SKILL.md
```

Expected: ≤120 lines. If over, trim prose without removing procedural steps.

- [ ] **Step 4: Validate YAML frontmatter**

```bash
head -8 skills/audit/SKILL.md
# Verify: name, description, argument-hint, allowed-tools all present
```

---

## Chunk 2: Update Documentation & Test

### Task 2: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md` (Architecture section and Skills subsection)

- [ ] **Step 1: Add audit skill to Architecture → Skills section**

In the `### Skills` section of CLAUDE.md, add after the `/wyx:map` entry:

```markdown
**`/wyx:audit`** — Discovery-only project scanner. Scans for spec coverage gaps, detects pipeline/sync candidates via code pattern analysis, and outputs a dependency-ordered TODO list of individual skill commands. Read-only — does not generate specs or modify files. For projects with 5+ uncovered modules, uses parallel Explore-type Agent subagents. Differentiates from SessionStart by adding: pattern-based candidate detection, dependency ordering, and staleness checking.
```

- [ ] **Step 2: Update Architecture tree to include audit skill**

Add `audit/SKILL.md` to the skills tree in the Architecture section:

```
skills/
├── audit/SKILL.md          # /wyx:audit — project audit & command planner
├── concept/SKILL.md        # /wyx:concept — bounded concept design + drift detection
├── map/SKILL.md            # /wyx:map — architecture visualization from specs
├── pipeline/SKILL.md       # /wyx:pipeline — data pipeline specs with quality invariants
└── sync/SKILL.md           # /wyx:sync — sync coordination maps
```

- [ ] **Step 3: Commit documentation update**

```bash
git add CLAUDE.md
git commit -m "docs: add /wyx:audit skill to architecture documentation"
```

### Task 3: Manual Testing

- [ ] **Step 1: Validate plugin loads with new skill**

```bash
unset CLAUDECODE
cd /path/to/test-project && claude --plugin-dir /path/to/wyx -p "List the wyx skills available"
```

Expected: output includes "audit" alongside concept, map, pipeline, sync.

- [ ] **Step 2: Test audit against a real project**

```bash
cd /path/to/test-project && claude --plugin-dir /path/to/wyx -p "/wyx:audit"
```

Expected: structured output with existing specs table, recommended commands list, suggested doc updates.

- [ ] **Step 3: Test scoped audit**

```bash
cd /path/to/test-project && claude --plugin-dir /path/to/wyx -p "/wyx:audit src/lib/"
```

Expected: same format but scoped to the given subtree.

### Task 4: Final Commit

- [ ] **Step 1: Commit the skill**

```bash
git add skills/audit/SKILL.md
git commit -m "feat: add /wyx:audit discovery-only project scanner

Scans for spec coverage gaps, detects pipeline/sync candidates,
and outputs dependency-ordered TODO list of individual skill commands.
Read-only by design — no spec generation, no file modification."
```
