# Architecture Decision Records

## DEC-001: Discovery-Only Audit Skill (No Orchestrator)

**Date:** 2026-03-11
**Status:** Accepted
**Source:** docs/archive/plans/2026-03-11-wyx-audit-skill.md

### Context
wyx needed a way to assess spec coverage across a project and recommend which skills to run. Three approaches were debated: full orchestrator (auto-generates specs), condensed template orchestrator (70% reduced templates), and discovery-only scanner.

### Decision
Build `/wyx:audit` as a read-only discovery tool that scans for coverage gaps and outputs prioritized commands — it does not generate specs or modify files. `allowed-tools: Read, Glob, Grep` (no Write/Edit/Agent).

### Alternatives Considered
- **Full orchestrator**: Rejected — context window exhaustion, template drift across 5 skills, quality degradation from compressed context. Each skill needs full context to produce good specs.
- **Condensed templates**: Rejected — 70% template reduction produces hollow specs. Worse than no specs per the stale spec warning in CLAUDE.md.

### Consequences
- Cross-module information propagates through spec files, not shared context — each skill runs independently with full context
- Audit cannot become stale (no generated artifacts to drift)
- Users must run suggested commands manually — acceptable friction for quality
- Revisit if Claude Code adds skill-to-skill invocation

---

## DEC-002: SYNCS.md Does Not Stop Hook Traversal

**Date:** 2026-03-13
**Status:** Accepted
**Source:** docs/archive/superpowers/specs/2026-03-16-field-feedback-improvements-design.md

### Context
`drift-context.sh` walks upward from edited files and stops at the first directory with a boundary-contributing spec. SYNCS.md was originally treated as a traversal-stopping spec, but it contributes no boundary declarations (`## interactions`, `## dependencies`, `## data boundary`). When PIPELINE.md + SYNCS.md co-existed in a directory without CONCEPT.md, ancestor CONCEPT.md boundaries were silently dropped.

### Decision
Remove SYNCS.md from traversal stop logic. Only CONCEPT.md and PIPELINE.md stop traversal. SYNCS.md remains as documentation for drift detection but is invisible to hook traversal. Additionally, directories with SYNCS.md are no longer reported as "uncovered" in SessionStart.

### Alternatives Considered
- **Keep SYNCS.md as traversal stop**: Original behavior. Rejected — caused silent boundary loss when no co-located CONCEPT.md existed.
- **Report SYNCS.md dirs as uncovered**: Original v0.18.1 vote (2-1). Overridden by new evidence: v0.17.1 traversal fix and v0.18.6 boundary-section distinction created a meaningful split between "has spec" and "has boundary protection."

### Consequences
- SYNCS.md-only directories get zero boundary protection — acceptable because SYNCS.md documents coordination between concepts that should have their own specs
- SessionStart no longer trains users to ignore output by reporting spec'd directories as uncovered
- Revisit if adoption shows SYNCS.md rarely written — may merge into enriched `## interactions`

---

## DEC-003: Field Feedback — Fixes Not Features

**Date:** 2026-03-16
**Status:** Accepted
**Source:** docs/archive/superpowers/specs/2026-03-16-field-feedback-improvements-design.md

### Context
17 feedback items from 3 projects (DenkiOffice, WineLevel3, StockRecommendation) were triaged into 9 proposals for v0.19.0. The debate needed to decide scope: fix existing output problems vs. add new capabilities.

### Decision
Accept 4 proposals totaling ~21 lines of string template changes, zero logic changes. Every original proposal was modified through debate — zero shipped as proposed. Guiding principle: "fixes not features" — 4/5 accepted proposals fix existing output inconsistencies (command suggestions, stale status hint, SYNCS.md false positive). Only P1a+ (architecture-aware suggestions) is a genuine new capability.

### Alternatives Considered
- **JSONL schema changes (P2-original)**: Rejected — "JSONL is snapshot, not ledger." Out-of-band fixes are invisible to JSONL state. State management is scope creep.
- **--min-severity flag (P4-original)**: Rejected — interacts with the >5 Low accumulation advisory added 4 days prior. Validate existing mechanism before layering.
- **LLM-based Mermaid diffing (P5-original)**: Unanimously rejected — structural diffing of Mermaid by LLM is unreliable. `git diff` on deterministic output is always accurate.
- **Low collapse in drift report (P4-alt)**: Deferred — >5 Low rule and deduplication (both v0.18.6) need validation first. Revisit after 3+ drift scans across 3 projects.

