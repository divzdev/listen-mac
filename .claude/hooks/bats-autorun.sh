#!/usr/bin/env bash
# PostToolUse hook: run BATS shell tests after Edit/Write if any exist.
# No-op when BATS isn't installed or no .bats files are present.
# Exit 2 on test failure to surface the failure back to Claude.
set -u

command -v bats >/dev/null 2>&1 || exit 0

bats_files=()
while IFS= read -r f; do
  bats_files+=("$f")
done < <(find tests test 2>/dev/null -type f -name "*.bats" -maxdepth 3 2>/dev/null)

[ "${#bats_files[@]}" -eq 0 ] && exit 0

if ! out=$(bats "${bats_files[@]}" 2>&1); then
  printf 'BATS tests failed after edit:\n%s\n' "$out" >&2
  exit 2
fi
exit 0
