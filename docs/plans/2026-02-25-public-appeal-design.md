# wyx Public Appeal Strategy — Design Document

**Date**: 2026-02-25
**Status**: Pending approval
**Debate**: 3 agents (PS: Positioning Specialist, CE: Community Expert, DA: Devil's Advocate) × 3 rounds, Opus model

## Problem Statement

wyx is a functional, well-engineered Claude Code plugin (boundary violations 33%→0%), but its public presentation is optimized for someone who already understands the value proposition. The README reads as a technical reference, not a product page. Zero visual assets, zero social proof, no discovery channel beyond direct links.

**Current appeal score**: 5/10 (content quality 7-8/10, packaging/discoverability 2-3/10).

## Key Strategic Decisions

### 1. Primary audience: Claude Code daily users ONLY (3-0 consensus)

The README targets Claude Code heavy users exclusively. Other audiences served via separate channels:
- LLM coding enthusiasts → blog post
- Architecture community → blog post
- Researchers → docs/background.md or blog

Rationale: wyx is literally a Claude Code plugin — only this audience can install it today.

### 2. Lead evidence: "silent data loss bug" story, NOT p-values (3-0 consensus)

The SQL UPDATE missing 2/5 fields story is wyx's strongest proof point. The p=0.21 stat is honest but self-defeating in a pitch context. Practical framing: "33 imports checked, 0 violations" + bug story.

### 3. Blog post = primary discovery channel (DA strongest, 2/3 agree)

The Claude Code plugin marketplace is nascent with unknown discovery mechanics. Blog posts (HN, Reddit, Discord) are likely the only viable acquisition channel. Blog is #2 in strategic importance, #4 in execution order.

### 4. Tagline: combined approach (CE compromise, all accept)

Keep "guardrails" (SEO value) + add empowering hook:
> **wyx** — Architecture guardrails for Claude Code
> Teach Claude your module boundaries. wyx automatically enforces them every time Claude writes code.

## Score Summary

| Priority | Avg Impact | Avg Feasibility | Execution Order |
|----------|-----------|-----------------|-----------------|
| A. Demo GIF/asciicast | 9.0 | 5.3 | #3 |
| B. README restructure | 9.0 | 7.7 | #2 |
| C. Tagline reframe | 5.7 | 9.0 | (fold into B) |
| D. Blog post / launch | 8.7 | 5.0 | #4 |
| E. Release + badges | 5.0 | 10.0 | #1 |
| F. Issue templates | 3.3 | 9.0 | #5 |
| G. Academic docs | 3.0 | 5.7 | Deferred |

## Execution Plan

### Step 1: GitHub Release v0.14.0 + Badges (15 min)

- Tag v0.14.0 as a proper GitHub Release with brief release notes
- Add badges to README top: Version, License (MIT), "Claude Code Plugin"
- No CI badge (empty CI validates nothing — "performative infrastructure")

### Step 2: README Restructure (2-4 hours)

This is the highest-ROI action. Reorganize existing content into a landing page:

**Above the fold (first 30 lines):**
1. Tagline + badges
2. (Placeholder for demo GIF — added in step 3)
3. Before/after code comparison (PS's key insight):
   ```
   // Without wyx — Claude reaches into module internals
   import { calculateScore } from '../scoring/internal/engine'

   // With wyx — Claude uses the declared public API
   import { getScore } from '../scoring'
   ```
4. One-line install command
5. "Try it in 2 minutes" callout → wyx-example repo (CE's key insight)

**Second screen:**
- "How it works" in 3 numbered steps (spec → hook → self-check)
- Key evidence: "Found a silent data loss bug (SQL UPDATE missing 2/5 fields)" + "33 imports checked, 0 violations"
- Skills table (keep as-is)

**Below the fold:**
- Quick start (expanded)
- Session start hook details (in `<details>` tag)
- Spec placement guide (in `<details>` tag)
- Test results with full methodology and p-values
- Background (renamed from "Theoretical foundations", no self-diminishment)
- Project structure

**Credibility trap fixes (DA findings, PS-validated):**
1. Move "33%→0%" result to after hook explanation (currently misattributed to drift detection)
2. Replace "76% to 100% coverage" with "identified 4 test gaps that human reviewers missed"
3. Rename "Theoretical foundations" → "Background", remove "beyond the scope" framing
4. Move p-values and statistical caveats to Test Results section below the fold

### Step 3: Demo GIF (4-6 hours)

**Creative brief (DA's requirement):**
- Use wyx-example repo as the demo project
- Show 3 beats: (1) spec exists, (2) Claude writes code → boundary context appears, (3) Claude respects boundaries
- The challenge: boundary injection is invisible to users. Need creative staging:
  - Option A: Split-screen showing context injection + resulting code
  - Option B: Annotated terminal recording highlighting the boundary declarations
  - Option C: Before/after terminal comparison (without wyx → with wyx)
- Tool: vhs (terminal GIF recorder) recommended by CE
- Target: 15-20 seconds, placed above the fold in README
- Bad GIF is worse than no GIF — plan what to show before recording

### Step 4: Blog Post + Launch (4-8 hours)

**Structure:**
- Lead with the "silent data loss bug" story (relatable, concrete)
- Walk through: problem → wyx mechanism → 5-minute demo with wyx-example
- End with results and invitation to try
- Include demo GIF from step 3

**Distribution:**
- HN (Show HN post)
- Reddit: r/ClaudeAI, r/programming
- Claude Code Discord/community
- dev.to or Hashnode cross-post

**Prerequisite:** Steps 2 and 3 must be complete (blog drives traffic to README).

### Step 5: Issue Templates (30 min)

- `.github/ISSUE_TEMPLATE/bug_report.md`
- `.github/ISSUE_TEMPLATE/feature_request.md`
- No PR template, no CI workflow (defer until external contributors exist)

### Step 6: Academic/Architecture Docs (Deferred)

Create only when demand emerges. The README's "Background" section is sufficient for now.

## Pre-Execution Investigation

**DA's open question (approval condition):** Investigate Claude Code plugin marketplace discovery mechanics before optimizing marketplace.json. If the marketplace has no browse/search/ranking, all discovery must be external — which further elevates blog post priority.

## Unique Agent Contributions

| Agent | Key Insight | Where Applied |
|-------|------------|---------------|
| PS | Before/after code comparison = 3-second value communication | README above the fold |
| CE | wyx-example repo = underutilized activation asset | README "Try in 2 min" + blog "follow along" + GIF demo project |
| DA | "4 audiences = 0 audiences" — focus README on installers | Entire README structure |
| DA | 3 credibility traps (result misattribution, unscoped 100%, self-diminishment) | README text fixes |
| DA | Marketplace viability question | Pre-execution investigation |
| PS | Execution order: README before GIF (feasibility > impact ordering) | Step sequencing |

## Revisit Conditions

- If marketplace develops browse/search: re-evaluate marketplace.json optimization
- If blog generates academic interest: create docs/background.md
- If external contributors appear: add PR template + CI workflow
- If demo GIF proves too difficult: use annotated screenshots as fallback
