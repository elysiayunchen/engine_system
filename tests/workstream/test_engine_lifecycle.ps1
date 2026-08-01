# T-079: PowerShell lifecycle mirror and parser smoke test.

$ErrorActionPreference = 'Stop'
$Root = Split-Path (Split-Path $PSScriptRoot)
$pass = 0
$fail = 0

function Assert-True {
  param([string]$Name, [bool]$Condition)
  if ($Condition) { Write-Output "PASS  $Name"; $script:pass++ }
  else { Write-Output "FAIL  $Name"; $script:fail++ }
}

$pairs = @(
  @('engine/bin/engine.ps1', 'plugin/bin/engine.ps1'),
  @('engine/scripts/engine-gate.ps1', 'plugin/engine/scripts/engine-gate.ps1'),
  @('engine/scripts/engine-verify.ps1', 'plugin/engine/scripts/engine-verify.ps1'),
  @('engine/scripts/engine-prove.ps1', 'plugin/engine/scripts/engine-prove.ps1'),
  @('engine/scripts/engine-close.ps1', 'plugin/engine/scripts/engine-close.ps1')
)
foreach ($pair in $pairs) {
  $left = Join-Path $Root $pair[0]
  $right = Join-Path $Root $pair[1]
  Assert-True "PowerShell mirror: $($pair[0])" ((Get-FileHash $left).Hash -eq (Get-FileHash $right).Hash)
  $tokens = $null; $parseErrors = $null
  [System.Management.Automation.Language.Parser]::ParseFile($left, [ref]$tokens, [ref]$parseErrors) | Out-Null
  Assert-True "PowerShell parses: $($pair[0])" ($parseErrors.Count -eq 0)
}

$bashCli = Get-Content -Raw -Path (Join-Path $Root 'engine/bin/engine')
$psCli = Get-Content -Raw -Path (Join-Path $Root 'engine/bin/engine.ps1')
$psGate = Get-Content -Raw -Path (Join-Path $Root 'engine/scripts/engine-gate.ps1')
Assert-True 'Bash CLI exposes gate, prove, and close' ($bashCli -match '(?m)^  gate\)' -and $bashCli -match '(?m)^  prove\)' -and $bashCli -match '(?m)^  close\)')
Assert-True 'PowerShell CLI exposes gate, prove, and close' ($psCli -match '"gate"' -and $psCli -match '"prove"' -and $psCli -match '"close"')
Assert-True 'PowerShell CLI preserves bash-compatible remaining flags' ($psCli -match 'ValueFromRemainingArguments' -and $psCli -match '\$RemainingArgs')
Assert-True 'PowerShell CLI preserves Doctor exit' ($psCli -match 'doctorExit' -and $psCli -match 'exit \$doctorExit')
Assert-True 'PowerShell gate provenance is environment-aware' ((Get-Content -Raw -Path (Join-Path $Root 'engine/scripts/engine-gate.ps1')) -match 'ENGINE_CLI_ENTRYPOINT')
Assert-True 'PowerShell gate runs PowerShell child scripts' ($psGate -match 'engine-prove\.ps1' -and $psGate -match 'ExecutionPolicy Bypass')

Write-Output "=== RESULTS: $pass passed, $fail failed ==="
if ($fail -ne 0) { exit 1 }
