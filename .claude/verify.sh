#!/usr/bin/env bash
# Fast verification gate, run by the Stop hook (.claude/hooks/driftcheck.sh) on every finish.
# Keep it FAST (typecheck/lint) — NOT the full app build or E2E. Exit non-zero on failure.
#
# This project's fast check = compile the pure-logic ListenCore package (typechecks all the
# cleanup / command / style / snippet / LLM logic against the WhisperKit API). Incremental
# builds run in ~20s; the heavy WhisperKit dependency is resolved/cached after the first build.
# The full macOS app (xcodebuild ListenMac scheme) is intentionally excluded — too slow for a gate.
set -euo pipefail

cd "$(dirname "$0")/.."

# Lint if a Swift linter is installed (no-op otherwise — none configured yet).
if command -v swiftlint >/dev/null 2>&1; then
  swiftlint lint --quiet
fi

# Typecheck the core logic package.
( cd Packages/ListenCore && swift build )
