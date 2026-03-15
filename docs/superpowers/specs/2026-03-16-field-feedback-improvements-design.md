# wyx v0.19.0 — Field Feedback Improvements

> Design spec from 3-agent debate (ADV+ARCH+DA, 2 rounds, Opus) + brainstorming session.
> Date: 2026-03-16

## Theme

"Close the loop" — consistent guidance from problem detection to fix action using wyx's full skill set.

## Origin

Field feedback from 3 projects:
- **DenkiOffice**: 16 specs, 19 drift scans
- **WineLevel3**: 15+ drift scans, 16 specs
- **StockRecommendation**: 18 specs, 23 drift history entries

17 feedback items triaged → 9 proposals debated → 4 accepted (+ 1 deferred, 4 rejected).

## Accepted Changes

### P1a+: wyx Command + Architecture Suggestions (~15 lines, 4 files)

**What**: When any skill detects a problem, suggest the specific wyx command to fix it. For structural issues, note which Design Rule (1-5) applies and suggest whether a new spec is needed.

**Why**: 3/7 skills already suggest next steps (concept, pipeline have `/wyx:map` reminders). 4 don't. Inconsistency confuses new users and wastes the "what to do next" opportunity. Architecture-level suggestions leverage wyx's full power — drift diagnoses, audit/concept/pipeline/sync prescribe.

**Files and changes**:

1. **drift-detection.md** — Phase 1 "After Drift Report" (+6 lines):
   - Add item 3: "When findings indicate structural issues (boundary violations, state overlap, cross-cutting patterns), note which Design Rule (1-5) applies and suggest the appropriate wyx command — whether updating an existing spec or creating a new one (/wyx:concept, /wyx:pipeline, /wyx:sync, /wyx:audit)."
   - Add item 4: "After the summary, add a 'Suggested next steps' line listing the highest-priority wyx commands to address the findings."
   - Add item 5: "If uncovered modules were observed during scanning, suggest: 'Run `/wyx:audit` to check overall spec coverage.'"

2. **map/SKILL.md** — "After Generating" coverage guidance (+3 lines):
   - Add item 6: For each uncovered module in coverage section, suggest `/wyx:concept path/`, `/wyx:pipeline path/`, or `/wyx:audit`.

3. **sync/SKILL.md** — "After Generating" (+2 lines):
   - Add item 5: If related CONCEPT.md specs exist, suggest `/wyx:concept drift`.

4. **pipeline/SKILL.md** — "After Generating" (+2 lines):
   - Add item 6: If pipeline references concepts without CONCEPT.md, suggest `/wyx:concept path/`.

Note: audit/SKILL.md needs no changes (already outputs command list in Phase 6). concept/SKILL.md's drift-related suggestion moved to drift-detection.md item 5 above (drift context is the correct location, not "After Generating").

**Constraints**: All changes are string templates in SKILL.md instruction text. Zero logic changes. Zero schema changes. Zero hook modifications.

### P2-simplified: "rerun to update" Hint (~20 chars, 1 file)

**What**: Add clarifying suffix to stale drift status in SessionStart output.

**Why**: WineLevel3 reported "4 spec(s) with drift" displayed after all drift was fixed. Users lose trust in SessionStart output. The number is a snapshot from the last drift run — users need to know it's stale.

**File**: session-start.sh

- **L80**: Change `"($last_drift spec(s) with drift)"` → `"($last_drift spec(s) with drift — rerun to update)"`
- **L206**: Change `"Suggestion: Run /wyx:concept drift to check if specs are up to date."` → `"Suggestion: Run /wyx:concept drift to check specs and update this status."`

Note: L80 uses "rerun" (previous run's results are stale). L206 uses "run...and update" (drift hasn't been run today). Different wording for different contexts.

### P3: SYNCS.md Uncovered Re-evaluation (2 lines, 1 file)

**What**: Stop reporting SYNCS.md-containing directories as "uncovered" in SessionStart.

**Why**: The original 2-1 vote to exclude SYNCS.md was cast before v0.17.1 (SYNCS traversal fix) and v0.18.1-v0.18.6 (audit boundary-section checking). These changes created a conceptual distinction between "has a spec" and "has boundary protection" that didn't exist at vote time. Reporting a spec'd directory as "uncovered" trains users to ignore SessionStart output (signal degradation).

