param(
  [string]$Root = (Get-Location).Path
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

if (-not (Test-Path $map)) {
  Write-Fail "engine/ENGINE_MAP.md is missing"
  Write-Host ""
  Write-Host "Engine Doctor: $failCount failure(s), $warnCount warning(s)"
  exit 1
}

Write-Pass "ENGINE_MAP exists"
$lines = Get-Content -Path $map
$profile = ""
foreach ($line in $lines) {
  if ($line -match "^\|\s*Active profile\s*\|") {
    $cells = Split-Row $line
    if ($cells.Count -ge 2) { $profile = $cells[1].Replace(" ", "") }
    break
  }
}
if (-not $profile) { Write-Warn "Active profile not found in ENGINE_MAP §0" }

$registeredRows = Get-TableRows $lines "^## 1\. " "^### 1\.1"
$sectionRows = Get-TableRows $lines "^### 1\.1" "^### 1\.2"
$anchorRows = Get-TableRows $lines "^### 1\.2" "^## 2\."
$planRows = Get-TableRows $lines "^## 2\." "^## 3\."

$registeredNames = New-Object System.Collections.Generic.List[string]
$validClasses = @("index", "irreducible", "derivable", "mixed", "anchor", "generated-cache")

foreach ($row in $registeredRows) {
  $cells = Split-Row $row
  if ($cells.Count -lt 5) { continue }
  $file = $cells[0]; $class = $cells[1]; $priority = $cells[2]
  if (-not $file -or $file -eq "File" -or $file -match "^-+$" -or $file.StartsWith("[")) { continue }
  $registeredNames.Add($file)
  if ($validClasses -notcontains $class) { Write-Fail "$file has illegal class '$class' in ENGINE_MAP §1" }
  if (-not $priority) { Write-Fail "$file has empty read priority" }
  $path = Resolve-EnginePath $file
  if (Test-Path $path) {
    Write-Pass "registered file exists: $file"
  } else {
    Write-Fail "registered file missing: $file"
  }
  $cap = Get-BudgetCap $file
  if ($cap -gt 0 -and (Test-Path $path)) {
    $count = (Get-Content -Path $path | Measure-Object -Line).Lines
    if ($count -gt $cap) { Write-Warn "$file exceeds hard budget ($count > $cap lines)" }
  }
  if ($class -eq "mixed") {
    $hasSection = $false
    foreach ($sectionRow in $sectionRows) {
      $sectionCells = Split-Row $sectionRow
      if ($sectionCells.Count -gt 0 -and $sectionCells[0] -eq $file) { $hasSection = $true; break }
    }
    if (-not $hasSection) { Write-Fail "$file is mixed but missing §1.1 section-class row" }
  }
  if ($profile -eq "CLI-LEAN" -and $class -eq "derivable" -and (Test-Path $path)) {
    $count = (Get-Content -Path $path | Measure-Object -Line).Lines
    if ($count -gt 120) { Write-Warn "$file is derivable in CLI-LEAN and longer than stub budget" }
    $content = Get-Content -Raw -Path $path
    if ($content -match "(?m)^\s*(├|└|│)|file inventory|directory tree|module count|version dump") {
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
  if (-not $id -or $id -eq "ID" -or $id -match "^-+$" -or $id.StartsWith("[") -or $id.StartsWith("无")) { continue }
  if ($allowedStatuses -notcontains $status) { Write-Fail "$id has invalid plan status '$status'" }
  if (-not (Test-Path (Join-Path $Root $plan))) { Write-Fail "$id plan file missing: $plan" }
  if (-not (Test-Path (Join-Path $Root $spec))) { Write-Fail "$id spec twin missing: $spec" }
}

foreach ($anchor in @("AGENTS.md", "CLAUDE.md")) {
  $path = Join-Path $Root $anchor
  if (Test-Path $path) {
    $count = (Get-Content -Path $path | Measure-Object -Line).Lines
    if ($count -gt 45) { Write-Warn "$anchor exceeds bootloader hard cap ($count > 45 lines)" }
  }
}

if ($registeredNames -notcontains "ENGINE_DOCTOR.md") {
  Write-Warn "ENGINE_DOCTOR.md is not registered in ENGINE_MAP §1"
}

Write-Host ""
Write-Host "Engine Doctor: $failCount failure(s), $warnCount warning(s)"
if ($failCount -gt 0) { exit 1 }
exit 0
