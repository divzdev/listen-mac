# Dynamic model selection

You (the main session, Opus) are the orchestrator. **Tiering is not automatic** — nothing
routes work to a cheaper model for you. It only happens when you *choose* to delegate a chunk
to a subagent **and** pass an explicit `model` to the Agent tool. Agents declare
`model: inherit`, and `inherit` means **the parent's model (Opus)** — so a spawn with no
`model` param runs on Opus and saves nothing. If you want Sonnet/Haiku, you must say so.

## Quality floor (non-negotiable — read first)

Cheaper tiers are a **throughput tool, never a quality compromise.** These hold absolutely:

- **Quality is never traded for speed or cost.** If a faster/cheaper route risks a worse
  result, take the slower route. When unsure whether a chunk is "safe enough" for Sonnet, it
  isn't — do it on Opus.
- **Opus owns everything that ships.** Anything a cheaper tier produces that will land in the
  codebase is a **draft** until Opus has read it line-by-line *and* `verify` (typecheck / lint /
  tests) passes. If you wouldn't review the output, don't delegate it — do it on Opus.
- **Only delegate cheaply-verifiable work.** Good Sonnet/Haiku fan-out: codebase search,
  investigation, test scaffolding, mechanical pattern-edits, boilerplate — work whose
  correctness a human or a test can check at a glance. The more a chunk turns on design judgment,
  the more it belongs on Opus.
- **High-stakes paths are Opus-only, always.** Auth, crypto, payments, data migrations,
  concurrency, anything touching money or PII — no cheaper tier, no exceptions.

The net effect: worst case, a cheaper tier drafts something wrong, Opus catches it on review or
`verify` fails — same final quality as Opus-only, just sometimes faster. Quality is floored; only
speed and cost vary.

## The economics (read before delegating)

A subagent is **not free**: you pay cold-start context, the tokens to write its prompt, and
the round-trip to read its summary. So:

- **A lone subagent for a trivial task usually loses.** It's slower than doing it inline (serial
  + overhead) and barely cheaper. Don't reflexively farm out small work — just do it on Opus.
- **The two shapes that actually win:**
  1. **Parallel fan-out** — when a task splits into **N independent, well-specified, cheaply
     verifiable chunks with no cross-dependencies**, spawn N agents *in a single turn* so they run
     concurrently. This is the only thing that cuts **wall-clock time**, and on Sonnet/Haiku it
     cuts **cost** too — provided Opus reviews each result before it's "done" (quality floor).
  2. **Context isolation** — offload one big, noisy job (read 20 files / run a long test suite,
     return a 10-line answer) to a cheap agent so its output never pollutes the main thread.

**The pipeline that protects quality:** Opus decomposes and plans → parallel Sonnet/Haiku
execute the independent chunks → Opus synthesizes the results and reviews. Opus does the
thinking; the cheaper tier does the parallel typing.

## When NOT to fan out (stay inline on Opus)

- Sequential work where step N needs step N−1's output — parallelism gives nothing.
- Ambiguous / underspecified work — a cheap agent will guess wrong; decide on Opus first.
- High-stakes paths: architecture, security (auth/crypto/payments), data migrations,
  concurrency, anything touching money or PII. Quality > savings here.
- Anything small enough that writing the subagent prompt costs more than just doing it.

## When you do delegate, pick the tier

Judge the chunk on blast radius, irreversibility, ambiguity, security/data sensitivity, and
cross-file reasoning. Then:

- **Haiku** — mechanical, low-ambiguity, easily verifiable. Codebase search, file location,
  renaming, boilerplate scaffolding, formatting, simple test stubs, log grepping. Prefer the
  built-in **Explore** agent for broad read-only searches.
- **Sonnet** — standard implementation/review where the path is clear. CRUD endpoints,
  component work, straightforward bug fixes, tests for known behavior, routine review of a small
  diff. **This is the default tier for fan-out chunks.**
- **Opus** — high-stakes or high-ambiguity work, and the main orchestrating session itself.
  System/architecture design, security-sensitive code, migrations, concurrency, gnarly
  debugging, anything where being wrong is expensive or hard to undo.

## Rules of thumb

- **When unsure, go one tier up.** A wrong cheap answer (rework, escaped bug) usually costs more
  than the savings.
- **Escalate on failure.** If a Haiku/Sonnet agent stalls, loops, or returns weak work, re-run it
  on the next tier up rather than hand-patching its output.
- **Match the reviewer to the risk.** Trivial diff → Sonnet review. Auth/payments/migration diff
  → Opus review.
- **State your choice.** When you delegate, note tier + why and whether it's parallel
  ("3× Sonnet in parallel — independent test files, clear spec"). Keeps the cost/quality
  tradeoff auditable.
- The user's request sets the ceiling: a "quick fix" rarely needs Opus or an agent at all; a
  "design the billing system" task always needs Opus and probably no fan-out.