### Consequences
- All changes are string templates — no regression risk to hook logic
- Consistent command suggestions across all 5 skills (was 3/7 before)
- Stale drift status is now self-documenting ("rerun to update")
- Low severity handling deferred — watch for evidence that >5 rule is insufficient

---

## DEC-004: Single Target Audience for README

**Date:** 2026-02-25
**Status:** Accepted
**Source:** docs/archive/plans/2026-02-25-public-appeal-design.md

### Context
wyx had 4 potential audiences: Claude Code daily users, LLM coding enthusiasts, architecture community, and researchers. The README attempted to serve all of them, resulting in unfocused messaging (appeal score: 5/10).

### Decision
README targets Claude Code daily users exclusively (3-0 agent consensus). Other audiences served via separate channels: blog post for enthusiasts/architects, docs/background.md for researchers.

### Alternatives Considered
- **Multi-audience README**: Status quo. Rejected — "4 audiences = 0 audiences" (Devil's Advocate). wyx is a Claude Code plugin; only Claude Code users can install it.

### Consequences
- README restructured as a landing page: tagline + diagram + before/after + install above the fold
- Blog post elevated to #2 strategic importance as primary discovery channel (marketplace has unknown discovery mechanics)
- Technical depth moved below the fold in `<details>` tags

---

## DEC-005: Lead with Bug Story, Not P-Values

**Date:** 2026-02-25
**Status:** Accepted
**Source:** docs/archive/plans/2026-02-25-public-appeal-design.md

### Context
wyx's test results include p=0.21 (feature-level, not significant) and p=0.024 (import-level, overstated independence). The "silent data loss bug" story (SQL UPDATE missing 2/5 fields) found during drift detection is more compelling.

### Decision
Lead evidence with the bug story and practical framing ("33 imports checked, 0 violations"). Move p-values and statistical caveats to a Test Results section below the fold (3-0 consensus).

### Alternatives Considered
- **Lead with statistics**: Rejected — p=0.21 is honest but self-defeating in a pitch context. Readers dismiss N=6 before reaching the qualitative evidence.

### Consequences
- Credibility depends on honest framing: "small sample" caveat inline with results
- Full methodology preserved below the fold for scrutiny
- Blog post uses the bug story as its opening hook

---

## DEC-006: Mermaid Diagram Over Demo GIF

**Date:** 2026-02-25
**Status:** Accepted
**Source:** docs/archive/plans/2026-02-25-launch-review-decision.md

### Context
The original public appeal plan called for a demo GIF showing boundary injection in action. However, boundary injection is invisible to users (it happens in hook context, not terminal output), making demonstration difficult. Claude's non-deterministic output also makes reproducible terminal recordings unreliable.

### Decision
Use Mermaid diagram for v1 (3-0 consensus). Shows the concept in 3 seconds, renders natively on GitHub, requires zero assets.

### Alternatives Considered
- **VHS terminal recording**: Planned as Step 3 of public appeal. Rejected — non-deterministic Claude output breaks reproducibility. A bad GIF is worse than no GIF.
- **Annotated screenshots**: Considered as fallback. Deferred to post-launch if needed.

### Consequences
- Zero-asset README — no external hosting or broken image links
- Concept communication limited to static flow diagram (no real-time demo)
- Screenshots/GIF deferred to post-launch if community requests

---

## DEC-007: "Enforces" Is an Overclaim — Use "Injects"

**Date:** 2026-02-25
**Status:** Accepted
**Source:** docs/archive/plans/2026-02-25-launch-review-decision.md

### Context
Launch materials used "enforces" and "prevents" (~10 locations) to describe wyx's behavior. wyx injects boundary context; Claude voluntarily respects it. The distinction matters for credibility, especially on HN and r/programming.

### Decision
Replace all "enforces/prevents" language with "injects" or "checks against." wyx provides context-only enforcement — the LLM self-checks, it cannot mechanically block violations.

### Alternatives Considered
- **Keep "enforces" with footnote disclaimer**: Rejected — readers skim; the overclaim lands, the disclaimer doesn't.

### Consequences
- Messaging is technically accurate but less punchy
- Builds trust with skeptical developer audiences
- README tagline settled on "injects them into Claude's context" rather than "enforces boundaries"

---

## DEC-008: Known Coupling — Phase 1 Format and Calibration Only

**Date:** 2026-03-21
**Status:** Accepted
**Source:** docs/archive/superpowers/specs/2026-03-21-v0.20.0-known-coupling-multilang-drift-design.md

### Context
2/3 field-tested projects (DenkiOffice and WineLevel3) independently invented ad-hoc sections for documenting intentional cross-concept data access (`## boundary exceptions`, direct SQL writes). The pattern was real but unstandardized — each project formatted it differently, and drift detection treated documented and undocumented coupling identically (both Critical severity).

### Decision
Standardize `## known coupling` as an optional CONCEPT.md section with a prescribed format (resource, access pattern, reason, resolution status). Phase 1 includes format definition and drift calibration only — documented coupling = Low severity, undocumented = Critical. Hook injection (extracting known coupling into boundary context) deferred to Phase 2.

### Alternatives Considered
- **Hook injection in Phase 1**: Would immediately surface coupling in boundary context during edits. Rejected — insufficient adoption data (N=3 projects) to justify hook complexity. Phase 2 condition: 5+ entries across 2+ projects.
- **`:::coupling` classDef in Mermaid maps**: Visual representation of coupling in architecture diagrams. Deferred — depends on Phase 2 hook injection.
- **No standardization**: Let each project invent its own format. Rejected — 2/3 independent invention signals a real pattern; inconsistency prevents calibration rules.

### Consequences
- Drift calibration now distinguishes documented vs undocumented coupling (Low vs Critical)
- Phase 2 has explicit trigger condition — prevents premature hook complexity
- Known coupling section is explicitly "structural necessities, not a tech debt parking lot"
- Prevention gap (forgotten spec updates) remains unresolved — all 3 projects report it, but no clean solution within current hook architecture (PostToolUse rejected for hook fatigue, CI for LLM cost)

---

## DEC-009: Multi-Language Drift — Documentation Over Tooling

**Date:** 2026-03-21
**Status:** Accepted
**Source:** docs/archive/superpowers/specs/2026-03-21-v0.20.0-known-coupling-multilang-drift-design.md

### Context
StockRecommendation project had an `exit_reason` enum mismatch between its Rust CLI and TypeScript frontend, caught during drift detection. The question was whether drift tooling needed language-specific awareness or multi-language scanning logic.

### Decision
Add a 2-line documentation note to drift-detection.md explaining that drift detection is language-agnostic (Claude reads Rust, Python, Go, etc.) and multi-language projects should scope drift checks to all implementation directories. No tooling changes.

### Alternatives Considered
- **Language-specific scanning logic**: Multi-language file discovery and cross-referencing. Rejected — LLM-based drift already handles any language natively. The gap is user awareness, not tooling capability.

### Consequences
- Zero code change — documentation fix only
- Users in multi-language projects must manually scope drift checks or colocate specs per language directory
- If cross-language enum mismatches recur despite documentation, revisit with automated cross-directory scanning

---

## DEC-010: Hook Architecture Frozen — No Expansion Beyond PreToolUse Context Injection

**Date:** 2026-03-21 (consolidation of decisions from v0.17 through v0.21)
**Status:** Accepted
**Source:** MEMORY.md debate records: v0.17 Improvement (2026-03-10), v0.20.0 Field Feedback (2026-03-21), v0.21 Field Feedback (2026-03-21)

### Context
Across 4 debate rounds (v0.17, v0.17.1, v0.20.0, v0.21), 6 proposals attempted to expand wyx's hook architecture beyond the current PreToolUse context injection. Each was independently rejected by agent teams (3-6 agents per debate, all Opus).

### Decision
wyx's hook architecture is limited to PreToolUse context injection (Write/Edit/NotebookEdit matcher). No additional hook types, no static analysis, no CI integration, no multi-IDE support. The architecture is frozen at current maturity (N=3 projects, 1 developer).

### Alternatives Considered
- **Static import analysis in PreToolUse hook** (v0.17, DA 9/10): PreToolUse fires *before* the write — disk file is stale, so import analysis reads the previous version. Multi-language regex is brittle. The LLM already performs import analysis better than shell scripts. Fatal timing flaw.
- **Pre-commit hook for drift** (v0.17): Drift detection requires LLM invocation (comparing spec against code semantics). Git hooks cannot invoke Claude. Pre-commit is architecturally incompatible with LLM-based drift.
- **PostToolUse hooks** (v0.20.0: all 2/2/2, upheld v0.21: all 2/2/2): Doubles hook surface area. PreToolUse assumes spec is authoritative; PostToolUse assumes it might be stale — contradictory signals in the same edit cycle. Also causes hook fatigue (user sees both pre and post messages per edit). Structural rejection — not revisitable without fundamental rethink.
- **Multi-IDE support** (v0.17): wyx is deeply coupled to the Claude Code plugin API (PreToolUse events, hookSpecificOutput.additionalContext, SKILL.md format). Supporting other IDEs would be a different product, not a feature addition.
- **Plugin agents** (rejected 3 times: 2026-02-16, 02-17, 03-10): Agent hooks add 10-30s latency per edit. Isolated agent context is net-negative — agents cannot read the conversation context that makes boundary declarations actionable.
- **CI drift integration** (v0.20.0): Drift detection requires LLM invocation — running Claude in CI hits cost and infrastructure barriers ("LLM wall"). Automating drift in CI transforms a plugin into a platform dependency.

### Consequences
- Prevention gap between per-edit hooks and manual drift remains unresolved — all 3 projects feel it
- Any future hook expansion requires: (1) new Claude Code platform capability, or (2) fundamental architecture change
- PostToolUse is a structural rejection — not deferral. Won't be revisited at N=10
- Revisit if Claude Code adds session-level hook state or non-LLM drift detection becomes feasible

---

## DEC-011: Audit Scope — Read-Only Discovery with No Generated Artifacts

**Date:** 2026-03-15 (consolidation of decisions from v0.18.1 through v0.21)
**Status:** Accepted
**Source:** MEMORY.md debate records: Audit Evolution (2026-03-15), v0.21 Field Feedback (2026-03-21)

### Context
After `/wyx:audit` shipped as a read-only scanner (DEC-001), 5 proposals across 2 debates attempted to expand its scope to include generated artifacts, persistent state, or analysis that duplicates existing capabilities.

### Decision
`/wyx:audit` remains read-only (`allowed-tools: Read, Glob, Grep`). It does not write files, track history, or duplicate analysis available in SessionStart or `/wyx:concept drift`.

### Alternatives Considered
- **ARCHITECTURE.md staleness check in audit** (v0.18.6, all 2/2/2): Exact duplicate of session-start.sh lines 103-111. Adding the same check to audit creates two sources of truth with no additional value.
- **CLAUDE.md cross-reference validation** (v0.18.6, 3/2/2): Checking if CLAUDE.md prose references match actual specs requires free-form prose parsing — too brittle. False positives from partial matches or paraphrased descriptions would erode trust.
- **Audit history JSONL** (v0.18.6, 2/2/2): Writing audit results to JSONL violates the v0.18.1 design constraint (Write excluded from allowed-tools). No consumer exists for the data — generating artifacts without consumers creates maintenance burden.
- **Audit cache** (v0.21, C6): Write is not in audit's allowed-tools by design. Adding it would break the structural scope-creep prevention that makes audit trustworthy as a read-only tool.
- **Drift history trend analysis** (v0.18.6, 7/4/3 → DEFER/REJECT): 60% functional overlap with SessionStart's existing drift reporting. N=1 project validation is insufficient for a trend analysis feature. Revisit at N=10+ projects.

### Consequences
- Audit cannot become stale (no generated artifacts to drift) — preserving DEC-001's key benefit
- Users who want persistent tracking use `/wyx:concept drift` (which writes to JSONL by design)
- SessionStart and audit have clean separation: SessionStart = smoke detection, audit = coverage analysis
- DA meta-question stands: "When a tool reports 'nothing to do', the correct response is 'congratulations' — not 'let me find something to report.'"

---

## DEC-012: SessionStart Is Smoke Detection, Not Intelligence

**Date:** 2026-03-13
**Status:** Accepted
**Source:** MEMORY.md debate record: Field Test Improvements (2026-03-13)

### Context
After audit shipped (v0.18.1), 2 proposals attempted to add LLM-level intelligence to the SessionStart shell hook — evaluating module behavioral cohesion and detecting "retained for future use" code patterns.

### Decision
SessionStart remains a shell-based smoke detector: file counting, mtime comparison, spec existence checks. LLM-level judgment belongs in `/wyx:audit` (which runs in Claude's context). The two-tier architecture (SessionStart = fast/dumb, audit = slow/smart) is correct.

### Alternatives Considered
- **Behavioral cohesion evaluation in SessionStart** (v0.18.1, 2/2/3): Shell scripts cannot perform LLM judgment. Evaluating whether a directory has "state + actions + operational principle" requires understanding code semantics — this is exactly what `/wyx:audit` does in Claude's context. Wrong layer for the task.
- **"Retained for future use" drift flagging** (v0.18.1, 2/3/2): Detecting unused code patterns in shell is unreliable (requires parsing imports, understanding call graphs). This is not drift detection — it's dead code analysis, which is scope creep. Even if detectable, flagging it in SessionStart output creates noise for a rare edge case.

### Consequences
- SessionStart stays fast (~35ms worst case) — no LLM invocation, no complex analysis
- Clean handoff: SessionStart flags "you have uncovered modules" → user runs `/wyx:audit` for details
- Debate insight applied: "Hook-script sync is itself a drift problem" — keeping SessionStart simple reduces drift surface

---

## DEC-013: Feature Proposals Rejected at Current Maturity (N=3, 1 Developer)

**Date:** 2026-03-21 (consolidation of rejections from v0.20.0 and v0.21)
**Status:** Accepted
**Source:** MEMORY.md debate records: v0.20.0 Field Feedback (2026-03-21), v0.21 Field Feedback (2026-03-21)

### Context
Across v0.20.0 (14 proposals) and v0.21 (23 proposals), a combined 16 feature proposals were rejected. While each had individual technical reasons, they share a common strategic principle: at N=3 projects with 1 developer, feature additions have negative expected value. The bottleneck is adoption breadth, not feature depth.

### Decision
Reject all feature-depth proposals that don't fix existing bugs or output problems. Strategic investment goes to adoption (4th project, 2nd developer) before new capabilities.

### Alternatives Considered
- **Type contracts in specs** (v0.20.0): Duplicates what TypeScript's compiler already checks. Adding type validation to specs creates a parallel system that must stay in sync with `tsconfig.json` — maintenance cost with no incremental benefit.
- **Export diff for map changes** (v0.20.0): False positive rate too high. Mermaid output differences from whitespace, ordering, or LLM non-determinism would generate noise. `git diff` on deterministic output (ensured by 7 stability rules) is already accurate.
- **Ghost detection via git diff** (v0.20.0): Detecting deleted-but-still-referenced code. `git diff` already provides this hint — building tooling around it adds complexity for a use case users can solve with existing git commands.
- **Layer concept in specs** (v0.20.0): Architectural layering abstraction. Only validated on N=1 project — insufficient evidence that the abstraction generalizes. Risk of imposing structure that doesn't fit other codebases.
- **Common parameter detection** (v0.20.0): Detecting shared parameters across concepts for extraction. Already exists as Retrofit step 6 in concept/SKILL.md — duplicate proposal.
- **Change summary in drift output** (v0.20.0): Re-litigates the v0.19.0 "fixes not features" decision (DEC-003). Change summaries were considered and rejected in that round.
- **Operational principle → test generation** (v0.20.0): Generating tests from CONCEPT.md operational principles. Scope creep — wyx produces specs, not test suites. Stale operational principles would generate wrong tests, amplifying the stale spec risk (worse than no tests).
- **2-pass verification for drift** (v0.21, A4): Running drift twice to reduce false positives. Existing calibration rules (Low deduplication, >5 Low advisory, naming convention = Low) are sufficient. A second pass doubles drift scan time for marginal accuracy gain.
- **Structural parsing for drift** (v0.21, B6): Parsing AST structure instead of LLM-based comparison. This is a feature, not a fix — and N=3 projects provide insufficient evidence that LLM-based drift is inadequate. Adding a parser creates a language-specific dependency that contradicts the language-agnostic design.
- **Known gaps lifecycle tracking** (v0.21, C4): Tracking `## known gaps` entries through resolution. Deletion of resolved gaps is sufficient — lifecycle tracking adds state management complexity with no clear consumer.
- **Systemic drift suppression** (v0.21, C1): Auto-suppressing drift findings seen N=3+ times. Deferred — pattern needs more data across projects to avoid masking real drift.
- **Agent grouping optimization** (v0.21, C8): Batching Explore agent calls for efficiency. Deferred — requires N=2+ concurrent users to validate that agent overhead is the actual bottleneck.
- **Premature proposals** (v0.21, C9/C10/C11): Various incremental features without clear problem statements. Rejected as premature — no evidence of user need.

### Consequences
- wyx feature set frozen at v0.21.1 for foreseeable future — next investment is adoption
- Each rejection documented with specific downside, enabling future re-evaluation when conditions change
- "N=10" and "2+ developers" serve as revisit triggers for deferred proposals (PM lowered B8 from N=10 to N=5)
- DA insight stands: "Most valuable investment is 4th project adoption, not feature depth"
