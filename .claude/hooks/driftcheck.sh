#!/usr/bin/env bash
# Stop hook: the verification gate. Closes the loop so unattended runs finish *correct*, not
# just "looks done" (the #1 Claude Code best practice).
#
# It runs the project's own fast check, `.claude/verify.sh`, if that file exists. Keep that
# script FAST (typecheck/lint, not the full E2E suite) — it runs every time Claude tries to
# stop. Exit 2 feeds failures back so Claude fixes them before ending; Claude Code caps this at
# 8 consecutive blocks, so it can't loop forever. No verify.sh ⇒ no-op (safe default).
#
# To enable: create .claude/verify.sh that exits non-zero on failure, e.g.
#   #!/usr/bin/env bash
#   npm run -s typecheck && npm run -s lint        # JS/TS
#   # ruff check . && mypy .                        # Python
#   # vendor/bin/phpstan analyse --no-progress -q   # PHP/Laravel
set -u

[ -f .claude/verify.sh ] || exit 0

# `timeout` isn't on macOS by default; use it (or coreutils' gtimeout) when present, else run bare.
if command -v timeout >/dev/null 2>&1; then TO="timeout 120"
elif command -v gtimeout >/dev/null 2>&1; then TO="gtimeout 120"
else TO=""; fi

if ! out=$($TO bash .claude/verify.sh 2>&1); then
  printf 'Verification gate (.claude/verify.sh) failed — fix before finishing:\n%s\n' "$out" >&2
  exit 2
fi
exit 0
