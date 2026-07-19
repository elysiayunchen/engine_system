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
    Write-Output "  human: The plugin manifest file is missing. Run 'engine init' to generate it, or create manifest.json with your file list."
    return
  }

  Write-Pass "plugin manifest exists"
  try {
    $manifest = Get-Content -Raw -Path $manifestPath -Encoding UTF8 | ConvertFrom-Json
  } catch {
    Write-Fail "plugin/manifest.json is not valid JSON: $($_.Exception.Message)"
    Write-Output "  human: The manifest file has a JSON syntax error. Open manifest.json and fix the formatting (missing commas, brackets, or quotes)."
    return
  }

  $files = @($manifest.files)
  if ($files.Count -eq 0) {
    Write-Fail "plugin manifest has no files"
    Write-Output "  human: The manifest lists no files to package. Add src/dest entries to the files array in manifest.json."
    return
  }

  $seen = New-Object System.Collections.Generic.HashSet[string]
  foreach ($file in $files) {
    if (-not $file.src) {
      Write-Fail "manifest entry has empty src"
      Write-Output "  human: A manifest file entry has no source path. Every file in manifest.json needs a non-empty 'src' field."
      continue
    }
    if (-not $file.dest) {
      Write-Fail "$($file.src) has empty dest"
      Write-Output "  human: The manifest entry for '$($file.src)' has no destination path. Add a 'dest' field specifying where it should be installed."
      continue
    }
    if (-not $seen.Add([string]$file.src)) {
      Write-Fail "duplicate manifest src: $($file.src)"
      Write-Output "  human: The file '$($file.src)' appears more than once in the manifest. Remove the duplicate entry."
    }

    $sourcePath = Join-Path $Root ($file.src -replace "/", [IO.Path]::DirectorySeparatorChar)
    if (Test-Path $sourcePath) {
      Write-Pass "package file exists: $($file.src)"
    } else {
      Write-Fail "package file missing: $($file.src)"
      Write-Output "  human: The file '$($file.src)' is listed in the manifest but does not exist on disk. Create the file or remove it from manifest.json."
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
    "engine/scripts/engine-context.ps1",
    "engine/scripts/engine-context.sh",
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
      Write-Output "  human: The required file '$required' is not listed in manifest.json. Add it to the manifest's files array."
    }
  }

  $settingsPath = Join-Path $Root ".claude\settings.json"
  if (-not (Test-Path $settingsPath)) {
    Write-Fail ".claude/settings.json is missing"
    Write-Output "  human: The Claude settings file is missing. Run 'engine init' to create .claude/settings.json with the required hook configuration."
    return
  }

  try {
    $settings = Get-Content -Raw -Path $settingsPath -Encoding UTF8 | ConvertFrom-Json
    if ($settings.hooks.SessionStart -and $settings.hooks.Stop) {
      Write-Pass "Claude hook settings declare SessionStart and Stop"
    } else {
      Write-Fail ".claude/settings.json is missing SessionStart or Stop hooks"
      Write-Output "  human: The Claude settings file is missing SessionStart or Stop hook definitions. Run 'engine init' to regenerate the hook configuration."
    }
  } catch {
    Write-Fail ".claude/settings.json is not valid JSON: $($_.Exception.Message)"
    Write-Output "  human: The Claude settings file has a JSON syntax error. Open .claude/settings.json and fix the formatting."
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
  Write-Output "  human: The project's table of contents file (ENGINE_MAP.md) is missing. Run 'engine init' to create it."
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
if (-not $profile) { Write-Warn "Active profile not found in ENGINE_MAP section 0"
  Write-Output "  human: Could not find the active profile (e.g. CLI-LEAN, FULL) in ENGINE_MAP. Add an 'Active profile' row to section 0 so the doctor knows which checks to run." }

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
  if ($validClasses -notcontains $class) { Write-Fail "$file has illegal class '$class' in ENGINE_MAP section 1"
    Write-Output "  human: The file '$file' has an invalid class type '$class' in the ENGINE_MAP registry. Use one of: index, irreducible, derivable, mixed, anchor, generated-cache." }
  if (-not $priority) { Write-Fail "$file has empty read priority"
    Write-Output "  human: The file '$file' is missing a read-priority value in the ENGINE_MAP registry. Add a priority level (e.g. always, on-demand) to its row." }
  $path = Resolve-EnginePath $file
  if (Test-Path $path) {
    Write-Pass "registered file exists: $file"
  } else {
    Write-Fail "registered file missing: $file"
    Write-Output "  human: The file '$file' is registered in ENGINE_MAP but does not exist on disk. Create the file or remove it from the registry."
  }
  $cap = Get-BudgetCap $file
  if ($cap -gt 0 -and (Test-Path $path)) {
    $count = (Get-Content -Path $path -Encoding UTF8 | Measure-Object -Line).Lines
    if ($count -gt $cap) { Write-Warn "$file exceeds hard budget ($count > $cap lines)"
      Write-Output "  human: The file '$file' is too long ($count lines, max $cap). Trim it to stay within the size budget." }
    # Byte budget: line cap x 200 (normal markdown ~50-100 chars/line; 200 gives headroom).
    # Catches single-line bloat that line-count misses (e.g. table cells padded to 19K chars).
    $bytes = (Get-Item $path).Length
    $byteCap = $cap * 200
    if ($bytes -gt $byteCap) { Write-Warn "$file exceeds byte budget ($bytes > $byteCap bytes)"
      Write-Output "  human: The file '$file' is $bytes bytes, exceeding its $byteCap-byte size limit (likely single-line bloat). Check for table cells padded with excessive whitespace." }
    # Line width: 2000 chars max. Normal markdown tables/paragraphs rarely exceed 1200;
    # 2000 gives headroom. Catches table cells padded to tens of thousands of chars.
    $longest = (Get-Content -Path $path -Encoding UTF8 | Measure-Object -Maximum Length).Maximum
    if ($longest -gt 2000) { Write-Warn "$file has very long line ($longest > 2000 chars)"
      Write-Output "  human: The file '$file' has a line $longest characters long (max 2000). This is likely a padded table row or separator. Remove the excessive padding." }
  }
  if ($class -eq "mixed") {
    $hasSection = $false
    foreach ($sectionRow in $sectionRows) {
      $sectionCells = Split-Row $sectionRow
      if ($sectionCells.Count -gt 0 -and $sectionCells[0] -eq $file) { $hasSection = $true; break }
    }
    if (-not $hasSection) { Write-Fail "$file is mixed but missing section 1.1 section-class row"
      Write-Output "  human: The file '$file' is classified as 'mixed' but has no section-class mapping in ENGINE_MAP section 1.1. Add a row for it in the section-class table." }
  }
  if ($profile -eq "CLI-LEAN" -and $class -eq "derivable" -and (Test-Path $path)) {
    $count = (Get-Content -Path $path -Encoding UTF8 | Measure-Object -Line).Lines
    if ($count -gt 120) { Write-Warn "$file is derivable in CLI-LEAN and longer than stub budget"
      Write-Output "  human: The file '$file' is auto-derivable but too long for CLI-LEAN mode (>120 lines). Replace its content with a short stub that points to the derivation source." }
    $content = Get-Content -Raw -Path $path -Encoding UTF8
    if ($content -match "(?m)file inventory|directory tree|module count|version dump") {
      Write-Warn "$file may contain live derivable inventory in CLI-LEAN"
      Write-Output "  human: The file '$file' looks like it contains auto-generated inventory (file lists, directory trees, etc.). In CLI-LEAN mode, replace this with a stub that derives the data on demand."
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
  Write-Output "  human: The file '$File' is missing a required section ('$Label'). Add a '## $Label' heading with the expected content."
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
          Write-Output "  human: The CONTEXT.md status panel row '$($label.Key)' has a placeholder value (like TBD or TODO). Fill in the actual current status."
        }
        $found = $true
        break
      }
    }
    if (-not $found) { Write-Warn "CONTEXT.md status panel missing row: $($label.Key)"
      Write-Output "  human: The CONTEXT.md status panel is missing the '$($label.Key)' row. Add a table row for it with the current status." }
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
  if (-not $hasResume) { Write-Warn "HANDOFF.md has no concrete next-step resume pointer"
    Write-Output "  human: HANDOFF.md does not specify what to do next. Add a concrete next-step description so the next session knows where to pick up." }

  $hasHistory = $false
  foreach ($line in $handoffLines) {
    if ($line -match "^\|\s*\d{4}-\d{2}-\d{2}\s*\|") { $hasHistory = $true; break }
  }
  if (-not $hasHistory) { Write-Warn "HANDOFF.md has no dated session history rows"
    Write-Output "  human: HANDOFF.md has no session history table. Add dated rows (| YYYY-MM-DD | ...) summarizing what was done in each session." }
}

