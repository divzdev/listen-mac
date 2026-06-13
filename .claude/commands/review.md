---
description: Security-first review of the current diff via the code-reviewer agent
argument-hint: "[optional: PR number, branch, or specific files]"
---

Review the pending changes: $ARGUMENTS

Delegate this to the **code-reviewer** agent (read-only). Have it:

1. Get the diff (`git diff main...HEAD`, or the named PR/branch/files) — review what changed and its blast radius, not the whole repo.
2. Review in priority order: **correctness → security (`@.claude/rules/security.md`) → data integrity → performance → maintainability (`@.claude/rules/code-style.md`)**.
3. Tag every finding **blocker / major / minor / nit**, cite `file:line`, and show the evidence + a concrete fix. One finding per comment.
4. Run the linter/type-checker/tests against the diff if available; a red build is the first finding.

When it returns, summarize: blockers first, then majors, then the rest. Do **not** apply fixes automatically — present them and let me decide, unless I asked you to fix-and-go.
