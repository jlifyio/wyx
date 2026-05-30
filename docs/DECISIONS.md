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