function Test-HandoffHistoryCap {
  # v6.6 (D-027): HANDOFF history table <= 8 rows; older rows move to
  # engine/handoff-archive-YYYY-MM.md. Archive is search-only (not loaded
  # by SessionStart, not registered in ENGINE_MAP section 1).
  if (-not (Test-RegisteredName "HANDOFF.md")) { return }
  $path = Join-Path $engineDir "HANDOFF.md"
  if (-not (Test-Path $path)) { return }

  $historySection = New-Text @(0x4F1A, 0x8BDD, 0x5386, 0x53F2)
  $inHistory = $false
  $historyCount = 0
  $lines = Get-Content -Path $path -Encoding UTF8
  foreach ($line in $lines) {
    if ($line -match ("^##\s+" + [regex]::Escape($historySection))) { $inHistory = $true; continue }
    if ($inHistory -and $line -match "^##\s") { $inHistory = $false }
    if ($inHistory -and $line -match "^\|\s*\d{4}-\d{2}-\d{2}\s*\|") { $historyCount++ }
  }
  if ($historyCount -gt 8) {
    Write-Warn "HANDOFF.md history table has $historyCount rows (> 8) - archive oldest to engine/handoff-archive-YYYY-MM.md"
    Write-Output "  human: The HANDOFF.md session history table has $historyCount rows. Keep only the most recent 8 in HANDOFF.md and move the rest to engine/handoff-archive-YYYY-MM.md (named by the month of the oldest moved row). The archive file is search-only and not loaded by SessionStart."
  }
}

