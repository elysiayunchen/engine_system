# Engine System — engine-context (PowerShell)
#
# PowerShell twin of engine-context.sh. Agent-agnostic session context dump.
# Any AI agent can run this to get the full project memory snapshot.
#
# Usage: engine context           (via CLI shim)
#        powershell -File engine/scripts/engine-context.ps1 [-Root <path>]
#
# Safety: read-only. No engine writes, no code writes, no network calls.

param(
  [string]$Root = ""
)

$ErrorActionPreference = "Continue"
trap { Write-Warning "[engine-context.ps1] error: $_"; continue }

if (-not $Root) {
  $Root = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { $PWD.Path }
}
$EngineDir = Join-Path $Root "engine"

if (-not (Test-Path $EngineDir)) {
  Write-Output "[Engine System] engine/ directory not found in $Root."
  Write-Output "Run 'engine init' or 'engine migrate' to set up the project memory layer."
  exit 0
}

Write-Output "==================================================="
Write-Output " Engine System - Session Context"
Write-Output " Agent: read the sections below to understand"
Write-Output " the current project state before taking action."
Write-Output "==================================================="
Write-Output ""

# L0 constitution injection.
$LawFile = Join-Path $Root "runtime-law.md"
if (Test-Path $LawFile) {
  Write-Output "---- L0 Constitution (runtime-law.md) ----"
  Get-Content $LawFile -TotalCount 40 | ForEach-Object { Write-Output $_ }
  Write-Output ""
}

# GLOSSARY injection.
$GlossaryFile = Join-Path $EngineDir "GLOSSARY.md"
if (Test-Path $GlossaryFile) {
  Write-Output "---- Glossary (engine/GLOSSARY.md) ----"
  Write-Output "When communicating with the developer, use the Plain meaning column."
  Write-Output "Match the developer's language. Full glossary: engine/GLOSSARY.md"
  Write-Output ""
}

# CONTEXT.md.
$ContextFile = Join-Path $EngineDir "CONTEXT.md"
if (Test-Path $ContextFile) {
  Write-Output "---- Current State (engine/CONTEXT.md, first 50 lines) ----"
  Get-Content $ContextFile -TotalCount 50 | ForEach-Object { Write-Output $_ }
  Write-Output ""
}

# HANDOFF.md.
$HandoffFile = Join-Path $EngineDir "HANDOFF.md"
if (Test-Path $HandoffFile) {
  Write-Output "---- Last Handoff (engine/HANDOFF.md, newest first) ----"
  Get-Content $HandoffFile | Select-String '^\|' | Select-Object -First 4 | ForEach-Object { Write-Output $_.Line }
  Write-Output ""
}

# Domain dashboard.
$FedFile = Join-Path $EngineDir "domains\federation.json"
if (Test-Path $FedFile) {
  Write-Output "---- Domain Dashboard (federation.json) ----"
  try {
    $fed = Get-Content -Raw -Path $FedFile -Encoding UTF8 | ConvertFrom-Json
    foreach ($domName in $fed.domains.PSObject.Properties.Name) {
      $sum = $fed.domains.$domName.summary
      if ($sum) { Write-Output ("* " + $domName + ": " + $sum) }
    }
  } catch {}
  Write-Output ""
}

# Active task cards.
# v6.12.0 (D-035): multiple active cards may run in parallel (one per session);
# show up to 3 in full, headers beyond.
$tasksDir = Join-Path $EngineDir "tasks"
$activeTask = $null
$activeTaskId = $null
$activeCount = 0
$activeIds = @()
if (Test-Path $tasksDir) {
  $taskFiles = Get-ChildItem -Path $tasksDir -File -Filter "T-*.md" -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notmatch '\.spec\.md$' } | Sort-Object Name
  foreach ($tf in $taskFiles) {
    $content = Get-Content -Raw -Path $tf.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
    if ($content -match '(?m)^\s*(>\s*)?status:\s*active') {
      $activeCount++
      $activeIds += $tf.BaseName
      if (-not $activeTask) {
        $activeTask = $tf.FullName
        $activeTaskId = $tf.BaseName
      }
      if ($activeCount -le 3) {
        Write-Output "---- Active Task Card ($($tf.BaseName)) ----"
        Write-Output "Every project path, including engine/*, MUST be covered by some active card's WRITE-SET (union gating) and outside that card's FORBIDDEN."
        Get-Content $tf.FullName | ForEach-Object { Write-Output $_ }
        Write-Output ""
      } else {
        Write-Output "---- Additional active card: $($tf.BaseName) (read engine/tasks/$($tf.BaseName).md) ----"
        Write-Output ""
      }
    }
  }
}
if ($activeCount -eq 0) {
  Write-Output "---- Active Task Card: none ----"
  Write-Output "contract-version 6.5+ blocks ordinary writes until engine/tasks/T-NNN.md is created or activated. Completion requires: engine verify T-NNN."
  Write-Output ""
} elseif ($activeCount -gt 1) {
  Write-Output "Multi-card parallel ($($activeIds -join ', ')): work under ONE card; write only inside YOUR card's WRITE-SET."
  Write-Output ""
}

