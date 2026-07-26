# Engine System - write/stop gate (PowerShell twin of engine-hook-stop.sh).
# v6.12.0 (D-035): union gating across ALL active cards + heartbeat lease.
param([string]$Mode = "stop")

$ErrorActionPreference = "Continue"
trap { Write-Warning "[engine-hook-stop.ps1] error: $_"; continue }

$Root = $env:CLAUDE_PROJECT_DIR
if (-not $Root) { $Root = $PWD.Path }
$EngineDir = Join-Path $Root "engine"
$payload = $input | Out-String

if ($payload -match '"stop_hook_active"\s*:\s*true') { exit 0 }
if (-not (Test-Path $EngineDir)) { exit 0 }
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { exit 0 }

Push-Location $Root
$inside = git rev-parse --is-inside-work-tree 2>$null
Pop-Location
if ($inside -ne "true") { exit 0 }

try { $event = $payload | ConvertFrom-Json -ErrorAction Stop } catch { $event = $null }

function Safe-Id([string]$Value) {
  if (-not $Value) { return "" }
  return ($Value -replace '[^A-Za-z0-9._-]', '_')
}

function Normalize-ProjectPath([string]$Path) {
  if (-not $Path) { return "" }
  $p = $Path -replace '\\', '/'
  $rootNorm = $Root -replace '\\', '/'
  if ($p.StartsWith($rootNorm + '/', [System.StringComparison]::OrdinalIgnoreCase)) {
    $p = $p.Substring($rootNorm.Length + 1)
  }
  if ($p.StartsWith('./')) { $p = $p.Substring(2) }
  return $p
}

function Test-StrictTaskProject {
  foreach ($markerPath in @(
    (Join-Path $Root 'AGENTS.md'),
    (Join-Path $EngineDir 'SYSTEM.md'),
    (Join-Path $EngineDir 'ENGINE_DOCTOR.md')
  )) {
    if (-not (Test-Path $markerPath)) { continue }
    $markerContent = Get-Content -Raw -Path $markerPath -Encoding UTF8 -ErrorAction SilentlyContinue
    if ($markerContent -match 'contract-version:\s*([0-9]+(?:\.[0-9]+)+)') {
      try { return ([version]$Matches[1] -ge [version]'6.5.0') } catch { return $false }
    }
  }
  return $false
}

function Test-TaskBootstrapPath([string]$Path) {
  return ($Path -like 'engine/tasks/T-*.md' -or $Path -like 'engine/decisions/D-*.md')
}

# v6.12.0 (D-035) RC-1 fix: collect EVERY active card, not the lexicographically
# first one. Multiple top-level sessions may each hold their own active card;
# gating is per-path union across cards (see Get-ScopeViolation).
function Find-ActiveTasks {
  $tasksDir = Join-Path $EngineDir "tasks"
  $found = @()
  if (-not (Test-Path $tasksDir)) { return $found }
  foreach ($tf in (Get-ChildItem -Path $tasksDir -File -Filter "T-*.md" -ErrorAction SilentlyContinue | Sort-Object Name)) {
    if ($tf.Name -like '*.spec.md') { continue }
    $content = Get-Content -Raw -Path $tf.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
    if ($content -match '(?m)^\s*(>\s*)?status:\s*active') { $found += $tf }
  }
  return $found
}

# Once an active card is edited to done, it is no longer discoverable as active.
# A dirty done card remains a governing boundary through Stop/commit.
function Find-ClosingTasks {
  $tasksDir = Join-Path $EngineDir 'tasks'
  $found = @()
  if (-not (Test-Path $tasksDir)) { return $found }
  foreach ($tf in (Get-ChildItem -Path $tasksDir -File -Filter 'T-*.md' -ErrorAction SilentlyContinue | Sort-Object Name)) {
    if ($tf.Name -like '*.spec.md') { continue }
    $content = Get-Content -Raw -Path $tf.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
    if ($content -notmatch '(?m)^\s*(>\s*)?status:\s*done') { continue }
    $rel = 'engine/tasks/' + $tf.Name
    $dirty = git -C $Root status --porcelain -- $rel 2>$null
    if ($dirty) { $found += $tf }
  }
  return $found
}

