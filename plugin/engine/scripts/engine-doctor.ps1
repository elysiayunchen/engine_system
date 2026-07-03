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
    "engine/scripts/engine-migrate-contract.ps1",
    "engine/scripts/engine-migrate-contract.sh",
    "engine/scripts/engine-verify.ps1",
    "engine/scripts/engine-verify.sh",
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

function Test-RegisteredName([string]$Name) {
  foreach ($registered in $registeredNames) {
    if ($registered -eq $Name -or $registered -eq "engine/$Name") { return $true }
  }
  return $false
}

function Test-RequiredMarkdownSection([string[]]$Lines, [string]$File, [string]$Pattern, [string]$Label) {
  foreach ($line in $Lines) {
    if ($line -match $Pattern) { return $true }
  }
  Write-Warn "$File is missing semantic section: $Label"
  return $false
}

function New-Text([int[]]$CodePoints) {
  return -join ($CodePoints | ForEach-Object { [char]$_ })
}

function Test-ContextSemantics {
  if (-not (Test-RegisteredName "CONTEXT.md")) { return }
  $path = Join-Path $engineDir "CONTEXT.md"
  if (-not (Test-Path $path)) { return }

  $contextLines = Get-Content -Path $path -Encoding UTF8
  $statusPanel = New-Text @(0x72B6, 0x6001, 0x9762, 0x677F)
  Test-RequiredMarkdownSection $contextLines "CONTEXT.md" ("^##\s+" + [regex]::Escape($statusPanel)) "status panel" | Out-Null
  $labels = @(
    @{ Key = "build"; Text = New-Text @(0x6784, 0x5EFA) },
    @{ Key = "last completed"; Text = New-Text @(0x4E0A, 0x6B21, 0x5B8C, 0x6210) },
    @{ Key = "in progress"; Text = New-Text @(0x8FDB, 0x884C, 0x4E2D) },
    @{ Key = "blocked"; Text = New-Text @(0x963B, 0x585E) }
  )
  foreach ($label in $labels) {
    $found = $false
    $labelPattern = [regex]::Escape($label.Text)
    foreach ($line in $contextLines) {
      if ($line -match "^\|\s*$labelPattern\s*\|\s*(.+?)\s*\|") {
        $value = $Matches[1].Trim()
        if (-not $value -or $value -match "^\[.*\]$|^TBD$|^TODO$") {
          Write-Warn "CONTEXT.md status row '$($label.Key)' is placeholder or empty"
        }
        $found = $true
        break
      }
    }
    if (-not $found) { Write-Warn "CONTEXT.md status panel missing row: $($label.Key)" }
  }
}

function Test-HandoffSemantics {
  if (-not (Test-RegisteredName "HANDOFF.md")) { return }
  $path = Join-Path $engineDir "HANDOFF.md"
  if (-not (Test-Path $path)) { return }

  $handoffLines = Get-Content -Path $path -Encoding UTF8
  $resumeSection = New-Text @(0x7ACB, 0x5373, 0x6062, 0x590D, 0x70B9)
  $historySection = New-Text @(0x4F1A, 0x8BDD, 0x5386, 0x53F2)
  $nextStep = New-Text @(0x4E0B, 0x4E00, 0x6B65)
  Test-RequiredMarkdownSection $handoffLines "HANDOFF.md" ("^##\s+" + [regex]::Escape($resumeSection)) "resume point" | Out-Null
  Test-RequiredMarkdownSection $handoffLines "HANDOFF.md" ("^##\s+" + [regex]::Escape($historySection)) "session history" | Out-Null

  $hasResume = $false
  foreach ($line in $handoffLines) {
    if ($line -match ("^" + [regex]::Escape($nextStep) + "[:" + [char]0xFF1A + "]\s*(.+)")) {
      $value = $Matches[1].Trim()
      if ($value -and $value -notmatch "^\[.*\]$|^TBD$|^TODO$") { $hasResume = $true }
    }
  }
  if (-not $hasResume) { Write-Warn "HANDOFF.md has no concrete next-step resume pointer" }

  $hasHistory = $false
  foreach ($line in $handoffLines) {
    if ($line -match "^\|\s*\d{4}-\d{2}-\d{2}\s*\|") { $hasHistory = $true; break }
  }
  if (-not $hasHistory) { Write-Warn "HANDOFF.md has no dated session history rows" }
}

