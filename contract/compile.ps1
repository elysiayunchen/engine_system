# Engine System - Contract compiler (v6 S3 + S3-b + review fix + D-015)
#
# NOTE: this file is saved with a UTF-8 BOM (unlike other *.ps1 in this repo).
# It embeds a Chinese string literal (rules.json _comment, matched to compile.sh
# for sh/ps1 byte parity). Windows PowerShell 5.1 (powershell.exe) decodes
# BOM-less .ps1 source using the system codepage, which mangles non-ASCII
# literals; the BOM forces correct UTF-8 decoding. Do not strip it.
#
# Produces 6 dist groups:
#   1. ENGINE_FILE_SYSTEM_v5.md (banner + 4 modules concatenated) - web-prompt
#   2. runtime-law.md (L0 constitution, from L0-runtime-law.md) - <=40 lines
#   3. rules.json (machine-readable rule table aggregate index)
#   4. plugin/.claude/commands/engine-init.md (CLI preamble + same contract modules)
#      - kills the init.md dual implementation (design 5.5 / D-015)
#   5. engine/prompts/init.md (agent-neutral preamble + same contract modules,
#      mirrored to plugin/) - in-project pickup point for ANY agent (D-018a)
#   6. behavior skills/prompts (contract/src/behaviors/*.md -> Claude Code
#      skills + agent-neutral prompts, mirrored to plugin/) - D-019 P1
#
# Idempotent: compile(src) == dist.

param()

$ErrorActionPreference = "Stop"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$SrcDir = Join-Path $Root "contract\src"
$BehaviorSrcDir = Join-Path $SrcDir "behaviors"
# ENGINE_COMPILE_OUT: dist output root (defaults to repo root). All write paths hang off
# this; read paths (contract/src, engine/scripts, engine/bin) always resolve under $Root
# so test sandboxes can recompute into isolation and compare against the real dist
# (tests/dist-drift).
$OutRoot = if ($env:ENGINE_COMPILE_OUT) { $env:ENGINE_COMPILE_OUT } else { $Root }
$Dist = Join-Path $OutRoot "ENGINE_FILE_SYSTEM_v5.md"
$LawDist = Join-Path $OutRoot "runtime-law.md"
$RulesDist = Join-Path $OutRoot "rules.json"
$InitDist = Join-Path $OutRoot "plugin\.claude\commands\engine-init.md"
$PromptsDist = Join-Path $OutRoot "engine\prompts\init.md"
$BehaviorPromptsDist = Join-Path $OutRoot "engine\prompts\behaviors"
$BehaviorPromptsPlugin = Join-Path $OutRoot "plugin\engine\prompts\behaviors"
$BehaviorSkillsPlugin = Join-Path $OutRoot "plugin\.claude\skills"
$RoutingSrc = Join-Path $Root "engine\domains\routing.json"
$RoutingPlugin = Join-Path $OutRoot "plugin\engine\domains\routing.json"

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

function Get-Sha256Hex([string]$Path) {
  $sha = [System.Security.Cryptography.SHA256]::Create()
  $stream = [System.IO.File]::OpenRead((Resolve-Path $Path).Path)
  try {
    $bytes = $sha.ComputeHash($stream)
    return (($bytes | ForEach-Object { $_.ToString("x2") }) -join "")
  } finally {
    $stream.Dispose()
    $sha.Dispose()
  }
}
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
  "_comment": "机读规则表(编译产出)。Doctor/hooks 直接读源文件;本文件是聚合索引。",
  "sources": {
    "budget": "contract/budget.json",
    "protected_paths": "engine/decisions/rules.json",
    "federation": "engine/domains/federation.json"
  },
  "max_lines": $maxLines,
  "max_rules": $maxRules,
  "debt_baseline": $debt
}
"@ + "`n"
[System.IO.File]::WriteAllText($RulesDist, $rulesJson, $utf8NoBom)

# 4. engine-init.md (CLI command dist: preamble + same contract modules, D-015)
$InitBanner = '<!-- plugin/.claude/commands/engine-init.md: compiled from contract/src/ (cli-preamble.md + [0-9]*.md) by engine compile. Do not edit dist directly; edit src and recompile. -->'
$preamble = Join-Path $SrcDir "cli-preamble.md"
if (Test-Path $preamble) {
  $initDir = Split-Path -Parent $InitDist
  if (-not (Test-Path $initDir)) { New-Item -ItemType Directory -Path $initDir -Force | Out-Null }
  $initCompiled = $InitBanner + "`n"
  $initCompiled += Get-Content -Raw -Path $preamble -Encoding UTF8
  foreach ($m in $modules) {
    $initCompiled += Get-Content -Raw -Path $m.FullName -Encoding UTF8
  }
  [System.IO.File]::WriteAllText($InitDist, $initCompiled, $utf8NoBom)
}

