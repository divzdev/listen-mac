# TypeScript / Next.js / Tailwind

Extends `@.claude/rules/code-style.md`. Applies when editing `*.ts`, `*.tsx`, `*.jsx`.

## TypeScript

- **`strict: true`**, plus `noUncheckedIndexedAccess` and `noImplicitOverride`. No `any` —
  use `unknown` + narrowing. No non-null `!` to silence the compiler; fix the type.
- `type` for unions/aliases, `interface` for object contracts you expect others to extend.
- Discriminated unions over boolean flags. Brand IDs (`type UserId = string & {…}`) where
  mixing them would be a bug. `as const` for literal tuples/enums-as-objects.
- camelCase values, PascalCase types/components, SCREAMING_SNAKE module constants.
- **Zod** at every boundary (API input, env, form data). Infer types from schemas — schema is
  the source of truth. `.strict()` to reject unknown keys.
- pnpm. Pin exact versions. ESLint + Prettier; fix on save.

## Next.js (App Router)

- **Server Components by default.** Add `"use client"` only when you need state, effects, or
  browser APIs — push it as far down the tree as possible.
- Data fetching in Server Components / Route Handlers / Server Actions. Never expose secrets
  to client bundles (no secret in `NEXT_PUBLIC_*`).
- `loading.tsx` / `error.tsx` for every route segment. Handle all four async states.
- Server Actions validate input with Zod and re-check authorization inside the action — the
  route boundary is not enough.
- Use `next/image`, `next/font`; stream with Suspense; cache deliberately (know your
  `revalidate` / `cache` settings).

## React

- Components are functions of state; derive, don't sync. Server state via TanStack Query /
  SWR; local state for UI only; global store only when truly shared.
- `key` on lists must be stable and unique (not the array index). Memoize only with a measured
  cause.

## Tailwind

- Utility-first; extract to a component (not `@apply` soup) when a pattern repeats. Drive
  spacing/color from the theme/tokens — no magic hex values or arbitrary `[13px]` unless
  unavoidable.
- Mobile-first responsive prefixes. Respect `prefers-reduced-motion`. Keep contrast ≥ 4.5:1
  (coordinate with `ui-ux-expert`). `clsx`/`cva` for conditional classes, not string concat.

## Tests

- Vitest + Testing Library. Query by role/label (accessible queries), not test IDs by default.
- Mock at the network boundary (MSW), not your own modules. Playwright for E2E golden paths.