function Test-PitfallsSemantics {
  if (-not (Test-RegisteredName "PITFALLS.md")) { return }
  $path = Join-Path $engineDir "PITFALLS.md"
  if (-not (Test-Path $path)) { return }

  $content = Get-Content -Raw -Path $path -Encoding UTF8
  $entries = New-Text @(0x6761, 0x76EE)
  $index = New-Text @(0x7D22, 0x5F15)
  if ($content -notmatch ("##\s+(" + [regex]::Escape($entries) + "|Entries)")) {
    Write-Warn "PITFALLS.md is missing entries section"
  }
  if ($content -notmatch ("##\s+(" + [regex]::Escape($index) + "|Index)")) {
    Write-Warn "PITFALLS.md is missing index section"
  }

  $entryMatches = [regex]::Matches($content, "(?m)^###\s+(P\d{3})\s+[" + [char]0x2014 + "-]\s+(.+)$")
  foreach ($entry in $entryMatches) {
    $start = $entry.Index
    $next = $content.IndexOf("### P", $start + 1)
    $body = if ($next -gt $start) { $content.Substring($start, $next - $start) } else { $content.Substring($start) }
    $fields = @(
      @{ Key = "severity"; Text = New-Text @(0x4E25, 0x91CD, 0x7A0B, 0x5EA6) },
      @{ Key = "category"; Text = New-Text @(0x7C7B, 0x522B) },
      @{ Key = "status"; Text = New-Text @(0x72B6, 0x6001) },
      @{ Key = "observable symptom"; Text = New-Text @(0x4F60, 0x80FD, 0x89C2, 0x5BDF, 0x5230, 0x7684, 0x73B0, 0x8C61) },
      @{ Key = "wrong action"; Text = New-Text @(0x9519, 0x8BEF, 0x505A, 0x6CD5) },
      @{ Key = "correct action"; Text = New-Text @(0x6B63, 0x786E, 0x505A, 0x6CD5) },
      @{ Key = "trigger"; Text = New-Text @(0x89E6, 0x53D1, 0x6761, 0x4EF6) },
      @{ Key = "verification"; Text = New-Text @(0x9A8C, 0x8BC1, 0x65B9, 0x5F0F) }
    )
    foreach ($field in $fields) {
      $marker = "**$($field.Text)$([char]0xFF1A)**"
      if ($body -notmatch [regex]::Escape($marker)) {
        Write-Warn "$($entry.Groups[1].Value) is missing pitfall field: $($field.Key)"
      }
    }
  }
}

function Test-SprintSemantics {
  if (-not (Test-RegisteredName "SPRINT.md")) { return }
  $path = Join-Path $engineDir "SPRINT.md"
  if (-not (Test-Path $path)) { return }

  $content = Get-Content -Raw -Path $path -Encoding UTF8
  $completion = New-Text @(0x5B8C, 0x6210, 0x6807, 0x51C6)
  $acceptance = New-Text @(0x9A8C, 0x6536)
  $verification = New-Text @(0x9A8C, 0x8BC1, 0x65B9, 0x6CD5)
  if ($content -notmatch ([regex]::Escape($completion) + "|" + [regex]::Escape($acceptance) + "|Acceptance")) {
    Write-Warn "SPRINT.md has no completion criteria"
  }
  if ($content -notmatch ([regex]::Escape($verification) + "|verify|verification")) {
    Write-Warn "SPRINT.md has no verification method pointers"
  }
}

function Get-ChangedPaths {
  $git = Get-Command git -ErrorAction SilentlyContinue
  if (-not $git) { return @() }
  try {
    $status = & $git.Source -C $Root status --short 2>$null
    if ($LASTEXITCODE -ne 0) { return @() }
    return @($status | ForEach-Object {
      if ($_ -match "^\s*(?:[A-Z?]{1,2})\s+(.+)$") { $Matches[1].Trim() }
    } | Where-Object { $_ })
  } catch {
    return @()
  }
}

