# Engine System - SessionStart hook (PowerShell)
#
# PowerShell twin of engine-hook-session-start.sh.
# v6 S1: always inject active task card to combat drift (especially after compact/resume).
#
# Safety: read-only. No engine writes, code writes, or network calls.

param()

$Root = $env:CLAUDE_PROJECT_DIR
if (-not $Root) { $Root = $PWD.Path }
$EngineDir = Join-Path $Root "engine"

if (-not (Test-Path $EngineDir)) {
  Write-Output "[Engine System] engine/ was not found. Run /engine-init to create the project memory layer."
  exit 0
}

Write-Output "[Engine System - auto handoff] Current project memory snapshot. Restate the current state in one Simplified Chinese sentence before acting."
Write-Output ""

$ContextFile = Join-Path $EngineDir "CONTEXT.md"
if (Test-Path $ContextFile) {
  Write-Output "---- Current state (engine/CONTEXT.md) ----"
  Get-Content $ContextFile -TotalCount 50 | ForEach-Object { Write-Output $_ }
  Write-Output ""
}

$HandoffFile = Join-Path $EngineDir "HANDOFF.md"
if (Test-Path $HandoffFile) {
  Write-Output "---- Last handoff (engine/HANDOFF.md, newest first) ----"
  Get-Content $HandoffFile | Select-String '^\|' | Select-Object -First 4 | ForEach-Object { Write-Output $_.Line }
  Write-Output ""
}

# v6 S2: domain dashboard (summary protocol) - one-line summary per domain, O(domains) not O(repo).
$FedFile = Join-Path $EngineDir "domains\federation.json"
if (Test-Path $FedFile) {
  Write-Output "---- Domain dashboard (federation) ----"
  try {
    $fed = Get-Content -Raw -Path $FedFile -Encoding UTF8 | ConvertFrom-Json
    foreach ($domName in $fed.domains.PSObject.Properties.Name) {
      $sum = $fed.domains.$domName.summary
      if ($sum) { Write-Output ("* " + $domName + ": " + $sum) }
    }
  } catch {}
  Write-Output ""
}

# v6 S1: active task card re-injection - core anti-drift anchor.
$tasksDir = Join-Path $EngineDir "tasks"
$activeTask = $null
$activeTaskId = $null
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
if ($activeTask) {
  Write-Output "---- Target: active task card ($activeTaskId) ----"
  Write-Output "WARNING: all code changes must be within WRITE-SET; FORBIDDEN is the architect's veto."
  Get-Content $activeTask | ForEach-Object { Write-Output $_ }
  Write-Output ""
}

# v6 S2: L2 domain assembly - pull CONTEXT+PITFALLS for each domain in the task card's domain field (budget-bounded).
if ($activeTask -and (Test-Path $FedFile)) {
  $taskContent = Get-Content -Raw -Path $activeTask -Encoding UTF8
  $taskDomainsL2 = ""
  foreach ($line in ($taskContent -split "`n")) {
    if (($line -match '^>') -and ($line -match 'domain:\s*([^|]+)')) {
      $taskDomainsL2 = ($Matches[1] -replace ' ', '')
      break
    }
  }
  if ($taskDomainsL2) {
    foreach ($dom in ($taskDomainsL2 -split ',')) {
      if (-not $dom) { continue }
      $domCtx = Join-Path $EngineDir ("domains\" + $dom + "\CONTEXT.md")
      $domPit = Join-Path $EngineDir ("domains\" + $dom + "\PITFALLS.md")
      if ((Test-Path $domCtx) -or (Test-Path $domPit)) {
        Write-Output ("---- L2 domain: " + $dom + " ----")
        if (Test-Path $domCtx) { Get-Content $domCtx -TotalCount 50 | ForEach-Object { Write-Output $_ } }
        if (Test-Path $domPit) { Get-Content $domPit -TotalCount 40 | ForEach-Object { Write-Output $_ } }
        Write-Output ""
      }
    }
  }
}

# "Wait for your call" queue: proposed decisions.
$decisionsDir = Join-Path $EngineDir "decisions"
$proposedFound = $false
if (Test-Path $decisionsDir) {
  $decFiles = Get-ChildItem -Path $decisionsDir -File -Filter "D-*.md" -ErrorAction SilentlyContinue | Sort-Object Name
  foreach ($df in $decFiles) {
    $content = Get-Content -Raw -Path $df.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
    if ($content -match 'status:\s*proposed') {
      if (-not $proposedFound) {
        Write-Output "---- Pending your decision (proposed) ----"
        $proposedFound = $true
      }
      Get-Content $df.FullName -TotalCount 3 | ForEach-Object { Write-Output $_ }
      Write-Output ""
    }
  }
}

$PendingFile = Join-Path $EngineDir ".cache/pending.txt"
if (Test-Path $PendingFile) {
  Write-Output "---- Pending note from previous session ----"
  Get-Content $PendingFile | ForEach-Object { Write-Output $_ }
  Write-Output ""
}

exit 0
