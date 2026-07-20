# Engine System - write/stop gate (PowerShell twin of engine-hook-stop.sh).
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

function Find-ActiveTask {
  $tasksDir = Join-Path $EngineDir "tasks"
  if (-not (Test-Path $tasksDir)) { return $null }
  foreach ($tf in (Get-ChildItem -Path $tasksDir -File -Filter "T-*.md" -ErrorAction SilentlyContinue | Sort-Object Name)) {
    $content = Get-Content -Raw -Path $tf.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
    if ($content -match 'status:\s*active') { return $tf }
  }
  return $null
}

function Find-ClosingTask {
  $tasksDir = Join-Path $EngineDir 'tasks'
  if (-not (Test-Path $tasksDir)) { return $null }
  foreach ($tf in (Get-ChildItem -Path $tasksDir -File -Filter 'T-*.md' -ErrorAction SilentlyContinue | Sort-Object Name)) {
    $content = Get-Content -Raw -Path $tf.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
    if ($content -notmatch 'status:\s*done') { continue }
    $rel = 'engine/tasks/' + $tf.Name
    $dirty = git -C $Root status --porcelain -- $rel 2>$null
    if ($dirty) { return $tf }
  }
  return $null
}

function Get-TaskPatterns([string]$Field, [string]$TaskContent) {
  $lines = $TaskContent -split "`n"
  foreach ($lineRaw in $lines) {
    $line = $lineRaw.TrimEnd("`r")
    if ($line -match ('^' + [regex]::Escape($Field) + ':\s*(.*)$')) {
      return $Matches[1].Trim()
    }
  }
  $inSection = $false
  $items = New-Object System.Collections.Generic.List[string]
  foreach ($lineRaw in $lines) {
    $line = $lineRaw.TrimEnd("`r")
    if ($line -match ('^##\s+' + [regex]::Escape($Field) + '\s*$')) {
      $inSection = $true
      continue
    }
    if ($inSection -and $line -match '^##\s+') { break }
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
    if ($p -and $Path -like $p) { return $true }
  }
  return $false
}

function Is-RuntimeCache([string]$Path) {
  return ($Path -like 'engine/.cache/*' -or $Path -like '.engine/*')
}

function Is-SharedMemory([string]$Path) {
  $exact = @(
    'AGENTS.md', 'CLAUDE.md', 'engine/ENGINE_MAP.md', 'engine/SYSTEM.md',
    'engine/REPO_GUIDE.md', 'engine/CONTEXT.md', 'engine/HANDOFF.md',
    'engine/PITFALLS.md', 'engine/SPRINT.md', 'engine/ROADMAP.md'
  )
  if ($exact -contains $Path) { return $true }
  return (
    $Path -like 'engine/domains/*/CONTEXT.md' -or
    $Path -like 'engine/domains/*/PITFALLS.md' -or
    $Path -like 'engine/plans/*' -or
    $Path -like 'docs/*/specs/*' -or
    $Path -like 'docs/specs/*'
  )
}

function Write-Block([string]$Reason) {
  $obj = @{ decision = 'block'; reason = $Reason }
  Write-Output ($obj | ConvertTo-Json -Compress)
  exit 0
}

$strictTaskMode = Test-StrictTaskProject
$activeTaskFile = Find-ActiveTask
if (-not $activeTaskFile -and $strictTaskMode) { $activeTaskFile = Find-ClosingTask }
$activeTask = $null
$activeTaskId = ""
$writeSet = ""
$forbidden = ""
if ($activeTaskFile) {
  $activeTask = Get-Content -Raw -Path $activeTaskFile.FullName -Encoding UTF8
  $activeTaskId = $activeTaskFile.BaseName
  $writeSet = Get-TaskPatterns 'WRITE-SET' $activeTask
  $forbidden = Get-TaskPatterns 'FORBIDDEN' $activeTask
}

function Get-ScopeViolation([string]$Path) {
  if (-not $activeTaskFile) {
    if ($strictTaskMode -and -not (Test-TaskBootstrapPath $Path)) {
      return "[Engine System] No active task card governs $Path. | developer: This project uses the v6.5 strict workflow. Create or activate engine/tasks/T-NNN.md before editing ordinary project files."
    }
    return $null
  }
  if ($forbidden -and (Match-Glob $Path $forbidden)) {
    return "[Engine System] Path $Path is in FORBIDDEN for $activeTaskId. | developer: This file is explicitly off-limits for the current task."
  }
  if (-not $writeSet) {
    return "[Engine System] Active task $activeTaskId has no readable WRITE-SET. | developer: The task boundary is malformed, so writes are paused until the task card is fixed."
  }
  if (-not (Match-Glob $Path $writeSet)) {
    return "[Engine System] Path $Path is outside the WRITE-SET of $activeTaskId. | developer: This file is outside the current task scope. Current WRITE-SET: $writeSet"
  }
  return $null
}

$sessionId = if ($event -and $event.session_id) { [string]$event.session_id } else { "" }
$agentId = if ($event -and $event.agent_id) { [string]$event.agent_id } else { "" }
$toolName = if ($event -and $event.tool_name) { [string]$event.tool_name } else { "" }
$sessionKey = if ($sessionId) { Safe-Id ($sessionId + '-' + $(if ($agentId) { $agentId } else { 'main' })) } else { "" }
$sessionsDir = Join-Path $EngineDir ".cache\sessions"