# Supports all three accepted spellings (v6.12.1, issue #11 B-1 - aligned with
# the pre-commit parser from T-043): inline `WRITE-SET: a,b`, markdown section
# `## WRITE-SET` list, and YAML frontmatter multi-line `write-set:` list.
function Get-TaskPatterns([string]$Field, [string]$TaskContent) {
  $lines = $TaskContent -split "`n"
  foreach ($lineRaw in $lines) {
    $line = $lineRaw.TrimEnd("`r")
    if ($line -match ('^' + [regex]::Escape($Field) + ':\s*(.*)$')) {
      return $Matches[1].Trim()
    }
  }
  $fieldLc = $Field.ToLowerInvariant()
  $inSection = $false
  $inFmBlock = $false
  $inFmField = $false
  $items = New-Object System.Collections.Generic.List[string]
  foreach ($lineRaw in $lines) {
    $line = $lineRaw.TrimEnd("`r")
    if ($line -match '^---\s*$') {
      $inFmBlock = -not $inFmBlock
      $inFmField = $false
      continue
    }
    $lineLc = $line.ToLowerInvariant()
    if ($lineLc -match ('^##\s+' + [regex]::Escape($fieldLc) + '\s*$')) {
      $inSection = $true; $inFmField = $false
      continue
    }
    if ($inSection -and $line -match '^##\s+') { break }
    if ($inFmBlock -and $lineLc -match ('^' + [regex]::Escape($fieldLc) + ':$')) {
      $inFmField = $true; $inSection = $false
      continue
    }
    if ($inFmField -and $line -notmatch '^\s' -and $line -ne '') { $inFmField = $false }
    if ($inFmField -and $line -match '^\s+-\s+(.+)$') {
      $item = ($Matches[1] -replace '\s+\(.*$', '').Trim()
      if ($item) { $items.Add($item) }
      continue
    }
    if ($inSection -and $line -match '^-\s+(.+)$') {
      $item = ($Matches[1] -replace '\s+\(.*$', '').Trim()
      if ($item) { $items.Add($item) }
    }
  }
  return ($items -join ',')
}

function Match-Glob([string]$Path, [string]$Patterns) {
  if (-not $Patterns) { return $false }
  foreach ($pRaw in ($Patterns -split ',')) {
    $p = $pRaw.Trim()
    if (-not $p) { continue }
    # v6.12.1 (issue #11 B-3): a bare directory entry also matches its children.
    if ($Path -like $p -or $Path -like ($p + '/*')) { return $true }
  }
  return $false
}

function Is-RuntimeCache([string]$Path) {
  return ($Path -like 'engine/.cache/*' -or $Path -like '.engine/*')
}

# v6.12.0 (D-035) RC-4 fix: split the old Is-SharedMemory blanket.
# - Shared singletons: one authoritative copy repo-wide; coordinator-only for
#   every worker kind (top-level worker session or in-session subagent).
# - Task-local files (per-task progress/checkpoint): governed by the owning
#   card's WRITE-SET union instead, so a worker session driving its OWN card
#   can still record progress. In-session subagents (agent_id set) keep the
#   old blanket: they shard everything and the coordinator merges (v6.5).
function Is-SharedSingleton([string]$Path) {
  $exact = @(
    'AGENTS.md', 'CLAUDE.md', 'engine/ENGINE_MAP.md', 'engine/SYSTEM.md',
    'engine/REPO_GUIDE.md', 'engine/CONTEXT.md', 'engine/HANDOFF.md',
    'engine/PITFALLS.md', 'engine/SPRINT.md', 'engine/ROADMAP.md'
  )
  if ($exact -contains $Path) { return $true }
  return (
    $Path -like 'engine/domains/*/CONTEXT.md' -or
    $Path -like 'engine/domains/*/PITFALLS.md' -or
    $Path -like 'engine/domains/*/INVENTORY.md' -or
    $Path -like 'engine/plans/*' -or
    $Path -like 'docs/*/specs/*' -or
    $Path -like 'docs/specs/*'
  )
}

function Is-TaskLocal([string]$Path) {
  return (
    $Path -like 'engine/tasks/T-*/progress.md' -or
    $Path -like 'engine/evidence/T-*/checkpoint.md'
  )
}

function Is-SharedMemory([string]$Path) {
  return ((Is-SharedSingleton $Path) -or (Is-TaskLocal $Path))
}

function Write-Block([string]$Reason) {
  $obj = @{ decision = 'block'; reason = $Reason }
  Write-Output ($obj | ConvertTo-Json -Compress)
  exit 0
}

