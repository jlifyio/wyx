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
**Status:** Partially superseded by DEC-014
**Source:** MEMORY.md debate records: v0.17 Improvement (2026-03-10), v0.20.0 Field Feedback (2026-03-21), v0.21 Field Feedback (2026-03-21)

### Context
Across 4 debate rounds (v0.17, v0.17.1, v0.20.0, v0.21), 6 proposals attempted to expand wyx's hook architecture beyond the current PreToolUse context injection. Each was independently rejected by agent teams (3-6 agents per debate, all Opus).

### Decision
wyx's hook architecture is limited to PreToolUse context injection (Write/Edit/NotebookEdit matcher). No additional hook types, no static analysis, no CI integration, no multi-IDE support. The architecture is frozen at current maturity (N=3 projects, 1 developer).

### Alternatives Considered
- **Static import analysis in PreToolUse hook** (v0.17, DA 9/10): PreToolUse fires *before* the write — disk file is stale, so import analysis reads the previous version. Multi-language regex is brittle. The LLM already performs import analysis better than shell scripts. Fatal timing flaw.
- **Pre-commit hook for drift** (v0.17): Drift detection requires LLM invocation (comparing spec against code semantics). Git hooks cannot invoke Claude. Pre-commit is architecturally incompatible with LLM-based drift.
- **PostToolUse hooks** (v0.20.0: all 2/2/2, upheld v0.21: all 2/2/2): Originally rejected — "contradictory signals" argument claimed PreToolUse assumes spec is authoritative while PostToolUse assumes it might be stale. **Overturned in v0.22.0** (see DEC-014): the "contradictory signals" framing was a false dichotomy. PreToolUse=guidance, PostToolUse=verification is complementary.
- **Multi-IDE support** (v0.17): wyx is deeply coupled to the Claude Code plugin API (PreToolUse events, hookSpecificOutput.additionalContext, SKILL.md format). Supporting other IDEs would be a different product, not a feature addition.
- **Plugin agents** (rejected 3 times: 2026-02-16, 02-17, 03-10): Agent hooks add 10-30s latency per edit. Isolated agent context is net-negative — agents cannot read the conversation context that makes boundary declarations actionable.
- **CI drift integration** (v0.20.0): Drift detection requires LLM invocation — running Claude in CI hits cost and infrastructure barriers ("LLM wall"). Automating drift in CI transforms a plugin into a platform dependency.

### Consequences
- Prevention gap between per-edit hooks and manual drift partially addressed by PostToolUse context reinforcement (DEC-014)
- Any future hook expansion requires: (1) new Claude Code platform capability, or (2) fundamental architecture change
- PostToolUse structural rejection **overturned** in v0.22.0 — see DEC-014
- Static import analysis, pre-commit, CI drift, multi-IDE, and plugin agents rejections still stand

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
- wyx feature set frozen at v0.21.1 for foreseeable future — next investment is adoption (note: PostToolUse context reinforcement added in v0.22.0 per DEC-014, overturning the PostToolUse rejection in DEC-010)
- Each rejection documented with specific downside, enabling future re-evaluation when conditions change
- "N=10" and "2+ developers" serve as revisit triggers for deferred proposals (PM lowered B8 from N=10 to N=5)
- DA insight stands: "Most valuable investment is 4th project adoption, not feature depth"

---

## DEC-014: PostToolUse Context Reinforcement — Overturning the "Contradictory Signals" Rejection

**Date:** 2026-03-22
**Status:** Accepted (supersedes PostToolUse rejection in DEC-010)
**Source:** MEMORY.md debate record: PostToolUse Debate (2026-03-22, 3-agent debate: ADV+ARCH+DA, Opus)

### Context
PostToolUse hooks were rejected twice (v0.20.0 and v0.21.0, all 2/2/2) based on the "contradictory signals" argument: PreToolUse assumes spec is authoritative while PostToolUse assumes it might be stale. In v0.22.0, all three debate agents independently withdrew this argument after recognizing it as a false dichotomy.

### Decision
Add a PostToolUse hook (~90 lines) that reinjects the `## dependencies` list from the nearest CONCEPT.md after each file edit. The hook is language-agnostic — no import parsing, no language-specific code. Silent when: no spec found, no `## dependencies` section, editing inert files, or editing spec files themselves. PreToolUse provides full boundary context before the edit (guidance); PostToolUse provides the dependency list after (verification prompt). New architectural principle: **"hooks extract and inject; the LLM judges."**

### Alternatives Considered
- **Import-checking PostToolUse** (v0.22.0 debate, 3/3/6 ARCH, 5/5/4 DA): Concept-name-to-import-path mapping has no clean bash solution. Language-specific code violates wyx's language-agnostic principle. ADV iterated the design 3x through debate pressure before arriving at context reinforcement.
- **No PostToolUse** (v0.20.0/v0.21.0 status quo): The "contradictory signals" rejection was a false dichotomy — guidance before and verification after are complementary, not contradictory. The previous DA attacked the concept instead of the mechanism.

