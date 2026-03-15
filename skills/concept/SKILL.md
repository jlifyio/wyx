---
name: concept
description: >
  This skill should be used when the user asks to "create a concept spec",
  "retrofit a module", "check spec drift", "run drift detection",
  "design a new module", or wants to generate, update, or audit CONCEPT.md
  files. Supports retrofit, greenfield, drift detection, and discovery modes.
argument-hint: "e.g. src/lib/auth/, Payment processing, drift src/lib/, or leave empty to discover"
allowed-tools: Read, Glob, Grep, Write, Edit, Agent
---

# Bounded Concept Design

Generate a **concept specification** — a structured description of a module
that serves as compressed context for code generation. A concept spec replaces reading
200+ lines of implementation with a 30-line bounded description of what the module IS.

## How to interpret $ARGUMENTS

Determine the mode from the argument:

- **Path to directory/file** (e.g. `src/lib/server/auth/`): **Retrofit mode** — read the existing code and propose a concept spec that describes what is already there. Flag any boundary violations you find (imports from other modules' internals, shared mutable state, etc.)
- **Feature description** (e.g. `Portfolio tracking with watchlists`): **Greenfield mode** — design a new concept spec from the description. Enforce decomposition: if the feature has multiple independent purposes, split into multiple concepts.
- **`drift` or `check`** (with optional path, e.g. `drift src/lib/server/`): **Drift detection mode** — compare existing CONCEPT.md/PIPELINE.md specs against current code. Produce a structured drift report showing what has diverged.
- **No arguments**: **Discovery mode** — analyze the project structure and propose which modules should have concept specs. List each candidate with a one-line purpose. Do NOT generate full specs; ask the user which ones to elaborate. After listing concept candidates, if the project has data transformation patterns or cross-concept coordination, briefly note that `/wyx:pipeline` and `/wyx:sync` are available for those patterns.

## Concept Spec Format

Write the spec as a `CONCEPT.md` file placed **next to the implementation code** (e.g. `src/lib/server/auth/CONCEPT.md`).

Use this exact structure:

```markdown
# concept: [Name] [TypeParam]

## purpose
[Single sentence: what this module does for its users]

## state
- [field]: [TypeParam] -> [type]
- [field]: [TypeParam] -> [type]

## actions

### [action-name] [input1: Type, input2: Type] => [output: Type]
[1-3 lines: what this action does, when it succeeds, when it fails]

### [action-name] [input1: Type] => [result: Type] | [error: String]
[behavior description with error cases as separate output patterns]

## operational principle
after [action]([args])
  => [expected output]
then [action]([args])
  => [expected output]
[This is simultaneously a behavioral contract and a test seed.
Write scenarios that define correct behavior. Multiple scenarios OK.]

## interactions
[Optional. How this concept coordinates with others.]
- when [ExternalConcept/action] completes, [this concept/action] should follow

## dependencies
[Optional. External concepts this module depends on.]
- [ExternalConcept]: [what this concept needs from it]
```

## Design Rules

Apply these five rules when generating or reviewing a concept spec:

1. **Single purpose**: Each concept serves exactly one user-facing purpose. If you find yourself writing "and" in the purpose, consider splitting.

2. **Concept independence**: A concept must not depend on the internal state of another concept. Concepts interact only through their declared actions. If you see direct imports of another module's internal types or state, flag it as a boundary violation.

3. **State ownership**: Each piece of state belongs to exactly one concept. No shared mutable state between concepts. If two concepts need the same data, one owns it and the other queries it through an action.

4. **Actions as interface**: All external access to a concept goes through its declared actions. No reaching into internal implementation details.

5. **Actions as declarations, not events**: Actions define what the module can do, not what happens when it runs. Do not derive runtime infrastructure (logging, metrics, interceptors, middleware) from action declarations. Cross-cutting infrastructure that wraps multiple concepts should be its own concept with its own spec.

## Retrofit Mode Guidelines

When analyzing existing code:

1. Read the directory structure, exports, and key files. Grep for all import/require/use statements to build a dependency map — list every external module imported and cross-reference against existing CONCEPT.md files to identify which imports cross concept boundaries.
2. Identify the implicit purpose (what does this module do?)
3. Map existing functions/methods to actions
4. Identify state (what data does this module own?). Check whether any state overlaps with state already declared in other CONCEPT.md files — flag overlaps as potential Rule 3 violations.
5. Write an operational principle based on how the code is actually used
6. **Compress common parameters**: When a parameter appears in most or all actions (e.g. `modified_by: string`), declare it once at the top of `## actions` as a common parameter rather than repeating in each action signature
7. **Focus on public contract**: When listing state fields, focus on fields that define the concept's public contract. Omit obvious implementation details (private caches, internal indices, session-local temporaries) — these are flagged as Low severity if discovered during drift detection (see Drift calibration)
8. **Flag violations**: List any boundary violations found:
   - Cross-module internal imports (imports reaching into another concept's internal files rather than its public API)
   - Shared mutable state
   - Functions that serve multiple unrelated purposes
   - State that belongs to a different concept

Present violations as:
```
## boundary violations found
- [file:line] imports [other-module] internals: [what and why it's a problem]
- [description of shared state issue]
```

## Greenfield Mode Guidelines

When designing from a feature description:

1. Ask: "What is the single purpose?" — if multiple, split
2. Define the minimal state needed
3. Design actions as the complete interface (what can users DO with this concept?)
4. Write operational principles that define correctness (these become test cases)
5. Consider interactions: what other concepts does this one relate to?

## After Generating

1. Present the concept spec to the user for review
2. Ask: "Does this decomposition look right? Should anything be split or merged?"
3. Only write the `CONCEPT.md` file after the user approves
4. If a `CONCEPT.md` already exists, show a diff of proposed changes
5. If `ARCHITECTURE.md` exists in the project, remind the user: "Spec changed — run `/wyx:map` to update ARCHITECTURE.md."

## Spec Placement and Hook Behavior

The drift context hook walks **upward** from the edited file's directory and stops at the **first directory containing any wyx spec** (CONCEPT.md, PIPELINE.md, or SYNCS.md). Only CONCEPT.md boundary sections (`## interactions` and `## dependencies`) are extracted for boundary checking.

**Co-locate specs**: Place CONCEPT.md and PIPELINE.md in the same directory when the pipeline belongs to that concept. The hook finds both and extracts CONCEPT.md boundaries correctly.

**Anti-patterns to avoid**:
- **Root-level CONCEPT.md**: A CONCEPT.md at `src/` becomes the fallback boundary for all files in subdirectories that lack their own closer spec — applying overly broad boundaries to uncovered modules.
- **Spec in a subdirectory**: A PIPELINE.md at `scoring/transforms/PIPELINE.md` causes the hook to stop there, silently hiding `scoring/CONCEPT.md` boundary declarations for files in `transforms/`.
- **Spec far from code**: A CONCEPT.md placed far from implementation won't trigger when nearby files are edited.

## Drift Detection Mode

When `$ARGUMENTS` starts with `drift`, detect spec-code divergence across
all spec types (CONCEPT.md, PIPELINE.md, SYNCS.md) including cross-spec
reference validation.

Read `references/drift-detection.md` for the complete drift detection
procedure, check tables, calibration rules, and report format.

## When Updating an Existing Concept

If `CONCEPT.md` already exists for the module:

1. Read the existing spec
2. Compare against the current code
3. Propose updates (new actions, changed state, revised operational principles)
4. Flag any drift: where the code has evolved beyond what the spec describes

## Relationship to Other wyx Skills

- **`/wyx:pipeline`**: When a concept's dependencies involve data transformations or
  aggregation pipelines, `/wyx:pipeline` can document stages, quality invariants, and
  data ownership boundaries.
- **`/wyx:sync`**: When a concept's interactions involve complex coordination patterns
  (timing, error isolation, qualification criteria), `/wyx:sync` can map the execution
  mechanics that CONCEPT.md's `## interactions` declares at a high level.
