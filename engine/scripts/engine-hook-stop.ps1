# Engine System - Stop hook (PowerShell)
#
# PowerShell twin of engine-hook-stop.sh. Decisions MUST stay identical to the
# .sh implementation - tests/hook-parity/run-parity.sh + tests/task-card/run-task-tests.sh
# enforce this.
#
# Responsibilities (strict -> lenient):
#   1. Task card gate (v6 S1+S2): with an active task card --
#      (a) WRITE-SET boundary / FORBIDDEN -> block (S1);
#      (b) route consistency: each code_path's domain (from federation.json)
#          must be in the task card's domain set, else block (S2).
#      No active card -> skip (backward compatible).
#   2. Hard gate (v5.6): code changed without CONTEXT/HANDOFF/ENGINE_MAP -> block.
#   3. Soft WARN (v6 S0): memory written but no change capsule -> systemMessage.
#
# Parsing contract: git status --porcelain -z -uall (NUL separated).
# Safety: read-only; fail-open; idempotent via stop_hook_active.

param()

$ErrorActionPreference = "Continue"
trap { Write-Warning "[engine-hook-stop.ps1] error: $_"; continue }

$Root = $env:CLAUDE_PROJECT_DIR
if (-not $Root) { $Root = $PWD.Path }
$EngineDir = Join-Path $Root "engine"

$payload = $input | Out-String
if ($payload -match '"stop_hook_active"\s*:\s*true') { exit 0 }
if (-not (Test-Path $EngineDir)) { exit 0 }

$gitFound = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitFound) { exit 0 }
Push-Location $Root
$inside = git rev-parse --is-inside-work-tree 2>$null
Pop-Location
if ($inside -ne "true") { exit 0 }

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
Push-Location $Root
$raw = git status --porcelain -z -uall 2>$null
Pop-Location
if ($raw -is [array]) { $raw = $raw -join "`n" }
if (-not $raw) { exit 0 }

$codeChanged = $false
$engineWritten = $false
$capsuleWritten = $false
$codePaths = @()
$skipNext = $false

foreach ($rec in ($raw -split "`0")) {
  if (-not $rec) { continue }
  if ($skipNext) { $skipNext = $false; continue }
  if ($rec.Length -lt 4) { continue }
  $st = $rec.Substring(0, 2)
  $path = $rec.Substring(3)
  if ($st -match '[RC]') { $skipNext = $true }

  switch -Wildcard ($path) {
    "engine/CONTEXT.md"          { $engineWritten = $true; break }
    "engine/HANDOFF.md"          { $engineWritten = $true; break }
    "engine/ENGINE_MAP.md"       { $engineWritten = $true; break }
    "engine/changes/CHANGE-*.md" { $capsuleWritten = $true; break }
    "engine/.cache/*"            { break }
    ".engine/*"                  { break }
    "engine/*"                   { break }
    default                      { $codeChanged = $true; $codePaths += $path }
  }
}

