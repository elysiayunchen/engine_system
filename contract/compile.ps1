# Engine System - Contract compiler (v6 S3 + S3-b)
#
# Compiles contract/src/[0-9]*.md (sorted modules) into dist ENGINE_FILE_SYSTEM_v5.md.
# Compile = prepend compile banner + concatenate all source modules. Idempotent.
#
# Usage: pwsh -File contract/compile.ps1
# Edit contract: change src modules, not dist; recompile, then run scripts/check.sh.

param()
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$SrcDir = Join-Path $Root "contract\src"
$Dist = Join-Path $Root "ENGINE_FILE_SYSTEM_v5.md"

if (-not (Test-Path $SrcDir)) {
  Write-Error "compile: source dir not found: $SrcDir"
  exit 1
}

$Banner = '<!-- ENGINE_FILE_SYSTEM_v5.md: compiled from contract/src/*.md by engine compile. Do not edit dist directly; edit src and recompile. -->'

$modules = Get-ChildItem -Path $SrcDir -File | Where-Object { $_.Name -match '^\d.*\.md$' } | Sort-Object Name
$compiled = $Banner + "`n"
foreach ($m in $modules) {
  $compiled += Get-Content -Raw -Path $m.FullName -Encoding UTF8
}

# UTF8 without BOM (consistent with the .sh twin).
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($Dist, $compiled, $utf8NoBom)

$lines = (Get-Content $Dist).Count
Write-Output "compile: $SrcDir\*.md -> $Dist ($lines lines)"
