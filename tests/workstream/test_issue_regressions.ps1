# PowerShell/static twin for the focused GitHub issue regressions.
$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path

function Assert-Contains([string]$Path, [string]$Needle) {
  $content = Get-Content -Raw -LiteralPath $Path -Encoding UTF8
  if (-not $content.Contains($Needle)) { throw "$Path does not contain: $Needle" }
}

function Assert-PowerShellParses([string]$Path) {
  $tokens = $null
  $errors = $null
  [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors) | Out-Null
  if ($errors.Count -gt 0) { throw "PowerShell parse failed: $Path`n$($errors | Out-String)" }
}

foreach ($file in @(
  (Join-Path $repoRoot "engine\scripts\engine-review.ps1"),
  (Join-Path $repoRoot "plugin\engine\scripts\engine-review.ps1")
)) {
  Assert-Contains $file '[Parameter(Position=0)]'
  Assert-Contains $file '$task = $Task'
}
foreach ($file in @(
  (Join-Path $repoRoot "engine\scripts\engine-review-pipeline.ps1"),
  (Join-Path $repoRoot "plugin\engine\scripts\engine-review-pipeline.ps1")
)) { Assert-Contains $file '${task}:' }
foreach ($file in @(
  (Join-Path $repoRoot "engine\scripts\engine-review.ps1"),
  (Join-Path $repoRoot "plugin\engine\scripts\engine-review.ps1"),
  (Join-Path $repoRoot "engine\scripts\engine-review-pipeline.ps1"),
  (Join-Path $repoRoot "plugin\engine\scripts\engine-review-pipeline.ps1")
)) { Assert-PowerShellParses $file }

Assert-Contains (Join-Path $repoRoot "install.ps1") '[switch]$SkipMigrate'
Assert-Contains (Join-Path $repoRoot "install.ps1") 'if (-not $SkipMigrate -and'
Assert-Contains (Join-Path $repoRoot "engine\bin\engine.ps1") '-Update -SkipMigrate'
Assert-Contains (Join-Path $repoRoot "engine\scripts\engine-check-update.ps1") 'Compare-Normalized-Version'
Assert-Contains (Join-Path $repoRoot "engine\scripts\engine-check-update.ps1") 'no downgrade recommended'
Assert-Contains (Join-Path $repoRoot "engine\scripts\engine-doctor.ps1") 'Test-LegacyVerdictEvidence'

# Execute the PowerShell version comparator without contacting GitHub by
# loading only the function definition from the parsed script AST.
$checkUpdatePath = Join-Path $repoRoot "engine\scripts\engine-check-update.ps1"
$tokens = $null
$errors = $null
$scriptAst = [System.Management.Automation.Language.Parser]::ParseFile($checkUpdatePath, [ref]$tokens, [ref]$errors)
$compareAst = $scriptAst.Find({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq "Compare-Normalized-Version" }, $true)
if ($null -eq $compareAst) { throw "Compare-Normalized-Version definition not found" }
Invoke-Expression $compareAst.Extent.Text
if ((Compare-Normalized-Version "6.23.0" "6.24.0") -ne -1) { throw "PowerShell comparator failed older-version direction" }
if ((Compare-Normalized-Version "6.24.0" "6.24.0") -ne 0) { throw "PowerShell comparator failed equality" }
if ((Compare-Normalized-Version "6.25.0" "6.24.0") -ne 1) { throw "PowerShell comparator failed newer-version direction" }

$pairs = @(
  @("engine\scripts\engine-review.ps1", "plugin\engine\scripts\engine-review.ps1"),
  @("engine\scripts\engine-review-pipeline.ps1", "plugin\engine\scripts\engine-review-pipeline.ps1"),
  @("engine\scripts\engine-check-update.ps1", "plugin\engine\scripts\engine-check-update.ps1"),
  @("engine\scripts\engine-doctor.ps1", "plugin\engine\scripts\engine-doctor.ps1"),
  @("engine\scripts\githooks\pre-commit", "plugin\engine\scripts\githooks\pre-commit"),
  @("engine\bin\engine", "plugin\bin\engine"),
  @("engine\bin\engine.ps1", "plugin\bin\engine.ps1")
)
foreach ($pair in $pairs) {
  $left = (Get-FileHash (Join-Path $repoRoot $pair[0]) -Algorithm SHA256).Hash
  $right = (Get-FileHash (Join-Path $repoRoot $pair[1]) -Algorithm SHA256).Hash
  if ($left -ne $right) { throw "Mirror drift: $($pair[0]) != $($pair[1])" }
}

foreach ($file in @((Join-Path $repoRoot "README.md"), (Join-Path $repoRoot "README.zh.md"))) {
  foreach ($needle in @("v6.24.0", "acceptance-preflight", "engine prove", "engine review", "engine gate", "engine close")) {
    Assert-Contains $file $needle
  }
}

Write-Output "PASS test_issue_regressions.ps1"
