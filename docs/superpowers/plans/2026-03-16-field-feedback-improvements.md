# Field Feedback Improvements Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add consistent wyx command suggestions across all skills, fix misleading SessionStart output, and resolve SYNCS.md false positive.

**Architecture:** String template additions to 4 SKILL.md files + 1 reference file, plus minor presentation fixes in session-start.sh. Zero logic changes, zero schema changes, zero hook (drift-context.sh) modifications.

**Tech Stack:** Bash (session-start.sh), Markdown (SKILL.md files, drift-detection.md)

**Spec:** `docs/superpowers/specs/2026-03-16-field-feedback-improvements-design.md`

---

## Chunk 1: All Changes

### Task 1: P3 — Fix SYNCS.md uncovered false positive (session-start.sh)

**Files:**
- Modify: `scripts/session-start.sh:113` (comment)
- Modify: `scripts/session-start.sh:142` (skip condition)
- Modify: `scripts/session-start.sh:156` (echo message)

- [ ] **Step 1: Update L113 comment**

```bash
# Before:
# Suggest uncovered modules (directories with >2 source files but no CONCEPT.md or PIPELINE.md)

# After:
# Suggest uncovered modules (directories with >2 source files but no CONCEPT.md, PIPELINE.md, or SYNCS.md)
```

- [ ] **Step 2: Update L142 skip condition**

```bash
# Before:
if [ -f "$d/CONCEPT.md" ] || [ -f "$d/PIPELINE.md" ]; then

# After:
if [ -f "$d/CONCEPT.md" ] || [ -f "$d/PIPELINE.md" ] || [ -f "$d/SYNCS.md" ]; then
```

- [ ] **Step 3: Update L156 echo message**

```bash
# Before:
echo "Uncovered modules (>2 files, no spec): $uncovered"

# After:
echo "Uncovered modules (>2 source files, no CONCEPT/PIPELINE/SYNCS): $uncovered"
```

- [ ] **Step 4: Validate shell syntax**

Run: `bash -n scripts/session-start.sh`
Expected: No output (clean parse)

- [ ] **Step 5: Commit**

```bash
git add scripts/session-start.sh
git commit -m "fix: include SYNCS.md in uncovered module detection

Directories with SYNCS.md were reported as 'uncovered' every session,
training users to ignore SessionStart output. SYNCS.md is a wyx spec
even though it provides no boundary protection.

Re-evaluation of 2-1 vote based on new evidence: v0.17.1 SYNCS traversal
fix and v0.18.1+ audit boundary-section distinction."
```

---

### Task 2: P2-simplified — Add "rerun to update" hint (session-start.sh)

**Files:**
- Modify: `scripts/session-start.sh:80` (drift status echo)
- Modify: `scripts/session-start.sh:206` (drift suggestion echo)

- [ ] **Step 1: Update L80 drift status message**

```bash
# Before:
echo "Last drift check: $last_ts ($last_drift spec(s) with drift)"

# After:
echo "Last drift check: $last_ts ($last_drift spec(s) with drift — rerun to update)"
```

- [ ] **Step 2: Update L206 drift suggestion message**

```bash
# Before:
echo "Suggestion: Run /wyx:concept drift to check if specs are up to date."

# After:
echo "Suggestion: Run /wyx:concept drift to check specs and update this status."
```

- [ ] **Step 3: Validate shell syntax**

Run: `bash -n scripts/session-start.sh`
Expected: No output (clean parse)

- [ ] **Step 4: Commit**

```bash
git add scripts/session-start.sh
git commit -m "fix: clarify stale drift status in SessionStart output

Users saw '4 spec(s) with drift' after fixing all drift, causing
confusion. Add 'rerun to update' hint to L80 and rephrase L206
suggestion to clarify the status updates on next drift run."
```

---

### Task 3: P1a+ — Add wyx command suggestions to drift-detection.md

**Files:**
- Modify: `skills/concept/references/drift-detection.md:130` (Phase 1 items)

- [ ] **Step 1: Add items 3-5 to Phase 1 and renumber Phase 2/3**

After existing item 2 (`"For each drifted spec, ask: ..."`), add three new items to Phase 1:

