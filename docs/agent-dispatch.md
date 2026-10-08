# Agent dispatch — policy and tier reasoning

Background for `CLAUDE.md` → "Agent dispatch: always pin the model". The rule, its enforcement and the fan-out
table stay in `CLAUDE.md`; this file keeps the policy it applies, the measurement behind map's tier, and the
reasoning behind the two corollaries.

## The owner's agent policy

The pin applies the owner's agent policy: agents that write code or make a judgment run on
Opus, effort by role — `high` for judgment and implementation, `low` for mechanical
edits, `xhigh` only where a measured quality gain over `high` justifies it; Haiku/Sonnet
only for read-only lookup/search. Why: Opus 5.5 costs 40% of Fable 5.1 ($4/$20 vs $10/$50 per Mtok, Anthropic pricing page, 2026-10-06),
so no role is assigned the pricier tier.
Effort is out of wyx's reach — the Agent tool has no effort parameter and effort comes
from agent frontmatter, which `Explore` does not have — so the call-site pin is the
model only, and an `Explore` dispatch runs at the session's effort.

## Why map's spec reading runs on Haiku

A dropped line leaves no trace in the graph, and an invented one looks like a real edge or
label, so both had to be counted up front rather than left for a later miss to reveal (first
corollary below). Counting them needs no judgment: the spec file is its own answer key. A
wrong `✓ clean` from drift is just as silent, but counting one needs a seeded fixture that
someone authors and then judges each verdict against; no such measurement is recorded.

Measured 2026-10-08 (Claude Code 2.1.293, Haiku 5.5 vs Sonnet 5.5, both at `high`) on the
33 specs of aofuda `a766d59`, 363 graph-section lines in all. Each run was a top-level
`claude -p --agent Explore` given one group of 4–5 specs and asked, as `skills/map/SKILL.md`
Step 1 now asks, to copy every section line verbatim (PIPELINE.md's `## purpose` included),
with the answer forced into a JSON schema; 8 groups, 3 runs per group per model. Both
models returned every line in all 24 of their runs (1,089 line checks each), none missed
and none invented; Haiku cost $0.23 in total against Sonnet's $3.64. A returned line counted
as copied when, after list markers and whitespace were normalised, `difflib` rated it at least
0.9 similar to a source line, so a slightly altered line would have counted as neither missed
nor invented.
The rule fixed before the runs: switch only if Haiku's missed lines and its invented lines
are each at most Sonnet's plus 0.5 % of the lines checked, and every Haiku run returns its
structured output. Both models hit the ceiling, so this shows Haiku is no worse at copying
sections, not that it reads harder material as well as Sonnet. A separate check confirmed
an `Explore` dispatched with `model: 'haiku'` from an Opus 5.5 session runs Haiku 5.5 at the
session's effort. The harness and per-run data are in the owner's jlifyio workspace
(`docs/lookup-tier-eval-2026-10-08/`), not in this repository.

Re-measure when the `haiku` alias moves to a new model, when the agent instruction in
`skills/map/SKILL.md` Step 1 changes, or before relying on map in sessions below `high`.

## Telling judgment from lookup — the corollaries

Two corollaries, both easy to get backwards. **A silent failure mode cannot be "start
cheap, promote on a demonstrated miss"** — that needs the miss to be observable, and an
under-report never generates its own evidence. And **do not re-derive the tier from
"does the agent assign severity"** (nor from its read-only tools): `skills/concept/references/drift-detection.md`
fixes severity in its tables and forbids escalation, making the task read mechanical
when the judgment actually sits in category selection.