# 5. engine/prompts/init.md (agent-neutral dist: neutral preamble + same contract modules, D-018a)
$PromptsBanner = '<!-- engine/prompts/init.md: compiled from contract/src/ (agent-preamble.md + [0-9]*.md) by engine compile. Do not edit dist directly; edit src and recompile. -->'
$agentPreamble = Join-Path $SrcDir "agent-preamble.md"
if (Test-Path $agentPreamble) {
  $promptsDir = Split-Path -Parent $PromptsDist
  if (-not (Test-Path $promptsDir)) { New-Item -ItemType Directory -Path $promptsDir -Force | Out-Null }
  $promptsCompiled = $PromptsBanner + "`n"
  $promptsCompiled += Get-Content -Raw -Path $agentPreamble -Encoding UTF8
  foreach ($m in $modules) {
    $promptsCompiled += Get-Content -Raw -Path $m.FullName -Encoding UTF8
  }
  [System.IO.File]::WriteAllText($PromptsDist, $promptsCompiled, $utf8NoBom)
  $pluginPrompts = Join-Path $OutRoot "plugin\engine\prompts"
  if (-not (Test-Path $pluginPrompts)) { New-Item -ItemType Directory -Path $pluginPrompts -Force | Out-Null }
  Copy-Item -Path $PromptsDist -Destination (Join-Path $pluginPrompts "init.md") -Force
}

$lines = (Get-Content $Dist).Count
Write-Output "compile: 5 dist files (web-prompt $lines lines, runtime-law, rules.json, engine-init, prompts/init)"

# 6. behavior skills/prompts (D-019 P1)
$behaviorCount = 0
if (Test-Path $BehaviorSrcDir) {
  foreach ($dir in @($BehaviorPromptsDist, $BehaviorPromptsPlugin)) {
    if (Test-Path $dir) { Remove-Item -Path $dir -Recurse -Force }
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
  }
  if (-not (Test-Path $BehaviorSkillsPlugin)) {
    New-Item -ItemType Directory -Path $BehaviorSkillsPlugin -Force | Out-Null
  }
  $behaviorFiles = Get-ChildItem -Path $BehaviorSrcDir -File -Filter "*.md" | Sort-Object Name
  foreach ($bf in $behaviorFiles) {
    $base = $bf.BaseName
    $skillName = "engine-$base"
    $skillDir = Join-Path $BehaviorSkillsPlugin $skillName
    if (Test-Path $skillDir) { Remove-Item -Path $skillDir -Recurse -Force }
    New-Item -ItemType Directory -Path $skillDir -Force | Out-Null
    Copy-Item -Path $bf.FullName -Destination (Join-Path $BehaviorPromptsDist "$base.md") -Force
    Copy-Item -Path $bf.FullName -Destination (Join-Path $BehaviorPromptsPlugin "$base.md") -Force
    Copy-Item -Path $bf.FullName -Destination (Join-Path $skillDir "SKILL.md") -Force
    $behaviorCount++
  }
}
Write-Output "compile: behavior skills/prompts synced ($behaviorCount behaviors)"

