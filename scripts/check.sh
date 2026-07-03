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

step "Hook parity (sh vs ps1 gatekeeper decisions)"
if bash tests/hook-parity/run-parity.sh; then
  pass "stop-hook + pre-commit parity fixtures"
else
  fail "hook parity"
fi

step "Task card gate (WRITE-SET / FORBIDDEN / decision reference)"
if bash tests/task-card/run-task-tests.sh; then
  pass "task card gate fixtures"
else
  fail "task card gate"
fi

step "Fractal memory (federation routing + L2 assembly)"
if bash tests/fractal-memory/run-fractal-tests.sh; then
  pass "fractal memory fixtures"
else
  fail "fractal memory"
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

step "Web prompt entrypoint"
root_prompts="$(find . -maxdepth 1 -type f -name 'ENGINE_FILE_SYSTEM*' 2>/dev/null | sed 's#^\./##' | sort)"
unexpected_root_prompts="$(printf '%s\n' "$root_prompts" | grep -vx 'ENGINE_FILE_SYSTEM_v5.md' || true)"
if [[ -f "ENGINE_FILE_SYSTEM_v5.md" && -z "$unexpected_root_prompts" ]]; then
  pass "single active root web prompt"
else
  fail "root must contain only ENGINE_FILE_SYSTEM_v5.md as active web prompt"
  printf '%s\n' "$root_prompts" | sed 's/^/  root prompt: /'
fi

for archived_prompt in \
  ENGINE_FILE_SYSTEM_v4_legacy.txt \
  ENGINE_FILE_SYSTEM_v5.2.md \
  ENGINE_FILE_SYSTEM_v5.5.md
do
  if [[ -f "archive/engine-file-system/$archived_prompt" ]]; then
    pass "archived prompt exists: $archived_prompt"
  else
    fail "archived prompt missing: $archived_prompt"
  fi
done

if [[ "$failures" -gt 0 ]]; then
  printf '\nCHECK FAILED: %s issue(s)\n' "$failures" >&2
  exit 1
fi

printf '\nCHECK PASSED\n'
