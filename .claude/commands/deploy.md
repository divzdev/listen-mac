---
description: Run the pre-deployment checklist and ship only if every gate is green
argument-hint: "[target environment, e.g. staging | production]"
---

Pre-deploy gate for: $ARGUMENTS

Do **not** deploy until every gate passes. Stop and report at the first red one.

1. **Clean tree** — no uncommitted changes; on the intended branch; up to date with remote.
2. **Tests** — full suite green (unit + integration). E2E smoke for production.
3. **Build** — production build succeeds with no errors/warnings that matter.
4. **Lint / type-check** — clean.
5. **Security** — `npm audit` / `pip-audit` (or equivalent) shows no new high/critical; no secrets in the diff; new env vars documented and present in the target's secret store.
6. **Migrations** — reviewed, reversible, and safe to run against live data (no destructive drops without a backfill plan).
7. **Observability** — logs/metrics/alerts cover the new code paths.
8. **Rollback** — state the exact rollback step for this deploy in one line.

If all green, run the project's deploy command (from CLAUDE.md). For production or anything irreversible, summarize the checklist and **confirm with me before executing**. For infra/pipeline depth, consult the **devops-engineer** agent.
