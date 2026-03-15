# Drift Detection Procedure

When `$ARGUMENTS` starts with `drift`, scan for spec-code divergence.

## How it works

1. **Find all specs**: Locate all `CONCEPT.md`, `PIPELINE.md`, and `SYNCS.md` files in the target path (or entire project if no path given). When scoped to a path, also search for dependent specs outside the scope: walk upward from the target path for ancestor specs, and find any `SYNCS.md` or `PIPELINE.md` elsewhere that reference concepts within the target path. This ensures cross-spec validation remains complete even in scoped mode.
2. **For each spec**: Read the spec AND the corresponding implementation code
3. **Compare**: Check for divergence in each category (see below)
4. **Report**: Produce a structured drift report

## Parallel scanning

When 3+ specs are found, use `Agent` with `subagent_type: "Explore"` to scan specs in parallel. Explore agents are read-only (Write/Edit structurally unavailable) — safe for drift analysis.

- Spawn one Explore agent per spec (or group of 2-3 nearby specs)
- Each agent reads the spec + implementation code and returns findings in the drift report format (category, severity, file:line, description)
- After all agents complete, merge findings into a single drift report, then run cross-spec validation and systemic pattern aggregation in the main context

## What to check for each CONCEPT.md

| Category | How to detect | Severity |
|----------|--------------|----------|
| **Missing action** | Function/method exists in code but not declared in spec `## actions` | Medium |
| **Removed action** | Action declared in spec but function no longer exists in code | High |
| **Changed signature** | Function parameters or return type differ from spec declaration | Medium |
| **New state** | New table column, class field, or persistent data not in spec `## state` | Medium |
| **New dependency** | Import from a concept not listed in spec `## dependencies` | High |
| **Boundary violation** | Direct import of another concept's internals (not through declared actions) | Critical |
| **Cross-cutting parameter** | A parameter appears in 3+ action implementations but is not documented in any action signature in `## actions` | Medium |
| **Resolved known gap** | If spec contains a `## known gaps` section, check whether any documented gaps have been resolved by existing code | Low |

## What to check for each PIPELINE.md

| Category | How to detect | Severity |
|----------|--------------|----------|
| **Missing stage** | New transformation step in code not declared in spec `## stages` | Medium |
| **Changed invariant** | Code logic contradicts a declared invariant | High |
| **New data source** | Code reads from table/API not listed in spec `## sources` | Medium |
| **Boundary violation** | Direct DB import for data owned by another concept | Critical |

## What to check for each SYNCS.md

| Category | How to detect | Severity |
|----------|--------------|----------|
| **Missing sync** | New cross-concept coordination in code not declared in spec | Medium |
| **Changed timing** | Code uses different trigger pattern (e.g. scheduled vs post-action) than spec declares | Medium |
| **New participant** | Sync handler involves a concept not listed in the spec | High |
| **Removed sync** | Sync declared in spec but handler no longer exists in code | High |
| **Graph inconsistency** | `## coordination graph` lists a sync flow not defined in any `## sync:` block, or vice versa | Medium |
| **Missing SYNCS coverage** | A CONCEPT.md `## interactions` declares a coordination relationship but no corresponding sync exists in any SYNCS.md | Medium |

## Drift calibration

- When the spec uses a simpler signature than the implementation's type wrapper (e.g., `void` vs `Promise<void>`, `Result` vs `anyhow::Result`), treat the discrepancy as Low unless it changes the error handling or calling contract.
- State fields that are implementation details (private variables, internal caches, derived computed values) rather than part of the concept's public API contract should be flagged as Low severity.
- Private helper methods or internal implementation functions (not exported, not called from outside the module) that appear as "Missing action" findings should be treated as Low severity — these are implementation details, not part of the concept's public API contract.
- Naming convention differences between spec and code (camelCase vs snake_case, abbreviated vs full names) are Low severity — style issues, not contract violations. Exception: if the divergent name appears in cross-spec references (PIPELINE.md or SYNCS.md), flag as Medium since renaming requires coordinated updates.
- When the same Low finding repeats across multiple actions in one spec (e.g., same undocumented parameter in 3+ actions), count as a single Low with a note listing affected actions. Deduplicated Lows count as 1 in the `low_by_spec` JSONL field.
- Before reporting a finding as Medium or higher, verify it exists in the current code with grep or file read. Do not report drift based on memory or assumptions from prior file reads.
- If a single spec accumulates more than 5 Low findings (after deduplication), note this in the drift report summary and suggest re-evaluating whether the spec's `## actions` or `## state` adequately describes the module's current public surface.

