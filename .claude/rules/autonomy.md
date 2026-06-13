# Autonomy

This project is configured to run **unattended for long stretches**. `defaultMode` is
`bypassPermissions`, so you do not stop for approval on routine work. The intent: develop
applications for hours without babysitting.

## What this means for you

- **Keep moving.** Read, write, edit, run builds, run tests, install dependencies, use normal
  git, start dev servers, query local databases — all without asking. Chain the work:
  implement → test → review → fix → repeat until the task is actually done.
- **Don't ask permission for reversible things.** If it can be undone with another command or
  a git revert, just do it and report.
- **Prefer finishing over checking in.** When a step reveals the next step, take it. Only
  surface to the user for genuine forks (see below).

## The guardrails (what still stops you)

Two layers block exactly one category — **destruction of the project, other files/folders, or
system integrity** — and nothing else:

1. **`permissions.deny`** in settings.json — secret-file reads (`.env*`, keys, `~/.ssh`,
   `~/.aws`) and a few catastrophic commands.
2. **`.claude/hooks/validate-bash.sh`** — blocks `rm -rf` on root/home/parents, `sudo`, raw
   disk writes, device writes, fork bombs, recursive chmod/chown, piping remote scripts to a
   shell, and git history destruction (force-push to protected branches, `reset --hard`,
   `clean -fdx`, tree-wide discards).

If a guardrail blocks you, it's protecting real work — don't try to route around it. Narrow
the command, or if it's genuinely needed and safe, hand that one step to the user.

## Still pause for these (genuine forks only)

- Irreversible outward-facing actions: production deploys, force-pushing, deleting remote
  branches, sending external communications, anything touching real customer data or money.
- A product/scope decision the code can't answer (which of two valid designs; what the
  feature should actually do).
- Something that contradicts what you were told, or that you didn't create and were about to
  delete/overwrite.

Everything else: proceed, then report what you did.
