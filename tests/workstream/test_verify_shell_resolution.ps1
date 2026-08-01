$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path

function Assert-Contains([string]$Path, [string]$Needle) {
  $content = Get-Content -Raw -LiteralPath $Path -Encoding UTF8
  if (-not $content.Contains($Needle)) { throw "$Path does not contain: $Needle" }
}

Assert-Contains (Join-Path $repoRoot 'engine\scripts\engine-verify.sh') 'ensure_powershell_on_path'
Assert-Contains (Join-Path $repoRoot 'engine\scripts\engine-verify.sh') '[ -f "$dir/pwsh.exe" ]'
Assert-Contains (Join-Path $repoRoot 'engine\scripts\engine-verify.sh') 'ENGINE_PWSH_CMD'
$left = (Get-FileHash (Join-Path $repoRoot 'engine\scripts\engine-verify.sh') -Algorithm SHA256).Hash
$right = (Get-FileHash (Join-Path $repoRoot 'plugin\engine\scripts\engine-verify.sh') -Algorithm SHA256).Hash
if ($left -ne $right) { throw 'Verify Bash mirrors differ' }
Write-Output 'PASS test_verify_shell_resolution.ps1'
