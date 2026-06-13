#!/usr/bin/env bash
# Status line: model + current dir + git branch + app-context freshness.
# Reads JSON from stdin (Claude Code provides model.display_name, workspace.current_dir,
# transcript_path, etc.). All git work is best-effort and silent when unavailable.
set -u

input=$(cat)
model=$(printf '%s' "$input" | jq -r '.model.display_name // "Claude"' 2>/dev/null)
raw_dir=$(printf '%s' "$input" | jq -r '.workspace.current_dir // "."' 2>/dev/null)
dir="${raw_dir/#$HOME/~}"

branch=""
ctx=""
if cd "$raw_dir" 2>/dev/null && git rev-parse --git-dir >/dev/null 2>&1; then
  b=$(git symbolic-ref --quiet --short HEAD 2>/dev/null)
  [ -n "$b" ] && branch=" ($b)"

  # App-context freshness: warn when source has been committed more recently than
  # docs/APP_CONTEXT.md, i.e. the business summary may have drifted. Zero token cost.
  if [ -f docs/APP_CONTEXT.md ]; then
    last_ctx=$(git log -1 --format=%ct -- docs/APP_CONTEXT.md 2>/dev/null)
    last_code=$(git log -1 --format=%ct -- '*.py' '*.ts' '*.tsx' '*.jsx' '*.php' 2>/dev/null)
    if [ -n "${last_ctx:-}" ] && [ -n "${last_code:-}" ] && [ "$last_code" -gt "$last_ctx" ]; then
      ctx=" ⚠ctx-stale"
    fi
  fi
fi

printf '[%s] %s%s%s' "$model" "$dir" "$branch" "$ctx"
