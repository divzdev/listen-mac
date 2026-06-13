---
description: Interview me about a feature, then write a self-contained SPEC.md to implement in a fresh session
argument-hint: "<brief description of the feature/change>"
---

I want to build: $ARGUMENTS

**Interview me first — do not start implementing.** Use the `AskUserQuestion` tool to dig into
the parts I haven't thought through. Cover, as relevant:

- **Scope & intent** — what problem this actually solves, and what's explicitly out of scope.
- **Technical approach** — affected files/modules, data model changes, key interfaces, the
  one or two decisions with real tradeoffs (pull in the **architect** agent's thinking if the
  design is non-trivial).
- **UX & behavior** — primary user flow, the four states (loading/empty/error/success), edge
  cases (consult **ui-ux-expert** thinking for anything user-facing).
- **Constraints** — auth/permissions, performance targets, compliance, backward compatibility.
- **Verification** — what "done" looks like and the concrete check that proves it (tests,
  command output, screenshot).

Don't ask obvious questions. Keep interviewing until the hard parts are settled.

Then write a **self-contained `SPEC.md`** that someone with zero prior context could execute:
1. Goal (1–2 sentences) and non-goals.
2. The files/interfaces involved, and the chosen approach with rationale.
3. Step-by-step implementation plan.
4. Edge cases and how each is handled.
5. An **end-to-end verification step** that proves the feature works.

Finish by telling me to **`/clear` and start a fresh session** pointing at `SPEC.md` — clean
context for implementation, with the spec as the source of truth. (Update `docs/APP_CONTEXT.md`
if this feature changes business behavior.)
