#!/usr/bin/env bash
# Test: engine-verify.ps1 Git Bash detection (T-055, v6.14.0, issue #12)
# Shell wrapper: detects PowerShell availability and runs the .ps1 test.
#
# Validates that engine-verify.ps1 L54-97 bash detection covers:
#   1. Standard 64-bit path (C:\Program Files\Git\bin\bash.exe)
#   2. 32-bit path (C:\Program Files (x86)\Git\bin\bash.exe)
#   3. Get-Command bash (excluding WSL stub)
#   4. git --exec-path derivation
#
# Scenarios:
#   S1 (AC-3): standard path detection regression (existing behavior preserved)
#   S2 (AC-1): 32-bit Program Files (x86) path is checked
#   S3 (AC-2): git --exec-path derivation path exists in source

set -euo pipefail

echo "[test_engine_verify_bash_detection.sh] T-055 bash detection wrapper"

# Detect PowerShell
PWSH=""
if command -v pwsh >/dev/null 2>&1; then
  PWSH="pwsh"
elif command -v powershell >/dev/null 2>&1; then
  PWSH="powershell"
fi

if [ -z "$PWSH" ]; then
  echo "SKIP no PowerShell available"
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PS1_TEST="$SCRIPT_DIR/test_engine_verify_bash_detection.ps1"

if [ ! -f "$PS1_TEST" ]; then
  echo "FAIL test file not found: $PS1_TEST"
  exit 1
fi

"$PWSH" -NoProfile -File "$PS1_TEST"