# 7. behavior routing table mirror (engine/domains/routing.json is source)
if (Test-Path $RoutingSrc) {
  $routingDir = Split-Path -Parent $RoutingPlugin
  if (-not (Test-Path $routingDir)) { New-Item -ItemType Directory -Path $routingDir -Force | Out-Null }
  Copy-Item -Path $RoutingSrc -Destination $RoutingPlugin -Force
  Write-Output "compile: behavior routing table synced"
}

# 8. plugin/engine/scripts/ mirror sync (engine/scripts/ is single source of truth)
# Edit scripts in engine/scripts/ only; compile.ps1 auto-syncs to plugin/.
# check.sh drift check catches manual edits to plugin/engine/scripts/.
$syncList = @(
  "engine-check-update.ps1",
  "engine-check-update.sh",
  "engine-doctor.ps1",
  "engine-doctor.sh",
  "engine-hook-session-end.ps1",
  "engine-hook-session-end.sh",
  "engine-hook-session-start.ps1",
  "engine-hook-session-start.sh",
  "engine-hook-stop.ps1",
  "engine-hook-stop.sh",
  "engine-hook.cmd",
  "engine-migrate-contract.ps1",
  "engine-migrate-contract.sh",
  "engine-sync-agent-anchors.ps1",
  "engine-sync-agent-anchors.sh",
  "engine-verify.ps1",
  "engine-verify.sh",
  "githooks\pre-commit"
)
$syncCount = 0
foreach ($f in $syncList) {
  $srcFile = Join-Path $Root "engine\scripts\$f"
  $dstFile = Join-Path $OutRoot "plugin\engine\scripts\$f"
  if (Test-Path $srcFile) {
    $dstDir = Split-Path -Parent $dstFile
    if (-not (Test-Path $dstDir)) { New-Item -ItemType Directory -Path $dstDir -Force | Out-Null }
    Copy-Item -Path $srcFile -Destination $dstFile -Force
    $syncCount++
  }
}
Write-Output "compile: plugin\engine\scripts\ synced ($syncCount files from engine\scripts\)"

# 9. plugin/bin/ mirror sync (engine/bin/ is single source of truth, D-018e)
$binCount = 0
foreach ($f in @("engine", "engine.ps1", "engine.cmd")) {
  $srcBin = Join-Path $Root "engine\bin\$f"
  if (Test-Path $srcBin) {
    $dstBinDir = Join-Path $OutRoot "plugin\bin"
    if (-not (Test-Path $dstBinDir)) { New-Item -ItemType Directory -Path $dstBinDir -Force | Out-Null }
    Copy-Item -Path $srcBin -Destination (Join-Path $dstBinDir $f) -Force
    $binCount++
  }
}
Write-Output "compile: plugin\bin\ synced ($binCount files from engine\bin\)"

# 10. manifest sha256 backfill (compute hash of plugin\<src> bytes, keep single-line format)
$manifest = Join-Path $OutRoot "plugin\manifest.json"
if (Test-Path $manifest) {
  $content = Get-Content -Raw -Path $manifest -Encoding UTF8
  # Remove existing sha256 fields
  $content = $content -replace ', "sha256": "[^"]*"', ''
  # Compute and insert hash for each src
  $srcMatches = [regex]::Matches($content, '"src"\s*:\s*"([^"]*)"')
  foreach ($m in $srcMatches) {
    $src = $m.Groups[1].Value
    $srcFile = Join-Path $OutRoot "plugin\$src"
    if (Test-Path $srcFile) {
      $hash = Get-Sha256Hex $srcFile
      $pattern = '"src": "' + [regex]::Escape($src) + '"'
      $replacement = '"src": "' + $src + '", "sha256": "' + $hash + '"'
      $content = $content -replace $pattern, $replacement
    }
  }
  [System.IO.File]::WriteAllText($manifest, $content, $utf8NoBom)
  $shaCount = ([regex]::Matches($content, '"sha256"')).Count
  Write-Output "compile: manifest sha256 backfilled ($shaCount entries)"
}
