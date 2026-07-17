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

# Active task card.
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
  Write-Output "---- Active Task Card ($activeTaskId) ----"
  Write-Output "Every project path, including engine/*, MUST be within WRITE-SET and outside FORBIDDEN."
  Get-Content $activeTask | ForEach-Object { Write-Output $_ }
  Write-Output ""
} else {
  Write-Output "---- Active Task Card: none ----"
  Write-Output "contract-version 6.5+ blocks ordinary writes until engine/tasks/T-NNN.md is created or activated. Completion requires: engine verify T-NNN."
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
    if ($content -match 'status:\s*proposed') {
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