function Test-ChangeCapsuleSemantics {
  $changesDir = Join-Path $engineDir "changes"
  $capsules = @()
  if (Test-Path $changesDir) {
    $capsules = @(Get-ChildItem -Path $changesDir -File -Filter "CHANGE-*.md" | Sort-Object LastWriteTime -Descending)
  }

  $changedPaths = @(Get-ChangedPaths)
  $meaningfulChanges = @($changedPaths | Where-Object {
    $_ -notmatch "^engine/changes/" -and
    $_ -notmatch "^engine/\.cache/" -and
    $_ -notmatch "^\.git/" -and
    $_ -notmatch "^archive/"
  })

  if ($meaningfulChanges.Count -gt 0 -and $capsules.Count -eq 0) {
    Write-Warn "meaningful changed files exist but no change capsule was found in engine/changes"
    return
  }

  if ($capsules.Count -eq 0) { return }

  $latest = $capsules[0]
  Write-Pass "latest change capsule exists: engine/changes/$($latest.Name)"
  $content = Get-Content -Raw -Path $latest.FullName -Encoding UTF8
  $requiredSections = @(
    @{ Key = "goal"; Pattern = "(?m)^##\s+Goal\s*$" },
    @{ Key = "actual changes"; Pattern = "(?m)^##\s+Actual Changes\s*$" },
    @{ Key = "impact scope"; Pattern = "(?m)^##\s+Impact Scope\s*$" },
    @{ Key = "risk"; Pattern = "(?m)^##\s+Risk & Watchpoints\s*$" },
    @{ Key = "verification"; Pattern = "(?m)^##\s+Verification\s*$" },
    @{ Key = "rollback"; Pattern = "(?m)^##\s+Rollback\s*$" },
    @{ Key = "next step"; Pattern = "(?m)^##\s+Next Step\s*$" },
    @{ Key = "responsibility boundary"; Pattern = "(?m)^##\s+Responsibility Boundary\s*$" }
  )
  foreach ($section in $requiredSections) {
    if ($content -notmatch $section.Pattern) {
      Write-Warn "$($latest.Name) is missing change capsule section: $($section.Key)"
    }
  }
  if ($content -match "\[.*\]|TBD|TODO") {
    Write-Warn "$($latest.Name) still contains placeholders"
  }
}

function Test-ContractCompile {
  $srcDir = Join-Path $Root "contract/src"
  $dist = Join-Path $Root "ENGINE_FILE_SYSTEM_v5.md"
  $compileSh = Join-Path $Root "contract/compile.sh"
  if (-not (Test-Path $srcDir)) { return }
  if (-not (Test-Path $dist)) { Write-Warn "contract dist missing: $dist"; return }
  if (-not (Test-Path $compileSh)) { Write-Warn "contract compile.sh missing"; return }
  $banner = '<!-- ENGINE_FILE_SYSTEM_v5.md: compiled from contract/src/*.md by engine compile. Do not edit dist directly; edit src and recompile. -->'
  $modules = Get-ChildItem -Path $srcDir -File | Where-Object { $_.Name -match '^\d.*\.md$' } | Sort-Object Name
  $srcContent = ""
  foreach ($m in $modules) { $srcContent += Get-Content -Raw -Path $m.FullName -Encoding UTF8 }
  $expected = $banner + "`n" + $srcContent
  $distContent = Get-Content -Raw -Path $dist -Encoding UTF8
  if ($expected -ceq $distContent) {
    Write-Pass "contract compile idempotent (compile(src) == dist)"
  } else {
    Write-Fail "contract dist is not compile(src) - run bash contract/compile.sh; do not edit dist directly"
  }
  $budget = Join-Path $Root "contract/budget.json"
  if (Test-Path $budget) {
    $budgetRaw = Get-Content -Raw -Path $budget -Encoding UTF8
    if ($budgetRaw -match '"max_lines"\s*:\s*(\d+)') {
      $maxLines = [int]$Matches[1]
      $srcLines = ($modules | ForEach-Object { (Get-Content $_.FullName).Count } | Measure-Object -Sum).Sum
      if ($srcLines -le $maxLines) {
        Write-Pass "contract budget: src $srcLines lines <= $maxLines"
      } else {
        Write-Fail "contract budget exceeded: src $srcLines lines > $maxLines (subtraction rule: net-zero growth)"
      }
    }
  }
}