```markdown
3. When findings indicate structural issues (boundary violations, state overlap,
   cross-cutting patterns), note which Design Rule (1-5) applies and suggest the
   appropriate wyx command — whether updating an existing spec or creating a new one
   (`/wyx:concept`, `/wyx:pipeline`, `/wyx:sync`, `/wyx:audit`).
4. After the summary, add a "Suggested next steps" line listing the highest-priority
   wyx commands to address the findings (e.g., `/wyx:concept path/` for specs with
   drift, `/wyx:audit` if uncovered modules were noted).
5. If uncovered modules were observed during scanning, suggest: "Run `/wyx:audit` to
   check overall spec coverage."
```

Then renumber existing Phase 2 items (currently 3→6, 4→7, 5→8) and Phase 3 item (currently 5→9) to avoid numbering collision.

- [ ] **Step 2: Commit**

```bash
git add skills/concept/references/drift-detection.md
git commit -m "feat: add architecture-aware fix suggestions to drift report

Drift findings now suggest the specific wyx command to fix them,
including Design Rule references for structural issues. Enables
suggesting new specs (concept/pipeline/sync) when patterns indicate
architectural gaps, not just updating existing specs."
```

---

### Task 4: P1a+ and P5-alt — Add suggestions to SKILL.md files

**Files:**
- Modify: `skills/map/SKILL.md:166-169` (After Generating)
- Modify: `skills/sync/SKILL.md:127-130` (After Generating)
- Modify: `skills/pipeline/SKILL.md:117-121` (After Generating)

- [ ] **Step 1: Add items 5-6 to map/SKILL.md "After Generating"**

After existing item 4 (`"Note: Mermaid graphs render visually..."`), add:

```markdown
5. If `ARCHITECTURE.md` was overwritten, suggest: "Run `git diff ARCHITECTURE.md` to review changes."
6. In the coverage section, for each uncovered module suggest the appropriate command:
   `/wyx:concept path/` for concept candidates, `/wyx:pipeline path/` for data
   transformation directories, or `/wyx:audit` for a full assessment.
```

- [ ] **Step 2: Add item 5 to sync/SKILL.md "After Generating"**

After existing item 4 (`"If a SYNCS.md already exists..."`), add:

```markdown
5. If related CONCEPT.md specs exist, suggest: "Run `/wyx:concept drift` to verify
   sync references match current concept declarations."
```

- [ ] **Step 3: Add item 6 to pipeline/SKILL.md "After Generating"**

After existing item 5 (`"If ARCHITECTURE.md exists..."`), add:

```markdown
6. If the pipeline references concepts without CONCEPT.md, suggest:
   "Run `/wyx:concept path/` to create the missing concept spec first."
```

- [ ] **Step 4: Commit**

```bash
git add skills/map/SKILL.md skills/sync/SKILL.md skills/pipeline/SKILL.md
git commit -m "feat: add consistent wyx command suggestions to all skills

Extend the existing 'After Generating' suggestion pattern (concept and
pipeline already suggest /wyx:map) to map, sync, and pipeline skills.
Map gets git diff hint + coverage suggestions. Sync suggests drift
verification. Pipeline suggests missing concept specs."
```

---

### Task 5: Version bump and validation

**Files:**
- Modify: `.claude-plugin/plugin.json` (version)

- [ ] **Step 1: Bump version to 0.19.0**

```json
"version": "0.19.0"
```

- [ ] **Step 2: Validate plugin structure**

Run: `python3 -c "import json; json.load(open('.claude-plugin/plugin.json'))" && echo "plugin.json OK"`
Run: `python3 -c "import json; json.load(open('hooks/hooks.json'))" && echo "hooks.json OK"`
Run: `bash -n scripts/session-start.sh && echo "session-start.sh OK"`
Run: `bash -n scripts/drift-context.sh && echo "drift-context.sh OK"`
Run: `for s in audit concept map pipeline sync; do test -f skills/$s/SKILL.md && echo "$s OK"; done`
Expected: All OK

- [ ] **Step 3: Commit**

```bash
git add .claude-plugin/plugin.json
git commit -m "v0.19.0"
```

---

## Verification

After all tasks, run the full SessionStart hook test to confirm P2+P3 changes work:

```bash
CLAUDE_PROJECT_DIR=/path/to/project-with-specs bash scripts/session-start.sh
```

Confirm:
- SYNCS.md directories no longer appear in "Uncovered modules"
- Drift status shows "— rerun to update" suffix
- Drift suggestion shows "check specs and update this status"
