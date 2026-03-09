# Launch Materials Review — Decision Record

**Date**: 2026-02-25
**Team**: launch-materials (3 agents: DX, CW, DA)
**Rounds**: 3 (cross-challenge debate)
**Scope**: All launch deliverables (README, blog, launch posts, demo assets)

## Verdict

**Launch-ready after fixes A-E.** All 3 agents agreed.

## Findings Registry (DA)

| ID | Severity | Finding | Status |
|----|----------|---------|--------|
| B1 | BLOCKER | Marketplace availability unverified | Deferred (pre-launch check) |
| B2 | BLOCKER | wyx-example repo untested by third party | Deferred (pre-launch check) |
| H1 | HIGH | "enforces/prevents" overclaim (~10 locations) | **Fixed** |
| H2 | HIGH | Stats without inline caveats (N=6) | **Fixed** |
| H3 | HIGH | Diff implies active rewrite | **Fixed** |
| H4 | HIGH | "It just works" overclaim in blog | **Fixed** |
| H5 | HIGH | Example domain inconsistency (Auth vs orders/payments) | **Fixed** |
| H6 | HIGH | Blog duplicates README "How it works" | **Fixed** |
| H7 | HIGH | HN title 1 self-referential risk | **Fixed** |
| M1 | MEDIUM | Blog bug story under-invested (10 lines) | **Fixed** (expanded to ~25 lines) |
| M2 | MEDIUM | r/ClaudeAI post lacks honest limitations | **Fixed** |
| L1 | LOW | VHS tape broken (non-deterministic Claude output) | Replaced with Mermaid diagram |

## Fix Priority Scores (agent averages)

| Fix | DX | CW | DA | Avg |
|-----|----|----|-----|-----|
| A. Verify marketplace + wyx-example (BLOCKER) | 10 | 10 | 10 | 10.0 |
| D. Fix overclaims | 9 | 9 | 9 | 9.0 |
| B. Unify example domain | 8 | 9 | 8 | 8.3 |
| C. Deduplicate blog from README | 8 | 8 | 8 | 8.0 |
| E. Rewrite HN title | 7 | 8 | 7 | 7.3 |
| H. Expand blog bug story | 6 | 7 | 5 | 6.0 |
| F. Add Mermaid diagram | 6 | 6 | 6 | 6.0 |
| G. r/ClaudeAI limitations | 5 | 6 | 5 | 5.3 |

## Visual Decision

Mermaid for v1 (3-0 consensus). Screenshots/GIF deferred to post-launch.

## Blog Title Options

- CW: "How a Claude Code Plugin Found the Bug My Tests Missed"
- DX: Keep current ("Caught a Silent Data Loss Bug")
- DA: "Teaching Claude Your Module Boundaries (and the Bug It Found)"

**Decision**: Keep current title — strongest hook for dev audience.

## Key Debate Insights

1. **"Enforces" is the biggest overclaim** — wyx injects context, Claude voluntarily respects it. This distinction matters for credibility on HN/r/programming.
2. **Blog should be story, README should be reference** — deduplication prevents reader fatigue across channels.
3. **Honest limitations build trust** — r/ClaudeAI audience especially values transparency over marketing polish.
4. **Mermaid > GIF for v1** — zero-asset, renders natively on GitHub, communicates the concept in 3 seconds.
5. **Domain consistency matters** — readers who visit README after blog/HN should see the same examples.

## Pre-Launch Blockers (still open)

- [ ] Verify `/plugin marketplace add jlifyio/claude-plugins` and `/plugin install wyx@jlifyio` work
- [ ] Have someone other than the author clone and run wyx-example end-to-end
