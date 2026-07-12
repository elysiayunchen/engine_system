# Project-custom Doctor check: all VERSION files must agree.
# Called by engine-doctor.ps1 after built-in checks.
# Exit 0 = PASS, non-zero = FAIL (stdout becomes the message).

$ErrorActionPreference = "Stop"
$Root = Resolve-Path "$PSScriptRoot\..\.."
$v1 = Join-Path $Root "VERSION"
$v2 = Join-Path $Root "engine\VERSION"
$v3 = Join-Path $Root "plugin\VERSION"

$versions = @{}
foreach ($f in @($v1, $v2, $v3)) {
  if (-not (Test-Path $f)) {
    Write-Output "MISSING: $f does not exist"
    exit 1
  }
  $versions[$f] = (Get-Content $f -Raw -Encoding UTF8).Trim()
}

if ($versions[$v1] -ne $versions[$v2]) {
  Write-Output "VERSION mismatch: root=$($versions[$v1]) engine=$($versions[$v2])"
  exit 1
}

if ($versions[$v1] -ne $versions[$v3]) {
  Write-Output "VERSION mismatch: root=$($versions[$v1]) plugin=$($versions[$v3])"
  exit 1
}

Write-Output "VERSION consistent: $($versions[$v1])"
exit 0
