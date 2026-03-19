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