### Consequences
- wyx now has 3 hooks: SessionStart + PreToolUse + PostToolUse (was 2)
- Prevention gap partially addressed — PostToolUse prompts the LLM to verify its edit against declared dependencies
- Hook fatigue risk mitigated by silent-on-clean design (PostToolUse only outputs when a CONCEPT.md with dependencies exists nearby)
- DA self-correction recorded: "Previous DA should have challenged the MECHANISM, not the CONCEPT. A DA's job is precision, not obstruction."

## DEC-015: Drift Detection Wording — Sanctioned Coupling, Project Conventions, Per-File Cohesion

**Date:** 2026-05-02
**Status:** Accepted
**Source:** Field feedback from two operating sessions (yorisen, aofuda) + 3-agent debate (field-voice/principle-guardian/devils-advocate, Opus)

### Context
Two field-operating sessions surfaced three drift-detection failure modes:
1. Drift agents recurringly flag `OtherConcept.publicAction()` calls as Critical "Boundary violation" despite the existing "(not through declared actions)" qualifier — observed 4+ times in `.claude/wyx-drift-history.jsonl` across multiple sessions.
2. Per-spec parallel agents miss cross-cutting parameter additions (e.g., `tenant: string` multi-tenant scoping) when only 2/N specs catch the pattern — Step 3 systemic pattern aggregation requires 3+ specs to fire, leaving 2-vs-2 cases as silent gaps.
3. Retrofit of mixed-cohesion directories (concept-shaped file + infrastructure siblings) defaults to one bloated spec covering all files — existing Retrofit Mode Guidelines check cross-CONCEPT.md overlap but not within-directory cohesion.

### Decision
Three minimal wording additions, no new sections or mechanisms:
1. **Sanctioned coupling line** in `drift-detection.md` calibration block: `Sanctioned coupling: invoking another concept's declared actions through their public API (including from SYNC handlers) is not a boundary violation.`
2. **Project conventions item** in `drift-detection.md` agent prompt template (item 4): instructs Explore agents to read project `CLAUDE.md` / `AGENTS.md` and treat undocumented appearances of documented cross-cutting params as Medium "Cross-cutting parameter" findings even at single-spec scope.
3. **Per-file cohesion sentence** in `concept/SKILL.md` Retrofit step 4: `If the directory contains a mix of concept-shaped files (with state ownership and lifecycle) and infrastructure files (stateless utilities, type definitions, schemas), spec only the concept-shaped subset and list infrastructure as ## dependencies, not as concept subjects.`

Total delta: 4 lines added across 2 files. No new sections. No language-specific code. No conflict with existing "language-agnostic, hooks extract; the LLM judges" principles.

### Alternatives Considered
- **Add Step 4 cross-cutting signature sweep** (yorisen original proposal): Rejected. Original proposal included TypeScript-specific grep (`grep "db: Sql,"`) violating language-agnostic principle. Opt-in/language-neutral compromise (field-voice + principle-guardian convergence) was further rejected because DA identified it as redundant with existing line 45 (Cross-cutting parameter check) and lines 134-144 (Systemic pattern aggregation). Real cause is per-spec agents not consulting project conventions — fixed by item 2 above instead.
- **Add new Retrofit step 9 (per-file scope rule)** (yorisen original proposal): Rejected. Existing Retrofit step 4 (state ownership) is the natural insertion point. New step 9 would push the guideline list to 9 steps with diminishing returns.
- **Lower systemic pattern aggregation threshold from 3+ to 2+ specs**: Rejected. Field-voice tested in own project: `db:Sql` first-param is intentionally project-wide, threshold 2 would produce 17/17 false positives.
- **DA's transitive boundary leak addition** to #1: Rejected. Theoretically sound (a sanctioned action's implementation re-importing internals is a separate violation) but rarely material in practice; complicates the rule for marginal benefit.