function Test-ProgressMd {
  # v6.7.0 (D-028/T-032): task-level progress.md 7-section recovery anchor.
  # active/paused cards MUST have engine/tasks/T-NNN/progress.md;
  # done cards MUST have it archived to engine/archive/tasks/T-NNN-progress.md
  # (live copy removed, mirrors D-027 HANDOFF archive).
  # Migration grace period: projects stamped contract-version < 6.7.0 -> WARN;
  # >= 6.7.0 -> FAIL (see D-028 section 9).
  $tasksDir = Join-Path $engineDir "tasks"
  if (-not (Test-Path $tasksDir)) { return }

  # Read contract-version from ENGINE_DOCTOR.md managed block.
  $doctorPath = Join-Path $engineDir "ENGINE_DOCTOR.md"
  $contractVersion = ""
  if (Test-Path $doctorPath) {
    $m = Select-String -Path $doctorPath -Pattern 'contract-version:\s*([0-9]+\.[0-9]+\.[0-9]+)' -List -ErrorAction SilentlyContinue
    if ($m) { $contractVersion = $m.Matches[0].Groups[1].Value }
  }
  # Parse "X.Y.Z" -> cvInt = X*10000 + Y*100 + Z (for numeric compare).
  $cvInt = 0
  if ($contractVersion -match '^(\d+)\.(\d+)\.(\d+)$') {
    $cvInt = [int]$Matches[1] * 10000 + [int]$Matches[2] * 100 + [int]$Matches[3]
  }
  $violationIsFail = $false
  if ($cvInt -ge 60700) { $violationIsFail = $true }

  $activeCount = 0; $pausedCount = 0; $doneCount = 0
  $activeMissing = 0; $pausedMissing = 0; $doneLive = 0

  $taskFiles = Get-ChildItem -Path $tasksDir -File -Filter "T-*.md" -ErrorAction SilentlyContinue
  foreach ($f in $taskFiles) {
    if ($f.Name -match '\.spec\.md$') { continue }
    $tid = $f.BaseName
    $prog = Join-Path $tasksDir ("$tid\progress.md")
    $content = Get-Content -Raw -Path $f.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $content) { continue }

    if ($content -match 'status:\s*active') {
      $activeCount++
      if (-not (Test-Path $prog)) {
        $activeMissing++
        if ($violationIsFail) {
          Write-Fail "task $tid (active) missing progress.md - copy engine/skeleton/progress.md to engine/tasks/$tid/progress.md"
          Write-Output "  human: Active task $tid has no progress.md recovery anchor. SessionStart injects progress.md to survive context compression; without it, in-progress details may be lost. Run: Copy-Item engine/skeleton/progress.md engine/tasks/$tid/progress.md and fill in sections 1-7."
        } else {
          Write-Warn "task $tid (active) missing progress.md (grace period, contract-version $contractVersion < 6.7.0)"
        }
      }
    } elseif ($content -match 'status:\s*paused') {
      $pausedCount++
      if (-not (Test-Path $prog)) {
        $pausedMissing++
        if ($violationIsFail) {
          Write-Fail "task $tid (paused) missing progress.md - copy engine/skeleton/progress.md to engine/tasks/$tid/progress.md"
          Write-Output "  human: Paused task $tid has no progress.md recovery anchor. Without it, resuming the task after context loss requires re-reading all files. Run: Copy-Item engine/skeleton/progress.md engine/tasks/$tid/progress.md."
        } else {
          Write-Warn "task $tid (paused) missing progress.md (grace period, contract-version $contractVersion < 6.7.0)"
        }
      }
    } elseif ($content -match 'status:\s*done') {
      $doneCount++
      # Done cards: live progress.md should be archived (mirror D-027 HANDOFF).
      if (Test-Path $prog) {
        $doneLive++
        if ($violationIsFail) {
          Write-Fail "task $tid (done) has live progress.md - archive to engine/archive/tasks/$tid-progress.md and remove live copy"
          Write-Output "  human: Done task $tid still has a live progress.md at engine/tasks/$tid/progress.md. Done cards are cold history; archive the progress.md to engine/archive/tasks/$tid-progress.md (mirrors HANDOFF archive) and remove the live copy."
        } else {
          Write-Warn "task $tid (done) has live progress.md (grace period, contract-version $contractVersion < 6.7.0)"
        }
      }
    }
  }

  # Summary line when there are active/paused cards with progress.md present.
  $totalActive = $activeCount + $pausedCount
  if ($totalActive -gt 0) {
    $totalMissing = $activeMissing + $pausedMissing
    if ($totalMissing -eq 0) {
      Write-Pass "progress.md summary: $totalActive active/paused task(s) all have progress.md (cv=$contractVersion)"
    }
  }
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
    Write-Output "  human: PITFALLS.md is missing an 'Entries' section. Add a '## Entries' heading and list known pitfalls under it."
  }
  if ($content -notmatch ("##\s+(" + [regex]::Escape($index) + "|Index)")) {
    Write-Warn "PITFALLS.md is missing index section"
    Write-Output "  human: PITFALLS.md is missing an 'Index' section. Add a '## Index' heading with a keyword index for quick lookup of pitfalls."
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
        Write-Output "  human: Pitfall entry '$($entry.Groups[1].Value)' is missing the '$($field.Key)' field. Add it with the required information."
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
    Write-Output "  human: SPRINT.md does not define when the sprint is done. Add an 'Acceptance' or completion criteria section so everyone knows the definition of done."
  }
  if ($content -notmatch ([regex]::Escape($verification) + "|verify|verification")) {
    Write-Warn "SPRINT.md has no verification method pointers"
    Write-Output "  human: SPRINT.md does not describe how to verify the work. Add a 'Verification' section with concrete steps to confirm correctness."
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
    Write-Output "  human: You have code or doc changes but no change-log entry. Create a CHANGE-*.md file in engine/changes/ describing what changed and why."
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
      Write-Output "  human: The change log '$($latest.Name)' is missing a '$($section.Key)' section. Add a '## $($section.Key)' heading with the relevant details."
    }
  }
  if ($content -match "\[.*\]|TBD|TODO") {
    Write-Warn "$($latest.Name) still contains placeholders"
    Write-Output "  human: The change log '$($latest.Name)' still has unfilled placeholders ([...], TBD, or TODO). Replace them with actual content before committing."
  }
}