function Touch-File([string]$Path) {
  try {
    if (Test-Path $Path) {
      [System.IO.File]::SetLastWriteTimeUtc($Path, [DateTime]::UtcNow)
    } else {
      New-Item -ItemType File -Path $Path -Force -ErrorAction SilentlyContinue | Out-Null
    }
  } catch {}
}

$strictTaskMode = Test-StrictTaskProject

# v6.12.0 (D-035): cache every governing card (all active, plus dirty-done
# closing cards). Parallel arrays: file / id / content / WRITE-SET / FORBIDDEN.
$cardFiles = @()
$cardIds = @()
$cardContents = @()
$cardWs = @()
$cardFb = @()
foreach ($tf in (Find-ActiveTasks)) { $cardFiles += $tf }
# Closing (dirty done) cards always co-govern: one session may be closing its
# card while another session's card is still active (D-035).
foreach ($tf in (Find-ClosingTasks)) { $cardFiles += $tf }
foreach ($tf in $cardFiles) {
  $content = Get-Content -Raw -Path $tf.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
  $cardIds += $tf.BaseName
  $cardContents += [string]$content
  $cardWs += (Get-TaskPatterns 'WRITE-SET' $content)
  $cardFb += (Get-TaskPatterns 'FORBIDDEN' $content)
}
# Primary card = first found. Display/meta only; gating is per-path union.
$activeTaskId = if ($cardIds.Count -gt 0) { $cardIds[0] } else { "" }
$cardIdList = ($cardIds -join ', ')

# True when the argument names any governing card (worker shard path check).
function Test-GoverningTaskId([string]$Want) {
  foreach ($id in $script:cardIds) {
    if ($id -eq $Want) { return $true }
  }
  return $false
}

# Union gating (D-035 RC-1/RC-2): a path is allowed when at least one governing
# card lists it in WRITE-SET and not in that same card's FORBIDDEN. One card's
# FORBIDDEN no longer vetoes another card's WRITE-SET. Task/decision card files
# are always writable (bootstrap channel): creating or updating a card must
# never be blocked by someone else's card.
function Get-ScopeViolation([string]$Path) {
  if ($script:cardFiles.Count -eq 0) {
    if ($script:strictTaskMode -and -not (Test-TaskBootstrapPath $Path)) {
      return "[Engine System] No active task card governs $Path. | developer: This project uses the v6.5 strict workflow. Create or activate engine/tasks/T-NNN.md before editing ordinary project files."
    }
    return $null
  }
  if (Test-TaskBootstrapPath $Path) { return $null }
  $readable = $false
  for ($i = 0; $i -lt $script:cardFiles.Count; $i++) {
    $ws = $script:cardWs[$i]
    $fb = $script:cardFb[$i]
    if (-not $ws) { continue }
    $readable = $true
    if ($fb -and (Match-Glob $Path $fb)) { continue }
    if (Match-Glob $Path $ws) { return $null }
  }
  if (-not $readable) {
    return "[Engine System] No governing task card has a readable WRITE-SET ($($script:cardIdList)). | developer: The task boundary is malformed, so writes are paused until a card is fixed."
  }
  return "[Engine System] Path $Path is outside the WRITE-SET of every active card ($($script:cardIdList)). | developer: Add the path to YOUR card WRITE-SET, or create a task card for this goal."
}

# Which governing card covers this path? Returns the card index, -1 when none.
function Get-CoveringCardIndex([string]$Path) {
  for ($i = 0; $i -lt $script:cardFiles.Count; $i++) {
    $ws = $script:cardWs[$i]
    $fb = $script:cardFb[$i]
    if ($ws -and (Match-Glob $Path $ws)) {
      if ((-not $fb) -or (-not (Match-Glob $Path $fb))) { return $i }
    }
  }
  return -1
}

$sessionId = if ($event -and $event.session_id) { [string]$event.session_id } else { "" }
$agentId = if ($event -and $event.agent_id) { [string]$event.agent_id } else { "" }
$toolName = if ($event -and $event.tool_name) { [string]$event.tool_name } else { "" }
$sessionKey = if ($sessionId) { Safe-Id ($sessionId + '-' + $(if ($agentId) { $agentId } else { 'main' })) } else { "" }
$sessionsDir = Join-Path $EngineDir ".cache\sessions"