**File**: session-start.sh

- **L113 comment**: Update `# Suggest uncovered modules (directories with >2 source files but no CONCEPT.md or PIPELINE.md)` → add "or SYNCS.md"
- **L142**: Add `|| [ -f "$d/SYNCS.md" ]` to the skip condition
- **L156 message**: Change `"Uncovered modules (>2 files, no spec): $uncovered"` → `"Uncovered modules (>2 source files, no CONCEPT/PIPELINE/SYNCS): $uncovered"`

**Edge case acknowledged**: SYNCS.md-only directory without ancestor CONCEPT.md gets zero boundary protection and won't be flagged. This is rare (SYNCS.md documents coordination between concepts that should have specs) and acceptable at current scale.

### P5-alt: Git Diff Hint (1 line, 1 file)

**What**: After regenerating ARCHITECTURE.md, suggest `git diff` to review changes.

**Why**: DenkiOffice reported needing to manually diff to see what changed. LLM-based Mermaid diffing (original P5) was rejected unanimously as unreliable. `git diff` on deterministic output (ensured by map/SKILL.md's 7 stability rules) is always accurate.

**File**: map/SKILL.md — "After Generating" section

- Add item 5: `If ARCHITECTURE.md was overwritten, suggest: "Run git diff ARCHITECTURE.md to review changes."`

(P1a+'s coverage suggestion becomes item 6.)

## Deferred

### P4-alt: Low Collapse in Drift Report (ADV 6, ARCH 5.5, DA 4)

Collapse Low findings into a summary line instead of listing individually. Deferred because:
- The >5 Low accumulation advisory was added in v0.18.6 (4 days ago) — zero evidence it's insufficient
- Low deduplication (also v0.18.6) may already address the noise complaints
- Revisit after 3+ drift scans across 3 projects show the >5 rule is insufficient

### P1b: SessionStart Directory-to-Spec Path Mapping (all 3: 4/10)

Mapping changed directories to nearest spec requires upward traversal logic, duplicating drift-context.sh. Same pattern rated 5/10 feasibility in incremental-drift debate. Current SessionStart output ("Code modified since last drift: src/lib/auth") is sufficient.

## Rejected

| Proposal | Reason | Score |
|----------|--------|-------|
| P2-original (JSONL schema) | JSONL is snapshot, not ledger. Out-of-band fixes invisible. State management scope creep. | 3.8 |
| P4-original (--min-severity flag) | Interacts with >5 Low advisory. Argument parsing complexity. | 4.2 |
| P5-original (Map diff summary) | LLM structural diffing of Mermaid unreliable. False confidence worse than no summary. | 2.6 |

## Implementation Summary

| File | Changes | Lines |
|------|---------|-------|
| drift-detection.md | P1a+ Phase 1 items 3-5 | +8 |
| pipeline/SKILL.md | P1a+ After Generating item 6 | +2 |
| sync/SKILL.md | P1a+ After Generating item 5 | +2 |
| map/SKILL.md | P5-alt item 5 + P1a+ item 6 | +4 |
| session-start.sh | P2-simplified L80+L206 + P3 L113+L142+L156 | +5 |
| **Total** | **5 files** | **~21 lines** |

All changes are string templates or presentation text. Zero logic changes. Zero schema changes. Zero hook (drift-context.sh) modifications.

## Debate Record

3-agent debate (Advocate + Architect + Devil's Advocate), 2 rounds, Opus model.

### Key Insights

1. **"Fixes not features"** (ADV): 4/5 accepted proposals fix existing output problems. Only P1a+ is a genuine improvement. Total cost (~25 lines) is less than the FIND_EXCLUDES refactor.
2. **"Snapshot not ledger"** (ARCH): JSONL records observations, not workflow state. Killed P2-original cleanly.
3. **"Let the fix prove itself"** (DA): >5 Low rule added 4 days ago — validate before layering more mechanisms.
4. **"Nudge > manual"** (brainstorming): Architecture suggestions need 3 lines of permission, not 15 lines of category mapping. Claude has Design Rules in context.
5. **Proposals improved through debate**: Every original proposal was either rejected, simplified, or split. Zero proposals shipped as originally proposed.