function Test-ContractCompile {
  $srcDir = Join-Path $Root "contract/src"
  $dist = Join-Path $Root "ENGINE_FILE_SYSTEM_v5.md"
  $compileSh = Join-Path $Root "contract/compile.sh"
  if (-not (Test-Path $srcDir)) { return }
  if (-not (Test-Path $dist)) { Write-Warn "contract dist missing: $dist"; Write-Output "  human: The compiled contract file is missing. Run 'bash contract/compile.sh' to generate it."; return }
  if (-not (Test-Path $compileSh)) { Write-Warn "contract compile.sh missing"; Write-Output "  human: The contract compile script is missing. The contract/src/ directory exists but compile.sh is not present to build the dist file."; return }
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
    Write-Output "  human: The compiled contract file is out of date or was edited by hand. Run 'bash contract/compile.sh' to regenerate it from the source files."
  }
  # D-015: 4th dist (engine-init.md = banner + cli-preamble + same modules) must be idempotent too
  $initDist = Join-Path $Root "plugin/.claude/commands/engine-init.md"
  $preamble = Join-Path $srcDir "cli-preamble.md"
  if ((Test-Path $preamble) -and (Test-Path $initDist)) {
    $initBanner = '<!-- plugin/.claude/commands/engine-init.md: compiled from contract/src/ (cli-preamble.md + [0-9]*.md) by engine compile. Do not edit dist directly; edit src and recompile. -->'
    $initExpected = $initBanner + "`n" + (Get-Content -Raw -Path $preamble -Encoding UTF8) + $srcContent
    $initContent = Get-Content -Raw -Path $initDist -Encoding UTF8
    if ($initExpected -ceq $initContent) {
      Write-Pass "contract compile idempotent (engine-init.md == compile(preamble+src))"
    } else {
      Write-Fail "engine-init.md is not compile(src) - run bash contract/compile.sh; do not edit dist directly"
      Write-Output "  human: The engine-init command file is out of date or was edited by hand. Run 'bash contract/compile.sh' to regenerate it from source files."
    }
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
        Write-Output "  human: The contract source files are too long ($srcLines lines, max $maxLines). Remove or consolidate rules to bring the total back under budget."
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
  $ruleLines = $modules | ForEach-Object { Get-Content $_.FullName -Encoding UTF8 -ErrorAction SilentlyContinue | Select-String -Pattern '\*\*[^*]*Rule \(v' -ErrorAction SilentlyContinue }
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
      Write-Output "  human: There are more ungated MUST rules than the baseline allows ($debt > $baseline). Move MUST requirements into data tables or wrap them in named Rules to reduce debt."
    }
  }
}