function Test-ContractDebt {
  $srcDir = Join-Path $Root "contract/src"
  if (-not (Test-Path $srcDir)) { return }
  $modules = Get-ChildItem -Path $srcDir -File | Where-Object { $_.Name -match '^\d.*\.md$' } | Sort-Object Name
  $totalMust = 0
  foreach ($m in $modules) {
    $content = Get-Content -Raw $m.FullName -Encoding UTF8
    $totalMust += ([regex]::Matches($content, '\bMUST\b')).Count
  }
  $ruleLines = $modules | ForEach-Object { Get-Content $_.FullName -Encoding UTF8 | Select-String -Pattern '\*\*[^*]*Rule \(v' }
  $ruleCount = if ($ruleLines) { @($ruleLines).Count } else { 0 }
  $debt = $totalMust - $ruleCount
  $budget = Join-Path $Root "contract/budget.json"
  $baseline = $null
  if (Test-Path $budget) {
    $budgetRaw = Get-Content -Raw -Path $budget -Encoding UTF8
    if ($budgetRaw -match '"debt_baseline"\s*:\s*(\d+)') { $baseline = [int]$Matches[1] }
  }
  $suffix = if ($null -ne $baseline) { ", baseline=$baseline" } else { "" }
  Write-Pass "contract debt: MUST=$totalMust, gated Rules=$ruleCount, debt=$debt$suffix"
  if ($null -ne $baseline) {
    if ($debt -le $baseline) {
      Write-Pass "contract debt <= baseline ($debt <= $baseline) - net-zero holding"
    } else {
      Write-Warn "contract debt > baseline ($debt > $baseline) - move MUST into data tables"
    }
  }
}

function Test-PlanAcceptanceEvidence {
  foreach ($row in $planRows) {
    $cells = Split-Row $row
    if ($cells.Count -lt 5) { continue }
    $id = $cells[0]; $status = $cells[2]; $spec = $cells[4]
    if ($status -ne "done") { continue }
    if (-not $spec -or -not $spec.StartsWith("engine/") -or $spec -match "\+") { continue }
    $specPath = Join-Path $Root ($spec -replace "/", [IO.Path]::DirectorySeparatorChar)
    if (-not (Test-Path $specPath)) { continue }
    $content = Get-Content -Raw -Path $specPath -Encoding UTF8
    if ($content -notmatch "Evidence|证据|engine/changes/CHANGE-|engine/evidence/") {
      Write-Warn "$id is marked done but has no acceptance evidence pointer"
    }
  }
}

if (Test-Path $engineDir) {
  Get-ChildItem -Path $engineDir -File -Filter "*.md" | ForEach-Object {
    $rel = "engine/$($_.Name)"
    if ($rel -in @("engine/README.md", "engine/README.zh.md")) { return }
    # External scratch spec, intentionally unregistered (parity with release package Doctor).
    if ($_.Name -eq "ENGINE_FILE_SYSTEM_v5.md") { return }
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
  # Plan rows may be compact; need id/status/plan/spec.
  if ($cells.Count -lt 5) { continue }
  $id = $cells[0]; $status = $cells[2]; $plan = $cells[3]; $spec = $cells[4]
  $nonePrefix = [string][char]0x65E0
  if (-not $id -or $id -eq "ID" -or $id -match "^-+$" -or $id.StartsWith("[") -or $id.StartsWith($nonePrefix)) { continue }
  if ($allowedStatuses -notcontains $status) { Write-Fail "$id has invalid plan status '$status'" }
  # Inline markers and composite paths are not single files on disk.
  if ($plan -and -not $plan.StartsWith("(") -and ($plan -notmatch "\+") -and -not (Test-Path (Join-Path $Root $plan))) {
    Write-Fail "$id plan file missing: $plan"
  }
  $inlineMarker = New-Text @(0x5185, 0x8054)
  $hasInline = $spec -match [regex]::Escape($inlineMarker)
  $hasSpecPath = $spec.StartsWith("engine/")
  if (-not $hasInline -and -not $hasSpecPath -and (@("accepted", "active", "done") -contains $status)) {
    Write-Fail "$id must have a spec twin path or inline spec marker: $spec"
  }
  if ($hasSpecPath -and ($spec -notmatch "\+") -and -not (Test-Path (Join-Path $Root $spec))) {
    Write-Fail "$id spec twin missing: $spec"
  }
}

Test-ContextSemantics
Test-HandoffSemantics
Test-PitfallsSemantics
Test-SprintSemantics
Test-ChangeCapsuleSemantics
Test-PlanAcceptanceEvidence
Test-ContractCompile
Test-ContractDebt

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
  "engine-hook.cmd",
  "engine-sync-agent-anchors.sh",
  "engine-sync-agent-anchors.ps1",
  "engine-migrate-contract.sh",
  "engine-migrate-contract.ps1",
  "engine-verify.sh",
  "engine-verify.ps1",
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