# Layer 2: hard gate (write-back check).
if ($codeChanged -and -not $engineWritten) {
  $reason = "[Engine System] Code was changed but project memory was not updated. | developer: The AI needs to save its notes about what was done before ending the session. Please update engine/CONTEXT.md (project status) and engine/HANDOFF.md (session handoff record). Think of it like updating meeting notes after a meeting — before you leave, write down what was decided and what comes next."
  Write-Output "{`"decision`":`"block`",`"reason`":`"$reason`"}"
  exit 0
}

# Layer 1: task card WRITE-SET gate (v6 S1).
$activeTask = $null
$activeTaskId = $null
$tasksDir = Join-Path $EngineDir "tasks"
if (Test-Path $tasksDir) {
  $taskFiles = Get-ChildItem -Path $tasksDir -File -Filter "T-*.md" -ErrorAction SilentlyContinue | Sort-Object Name
  foreach ($tf in $taskFiles) {
    $content = Get-Content -Raw -Path $tf.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
    if ($content -match 'status:\s*active') {
      $activeTask = $tf.FullName
      $activeTaskId = $tf.BaseName
      break
    }
  }
}

if ($activeTask -and $codePaths.Count -gt 0) {
  $taskContent = Get-Content -Raw -Path $activeTask -Encoding UTF8
  $writeSet = ""
  $forbidden = ""
  foreach ($line in ($taskContent -split "`n")) {
    if ($line -match '^WRITE-SET:\s*(.*)') { $writeSet = $Matches[1].Trim() }
    if ($line -match '^FORBIDDEN:\s*(.*)') { $forbidden = $Matches[1].Trim() }
  }

  # Glob match: comma-separated patterns, path hits any -> true.
  # In PS -like, * matches across path separators, so ** behaves as * (identical to bash case).
  function Match-Glob([string]$Path, [string]$Patterns) {
    if (-not $Patterns) { return $false }
    foreach ($p in ($Patterns -split ',')) {
      $p = $p.Trim()
      if (-not $p) { continue }
      if ($Path -like $p) { return $true }
    }
    return $false
  }

  foreach ($path in $codePaths) {
    # FORBIDDEN takes precedence (architect veto).
    if ($forbidden -and (Match-Glob $path $forbidden)) {
      $reason = "[Engine System] Path $path is in the FORBIDDEN list of task $activeTaskId. | developer: This path is locked by an architect decision — it is off-limits for the current task. To unblock, create a new decision (engine/decisions/D-NNN.md) explaining why access is needed, then update the task card."
      Write-Output "{`"decision`":`"block`",`"reason`":`"$reason`"}"
      exit 0
    }
    # WRITE-SET boundary.
    if ($writeSet -and -not (Match-Glob $path $writeSet)) {
      $reason = "[Engine System] Path $path is not in the WRITE-SET of task $activeTaskId. | developer: This file is outside the current task's approved scope. To expand the scope, update the WRITE-SET in engine/tasks/$activeTaskId.md, or create a new decision. Current WRITE-SET: $writeSet"
      Write-Output "{`"decision`":`"block`",`"reason`":`"$reason`"}"
      exit 0
    }
  }

  # S2: route consistency check.
  # federation.json present + task card declares domain: each code_path's
  # domain must be in the task card's domain set, else block. No federation /
  # no domain -> skip (backward compatible with S1).
  $fedPath = Join-Path $EngineDir "domains\federation.json"
  $taskDomains = ""
  foreach ($line in ($taskContent -split "`n")) {
    if (($line -match '^>') -and ($line -match 'domain:\s*([^|]+)')) {
      $taskDomains = ($Matches[1] -replace ' ', '')
      break
    }
  }
  if ((Test-Path $fedPath) -and $taskDomains) {
    try { $fed = Get-Content -Raw -Path $fedPath -Encoding UTF8 | ConvertFrom-Json } catch { $fed = $null }
    if ($fed) {
      $defaultDom = $fed.default_domain
      if (-not $defaultDom) { $defaultDom = "root" }
      $taskDomainList = $taskDomains -split ','
      foreach ($path in $codePaths) {
        $pathDom = $null
        foreach ($domName in $fed.domains.PSObject.Properties.Name) {
          $dom = $fed.domains.$domName
          if ($dom.paths) {
            foreach ($g in $dom.paths) {
              if ($path -like $g) { $pathDom = $domName; break }
            }
          }
          if ($pathDom) { break }
        }
        if (-not $pathDom) { $pathDom = $defaultDom }
        if ($taskDomainList -notcontains $pathDom) {
          $reason = "[Engine System] Path $path belongs to domain '$pathDom', but task $activeTaskId domain covers only [$taskDomains]. | developer: This file belongs to a different project area ('$pathDom') than the one the current task is scoped for ([$taskDomains]). To work across areas, update the task card's domain field to include the needed domain."
          Write-Output "{`"decision`":`"block`",`"reason`":`"$reason`"}"
          exit 0
        }
      }
    }
  }
}

# Layer 3: soft WARN (missing capsule).
if ($codeChanged -and $engineWritten -and -not $capsuleWritten) {
  $msg = "[Engine System] Code changes were saved to CONTEXT/HANDOFF, but no change capsule (engine/changes/CHANGE-*.md) was found. | developer: Consider writing a change summary — a short note explaining what was changed and why. This helps future you (or teammates) understand the intent behind the change. (WARN, non-blocking)"
  Write-Output "{`"systemMessage`":`"$msg`"}"
  exit 0
}

exit 0
