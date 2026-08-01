param(
  [string]$Root = (Get-Location).Path,
  [switch]$PackageMode
)

$ErrorActionPreference = "Stop"

# v6.12.1 (issue #11 / T-048): unknown flags must fail loudly. PowerShell's
# positional binding would otherwise swallow a bash-style flag (--quiet) into
# $Root and report "ENGINE_MAP.md is missing" instead of "no such flag".
if ($Root -like '--*') {
  Write-Error "Error: unknown flag '$Root' (known: -PackageMode; a path argument sets -Root)"
  exit 2
}
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

# Parse-AcDeclarations: Extract (ac_id, verify_cmd) pairs from a task card.
# Supports 4 AC declaration formats (D-037 / v6.17.0):
#   1. Single-line:  AC: AC-N <desc> | verify: <cmd>
#   2. Section:      ### AC-N: <title> + body's first verify: line
#   3. List item:    - AC-N: <desc> | verify: <cmd>  (or next line verify:)
#   4. Table row:    | AC-N | <desc> | verify: <cmd> |
# Returns: array of objects with AcId and VerifyCmd properties (VerifyCmd may be empty for SKIP).
# AC id regex: AC-[A-Za-z]*[0-9]+(\.[0-9]+)* (v6.12.1 A-3).
# Separators: | verify: / |verify: / -> verify: / ->verify: / line-start verify:
function Parse-AcDeclarations {
  param([string]$Path)
  $results = @()
  if (-not (Test-Path $Path)) { return $results }
  $sepArrow = [string][char]0x2192
  $acIdPattern = 'AC-[A-Za-z]*\d+(?:\.\d+)*'
  $sectionAc = ""
  $pendingAc = ""
  foreach ($line in (Get-Content $Path -Encoding UTF8)) {
    # Format 2: section heading "### AC-N: <title>"
    if ($line -match "^###\s+($acIdPattern)") {
      $sectionAc = $Matches[1]
      $pendingAc = ""
      continue
    }
    # Any other ### heading ends the current section
    if ($line -match '^###') { $sectionAc = "" }
    # In section: look for first verify: line
    if ($sectionAc) {
      if ($line -match '^\s*verify:\s*(.+?)\s*$') {
        $results += [PSCustomObject]@{ AcId = $sectionAc; VerifyCmd = $Matches[1] }
        $sectionAc = ""
        continue
      }
      continue
    }
    # Format 1: "AC: AC-N <desc> | verify: <cmd>"
    if ($line -match "^AC:\s*($acIdPattern)") {
      $acId = $Matches[1]
      $verifyCmd = ""
      if ($line -match "[|$sepArrow]\s*verify:\s*(.+?)\s*$") { $verifyCmd = $Matches[1] }
      $results += [PSCustomObject]@{ AcId = $acId; VerifyCmd = $verifyCmd }
      $pendingAc = ""
      continue
    }
    # Format 3: "- AC-N: <desc>" with same-line or next-line verify:
    if ($line -match "^-\s+($acIdPattern)") {
      $acId = $Matches[1]
      $verifyCmd = ""
      if ($line -match '\|\s*verify:\s*(.+?)\s*$') { $verifyCmd = $Matches[1] }
      if ($verifyCmd) {
        $results += [PSCustomObject]@{ AcId = $acId; VerifyCmd = $verifyCmd }
      } else {
        $pendingAc = $acId
      }
      continue
    }
    # Pending Format 3: next line "  verify: <cmd>"
    if ($pendingAc) {
      if ($line -match '^\s*verify:\s*(.+?)\s*$') {
        $results += [PSCustomObject]@{ AcId = $pendingAc; VerifyCmd = $Matches[1] }
        $pendingAc = ""
        continue
      }
      $results += [PSCustomObject]@{ AcId = $pendingAc; VerifyCmd = "" }
      $pendingAc = ""
    }
    # Format 4: "| AC-N | <desc> | verify: <cmd> |"
    if ($line -match "^\|\s*($acIdPattern)") {
      $acId = $Matches[1]
      $verifyCmd = ""
      if ($line -match 'verify:\s*([^|]+)') { $verifyCmd = $Matches[1].Trim() }
      $results += [PSCustomObject]@{ AcId = $acId; VerifyCmd = $verifyCmd }
      continue
    }
  }
  if ($pendingAc) { $results += [PSCustomObject]@{ AcId = $pendingAc; VerifyCmd = "" } }
  if ($sectionAc) { $results += [PSCustomObject]@{ AcId = $sectionAc; VerifyCmd = "" } }
  return $results
}

# v6.12.1 (issue #11 C-1): anchored card-status predicate. Unanchored
# 'status:.*active' matches also hit prose that merely QUOTES the pattern -
# a card documenting the bug pins itself active (self-referential lock).
function Test-CardStatus([string]$Content, [string]$Status) {
  if (-not $Content) { return $false }
  return [bool]($Content -match ('(?m)^\s*(>\s*)?status:\s*' + [regex]::Escape($Status)))
}

# v6.12.1 (issue #11 B-2): unified task-card field parser, same three formats
# as the pre-commit hook (T-043): inline "FIELD: a,b", markdown "## FIELD"
# section list, YAML frontmatter multi-line list. Returns comma-joined string.
function Get-TaskPatterns([string]$Content, [string]$Field) {
  if (-not $Content) { return "" }
  $inlineMatch = [regex]::Match($Content, ('(?m)^' + [regex]::Escape($Field) + ':\s*(.+)$'))
  if ($inlineMatch.Success) { return $inlineMatch.Groups[1].Value.TrimEnd() }
  $out = @()
  $inSection = $false
  $inFmBlock = $false
  $inFmField = $false
  $fieldLc = $Field.ToLower()
  foreach ($line in ($Content -split "`n")) {
    $l = $line.TrimEnd("`r")
    if ($l -match '^---\s*$') { $inFmBlock = -not $inFmBlock; $inFmField = $false; continue }
    $lLc = $l.ToLower()
    if ($lLc -match ('^##\s+' + [regex]::Escape($fieldLc) + '\s*$')) { $inSection = $true; $inFmField = $false; continue }
    if ($inSection -and $l -match '^##\s+') { break }
    if ($inFmBlock -and $lLc -match ('^' + [regex]::Escape($fieldLc) + ':$')) { $inFmField = $true; $inSection = $false; continue }
    if ($inFmField -and $l -notmatch '^\s' -and $l -ne '') { $inFmField = $false }
    if ($inFmField -and $l -match '^\s+-\s+(.+)$') {
      $entry = $Matches[1] -replace '\s+\(.*$', ''
      if ($entry) { $out += $entry.Trim() }
      continue
    }
    if ($inSection -and $l -match '^-\s+(.+)$') {
      $entry = $Matches[1] -replace '\s+\(.*$', ''
      if ($entry) { $out += $entry.Trim() }
    }
  }
  return ($out -join ',')
}