# v6.11.0 (D-029/T-036) AC-5: Active Sessions 面板
# 数据源 1: engine/.cache/session.lock (协调者: pid|sid|role|started_at|task_id)
# 数据源 2: engine/.cache/sessions/*.meta (workers: role|stopped_at|task_id)
# 数据源 3: engine/.cache/sessions/*.role=worker (降级标记, 无 .meta 显示 degraded)
$lockFileCtx = Join-Path $EngineDir '.cache\session.lock'
$sessionsDirCtx = Join-Path $EngineDir '.cache\sessions'
if ((Test-Path $lockFileCtx) -or (Test-Path $sessionsDirCtx)) {
  Write-Output "---- Active Sessions ----"
  # Coordinator (from lock file)
  if (Test-Path $lockFileCtx) {
    try {
      $lockLineCtx = (Get-Content -Raw -Path $lockFileCtx -Encoding UTF8 -ErrorAction Stop).Trim()
      if ($lockLineCtx) {
        $lockFields = $lockLineCtx -split '\|'
        $cPid = if ($lockFields.Length -ge 1) { $lockFields[0] } else { '' }
        $cSid = if ($lockFields.Length -ge 2) { $lockFields[1] } else { '' }
        $cStarted = if ($lockFields.Length -ge 4) { $lockFields[3] } else { '' }
        $cTask = if ($lockFields.Length -ge 5) { $lockFields[4] } else { 'none' }
        $cSidShort = if ($cSid.Length -gt 8) { $cSid.Substring(0, 8) } else { $cSid }
        Write-Output ("Coordinator: pid={0} sid={1} started={2} task={3}" -f $cPid, $cSidShort, $cStarted, $cTask)
      }
    } catch {}
  } else {
    Write-Output "Coordinator: none (single-session mode)"
  }
  # Workers (from .meta files; role=coordinator entries are exited coordinators, skip)
  if (Test-Path $sessionsDirCtx) {
    $metaFiles = @(Get-ChildItem -Path $sessionsDirCtx -Filter '*.meta' -ErrorAction SilentlyContinue)
    foreach ($metaCtx in $metaFiles) {
      try {
        $metaLineCtx = (Get-Content -Raw -Path $metaCtx.FullName -Encoding UTF8 -ErrorAction Stop).Trim()
        if (-not $metaLineCtx) { continue }
        $metaFields = $metaLineCtx -split '\|'
        $mRole = if ($metaFields.Length -ge 1) { $metaFields[0] } else { '' }
        $mStopped = if ($metaFields.Length -ge 2) { $metaFields[1] } else { '' }
        $mTask = if ($metaFields.Length -ge 3) { $metaFields[2] } else { 'none' }
        $wKey = $metaCtx.BaseName
        $wKeyShort = if ($wKey.Length -gt 8) { $wKey.Substring(0, 8) } else { $wKey }
        if ($mRole -eq 'worker') {
          Write-Output ("Worker {0}: stopped={1} task={2}" -f $wKeyShort, $mStopped, $mTask)
        }
      } catch {}
    }
    # Degraded workers (.role=worker marker without matching .meta)
    $roleMarkers = @(Get-ChildItem -Path $sessionsDirCtx -Filter '*.role=worker' -ErrorAction SilentlyContinue)
    foreach ($marker in $roleMarkers) {
      $rKey = $marker.Name -replace '\.role=worker$',''
      $rKeyShort = if ($rKey.Length -gt 8) { $rKey.Substring(0, 8) } else { $rKey }
      $metaPath = Join-Path $sessionsDirCtx ($rKey + '.meta')
      if (-not (Test-Path $metaPath)) {
        Write-Output ("Worker {0}: degraded (no .meta)" -f $rKeyShort)
      }
    }
  }
  Write-Output ""
}

