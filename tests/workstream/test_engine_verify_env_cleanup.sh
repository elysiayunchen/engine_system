#!/usr/bin/env bash
# Test runner: engine-verify.ps1 env cleanup + recursion guard (T-053, v6.13.1)
#
# Finds PowerShell (pwsh or powershell.exe) and runs the .ps1 test.
# SKIPs if no PowerShell is available on this host.
# This mirrors the SKIP pattern in tests/hook-parity/run-parity.sh.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PS1_TEST="$ROOT/tests/workstream/test_engine_verify_env_cleanup.ps1"

# Find PowerShell
PS_BIN=""
if command -v pwsh >/dev/null 2>&1; then
  PS_BIN="pwsh"
elif command -v powershell >/dev/null 2>&1; then
  PS_BIN="powershell"
elif command -v powershell.exe >/dev/null 2>&1; then
  PS_BIN="powershell.exe"
fi

if [ -z "$PS_BIN" ]; then
  echo "SKIP  ps1  test_engine_verify_env_cleanup (no PowerShell on this host)"
  exit 0
fi

echo "=== engine-verify env cleanup (ps1) ==="
"$PS_BIN" -NoProfile -File "$PS1_TEST"
rc=$?
if [ $rc -eq 0 ]; then
  echo "PASS  ps1  engine-verify-env-cleanup"
else
  echo "FAIL  ps1  engine-verify-env-cleanup (exit=$rc)"
fi
exit $rc
