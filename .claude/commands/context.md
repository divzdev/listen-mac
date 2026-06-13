---
description: Create or refresh docs/APP_CONTEXT.md — the tight, always-loaded business/domain summary
argument-hint: "[optional: area that changed, e.g. 'billing' or 'new returns flow']"
---

Maintain the application context doc at `docs/APP_CONTEXT.md`. Focus, if given: $ARGUMENTS

This doc is loaded into every session, so its job is to let Claude understand the business
**without** re-reading planning docs or the whole codebase. Keep it a **summary**, under ~200
lines. Prefer editing/compressing over appending.

**Efficiency:** this is summarization, not reasoning-heavy work — run the heavy reading on a
**cheap model** (delegate the codebase/doc skim to the built-in Explore agent or a Haiku/Sonnet
subagent, see `@.claude/rules/model-selection.md`), then write the concise result yourself.

### If `docs/APP_CONTEXT.md` is still a STUB or missing
Bootstrap it: read `CLAUDE.md`, any `docs/*PLAN*`/`README`, and skim the codebase structure
(routes, models, core services) to infer the domain. Fill the template's sections with **real,
terse** content. Don't invent business rules you can't find — list unknowns under "Open
questions" instead.

### If it already has real content (a refresh)
1. Get what changed since the last update: `git log` / `git diff` since the date in the header
   (and anything the user flagged in $ARGUMENTS).
2. Update only the sections whose **business meaning** changed — new entities, changed rules,
   new/removed flows, resolved open questions (fold decisions into the body, then delete the
   question).
3. **Re-summarize and compress.** Remove anything now obvious from code/tests, anything stale,
   and any implementation detail that crept in. If over budget, tighten wording until it fits.
4. Update the "Last meaningful update" date.

### Always
- Keep the maintenance-contract comment at the top intact.
- No dated changelog, no task history, no how-to-build steps — those belong elsewhere.
- Every line must earn its permanent token cost. When in doubt, cut it.

Report a one-line summary of what business knowledge changed (or "bootstrapped from scratch").