## Drift Report Format

Present the report as:

```
# Drift Report — [date]

## Summary
- Specs scanned: [N]
- Specs with drift: [N]
- Critical: [N] | High: [N] | Medium: [N] | Low: [N]

## [Concept/Pipeline Name] — [path/to/CONCEPT.md]

### Critical
- **Boundary violation**: [file:line] imports [module] directly — spec declares interaction through [action] only

### High
- **Removed action**: `deleteUser` declared in spec but no longer exists in code
- **New dependency**: code imports `PaymentConcept` but spec `## dependencies` only lists `AuthConcept`

### Medium
- **Missing action**: `exportToCSV()` exists in code but not declared in spec
- **Changed signature**: `createUser` spec says `[name: string]` but code takes `[name: string, email: string]`

## [Next spec...]
```

## Cross-spec reference validation

After checking each spec individually, cross-validate references between spec types in the scanned path:

| What to check | How to detect | Severity |
|---------------|--------------|----------|
| **PIPELINE→CONCEPT name mismatch** | A PIPELINE.md `## stages` or `## data boundary` references a concept action name that doesn't match any declared action in the target CONCEPT.md `## actions` | High |
| **SYNCS→CONCEPT missing reference** | A SYNCS.md sync block references `Concept.action` where the action doesn't exist in the target CONCEPT.md | High |
| **SYNCS→CONCEPT missing participant** | A SYNCS.md sync block names a concept that has no corresponding CONCEPT.md | Medium |

Report mismatches in the drift report after per-spec results:

```
## Cross-spec reference validation

### High
- **PIPELINE→CONCEPT name mismatch**: pipelines/PIPELINE.md references `getExpired` but scoring/CONCEPT.md declares `findExpiredItems`
- **SYNCS→CONCEPT missing reference**: SYNCS.md `sync: onPurchase` references `Inventory.decrementStock` but Inventory CONCEPT.md has no `decrementStock` action

### Medium
- **SYNCS→CONCEPT missing participant**: SYNCS.md references `AuditLog` but no AuditLog CONCEPT.md exists
```

## Systemic pattern aggregation

After per-spec results and cross-spec validation, identify drift patterns that repeat across multiple specs. When the same drift category and description appear in 3+ specs, group them as a systemic issue instead of listing individually:

```
## Systemic patterns
- **Undocumented parameter `modified_by`** found in 4/7 concept specs — appears in mutation actions but not declared in ## actions signatures. Consider documenting as a common parameter in each affected spec.
- **Missing `## dependencies` section** in 3/5 concept specs that import from other concepts.
```

Systemic patterns suggest cross-cutting concerns rather than individual spec drift. Flag them for batch resolution.

## After Drift Report

**Phase 1 — Audit (read-only):**
1. Present the full report to the user
2. For each drifted spec, ask: "Update the spec to match code, or is this a code bug?"

**Phase 2 — Fix (user-approved writes):**
3. If updating spec: generate the specific minimal edits needed, then apply after user confirmation
4. If code bug: flag for fixing (the spec is the intended contract)
5. If spec changes were applied and `ARCHITECTURE.md` exists, remind the user: "Specs updated — run `/wyx:map` to regenerate ARCHITECTURE.md."

**Phase 3 — Record drift history:**
5. Append a summary entry to `.claude/wyx-drift-history.jsonl`:
```json
{"ts":"<ISO-8601>","specs_scanned":<N>,"specs_with_drift":<N>,"critical":<N>,"high":<N>,"medium":<N>,"low":<N>,"low_by_spec":{"path/CONCEPT.md":<N>},"path":"<scanned-path-or-project>"}
```
The `low_by_spec` field tracks per-spec Low counts for accumulation trending. When comparing against previous entries, flag specs whose Low count increased — accumulating Lows suggest the spec's public surface description is falling behind implementation growth.
This enables the SessionStart hook to report when drift was last checked.
