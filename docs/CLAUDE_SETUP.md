# Claude Code Setup — Master Plan & Reference

> The single source of truth for this `default/` boilerplate: what every file does, why it
> exists, the decisions behind it, and how to extend it. Read this before changing the setup.
> Last substantive update: 2026-06-01.

## 1. Purpose

This directory is a **reusable Claude Code configuration** that turns Claude into a full,
mostly-autonomous software team. Copy it to seed a new project, then fill in the `<TODO>`
sections of `CLAUDE.md`. It is config, not an app.

Design goals (from the owner):
1. **A whole software team** — architect, backend, frontend, UI/UX + product psychology, QA,
   DevOps, and code review — that engages itself without being asked.
2. **Autonomous** — runs for hours without approval prompts; only destructive actions are
   blocked.
3. **Fast & efficient** — model tier chosen per task (Haiku/Sonnet/Opus), not one-size-Opus.
4. **Serious** — security, testing, and review are first-class, with language rules for the
   owner's stack (Python, Next.js/TS/Tailwind, PHP/Laravel, MySQL/Postgres, Docker).

## 1a. Starting a new project (quickstart)

1. From inside your project (new or existing), run the installer once:
   ```bash
   bash /path/to/default/install.sh
   ```
   It drops in `.claude/` + `CLAUDE.md` + `docs/`, never clobbers files you already have, skips
   personal `settings.local.json`, and is safe to re-run to pull updates.
2. Put your planning material where Claude can read it — a `README`, a `docs/` folder, or any
   `PLAN`/`PRD`/`SPEC` docs. Stack manifests (`package.json`, `pyproject.toml`, `composer.json`,
   `Dockerfile`, …) are read automatically.
3. Run **`/setup`** (optionally `/setup path/to/your/docs`). It fills `CLAUDE.md` (stack,
   commands, layout) from your docs + manifests, bootstraps `docs/APP_CONTEXT.md` (business
   rules, flows, domain model), drafts `docs/SPRINTS.md` (the sprint delivery plan with Features
   + Testing checklists), adds a language rule for non-bundled stacks, interviews you for the few
   gaps it can't find, and stands up `.claude/verify.sh` (the verification gate). The most capable
   Opus leads it and delegates the heavy reading to a cheap model.
4. Skim `CLAUDE.md`, `docs/APP_CONTEXT.md`, and `docs/SPRINTS.md`, fix anything off, then build
   **Sprint 0** (or **`/spec`** a feature). From here the team, autonomy, hooks, and cost controls
   are all live.

Re-running `/setup` later only completes remaining `<TODO>`s — it won't clobber content you've
already written.

## 2. File map

```
default/
├── CLAUDE.md                     # Project charter (template, fill the <TODO>s). Wires rules/agents/commands.
├── CLAUDE.local.md               # Personal, gitignored overrides (template).
├── .gitignore                    # Secrets + multi-stack artifacts.
├── docs/
│   ├── CLAUDE_SETUP.md           # ← this file.
│   ├── APP_CONTEXT.md            # Always-loaded ~2-page business/domain summary (the "what & why").
│   └── SPRINTS.md                # Delivery plan — sprints w/ Features + Testing checklists (read on demand).
└── .claude/
    ├── settings.json             # Model, statusline, permissions (bypass + deny), hooks.
    ├── settings.local.json       # Personal permissions (gitignored).
    ├── statusline.sh             # [model] cwd status line.
    ├── commands/                 # /setup /git /fix /explain /refactor /test /review /deploy /context /spec.
    ├── agents/                   # The team (7 subagents).
    ├── verify.sh                 # (optional, per-project) fast check the Stop-hook gate runs. Absent by default.
    ├── hooks/
    │   ├── validate-bash.sh      # PreToolUse firewall: blocks destructive commands only.
    │   ├── format-on-edit.sh     # PostToolUse: auto-formats the edited file (prettier/ruff/pint/gofmt), silent.
    │   ├── bats-autorun.sh       # PostToolUse: runs *.bats after Edit/Write if present.
    │   └── driftcheck.sh         # Stop: verification gate — runs .claude/verify.sh if present, else no-op.
    └── rules/
        # Eagerly @-imported by CLAUDE.md (loaded every session — keep tight):
        ├── code-style.md         # Universal style.
        ├── security.md           # Security baseline (OWASP, secrets, authz…).
        ├── testing.md            # Test pyramid & determinism.
        ├── autonomy.md           # Run-unattended doctrine + guardrail description.
        ├── agent-activation.md   # When to delegate to which agent (trigger map).
        ├── model-selection.md    # Dynamic Haiku/Sonnet/Opus policy.
        ├── context-efficiency.md # Keep the working set small; tool output is the main token drain.
        # Read ON DEMAND (NOT @-imported) — only the language being edited is loaded:
        ├── python.md             # Python/uv/ruff/pytest/pydantic.
        ├── typescript.md         # TS/Next App Router/React/Tailwind/zod/vitest.
        └── php-laravel.md        # PHP 8.2+/Laravel/Eloquent/Pest.
```

