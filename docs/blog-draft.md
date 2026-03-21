# How a Claude Code Plugin Caught a Silent Data Loss Bug My Tests Missed

*Architecture guardrails for AI-assisted development with wyx*

---

I was building a stock analysis platform with Claude Code when I noticed something troubling: Claude kept reaching into modules it shouldn't touch. Direct imports from internal repositories. Bypassing the service layer to access prediction internals. The code worked, but the architecture was slowly turning into spaghetti.

**The violation rate? 33% of features had at least one cross-module boundary violation.**

I tried adding rules to CLAUDE.md: "Don't import from scoring internals." "Use the service API for cross-module access." Claude followed them... sometimes. CLAUDE.md rules are aspirational — the LLM may or may not respect them on any given write.

So I built wyx.

## What wyx does

wyx is a Claude Code plugin with one core idea: **put your module boundaries in a structured spec, and inject them into Claude's context on every write.**

When you create a `CONCEPT.md` next to your module:

```markdown
# concept: Orders [OrderId]

## interactions
- READS stock levels FROM Inventory (via checkStock service API only)
- RESERVES inventory FROM Inventory (via reserveStock service API only)
- NEVER directly accesses Inventory repository or Payments internals

## dependencies
- Inventory: read + reserve via checkStock(), reserveStock(), releaseStock()
```

...wyx's hooks automatically fire every time Claude writes or edits a file near that spec. Before the edit, the PreToolUse hook injects the full boundary declarations into Claude's context. After the edit, the PostToolUse hook reinjects the dependency list as a focused reminder — catching violations that slip through during multi-file sequences.

No manual rules to remember. No hoping the LLM reads CLAUDE.md guidelines. The boundaries are right there in context, before and after every write.

**Result (N=6 features, 2 projects): 33 cross-module imports checked, 0 violations.** Down from a 33% violation rate in our baseline.

## The bug that changed my mind

The boundary injection was working well, but what really sold me was an unexpected side effect: **drift detection**.

I'd been running wyx for a few days when I decided to try `/wyx:concept drift` — a mode that compares your specs against actual code. I expected minor housekeeping issues. Undeclared helper methods, maybe a naming mismatch.

Instead, it found this:

> **High severity**: SQL UPDATE in `scoring/repository.ts` writes 3 of 5 declared state fields. Fields `updated_at` and `confidence_score` are silently dropped on every update.

I stared at it for a moment. Then I opened the repository file and checked.

The `updateScore()` function wrote `score`, `symbol`, and `calculated_at` to the database. But the CONCEPT.md spec — which I'd generated from the actual code's interface — declared 5 state fields: those 3 plus `updated_at` and `confidence_score`.

Every time a score was updated, two fields were quietly lost. The data was there when the record was created, but every subsequent update silently dropped it. Not an error. Not a crash. Just silent data loss, accumulating over time.

My test suite didn't catch it because the tests only asserted on the 3 fields that *were* being written. The tests passed. The code "worked." But the data was slowly degrading.

The CONCEPT.md spec declared all 5 fields in `## state`. Drift detection noticed the mismatch between spec and implementation — and flagged it.

This wasn't a theoretical improvement. This was a real bug in code I was actively developing. The kind of bug that would surface weeks later as "why are half our confidence scores null?" — and would be nearly impossible to trace back to the root cause.

## How it works

The mechanism is simple: wyx is a Claude Code plugin with two edit-time hooks. Every time Claude writes or edits a file, the PreToolUse hook checks if there's a `CONCEPT.md` nearby. If so, it extracts the `## interactions` and `## dependencies` sections and injects them into Claude's context *before* the edit. After the edit, the PostToolUse hook reinjects just the dependency list — a focused "did you stay within bounds?" reminder.

Claude sees the full boundary declarations before it writes, then gets a dependency check after. In my testing, it consistently respects them.

Run `/wyx:concept src/payments/` on an existing module and wyx generates the spec from your code. From then on, boundary injection is automatic. No manual step, no CLAUDE.md rules to maintain.

(For the full setup guide, see the [README](https://github.com/jlifyio/wyx).)

## Try it in 2 minutes

I've set up an [example project](https://github.com/jlifyio/wyx-example) — a small e-commerce backend with 4 modules. Three have concept specs; one (`payments/`) has intentional drift for you to discover.

```bash
# 1. Clone the example project
git clone https://github.com/jlifyio/wyx-example
cd wyx-example

# 2. Install wyx (in Claude Code)
/plugin marketplace add jlifyio/claude-plugins
/plugin install wyx@jlifyio

# 3. Start a Claude Code session — wyx reports spec coverage automatically:
#    wyx artifacts: CONCEPT(3: orders, inventory, payments) | Uncovered: notifications

# 4. Run drift detection
/wyx:concept drift src/
```

Drift detection will find 3 issues in the payments module:

- **Boundary violation**: `payments/service.ts` imports `orders/repository` directly — the spec says to use `getOrderTotal()` via the service API
- **Missing action**: `refund()` exists in code but isn't declared in the concept spec
- **SQL bug**: `updatePaymentStatus()` doesn't update the `updated_at` field

Try editing `src/orders/service.ts` — wyx automatically injects the module's boundary declarations, and Claude respects them.

## What else it does

Beyond the core boundary hook, wyx includes 4 skills:

- **`/wyx:concept`** — Generate concept specs from existing code (or design new modules). Includes drift detection mode.
- **`/wyx:pipeline`** — Spec data pipelines with quality invariants and data boundary declarations.
- **`/wyx:sync`** — Map coordination patterns between concepts (timing, qualification, error isolation).
- **`/wyx:map`** — Generate a project-wide architecture map as a Mermaid graph from all specs.

Specs are additive. Start with one module, see the benefit, then expand coverage as you go.

## The results

Tested on 2 real projects across 6 features:

- **Boundary violations**: 33% → 0%
- **33 cross-module imports checked**, 0 violations with wyx active
- **1 silent data loss bug** caught by drift detection
- **4 test gaps** identified from concept spec analysis
- **8/8 skill tests passed** across both projects

The sample is small (N=6, p=0.21), but in practice: zero violations across 33 imports, and drift detection found a real data loss bug that tests missed.

## How it's different

You might be thinking: "Can't I just write better CLAUDE.md rules?" You can try. The difference:

- **CLAUDE.md rules are static.** They sit in a file that Claude reads once at session start. By the time Claude writes code in a specific module, the relevant boundaries may be pages of context away.
- **wyx specs are contextual.** They're injected into Claude's context before and after every write — right when Claude needs them. Both rely on Claude choosing to comply, but wyx's delivery is timely and targeted.
- **Drift detection is active verification.** It checks code against specs, not just hoping they stay aligned.

wyx adapts ideas from [WYSIWID](https://arxiv.org/abs/2508.14511) (Meng & Jackson, MIT) and [WYWIWID](https://ihack.us/2025/11/13/what-you-write-is-what-it-did-a-legible-pattern-for-structuring-software/) (Dr. Ernie) for practical use in LLM-assisted development.

## Get started

```bash
/plugin marketplace add jlifyio/claude-plugins
/plugin install wyx@jlifyio
```

- **GitHub**: [jlifyio/wyx](https://github.com/jlifyio/wyx)
- **Example project**: [jlifyio/wyx-example](https://github.com/jlifyio/wyx-example)
- **License**: MIT

---

*wyx is an open-source Claude Code plugin. Issues and feedback welcome on [GitHub](https://github.com/jlifyio/wyx/issues).*
