#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail() { echo "FAIL: $*" >&2; exit 1; }

grep -Fq 'ensure_powershell_on_path' "$REPO_ROOT/engine/scripts/engine-verify.sh" || fail 'PowerShell resolver missing'
grep -Fq '[ -f "$dir/pwsh.exe" ]' "$REPO_ROOT/engine/scripts/engine-verify.sh" || fail 'PowerShell resolver must support WSL mounted .exe files'
grep -Fq 'ENGINE_PWSH_CMD' "$REPO_ROOT/engine/scripts/engine-verify.sh" || fail 'PowerShell resolver must rewrite extensionless pwsh tokens'
cmp -s "$REPO_ROOT/engine/scripts/engine-verify.sh" "$REPO_ROOT/plugin/engine/scripts/engine-verify.sh" || fail 'verify mirror drift'

# In Windows Git Bash/WSL, pwsh may only be reachable through the mounted
# PowerShell installation. Exercise the real Bash verifier against T-080.
output="$(cd "$REPO_ROOT" && bash engine/bin/engine verify T-080 2>&1)" || {
  printf '%s\n' "$output" >&2
  fail 'Bash verifier could not execute the Windows-facing AC commands'
}
printf '%s\n' "$output" | grep -Fq 'T-080: 8 pass, 0 fail' || {
  printf '%s\n' "$output" >&2
  fail 'Bash verifier did not report 8/8 after PowerShell resolution'
}

echo 'PASS test_verify_shell_resolution.sh'
