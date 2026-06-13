---
description: Run the test suite, diagnose failures, and fix them (or the code) until green
argument-hint: "[optional: path, pattern, or feature to focus on]"
---

Run and green the tests: $ARGUMENTS

1. **Discover** the test command from CLAUDE.md / package.json / Makefile / pyproject. Run the relevant subset if a focus was given, else the full suite.
2. **Read failures carefully.** For each failure decide: is the **test** wrong (stale expectation) or is the **code** wrong (real bug)? State which, with evidence — don't just make red go green.
3. **Fix the right thing.** Repair the code for real bugs; update the test only when the expectation genuinely changed. Never delete or `skip` a test to pass.
4. **Strengthen coverage** per `@.claude/rules/testing.md`: if you touched a code path with weak coverage, add the missing edge cases (empty, boundary, error path).
5. **Determinism.** No `sleep`-based waits, no unseeded randomness, no order-dependence. Fix flakiness rather than retrying.
6. Re-run until green. Report what failed, why, and what you changed.

For a broader test-strategy or edge-case pass, delegate to the **qa-engineer** agent.
