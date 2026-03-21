# Launch Distribution Materials

Ready-to-post content for each platform. Copy, paste, submit.

---

## Hacker News — Show HN

**Title** (pick one):
1. `Show HN: wyx – Boundary specs that keep Claude Code from breaking your architecture`
2. `Show HN: wyx – Architecture guardrails that inject module boundaries into Claude's context`

**Body** (HN Show posts can include a short text):

```
wyx is a Claude Code plugin that surfaces module boundaries to Claude on every write, reducing cross-module violations.

The core mechanism: you write a CONCEPT.md spec next to your module describing its boundaries (interactions, dependencies). wyx's hooks automatically inject these boundaries into Claude's context before and after every write. Claude sees them and self-checks — no manual rules needed.

In testing (N=6 features, 2 projects): 33 cross-module imports checked, 0 violations (down from 33% baseline). Drift detection also caught a silent data loss bug — an SQL UPDATE missing 2 of 5 fields.

Try it in 2 minutes with the example project: https://github.com/jlifyio/wyx-example

GitHub: https://github.com/jlifyio/wyx

Adapts ideas from WYSIWID (Meng & Jackson, MIT) and WYWIWID (Dr. Ernie) for practical use with Claude Code.
```

**Timing**: Tuesday or Wednesday, 9-10am US Eastern (peak HN traffic)

---

## Reddit r/ClaudeAI

**Title**: `I built a Claude Code plugin that injects module boundaries into Claude's context — and it caught a data loss bug my tests missed`

**Body**:

```
I've been using Claude Code daily for the past few months and kept running into the same problem: Claude generates code that works but breaks module boundaries. Direct imports from internal repositories, bypassing service APIs, cross-module state access.

I tried CLAUDE.md rules ("don't import from scoring internals"). Claude followed them... sometimes. 33% of my features had at least one boundary violation.

So I built wyx — a Claude Code plugin that takes a different approach:

1. You write a CONCEPT.md spec describing your module's boundaries
2. wyx's hooks inject those boundaries into Claude's context before and after every write
3. Claude self-checks against them automatically

Result (N=6 features, 2 projects): 33 imports checked, 0 violations. And drift detection (`/wyx:concept drift`) caught a silent data loss bug — an SQL UPDATE that was missing 2 of 5 fields. My test suite completely missed it.

**Caveats:** Small sample (N=6, single developer, Claude only). Context injection is probabilistic — Claude *sees* the boundaries and self-checks, but it's not a hard blocker. In my testing it worked consistently, but YMMV.

**Try it in 2 minutes:** Clone the example project (https://github.com/jlifyio/wyx-example) — it's a small e-commerce backend with pre-written specs and intentional drift to discover.

**Install:**
```
/plugin marketplace add jlifyio/claude-plugins
/plugin install wyx@jlifyio
```

**Honest caveats:**
- Small sample: N=6 features, 2 projects, single developer
- Context injection is probabilistic — Claude *sees* the boundaries and self-checks, but it's not a hard blocker. It won't stop Claude the way a linter stops you.
- Only tested with Claude (Opus-class models). No idea how other LLMs would respond.
- The diff example doesn't mean wyx *rewrites* your code — it means Claude makes better choices when it *sees* the boundary context before writing.

GitHub: https://github.com/jlifyio/wyx

MIT licensed, feedback welcome. This is my first Claude Code plugin — would love to hear if it's useful for your projects.
```

---

## Reddit r/programming

**Title**: `Architecture guardrails for LLM coding: boundary specs that Claude actually reads before every write`

**Body**:

```
I built a Claude Code plugin called wyx that solves a specific problem: LLMs generate code that works but breaks module boundaries.

The approach: you write a structured spec (CONCEPT.md) describing a module's interactions and dependencies. Hooks automatically inject these boundary declarations into Claude's context before and after every file write. The LLM self-checks against them.

What made it interesting: drift detection — comparing specs against actual code — caught a silent data loss bug (SQL UPDATE missing 2/5 fields) that my test suite missed entirely.

The idea adapts concept specs from WYSIWID (Meng & Jackson, MIT, https://arxiv.org/abs/2508.14511) for practical use in LLM-assisted development.

Example project to try it: https://github.com/jlifyio/wyx-example
Plugin: https://github.com/jlifyio/wyx

Currently works with Claude Code only. The concept (structured boundary specs + context injection) could apply to other LLM coding tools.
```

---

## Twitter/X Thread

```
🧵 I built a Claude Code plugin that surfaces module boundaries to Claude on every write — and it caught a data loss bug my tests missed.

The problem: Claude writes code that works but breaks module boundaries. 33% of my features had cross-module violations.

CLAUDE.md rules don't reliably fix this.
```

```
The solution: wyx.

Write a CONCEPT.md spec next to your module:

## interactions
- READS stock levels FROM Inventory (via service API only)
- NEVER directly accesses Payments internals

wyx injects these boundaries into Claude's context before and after EVERY write. Automatically.
```

```
Result: 33 imports checked, 0 violations.

But the real surprise was drift detection. `/wyx:concept drift` found:

- SQL UPDATE missing 2 of 5 fields (silent data loss)
- Undeclared actions in code
- Cross-module reference mismatches

My test suite caught zero of these.
```

```
Try it in 2 minutes:

1. git clone https://github.com/jlifyio/wyx-example
2. Install: /plugin marketplace add jlifyio/claude-plugins
3. Run: /wyx:concept drift src/

The example project has intentional drift for you to discover.

GitHub: https://github.com/jlifyio/wyx
MIT licensed. Feedback welcome.
```

---

## Distribution Checklist

- [ ] README restructure committed and pushed
- [ ] Demo GIF recorded and added to README
- [ ] Blog post published (dev.to / Hashnode / personal blog)
- [ ] HN Show post submitted (Tue/Wed 9-10am ET)
- [ ] Reddit r/ClaudeAI post submitted
- [ ] Reddit r/programming post submitted (same day or day after HN)
- [ ] Twitter/X thread posted
- [ ] Claude Code Discord / community channels (if applicable)

**Sequence**: Push code → Publish blog → HN (link to blog or GitHub) → Reddit → Twitter

**Key rule**: The README must be ready before any external post goes live. Every link points back to the repo — the README IS the landing page.
