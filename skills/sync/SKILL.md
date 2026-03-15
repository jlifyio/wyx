---
name: sync
description: >
  This skill should be used when the user asks to "document sync patterns",
  "map sync handlers", "create SYNCS.md", "audit sync coordination",
  "wyx sync", "wyx", or wants to understand how concepts communicate
  through orchestrated workflows. Produces SYNCS.md coordination maps.
argument-hint: "e.g. src/lib/server/syncs/ or Stock-to-Indicators pipeline"
allowed-tools: Read, Glob, Grep, Write, Edit
---

# Sync Coordination Mapping

Generate a **sync coordination map** — a structured description of how
independent concepts interact through synchronization handlers. A sync map replaces
reading dozens of handler files with a single page showing the coordination topology,
timing patterns, and error strategies.

Syncs implement the execution mechanics of concept interactions. Where CONCEPT.md
`## interactions` declares relationships, SYNCS.md specifies the **execution mechanics**:
when the sync fires, what data flows, when it skips, and how errors propagate.

## How to interpret $ARGUMENTS

Determine the mode from the argument:

- **Path to sync directory** (e.g. `src/lib/server/syncs/`): **Retrofit mode** — read the existing sync handlers, map the coordination patterns, and propose a SYNCS.md. Flag any patterns that bypass concept boundaries.
- **Sync description** (e.g. `Order fulfillment → Inventory update`): **Greenfield mode** — design a sync spec for the described coordination. Define trigger, flow, qualification, and error strategy.
- **No arguments**: **Discovery mode** — analyze the project for sync-like patterns (event handlers, cross-concept calls, scheduled jobs, dispatch registrations) and list candidates. Do NOT generate full specs; ask the user which to elaborate.

## SYNCS.md Format

Write the spec as a `SYNCS.md` file placed **in the sync directory** (e.g. `src/lib/server/syncs/SYNCS.md`).

```markdown
# syncs: [Module/Area Name]

## coordination graph
[Text diagram showing concept-to-concept flow through syncs]

[Concept] --(action)--> (SyncName) --> [Concept]
[Concept] --(action)--> (SyncName) --> [Concept]
                                   --> [Concept]

## dispatching
- pattern: [event-driven | explicit-call | hybrid]
- error-isolation: [sync failure does NOT propagate to source | propagates]
- depth-limit: [max cascading depth, if applicable]
- context: [how correlation/tracing works across sync boundaries]

## sync: [SyncName]
trigger: [Concept.action | schedule(interval) | manual]
timing: [post-action | pre-validation | scheduled]
flow:
  1. [Concept.action] → [what data is read]
  2. [transform/filter/validate] → [what happens]
  3. [Concept.action] → [what data is written]
qualification: [conditions for execution vs skip]
error: [isolated | propagates | skip-and-log]
file: [relative path to implementation]
```

## Design Rules for Sync Patterns

1. **Syncs live between concepts**: A sync never belongs to a single concept. It
   coordinates two or more concepts. Place sync code in a dedicated directory, not
   inside concept directories.

2. **One direction per sync**: Each sync has a clear source and target. If two
   concepts need bidirectional coordination, use two separate syncs. This keeps
   the coordination graph acyclic and prevents cascading loops.

3. **Three timing patterns**:
   - **Post-action**: Runs AFTER source concept's action completes. Source succeeds
     regardless of sync outcome. Error-isolated.
   - **Pre-validation**: Runs BEFORE target concept's action. Validates cross-concept
     references. Blocks the target action on failure. Error-propagating.
   - **Scheduled**: Runs on a timer. Checks what needs updating, processes in batch.
     Independent of individual concept actions.

4. **Qualification over silent filtering**: Sync handlers should declare explicit
   qualification criteria (when to execute, when to skip). This makes the coordination
   graph truthful — you can see exactly when a sync fires vs when it is skipped.

5. **Error isolation by timing**: Post-action syncs should NOT fail the source action —
   the source concept completed its work. Pre-validation syncs SHOULD fail the target
   action — that is their purpose. Scheduled syncs should log errors and continue
   processing remaining items.

## Retrofit Mode Guidelines

When analyzing existing sync code:

1. Read all sync handler files in the directory
2. Read the index/registry file to understand registration and dispatch patterns
3. Read any dispatcher or context module to understand execution infrastructure
4. Map each sync to: trigger → flow → target
5. Classify timing patterns (post-action, pre-validation, scheduled)
6. Check for concept boundary violations within syncs (direct database imports
   for data owned by other concepts)
7. Note error handling strategies and correlation tracking

Present findings as:
```
## patterns detected
- [N] post-action syncs (event-driven, error-isolated)
- [N] pre-validation syncs (called before target action, error-propagating)
- [N] scheduled syncs (periodic batch processing)

## boundary concerns
- [file:line] sync directly queries [table] owned by [Concept] — should use [Concept.action]
```

## Greenfield Mode Guidelines

When designing from a sync description:

1. Identify source and target concepts (must each have CONCEPT.md or be candidates)
2. Determine timing: post-action, pre-validation, or scheduled?
3. Define the data contract: what fields flow from source to target?
4. Specify qualification criteria: when does this sync execute vs skip?
5. Choose error strategy based on timing pattern (see Design Rule 5)
6. Consider cascading: can this sync trigger another sync? If so, declare depth limits

## After Generating

1. Present the sync map to the user for review
2. Ask: "Are the timing patterns correct? Should any syncs be split or merged?"
3. Only write the `SYNCS.md` file after the user approves
4. If a `SYNCS.md` already exists, show a diff of proposed changes
5. If related CONCEPT.md specs exist, suggest: "Run `/wyx:concept drift` to verify
   sync references match current concept declarations."

## Relationship to Other wyx Skills

- **`/wyx:concept`**: Each concept in the coordination graph should have a CONCEPT.md.
  SYNCS.md references concept actions declared in CONCEPT.md specs.
  CONCEPT.md `## interactions` is the concept's view of its sync relationships.
  SYNCS.md is the sync directory's view of the same relationships — with execution details.
  **Placement**: Keep all syncs in a single SYNCS.md per sync directory — the coordination graph requires a complete view of all sync flows. See `/wyx:concept` for hook traversal behavior.
- **`/wyx:pipeline`**: When a sync includes data transformation stages, those stages may also
  appear in a PIPELINE.md. SYNCS.md handles coordination; PIPELINE.md handles data quality.
  A sync that transforms data should reference its PIPELINE.md.
