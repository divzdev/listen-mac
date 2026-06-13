---
description: Restructure code safely — behavior-preserving, test-guarded, with impact analysis
argument-hint: "<target file/module/function and the goal>"
---

Refactor with a safety net: $ARGUMENTS

Refactoring changes structure, **never behavior**. Enforce that:

1. **Baseline.** Confirm tests exist and pass for the target. If coverage is thin, write characterization tests **first** so you can detect behavior drift. Don't refactor untested code blind.
2. **Impact analysis.** Find every caller/usage of what you're changing (Grep the symbol). List the blast radius before touching anything.
3. **Small steps.** Make incremental, reversible changes — rename, extract, inline, dedupe. Run tests after each step. Keep the diff reviewable.
4. **Hold behavior constant.** Same inputs → same outputs, same side effects, same errors. If you find a bug mid-refactor, note it separately — don't fix it in the same change.
5. **Verify.** Full test suite + linter + type-check green at the end.

Apply `@.claude/rules/code-style.md`. Report what changed structurally and confirm behavior is unchanged. For large/architectural restructures, consult the **architect** agent first.