function Resolve-EnginePath([string]$File) {
  $clean = Trim-Cell $File
  # Registry rows may name root-level files (docs/, tests/, install.ps1, ...)
  # as well as engine-relative files. Prefer an existing project-root path;
  # otherwise retain the historical engine-relative resolution.
  if ($clean -like "engine/*" -or (Test-Path -LiteralPath (Join-Path $Root ($clean -replace "/", [IO.Path]::DirectorySeparatorChar)))) {
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

    if (Test-CardStatus $content 'active') {
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
    } elseif (Test-CardStatus $content 'paused') {
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
    } elseif (Test-CardStatus $content 'done') {
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

# v6.8.0 (D-028/T-033): domain-level INVENTORY.md bidirectional FAIL check.
# (a) INVENTORY->code: every Entry file path in any engine/domains/<domain>/INVENTORY.md
#     row must exist (Test-Path);
# (b) code->INVENTORY: every file path touched by a `done` task card must be represented
#     in its domain's INVENTORY (Entry file column mentions it, or domain has >=1 row).
# Migration grace period: contract-version < 6.8.0 -> WARN; >= 6.8.0 -> FAIL (D-028 section 9).
function Test-InventoryBidirectional {
  $domainsDir = Join-Path $engineDir "domains"
  if (-not (Test-Path $domainsDir)) { return }

  $doctorPath = Join-Path $engineDir "ENGINE_DOCTOR.md"
  $contractVersion = ""
  if (Test-Path $doctorPath) {
    $m = Select-String -Path $doctorPath -Pattern 'contract-version:\s*([0-9]+\.[0-9]+\.[0-9]+)' -List -ErrorAction SilentlyContinue
    if ($m) { $contractVersion = $m.Matches[0].Groups[1].Value }
  }
  $cvInt = 0
  if ($contractVersion -match '^(\d+)\.(\d+)\.(\d+)$') {
    $cvInt = [int]$Matches[1] * 10000 + [int]$Matches[2] * 100 + [int]$Matches[3]
  }
  $violationIsFail = $false
  if ($cvInt -ge 60800) { $violationIsFail = $true }

  # Collect all top-level INVENTORY.md files (maxdepth 2: domains/<domain>/INVENTORY.md).
  $inventoryFiles = @(Get-ChildItem -Path $domainsDir -Recurse -Depth 1 -Filter 'INVENTORY.md' -File -ErrorAction SilentlyContinue)
  if ($inventoryFiles.Count -eq 0) {
    # v6.12.1 (issue #11 D-2): "not initialized" must not be indistinguishable
    # from "checked and clean". Say so explicitly instead of silent green.
    Write-Pass "INVENTORY bidirectional: SKIP (not initialized - no engine/domains/*/INVENTORY.md yet)"
    return
  }

  # (a) INVENTORY->code: Entry file paths must exist.
  $invToCodeViolations = 0
  $entryPathsSeen = New-Object System.Collections.Generic.List[string]
  foreach ($inv in $inventoryFiles) {
    $lines = Get-Content -Path $inv.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
    foreach ($line in $lines) {
      if ($line -match '^\s*$') { continue }
      if ($line -match '^#') { continue }
      if ($line -match '^>') { continue }
      if ($line -match '^<!--') { continue }
      if ($line -match '^\|\s*-') { continue }
      if ($line -match '^\|\s*Feature') { continue }
      $cols = $line -split '\|'
      # cols[0]=empty, cols[1]=Feature, cols[2]=Entry file, cols[3]=Public API, ...
      if ($cols.Count -lt 3) { continue }
      $entryFile = $cols[2].Trim()
      if ([string]::IsNullOrEmpty($entryFile)) { continue }
      if ($entryFile -match '^\[.*\].*$') { continue }
      if ($entryFile -match '<.*>') { continue }
      $fullPath = Join-Path $Root $entryFile
      if (-not (Test-Path $fullPath) -and -not (Test-Path $entryFile)) {
        $invToCodeViolations++
        if ($violationIsFail) {
          Write-Fail "INVENTORY->code: $($inv.FullName) references non-existent Entry file '$entryFile'"
          Write-Output "  human: INVENTORY row in $($inv.Name) points to '$entryFile' which does not exist. Fix the path or remove the row."
        } else {
          Write-Warn "INVENTORY->code: $($inv.Name) references '$entryFile' (grace period, cv=$contractVersion < 6.8.0)"
        }
      } else {
        [void]$entryPathsSeen.Add($entryFile)
      }
    }
  }

  # (b) code->INVENTORY: done task cards' touched files should appear in their domain INVENTORY.
  $codeToInvViolations = 0
  $tasksDir = Join-Path $engineDir "tasks"
  if (Test-Path $tasksDir) {
    $taskFiles = Get-ChildItem -Path $tasksDir -File -Filter "T-*.md" -ErrorAction SilentlyContinue
    foreach ($tf in $taskFiles) {
      if ($tf.Name -match '\.spec\.md$') { continue }
      $content = Get-Content -Raw -Path $tf.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
      if (-not $content) { continue }
      if (-not (Test-CardStatus $content 'done')) { continue }
      $tid = $tf.BaseName
      # v6.12.1 (issue #11 B-2): unified parser (inline/section/frontmatter).
      # The old inline-only ^WRITE-SET: grep meant this check never evaluated
      # a single section-list card - the core v6.8.0 gate was a no-op.
      $wsRaw = Get-TaskPatterns $content 'WRITE-SET'
      if (-not $wsRaw) { continue }
      $wsPaths = $wsRaw -split ',' | ForEach-Object { $_.Trim() }
      foreach ($wsPath in $wsPaths) {
        if ([string]::IsNullOrEmpty($wsPath)) { continue }
        if ($wsPath -match '\*') { continue }
        if ($wsPath -match '^engine/') { continue }
        if ($wsPath -match '^plugin/') { continue }
        if ($wsPath -eq 'VERSION') { continue }
        if ($wsPath -eq 'CHANGELOG.md') { continue }
        if ($wsPath -eq 'AGENTS.md') { continue }
        if ($wsPath -match '^\.github/') { continue }
        $matched = $false
        foreach ($seen in $entryPathsSeen) {
          if ($seen -like "*$wsPath*") { $matched = $true; break }
        }
        if (-not $matched) {
          $codeToInvViolations++
          if ($violationIsFail) {
            Write-Fail "code->INVENTORY: $tid touched '$wsPath' but no INVENTORY row references it"
            Write-Output "  human: Done task $tid touched file '$wsPath' which is not in any domain INVENTORY. Add a row (Feature / Entry file / Public API / Status / Last verified) to the appropriate engine/domains/<domain>/INVENTORY.md."
          } else {
            Write-Warn "code->INVENTORY: $tid touched '$wsPath' (grace period, cv=$contractVersion < 6.8.0)"
          }
        }
      }
    }
  }

  $totalInv = $inventoryFiles.Count
  if ($invToCodeViolations -eq 0 -and $codeToInvViolations -eq 0) {
    Write-Pass "INVENTORY bidirectional summary: $totalInv domain(s) checked, both directions clean (cv=$contractVersion)"
  }
}

# v6.8.0 (D-028 section 10 mechanism C): INVENTORY Public API column must be unique across repo.
# Scans all engine/domains/*/INVENTORY.md + engine/domains/*/INVENTORY/*.md files.
# Migration grace period: contract-version < 6.8.0 -> WARN; >= 6.8.0 -> FAIL (D-028 section 9).
function Test-InventoryApiUniqueness {
  $domainsDir = Join-Path $engineDir "domains"
  if (-not (Test-Path $domainsDir)) { return }

  $doctorPath = Join-Path $engineDir "ENGINE_DOCTOR.md"
  $contractVersion = ""
  if (Test-Path $doctorPath) {
    $m = Select-String -Path $doctorPath -Pattern 'contract-version:\s*([0-9]+\.[0-9]+\.[0-9]+)' -List -ErrorAction SilentlyContinue
    if ($m) { $contractVersion = $m.Matches[0].Groups[1].Value }
  }
  $cvInt = 0
  if ($contractVersion -match '^(\d+)\.(\d+)\.(\d+)$') {
    $cvInt = [int]$Matches[1] * 10000 + [int]$Matches[2] * 100 + [int]$Matches[3]
  }
  $violationIsFail = $false
  if ($cvInt -ge 60800) { $violationIsFail = $true }

  # Collect all inventory files: top-level INVENTORY.md + sub-files INVENTORY/*.md.
  $inventoryFiles = @()
  $inventoryFiles += Get-ChildItem -Path $domainsDir -Recurse -Depth 1 -Filter 'INVENTORY.md' -File -ErrorAction SilentlyContinue
  $inventorySubFiles = Get-ChildItem -Path $domainsDir -Recurse -Depth 2 -Filter '*.md' -File -ErrorAction SilentlyContinue | Where-Object { $_.FullName -match '\\INVENTORY\\[^\\]+\.md$' }
  $inventoryFiles += $inventorySubFiles
  if ($inventoryFiles.Count -eq 0) {
    # v6.12.1 (issue #11 D-2): explicit SKIP instead of silent green.
    Write-Pass "INVENTORY API uniqueness: SKIP (not initialized)"
    return
  }

  # Extract Public API column (3rd column) from each table row.
  $apiEntries = @{}  # api -> list of file paths
  foreach ($inv in $inventoryFiles) {
    $lines = Get-Content -Path $inv.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
    foreach ($line in $lines) {
      if ($line -match '^\s*$') { continue }
      if ($line -match '^#') { continue }
      if ($line -match '^>') { continue }
      if ($line -match '^<!--') { continue }
      if ($line -match '^\|\s*-') { continue }
      if ($line -match '^\|\s*Feature') { continue }
      $cols = $line -split '\|'
      if ($cols.Count -lt 4) { continue }
      $api = $cols[3].Trim()
      if ([string]::IsNullOrEmpty($api)) { continue }
      if ($api -match '^\[.*\].*$') { continue }
      if ($api -match '<.*>') { continue }
      if (-not $apiEntries.ContainsKey($api)) {
        $apiEntries[$api] = New-Object System.Collections.Generic.List[string]
      }
      [void]$apiEntries[$api].Add($inv.Name)
    }
  }

  $dupCount = 0
  foreach ($kv in $apiEntries.GetEnumerator()) {
    if ($kv.Value.Count -gt 1) {
      $dupCount++
      $occurrences = ($kv.Value | Sort-Object -Unique) -join ' '
      if ($violationIsFail) {
        Write-Fail "INVENTORY API uniqueness: '$($kv.Key)' appears in multiple inventory files: $occurrences"
        Write-Output "  human: Public API contract name '$($kv.Key)' is duplicated across INVENTORY files. Rename one, or mark the deprecated one with Status=deprecated and a clear successor note."
      } else {
        Write-Warn "INVENTORY API uniqueness: '$($kv.Key)' duplicated (grace period, cv=$contractVersion < 6.8.0)"
      }
    }
  }

  if ($dupCount -eq 0) {
    $totalApis = $apiEntries.Count
    Write-Pass "INVENTORY API uniqueness: $totalApis API names across $($inventoryFiles.Count) file(s), all unique (cv=$contractVersion)"
  }
}

# v6.9.0 (D-028 §10 mechanism A / T-034 AC-5.1): WRITE-SET static budget soft gate.
# Sums byte length of all files listed in active card's WRITE-SET; > 30KB triggers
# soft gate (FAIL unless checkpoint_plan field is declared, D-028 §9 tryout bypass).
# Migration grace period: contract-version < 6.9.0 -> WARN; >= 6.9.0 -> FAIL.
function Test-WriteSetBudget {
  $tasksDir = Join-Path $engineDir "tasks"
  if (-not (Test-Path $tasksDir)) { return }

  $doctorPath = Join-Path $engineDir "ENGINE_DOCTOR.md"
  $contractVersion = ""
  if (Test-Path $doctorPath) {
    $m = Select-String -Path $doctorPath -Pattern 'contract-version:\s*([0-9]+\.[0-9]+\.[0-9]+)' -List -ErrorAction SilentlyContinue
    if ($m) { $contractVersion = $m.Matches[0].Groups[1].Value }
  }
  $cvInt = 0
  if ($contractVersion -match '^(\d+)\.(\d+)\.(\d+)$') {
    $cvInt = [int]$Matches[1] * 10000 + [int]$Matches[2] * 100 + [int]$Matches[3]
  }
  $violationIsFail = $false
  if ($cvInt -ge 60900) { $violationIsFail = $true }

  $budgetBytes = 30720  # 30KB
  $taskFiles = Get-ChildItem -Path $tasksDir -Filter 'T-*.md' -File -ErrorAction SilentlyContinue
  foreach ($f in $taskFiles) {
    if ($f.Name -like '*.spec.md') { continue }
    $content = Get-Content -Raw -Path $f.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not (Test-CardStatus $content 'active')) { continue }
    $tid = $f.BaseName
    # checkpoint_plan bypass: any non-empty value (incl. tryout) downgrades FAIL->WARN.
    $checkpointPlan = ""
    if ($content -match 'checkpoint_plan:\s*([^|]*)') { $checkpointPlan = $Matches[1].Trim() }
    $hasBypass = (-not [string]::IsNullOrEmpty($checkpointPlan))

    # Sum byte length of all concrete files in WRITE-SET (skip globs).
    $writeSetLine = ""
    if ($content -match '(?m)^WRITE-SET:\s*(.*)$') { $writeSetLine = $Matches[1].Trim() }
    if ([string]::IsNullOrEmpty($writeSetLine)) { continue }
    $totalBytes = 0
    foreach ($wsPath in ($writeSetLine -split ',')) {
      $wsPath = $wsPath.Trim()
      if ([string]::IsNullOrEmpty($wsPath)) { continue }
      if ($wsPath -like '*\**' -or $wsPath -like '*/**' -or $wsPath -like '*\*' -or $wsPath -like '*/*') { continue }
      $full = Join-Path $Root ($wsPath -replace '/', [IO.Path]::DirectorySeparatorChar)
      if (Test-Path $full -PathType Leaf) {
        $totalBytes += (Get-Item $full).Length
      }
    }
    if ($totalBytes -gt $budgetBytes) {
      $kb = [int]($totalBytes / 1024)
      if ($hasBypass) {
        Write-Warn "task $tid WRITE-SET budget ${kb}KB > 30KB but checkpoint_plan declared (bypass, cv=$contractVersion)"
      } elseif ($violationIsFail) {
        Write-Fail "task $tid WRITE-SET budget ${kb}KB > 30KB - split card or declare checkpoint_plan"
        Write-Output "  human: Active task $tid has WRITE-SET totaling ${kb}KB across listed files (threshold 30KB ~ 8000 tokens). Either split into smaller cards, or add a 'checkpoint_plan: <text or tryout>' field to the task card header to declare a bypass (D-028 S9)."
      } else {
        Write-Warn "task $tid WRITE-SET budget ${kb}KB > 30KB (grace period, cv=$contractVersion < 6.9.0)"
      }
    }
  }
}

# v6.9.0 (D-028 §9 / T-034 AC-6): task granularity soft gate.
# 4 thresholds: AC count > 12, WRITE-SET distinct paths > 15, estimated_steps > 20,
# WRITE-SET bytes > 30KB (delegated to Test-WriteSetBudget).
# Any threshold hit and no checkpoint_plan field = FAIL; declaring checkpoint_plan
# (non-empty, including `tryout`) downgrades FAIL->WARN.
function Test-TaskGranularity {
  $tasksDir = Join-Path $engineDir "tasks"
  if (-not (Test-Path $tasksDir)) { return }

  $doctorPath = Join-Path $engineDir "ENGINE_DOCTOR.md"
  $contractVersion = ""
  if (Test-Path $doctorPath) {
    $m = Select-String -Path $doctorPath -Pattern 'contract-version:\s*([0-9]+\.[0-9]+\.[0-9]+)' -List -ErrorAction SilentlyContinue
    if ($m) { $contractVersion = $m.Matches[0].Groups[1].Value }
  }
  $cvInt = 0
  if ($contractVersion -match '^(\d+)\.(\d+)\.(\d+)$') {
    $cvInt = [int]$Matches[1] * 10000 + [int]$Matches[2] * 100 + [int]$Matches[3]
  }
  $violationIsFail = $false
  if ($cvInt -ge 60900) { $violationIsFail = $true }

  $acThreshold = 12
  $pathThreshold = 15
  $stepsThreshold = 20

  $taskFiles = Get-ChildItem -Path $tasksDir -Filter 'T-*.md' -File -ErrorAction SilentlyContinue
  foreach ($f in $taskFiles) {
    if ($f.Name -like '*.spec.md') { continue }
    $content = Get-Content -Raw -Path $f.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not (Test-CardStatus $content 'active')) { continue }
    $tid = $f.BaseName

    # checkpoint_plan bypass: any non-empty value (incl. tryout) downgrades FAIL->WARN.
    $checkpointPlan = ""
    if ($content -match 'checkpoint_plan:\s*([^|]*)') { $checkpointPlan = $Matches[1].Trim() }
    $hasBypass = (-not [string]::IsNullOrEmpty($checkpointPlan))

    # AC count: count lines starting with "AC:".
    $acCount = 0
    foreach ($ln in ($content -split "`n")) {
      if ($ln -match '^AC:') { $acCount++ }
    }

    # WRITE-SET distinct paths: count comma-separated entries, de-dup mirror pairs
    # (engine/X and plugin/engine/X count as 1).
    $writeSetLine = ""
    if ($content -match '(?m)^WRITE-SET:\s*(.*)$') { $writeSetLine = $Matches[1].Trim() }
    $distinctCount = 0
    if (-not [string]::IsNullOrEmpty($writeSetLine)) {
      $seen = New-Object System.Collections.Generic.HashSet[string]
      foreach ($p in ($writeSetLine -split ',')) {
        $p = $p.Trim()
        if ([string]::IsNullOrEmpty($p)) { continue }
        # De-dup mirror pairs: strip "plugin/" prefix for comparison.
        $canonical = $p
        if ($p -like 'plugin/*') { $canonical = $p -replace '^plugin/', '' }
        [void]$seen.Add($canonical)
      }
      $distinctCount = $seen.Count
    }

    # estimated_steps: parse from header line "> estimated_steps: N | ..."
    $estimatedSteps = 0
    if ($content -match 'estimated_steps:\s*(\d+)') { $estimatedSteps = [int]$Matches[1] }

    # Check thresholds.
    $hit = 0
    $hitMsg = ""
    if ($acCount -gt $acThreshold) { $hit = 1; $hitMsg = "AC count $acCount > $acThreshold" }
    if ($distinctCount -gt $pathThreshold) { $hit = 1; $hitMsg = "$hitMsg; WRITE-SET distinct paths $distinctCount > $pathThreshold" }
    if ($estimatedSteps -gt 0 -and $estimatedSteps -gt $stepsThreshold) { $hit = 1; $hitMsg = "$hitMsg; estimated_steps $estimatedSteps > $stepsThreshold" }

    if ($hit -eq 1) {
      if ($hasBypass) {
        Write-Warn "task $tid granularity soft gate hit ($hitMsg) but checkpoint_plan declared (bypass, cv=$contractVersion)"
      } elseif ($violationIsFail) {
        Write-Fail "task $tid granularity soft gate hit ($hitMsg) - split card or declare checkpoint_plan"
        Write-Output "  human: Active task $tid exceeds granularity thresholds ($hitMsg). Either split into smaller cards, or add a 'checkpoint_plan: <text or tryout>' field to the task card header to declare a bypass (D-028 S9)."
      } else {
        Write-Warn "task $tid granularity soft gate hit ($hitMsg) (grace period, cv=$contractVersion < 6.9.0)"
      }
    }
  }
}

# v6.9.0 (D-028 §9 / T-034 AC-6): depends-on dependency gate.
# Active card with `depends-on: T-NNN, T-NNN` field where any upstream is not done = FAIL.
# Cross-domain split coordination. Migration grace period: < 6.9.0 -> WARN; >= 6.9.0 -> FAIL.
function Test-DependsOn {
  $tasksDir = Join-Path $engineDir "tasks"
  if (-not (Test-Path $tasksDir)) { return }

  $doctorPath = Join-Path $engineDir "ENGINE_DOCTOR.md"
  $contractVersion = ""
  if (Test-Path $doctorPath) {
    $m = Select-String -Path $doctorPath -Pattern 'contract-version:\s*([0-9]+\.[0-9]+\.[0-9]+)' -List -ErrorAction SilentlyContinue
    if ($m) { $contractVersion = $m.Matches[0].Groups[1].Value }
  }
  $cvInt = 0
  if ($contractVersion -match '^(\d+)\.(\d+)\.(\d+)$') {
    $cvInt = [int]$Matches[1] * 10000 + [int]$Matches[2] * 100 + [int]$Matches[3]
  }
  $violationIsFail = $false
  if ($cvInt -ge 60900) { $violationIsFail = $true }

  $taskFiles = Get-ChildItem -Path $tasksDir -Filter 'T-*.md' -File -ErrorAction SilentlyContinue
  foreach ($f in $taskFiles) {
    if ($f.Name -like '*.spec.md') { continue }
    $content = Get-Content -Raw -Path $f.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not (Test-CardStatus $content 'active')) { continue }
    $tid = $f.BaseName

    # Parse depends-on field (comma-separated list of T-NNN). Also accept depends_on.
    $dependsLine = ""
    if ($content -match 'depends-on:\s*([^|]*)') { $dependsLine = $Matches[1].Trim() }
    if ([string]::IsNullOrEmpty($dependsLine) -and $content -match 'depends_on:\s*([^|]*)') { $dependsLine = $Matches[1].Trim() }
    if ([string]::IsNullOrEmpty($dependsLine)) { continue }

    foreach ($upstream in ($dependsLine -split ',')) {
      $upstream = $upstream.Trim()
      if ([string]::IsNullOrEmpty($upstream)) { continue }
      if ($upstream -notmatch '^T-\d+$') { continue }
      $upstreamFile = Join-Path $tasksDir ($upstream + ".md")
      if (-not (Test-Path $upstreamFile)) {
        if ($violationIsFail) {
          Write-Fail "task $tid depends-on $upstream but upstream card not found"
          Write-Output "  human: Active task $tid declares depends-on: $upstream, but no task card exists at engine/tasks/$upstream.md. Remove the depends-on entry or create the upstream card."
        } else {
          Write-Warn "task $tid depends-on $upstream not found (grace period, cv=$contractVersion < 6.9.0)"
        }
        continue
      }
      $upstreamContent = Get-Content -Raw -Path $upstreamFile -Encoding UTF8 -ErrorAction SilentlyContinue
      if (-not (Test-CardStatus $upstreamContent 'done')) {
        if ($violationIsFail) {
          Write-Fail "task $tid depends-on $upstream which is not done - block active"
          Write-Output "  human: Active task $tid declares depends-on: $upstream, but $upstream is not done. Either complete $upstream first (run 'engine verify $upstream' and mark done), or remove the depends-on entry if the dependency no longer applies."
        } else {
          Write-Warn "task $tid depends-on $upstream not done (grace period, cv=$contractVersion < 6.9.0)"
        }
      }
    }
  }
}

