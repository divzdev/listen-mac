# Code style

Universal principles. Override per-language as needed in language-specific subfiles.

## Naming

- Names describe **what something is**, not how it's used. `user`, not `userData`. `fetchUser`, not `getUserHelper`.
- Booleans read like assertions: `isActive`, `hasPermission`, `canDelete`. Not `active`, `permission`, `delete`.
- No abbreviations except universally recognized ones (`id`, `url`, `http`, `db`). `usr`, `cnt`, `mgr` are not.
- Constants `SCREAMING_SNAKE`, types/classes `PascalCase`, everything else `camelCase` (JS/TS) or `snake_case` (Python/Go-internal).

## Functions

- One thing per function. If you need "and" to describe what it does, split it.
- Cyclomatic complexity ≤ 10. Nesting ≤ 3 levels — extract or invert early returns.
- Pure where possible. Side effects at the edges, logic in the middle.
- Function length: aim for ≤ 40 lines. Hard ceiling 80. Above that, refactor.

## Files & modules

- Files ≤ 400 lines. Above that, the module is doing too much.
- One default export per file. Group related exports in a barrel only at package boundaries.
- Organize by **feature**, not by file type. `users/` not `models/`, `controllers/`, `views/`.

## Comments

- Default to no comments. Names should carry the meaning.
- Only write a comment when the **why** is non-obvious: a hidden constraint, a subtle invariant, a workaround for a specific bug, a future-reader trap.
- Never explain **what** the code does. Never reference the current task/PR ("added for feature X") — that rots.
- Public APIs get docstrings. Internal code does not.

## Errors

- Fail loud at the boundary, gracefully in the middle.
- Don't catch what you can't handle. Re-raise with context if you must.
- Never silently swallow errors. `try { ... } catch {}` is a bug.
- Error messages name the offending value: `"user_id must be UUID, got: \"abc\""`, not `"invalid input"`.

## State

- Immutability by default. Mutation is a code smell unless performance demands it.
- No globals. No singletons unless the runtime forces them.
- Make illegal states unrepresentable (discriminated unions, branded types, NOT-NULL columns).

## Dependencies

- Prefer standard library / built-ins.
- Adding a dep needs justification: what does it save us, how big is it, when did we last update it, who maintains it.
- Pin exact versions in app code. Range versions in libraries.