## 3. The team (`.claude/agents/`)

| Agent | Role | Tools | Notes |
|---|---|---|---|
| architect | System design, tradeoffs, tech selection | Read, Grep, Glob, WebFetch, WebSearch | No edit — advises. |
| backend-engineer | APIs, data models, jobs, perf | Read, Edit, Write, Grep, Glob, Bash | |
| frontend-engineer | Components, state, routing, client perf | Read, Edit, Write, Grep, Glob, Bash | |
| ui-ux-expert | Design **+ behavioral psychology** (color/copy/persuasion/trust) | Read, Grep, Glob, WebFetch | Owns the "human psychologist" role. |
| qa-engineer | Test strategy, edge cases, regression | Read, Edit, Write, Grep, Glob, Bash | Lead + tester voice. |
| devops-engineer | CI/CD, IaC, observability, deploy | Read, Edit, Write, Grep, Glob, Bash, WebFetch | Lead + server architect. |
| code-reviewer | Read-only second-pass review | Read, Grep, Glob, Bash | No Edit/Write — reports, doesn't fix. |

All declare `model: inherit`; the orchestrator picks the tier per task. Keep this table in
sync with the "Team (subagents)" list in `CLAUDE.md` — that invariant is enforced by eye on
every change.

## 4. Key decisions & rationale

- **Dynamic model selection over fixed per-agent models.** Owner wanted cost + quality
  optimized per feature. Agents are `model: inherit`; `rules/model-selection.md` tells the
  Opus orchestrator to assess complexity and choose Haiku (mechanical), Sonnet (standard), or
  Opus (high-stakes), escalating when unsure or on failure. The Agent tool's `model` param
  overrides frontmatter at spawn time, which is the mechanism.
- **Opus is the standing orchestrator (chosen, quality-first).** The base model is the `opus`
  alias — the best available model leads and delegates down. We accept it as the dominant cost
  line in exchange for the best planning/judgment at the top. See §5b for the tradeoff and the
  Sonnet alternative we deliberately did not take.
- **Autonomy via bypassPermissions + a tight firewall.** Owner wanted hours of unattended
  work. `defaultMode: bypassPermissions` removes prompts; safety comes from two layers that
  block **only** destruction: `permissions.deny` (secret reads, catastrophic commands) and
  `validate-bash.sh`. We deliberately **removed** the old `git add -A` block (it fought
  autonomy; secret-leak risk is covered instead by `.gitignore` + `permissions.deny` on
  `.env*`). `permissions.deny` stays minimal — secret reads + truly catastrophic filesystem
  commands only; all git protection is delegated to the hook so it can be context-aware.
- **Psychologist folded into ui-ux-expert**, not a separate agent — the overlap with design
  was too high. Strengthened its persuasion / behavioral-economics / trust / typography
  sections instead.
- **Slash commands** added for the seven highest-leverage workflows (the "15-file setup"
  article's set). They encode process (root-cause before fix, tests before refactor,
  checklist before deploy) so quality doesn't depend on remembering.
- **Per-language rules** scoped to the owner's actual stack, referenced from `CLAUDE.md`.
- **`code-reviewer` is read-only** (no Edit/Write), matching Anthropic's official example —
  it reports findings; the author or an engineer agent applies them.

## 5. Source review — verdict on each input

Reviewed against the three articles + official Claude Code docs. Net: the originals were
sound; we adopted the high-value items and skipped the environment-specific ones.