# v6.12.0 (D-035) RC-3 fix: lease freshness by heartbeat mtime, not pid
# liveness. The lock records the transient hook shell pid (always dead by the
# next check), so instead each session renews .cache/sessions/<key>.hb on every
# PreToolUse and the holder re-stamps the lock at UserPromptSubmit. Fresh =
# newest of lock/.hb mtime within ENGINE_SESSION_TTL_MIN (default 120 minutes).
function Test-LeaseFresh([string]$LockPath) {
  if (-not (Test-Path $LockPath)) { return $false }
  $ttlMin = 120
  $ttlRaw = $env:ENGINE_SESSION_TTL_MIN
  if ($ttlRaw -and ($ttlRaw -match '^[0-9]+$')) { $ttlMin = [int]$ttlRaw }
  $newest = $null
  try { $newest = (Get-Item -Path $LockPath -ErrorAction Stop).LastWriteTimeUtc } catch {}
  $lockSid = ''
  try {
    $lockLine = (Get-Content -Path $LockPath -TotalCount 1 -ErrorAction Stop)
    $parts = ([string]$lockLine) -split '\|'
    if ($parts.Length -ge 2) { $lockSid = $parts[1] }
  } catch {}
  if ($lockSid) {
    $hbPath = Join-Path $script:sessionsDir ((Safe-Id ($lockSid + '-main')) + '.hb')
    if (Test-Path $hbPath) {
      try {
        $hbTime = (Get-Item -Path $hbPath -ErrorAction Stop).LastWriteTimeUtc
        if ((-not $newest) -or ($hbTime -gt $newest)) { $newest = $hbTime }
      } catch {}
    }
  }
  if (-not $newest) { return $false }
  $age = ([DateTime]::UtcNow - $newest).TotalSeconds
  return ($age -le ($ttlMin * 60))
}

