# Engine System - Contract compiler (v6 S3 + S3-b + review fix + D-015)
#
# Produces 4 dist files:
#   1. ENGINE_FILE_SYSTEM_v5.md (banner + 4 modules concatenated) - web-prompt
#   2. runtime-law.md (L0 constitution, from L0-runtime-law.md) - <=40 lines
#   3. rules.json (machine-readable rule table aggregate index)
#   4. plugin/.claude/commands/engine-init.md (CLI preamble + same contract modules)
#      - kills the init.md dual implementation (design 5.5 / D-015)
#
# Idempotent: compile(src) == dist.

param()
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$SrcDir = Join-Path $Root "contract\src"
$Dist = Join-Path $Root "ENGINE_FILE_SYSTEM_v5.md"
$LawDist = Join-Path $Root "runtime-law.md"
$RulesDist = Join-Path $Root "rules.json"
$InitDist = Join-Path $Root "plugin\.claude\commands\engine-init.md"

if (-not (Test-Path $SrcDir)) {
  Write-Error "compile: source dir not found: $SrcDir"
  exit 1
}

$Banner = '<!-- ENGINE_FILE_SYSTEM_v5.md: compiled from contract/src/*.md by engine compile. Do not edit dist directly; edit src and recompile. -->'

# 1. web-prompt (banner + 4 modules)
$modules = Get-ChildItem -Path $SrcDir -File | Where-Object { $_.Name -match '^\d.*\.md$' } | Sort-Object Name
$compiled = $Banner + "`n"
foreach ($m in $modules) {
  $compiled += Get-Content -Raw -Path $m.FullName -Encoding UTF8
}
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($Dist, $compiled, $utf8NoBom)

# 2. runtime-law.md (L0 constitution)
$lawSrc = Join-Path $SrcDir "L0-runtime-law.md"
if (Test-Path $lawSrc) {
  Copy-Item -Path $lawSrc -Destination $LawDist -Force
}

# 3. rules.json (aggregate index from budget.json)
$budget = Join-Path $Root "contract\budget.json"
$maxLines = 0; $maxRules = 0; $debt = 0
if (Test-Path $budget) {
  $br = Get-Content -Raw -Path $budget -Encoding UTF8
  if ($br -match '"max_lines"\s*:\s*(\d+)') { $maxLines = [int]$Matches[1] }
  if ($br -match '"max_rules"\s*:\s*(\d+)') { $maxRules = [int]$Matches[1] }
  if ($br -match '"debt_baseline"\s*:\s*(\d+)') { $debt = [int]$Matches[1] }
}
$rulesJson = @"
{
  "_comment": "machine-readable rule table (compiled). Doctor/hooks read source files directly; this is an aggregate index.",
  "sources": {
    "budget": "contract/budget.json",
    "protected_paths": "engine/decisions/rules.json",
    "federation": "engine/domains/federation.json"
  },
  "max_lines": $maxLines,
  "max_rules": $maxRules,
  "debt_baseline": $debt
}
"@
[System.IO.File]::WriteAllText($RulesDist, $rulesJson, $utf8NoBom)

# 4. engine-init.md (CLI command dist: preamble + same contract modules, D-015)
$InitBanner = '<!-- plugin/.claude/commands/engine-init.md: compiled from contract/src/ (cli-preamble.md + [0-9]*.md) by engine compile. Do not edit dist directly; edit src and recompile. -->'
$preamble = Join-Path $SrcDir "cli-preamble.md"
if ((Test-Path $preamble) -and (Test-Path (Split-Path -Parent $InitDist))) {
  $initCompiled = $InitBanner + "`n"
  $initCompiled += Get-Content -Raw -Path $preamble -Encoding UTF8
  foreach ($m in $modules) {
    $initCompiled += Get-Content -Raw -Path $m.FullName -Encoding UTF8
  }
  [System.IO.File]::WriteAllText($InitDist, $initCompiled, $utf8NoBom)
}

$lines = (Get-Content $Dist).Count
Write-Output "compile: 4 dist files (web-prompt $lines lines, runtime-law, rules.json, engine-init)"
