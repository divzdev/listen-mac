# Agent activation

This project ships a full software team in `.claude/agents/`. The team is **on-demand, not
auto-pilot** — delegating has a real cost (a subagent starts cold and re-derives context), so
you don't farm out every task. The default for most work is: **do it inline on Opus.** You
reach for the team when delegation actually buys something — see `@.claude/rules/model-selection.md`
for the economics. Pick each agent's model per that file (and remember `model: inherit` = Opus,
so pass `model` explicitly when you want a cheaper tier).

## Standing authorization (this project specifically)

The owner has explicitly asked for **proactive parallel fan-out** here — but **quality first,
always** (`@.claude/rules/model-selection.md` → Quality floor). So when a task splits into
**independent, well-specified, cheaply verifiable chunks**, you are pre-authorized to **spawn
multiple Sonnet (or Haiku) agents in a single turn** without asking first. This overrides any
default reluctance to spawn unprompted. Non-negotiable conditions:

- Chunks are independent (no cross-dependencies) and clear enough that a cheaper model won't guess
  wrong — search, tests, mechanical edits, scaffolding. Design-judgment work stays on Opus.
- **Every fan-out result is a draft until Opus reviews it and `verify` passes.** Opus owns what
  ships; the cheaper tier never has the last word on production code.
- Complex / ambiguous / high-stakes work (auth, crypto, payments, migrations, concurrency,
  money/PII) is **Opus-only, inline** — never delegated.

If fanning out would mean shipping unreviewed cheaper-tier code, don't — do it on Opus.

## Trigger map (which teammate for which work)

| When the work is… | Delegate to | Typical tier |
|---|---|---|
| System design, new service, tech selection, "should we…" tradeoffs, scaling/cost | **architect** | Opus |
| Non-trivial backend: endpoints, data models, jobs, integrations, query/perf | **backend-engineer** | Sonnet→Opus |
| Non-trivial frontend: components, state, routing, forms, data fetching, client perf | **frontend-engineer** | Sonnet→Opus |
| Layout, hierarchy, interaction, color/copy, conversion & behavioral-psychology calls | **ui-ux-expert** | Sonnet |
| Test strategy, edge-case hunting, integration/E2E suites, "what could break this?" | **qa-engineer** | Sonnet |
| CI/CD, IaC, deploys, observability, incidents, capacity/cost | **devops-engineer** | Sonnet→Opus |
| **After writing or modifying non-trivial code** | **code-reviewer** | Sonnet→Opus |
| Broad read-only codebase search across many files | built-in **Explore** | Haiku |

## Standing rules

- **Parallelize independent work.** Several test files, several CRUD endpoints from one spec,
  several search queries — fire them as concurrent Sonnet/Haiku agents in one turn, then
  synthesize on Opus. This is the main time+cost win (`model-selection.md`).
- **Design before build.** For a new feature with non-trivial tradeoffs, get an **architect**
  pass before significant code. UI screens get a **ui-ux-expert** pass before
  **frontend-engineer** implements them.
- **Review after build.** After a non-trivial change, run the **code-reviewer**. For
  auth/payments/migrations this is mandatory before "done."
- **Test alongside build.** Net-new behavior gets tests; pull in **qa-engineer** for edge-case
  strategy on anything user-facing or risky.
- **Don't over-delegate.** A typo, a one-line change, a quick question, or any sequential task
  doesn't need an agent. Match the ceremony to the size of the task (CLAUDE.md "scale your work").
- **Keep context fresh.** When you finish work that changes the app's **business behavior**
  (new entity, changed rule, new/removed flow), update `docs/APP_CONTEXT.md` — `/context` or edit
  directly, under budget. Pure refactors/bug fixes that don't change behavior don't need it.
- Agents run in their own context and return a summary. Give them a crisp task and the relevant
  file paths; don't make them re-discover what you already know.