if ($Mode -eq '--pre-tool-use') {
  $filePath = ""
  if ($event -and $event.tool_input) {
    if ($event.tool_input.file_path) { $filePath = [string]$event.tool_input.file_path }
    elseif ($event.tool_input.path) { $filePath = [string]$event.tool_input.path }
  }

  # v6.12.0 (D-035): every tool call renews this session's lease heartbeat.
  if ($sessionKey) {
    New-Item -ItemType Directory -Force -Path $sessionsDir | Out-Null
    Touch-File (Join-Path $sessionsDir ($sessionKey + '.hb'))
  }

  if ($toolName -in @('Bash', 'Shell')) {
    if ($sessionKey) {
      Set-Content -Path (Join-Path $sessionsDir ($sessionKey + '.global')) -Value '' -Encoding ASCII
    }
    exit 0
  }
  if (-not $filePath) { exit 0 }

  $path = Normalize-ProjectPath $filePath
  # Still absolute after ROOT-stripping = outside this worktree (scratchpad,
  # temp dirs, other repos). Not a project path; not governed (v6.12.1).
  if ($path -match '^([A-Za-z]:)?/') { exit 0 }
  if (Is-RuntimeCache $path) { exit 0 }

  # v6.11.0 (D-029/T-036) AC-4 dual-signal, scope narrowed by v6.12.0 (D-035):
  # signal 1: agentId set (in-session subagent, passed by Claude Code)
  # signal 2: .cache/sessions/<sessionKey>.role=worker flag (demoted top-level session)
  $isWorker = $false
  if ($agentId) {
    $isWorker = $true
  } elseif ($sessionKey -and (Test-Path (Join-Path $sessionsDir ($sessionKey + '.role=worker')))) {
    $isWorker = $true
  }
  $workerId = if ($agentId) { $agentId } else { $sessionKey }
  $agentSafe = Safe-Id $workerId

  # Shared singleton writes resolve against the coordinator lease (D-035):
  # - in-session subagents never own the lease -> always shard
  # - top-level sessions: holder writes; non-holder blocked while the lease is
  #   fresh; a stale or free lease is claimed on the spot (self-healing, incl.
  #   sessions stuck with an obsolete .role=worker flag from RC-3b)
  if (Is-SharedSingleton $path) {
    if ($agentId) {
      Write-Block "[Engine System] Worker $workerId cannot write shared memory $path. | developer: Parallel workers write their own engine/workstreams/<task>/$agentSafe/ shard; the coordinator merges shared CONTEXT/HANDOFF once."
    }
    if ($sessionId) {
      $lockFile = Join-Path $EngineDir '.cache\session.lock'
      $nowIso = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
      if (-not (Test-Path $lockFile)) {
        New-Item -ItemType Directory -Force -Path (Join-Path $EngineDir '.cache') | Out-Null
        # Atomic exclusive create (FileStream CreateNew, no TOCTOU window).
        try {
          $fs = New-Object System.IO.FileStream($lockFile, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
          $bytes = [System.Text.Encoding]::ASCII.GetBytes("$PID|$sessionId|coordinator|$nowIso|$activeTaskId`n")
          $fs.Write($bytes, 0, $bytes.Length)
          $fs.Close()
        } catch {}
      }
      $lockSid = ''
      try {
        $lockLine = (Get-Content -Path $lockFile -TotalCount 1 -ErrorAction Stop)
        $parts = ([string]$lockLine) -split '\|'
        if ($parts.Length -ge 2) { $lockSid = $parts[1] }
      } catch {}
      if ($lockSid -and ($lockSid -ne $sessionId)) {
        if (Test-LeaseFresh $lockFile) {
          if ($isWorker) {
            Write-Block "[Engine System] Worker $workerId cannot write shared memory $path. | developer: Parallel workers write their own engine/workstreams/<task>/$agentSafe/ shard; the coordinator merges shared CONTEXT/HANDOFF once."
          } else {
            Write-Block "[Engine System] Shared memory $path is leased by another live session. | developer: Run engine assume-coordinator to take over, or write your own workstreams shard and let the coordinator merge."
          }
        }
        # Stale lease: take over and continue as coordinator.
        try { Set-Content -Path $lockFile -Value "$PID|$sessionId|coordinator|$nowIso|$activeTaskId" -Encoding ASCII } catch {}
        try { Set-Content -Path (Join-Path $EngineDir '.cache\session.tombstone') -Value "$nowIso|unknown|stale-recovered" -Encoding ASCII } catch {}
      }
      # Holding (or just claimed) the lease: coordinator from here on.
      if ($sessionKey) {
        Remove-Item -Path (Join-Path $sessionsDir ($sessionKey + '.role=worker')) -Force -ErrorAction SilentlyContinue
      }
      $isWorker = $false
    } elseif ($isWorker) {
      # No session identity (non-Claude harness): keep the flag-based block.
      Write-Block "[Engine System] Worker $workerId cannot write shared memory $path. | developer: Parallel workers write their own engine/workstreams/<task>/$agentSafe/ shard; the coordinator merges shared CONTEXT/HANDOFF once."
    }
  }

  # In-session subagents keep the v6.5 blanket: task-local progress/checkpoint
  # files also go through their shard; the coordinator merges. Top-level worker
  # sessions write task-local files of their OWN card via WRITE-SET union.
  if ($agentId -and (Is-TaskLocal $path)) {
    Write-Block "[Engine System] Subagent $agentId cannot write task file $path directly. | developer: Record it in your engine/workstreams/<task>/$agentSafe/ shard; the coordinator merges."
  }

  if ($isWorker -and $path -like 'engine/workstreams/*') {
    $shardTask = ($path.Substring('engine/workstreams/'.Length) -split '/')[0]
    if ($path -like "engine/workstreams/$shardTask/$agentSafe/*") {
      # v6.12.0 (D-035) RC-4 fix: a shard may live under ANY governing card,
      # not only the lexicographically first one. A validated own shard is the
      # sanctioned worker write channel: allow it directly instead of demanding
      # every card list workstreams in WRITE-SET.
      if (($cardIds.Count -gt 0) -and (-not (Test-GoverningTaskId $shardTask))) {
        Write-Block "[Engine System] Workstream shard task $shardTask is not an active card ($cardIdList). | developer: Run engine workstream against your own active card."
      }
      if ($sessionKey) {
        New-Item -ItemType Directory -Force -Path $sessionsDir | Out-Null
        $ledger = Join-Path $sessionsDir ($sessionKey + '.paths')
        $known = @()
        if (Test-Path $ledger) { $known = @(Get-Content $ledger -ErrorAction SilentlyContinue) }
        if ($known -notcontains $path) { Add-Content -Path $ledger -Value $path -Encoding UTF8 }
      }
      exit 0
    } else {
      Write-Block "[Engine System] Worker $workerId may only write its own workstream shard: engine/workstreams/<task>/$agentSafe/."
    }
  }

  $violation = Get-ScopeViolation $path
  if ($violation) { Write-Block $violation }

  if ($sessionKey) {
    New-Item -ItemType Directory -Force -Path $sessionsDir | Out-Null
    $ledger = Join-Path $sessionsDir ($sessionKey + '.paths')
    $known = @()
    if (Test-Path $ledger) { $known = @(Get-Content $ledger -ErrorAction SilentlyContinue) }
    if ($known -notcontains $path) { Add-Content -Path $ledger -Value $path -Encoding UTF8 }
  }
  exit 0
}

$ownedPaths = @()
$attributed = $false
if ($sessionKey) {
  $ledger = Join-Path $sessionsDir ($sessionKey + '.paths')
  $globalMarker = Join-Path $sessionsDir ($sessionKey + '.global')
  if ((Test-Path $ledger) -and -not (Test-Path $globalMarker)) {
    $ownedPaths = @(Get-Content $ledger -ErrorAction SilentlyContinue | Where-Object { $_ })
    if ($ownedPaths.Count -gt 0) { $attributed = $true }
  }
}

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
Push-Location $Root
$raw = git status --porcelain -z -uall 2>$null
Pop-Location
if ($raw -is [array]) { $raw = $raw -join "`n" }
if (-not $raw) { exit 0 }

$codeChanged = $false
$engineWritten = $false
$capsuleWritten = $false
$codePaths = New-Object System.Collections.Generic.List[string]
$governedPaths = New-Object System.Collections.Generic.List[string]
$skipNext = $false

foreach ($rec in ($raw -split "`0")) {
  if (-not $rec) { continue }
  if ($skipNext) { $skipNext = $false; continue }
  if ($rec.Length -lt 4) { continue }
  $st = $rec.Substring(0, 2)
  $path = $rec.Substring(3)
  if ($st -match '[RC]') { $skipNext = $true }
  if ($attributed -and $ownedPaths -notcontains $path) { continue }
  if (Is-RuntimeCache $path) { continue }

  $governedPaths.Add($path)
  switch -Wildcard ($path) {
    'engine/CONTEXT.md'          { $engineWritten = $true; break }
    'engine/HANDOFF.md'          { $engineWritten = $true; break }
    'engine/ENGINE_MAP.md'       { $engineWritten = $true; break }
    'engine/workstreams/*/*/CONTEXT.md' { $engineWritten = $true; break }
    'engine/workstreams/*/*/HANDOFF.md' { $engineWritten = $true; break }
    'engine/changes/CHANGE-*.md' { $capsuleWritten = $true; break }
    'engine/*'                   { break }
    default                      { $codeChanged = $true; $codePaths.Add($path) }
  }
}

if (($cardFiles.Count -gt 0) -or $strictTaskMode) {
  foreach ($path in $governedPaths) {
    if ($agentId -and (Is-SharedMemory $path)) {
      Write-Block "[Engine System] Worker agent $agentId changed shared memory $path. Use engine/workstreams/<task>/$(Safe-Id $agentId)/ and let the coordinator merge."
    }
    # Workstream shards are the sanctioned worker channel; the conservative
    # whole-worktree fallback may also see sibling sessions' shards - never block.
    if ($path -like 'engine/workstreams/*/*/*') { continue }
    $violation = Get-ScopeViolation $path
    if ($violation) { Write-Block $violation }
  }
}

if ($codeChanged -and -not $engineWritten) {
  Write-Block '[Engine System] Code changed but this session did not update project memory. | developer: Save what changed and what comes next before ending. Parallel workers must write their own workstream shard; the coordinator updates shared CONTEXT/HANDOFF.'
}

# Domain routing remains a code-path concern. Engine-memory routing is governed
# by WRITE-SET. v6.12.0 (D-035): each code path is judged against the domains of
# the card that covers it, not against the first active card.
if (($cardFiles.Count -gt 0) -and $codePaths.Count -gt 0) {
  $fedPath = Join-Path $EngineDir 'domains\federation.json'
  if (Test-Path $fedPath) {
    try { $fed = Get-Content -Raw -Path $fedPath -Encoding UTF8 | ConvertFrom-Json } catch { $fed = $null }
    if ($fed) {
      $defaultDom = if ($fed.default_domain) { $fed.default_domain } else { 'root' }
      foreach ($path in $codePaths) {
        $coverIdx = Get-CoveringCardIndex $path
        if ($coverIdx -lt 0) { continue }
        $coverId = $cardIds[$coverIdx]
        $taskDomains = ""
        foreach ($line in ($cardContents[$coverIdx] -split "`n")) {
          if (($line -match '^>') -and ($line -match 'domain:\s*([^|]+)')) {
            $taskDomains = ($Matches[1] -replace ' ', '')
            break
          }
        }
        if (-not $taskDomains) { continue }
        $taskDomainList = $taskDomains -split ','
        $pathDom = $null
        foreach ($domName in $fed.domains.PSObject.Properties.Name) {
          foreach ($g in $fed.domains.$domName.paths) {
            if ($path -like $g) { $pathDom = $domName; break }
          }
          if ($pathDom) { break }
        }
        if (-not $pathDom) { $pathDom = $defaultDom }
        if ($taskDomainList -notcontains $pathDom) {
          Write-Block "[Engine System] Path $path belongs to domain $pathDom, outside task $coverId domains [$taskDomains]."
        }
      }
    }
  }
}

if ($codeChanged -and $engineWritten -and -not $capsuleWritten) {
  $msg = @{ systemMessage = '[Engine System] Code and project memory changed, but no change capsule was found. Add engine/changes/CHANGE-*.md before completion. (WARN)' }
  Write-Output ($msg | ConvertTo-Json -Compress)
}

# v6.11.0 (D-029/T-036) AC-3: Stop hook 多会话收尾
# - 写 .cache/sessions/<sessionKey>.meta (role|stopped_at|task_id),供 engine-context.sh Active Sessions 面板读
# - 如果当前会话是协调者(持有 lock 且 sessionId 匹配 lock 内 sid),释放 lock (Remove session.lock)
# - 写 tombstone 文件通知其他会话(coordinator-exited,可接管)
# PreToolUse 双信号由 AC-4 扩展;本 AC-3 只做 .meta + lock release + tombstone。
if ($sessionKey -and (Test-Path (Join-Path $EngineDir '.cache\sessions'))) {
  $lockFile = Join-Path $EngineDir '.cache\session.lock'
  $role = 'worker'
  $lockContent = ''
  $lockParts = @()
  # P1 修复 (review):AC-3 复用 AC-4 双信号优先判定 worker,避免协调者先退出后
  # worker 因 lockFile 不存在被默认判定为 coordinator 污染 .meta role 字段
  $isWorkerExplicit = $false
  if ($agentId) {
    $isWorkerExplicit = $true
  } elseif (Test-Path (Join-Path $sessionsDir ($sessionKey + '.role=worker'))) {
    $isWorkerExplicit = $true
  }
  if (-not $isWorkerExplicit) {
    if (Test-Path $lockFile) {
      try { $lockContent = (Get-Content -Raw -Path $lockFile -Encoding UTF8 -ErrorAction Stop).Trim() } catch {}
      if ($lockContent) { $lockParts = $lockContent -split '\|' }
      $lockSid = if ($lockParts.Length -ge 2) { $lockParts[1] } else { '' }
      if ($lockSid -and ($lockSid -eq $sessionId)) {
        $role = 'coordinator'
      }
    } else {
      # No lock — single session mode (coordinator by default)
      $role = 'coordinator'
    }
  }
  $stoppedAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
  $metaFile = Join-Path $EngineDir (".cache\sessions\$sessionKey.meta")
  try {
    Set-Content -Path $metaFile -Value ($role + '|' + $stoppedAt + '|' + $activeTaskId) -Encoding UTF8 -NoNewline
  } catch {}

  # 协调者退出:释放 lock (Remove session.lock) + 写 tombstone 通知其他会话
  if (($role -eq 'coordinator') -and (Test-Path $lockFile)) {
    $lockPid = if ($lockParts.Length -ge 1) { $lockParts[0] } else { '' }
    # P2 修复 (review):tombstone lockPid 空值 fallback "unknown",避免数据不完整
    if (-not $lockPid) { $lockPid = 'unknown' }
    # Remove session.lock (release lock)
    Remove-Item -Path "$EngineDir\.cache\session.lock" -Force -ErrorAction SilentlyContinue
    # tombstone: coordinator-exited 通知,其他会话 SessionStart 检测到时可接管
    $tombstoneFile = Join-Path $EngineDir '.cache\session.tombstone'
    try {
      Set-Content -Path $tombstoneFile -Value ($stoppedAt + '|' + $lockPid + '|coordinator-exited') -Encoding UTF8 -NoNewline
    } catch {}
  }
}

exit 0