function Test-TaskCardDoneEvidence {
  $tasksDir = Join-Path $engineDir "tasks"
  if (-not (Test-Path $tasksDir)) { return }
  $doneCount = 0
  $exemptCount = 0
  $verifiedCount = 0
  foreach ($f in (Get-ChildItem -Path $tasksDir -File -Filter "T-*.md" -ErrorAction SilentlyContinue)) {
    if ($f.Name -match '\.spec\.md$') { continue }
    $content = Get-Content -Raw -Path $f.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
    if ($content -notmatch 'status:\s*done') { continue }
    $doneCount++
    $tid = $f.BaseName
    $evDir = Join-Path $engineDir ("evidence\" + $tid)
    if ($content -match 'exempt') {
      $exemptCount++
      continue
    }
    $acIds = @([regex]::Matches($content, '(?m)^AC:\s*(AC-[0-9]+(?:\.[0-9]+)*)') | ForEach-Object { $_.Groups[1].Value })
    $missing = New-Object System.Collections.Generic.List[string]
    foreach ($ac in $acIds) {
      $evPath = Join-Path $evDir ($ac + '.json')
      if (-not (Test-Path $evPath)) { $missing.Add($ac); continue }
      $evContent = Get-Content -Raw -Path $evPath -Encoding UTF8 -ErrorAction SilentlyContinue
      if ($evContent -notmatch '"status"\s*:\s*"pass"') { $missing.Add($ac) }
    }
    if ($acIds.Count -gt 0 -and $missing.Count -eq 0) {
      $verifiedCount++
    } else {
      $missingText = if ($missing.Count -gt 0) { $missing -join ',' } else { 'no declared AC' }
      Write-Fail "task $tid done without complete PASS evidence ($missingText) - run 'engine verify $tid' or mark exempt"
      Write-Output "  human: Task '$tid' is marked as done, but every declared AC needs a PASS evidence file. Missing/non-pass: $missingText."
    }
  }
  if ($doneCount -gt 0) {
    Write-Pass "done task evidence summary: $doneCount checked ($verifiedCount verified, $exemptCount exempt)"
  }
}

function Test-EngineVersion {
  $ev = Join-Path $EngineDir "VERSION"
  if (-not (Test-Path $ev)) {
    Write-Warn "engine/VERSION missing - run 'engine migrate' to stamp the local version"
    Write-Output "  human: The engine version stamp file is missing. Run 'engine migrate' to create it with the current version."
    return
  }
  $v = (Get-Content $ev -Raw -Encoding UTF8).Trim()
  if (-not $v) {
    Write-Fail "engine/VERSION is empty"
    Write-Output "  human: The engine version file exists but is empty. Run 'engine migrate' to stamp it with the current version number."
    return
  }
  # Only compare engine/VERSION with repo root VERSION when this IS the
  # engine_system source repo (contract/src/ exists). In user projects,
  # $Root/VERSION is the product's own version (e.g. 1.0.0) with different
  # semantics — comparing it against the engine tooling version (e.g. 6.0.1)
  # is always a false positive. See P014 + CHANGE-2026-07-06-08.
  $contractSrc = Join-Path $Root "contract/src"
  $repoVer = Join-Path $Root "VERSION"
  if ((Test-Path $contractSrc) -and (Test-Path $repoVer)) {
    $rv = (Get-Content $repoVer -Raw -Encoding UTF8).Trim()
    if ($v -ne $rv) {
      Write-Warn "engine/VERSION ($v) differs from repo VERSION ($rv) - run 'engine migrate' to sync"
      Write-Output "  human: The engine tooling version ($v) does not match the repo version ($rv). Run 'engine migrate' to sync them."
    } else {
      Write-Pass "engine/VERSION ($v) matches repo VERSION"
    }
  } else {
    Write-Pass "engine/VERSION present ($v)"
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
      Write-Output "  human: Plan '$id' is marked as done but the spec file has no evidence reference. Add pointers to engine/evidence/ or engine/changes/ in the spec twin's Evidence column."
    }
  }
}

