# v6.0 migration step - delegates to engine-migrate-contract.ps1
#
# v6.0 introduced:
#   - v6 data-layer dirs (tasks/decisions/domains/changes/evidence/.cache)
#   - federation table (engine/domains/federation.json)
#   - decision rules baseline (engine/decisions/rules.json)
#   - local VERSION stamp (engine/VERSION)
#   - v6 contract block (task card headers / decision ledger / fractal memory /
#     three-layer gate / contract compile / cockpit / N1-N5)
#
# This step is idempotent. It is the first versioned step. Future versions
# (v6.1+) will add sibling scripts; `engine migrate` applies all steps newer
# than the local engine/VERSION in order.
#
# Path note: this script may live under plugin/migrations/ (dev tree) or
# engine/migrations/ (installed project). It probes candidate locations.

$ErrorActionPreference = "Stop"

param(
  [string]$Root = $(if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (Get-Location).Path })
)

$Dir = Split-Path -Parent $MyInvocation.MyCommand.Path

$migrator = $null
foreach ($candidate in @(
  (Join-Path $Dir "..\scripts\engine-migrate-contract.ps1"),
  (Join-Path $Dir "..\engine\scripts\engine-migrate-contract.ps1"),
  (Join-Path $Dir "engine-migrate-contract.ps1")
)) {
  if (Test-Path $candidate) { $migrator = $candidate; break }
}

if (-not $migrator) {
  Write-Error "Error: engine-migrate-contract.ps1 not found near $Dir."
  exit 1
}

& $migrator -Root $Root
exit $LASTEXITCODE
