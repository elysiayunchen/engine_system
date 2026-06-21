#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(pwd)}"
failures=0

step() {
  printf '\n== %s ==\n' "$1"
}

pass() {
  printf 'PASS %s\n' "$1"
}

fail() {
  failures=$((failures + 1))
  printf 'FAIL %s\n' "$1" >&2
}

cd "$ROOT"

step "Engine Doctor"
if bash engine/scripts/engine-doctor.sh .; then pass "project doctor"; else fail "project doctor"; fi
if bash plugin/engine/scripts/engine-doctor.sh --package-mode plugin; then pass "plugin package doctor"; else fail "plugin package doctor"; fi

step "Shell syntax"
if find . -name '*.sh' -o -path '*/githooks/pre-commit' | sort | while read -r file; do bash -n "$file"; done; then
  pass "all shell scripts"
else
  fail "shell syntax"
fi

step "PowerShell syntax"
if command -v pwsh >/dev/null 2>&1; then
  if pwsh -NoProfile -File scripts/check.ps1 -Root "$PWD"; then
    pass "PowerShell + full checks"
  else
    fail "PowerShell + full checks"
  fi
else
  pass "pwsh unavailable, skipped PowerShell parse"
fi

if [[ "$failures" -gt 0 ]]; then
  printf '\nCHECK FAILED: %s issue(s)\n' "$failures" >&2
  exit 1
fi

printf '\nCHECK PASSED\n'