function Test-LegacyDataFormat {
  # Version-agnostic detection of legacy (pre-v6) data residue.
  # Detects format features (not version numbers) so any old-format data
  # is reported. Empty projects (no changes/tasks/evidence) trigger 0 WARNs.
  $tasksDir = Join-Path $engineDir "tasks"
  $changesDir = Join-Path $engineDir "changes"
  $evidenceDir = Join-Path $engineDir "evidence"

  # 1. Task cards without v6 headers (write-set: or status:).
  if (Test-Path $tasksDir) {
    $legacyTasks = 0
    $taskFiles = @(Get-ChildItem -Path $tasksDir -Filter "T-*.md" -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch '\.spec\.md$' })
    foreach ($tf in $taskFiles) {
      $content = Get-Content -Raw -Path $tf.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
      if ($content -and ($content -notmatch "(?i)write-set:|status:")) {
        $legacyTasks++
      }
    }
    if ($legacyTasks -gt 0) {
      Write-Warn "$legacyTasks task card(s) missing v6 headers (write-set/status) - may be legacy format"
      Write-Output "  human: $legacyTasks task card(s) in engine/tasks/ are missing the v6 machine-readable header (write-set: or status:). They may be from an older engine version. New work should use the v6 task card format (see engine/tasks/README.md)."
    }
  }

  # 2. changes/ has capsules but tasks/ is empty - v5 data residue.
  $changesCount = 0
  $tasksCount = 0
  if (Test-Path $changesDir) {
    $changesCount = @(Get-ChildItem -Path $changesDir -Filter "CHANGE-*.md" -File -ErrorAction SilentlyContinue).Count
  }
  if (Test-Path $tasksDir) {
    $tasksCount = @(Get-ChildItem -Path $tasksDir -Filter "T-*.md" -File -ErrorAction SilentlyContinue).Count
  }
  if ($changesCount -gt 0 -and $tasksCount -eq 0) {
    Write-Warn "$changesCount change capsule(s) in engine/changes/ but 0 task cards - new work should use v6 task cards"
    Write-Output "  human: Your project has $changesCount change capsules (engine/changes/) but no v6 task cards (engine/tasks/). This suggests the project was upgraded from an older engine version but new work hasn't adopted v6 task cards yet. New work should be tracked as T-NNN.md task cards."
  }

  # 3. evidence/ has loose .md files (v5 format) instead of T-NNN/AC-N.json.
  if (Test-Path $evidenceDir) {
    $legacyEv = @(Get-ChildItem -Path $evidenceDir -Filter "*.md" -File -ErrorAction SilentlyContinue).Count
    if ($legacyEv -gt 0) {
      Write-Warn "$legacyEv evidence file(s) are loose .md (legacy format) - new work should use evidence/T-NNN/AC-N.json"
      Write-Output "  human: $legacyEv evidence file(s) in engine/evidence/ are loose .md files (v5 format). New verification evidence should be stored as engine/evidence/T-NNN/AC-N.json (machine-readable, with sha256 fingerprint)."
    }
  }
}

