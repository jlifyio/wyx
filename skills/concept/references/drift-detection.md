# Drift Detection Procedure

When `$ARGUMENTS` starts with `drift`, scan for spec-code divergence.

## How it works

1. **Find all specs**: Locate all `CONCEPT.md`, `PIPELINE.md`, and `SYNCS.md` files in the target path (or entire project if no path given). When scoped to a path, also search for dependent specs outside the scope: walk upward from the target path for ancestor specs, and find any `SYNCS.md` or `PIPELINE.md` elsewhere that reference concepts within the target path. This ensures cross-spec validation remains complete even in scoped mode.
2. **For each spec**: Read the spec AND the corresponding implementation code
3. **Compare**: Check for divergence in each category (see below)
4. **Report**: Produce a structured drift report

**Multi-language projects**: When a concept has implementations in multiple languages, scope the drift check to include all relevant directories, or colocate a CONCEPT.md near each language's implementation. Drift detection is language-agnostic — Claude reads any language.

## Parallel scanning

When 5+ specs are found, use `Agent` with `subagent_type: "Explore"` to scan specs in parallel. Explore agents are read-only (Write/Edit structurally unavailable) — safe for drift analysis. (The threshold is lower than `/wyx:map`'s 10+ because drift agents read both spec AND implementation per task; the heavier per-task work amortizes agent-spawn overhead at lower N.)

- Spawn one Explore agent per spec (or group of 2-3 nearby specs)
- Each agent reads the spec + implementation code and returns findings in the drift report format (category, severity, file:line, description)
- After all agents complete, merge findings into a single drift report, then run cross-spec validation and systemic pattern aggregation in the main context

### Agent output requirements

Each agent must output a verdict for every applicable check category (e.g., "Missing action: ✓ clean", "Changed signature: Low — naming convention"). Omitted categories are flagged as "unverified" during the merge step.

### Agent prompt template

When spawning Explore agents for parallel drift scanning, include this in each agent prompt:

1. The assigned spec paths and their types (CONCEPT/PIPELINE/SYNCS)
2. The full "Drift calibration" block from this document (verbatim)
3. The relevant check table(s) for the assigned spec types — **severity values are authoritative; agents must copy them verbatim and must not escalate on their own judgment**
4. Output requirement: verdict for every check category — omitted = unverified

## What to check for each CONCEPT.md

| Category | How to detect | Severity |
|----------|--------------|----------|
| **Missing action** | Function/method exists in code but not declared in spec `## actions` | **Medium** |
| **Removed action** | Action declared in spec but function no longer exists in code | **High** |
| **Changed signature** | Function parameters and/or return type differ from spec declaration — trace actual return statements, not just type annotations | **Medium** |
| **New state** | New table column, class field, or persistent data not in spec `## state`. Also verify persistent storage definitions (schema files, migrations) for state not reflected in spec or application types | **Medium** |
| **New dependency** | Import from a concept not listed in spec `## dependencies` | **High** |
| **Boundary violation** | Direct import of another concept's internals (not through declared actions) | **Critical** |
| **Cross-cutting parameter** | A parameter appears in 3+ action implementations but is not documented in any action signature in `## actions` | **Medium** |
| **Resolved known gap** | If spec contains a `## known gaps` section, check whether any documented gaps have been resolved by existing code | **Low** |
| **Resolved known coupling** | A `## known coupling` entry with `status: refactor` no longer exists in code (coupling removed via grep-verifiable absence of the declared access pattern) — spec should be updated to reflect the resolution | **Low** |

## What to check for each PIPELINE.md

| Category | How to detect | Severity |
|----------|--------------|----------|
| **Missing stage** | New transformation step in code not declared in spec `## stages` | **Medium** |
| **Changed invariant** | Code logic contradicts a declared invariant | **High** |
| **New data source** | Code reads from table/API not listed in spec `## sources` | **Medium** |
| **Boundary violation** | Direct DB import for data owned by another concept | **Critical** |

## What to check for each SYNCS.md

| Category | How to detect | Severity |
|----------|--------------|----------|
| **Missing sync** | New cross-concept coordination in code not declared in spec | **Medium** |
| **Changed timing** | Code uses different trigger pattern (e.g. scheduled vs post-action) than spec declares | **Medium** |
| **New participant** | Sync handler involves a concept not listed in the spec | **High** |
| **Removed sync** | Sync declared in spec but handler no longer exists in code | **High** |
| **Graph inconsistency** | `## coordination graph` lists a sync flow not defined in any `## sync:` block, or vice versa | **Medium** |
| **Missing SYNCS coverage** | A CONCEPT.md `## interactions` declares a coordination relationship but no corresponding sync exists in any SYNCS.md | **Medium** |

## Drift calibration

- When the spec uses a simpler signature than the implementation's language-specific type wrapper (e.g., async wrappers, result/error types), treat the discrepancy as Low unless it changes the error handling or calling contract.
- State fields that are implementation details (private variables, internal caches, derived computed values) rather than part of the concept's public API contract should be flagged as Low severity.
- Private helper methods or internal implementation functions (not exported, not called from outside the module) that appear as "Missing action" findings should be treated as Low severity — these are implementation details, not part of the concept's public API contract.
- Naming convention differences between spec and code (camelCase vs snake_case, abbreviated vs full names) are Low severity — style issues, not contract violations. Exception: if the divergent name appears in cross-spec references (PIPELINE.md or SYNCS.md), this is **not** a within-category escalation but a **reclassification** into a cross-spec validation category (`PIPELINE→CONCEPT name mismatch` or `SYNCS→CONCEPT missing reference`, both High in the cross-spec table below).
- When the same Low finding repeats across multiple actions in one spec (e.g., same undocumented parameter in 3+ actions), count as a single Low with a note listing affected actions. Deduplicated Lows count as 1 in the `low_by_spec` JSONL field.
- Before reporting a finding as Medium or higher, verify it exists in the current code with grep or file read. Do not report drift based on memory or assumptions from prior file reads.
- If a single spec accumulates more than 5 Low findings (after deduplication), note this in the drift report summary and suggest re-evaluating whether the spec's `## actions` or `## state` adequately describes the module's current public surface.
- Cross-concept data access documented in the source concept's `## known coupling` section should be treated as Low severity rather than Critical/High. Undocumented cross-concept data access remains Critical.
- **Use check-table severity verbatim.** The severity values in the check tables are calibrated — do not promote Low to Medium, or Medium to High, based on independent judgment about impact. If a finding is more severe than its initial category suggests, **reclassify it into the correct check category** (e.g., a "Missing action" finding that is actually cross-concept internal access → "Boundary violation" at Critical). Do not escalate severity within a category; only downward adjustments via the calibration rules above (e.g., private helper → Low, naming convention → Low) are allowed.

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
| **PIPELINE→CONCEPT name mismatch** | A PIPELINE.md `## stages` or `## data boundary` references a concept action name that doesn't match any declared action in the target CONCEPT.md `## actions` | **High** |
| **SYNCS→CONCEPT missing reference** | A SYNCS.md sync block references `Concept.action` where the action doesn't exist in the target CONCEPT.md | **High** |
| **SYNCS→CONCEPT missing participant** | A SYNCS.md sync block names a concept that has no corresponding CONCEPT.md | **Medium** |
| **CONCEPT→CONCEPT missing action** | `## interactions` references `OtherConcept.actionName()` (explicit method-call syntax only) but action doesn't exist in target CONCEPT.md `## actions` | **High** |
| **CONCEPT→CONCEPT missing concept** | `## dependencies` references a concept name with no corresponding CONCEPT.md | **Medium** |

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
   For each finding, briefly note whether the spec or the code appears more current, to help the user decide the fix direction (update spec vs fix code).
3. When findings indicate structural issues (boundary violations, state overlap,
   cross-cutting patterns), note which Design Rule (1-5) applies and suggest the
   appropriate wyx command — whether updating an existing spec or creating a new one
   (`/wyx:concept`, `/wyx:pipeline`, `/wyx:sync`, `/wyx:audit`).
4. After the summary, add a "Suggested next steps" line listing the highest-priority
   wyx commands to address the findings (e.g., `/wyx:concept path/` for specs with
   drift, `/wyx:audit` if uncovered modules were noted).
5. If uncovered modules were observed during scanning, suggest: "Run `/wyx:audit` to
   check overall spec coverage."

**Phase 2 — Fix (user-approved writes):**
6. If updating spec: generate the specific minimal edits needed, then apply after user confirmation
7. If code bug: flag for fixing (the spec is the intended contract)
8. If spec changes were applied and `ARCHITECTURE.md` exists, remind the user: "Specs updated — run `/wyx:map` to regenerate ARCHITECTURE.md."

**Phase 3 — Record drift history:**
9. Append a detect entry to `.claude/wyx-drift-history.jsonl`:
```json
{"ts":"<ISO-8601>","action":"detect","specs_scanned":<N>,"specs_with_drift":<N>,"critical":<N>,"high":<N>,"medium":<N>,"low":<N>,"low_by_spec":{"path/CONCEPT.md":<N>},"path":"<scanned-path-or-project>"}
```
The `action` field distinguishes detect entries from fix entries (see step 10). Entries without an `action` field are treated as `"detect"` for backward compatibility. The `low_by_spec` field tracks per-spec Low counts for accumulation trending. When comparing against previous entries, flag specs whose Low count increased — accumulating Lows suggest the spec's public surface description is falling behind implementation growth. The detect entry enables the SessionStart hook to report when drift was last checked.

10. **After applying fixes in the same session** (Phase 2), append a fix entry referencing the detect entry:
```json
{"ts":"<ISO-8601>","action":"fix","specs_fixed":<N>,"specs_remaining":<N>,"ref_ts":"<detect-entry-ts>"}
```
- `specs_fixed`: number of specs resolved in this fix pass
- `specs_remaining`: specs still drifting (detect `specs_with_drift` minus the specs fixed); `0` means the drift is fully resolved
- `ref_ts`: `ts` of the **most recent detect** entry — the one this fix is resolving (ties fixes back to their originating scan)

JSONL is append-only — never edit prior entries. The SessionStart hook reads the latest entry: if `action=fix`, it reports `specs_remaining` instead of the older `specs_with_drift`, so the session header reflects the true pending count rather than stale detection numbers.

**Snapshot semantics (v0.17 invariant).** Each entry is a snapshot, not a ledger. A fresh `detect` entry supersedes any prior `fix` entry's `specs_remaining` — SessionStart reads only the latest entry, so the newly measured `specs_with_drift` replaces prior pending state. If a `fix` pass only resolves some specs and the user later rescans, the new `detect` is the authoritative count; the hook does not walk backward to combine detect/fix pairs.