**dev.to "10 configs"** — the boilerplate already implemented 6 (status line, allow-list,
bypass + safety hook, PostToolUse test run, Stop driftcheck, MEMORY.md). Added from it:
hierarchical/per-language rules (#6) and agent auto-activation (#8). Skipped: `enabledPlugins`
(#10) and global-vs-project skills (#7) — environment-specific, not boilerplate concerns.

**towardsai "15-file dev team"** — adopted: `.claude/commands/` workflow set, explicit
deny-list, `CLAUDE.local.md` + gitignore split, model-per-agent thinking (made dynamic).

**ranthebuilder "best practices"** — adopted in spirit: Opus for heavy lifting / cheaper
models for routine work (now dynamic), CLAUDE.md < 200 lines with imports, security-review as
a first-class step (`/review` + security rules), proactive adversarial review.

**Official docs (code.claude.com/docs/sub-agents)** — validated our code-reviewer design
(read-only, "use proactively," runs `git diff`), the frontmatter fields, and "design focused
subagents / write detailed descriptions / limit tool access / version-control them."

## 5a. Application context subsystem (`docs/APP_CONTEXT.md`)

A tight, **always-loaded** summary of the business/domain — what the app does and why
(domain model, business rules, critical flows, constraints, glossary). `CLAUDE.md` imports it
via `@docs/APP_CONTEXT.md`. Purpose: let Claude understand the app from ~2 cached pages instead
of re-reading code and long planning docs every session — a net token saving.

Kept cheap and fresh by three mechanisms, not an expensive always-on hook:
- **Hard budget + template** — the maintenance contract at the top caps it at ~200 lines and
  defines what belongs (durable business truth) vs. what doesn't (impl detail, task history).
  It's a summary, never a log.
- **`/context` command** — on-demand create/refresh/compress. Cost is paid only when run, and
  it delegates the heavy reading to a cheap model (Explore/Haiku) per `model-selection.md`.
- **Status-line staleness marker** — `statusline.sh` shows `⚠ctx-stale` (zero tokens) when
  source has been committed more recently than `APP_CONTEXT.md`, signalling a refresh.

`agent-activation.md` also tells Claude to update it after any change to business behavior.
Rule of thumb: every line lives in context forever, so it must earn its cost — when in doubt,
cut it.

## 5b. Cost controls (the CFO view)

Token cost scales with **context size**, and tool output (file reads, command results) is the
biggest silent drain — it accumulates for the whole session. Benchmarks: Anthropic reports
~$13/developer/active-day average; community write-ups show 60–72% reductions from the levers
below. What this boilerplate already does, and the dials you can turn:

**Actually automatic (working for you with no behavior required):**
- **On-demand language rules** — only the language being edited loads, not all three.
- **Small, stable base** — `CLAUDE.md` + rules are tight and unchanging, so **prompt caching**
  (~90% off repeated prefix) stays warm. Don't churn `CLAUDE.md` mid-session — it busts the cache.
- **`APP_CONTEXT.md`** — ~2 cached pages replace re-reading code/plans every session.

**Available but VOLUNTARY — and measured: it was barely happening.**
- **Dynamic model tiering** (`model-selection.md`) and **subagent isolation** (`code-reviewer`,
  `Explore`) are not enforced by anything — they only fire when the orchestrator chooses to
  delegate *and* passes a cheaper `model` (`inherit` = Opus). A June-2026 audit of two real
  projects (curio, luckytrade) found **~5,300 assistant turns, 100% on Opus, exactly one
  subagent spawn total — and that one ran on Opus too.** Result: 0% Sonnet usage account-wide.
  So the headline "Haiku ~1/15th of Opus" saving was theoretical, not realized.
- **Why:** the harness defaults to *not* spawning subagents unless asked (it treats a cold agent
  as the expensive path on subscription plans), and `model: inherit` defaults to Opus. The
  doctrine in `model-selection.md` / `agent-activation.md` was prose the model didn't follow.
- **The fix (current docs):** make the doctrine honest — default to **inline Opus**, and treat
  delegation as worth it only for **parallel fan-out** (N independent chunks → N concurrent
  Sonnet/Haiku agents, the real time+cost win) or **context isolation** (one noisy job). The
  owner's explicit standing authorization for parallel Sonnet fan-out is now written into
  `agent-activation.md`, which is what overrides the harness's don't-spawn default. A lone
  subagent for a trivial task is *not* a win and is no longer encouraged. Crucially, fan-out is
  bounded by a **non-negotiable quality floor** (`model-selection.md`): cheaper tiers only ever
  *draft* shipping code — Opus reviews everything that lands and `verify` must pass, and
  high-stakes paths (auth/crypto/payments/migrations/concurrency/money/PII) are Opus-only. So the
  time+cost win never trades away quality; worst case it's neutral.

**Orchestrator model — DECIDED: Opus stays in charge (quality-first).**
The main session runs on the `opus` alias (always the best available Opus — 4.8 today, and it
auto-tracks future Opus releases). This is a deliberate choice: the most capable model leads,
plans, and delegates *down* to Sonnet/Haiku for routine sub-tasks (`model-selection.md`). It's
the largest cost line, accepted on purpose — we buy the best decision-making at the top and save
on the work below it. The cost docs' ~40% "use Sonnet as base" cut is therefore *not* taken
here; if cost pressure ever forces it, switching the base to Sonnet (Opus on-demand) is the
lever, via `/model` or `settings.json → "model"`. (To freeze the exact version instead of
auto-tracking, pin `"model": "claude-opus-4-8"`.)

**Other dials you can turn (not hard-set — your call):**
- **Effort / thinking budget.** Thinking bills as output tokens (default budget can be tens of
  thousands). For routine work lower it: `/effort`, `effortLevel` in settings, or
  `MAX_THINKING_TOKENS=8000` (env). Keep high effort for architecture/debugging.
- **`/clear` between unrelated tasks; `/compact` within ~5 min** (while cache is warm — after
  that `/clear` is cheaper). Encoded as guidance in `context-efficiency.md`.
- **Code-intelligence (LSP) plugins** for TS/Python/PHP — symbol nav instead of grep-and-read,
  and auto type-errors after edits. Fewer file reads = fewer tokens. Add via `/plugin` (omitted
  from the committed config because availability is environment-specific).
- **Prefer CLI over MCP** (`gh`/`aws`/`gcloud`/`docker`) — MCP tool listings cost context; CLIs
  don't. Already in the allow-list and the `context-efficiency` rule.
- **Verbose-output filtering hook** (optional) — a PreToolUse Bash hook can rewrite test/log
  commands to return only failures, cutting tens of thousands of tokens to hundreds. Powerful
  but invasive (it alters commands), so it's documented, not enabled by default.

**Cost vs. autonomy — the honest tension:** running for hours unattended raises *total* spend
because Claude does more, even as cost *per unit of work* drops. The tiering + caching + context
discipline above are what keep the per-unit cost down; the orchestrator-model choice is what
caps the ceiling. Track real spend with `/usage` (it breaks down by subagent/skill/MCP).

## 6. How to update this setup (next time)

1. **Read this file first**, then make the change.
2. **Adding an agent:** create `.claude/agents/<name>.md` (`name`, detailed `description`,
   least-privilege `tools`, `model: inherit`); add it to the Team list in `CLAUDE.md`, the
   table in §3 here, and the trigger map in `rules/agent-activation.md`.
3. **Adding a slash command:** `.claude/commands/<name>.md` with a `description` +
   `argument-hint`; list it in `CLAUDE.md` → Slash commands and in §2 here.
4. **Adding a language:** `.claude/rules/<lang>.md` extending `code-style.md`; reference it in
   `CLAUDE.md` → Conventions. `/setup` now does this automatically for a non-bundled stack
   (step 2b) — the boilerplate ships Python/TS/PHP rules; anything else (Swift, Go, Rust…) gets
   a rule generated at onboarding.
5. **Changing autonomy/guardrails:** edit `permissions.deny` in `settings.json` and/or
   `validate-bash.sh`; keep `rules/autonomy.md` describing the *current* truth.
6. **Validate** after any change:
   - `cat .claude/settings.json | jq .` (valid JSON) and Claude Code's own schema check.
   - `bash -n .claude/hooks/*.sh .claude/statusline.sh` (shell syntax).
   - Agents in `.claude/agents/` match the Team list in `CLAUDE.md`.
   - All `@.claude/rules/*` imports referenced in `CLAUDE.md` resolve to real files.

## 7. Known tradeoffs / things to revisit

- Git protection lives **only in `validate-bash.sh`**, not in `permissions.deny` (which is
  absolute and was duplicating it). The hook blocks tree-wide history/work destruction
  (`reset --hard`, `clean -fdx`, `checkout -- .`, force-push to protected branches) but lets
  Claude commit/stash or scope to specific paths instead — and allows force-push on your own
  feature branches. If you ever want a hard, unconditional git block, add it back to
  `permissions.deny` in `settings.local.json`.
- `driftcheck.sh` is an intentional no-op stub — wire it per project (lint pass, leftover
  TODO/secret scan, doc-structure check) when the project has a real shape.
- Per-language rules assume common toolchains (uv/ruff, pnpm/Next App Router, Pint/Pest).
  Adjust if a project diverges.
- Hooks are synchronous. If `bats-autorun`/`driftcheck` get heavy, consider `async: true`
  (Jan-2026 feature) so they don't block the turn.
