---
description: Stage, commit, and optionally push using Conventional Commits with a clean message
argument-hint: "[optional: extra context or 'push']"
---

You are handling version control. Extra context: $ARGUMENTS

1. Run `git status` and `git diff` (and `git diff --staged`) to see exactly what changed.
2. Group the changes into one or more **logical** commits — don't bundle unrelated work. If everything is one concern, one commit is fine.
3. Stage files **explicitly** by path (never blanket-stage). Confirm no secrets, `.env*`, keys, or large artifacts are included; if you see any, stop and report.
4. Write each message as a [Conventional Commit](https://www.conventionalcommits.org): `type(scope): summary` where type ∈ feat|fix|chore|refactor|test|docs|perf|build|ci. Imperative mood, ≤ 72-char subject, body explaining the **why** when non-obvious.
5. If on `main`/`master`/`production`, create a feature branch first.
6. Commit. Only push if the user said "push" (or asked) — and never force-push a protected branch.

End the commit message with the standard co-author trailer for this environment. Report the commit SHA(s) and branch.