### Consequences
- Drift agents reclassify public-action calls correctly — false positives observed in drift-history should drop.
- Cross-cutting parameter detection improves at single-spec scope when project documents the convention (e.g., wyx CLAUDE.md, yorisen CLAUDE.md L79).
- Retrofit avoids over-inclusive specs in mixed-cohesion directories (e.g., `db/tenant.ts` is concept, `db/client.ts/schema.ts` are dependencies).
- Validates the "minimal wording > new sections" pattern: the original yorisen proposals were 3 substantial additions; the accepted form is 4 lines total. Future field feedback should default to wording fixes before structural changes.
- Confirms 3-agent debate value: field-voice + principle-guardian converged on a wrong answer (#2 opt-in Step 4) that DA overturned via redundancy critique. Two-agent symmetry is insufficient.

## DEC-016: Post-Fix Drift Re-Scan — Documentation Over Mechanism

**Date:** 2026-05-30
**Status:** Accepted
**Source:** User report ("does the drift warning sometimes not clear?") + 3-agent debate (architect/minimalist/devils-advocate, Opus) with lead synthesis and independent file verification

### Context
The SessionStart "Specs modified since last drift check" reminder (`session-start.sh:117-125`) is mtime-based and anchors find-newer on the last **detect** entry's `ts` — never the JSONL file mtime, never the fix `ts` (the v0.21.0 false-positive came from using file mtime). Three reliability gaps were raised:
1. **③ post-fix re-fire**: after a detect+fix in one session, the just-fixed spec's mtime exceeds `detect_ts`, so the reminder re-fires next session. This is the v0.17/v0.21 invariant working as designed (`session-start.sh:107-117`: "a fix entry is a mid-workflow marker, not a new measurement").
2. **① history-append skip**: the `.jsonl` append (drift-detection.md Phase 3, steps 9-10) is an LLM-manual step; if skipped, the reminder never refreshes.
3. **② closing cannot verify the append** — out of scope (workflow-kit's `closing`, a separate plugin); handed off via a maintainer prompt, not addressed here.
User asked to "improve all in wyx." Debate concluded that most of "all" should NOT be done.

### Decision
**One optional documentation paragraph** in `drift-detection.md` Phase 3 (after the append-only note, before "Snapshot semantics"). It documents the honest recovery — re-run `/wyx:concept drift` to write a fresh `detect` anchor whose ts post-dates the fixes — and carries a **no-fabrication guardrail (MUST)**: never hand-write a `detect` entry with `specs_with_drift: 0` without re-measuring. Zero script edits, zero new files. Gap ① = no change (true-zero).

### Alternatives Considered
- **③-A: re-anchor find-newer on fix `ts` when `specs_remaining=0`** (`session-start.sh`): Rejected (unanimous). `specs_remaining` is an LLM-reported integer (drift-detection.md:181); anchoring on it to *suppress* the warning converts a benign false-positive (a nag) into a dangerous false-**negative** (hidden drift = the stale-spec failure mode, wyx's named worst case) whenever the LLM under-counts. Also re-opens the v0.21.0 invariant.
- **③-B: append a post-fix `detect` entry with `specs_with_drift: 0`**: Rejected (unanimous, independently derived by all three). Either it means re-running the full scan (= the 2-pass drift already rejected in DEC-013 A4) or writing `detect: 0` without re-scanning (= fabricating a measurement that never ran, poisoning the append-only record and `low_by_spec` trend, and silencing both drift signals when untouched specs still drift). The surviving doc note explicitly forbids this as the user-facing footgun.
- **`scripts/record-drift.sh` helper for ①**: Rejected (unanimous). A *writing* helper inverts "hooks extract and inject; the LLM judges" (DEC-014); a 4th script is DEC-013 feature-depth plus DEC-012's "hook-script sync is itself a drift problem"; and the read side already degrades gracefully on malformed JSONL (`session-start.sh:78-95`). The LLM must still remember to call it — zero gain on the root cause.
- **Re-bold Phase 3 step 9 ("append is required")**: Rejected as theater. The premise of ① is that the step is skipped; strengthening an already-imperative step has zero behavioral delta. Gap ① is also hypothetical (no `wyx-drift-history.jsonl` in-repo, no field-observed skip) and self-healing (a skipped append recovers on the next scan; `suggest_drift` stays true meanwhile, so drift is never hidden) — under DEC-013 it earns no edit.

### Consequences
- Net change: 1 documentation paragraph; the drift mechanism, hooks, and scripts are untouched. Respects DEC-010/012/013/014/015 and the detect_ts invariant.
- The guardrail's value is forward-looking footgun-prevention (a future contributor "fixing" ③ via synthetic `detect: 0` would inject silent masked drift), not a workflow nag the LLM must obey — an optional re-run skipped by the LLM fails safe (③ re-fires harmlessly, self-clears on the next real detect).
- The note is written to describe the reminder by behavior, not by quoting `session-start.sh`'s exact string, so it does not couple `drift-detection.md` to the hook's wording (avoids the meta-drift the change would otherwise introduce).
- Lead-verifies-agent-output is load-bearing: the debate's reasoning was sound, but the relayed implementation instructions named a nonexistent section ("After Drift Report") and mis-cased the quoted warning string. Independent file verification at synthesis time caught both before any edit. Multi-agent consensus improves *conclusions*, not *citation accuracy*.

## DEC-017: "Improve All" (create-plugin Review) — One Correctness Fix, Three Rejections

**Date:** 2026-05-30
**Status:** Accepted
**Source:** `/plugin-dev:create-plugin`-perspective review (plugin-validator + Explore agents + lead) → user "improve all" → 3-agent debate (architect/minimalist/devils-advocate, Opus) with lead synthesis and independent before/after verification

### Context
A create-plugin-perspective review produced five findings. The user said "improve all" — the same phrase that, in DEC-016, the debate filtered down to a single change. Four candidates remained after #5 (`session-start.sh:246` "today unbound") was withdrawn at review time as a false alarm (the `|| true` is *inside* the `$()`, so the var is always assigned — a relayed agent error the lead caught by reading the line).

### Decision
**Ship one correctness fix (#1); reject the other three.** The fix corrects a dirname→regex-injection bug in the SessionStart uncovered-modules detector: `spec_dirs` (directory paths) was `|`-joined and interpolated raw into an ERE (`grep -qE "^($spec_dirs)$"`), so any spec'd directory whose path contains a regex metacharacter was misreported as uncovered. Verified concretely on the author's SvelteKit stack: a route-group directory `src/routes/(app)/dashboard/` containing a `CONCEPT.md` was reported "Uncovered" before the fix and correctly excluded after. Impact is SessionStart **advisory text only** — no effect on boundary injection, edits, or safety. The fix is a coupled 3-line edit (a naive one-line swap to `grep -qxF` against the `|`-blob matches nothing — flagged by the devil's advocate): store `spec_dirs` newline-delimited, drop the leading-`|` strip, and test membership with `grep -qxF -- "$d" <<<"$spec_dirs"` (fixed-string, whole-line — metacharacters never reach a regex engine). Semantically identical to the old anchored match for metachar-free paths; only the broken case changes.

### Alternatives Considered
- **#2 — drop the bare `"wyx"` trigger from 4 skills (keep it only on `audit`)**: Rejected (unanimous). Behavior/discoverability change, not a bug. Zero field evidence of misrouting — the non-determinism is purely theoretical, and no member could produce a concrete mis-routing prompt. `audit` is the intended front door and Claude disambiguates from context. If ever revisited, it needs a deliberate pass *with* a routing test, not a ride-along on a bug fix.
- **#3 — add `.remember/` to the root `.gitignore`**: Rejected (unanimous, evidence-hardened). `git check-ignore -v .remember/` already matches via the nested `.remember/.gitignore`; nothing is tracked; the marketplace is a separate repo. Zero distribution impact — pure redundancy.
- **#4 — add `email`/`url` to the `author` object in `plugin.json`**: Rejected (unanimous). Cosmetic, and adding the maintainer's personal email would *publish* it to the marketplace — a privacy regression, not a fix. Plausibly an intentional omission.

### Consequences
- Net change: one coupled 3-line correctness fix in `session-start.sh`, plus this record. The hooks, skills, and the rest of the script are untouched. Respects YAGNI and the "fixes not features" / "minimal change" pattern (DEC-003, DEC-013, DEC-016).
- The `dirname`-as-regex class is closed for this detector: fixed-string whole-line matching cannot be re-broken by metacharacter paths (`src/v1.2/`, `src/foo+bar/`, dotted dirs, route groups).
- Reaffirms two meta-lessons from DEC-016: (a) "improve all" is a filter prompt, not a mandate — most of "all" was correctly rejected; (b) lead-verifies-agent-output is load-bearing — the debate endorsed a one-line fix that was broken, and a withdrawn finding (#5) was an agent misread; both were caught only by the lead reading/running the actual code, not by consensus.

## DEC-018: ARCHITECTURE.md Staleness False-Nag — Verified-Current Write-Back on the Map Skip Path

**Date:** 2026-06-07
**Status:** Accepted
**Source:** Field feedback (dogfooding workflow-kit `closing` across 5 yorisen releases) + 3-agent debate (architect/minimalist/devils-advocate, Opus) with lead synthesis and independent git/render verification

### Context
The SessionStart freshness check (`session-start.sh:143-152`) fires "ARCHITECTURE.md may be stale" iff `find <specs> -newer ARCHITECTURE.md` is non-empty — a **relative** mtime test, not an absolute "file is old" test (the feedback's stated mechanism was imprecise; corrected at verification). `/wyx:map`'s "Pre-check: Skip if Clean" (`map/SKILL.md:34`) stops **without writing** ARCHITECTURE.md when a spec is newer by mtime but its graph-contributing sections are unchanged. So ARCHITECTURE.md's mtime stays below the spec's, and the warning re-fires every session until a real regen or a manual date-bump (the workaround the feedback flags). ../yorisen reproduced it live: ARCHITECTURE.md generated 06:48, then a drift fix at 11:10 touched three CONCEPT.md (estimate `## actions`, platform-admin `## purpose`, keishin-simulation `## dependencies`) — all newer than the map. Lead verification of the **rendered** graph (not just the spec text) found all three are render-level false-nags: estimate/platform-admin edited non-graph sections; keishin's `list()→listEmployees()` rename renders identically because its dependency edges carry the generic `reads` label (`KS -->|reads| E/R`), not the action verb. The write-back's real target is the **estimate/platform-admin class** — edits to non-graph sections that skip under the text gate and nag every session; keishin's `## dependencies` text *did* change, so under the textual gate it regenerates and self-clears, making it a render-world artifact rather than a current residual-nag case. (The lead's initial "keishin nag is correct" read was wrong and was corrected by the agents' independent render check — verification is bidirectional.)

### Decision
**Ship a one-clause write-back on `map/SKILL.md` Step 4's skip branch; `skills/map/SKILL.md` only, zero script change.** On a confirmed graph-unchanged skip — and only after the comparison was actually performed — the skill inserts/updates a `> Verified current on [date]` line below the truthful `> Generated by` header (v2a; "Generated by" is never overwritten). The Write bumps the file's mtime, so the next session's `-newer` test passes and the nag clears. The write-back is provably false-negative-free only under **two coupled preconditions**, both folded into this change. **(B1) Textual gate:** Step 4's skip condition is pinned to a *textual* byte-identity comparison (the watched sections' text identical via `git diff`, never a rendered-graph judgment) — this also removes a pre-existing run-to-run ambiguity in the wording, which read as both text ("compare via git diff") and render ("graph sections unchanged") and so coin-flipped per run. **(B2) Watched ⊇ derivation sources:** Step 4's watched-section set is aligned to equal Step 2's graph-derivation source set — adding **PIPELINE.md's `## purpose`** (pipeline node labels, `map/SKILL.md:58`), which was missing. Without B2 the write-back would stamp "verified current" on a stale pipeline label for a PIPELINE-`## purpose`-only edit; without B1 the comparison could be a render judgment, reopening the local-derivation-vs-global-matrix false-negative class below. Together they make the safety proof exact: byte-identical watched text ⟹ identical derived graph, so the stamp records a fact, not an LLM opinion.

### Alternatives Considered
- **(a) SessionStart content-hash (re-derive the graph in bash, hash-compare vs ARCHITECTURE.md):** Rejected (unanimous). Re-deriving the Mermaid graph from `## interactions`/`## dependencies` in shell duplicates the LLM graph-synthesis of Step 2 — the same "no clean bash / language-specific" failure that killed PostToolUse import-checking (DEC-014), and it inverts "hooks extract and inject; the LLM judges." Also brittle: whitespace/ordering churn changes the hash without changing the graph.
- **Render-gated write-back (skip when the *derived edges/matrix* are unchanged, not the section *text*):** Proposed by the architect to let keishin skip instead of needlessly regenerating; **vetoed** after the DA constructed a concrete false-negative it introduces — editing spec A's `## dependencies` (drop a bullet to B) under a render judgment updates edge A→B but leaves B's matrix "Depended By: A" cell stale because Step 4 reads only the *changed* spec; the LLM judges "render unchanged" and freezes a half-updated matrix under a fresh date. The text gate has no such surface: skip ⟺ section text byte-identical ⟹ derived graph necessarily identical. The render gate buys only keishin's one needless regen (a 1-line date diff, since the render is identical) at the cost of a real LLM-judgment FN vector — the wrong trade (DEC-016's stance). Text gate kept unchanged.
- **(d) Delete the "Skip if Clean" pre-check (always regenerate):** Rejected. Kills `closing`'s "executed: no-op" signal the feedback author explicitly relies on, re-reads all specs every run (tokens), and churns ARCHITECTURE.md's date header on every close. Restores the invariant by brute force.
- **WONTFIX / documentation-only (disambiguate Step 4 + a Known-Limitations line):** Rejected. The nag is a SessionStart-time mtime `find -newer`; no message printed at map-run time can clear a check that runs at the *next* session start — only a file write moves mtime. A doc note documents the manual chore rather than removing it. (The DA's correct sub-point — Step 4 was ambiguous between a text and a render reading — is absorbed: the watched set is now pinned to the text of the derivation sections.)
- **Known-Limitations note for the residual judgment FN:** Rejected as scope creep. With the render gate dropped, the gate is byte-identical to today's near-zero-FN text comparison; the write-back records the result of a check wyx already runs ("stops discarding," not "adds trust") and fix (B) closes the only structural hole. The pre-existing global stale-spec limitation already lives in CLAUDE.md; a second weaker restatement is the accretion DEC-013 rejects. The residual reasoning lives here, in Consequences, where it is accurate.

### Consequences
- Net change: one clause + one watched-set item on `map/SKILL.md:34`, plus a conditional (skip-path-only) `> Verified current on` line in the Format block. Hooks, scripts, and the rest of the skill are untouched. Respects DEC-010/012/013/014/016/017 and the "minimal mechanical fix" pattern.
- **Clears DEC-016's bar (this time the fix is earned, not deferred):** DEC-016 left a re-fire alone because it was a *correct* invariant; here the re-fire is a self-inflicted *false positive*, so it earns the mechanical fix. The write-back is not DEC-016's rejected ③-A (anchor-on-fix): ③-A added a brand-new suppression keyed on an LLM-reported integer; the write-back rides on a comparison the skip already trusts and introduces no new judgment vector. Blast radius is a non-hook-consumed human orientation doc (`map/SKILL.md:17`), categorically below the stale-CONCEPT.md-feeds-PreToolUse worst case.
- **New invariant:** Step 4's watched-section set must equal Step 2's graph-derivation source set. A future derivation source added to Step 2 must also be added to Step 4, or the write-back can stamp-stale on edits to that source. Stated inline in the Step 4 text so the coupling is visible at the edit site.
- **Residual (accepted, irreducible):** the first session *after* a non-graph-section spec edit and *before* the next `/wyx:map` still shows the nag once (mtime cannot see which section changed); the write-back clears it from the following session on. Making SessionStart section-aware would import the LLM-judgment FN into the hook — far higher blast radius — and is refused. Separately, a spec *deletion* leaves a stale node that `find -newer` cannot detect (a deleted file has no mtime) — a pre-existing gap orthogonal to this change and explicitly *not* covered by the "verified current" stamp, which asserts only that the existing specs' graph sections match.
- Meta-lessons reaffirmed: (a) lead-verifies-agent-output is **bidirectional** — the lead's own "keishin is a correct nag" claim was wrong and was corrected by the agents' independent render check; (b) the devil's advocate again blocked a broken fix that consensus had endorsed (the render gate, then the `## purpose` section-list hole), each caught by reading the actual SKILL.md derivation list, not by agreement.

## DEC-019: create-plugin-Lens Review — Five Fixes, Three Rejections, "Improve All" Filtered Again

**Date:** 2026-06-20
**Status:** Accepted
**Source:** `/plugin-dev:create-plugin`-perspective review (skill-development + hook-development criteria; all three hooks smoke-tested in-harness) + cross-project field feedback (7 wyx items across 4 dogfooding sessions) → user "improve all should be fixed"

### Context
A create-plugin-lens review scored wyx healthy: manifest, hook defensive-coding, and progressive disclosure (SKILL.md bodies 837–1665 words, all under 2k) are above typical plugin quality, and all three hooks execute cleanly in-harness. Seven distinct field items mapped to the review. Two were already shipped by DEC-018 (ARCHITECTURE.md staleness write-back; map textual-skip "Verified current" path). The user's "improve all" — the same filter prompt as DEC-016/017 — resolved to five earned fixes and three rejections.

### Decision
**Five fixes, all minimal/mechanical:**
1. **(C) audit tool-portability.** `skills/audit/SKILL.md`: add `Bash` to `allowed-tools` and a **read-only degraded mode** — when a harness exposes no `Glob`/`Grep` tools (reproduced in the review harness, where `/wyx:audit`'s `Read, Glob, Grep` collapsed to `Read` only while the body forbade `find`, leaving file discovery impossible), fall back to read-only shell (`find`/`ls`/`grep -r`) for discovery *only*. Audit stays strictly read-only (DEC-001/011) on every path — it never writes. Only the *mechanism* (Glob-only discovery) is relaxed; the no-artifacts *invariant* is unchanged.
2. **(E) scoped-detect display.** `session-start.sh`: read the JSONL detect entry's existing `path` field and append `[scope: <path>]` to the "Last drift check … N with drift" line when the measurement was scoped, so a scoped "0 with drift" is not misread as a project-wide all-clear. Reads an existing field; no JSONL schema change.
3. **(B) spec-silence calibration.** `drift-detection.md`: one calibration bullet — "spec silence is not drift; do not infer a contradiction from what a spec omits." Explicitly preserves the Missing action / New state / New dependency / Missing stage checks, which deliberately surface specific undocumented *additions*.
4. **(D) uncovered-module exclusions.** `session-start.sh` + its doc mirrors (CLAUDE.md, README.md, and `audit/SKILL.md` Step 2): extend the hardcoded support-dir exclusion set (`utils/`, `util/`, `helpers/`, `scripts/`, `schema(s)/`, `constants/`, `config/`). String change, no new mechanism. The three prose mirrors are kept identical to the `case` block so the "matches the SessionStart hook's exclusion set" invariant in `audit/SKILL.md` holds.
5. **(A) project-convention coupling demotion.** `drift-detection.md`: a `CLAUDE.md`/`AGENTS.md`-documented architectural convention demotes cross-concept access from Critical to **Low** (not suppressed), and the finding MUST recommend formalizing it into `## known coupling`. Guardrails: requires an *explicit* documented convention (never inferred); when in doubt, stays Critical. Extends DEC-008/015's known-coupling philosophy and propagates to drift agents automatically via the verbatim-calibration-block rule (agent prompt item 2). Plus a trivial imperative cleanup in `map/SKILL.md` Step 4.

**Three rejections (prior decisions re-affirmed):**
- **Bare `"wyx"` trigger in all 5 skill descriptions** — re-affirms DEC-017 #2. Still zero field evidence of misrouting; a discoverability change needs a routing test, not a ride-along on a fix batch. "Improve all" does not override a deliberate prior decision absent new evidence.
- **`author.email` in `plugin.json`** — re-affirms DEC-017 #4. Adding it *publishes* the maintainer's personal email to a public marketplace (outward-facing, hard to reverse); not done without explicit owner consent. The create-plugin template's email field is optional.
- **`.wyxignore` / config for persistent uncovered-module exclusions** — rejected as a feature (DEC-012 dumb-SessionStart, DEC-013 no-feature-depth-at-N=3). The exclusion-list expansion (#D) covers the reported support-dir noise; a parser + file format is scope creep. Residual: a project whose *root* holds >2 source files is still flagged (mtime/glob cannot exempt the root), and `/wyx:pipeline`+`/wyx:sync` *Discovery* mode still depends on Glob (path-given modes work; `/wyx:concept` Discovery escapes via its `Agent` tool). Both deferred — not field-reported as blocking.

### Alternatives Considered
- **SessionStart section-aware staleness (deeper form of field item F)**: Rejected — already refused in DEC-018 ("making SessionStart section-aware would import the LLM-judgment FN into the hook — far higher blast radius"). The map write-back is the sanctioned fix; the residual one-session nag is accepted.
- **Extending the (C) Bash fallback to pipeline/sync/concept frontmatter**: Deferred. Only `/wyx:audit` is fully broken-for-its-core-purpose without Glob/Grep (discovery *is* its job); the others retain path-given modes (and concept has `Agent`). Speculative frontmatter expansion across 3 more skills fails the evidence bar (DEC-013); revisit if Discovery-mode breakage is field-reported.

### Consequences
- Net change: five fixes across `audit/SKILL.md`, `session-start.sh`, `drift-detection.md`, `map/SKILL.md`, CLAUDE.md, and README.md (the last carrying fix (D)'s user-facing exclusion-list mirror, synced during the closing docs pass), plus this record. The hooks' core logic, the manifest, and the other skills are untouched.
- (A) is the one finding carrying residual false-negative risk (the stale-spec worst case) — bounded by three guardrails: explicit-documentation-only, reported-as-Low-never-suppressed, and must-recommend-`## known coupling` formalization, which pushes the sanction from fuzzy prose into the spec where the hook can see it.
- (C) closes a portability defect the lens caught that no prior DEC had: `allowed-tools` names tools that need not exist. `/wyx:map`'s pre-existing `Bash` is why it was the only discovery-resilient skill; audit now matches.
- Re-affirms the DEC-016/017 meta-lesson a third time: **"improve all" is a filter prompt, not a mandate** — 5 of 8 candidates shipped, 3 (two of them prior decisions) correctly held. Lead-verifies is load-bearing: the (C) defect was confirmed by *running* the hooks in-harness, not by reading frontmatter.

## DEC-020: `/wyx:map` Design Improvement — Classification-Free Floor; Reject Overview/Clustering/HTML/Infra-Collapse

**Date:** 2026-06-23
**Status:** Accepted
**Source:** User question — "can `/wyx:map` be improved design-wise, e.g. HTML?" → 4-agent peer-to-peer debate (architect / guardian / devils-advocate / verifier, all Opus, SendMessage peer-to-peer, lead synthesis) cross-verified against the rendered `ARCHITECTURE.md` of four dogfooding projects: yorisen (26 concepts / 159 edges / 140 non-infra, DB-fan 19), aofuda (24 / 119 / 102, DatabaseCore-fan 17), stockrec (15 / 79 / 77, ArtifactLogger-fan 2), WineLevel3/wset3 (7 / 15).

### Context
The map output is a dense `graph TB` Mermaid hairball on 3 of 4 real projects (all >15 concepts — past the skill's own scoped-mode threshold). The opening motion had 6 planks: (1) always-complete graph, (2) edge-count adaptive **cluster overview**, (3) **infra-in-matrix relocation**, (4) generation-time adaptation, (5) reject a bundled JS/HTML viewer, (6) **directory clustering**. A palette refresh (concept layer unstyled while `:::external` carried the loudest fill — an inverted visual hierarchy) was added by the lead as a separate, undebated design fix.

### Decision
**Ship a classification-free floor — three SKILL.md-only changes plus the palette (`skills/map/SKILL.md` only):**
1. **Matrix per-cell enumeration (new Output Stability Rule 8):** a dependency-matrix cell MUST name its members; never a quantifier (`All concepts` / `N of M` / `5/7`). Operates on the cell in place — adds no node, reclassifies nothing, never smears a dependency across other rows; scoped to concept/infra rows (external/sync exempt). Fixes yorisen's DB dropped from the matrix entirely (19 graph edges, 0 matrix rows) and wset3's lossy "5/7" prose. Keys off graph membership — never asks "is this infra."
2. **Reinforce Mermaid rule "No linking TO subgraph names" (#6626)** to explicitly cover fan-out summaries: never `Node -.-> layerName`; emit individual edges (the matrix carries the relationship losslessly per Rule 8, never relocated out of the graph). Fixes stockrec's shipped illegal `AL -.->|logAction| concepts`. Keys off Mermaid syntax — classifies nothing.
3. **Demote `:::infra` to cosmetic-only:** remove Step 3's "what counts as infra" derivation guidance; keep the classDef as optional author styling that no rule reads (no forced re-render of existing maps).
4. **Palette refresh:** retune the four classDef hex values into one muted saturation band so the default-styled concept layer reads as the protagonist; `:::external` demoted from loud magenta (`#f9f`) to a muted neutral boundary. Deterministic (hardcoded hex), no new mechanism.
Plus a **Known-Limitation** note: rendered visual density is unsolved-by-design; scoped mode (`/wyx:map src/path/`) is the readability escape hatch.

**The unifying principle (anchors every rejection):** the determinism line runs between **structural** and **semantic** operations. Structural/uniform operations (matrix enumeration, complete-graph, alphabetical edge order) are deterministic because mechanical. Semantic operations (clustering, infra-classification) churn `git diff` because they require "what does this node *mean*," for which the spec format has no machine-readable signal. **DEC-016/018 privilege a trustworthy `git diff` over rendered density** — so only structural rules survive.

### Alternatives Considered (rejected)
- **Cluster overview / edge-count threshold (motion 2,4):** rejected. (a) Content undeliverable — the overview's value is a ~5-domain view, which needs clustering, which is impossible (below). (b) Threshold mis-calibrated — at >90 it misses stockrec's genuine 79-edge hairball; any cut is post-hoc, and a section-toggle on a one-edge change is a diff disproportionate to the semantic change. (c) 0/4 field demand. DEC-010/013 accretion.
- **Directory clustering (motion 6):** **provably unsalvageable**, not deferred. The three deterministic grouping keys all fail on the corpus: directory → one degenerate cluster (3/4 store concepts flat under one `concepts/`; aofuda's dirs are tech layers, 14-15/24 in `server/db`), node-class → redundant with the existing subgraph layers, semantic → **zero** of yorisen's 27 CONCEPT.md carry a `## domain`/`## cluster` heading (the WYSIWID format has no slot for domain membership).
- **Infra-in-matrix relocation / summary-row (motion 3):** rejected. Manufactures false-or-uncheckable universals ("All concepts" is false by 7 on yorisen's 19/26 DB fan — and the 7 misses are the no-own-table aggregator concepts that ARE the redundant-data-store signal). The summary-with-exception form is a non-local cross-spec re-derivation = the half-updated-matrix FN class DEC-018 vetoed. Replaced by the classification-free Rule 8.
- **All `:::infra`-gated rules (infra-collapse, edges-last fan ordering, the `## state` "mechanism-only + ≥5 consumers" classifier):** rejected. **No deterministic infra discriminator exists** — every candidate fails on the corpus (CONCEPT.md-presence: all 4 have one; named "Database": yorisen's is titled `Tenant`; path `*/db/*`: misses stockrec's logger + wset3's storage; out-degree: a cliff on a smooth gradient that also catches god-node *concepts*; `## state` mechanism-only: aofuda and yorisen authors classified functionally-identical DB concepts **oppositely**, and it false-positives on mixed concepts like yorisen Notification = transport + domain Preferences). Two distinct failure modes: non-reproducible on mixed concepts, and reproducible-but-author-overriding on pure ones. Making any of these deterministic requires a new `kind: infra` frontmatter field — out of scope for a map-skill change.
- **Fan-out ordering rule (`%% <Node> fan-out` trailing group):** rejected by an **impossibility proof** — selecting "the noisy fan" must key on a semantic property (irreducible margin) or a scalar property (degree threshold cliffs on a smooth gradient); there is no third node-property category. It also (a) does not reduce *rendered* density (Mermaid ignores source order) and (b) would override the existing alphabetical-by-source Output Stability Rule 3.
- **Bundled HTML/JS viewer (motion 5 — keep the rejection):** not a Claude Code plugin component type (skills/agents/hooks/MCP/settings only); adds a JS supply-chain dependency (wyx has zero); reinvents rendering GitHub/VS Code/mermaid.live already do; only helps users who open it. A "render the canonical .md" viewer was floated and also rejected — same component-model and adoption problems, and it does not thin a dense graph (pan/zoom of a hairball is still a hairball).
- **Hub-stats `## graph statistics` text section:** deferred (N≥5 demand trigger). Its deterministic form is a re-sort of the matrix's Depended-By column (redundant, DEC-013); the form a developer actually hand-wrote (aofuda) is editorialised prose (non-deterministic). Worst of both.

### Deferred
**`kind: infra` CONCEPT.md frontmatter marker** — the only infra-aware design that is both deterministic and author-respecting (author-*declared*, not inferred). Map would honour it when present, emit the complete graph otherwise. It is the genuine path to the density improvement the original question asked for, and the DEC-008 precedent (standardise a CONCEPT.md construct that projects independently invent — infra is classified 4 ways across 4 projects, a stronger signal than known-coupling's 2/3) supports it. **But it is a spec-format expansion** (touches the CONCEPT.md schema, `/wyx:concept`, the drift checker, and every existing spec), so it is its own larger motion — to be evaluated on its own merits at N≥5, not bundled into a map-skill tweak.

### Consequences
- Net change: `skills/map/SKILL.md` only — one new Output Stability Rule, one reinforced Mermaid constraint, one Step-3 demotion, the four classDef hex values (Rule 4 block + Format example kept in sync per Rule 4), and a density Known-Limitation note. Hooks, scripts, and the other skills are untouched. Determinism (DEC-016/018), zero-asset/GitHub-native rendering (DEC-006), and the no-accretion bar (DEC-010/013) are all preserved — the floor classifies nothing, adds no spec surface, and conflicts with none of the existing 7 stability rules.
- **Behaviour-change, not codification:** Rule 8's enumerated form was produced unprompted in only 1 of 3 large projects (aofuda); stockrec/wset3 degraded to lossy prose. The rule corrects a 2/3-prevalent failure mode — but adherence is context-only (no enforcement; the same limitation class as PreToolUse). Acceptable: it is grep-checkable and the enumerated-vs-quantifier distinction is unambiguous.
- One-time diff on regeneration: existing maps will change their four classDef lines (palette) and, where present, a quantifier matrix cell expands to an enumeration. Both are true, reviewable diffs, not churn.
- **The original "improve design, e.g. HTML" question is answered honestly: the large visual wins (HTML, overview, clustering, infra-collapse) do not survive wyx's determinism + no-accretion constraints; what is earned is two correctness fixes, a demotion, and a palette refresh.** The density problem is real and its only deterministic cure is the deferred `kind: infra` marker.
- Meta-lesson: the verdict is trustworthy via adversarial **mutual error-correction**, not consensus — two impossibility/exhaustiveness proofs (no clustering key; no fan-selector), the keystone "authors classify identical concepts oppositely" finding, four corrections of the DA's own over-reaches (a stockrec edge overcount 96→79, an "always lossy" overclaim → 2/3, a fan-degree trigger, a "non-deterministic threshold" misframing), and three independent kills of the one rule the DA authored and most wanted to keep. Corrected canonical figures used above: stockrec = 79 dependency edges; clustering degenerate 3/3; infra-in-matrix lossy 2/3 (aofuda enumerated); "All concepts" false by 7 on yorisen.