# v6.10.0 (D-028/T-035): warn_count → done gate. For any task card whose
# evidence/T-NNN/DEAD-CODE.json exists:
#  - top-level exempt_all: true  → pass (batch exemption, D-028 §9)
#  - summary.warn_count == 0     → pass (clean)
#  - all entries[].exempt: true → pass (per-entry exemption, fine-grained)
#  - otherwise: warn_count > 0 with unexempted entries → FAIL (or WARN if
#    contract-version < 6.10.0 grace period, aligned with D-028 §9).
# The check applies to any task with DEAD-CODE.json present (active or done).
# Architectural exemption is via top-level exempt_all + exempt_reason, or
# per-entry exempt + exempt_reason.
function Test-WarnDoneGate {
  $tasksDir = Join-Path $engineDir "tasks"
  if (-not (Test-Path $tasksDir)) { return }

  $doctorPath = Join-Path $engineDir "ENGINE_DOCTOR.md"
  $contractVersion = ""
  if (Test-Path $doctorPath) {
    $m = Select-String -Path $doctorPath -Pattern 'contract-version:\s*([0-9]+\.[0-9]+\.[0-9]+)' -List -ErrorAction SilentlyContinue
    if ($m) { $contractVersion = $m.Matches[0].Groups[1].Value }
  }
  $cvInt = 0
  if ($contractVersion -match '^(\d+)\.(\d+)\.(\d+)$') {
    $cvInt = [int]$Matches[1] * 10000 + [int]$Matches[2] * 100 + [int]$Matches[3]
  }
  $violationIsFail = $false
  if ($cvInt -ge 61000) { $violationIsFail = $true }

  $dcMissing = 0
  $taskFiles = Get-ChildItem -Path $tasksDir -Filter 'T-*.md' -File -ErrorAction SilentlyContinue
  foreach ($f in $taskFiles) {
    if ($f.Name -like '*.spec.md') { continue }
    $content = Get-Content -Raw -Path $f.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
    # Gate applies only to `done` tasks - active/paused tasks may have
    # in-progress DEAD-CODE.json with warn_count > 0 (architect hasn't
    # reviewed yet). The done gate fires when architect marks done.
    if (-not (Test-CardStatus $content 'done')) { continue }
    $tid = $f.BaseName
    $dcFile = Join-Path $engineDir "evidence\$tid\DEAD-CODE.json"
    # v6.12.1 (issue #11 D-2): count silent skips instead of hiding them.
    if (-not (Test-Path $dcFile)) { $dcMissing++; continue }

    $dcContent = Get-Content -Raw -Path $dcFile -Encoding UTF8 -ErrorAction SilentlyContinue
    if ([string]::IsNullOrEmpty($dcContent)) { continue }

    # Top-level exempt_all: true → batch exemption (D-028 §9).
    if ($dcContent -match '"exempt_all"\s*:\s*true') {
      Write-Pass "task $tid DEAD-CODE.json exempt_all:true (batch exemption)"
      continue
    }

    # Read summary.warn_count.
    $warnCount = 0
    $wcMatch = [regex]::Match($dcContent, '"warn_count"\s*:\s*(\d+)')
    if ($wcMatch.Success) { $warnCount = [int]$wcMatch.Groups[1].Value }

    if ($warnCount -eq 0) {
      Write-Pass "task $tid DEAD-CODE.json warn_count=0 (clean)"
      continue
    }

    # Count per-entry exempt fields. Pattern `"exempt":` is specific to
    # per-entry (top-level is `"exempt_all":`, reason is `"exempt_reason":`,
    # count is `"exempt_count":` - none collide with `"exempt":`).
    $totalEntries = ([regex]::Matches($dcContent, '"exempt"\s*:\s*')).Count
    $exemptEntries = ([regex]::Matches($dcContent, '"exempt"\s*:\s*true')).Count

    # Defensive: if totalEntries is 0 (parse failed), skip rather than
    # falsely failing on an unparseable file.
    if ($totalEntries -eq 0) {
      Write-Warn "task $tid DEAD-CODE.json has warn_count=$warnCount but no entries[] parsed (skip)"
      continue
    }

    if ($exemptEntries -eq $totalEntries) {
      Write-Pass "task $tid DEAD-CODE.json all $totalEntries entries exempt (warn_count=$warnCount)"
      continue
    }

    $unexempt = $totalEntries - $exemptEntries
    if ($violationIsFail) {
      Write-Fail "task $tid DEAD-CODE.json has $unexempt unexempted warn entry/entries (warn_count=$warnCount) - mark exempt:true or top-level exempt_all:true"
      Write-Output "  human: Task $tid has dead-code warnings ($warnCount warn, $unexempt not exempted). Architect must review evidence/$tid/DEAD-CODE.json and mark each entry `"exempt`": true with a reason, or set top-level `"exempt_all`": true with `"exempt_reason`"."
    } else {
      Write-Warn "task $tid DEAD-CODE.json has $unexempt unexempted warn entry/entries (grace period, cv=$contractVersion < 6.10.0)"
      Write-Output "  human: Task $tid has dead-code warnings ($warnCount warn, $unexempt not exempted). Migration grace period (cv=$contractVersion < 6.10.0); WARN only. To fix: mark exemptions in evidence/$tid/DEAD-CODE.json."
    }
  }
  # v6.12.1 (issue #11 D-2): "no DEAD-CODE evidence" and "checked clean" must
  # not collapse into the same silence. One summary line, no per-card spam.
  if ($dcMissing -gt 0) {
    Write-Pass "warn-done gate: $dcMissing done card(s) have no DEAD-CODE.json (not initialized - predates v6.10.0, skipped)"
  }
}

