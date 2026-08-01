# T-078 / issue #25: PowerShell acceptance-preflight smoke test.

$ErrorActionPreference = 'Stop'
$Root = Split-Path (Split-Path $PSScriptRoot)
$pass = 0
$fail = 0

function Assert-True {
  param([string]$Name, [bool]$Condition)
  if ($Condition) { Write-Output "PASS  $Name"; $script:pass++ }
  else { Write-Output "FAIL  $Name"; $script:fail++ }
}

Assert-True 'PowerShell verifier exists' (Test-Path (Join-Path $Root 'engine/scripts/engine-verify.ps1'))
Assert-True 'plugin PowerShell verifier mirrors engine' ((Get-FileHash (Join-Path $Root 'engine/scripts/engine-verify.ps1')).Hash -eq (Get-FileHash (Join-Path $Root 'plugin/engine/scripts/engine-verify.ps1')).Hash)
Assert-True 'PowerShell CLI mirrors engine' ((Get-FileHash (Join-Path $Root 'engine/bin/engine.ps1')).Hash -eq (Get-FileHash (Join-Path $Root 'plugin/bin/engine.ps1')).Hash)

$tokens = $null
$parseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile((Join-Path $Root 'engine/scripts/engine-verify.ps1'), [ref]$tokens, [ref]$parseErrors) | Out-Null
Assert-True 'PowerShell verifier parses' ($parseErrors.Count -eq 0)

$task = Join-Path $Root 'engine/tasks/T-078.md'
$taskText = Get-Content -Raw -Path $task -Encoding UTF8
Assert-True 'task card exposes preflight ACs' ($taskText -match 'acceptance preflight' -and $taskText -match 'coverage: no-cov')

Write-Output "=== RESULTS: $pass passed, $fail failed ==="
if ($fail -ne 0) { exit 1 }
