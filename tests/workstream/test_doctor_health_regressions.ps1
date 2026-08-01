$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path

function Assert-Contains([string]$Path, [string]$Needle) {
  $content = Get-Content -Raw -LiteralPath $Path -Encoding UTF8
  if (-not $content.Contains($Needle)) { throw "$Path does not contain: $Needle" }
}

$map = Join-Path $repoRoot "engine\ENGINE_MAP.md"
foreach ($row in @(
  "engine/scripts/engine-review-agent.sh",
  "engine/scripts/engine-review-agent-package.sh",
  "engine/scripts/engine-review-agent-validate.sh",
  "engine/scripts/engine-gate.sh",
  "engine/scripts/engine-gate.ps1"
)) { Assert-Contains $map "| $row |" }
if ((Get-Content -Raw -LiteralPath $map -Encoding UTF8) -match '\| tool \|') { throw "ENGINE_MAP still contains unsupported class tool" }
Assert-Contains $map '| engine/gate/config.json | gates + policy | mixed |'

foreach ($task in @('T-075', 'T-076', 'T-077')) {
  if (-not (Test-Path (Join-Path $repoRoot "engine\tasks\$task\progress.md"))) { throw "$task progress anchor missing" }
}
if (Test-Path (Join-Path $repoRoot 'engine\tasks\T-078\progress.md')) { throw 'T-078 live progress was not archived' }
if (-not (Test-Path (Join-Path $repoRoot 'engine\archive\tasks\T-078-progress.md'))) { throw 'T-078 progress archive missing' }

$inventory = Join-Path $repoRoot 'engine\domains\project-meta\INVENTORY.md'
foreach ($path in @(
  'tests/workstream/test_review_agent_cli.sh',
  'tests/workstream/test_review_agent_package.sh',
  'tests/workstream/test_review_agent_validate.sh',
  'tests/workstream/test_review_agent_config.sh',
  'tests/workstream/test_review_agent_mirror.sh',
  'docs/superpowers/specs/2026-07-31-agent-reviewer-design.md',
  'tests/workstream/test_review_agent_gate.sh',
  'tests/workstream/test_doctor_agent_review.sh',
  'tests/workstream/test_review_agent_grounded.sh',
  'tests/workstream/test_review_agent_dynamic.sh',
  'tests/workstream/test_prove_infer.sh',
  'tests/workstream/test_prove_execute.sh',
  'tests/workstream/test_acceptance_preflight.sh',
  'tests/workstream/test_acceptance_preflight.ps1'
)) { Assert-Contains $inventory "| $path |" }

Assert-Contains (Join-Path $repoRoot 'engine\scripts\engine-doctor.ps1') 'Prefer an existing project-root path'
Assert-Contains (Join-Path $repoRoot 'engine\scripts\engine-verify.sh') 'ensure_powershell_on_path'
Assert-Contains (Join-Path $repoRoot 'engine\scripts\engine-drift-check.sh') 'historical_snapshot=0'
Assert-Contains (Join-Path $repoRoot 'engine\scripts\engine-drift-check.ps1') '$historicalSnapshot = $false'
Assert-Contains (Join-Path $repoRoot 'engine\scripts\engine-drift-check.ps1') 'array membership rather than HashSet constructors'
$driftPsHash = (Get-FileHash (Join-Path $repoRoot 'engine\scripts\engine-drift-check.ps1') -Algorithm SHA256).Hash
$driftPsPluginHash = (Get-FileHash (Join-Path $repoRoot 'plugin\engine\scripts\engine-drift-check.ps1') -Algorithm SHA256).Hash
if ($driftPsHash -ne $driftPsPluginHash) { throw 'Drift PowerShell mirrors differ' }
Write-Output 'PASS test_doctor_health_regressions.ps1'
