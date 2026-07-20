# Engine System - SessionStart hook (PowerShell)
#
# PowerShell twin of engine-hook-session-start.sh.
# v6 S1: always inject active task card to combat drift (especially after compact/resume).
#
# Safety: read-only. No engine writes, code writes, or network calls.

param([string]$Mode = "full")

$ErrorActionPreference = "Continue"
trap { Write-Warning "[engine-hook-session-start.ps1] error: $_"; continue }

$Root = $env:CLAUDE_PROJECT_DIR
if (-not $Root) { $Root = $PWD.Path }
$EngineDir = Join-Path $Root "engine"

if (-not (Test-Path $EngineDir)) {
  Write-Output "[Engine System] engine/ was not found. Run /engine-init to create the project memory layer."
  exit 0
}

# Compact anti-drift refresh for UserPromptSubmit. Do not inject full L2 here.
if ($Mode -eq '--guard') {
  $guardTask = $null
  $tasksDirGuard = Join-Path $EngineDir "tasks"
  if (Test-Path $tasksDirGuard) {
    foreach ($tf in (Get-ChildItem -Path $tasksDirGuard -File -Filter "T-*.md" -ErrorAction SilentlyContinue | Sort-Object Name)) {
      $content = Get-Content -Raw -Path $tf.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
      if ($content -match 'status:\s*active') { $guardTask = $tf; break }
    }
  }
  if ($guardTask) {
    $content = Get-Content -Raw -Path $guardTask.FullName -Encoding UTF8
    $lines = $content -split "`n"
    $goalLine = $lines | Where-Object { $_ -match '^GOAL:' } | Select-Object -First 1
    $goal = if ($goalLine) { $goalLine -replace '^GOAL:\s*', '' } else { '' }
    if (-not $goal) {
      $on = $false
      foreach ($raw in $lines) {
        $line = $raw.TrimEnd("`r")
        if ($line -match '^##\s+GOAL\s*$') { $on = $true; continue }
        if ($on -and $line -match '^##\s+') { break }
        if ($on -and $line.Trim()) { $goal = $line.Trim(); break }
      }
    }
    if ($goal.Length -gt 240) { $goal = $goal.Substring(0, 240) }
    Write-Output ("[Engine Guard] ACTIVE: " + $guardTask.BaseName + " | Re-check before writing.")
    Write-Output ("GOAL: " + $goal)
    Write-Output ("BOUNDARY: read engine/tasks/" + $guardTask.BaseName + ".md before edits; PreToolUse enforces WRITE-SET/FORBIDDEN.")
  } else {
    Write-Output "[Engine Guard] ACTIVE: none | v6.5+ ordinary writes are blocked; create/select a task card first."
  }
  Write-Output "PARALLEL: workers share the task and write engine/workstreams/<task>/<agent>/; coordinator owns shared memory."
  exit 0
}

Write-Output "[Engine System - auto handoff] Current project memory snapshot. Detect the developer's language, then restate the current state in that language before acting."
Write-Output ""

# v6 mid-priority: L0 constitution injection (runtime-law.md <=40 lines, top anti-drift anchor).
$LawFile = Join-Path $Root "runtime-law.md"
if (Test-Path $LawFile) {
  Write-Output "---- L0 constitution (runtime-law) ----"
  Get-Content $LawFile -TotalCount 40 | ForEach-Object { Write-Output $_ }
  Write-Output ""
}

# v6.1: GLOSSARY injection - agent must use Plain meaning column when talking to developer.
# Only inject header + instruction (3 lines), full glossary read on demand to save tokens.
$GlossaryFile = Join-Path $EngineDir "GLOSSARY.md"
if (Test-Path $GlossaryFile) {
  Write-Output "---- Glossary (engine/GLOSSARY.md) ----"
  Write-Output "When communicating with the developer, use the Plain meaning column from GLOSSARY.md."
  Write-Output "Match the developer's language (not hardcoded Chinese). Full glossary: engine/GLOSSARY.md"
  Write-Output ""
}

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
  Write-Output "WARNING: every project path, including engine/*, must be within WRITE-SET and outside FORBIDDEN."
  Get-Content $activeTask | ForEach-Object { Write-Output $_ }
  Write-Output ""
} else {
  Write-Output "---- Target: active task card (none) ----"
  Write-Output "contract-version 6.5+ blocks ordinary writes until a task card is active; finish with engine verify T-NNN."
  Write-Output ""
}