if (Test-Path $engineDir) {
  Get-ChildItem -Path $engineDir -File -Filter "*.md" | ForEach-Object {
    $rel = "engine/$($_.Name)"
    if ($rel -in @("engine/README.md", "engine/README.zh.md")) { return }
    # External scratch spec, intentionally unregistered (parity with release package Doctor).
    if ($_.Name -eq "ENGINE_FILE_SYSTEM_v5.md") { return }
    # v6.6 (D-027): HANDOFF history archive files are search-only, not section 1 authority.
    if ($_.Name -like "handoff-archive-*.md") { return }
    if (-not (Test-Registered $rel) -and -not (Test-Registered $_.Name)) {
      Write-Fail "authority-looking file is not registered or explained: $rel"
      Write-Output "  human: The file '$rel' exists in the engine directory but is not registered in ENGINE_MAP. Register it or move it elsewhere."
    }
  }
  $agentsDir = Join-Path $engineDir "agents"
  if (Test-Path $agentsDir) {
    Get-ChildItem -Path $agentsDir -File -Filter "*.md" | ForEach-Object {
      $rel = "engine/agents/$($_.Name)"
      if (-not (Test-Registered $rel)) { Write-Fail "agent adapter is not registered: $rel"
        Write-Output "  human: The agent adapter '$rel' is not listed in ENGINE_MAP. Register it so the system knows about this environment-specific adapter." }
    }
  }
}

foreach ($row in $anchorRows) {
  $cells = Split-Row $row
  if ($cells.Count -lt 4) { continue }
  $path = $cells[0]
  if (-not $path -or $path -eq "Path" -or $path -match "^-+$" -or $path.StartsWith("[")) { continue }
  if ($path -match "archived|superseded|external") { continue }
  if (-not (Test-Path (Join-Path $Root $path))) { Write-Warn "registered anchor missing: $path"
    Write-Output "  human: The anchor file '$path' is registered in ENGINE_MAP but does not exist on disk. Create it or remove it from the anchor registry." }
}

$allowedStatuses = @("draft", "proposed", "accepted", "active", "blocked", "done", "archived", "superseded")
foreach ($row in $planRows) {
  $cells = Split-Row $row
  # Plan rows may be compact; need id/status/plan/spec.
  if ($cells.Count -lt 5) { continue }
  $id = $cells[0]; $status = $cells[2]; $plan = $cells[3]; $spec = $cells[4]
  $nonePrefix = [string][char]0x65E0
  if (-not $id -or $id -eq "ID" -or $id -match "^-+$" -or $id.StartsWith("[") -or $id.StartsWith($nonePrefix)) { continue }
  if ($allowedStatuses -notcontains $status) { Write-Fail "$id has invalid plan status '$status'"
    Write-Output "  human: Plan '$id' has an unrecognized status '$status'. Use one of: draft, proposed, accepted, active, blocked, done, archived, superseded." }
  # Inline markers and composite paths are not single files on disk.
  if ($plan -and -not $plan.StartsWith("(") -and ($plan -notmatch "\+") -and -not (Test-Path (Join-Path $Root $plan))) {
    Write-Fail "$id plan file missing: $plan"
    Write-Output "  human: Plan '$id' references a plan file at '$plan' but it does not exist. Create the plan file or update the ENGINE_MAP entry."
  }
  $inlineMarker = New-Text @(0x5185, 0x8054)
  $hasInline = $spec -match [regex]::Escape($inlineMarker)
  $hasSpecPath = $spec.StartsWith("engine/")
  if (-not $hasInline -and -not $hasSpecPath -and (@("accepted", "active", "done") -contains $status)) {
    Write-Fail "$id must have a spec twin path or inline spec marker: $spec"
    Write-Output "  human: Plan '$id' is active but has no spec twin file path and no inline spec marker. Add a spec twin path (engine/...) or an inline marker to the ENGINE_MAP plan row."
  }
  if ($hasSpecPath -and ($spec -notmatch "\+") -and -not (Test-Path (Join-Path $Root $spec))) {
    Write-Fail "$id spec twin missing: $spec"
    Write-Output "  human: Plan '$id' references a spec twin at '$spec' but the file does not exist. Create the spec file or update the ENGINE_MAP entry."
  }
}

Test-ContextSemantics
Test-HandoffSemantics
Test-HandoffHistoryCap
Test-ProgressMd
Test-PitfallsSemantics
Test-SprintSemantics
Test-ChangeCapsuleSemantics
Test-PlanAcceptanceEvidence
Test-ContractCompile
Test-ContractDebt
Test-TaskCardDoneEvidence
Test-EngineVersion
Test-LegacyDataFormat

