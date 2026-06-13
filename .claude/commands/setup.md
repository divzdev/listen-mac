---
description: Onboard this boilerplate to a project — fill CLAUDE.md (stack/commands/layout) and bootstrap docs/APP_CONTEXT.md from existing plans/code
argument-hint: "[optional: path to your planning docs, or a short project description]"
---

Wire this Claude setup to the actual project. Input/pointer (if any): $ARGUMENTS

You're configuring the boilerplate for a real codebase. Goal: replace the `<TODO>` placeholders
with real, verified values and bootstrap the business context — using what the project already
provides, asking only for what you genuinely can't find.

**Be token-efficient:** delegate the heavy reading (planning docs + codebase skim) to the
built-in **Explore** agent or a Haiku/Sonnet subagent (`@.claude/rules/model-selection.md`),
then write the concise results yourself. Don't pull whole files into the main context.

### 1. Gather inputs
- Read anything in $ARGUMENTS first. Then auto-discover: `README*`, `docs/**`, and any
  `*PLAN*`/`*PRD*`/`*SPEC*`/`*REQUIREMENTS*` docs.
- Detect the stack from manifests, don't guess: `package.json`, `pnpm-lock`/`yarn.lock`,
  `pyproject.toml`/`uv.lock`/`requirements.txt`, `composer.json`, `go.mod`, `Cargo.toml`,
  `Gemfile`, `Dockerfile`/`compose*.yml`, `Makefile`/`justfile`, CI workflows.

### 2. Fill `CLAUDE.md` (only the `<TODO>`s — keep all structure, rules, and imports)
- **Project name** and **What this project is** — from the docs (purpose, users, stage/scale).
- **Stack** — runtime, framework, DB, infra, package manager (real versions where pinned).
- **Commands** — install / dev / test / lint / build / deploy, taken from `scripts`, Makefile,
  or CI. If a command can't be found, leave a clearly-marked `<TODO>` rather than inventing one.
- **Project layout** — a short real tree of the dirs that matter.
- **Conventions** — branching/commit style if discoverable (CONTRIBUTING, git history); else
  leave the sensible defaults already in the file.
- Keep it under ~200 lines. Don't touch the Team, Slash commands, Autonomy, or rule-import
  sections — those are already correct.

### 2b. Ensure a language rule exists for the stack (create if missing)
The bundled `.claude/rules/` ships language rules for **Python, TypeScript, and PHP only**. If the
project's primary language isn't one of those (e.g. **Swift**, Go, Rust, Kotlin, Ruby):
- **Create `.claude/rules/<lang>.md`** — open with `Extends @.claude/rules/code-style.md. Applies
  when editing *.<ext>.`, then cover that language's **tooling, style, error/optional handling,
  concurrency, framework conventions, data/DB access, and tests**. Match the depth and shape of
  the existing `python.md`/`typescript.md` (tight, ~50–70 lines, read-on-demand — do NOT
  `@`-import it). Pull real conventions from the docs/stack, don't invent ceremony.
- **Point `CLAUDE.md` at it** — update the "Language rules" bullet under Conventions to name the
  new file as the read-on-demand rule for this stack, and note the bundled ones that don't apply.
- If the project legitimately uses one of the bundled languages, just reference it — don't
  duplicate. Skip this step only for a stack with no meaningful language conventions.

### 3. Interview for the gaps (only what's not in docs/code)
Use the **AskUserQuestion** tool for the few things you couldn't determine — e.g. stage/scale
target, deploy target/environment, branching model, any critical non-obvious rules. Don't ask
what you already found. Keep it to a handful of high-signal questions.

### 4. Bootstrap `docs/APP_CONTEXT.md`
Run the `/context` bootstrap discipline: from the planning/feature/logic docs, fill the real
business summary — domain model, business rules & invariants, critical flows, constraints,
glossary. Keep it under budget; push anything you can't confirm into "Open questions." Don't
invent rules.

### 4b. Draft the delivery plan as sprints (`docs/SPRINTS.md`)
Turn the full feature set into an ordered, checkable sprint plan using the **standard format**
already in `docs/SPRINTS.md` (the shipped stub). This is the standard for every plan in the project.
- **Group features into sprints**, categorized smartly by **architecture/build flow** (foundations
  → data → core behavior → UI → polish) or **business flow** — whichever makes each sprint
  **independently demoable**. Respect any phase/roadmap in the docs (don't put Phase-3 work in
  Sprint 1).
- Each sprint gets: a one-line **Goal**, **Depends on**, a **Features** checklist (`- [ ]`,
  concrete + demoable), a **Testing** checklist (unit/integration/E2E + edge cases per
  `@.claude/rules/testing.md`), and a **Definition of Done** (all boxes + `verify.sh` green +
  demoable). Fill the **Status overview** table; mark a clear MVP cut-line.
- Keep early sprints **detailed**; later/uncertain ones can be lighter outlines, refined on arrival.
- **Build discipline (carry into implementation):** build one sprint at a time; check off each box
  as it ships; mark a sprint ✅ only when its DoD holds; then advance. Keep `SPRINTS.md` current —
  it's the source of truth for what's built vs. pending. Don't invent features not in the docs.

### 5. Stand up the verification gate
Create `.claude/verify.sh` (executable) with the project's **fast** check matched to the stack
(typecheck + lint, not the full E2E suite) so the Stop hook can gate "done" — e.g.
`npm run -s typecheck && npm run -s lint`, or `ruff check . && mypy .`, or
`vendor/bin/phpstan analyse -q`. If you can't determine a fast check, skip it and say so.

### 6. Report
Summarize in one screen: stack detected, commands wired, what you asked vs. inferred, what's
still `<TODO>`, whether `APP_CONTEXT.md`, `docs/SPRINTS.md`, `verify.sh`, and a language rule
(`.claude/rules/<lang>.md`) were created, and the suggested next step (review `CLAUDE.md` +
`SPRINTS.md`, then `/spec` or build Sprint 0).

**Safety:** if `CLAUDE.md` is already filled in (not the template), don't overwrite real content
— only complete remaining `<TODO>`s and confirm before changing anything already written.
