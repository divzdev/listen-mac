# Context efficiency

Context is the scarce resource: performance degrades and cost rises as it fills, and tool
output is the biggest silent drain — every file read and command result stays in context for
the rest of the session. Keep the working set small.

## Reading & searching

- **Read what you need, not whole files.** Target the relevant lines/functions. Don't `cat`
  large files or dump whole directories.
- **Grep for failures, don't scroll output.** For logs/test runs, filter to what matters
  (`grep -E 'FAIL|ERROR' | head`) instead of pulling thousands of lines into context.
- **Delegate noisy investigation to a subagent** (or the built-in **Explore** agent). Reading
  many files to answer "how does X work" belongs in a separate context that returns only the
  summary — see `@.claude/rules/agent-activation.md`.
- **Scope investigations.** "Investigate the auth flow in `src/auth/`" not "investigate the
  codebase." Unscoped exploration reads hundreds of files and fills context.

## Working

- **Plan mode for the uncertain or multi-file**; skip it when you could describe the diff in
  one sentence (typo, log line, rename). Planning prevents expensive wrong-direction rework,
  but it has overhead — match it to the task.
- **Course-correct early.** If an approach is failing, stop and rethink rather than piling
  more attempts into context. Two failed tries on the same thing means the context is polluted
  — restate the problem cleanly.
- **Verify with a check, show the evidence.** Prefer a signal you can read (test/build/lint
  exit, a diff against a fixture) over asserting "done." Paste the result, don't re-describe it.

## Tools & integrations

- **Prefer CLI tools over MCP** for external services (`gh`, `aws`, `gcloud`, `docker`,
  `psql`) — they're far more context-efficient than MCP tool listings. Reach for MCP only when
  no good CLI exists.
- **Keep the always-loaded base small.** `CLAUDE.md` + eagerly-imported rules cost tokens every
  turn. Language-specific and occasional guidance is read on demand, not `@`-imported — keep it
  that way.

## For the human (surfaced so Claude can suggest it)

- `/clear` between unrelated tasks; a fresh session with a sharp prompt beats a long polluted
  one. `/compact` works cheapest within ~5 min while the cache is warm.
- Keep `CLAUDE.md` stable during a session — editing it busts the prompt cache for the whole
  prefix.