# ── Project-custom checks (engine/checks/) ──
function Run-CustomChecks {
  $checksDir = Join-Path $EngineDir "checks"
  if (-not (Test-Path $checksDir)) { return }
  $found = $false
  $patterns = @("check-*.ps1", "warn-*.ps1")
  foreach ($pattern in $patterns) {
    $scripts = Get-ChildItem -Path $checksDir -Filter $pattern -ErrorAction SilentlyContinue | Sort-Object Name
    foreach ($script in $scripts) {
      $found = $true
      $name = $script.Name
      $isWarn = $name.StartsWith("warn-")
      $output = & $script.FullName 2>&1 | Out-String
      if ($LASTEXITCODE -eq 0) {
        Write-Pass "custom check $($name): PASS"
        if ($output.Trim()) { Write-Host $output.Trim() }
      } else {
        $outputText = if ($output.Trim()) { $output.Trim() } else { "" }
        if ($isWarn) {
          Write-Warn "custom check $($name): FAIL"
        } else {
          Write-Fail "custom check $($name): FAIL"
        }
        if ($outputText) { Write-Host $outputText }
      }
    }
  }
  if (-not $found) {
    Write-Pass "custom checks directory exists but is empty (engine/checks/)"
  }
}
Run-CustomChecks

foreach ($anchor in @("AGENTS.md", "CLAUDE.md")) {
  $path = Join-Path $Root $anchor
  if (Test-Path $path) {
    $count = (Get-Content -Path $path -Encoding UTF8 | Measure-Object -Line).Lines
    if ($count -gt 45) { Write-Warn "$anchor exceeds bootloader hard cap ($count > 45 lines)"
      Write-Output "  human: The bootloader file '$anchor' is too long ($count lines, max 45). It should be a minimal entry point that directs agents to ENGINE_MAP. Trim it down." }
  }
}

# Anchor content quality: TOP RULES source attribution
foreach ($anchor in @("AGENTS.md", "CLAUDE.md")) {
  $path = Join-Path $Root $anchor
  if (Test-Path $path) {
    $lines = Get-Content -Path $path -Encoding UTF8
    $inTopRules = $false; $unsourced = 0
    foreach ($line in $lines) {
      if ($line -match "TOP RULES") { $inTopRules = $true; continue }
      if ($inTopRules) {
        if ($line -match "^## ") { break }
        if ($line -match "^\d+\.\s" -and $line -notmatch "source:") { $unsourced++ }
      }
    }
    if ($unsourced -gt 0) {
      Write-Warn "$anchor has $unsourced TOP RULES line(s) without source: attribution"
      Write-Output "  human: The bootloader '$anchor' contains rule excerpts without 'source:' annotation."
      Write-Output "  Each excerpted rule should cite its authority (e.g., 'source: engine/SYSTEM.md')."
      Write-Output "  Unsourced rules may be originals that belong in engine/SYSTEM.md, not in the bootloader."
    }
  }
}

if ($registeredNames -notcontains "ENGINE_DOCTOR.md") {
  Write-Warn "ENGINE_DOCTOR.md is not registered in ENGINE_MAP section 1"
  Write-Output "  human: The ENGINE_DOCTOR.md file is not listed in the ENGINE_MAP file registry. Add it to section 1 so the system can track it."
}

foreach ($script in @(
  "engine-doctor.sh",
  "engine-doctor.ps1",
  "engine-context.sh",
  "engine-context.ps1",
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
    Write-Output "  human: The maintenance script 'engine/scripts/$script' is missing. Run 'engine sync' to restore bundled scripts from the engine package."
  }
}

foreach ($cli in @("engine", "engine.ps1", "engine.cmd")) {
  $cliPath = Join-Path (Join-Path $engineDir "bin") $cli
  if (Test-Path $cliPath) {
    Write-Pass "bundled CLI shim exists: engine/bin/$cli"
  } else {
    Write-Warn "bundled CLI shim missing: engine/bin/$cli"
    Write-Output "  human: The CLI entry point 'engine/bin/$cli' is missing. Run 'engine sync' to restore bundled CLI shims from the engine package."
  }
}

Write-Host ""
Write-Host "Engine Doctor: $failCount failure(s), $warnCount warning(s)"
if ($failCount -gt 0) { exit 1 }
exit 0
