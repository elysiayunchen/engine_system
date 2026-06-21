param(
  [string]$Root = (Get-Location).Path,
  [switch]$PackageMode
)

$ErrorActionPreference = "Stop"
$engineDir = Join-Path $Root "engine"
$map = Join-Path $engineDir "ENGINE_MAP.md"
$failCount = 0
$warnCount = 0

function Write-Fail([string]$Message) {
  $script:failCount++
  Write-Host "FAIL $Message" -ForegroundColor Red
}

function Write-Warn([string]$Message) {
  $script:warnCount++
  Write-Host "WARN $Message" -ForegroundColor Yellow
}

function Write-Pass([string]$Message) {
  Write-Host "PASS $Message" -ForegroundColor Green
}

function Trim-Cell([string]$Value) {
  if ($null -eq $Value) { return "" }
  return $Value.Replace('`', "").Trim()
}

function Resolve-EnginePath([string]$File) {
  $clean = Trim-Cell $File
  if ($clean -like "engine/*") {
    return Join-Path $Root ($clean -replace "/", [IO.Path]::DirectorySeparatorChar)
  }
  return Join-Path $engineDir ($clean -replace "/", [IO.Path]::DirectorySeparatorChar)
}

function Get-BudgetCap([string]$File) {
  switch ($File) {
    "ENGINE_MAP.md" { 240; break }
    "SYSTEM.md" { 340; break }
    "ENGINE_DOCTOR.md" { 320; break }
    "REPO_GUIDE.md" { 380; break }
    "CONTEXT.md" { 260; break }
    "HANDOFF.md" { 180; break }
    "SPRINT.md" { 320; break }
    "PITFALLS.md" { 500; break }
    "ARCHITECTURE.md" { 320; break }
    "SOURCEMAP.md" { 120; break }
    "AGENTS.md" { 45; break }
    "CLAUDE.md" { 45; break }
    default { 0 }
  }
}

function Get-TableRows([string[]]$Lines, [string]$StartPattern, [string]$EndPattern) {
  $inside = $false
  foreach ($line in $Lines) {
    if ($line -match $StartPattern) { $inside = $true; continue }
    if ($inside -and $line -match $EndPattern) { break }
    if ($inside -and $line.StartsWith("|")) { $line }
  }
}

function Split-Row([string]$Line) {
  $parts = $Line -split "\|"
  if ($parts.Count -le 2) { return @() }
  return $parts[1..($parts.Count - 2)] | ForEach-Object { Trim-Cell $_ }
}

function Test-PackageMode {
  $manifestPath = Join-Path $Root "manifest.json"
  if (-not (Test-Path $manifestPath)) {
    Write-Fail "plugin/manifest.json is missing"
    return
  }

  Write-Pass "plugin manifest exists"
  try {
    $manifest = Get-Content -Raw -Path $manifestPath -Encoding UTF8 | ConvertFrom-Json
  } catch {
    Write-Fail "plugin/manifest.json is not valid JSON: $($_.Exception.Message)"
    return
  }

  $files = @($manifest.files)
  if ($files.Count -eq 0) {
    Write-Fail "plugin manifest has no files"
    return
  }

  $seen = New-Object System.Collections.Generic.HashSet[string]
  foreach ($file in $files) {
    if (-not $file.src) {
      Write-Fail "manifest entry has empty src"
      continue
    }
    if (-not $file.dest) {
      Write-Fail "$($file.src) has empty dest"
      continue
    }
    if (-not $seen.Add([string]$file.src)) {
      Write-Fail "duplicate manifest src: $($file.src)"
    }

    $sourcePath = Join-Path $Root ($file.src -replace "/", [IO.Path]::DirectorySeparatorChar)
    if (Test-Path $sourcePath) {
      Write-Pass "package file exists: $($file.src)"
    } else {
      Write-Fail "package file missing: $($file.src)"
    }
  }

  foreach ($required in @(
    "AGENTS.md",
    "CLAUDE.md",
    ".claude/commands/engine-init.md",
    ".claude/commands/engine-sync.md",
    "engine/ENGINE_DOCTOR.md",
    "engine/scripts/engine-doctor.ps1",
    "engine/scripts/engine-doctor.sh",
    "engine/scripts/githooks/pre-commit",
    "bin/engine",
    "bin/engine.ps1",
    "bin/engine.cmd"
  )) {
    if ($files.src -notcontains $required) {
      Write-Fail "required package file is not in manifest: $required"
    }
  }

  $settingsPath = Join-Path $Root ".claude\settings.json"
  if (-not (Test-Path $settingsPath)) {
    Write-Fail ".claude/settings.json is missing"
    return
  }

  try {
    $settings = Get-Content -Raw -Path $settingsPath -Encoding UTF8 | ConvertFrom-Json
    if ($settings.hooks.SessionStart -and $settings.hooks.Stop) {
      Write-Pass "Claude hook settings declare SessionStart and Stop"
    } else {
      Write-Fail ".claude/settings.json is missing SessionStart or Stop hooks"
    }
  } catch {
    Write-Fail ".claude/settings.json is not valid JSON: $($_.Exception.Message)"
  }
}

