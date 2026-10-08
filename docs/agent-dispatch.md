# Agent dispatch — policy and tier reasoning

Background for `CLAUDE.md` → "Agent dispatch: always pin the model". The rule, its enforcement and the fan-out
table stay in `CLAUDE.md`; this file keeps the policy it applies and the reasoning behind the two corollaries.

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

Measured 2026-10-08 (Claude Code 2.1.293, Haiku 5.5 vs Sonnet 5.5, both at `high`): the 33
aofuda specs in 8 groups of 4–5, an `Explore` agent per group asked for the graph sections
verbatim, 3 runs per group per model. Both models returned all 1,089 section lines with
none missed and none invented; Haiku cost $0.23 in total against Sonnet's $3.64. The rule
fixed before the runs was "switch only if Haiku misses and invents no more than Sonnet".

## Telling judgment from lookup — the corollaries

Two corollaries, both easy to get backwards. **A silent failure mode cannot be "start
cheap, promote on a demonstrated miss"** — that needs the miss to be observable, and an
under-report never generates its own evidence. And **do not re-derive the tier from
"does the agent assign severity"** (nor from its read-only tools): `skills/concept/references/drift-detection.md`
fixes severity in its tables and forbids escalation, making the task read mechanical
when the judgment actually sits in category selection.
