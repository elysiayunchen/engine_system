# Engine System - Contract compiler (v6 S3)
#
# Compiles contract/src/ENGINE_FILE_SYSTEM.md into dist ENGINE_FILE_SYSTEM_v5.md.
# Compile = prepend compile banner + src content. Idempotent: compile(src) == dist.
#
# Usage: pwsh -File contract/compile.ps1
# Edit contract: change src, not dist; recompile, then run scripts/check.sh to verify.

param()
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$Src = Join-Path $Root "contract\src\ENGINE_FILE_SYSTEM.md"
$Dist = Join-Path $Root "ENGINE_FILE_SYSTEM_v5.md"

if (-not (Test-Path $Src)) {
  Write-Error "compile: source not found: $Src"
  exit 1
}

$Banner = '<!-- ENGINE_FILE_SYSTEM_v5.md: compiled from contract/src/ENGINE_FILE_SYSTEM.md by engine compile. Do not edit dist directly; edit src and recompile. -->'

$srcContent = Get-Content -Raw -Path $Src -Encoding UTF8
$compiled = $Banner + "`n" + $srcContent

# UTF8 without BOM (consistent with the .sh twin).
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($Dist, $compiled, $utf8NoBom)

$lines = (Get-Content $Dist).Count
Write-Output "compile: $Src -> $Dist ($lines lines)"