# v6.12.1 (issue #11 C-1): a single card must never satisfy both the active and
# done predicates. Report the contradiction itself instead of letting the
# downstream diagnostics fight about which state governs.
function Test-StatusConflict {
  $tasksDir = Join-Path $engineDir "tasks"
  if (-not (Test-Path $tasksDir)) { return }
  foreach ($f in (Get-ChildItem -Path $tasksDir -Filter 'T-*.md' -File -ErrorAction SilentlyContinue)) {
    if ($f.Name -match '\.spec\.md$') { continue }
    $content = Get-Content -Raw -Path $f.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
    if ((Test-CardStatus $content 'active') -and (Test-CardStatus $content 'done')) {
      $tid = $f.BaseName
      Write-Fail "task $tid declares BOTH active and done status lines - card state is self-contradictory"
      Write-Output "  human: engine/tasks/$tid.md contains an anchored 'status: active' line AND an anchored 'status: done' line. Gates cannot agree which one governs. Remove the stale line so the card has exactly one status."
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

function Test-EvidencePass([string]$Content) {
  if ($Content -match '(?i)"status"\s*:\s*"pass"') { return $true }
  if ($Content -match '(?i)"status"\s*:') { return $false }
  return ($Content -match '(?i)"verdict"\s*:\s*"pass"')
}

function Test-LegacyVerdictEvidence([string]$Content) {
  return (($Content -match '(?i)"verdict"\s*:\s*"pass"') -and ($Content -notmatch '(?i)"status"\s*:'))
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
    if (-not (Test-CardStatus $content 'done')) { continue }
    $doneCount++
    $tid = $f.BaseName
    $evDir = Join-Path $engineDir ("evidence\" + $tid)
    if ($content -match 'exempt') {
      $exemptCount++
      continue
    }
    $acIds = @(Parse-AcDeclarations -Path $f.FullName | ForEach-Object { $_.AcId })
    $missing = New-Object System.Collections.Generic.List[string]
    foreach ($ac in $acIds) {
      $evPath = Join-Path $evDir ($ac + '.json')
      if (-not (Test-Path $evPath)) { $missing.Add($ac); continue }
      $evContent = Get-Content -Raw -Path $evPath -Encoding UTF8 -ErrorAction SilentlyContinue
      if (-not (Test-EvidencePass $evContent)) {
        $missing.Add($ac)
      } elseif (Test-LegacyVerdictEvidence $evContent) {
        Write-Warn "task $tid/$ac uses legacy verdict evidence (accepted; re-run 'engine verify $tid' to write status=pass)"
        Write-Output "  human: Evidence for $tid/$ac uses the legacy verdict=PASS field. It is accepted for compatibility; re-run engine verify to upgrade it to status=pass."
      }
    }
    if ($acIds.Count -gt 0 -and $missing.Count -eq 0) {
      $verifiedCount++
    } else {
      $missingText = if ($missing.Count -gt 0) { $missing -join ',' } else { 'no declared AC' }
      $inHead = $false
      if (Get-Command git -ErrorAction SilentlyContinue) {
        git cat-file -e "HEAD:engine/tasks/$tid.md" 2>$null
        if ($LASTEXITCODE -eq 0) { $inHead = $true }
      }
      if ($inHead) {
        Write-Warn "task $tid (pre-existing in HEAD) done with AC evidence drift ($missingText) - legacy card, run 'engine verify $tid' or mark exempt"
        Write-Output "  human: Task '$tid' was 'done' in HEAD; evidence may have drifted. Re-verify or mark exempt."
      } else {
        Write-Fail "task $tid done without complete PASS evidence ($missingText) - run 'engine verify $tid' or mark exempt"
        Write-Output "  human: Task '$tid' is marked as done, but every declared AC needs a PASS evidence file. Missing/non-pass: $missingText."
      }
    }
  }
  if ($doneCount -gt 0) {
    Write-Pass "done task evidence summary: $doneCount checked ($verifiedCount verified, $exemptCount exempt)"
  }
}

# v6.18.0 (D-038/T-066 AC-8): drift-check integration. Defers to the
# standalone engine-drift-check.ps1 script (cheap fingerprint comparison,
# no verify re-run). Tamper/drift = FAIL; warn-only issues stay WARN.
function Test-Drift {
  $script = Join-Path $EngineDir "scripts\engine-drift-check.ps1"
  if (-not (Test-Path $script)) {
    Write-Warn "drift-check script missing: $script"
    return
  }
  $gitCmd = Get-Command git -ErrorAction SilentlyContinue
  if (-not $gitCmd) {
    Write-Warn "git not on PATH - drift-check skipped"
    return
  }
  $out = & pwsh -NoProfile -File $script 2>&1 | Out-String
  $rc = $LASTEXITCODE
  if ($out) {
    foreach ($line in ($out -split "`r?`n")) {
      if ($line) { Write-Output "  $line" }
    }
  }
  if ($rc -ne 0) {
    Write-Fail "drift-check detected tamper or drift (see above)"
    Write-Output "  human: Evidence integrity or code fingerprint mismatch. Re-run 'engine verify <T-NNN>' against current HEAD, or mark evidence-manual-edit with a covering approved decision."
  } else {
    Write-Pass "drift-check passed (no tamper, no drift)"
  }
}

# v6.19.0 (D-038c/T-067): derived status panel check. Double-write transition:
# CONTEXT.md static panel is labeled "legacy" while engine context outputs a
# real-time "Derived Status" segment. Doctor verifies (1) the legacy annotation
# exists and (2) derived values (git tag vs engine/VERSION) match the static
# declaration. Mismatches are WARN only during the double-write transition.
function Test-DerivedStatus {
  $ctx = Join-Path $EngineDir "CONTEXT.md"
  if (-not (Test-Path $ctx)) { return }
  $gitExe = Get-Command git -ErrorAction SilentlyContinue
  if (-not $gitExe) {
    Write-Warn "git not on PATH - derived status check skipped"
    return
  }

  # (1) Legacy annotation check.
  $ctxContent = Get-Content -Raw -Path $ctx -Encoding UTF8 -ErrorAction SilentlyContinue
  if ($ctxContent -match '<!-- legacy: status-panel') {
    Write-Pass "CONTEXT.md status-panel has legacy annotation (double-write transition)"
  } else {
    Write-Warn "CONTEXT.md status-panel missing <!-- legacy: status-panel --> annotation"
    Write-Output "  human: Add <!-- legacy: status-panel (double-write transition, v6.19.0~v6.20.0) --> after the status panel header. See D-038c."
    return
  }

  # (2) Derived value consistency: latest git tag vs engine/VERSION.
  $latestTag = "none"
  try {
    $latestTag = (git -C $Root describe --tags --abbrev=0 2>$null) -join ''
    if (-not $latestTag) { $latestTag = "none" }
  } catch { $latestTag = "none" }

  $engineVer = "unknown"
  $evFile = Join-Path $EngineDir "VERSION"
  if (Test-Path $evFile) {
    $engineVer = (Get-Content $evFile -Raw -Encoding UTF8 -ErrorAction SilentlyContinue).Trim()
  }
  $latestVer = $latestTag -replace '^v', ''

  if ($latestVer -eq $engineVer) {
    Write-Pass "derived tag/VERSION consistent ($latestTag = $engineVer)"
  } else {
    Write-Warn "derived tag/VERSION mismatch: git tag=$latestTag, engine/VERSION=$engineVer"
    Write-Output "  human: The latest git tag does not match engine/VERSION. Run 'engine update' or create a matching tag."
  }

  # (3) Check static panel mentions the latest tag (stale panel detection).
  if ($ctxContent -match [regex]::Escape($latestVer)) {
    Write-Pass "static panel references current version ($latestVer)"
  } else {
    Write-Warn "static panel does not reference current version ($latestVer) - panel may be stale"
    Write-Output "  human: Update the status panel in CONTEXT.md to mention v$engineVer, or rely on the Derived Status segment."
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
  # semantics - comparing it against the engine tooling version (e.g. 6.0.1)
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

function Test-Engineignore {
  # v6.13.0 (T-052/D-036, issue #17): WARN if .engineignore lists product paths.
  $ei = Join-Path $Root ".engineignore"
  if (-not (Test-Path $ei)) { return }
  $productPatterns = @('src/**', 'runtime/**', 'contract/**')
  $lines = Get-Content -Path $ei -Encoding UTF8 -ErrorAction SilentlyContinue
  foreach ($p in $productPatterns) {
    $bare = $p -replace '/\*\*$', ''
    foreach ($line in $lines) {
      $trimmed = $line.Trim()
      if ($trimmed -eq '' -or $trimmed.StartsWith('#')) { continue }
      if ($trimmed -eq $p -or $trimmed -eq $bare -or $trimmed.StartsWith("$p ") -or $trimmed.StartsWith("$bare ") -or $trimmed.StartsWith("$bare/")) {
        Write-Warn ".engineignore lists product path '$p' - .engineignore is for non-product paths only (cross-agent anchors, engine tooling, project config). Product paths in .engineignore undermine task-card discipline."
        Write-Output "  human: The file .engineignore contains '$p' which is a product code path. .engineignore should only exempt non-product paths (anchors, tooling, config) from task-card union gating. Remove product paths from .engineignore."
        break
      }
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

# v6.11.0 (D-029/T-036) AC-6: multi-session isolation health check.
# cv >= 6.11.0 -> fail-closed (FAIL); cv < 6.11.0 -> fail-open (WARN, grace period).
# v6.12.2 (T-050): tombstone check downgraded FAIL->WARN. Tombstone is a historical
#   transition record (coordinator-exited / stale-recovered / forced-replaced), not
#   an active-state signal - lock file + lease mtime is the source of truth. A stale
#   tombstone just means the repo has been quiet; it auto-cleans on the next
#   coordinator start (SessionStart hook). cv < 6.12.2 keeps prior FAIL for migration.
# Checks: (1) .cache/sessions dir exists (SessionStart hook should create);
#         (2) session.lock format validity (>= 5 fields);
#         (3) tombstone file staleness (>24h): cv>=6.12.2 WARN, 6.11.0<=cv<6.12.2 FAIL, cv<6.11.0 WARN.
function Test-MultiSessionIsolation {
  $doctorPath = Join-Path $engineDir "ENGINE_DOCTOR.md"
  $contractVersion = ""
  if (Test-Path $doctorPath) {
    $m = Select-String -Path $doctorPath -Pattern 'contract-version:\s*([0-9]+\.[0-9]+\.[0-9]+)' -List -ErrorAction SilentlyContinue
    if ($m) { $contractVersion = $m.Matches[0].Groups[1].Value }
  }
  $cvInt = 0
  if ($contractVersion -match '^(\d+)\.(\d+)\.(\d+)$') {
    $cvInt = [int]$Matches[1] * 10000 + [int]$Matches[2] * 100 + [int]$Matches[3]
  }
  $violationIsFail = $false
  if ($cvInt -ge 61100) { $violationIsFail = $true }
  # T-050 (v6.12.2): tombstone staleness FAIL only on old contract versions
  # (6.11.0 <= cv < 6.12.2). cv >= 6.12.2 downgrades to WARN (tombstone is
  # historical, not active state; auto-cleans on next coordinator start).
  $tombstoneIsFail = $false
  if (($cvInt -ge 61100) -and ($cvInt -lt 61202)) { $tombstoneIsFail = $true }

  $sessionsDir = Join-Path $engineDir '.cache\sessions'
  $lockFile = Join-Path $engineDir '.cache\session.lock'
  $tombstoneFile = Join-Path $engineDir '.cache\session.tombstone'

  # 1. sessions dir exists
  if (-not (Test-Path $sessionsDir)) {
    # CI/非交互式环境 (T-045): SessionStart hook 不会运行, sessions dir 缺失是正常状态
    if ($env:CI -eq 'true' -or $env:GITHUB_ACTIONS -eq 'true') {
      Write-Warn "multi-session isolation: .cache/sessions dir missing (CI environment, SessionStart hook not expected to run, cv=$contractVersion)"
      return
    }
    if ($violationIsFail) {
      Write-Fail "multi-session isolation: .cache/sessions dir missing (cv=$contractVersion >= 6.11.0, SessionStart hook should create it)"
      Write-Output "  human: contract-version $contractVersion requires multi-session isolation, but engine/.cache/sessions directory does not exist. SessionStart hook may not have run. Run 'engine context' to verify hook setup."
    } else {
      Write-Warn "multi-session isolation: .cache/sessions dir missing (grace period, cv=$contractVersion < 6.11.0)"
    }
    return
  }

  # 2. lock file format validity
  if (Test-Path $lockFile) {
    try {
      $lockLine = (Get-Content -Raw -Path $lockFile -Encoding UTF8 -ErrorAction Stop).Trim()
      if ($lockLine) {
        $lockFields = $lockLine -split '\|'
        if ($lockFields.Length -lt 5) {
          if ($violationIsFail) {
            Write-Fail "multi-session isolation: session.lock malformed ($($lockFields.Length) fields, expected 5: pid|sid|role|started_at|task_id)"
            Write-Output "  human: engine/.cache/session.lock has $($lockFields.Length) pipe-separated fields, expected at least 5. Remove the file and let SessionStart hook recreate it."
          } else {
            Write-Warn "multi-session isolation: session.lock malformed (grace period)"
          }
        }
      }
    } catch {}
  }

  # 3. tombstone staleness (>24h)
  # T-050 (v6.12.2): tombstone is a historical transition record, not active state.
  # lock file + lease mtime is the source of truth for active-state problems.
  # cv>=6.12.2 downgrades FAIL->WARN (tombstone auto-cleans on next coordinator start).
  if (Test-Path $tombstoneFile) {
    try {
      $tombstoneLine = (Get-Content -Raw -Path $tombstoneFile -Encoding UTF8 -ErrorAction Stop).Trim()
      $tombstoneParts = $tombstoneLine -split '\|'
      $tombstoneType = if ($tombstoneParts.Length -ge 3) { $tombstoneParts[2] } else { "unknown" }
      if (-not $tombstoneType) { $tombstoneType = "unknown" }
      if ($tombstoneParts.Length -ge 1) {
        $tombstoneTs = $tombstoneParts[0]
        if ($tombstoneTs) {
          $ts = [datetime]::SpecifyKind([datetime]::Parse($tombstoneTs), [System.DateTimeKind]::Utc)
          $ageSec = ([datetime]::UtcNow - $ts).TotalSeconds
          if ($ageSec -gt 86400) {
            if ($tombstoneIsFail) {
              Write-Fail "multi-session isolation: tombstone file is stale ($([int]$ageSec)s old, type=$tombstoneType, >24h) - run 'engine assume-coordinator --force' to clean up"
              Write-Output "  human: engine/.cache/session.tombstone is $([int]($ageSec / 3600))h old (type=$tombstoneType). Run 'engine assume-coordinator --force' to take over."
            } else {
              Write-Warn "multi-session isolation: tombstone is a historical transition record (type=$tombstoneType, $([int]$ageSec)s old, >24h); not an active failure - lock file + lease mtime is the source of truth; auto-cleans on next coordinator start (cv=$contractVersion)"
            }
          }
        }
      }
    } catch {}
  }
}

# v6.12.0 (D-035) multi-card WRITE-SET overlap check (WARN level).
# Union gating allows several active cards in parallel; when two cards declare
# the SAME WRITE-SET entry (string-equal), both sessions may write it and the
# race falls back to git. Shared singletons and engine/tasks/* own-card paths
# are expected overlaps and excluded.
function Test-MultiCardWritesetOverlap {
  $tasksDir = Join-Path $engineDir 'tasks'
  if (-not (Test-Path $tasksDir)) { return }
  $activeCards = @()
  Get-ChildItem -Path $tasksDir -Filter 'T-*.md' -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notmatch '\.spec\.md$' } | ForEach-Object {
      $c = Get-Content -Raw -Path $_.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
      if (Test-CardStatus $c 'active') { $activeCards += ,@($_.BaseName, $c) }
    }
  if ($activeCards.Count -lt 2) { return }
  $seen = @{}
  $dups = @{}
  foreach ($pair in $activeCards) {
    $cardId = $pair[0]; $content = $pair[1]
    $entries = @()
    $inlineMatch = [regex]::Match($content, '(?m)^WRITE-SET:\s*(.+)$')
    if ($inlineMatch.Success) {
      $entries = $inlineMatch.Groups[1].Value -split ',' | ForEach-Object { $_.Trim() }
    } else {
      $inSection = $false
      foreach ($line in ($content -split "`n")) {
        $l = $line.TrimEnd("`r")
        if ($l -match '^##\s+WRITE-SET\s*$') { $inSection = $true; continue }
        if ($inSection -and $l -match '^##\s+') { break }
        if ($inSection -and $l -match '^-\s+(.+)$') { $entries += $Matches[1].Trim() }
      }
    }
    foreach ($e in $entries) {
      if (-not $e) { continue }
      if ($e -match '^engine/(CONTEXT|HANDOFF|ENGINE_MAP|SYSTEM|REPO_GUIDE|PITFALLS|SPRINT|ROADMAP)\.md$') { continue }
      if ($e -match '^engine/tasks/') { continue }
      if ($seen.ContainsKey($e) -and $seen[$e] -ne $cardId) {
        $dups[$e] = "$($seen[$e])+$cardId"
      } else {
        $seen[$e] = $cardId
      }
    }
  }
  if ($dups.Count -gt 0) {
    $list = ($dups.GetEnumerator() | ForEach-Object { "$($_.Key) ($($_.Value))" }) -join '; '
    Write-Warn "multi-card WRITE-SET overlap: $list"
    Write-Host "  human: two active task cards declare the same WRITE-SET entry. Union gating lets both sessions write it, so concurrent edits race at the git layer. Narrow one card's WRITE-SET, or accept the risk knowingly."
  }
}

# v6.11.0 (D-029/T-036) AC-7: workstream orphan check (WARN level).
# For each engine/workstreams/<task>/<worker>/ shard, check if a matching
# .cache/sessions/<worker_key>.meta file exists. If not, WARN (worker may
# still be running, or exited without Stop hook firing).
function Test-WorkstreamOrphan {
  $workstreamsDir = Join-Path $engineDir 'workstreams'
  if (-not (Test-Path $workstreamsDir)) { return }

  $sessionsDir = Join-Path $engineDir '.cache\sessions'
  $orphanCount = 0
  $taskDirs = @(Get-ChildItem -Path $workstreamsDir -Directory -ErrorAction SilentlyContinue)
  foreach ($taskDir in $taskDirs) {
    $workerDirs = @(Get-ChildItem -Path $taskDir.FullName -Directory -ErrorAction SilentlyContinue)
    foreach ($workerDir in $workerDirs) {
      $workerName = $workerDir.Name
      $metaFound = $false
      if (Test-Path $sessionsDir) {
        $metaPath = Join-Path $sessionsDir ($workerName + '.meta')
        if (Test-Path $metaPath) {
          $metaFound = $true
        } else {
          # Short prefix match (worker_name first 8 chars) - tolerates worker_id=agent_id vs session_key mismatch
          $prefix = if ($workerName.Length -gt 8) { $workerName.Substring(0, 8) } else { $workerName }
          $metaFiles = @(Get-ChildItem -Path $sessionsDir -Filter '*.meta' -ErrorAction SilentlyContinue)
          foreach ($meta in $metaFiles) {
            $metaBase = $meta.BaseName
            $metaPrefix = if ($metaBase.Length -gt 8) { $metaBase.Substring(0, 8) } else { $metaBase }
            if ($metaPrefix -eq $prefix) {
              $metaFound = $true
              break
            }
          }
        }
      }
      if (-not $metaFound) {
        Write-Warn "orphan workstream shard: $($taskDir.Name)/$workerName (no matching .cache/sessions/$workerName.meta)"
        Write-Output "  human: Workstream shard for task $($taskDir.Name) worker $workerName has no .meta file. Worker may still be running, or exited without Stop hook firing. If stale, remove engine/workstreams/$($taskDir.Name)/$workerName/ manually."
        $orphanCount++
      }
    }
  }
  if ($orphanCount -eq 0) {
    Write-Pass "workstream orphan: no orphan shards detected"
  }
}

# v6.20.0 (T-070): review evidence Doctor check (spec §3.3).
function Test-ReviewEvidence {
  $tasksDir = Join-Path $engineDir "tasks"
  if (-not (Test-Path $tasksDir)) { return }
  Get-ChildItem -Path $tasksDir -Filter "T-*.md" | ForEach-Object {
    $f = $_.FullName
    if ($f -like "*.spec.md") { return }
    $content = Get-Content $f -Raw
    if ($content -notmatch '(?m)^\s*(>\s*)?status:\s*done') { return }
    $tid = $_.BaseName
    $reviewFile = Join-Path $engineDir "review\evidence\$tid\REVIEW.json"

    if (-not (Test-Path $reviewFile)) {
      $headContent = git show "HEAD:engine/tasks/$tid.md" 2>$null
      if ($headContent -and ($headContent -match '(?m)^\s*(>\s*)?status:\s*done')) {
        Write-Warn "done task $tid missing review evidence (legacy)"
      } else {
        Write-Fail "newly-done task $tid missing review evidence"
      }
      return
    }

    $review = Get-Content $reviewFile -Raw | ConvertFrom-Json
    $headCommit = git rev-parse HEAD 2>$null
    if ($review.write_provenance.writer -notin @("engine-review","engine-review-from-receipt")) {
      Write-Warn "$tid review evidence writer=$($review.write_provenance.writer) (expected engine-review or engine-review-from-receipt)"
    }
    if ($review.write_provenance.commit -ne $headCommit) {
      # D-040 (issue #28): stale 判定改为 ancestor-of-HEAD。正常 Coordinator closeout
      # 会在 review 之后提交 evidence/任务卡/CONTEXT/HANDOFF/ENGINE_MAP/胶囊,合法推进 HEAD;
      # review commit 仍为 HEAD 祖先即有效,只有被 rebase 掉/分叉/未知 commit 才报 stale。
      $provCommit = $review.write_provenance.commit
      $isAncestor = $false
      if ($provCommit) {
        git merge-base --is-ancestor $provCommit HEAD 2>$null
        if ($LASTEXITCODE -eq 0) { $isAncestor = $true }
      }
      if (-not $isAncestor) {
        Write-Warn "$tid stale review evidence (commit=$($review.write_provenance.commit) HEAD=$headCommit)"
      }
    }
    if ($review.write_provenance.argv -ne "engine review $tid" -and $review.write_provenance.argv -notlike "engine review $tid --from-receipt *") {
      Write-Warn "$tid review evidence argv mismatch: $($review.write_provenance.argv)"
    }
    if ($review.tool_unavailable -eq $true) {
      Write-Warn "$tid review degraded (tool_unavailable=true), architect should confirm"
    }
    if ($review.status -eq "block") {
      Write-Fail "$tid done task has unresolved block findings"
    }
  }
}

# v6.20.0 (T-070): review config protected check (spec §3.3).
function Test-ReviewConfigProtected {
  $rulesFile = Join-Path $engineDir "decisions\rules.json"
  if (-not (Test-Path $rulesFile)) { return }
  if (-not (Test-Path (Join-Path $engineDir "review\config.json"))) { return }
  $rules = Get-Content $rulesFile -Raw
  if ($rules -notmatch '"engine/review/config.json"') {
    Write-Warn "engine/review/config.json not in protected_paths (rule gap)"
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
Test-InventoryBidirectional
Test-InventoryApiUniqueness
Test-WriteSetBudget
Test-TaskGranularity
Test-DependsOn
Test-WarnDoneGate
Test-PitfallsSemantics
Test-SprintSemantics
Test-ChangeCapsuleSemantics
Test-PlanAcceptanceEvidence
Test-ContractCompile
Test-ContractDebt
Test-TaskCardDoneEvidence
Test-Drift
Test-DerivedStatus
Test-EngineVersion
Test-Engineignore
Test-LegacyDataFormat
Test-MultiSessionIsolation
Test-MultiCardWritesetOverlap
Test-StatusConflict
Test-WorkstreamOrphan
Test-ReviewEvidence
Test-ReviewConfigProtected

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