# Compact dashboard of unmerged worker shards.
if ($activeTask) {
  $workstreamRoot = Join-Path $EngineDir ("workstreams\" + $activeTaskId)
  if (Test-Path $workstreamRoot) {
    $ctxFiles = @(Get-ChildItem -Path $workstreamRoot -Filter "CONTEXT.md" -File -Recurse -ErrorAction SilentlyContinue | Sort-Object FullName)
    if ($ctxFiles.Count -gt 0) {
      Write-Output "---- Parallel Workstreams (unmerged) ----"
      foreach ($ctx in $ctxFiles) {
        $owner = $ctx.Directory.Name
        # v6.11.1 (D-029/T-038) AC-5: strip a-/s- prefix added for two-level agents/sessions layout.
        if ($owner -like 'a-*' -or $owner -like 's-*') { $owner = $owner.Substring(2) }
        $lines = Get-Content $ctx.FullName -ErrorAction SilentlyContinue
        $state = ($lines | Where-Object { $_ -match '^>' } | Select-Object -First 1) -replace '^>\s*', ''
        $progress = ""
        $on = $false
        foreach ($line in $lines) {
          if ($line -match '^## Progress') { $on = $true; continue }
          if ($on -and $line -match '^-\s+') { $progress = $line; break }
        }
        Write-Output ("* " + $owner + ": " + $state + $(if ($progress) { " | " + $progress } else { "" }))
      }
      Write-Output ""
    }
  }
}

# L2 domain assembly.
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
        Write-Output ("---- L2 Domain: " + $dom + " ----")
        if (Test-Path $domCtx) { Get-Content $domCtx -TotalCount 50 | ForEach-Object { Write-Output $_ } }
        if (Test-Path $domPit) { Get-Content $domPit -TotalCount 40 | ForEach-Object { Write-Output $_ } }
        Write-Output ""
      }
    }
  }
}

# Pending decisions.
$decisionsDir = Join-Path $EngineDir "decisions"
if (Test-Path $decisionsDir) {
  $decFiles = Get-ChildItem -Path $decisionsDir -File -Filter "D-*.md" -ErrorAction SilentlyContinue | Sort-Object Name
  $proposedFound = $false
  foreach ($df in $decFiles) {
    $content = Get-Content -Raw -Path $df.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
    if ($content -match '(?m)^\s*(>\s*)?status:\s*proposed') {
      if (-not $proposedFound) {
        Write-Output "---- Pending Decisions (proposed) ----"
        $proposedFound = $true
      }
      Get-Content $df.FullName -TotalCount 3 | ForEach-Object { Write-Output $_ }
      Write-Output ""
    }
  }
}

# Previous session pending notes.
$PendingFile = Join-Path $EngineDir ".cache/pending.txt"
if (Test-Path $PendingFile) {
  Write-Output "---- Pending from Previous Session ----"
  Get-Content $PendingFile | ForEach-Object { Write-Output $_ }
  Write-Output ""
}

# Update check (read from cache, non-blocking).
$cache = Join-Path $EngineDir ".cache\update-check.json"
if (Test-Path $cache) {
  function Normalize-Version([string]$v) {
    $v = ($v -replace '\s', '')
    if ($v -notmatch '^[0-9]+(\.[0-9]+)*$') { return $v }
    $parts = @($v.Split('.'))
    while ($parts.Count -lt 3) { $parts += '0' }
    return ($parts -join '.')
  }
  try {
    $cached = Get-Content $cache -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($cached.latest -and $cached.latest -ne "" -and ((Normalize-Version ([string]$cached.latest)) -ne (Normalize-Version ([string]$cached.current)))) {
      Write-Output "---- Engine Update Available ----"
      Write-Output ("Local " + $cached.current + " -> Remote " + $cached.latest + ". Run: engine update")
      Write-Output ""
    }
  } catch {}
}

Write-Output "==================================================="
Write-Output " End of Engine System context."
Write-Output " Key files: engine/ENGINE_MAP.md (index)"
Write-Output "            engine/CONTEXT.md    (current state)"
Write-Output "            engine/HANDOFF.md    (session history)"
Write-Output "==================================================="

exit 0