if ($PackageMode) {
  Test-PackageMode
  Write-Host ""
  Write-Host "Engine Doctor: $failCount failure(s), $warnCount warning(s)"
  if ($failCount -gt 0) { exit 1 }
  exit 0
}

if (-not (Test-Path $map)) {
  Write-Fail "engine/ENGINE_MAP.md is missing"
  Write-Host ""
  Write-Host "Engine Doctor: $failCount failure(s), $warnCount warning(s)"
  exit 1
}

Write-Pass "ENGINE_MAP exists"
$lines = Get-Content -Path $map -Encoding UTF8
$profile = ""
foreach ($line in $lines) {
  if ($line -match "^\|\s*Active profile\s*\|") {
    $cells = Split-Row $line
    if ($cells.Count -ge 2) { $profile = $cells[1].Replace(" ", "") }
    break
  }
}
if (-not $profile) {
  foreach ($line in $lines) {
    if ($line -match "Active profile:\s*\**([^* \(]+)") {
      $profile = $Matches[1].Replace(" ", "")
      break
    }
  }
}
if (-not $profile) { Write-Warn "Active profile not found in ENGINE_MAP section 0" }

$sectionMark = [string][char]0x00A7
$regStart = "^## (1\.|${sectionMark}1\s)"
$regEnd = "^(### (1\.1|${sectionMark}1\.1)|## (${sectionMark}4|4\.|2\.|${sectionMark}2|3\.|${sectionMark}3))"
$sectionStart = "^### (1\.1|${sectionMark}1\.1)"
$sectionEnd = "^### (1\.2|${sectionMark}1\.2)"
$anchorStart = "^### (1\.2|${sectionMark}1\.2)"
$anchorEnd = "^## (2\.|${sectionMark}2)"
$planStart = "^## (2\.|${sectionMark}2)"
$planEnd = "^## (3\.|${sectionMark}3)"

$registeredRows = Get-TableRows $lines $regStart $regEnd
$sectionRows = Get-TableRows $lines $sectionStart $sectionEnd
$anchorRows = Get-TableRows $lines $anchorStart $anchorEnd
$planRows = Get-TableRows $lines $planStart $planEnd

$registeredNames = New-Object System.Collections.Generic.List[string]
$validClasses = @("index", "irreducible", "derivable", "mixed", "anchor", "generated-cache")

foreach ($row in $registeredRows) {
  $cells = Split-Row $row
  if ($cells.Count -lt 2) { continue }
  $file = $cells[0]; $class = $cells[1]
  $priority = if ($cells.Count -ge 5) { $cells[2] } else { "compact-registry" }
  $fileHeaderZh = [string][char]0x6587 + [string][char]0x4EF6
  if (-not $file -or $file -eq "File" -or $file -eq $fileHeaderZh -or $file -match "^-+$" -or $file.StartsWith("[")) { continue }
  $registeredNames.Add($file)
  if ($validClasses -notcontains $class) { Write-Fail "$file has illegal class '$class' in ENGINE_MAP section 1" }
  if (-not $priority) { Write-Fail "$file has empty read priority" }
  $path = Resolve-EnginePath $file
  if (Test-Path $path) {
    Write-Pass "registered file exists: $file"
  } else {
    Write-Fail "registered file missing: $file"
  }
  $cap = Get-BudgetCap $file
  if ($cap -gt 0 -and (Test-Path $path)) {
    $count = (Get-Content -Path $path -Encoding UTF8 | Measure-Object -Line).Lines
    if ($count -gt $cap) { Write-Warn "$file exceeds hard budget ($count > $cap lines)" }
  }
  if ($class -eq "mixed") {
    $hasSection = $false
    foreach ($sectionRow in $sectionRows) {
      $sectionCells = Split-Row $sectionRow
      if ($sectionCells.Count -gt 0 -and $sectionCells[0] -eq $file) { $hasSection = $true; break }
    }
    if (-not $hasSection) { Write-Fail "$file is mixed but missing section 1.1 section-class row" }
  }
  if ($profile -eq "CLI-LEAN" -and $class -eq "derivable" -and (Test-Path $path)) {
    $count = (Get-Content -Path $path -Encoding UTF8 | Measure-Object -Line).Lines
    if ($count -gt 120) { Write-Warn "$file is derivable in CLI-LEAN and longer than stub budget" }
    $content = Get-Content -Raw -Path $path -Encoding UTF8
    if ($content -match "(?m)file inventory|directory tree|module count|version dump") {
      Write-Warn "$file may contain live derivable inventory in CLI-LEAN"
    }
  }
}

