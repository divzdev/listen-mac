#!/usr/bin/env bash
# PostToolUse hook: auto-format the file Claude just edited, using whatever formatter the
# project already has. Silent on success (no tokens added to context); only speaks on error.
# No-op when the formatter isn't installed — so it's safe in any project.
#
# Why: deterministic formatting means Claude never spends tokens hand-fixing style, and diffs
# stay clean during long unattended runs.
set -u

input=$(cat)
file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -z "$file" ] || [ ! -f "$file" ] && exit 0

have() { command -v "$1" >/dev/null 2>&1; }
run() { "$@" >/dev/null 2>&1 || true; }   # formatting must never block the edit

case "$file" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.json|*.css|*.scss|*.md|*.html|*.yaml|*.yml)
    if have prettier; then run prettier --write "$file"
    elif have npx; then run npx --no-install prettier --write "$file"; fi ;;
  *.py)
    if have ruff; then run ruff format "$file"; run ruff check --fix "$file"
    elif have black; then run black -q "$file"; fi ;;
  *.php)
    if have pint; then run pint "$file"
    elif [ -x vendor/bin/pint ]; then run vendor/bin/pint "$file"; fi ;;
  *.go)
    have gofmt && run gofmt -w "$file" ;;
  *.rs)
    have rustfmt && run rustfmt "$file" ;;
esac

exit 0
