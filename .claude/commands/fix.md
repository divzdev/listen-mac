---
description: Root-cause a bug and apply the smallest correct fix, with a regression test
argument-hint: "<bug description, error, or failing test>"
---

Fix this, properly: $ARGUMENTS

Work the problem in order — do not jump to a patch:

1. **Reproduce.** Find or write the smallest reproduction (a failing test is ideal). If you can't reproduce, say so and list what you'd need.
2. **Diagnose the root cause.** Trace from symptom to source. State the actual cause in one sentence: "X happens because Y." Don't fix a symptom you can't explain.
3. **Fix minimally.** Change the least code that addresses the root cause. No opportunistic refactors, no scope creep — match the scale of the bug.
4. **Prove it.** Add/adjust a regression test that fails before and passes after. Run the test suite and the linter.
5. **Report.** Root cause, the fix, the test, and any related spots that share the same bug (flag them; don't silently fix unless trivial).

If the fix is risky or touches auth/payments/migrations, delegate a review to the **code-reviewer** agent before declaring done.