function Test-Registered([string]$RelativePath) {
  foreach ($name in $registeredNames) {
    if ($name -eq $RelativePath -or "engine/$name" -eq $RelativePath) { return $true }
  }
  return $false
}

if (Test-Path $engineDir) {
  Get-ChildItem -Path $engineDir -File -Filter "*.md" | ForEach-Object {
    $rel = "engine/$($_.Name)"
    if ($rel -in @("engine/README.md", "engine/README.zh.md")) { return }
    if (-not (Test-Registered $rel) -and -not (Test-Registered $_.Name)) {
      Write-Fail "authority-looking file is not registered or explained: $rel"
    }
  }
  $agentsDir = Join-Path $engineDir "agents"
  if (Test-Path $agentsDir) {
    Get-ChildItem -Path $agentsDir -File -Filter "*.md" | ForEach-Object {
      $rel = "engine/agents/$($_.Name)"
      if (-not (Test-Registered $rel)) { Write-Fail "agent adapter is not registered: $rel" }
    }
  }
}

foreach ($row in $anchorRows) {
  $cells = Split-Row $row
  if ($cells.Count -lt 4) { continue }
  $path = $cells[0]
  if (-not $path -or $path -eq "Path" -or $path -match "^-+$" -or $path.StartsWith("[")) { continue }
  if ($path -match "archived|superseded|external") { continue }
  if (-not (Test-Path (Join-Path $Root $path))) { Write-Warn "registered anchor missing: $path" }
}

$allowedStatuses = @("draft", "proposed", "accepted", "active", "blocked", "done", "archived", "superseded")
foreach ($row in $planRows) {
  $cells = Split-Row $row
  if ($cells.Count -lt 7) { continue }
  $id = $cells[0]; $status = $cells[2]; $plan = $cells[3]; $spec = $cells[4]
  $nonePrefix = [string][char]0x65E0
  if (-not $id -or $id -eq "ID" -or $id -match "^-+$" -or $id.StartsWith("[") -or $id.StartsWith($nonePrefix)) { continue }
  if ($allowedStatuses -notcontains $status) { Write-Fail "$id has invalid plan status '$status'" }
  if (-not (Test-Path (Join-Path $Root $plan))) { Write-Fail "$id plan file missing: $plan" }
  if (-not (Test-Path (Join-Path $Root $spec))) { Write-Fail "$id spec twin missing: $spec" }
}

foreach ($anchor in @("AGENTS.md", "CLAUDE.md")) {
  $path = Join-Path $Root $anchor
  if (Test-Path $path) {
    $count = (Get-Content -Path $path -Encoding UTF8 | Measure-Object -Line).Lines
    if ($count -gt 45) { Write-Warn "$anchor exceeds bootloader hard cap ($count > 45 lines)" }
  }
}

if ($registeredNames -notcontains "ENGINE_DOCTOR.md") {
  Write-Warn "ENGINE_DOCTOR.md is not registered in ENGINE_MAP section 1"
}

foreach ($script in @(
  "engine-doctor.sh",
  "engine-doctor.ps1",
  "engine-hook-session-start.sh",
  "engine-hook-session-start.ps1",
  "engine-hook-stop.sh",
  "engine-hook-stop.ps1",
  "engine-hook-session-end.sh",
  "engine-hook-session-end.ps1",
  "engine-sync-agent-anchors.sh",
  "engine-sync-agent-anchors.ps1",
  "githooks/pre-commit"
)) {
  $scriptPath = Join-Path (Join-Path $engineDir "scripts") ($script -replace "/", [IO.Path]::DirectorySeparatorChar)
  if (Test-Path $scriptPath) {
    Write-Pass "bundled maintenance script exists: engine/scripts/$script"
  } else {
    Write-Warn "bundled maintenance script missing: engine/scripts/$script"
  }
}

foreach ($cli in @("engine", "engine.ps1", "engine.cmd")) {
  $cliPath = Join-Path (Join-Path $engineDir "bin") $cli
  if (Test-Path $cliPath) {
    Write-Pass "bundled CLI shim exists: engine/bin/$cli"
  } else {
    Write-Warn "bundled CLI shim missing: engine/bin/$cli"
  }
}

Write-Host ""
Write-Host "Engine Doctor: $failCount failure(s), $warnCount warning(s)"
if ($failCount -gt 0) { exit 1 }
exit 0