if ($Mode -eq '--pre-tool-use') {
  $filePath = ""
  if ($event -and $event.tool_input) {
    if ($event.tool_input.file_path) { $filePath = [string]$event.tool_input.file_path }
    elseif ($event.tool_input.path) { $filePath = [string]$event.tool_input.path }
  }

  if ($toolName -in @('Bash', 'Shell')) {
    if ($sessionKey) {
      New-Item -ItemType Directory -Force -Path $sessionsDir | Out-Null
      Set-Content -Path (Join-Path $sessionsDir ($sessionKey + '.global')) -Value '' -Encoding ASCII
    }
    exit 0
  }
  if (-not $filePath) { exit 0 }

  $path = Normalize-ProjectPath $filePath
  if (Is-RuntimeCache $path) { exit 0 }

  # v6.11.0 (D-029/T-036) AC-4: PreToolUse 双信号扩展
  # 信号 1: agentId 非空 (subagent 由 Claude Code 传入)
  # 信号 2: .cache/sessions/<sessionKey>.role=worker 文件存在 (顶层会话降级为 worker)
  # OR 关系: 任一信号触发即视为 worker, 拦截共享记忆写入 + 限定 workstream 路径
  $isWorker = $false
  if ($agentId) {
    $isWorker = $true
  } elseif ($sessionKey -and (Test-Path (Join-Path $sessionsDir ($sessionKey + '.role=worker')))) {
    $isWorker = $true
  }
  # worker 标识: 优先 agentId, 否则用 sessionKey (顶层会话降级场景)
  $workerId = if ($agentId) { $agentId } else { $sessionKey }

  if ($isWorker -and (Is-SharedMemory $path)) {
    $agentSafe = Safe-Id $workerId
    $taskLabel = if ($activeTaskId) { $activeTaskId } else { 'T-NNN' }
    Write-Block "[Engine System] Worker $workerId cannot write shared memory $path. | developer: Parallel workers write engine/workstreams/$taskLabel/$agentSafe/; the coordinator merges shared CONTEXT/HANDOFF once."
  }

  if ($isWorker -and $path -like 'engine/workstreams/*') {
    $agentSafe = Safe-Id $workerId
    $taskLabel = if ($activeTaskId) { $activeTaskId } else { 'T-NNN' }
    if ($path -notlike "engine/workstreams/$taskLabel/$agentSafe/*") {
      Write-Block "[Engine System] Worker $workerId may only write its own workstream shard: engine/workstreams/$taskLabel/$agentSafe/."
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

if ($activeTaskFile -or $strictTaskMode) {
  foreach ($path in $governedPaths) {
    if ($agentId -and (Is-SharedMemory $path)) {
      Write-Block "[Engine System] Worker agent $agentId changed shared memory $path. Use engine/workstreams/$activeTaskId/$(Safe-Id $agentId)/ and let the coordinator merge."
    }
    $violation = Get-ScopeViolation $path
    if ($violation) { Write-Block $violation }
  }
}

if ($codeChanged -and -not $engineWritten) {
  Write-Block '[Engine System] Code changed but this session did not update project memory. | developer: Save what changed and what comes next before ending. Parallel workers write their own workstream shard; the coordinator updates shared CONTEXT/HANDOFF.'
}

# Domain routing stays a code-path concern; engine-memory routing is governed by WRITE-SET.
if ($activeTaskFile -and $codePaths.Count -gt 0) {
  $taskDomains = ""
  foreach ($line in ($activeTask -split "`n")) {
    if (($line -match '^>') -and ($line -match 'domain:\s*([^|]+)')) {
      $taskDomains = ($Matches[1] -replace ' ', '')
      break
    }
  }
  $fedPath = Join-Path $EngineDir 'domains\federation.json'
  if ((Test-Path $fedPath) -and $taskDomains) {
    try { $fed = Get-Content -Raw -Path $fedPath -Encoding UTF8 | ConvertFrom-Json } catch { $fed = $null }
    if ($fed) {
      $defaultDom = if ($fed.default_domain) { $fed.default_domain } else { 'root' }
      $taskDomainList = $taskDomains -split ','
      foreach ($path in $codePaths) {
        $pathDom = $null
        foreach ($domName in $fed.domains.PSObject.Properties.Name) {
          foreach ($g in $fed.domains.$domName.paths) {
            if ($path -like $g) { $pathDom = $domName; break }
          }
          if ($pathDom) { break }
        }
        if (-not $pathDom) { $pathDom = $defaultDom }
        if ($taskDomainList -notcontains $pathDom) {
          Write-Block "[Engine System] Path $path belongs to domain $pathDom, outside task $activeTaskId domains [$taskDomains]."
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
  $stoppedAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
  $metaFile = Join-Path $EngineDir (".cache\sessions\$sessionKey.meta")
  try {
    Set-Content -Path $metaFile -Value ($role + '|' + $stoppedAt + '|' + $activeTaskId) -Encoding UTF8 -NoNewline
  } catch {}

  # 协调者退出:释放 lock (Remove session.lock) + 写 tombstone 通知其他会话
  if (($role -eq 'coordinator') -and (Test-Path $lockFile)) {
    $lockPid = if ($lockParts.Length -ge 1) { $lockParts[0] } else { '' }
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