# v6.9.0 (D-028/T-034): AC-level checkpoint.md priority injection - when active/paused
# card exists, read engine/evidence/T-NNN/checkpoint.md and inject full text. Priority
# chain #1 (covers progress.md section 4 and HANDOFF immediate-resume pointer).
# verify script writes checkpoint; agents write progress.md.
if (Test-Path $tasksDir) {
  $cpTaskFiles = Get-ChildItem -Path $tasksDir -File -Filter "T-*.md" -ErrorAction SilentlyContinue | Sort-Object Name
  foreach ($cf in $cpTaskFiles) {
    if ($cf.Name -match '\.spec\.md$') { continue }
    $cc = Get-Content -Raw -Path $cf.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
    if ($cc -match 'status:\s*(active|paused)') {
      $cpId = $cf.BaseName
      $cpFile = Join-Path $engineDir ("evidence\" + $cpId + "\checkpoint.md")
      if (Test-Path $cpFile) {
        Write-Output "---- AC Checkpoint ($cpId/checkpoint.md) ----"
        Get-Content $cpFile | ForEach-Object { Write-Output $_ }
        Write-Output ""
      }
    }
  }
}

# v6.7.0 (D-028/T-032): task progress.md injection - read engine/tasks/T-NNN/progress.md
# when active/paused card exists; multiple cards injected in ascending ID order.
# Covers HANDOFF immediate-resume pointer with progress.md section 4 (fine-grained).
if (Test-Path $tasksDir) {
  $progressTaskFiles = Get-ChildItem -Path $tasksDir -File -Filter "T-*.md" -ErrorAction SilentlyContinue | Sort-Object Name
  foreach ($pf in $progressTaskFiles) {
    if ($pf.Name -match '\.spec\.md$') { continue }
    $pc = Get-Content -Raw -Path $pf.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
    if ($pc -match 'status:\s*(active|paused)') {
      $progId = $pf.BaseName
      $progFile = Join-Path $tasksDir ("$progId\progress.md")
      if (Test-Path $progFile) {
        Write-Output "---- Task progress ($progId/progress.md) ----"
        Get-Content $progFile | ForEach-Object { Write-Output $_ }
        Write-Output ""
      } else {
        Write-Output "---- Task progress: $progId missing progress.md (Doctor WARN) ----"
        Write-Output "active/paused card $progId has no progress.md; instantiate from engine/skeleton/progress.md per contract/src/20-file-templates.md FILE 13."
        Write-Output ""
      }
    }
  }
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

# v6 auto update check: 24h cache, fail-open (network failure silently skips, never blocks session).
# Safety: read-only remote VERSION, no engine memory writes, no code touches. Non-blocking hint.
$cache = Join-Path $EngineDir ".cache\update-check.json"
$now = [int][DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$checkInterval = 86400  # 24h
$needCheck = $true
if (Test-Path $cache) {
  try {
    $cached = Get-Content $cache -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($cached.last_check -and ($now - [int]$cached.last_check) -lt $checkInterval) {
      $needCheck = $false
    }
  } catch { $needCheck = $true }
}

if ($needCheck) {
  $repoU = if ($env:ENGINE_SYSTEM_REPO) { $env:ENGINE_SYSTEM_REPO } else { "elysiayunchen/engine_system" }
  $branchU = if ($env:ENGINE_SYSTEM_BRANCH) { $env:ENGINE_SYSTEM_BRANCH } else { "main" }
  $remoteVersion = ""
  try {
    $resp = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/$repoU/$branchU/VERSION" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    $remoteVersion = $resp.Content.Trim()
  } catch { $remoteVersion = "" }

  $localVersion = "unknown"
  $localVerFile = Join-Path $EngineDir "VERSION"
  if (Test-Path $localVerFile) {
    $localVersion = (Get-Content $localVerFile -Raw -Encoding UTF8).Trim()
  }

  $cacheDir = Join-Path $EngineDir ".cache"
  if (-not (Test-Path $cacheDir)) { New-Item -ItemType Directory -Force -Path $cacheDir | Out-Null }
  $cacheObj = @{ last_check = $now; latest = $remoteVersion; current = $localVersion }
  $cacheObj | ConvertTo-Json -Compress | Set-Content $cache -Encoding UTF8 -ErrorAction SilentlyContinue
}

# Hint if a newer version exists (read from cache, non-blocking).
# D-015: compare normalized versions (6.0 == 6.0.0) to avoid false update hints.
function Normalize-Version([string]$v) {
  $v = ($v -replace '\s', '')
  if ($v -notmatch '^[0-9]+(\.[0-9]+)*$') { return $v }
  $parts = @($v.Split('.'))
  while ($parts.Count -lt 3) { $parts += '0' }
  return ($parts -join '.')
}
if (Test-Path $cache) {
  try {
    $cached = Get-Content $cache -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($cached.latest -and $cached.latest -ne "" -and ((Normalize-Version ([string]$cached.latest)) -ne (Normalize-Version ([string]$cached.current)))) {
      Write-Output "---- Engine update available ----"
      Write-Output ("Local " + $cached.current + " -> Remote " + $cached.latest + ". Run: engine update")
      Write-Output ""
    }
  } catch { }
}

exit 0
