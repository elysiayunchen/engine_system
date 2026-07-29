# Test: engine-verify.ps1 env var cleanup + recursion guard (T-053, v6.13.1)
#
# Validates the fix replacing `Remove-Item Env:VAR` with .NET
# `[Environment]::SetEnvironmentVariable(VAR, $null, 'Process')`:
#   (1) AC-3: .NET method clears the env var (no leftover).
#   (2) AC-4: recursion guard still works - when GUARD matches the task,
#       engine-verify.ps1 exits 0 immediately without running ACs.
#
# Compatible with Windows PowerShell 5.1 (no pwsh-only syntax).

$ErrorActionPreference = "Stop"
$Root = $env:CLAUDE_PROJECT_DIR
if (-not $Root) { $Root = $PWD.Path }

$VerifyScript = Join-Path $Root "engine\scripts\engine-verify.ps1"
if (-not (Test-Path $VerifyScript)) {
  Write-Output "FAIL: engine-verify.ps1 not found at $VerifyScript"
  exit 1
}

$passCount = 0
$failCount = 0

function Pass($name) {
  Write-Output "PASS  $name"
  $script:passCount++
}
function Fail($name, $detail) {
  Write-Output "FAIL  $name - $detail"
  $script:failCount++
}

Write-Output "[test_engine_verify_env_cleanup.ps1] T-053 env cleanup + recursion guard"

# --- AC-3: .NET SetEnvironmentVariable clears the env var ---
try {
  $env:ENGINE_VERIFY_RECURSE_GUARD = "test-sentinel-value"
  if (-not $env:ENGINE_VERIFY_RECURSE_GUARD) {
    Fail "AC-3a setup" "could not set env var"
  } else {
    [Environment]::SetEnvironmentVariable('ENGINE_VERIFY_RECURSE_GUARD', $null, 'Process')
    if ($env:ENGINE_VERIFY_RECURSE_GUARD) {
      Fail "AC-3 env-cleared" "env var still set: '$($env:ENGINE_VERIFY_RECURSE_GUARD)'"
    } else {
      Pass "AC-3 env-cleared"
    }
  }
} finally {
  [Environment]::SetEnvironmentVariable('ENGINE_VERIFY_RECURSE_GUARD', $null, 'Process')
}

# --- AC-4: recursion guard - same task exits 0 immediately ---
# Set GUARD to T-052, then run engine-verify.ps1 -Task T-052.
# The script should hit line 32-34 and exit 0 without running any ACs.
try {
  $env:ENGINE_VERIFY_RECURSE_GUARD = "T-052"
  $output = & powershell.exe -NoProfile -File $VerifyScript -Task T-052 2>&1 | Out-String
  $rc = $LASTEXITCODE
  # When recursion guard triggers, output should NOT contain AC verify lines.
  # It may contain the header "[Engine System behavior verify] T-052" (line 51
  # runs before the guard check at line 32? No - guard check is at line 32-34,
  # BEFORE the header at line 51. So output should be empty.
  if ($rc -ne 0) {
    Fail "AC-4 recursion-exit0" "expected exit 0, got $rc; output: $output"
  } elseif ($output -match '^-- AC-') {
    Fail "AC-4 no-ac-output" "recursion guard should skip ACs, but got AC output: $output"
  } else {
    Pass "AC-4 recursion-guard"
  }
} finally {
  [Environment]::SetEnvironmentVariable('ENGINE_VERIFY_RECURSE_GUARD', $null, 'Process')
}

# --- Summary ---
Write-Output ""
Write-Output "=========================================="
Write-Output "PASS=$passCount  FAIL=$failCount"
if ($failCount -gt 0) { exit 1 } else { exit 0 }
