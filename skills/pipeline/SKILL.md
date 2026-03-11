---
name: pipeline
description: >
  Specify wyx data pipelines with quality invariants and boundary ownership.
  Use when designing data pipelines, auditing existing transformations,
  or discovering pipeline candidates. Produces PIPELINE.md specs.
argument-hint: "e.g. src/lib/syncs/, Sentiment scoring pipeline, or leave empty to discover"
allowed-tools: Read, Glob, Grep, Write, Edit
---

# Data Workflow Specification

You are generating a **data pipeline specification** — a structured description of how data
flows through transformations, what quality invariants must hold, and which concepts own the
source and output data.

## How to interpret $ARGUMENTS

Determine the mode from the argument:

- **Path to directory/file** (e.g. `src/lib/server/syncs/`): **Retrofit mode** — read the existing data transformation code, identify the pipeline stages, and propose a PIPELINE.md spec. Flag any quality invariants that are assumed but not checked.
- **Pipeline description** (e.g. `Sentiment scoring with recency weighting`): **Greenfield mode** — design a data pipeline spec from the description. Define sources, stages, outputs, and invariants.
- **No arguments**: **Discovery mode** — analyze the project for data workflows (queries, aggregations, sync chains, batch operations) and list candidates for PIPELINE.md specs. Do NOT generate full specs; ask the user which to elaborate.

## PIPELINE.md Format

Write the spec as a `PIPELINE.md` file placed **next to the data transformation code** (one per directory).

```markdown
# pipeline: [Name]

## purpose
[Single sentence: what data this pipeline produces and for whom]

## sources
- [name]: [table/file/API] → [key fields] ([row estimate or "unbounded"])

## stages

### [stage-name] [tool: <tool-name>]
in: [source or previous stage output]
out: [what this stage produces]
[1-3 lines: transformation logic]
quality: [invariant for this stage]

### [stage-name] [tool]
in: [...]
out: [...]
[...]
quality: [invariant]

## outputs
- [name]: [table/format] → [key fields] ([row estimate])

## invariants
- [data quality rules that must always hold across the full pipeline]
- [e.g. "output rows <= input rows" or "scores in [-1.0, 1.0]"]
- [e.g. "no null values in amount_tax_excluded after stage 2"]

## triggers
- [what causes this pipeline to run: sync event, API call, schedule, manual]

## data boundary
- [which concept owns the source data — read through its service, not direct SQL]
- [which concept owns the output data — write through its service, not direct INSERT]
```

## Design Rules for Data Pipelines

1. **Source ownership**: Every data source belongs to a concept. Read through the concept's
   service or query actions, never import `db` directly for cross-concept data. If the
   pipeline needs data from another concept, declare it in `## data boundary`.

2. **Invariants are executable**: Each invariant should be verifiable at runtime.
   Write them as assertions, not aspirations. Good: "output.rows <= input.rows".
   Bad: "data should be clean".

3. **Stage granularity**: Each stage should have a single transformation purpose.
   If a stage does filtering AND aggregation, split it. This makes individual stages
   testable and traceable.

4. **Tool declaration**: Declare which tool each stage uses (e.g. the project's
   database, language, or data processing library). This helps future developers
   understand the technology stack.

## Retrofit Mode Guidelines

When analyzing existing data transformation code:

1. Identify the data flow: source → transforms → output
2. Map DuckDB queries, aggregations, and joins to pipeline stages
3. Identify implicit invariants (e.g., `WHERE amount >= 0` implies non-negative invariant)
4. Check for cross-concept data access violations (direct `db` imports for foreign tables)
5. Note which stages are in sync handlers vs. direct API routes

Present findings as:
```
## data boundary violations found
- [file:line] directly queries [table] owned by [Concept] — should use [Concept].list/query
- [file:line] aggregates [table] with raw SQL — should use service-layer aggregation
```

## Greenfield Mode Guidelines

When designing from a pipeline description:

1. Define sources with ownership (which concept owns each input?)
2. Design stages as a DAG — each stage has typed inputs and outputs
3. Write invariants that are checkable (row count bounds, value ranges, null checks)
4. Consider: what triggers this pipeline? Manual, event-driven, scheduled?
5. Consider: what happens when source data changes? (idempotent? append-only? full refresh?)

## After Generating

1. Present the pipeline spec to the user for review
2. Ask: "Are the invariants correct? Should any stages be split or merged?"
3. Only write the `PIPELINE.md` file after the user approves
4. If a `PIPELINE.md` already exists, show a diff of proposed changes
5. If `ARCHITECTURE.md` exists in the project, remind the user: "Spec changed — run `/wyx:map` to update ARCHITECTURE.md."

## Relationship to Other wyx Skills

- **`/wyx:concept`**: Defines the service boundaries that data pipelines must respect.
  A PIPELINE.md references CONCEPT.md-defined services for data access.
  **Placement**: Co-locate PIPELINE.md with CONCEPT.md in the same directory. A PIPELINE.md in a subdirectory shadows the parent CONCEPT.md's boundary checking — see `/wyx:concept` for details.
- **`/wyx:sync`**: When a sync includes data transformation stages, those stages may also
  appear in a PIPELINE.md. SYNCS.md handles coordination; PIPELINE.md handles data quality.
