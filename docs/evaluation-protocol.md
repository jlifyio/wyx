# Evaluation Protocol — Concurrent A/B for Boundary Injection

How to re-measure whether wyx's hook injection reduces cross-concept boundary
violations. The published figures (README §Test results and methodology) come
from a before/after comparison, which cannot separate the hooks from the effect
of writing specs, or from model and Claude Code updates between the two periods.
This protocol runs both arms from the same commit, at the same time, on the same
model. Rationale: DEC-022.

## Arms

| Arm | Specs in the worktree | wyx loaded | Purpose |
|-----|-----------------------|------------|---------|
| B — control | yes | no | Claude can still read CONCEPT.md itself |
| C — treatment | yes | yes (`--plugin-dir`) | Adds the plugin: hook injection plus skill listings |
| A — optional | no (deleted before the run) | no | Measures what the specs alone contribute |

B vs C isolates the plugin (its hooks plus its skill listings): both arms can
read the specs, so a difference comes from wyx, not from the specs existing.
A vs B measures the specs themselves — the automated counterpart of the
"writing specs helps" confound.

## Before any run

1. **Freeze the inputs.** Pick a project with committed specs and pin a commit
   `BASE`. Write T task prompts, each needing data from another concept where
   both a sanctioned route (a declared action) and a violating route (an
   internal import) exist. Commit the prompt files; never edit them mid-study.
2. **Pre-register the scorer.** Define a violation before running — for
   example, an import of a file another concept's spec does not expose through
   its declared actions — and implement it as a deterministic checker
   (dependency-cruiser, import-linter, or a per-concept list of internal
   paths). The scorer sees only an opaque run ID and a diff, never the arm:
   keep the run-ID → arm key in a separate file, and exclude spec files from
   the scored diff (arm A deletes them, which would reveal the arm).
3. **Fix the sample.** k ≥ 5 runs per task per arm. Decide k and T now; do not
   stop early on a promising result.

## Running

One fresh worktree per run, all from `BASE`:

```bash
git worktree add ../ab/r017 BASE   # opaque run ID; the arm lives in the key file
```

Disable any installed wyx in every arm, and load the plugin under test only in
C. wyx is often enabled at user scope; a plain `claude -p` then loads it into
the control arm too.

```bash
unset CLAUDECODE   # required when launched from inside a Claude Code session
COMMON=(--model <full-model-id> --output-format stream-json --verbose
        --include-hook-events --no-session-persistence --max-budget-usd 5
        --permission-mode acceptEdits
        --settings '{"enabledPlugins":{"wyx@jlifyio":false}}')

# control run (arm A or B)
(cd ../ab/r017 && claude -p "$(cat /abs/prompts/T1.txt)" "${COMMON[@]}" \
  > /abs/logs/r017.jsonl)

# treatment run (arm C)
(cd ../ab/r018 && claude -p "$(cat /abs/prompts/T1.txt)" "${COMMON[@]}" \
  --plugin-dir /abs/path/to/wyx > /abs/logs/r018.jsonl)
```

- Pin the full model ID (e.g. `claude-opus-5-5`), never an alias.
- `wyx@jlifyio` is the key when wyx was installed from the jlifyio
  marketplace; use the key your own `enabledPlugins` shows.
- Use the same permission mode in every arm.
- Interleave the arms or run them in parallel, so a model or service change
  mid-study hits both arms equally.

## Pre-flight: check arm isolation

Each stream has one `system` event of subtype `init`. With
`--include-hook-events` it comes after the SessionStart and UserPromptSubmit
hook events, so select it by type (`jq 'select(.type=="system" and
.subtype=="init")'`), not by position. Before scoring a batch, check each run:

- **C**: `plugins` contains `wyx` with `"source": "wyx@inline"` and the `path`
  of the plugin under test, and at least one `hook_response` with `hook_event`
  `PreToolUse` has a `stdout` containing `wyx drift context:` once an edit lands
  near a spec. (A wyx SessionStart response appears at startup regardless, so
  it proves nothing about injection.)
- **A, B**: `plugins` has no `wyx` entry, and no `hook_response` `stdout`
  contains `wyx drift context:`.
- **All**: `model`, `claude_code_version` and `permissionMode` are identical
  across arms. If not, discard the batch.

Verified on Claude Code 2.1.281 (2026-09-24): with `wyx@jlifyio` enabled at
user scope, the `--settings` override above removes it from `plugins`, and
`--plugin-dir` loads it as `wyx@inline`.

## Record per run

Run ID, task, arm (in the key file), k; `BASE` SHA; wyx commit SHA (arm C);
`model`, `claude_code_version` and `permissionMode` from the `init` event;
start time; cost and turns from the final `result` event; the diff
(`git -C <worktree> diff BASE`, spec files excluded); scorer output.

## Analysis

- **Primary outcome**: whether a run's diff contains at least one violation.
  Report raw counts and rates with 95% confidence intervals per task and
  overall. Runs of one task share its difficulty, so they are not independent:
  compare C with B with a task-stratified test (Cochran–Mantel–Haenszel), not
  Fisher's exact test on pooled runs.
- **Secondary**: violations per cross-concept import; task completion (tests
  pass or the feature works). Avoiding violations by not doing the task is not
  a win.
- Report every run, including failures and aborts. No post-hoc exclusions.
- State the limits: one model, the chosen projects and tasks, Claude only.

## Out of scope

Drift-detection quality, `/wyx:map` output, and developer experience. This
protocol measures boundary-violation rates during code generation only.
