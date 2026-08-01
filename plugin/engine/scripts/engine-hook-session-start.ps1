# Engine System - SessionStart hook (PowerShell)
#
# PowerShell twin of engine-hook-session-start.sh.
# v6 S1: always inject active task card to combat drift (especially after compact/resume).
# v6.12.0 (D-035): multi-card injection + heartbeat lease liveness + role flag cleanup.
#
# Safety: read-only for engine memory (runtime cache under .cache is fair game).

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
  # v6.12.0 (D-035): the guard also renews this session's lease heartbeat and
  # re-claims a free coordinator lock at the earliest point of each turn.
  $guardPayload = $input | Out-String
  $guardSid = ""
  if ($guardPayload -match '"session_id"\s*:\s*"([^"]*)"') { $guardSid = $Matches[1] }
  $guardDisabled = $env:ENGINE_DISABLE_MULTI_SESSION
  if (Test-Path (Join-Path $EngineDir ".cache\multi-session.disabled")) { $guardDisabled = "1" }
  if ($guardSid -and -not $guardDisabled) {
    $guardKey = (($guardSid + "-main") -replace '[^A-Za-z0-9._-]', '_')
    if ($guardKey.Length -gt 64) { $guardKey = $guardKey.Substring(0, 64) }
    $guardSessions = Join-Path $EngineDir ".cache\sessions"
    New-Item -ItemType Directory -Force -Path $guardSessions | Out-Null
    $guardHb = Join-Path $guardSessions ($guardKey + ".hb")
    try {
      if (Test-Path $guardHb) { [System.IO.File]::SetLastWriteTimeUtc($guardHb, [DateTime]::UtcNow) }
      else { New-Item -ItemType File -Path $guardHb -Force -ErrorAction SilentlyContinue | Out-Null }
    } catch {}
    $guardLock = Join-Path $EngineDir ".cache\session.lock"
    if (Test-Path $guardLock) {
      $guardLockSid = ""
      try {
        $gl = (Get-Content -Path $guardLock -TotalCount 1 -ErrorAction Stop)
        $gp = ([string]$gl) -split '\|'
        if ($gp.Length -ge 2) { $guardLockSid = $gp[1] }
      } catch {}
      if ($guardLockSid -eq $guardSid) {
        try { [System.IO.File]::SetLastWriteTimeUtc($guardLock, [DateTime]::UtcNow) } catch {}
      }
    } else {
      $guardNow = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
      try {
        $fs = New-Object System.IO.FileStream($guardLock, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        $bytes = [System.Text.Encoding]::ASCII.GetBytes("$PID|$guardSid|coordinator|$guardNow|`n")
        $fs.Write($bytes, 0, $bytes.Length)
        $fs.Close()
      } catch {}
    }
  }
  $guardIds = @()
  $guardGoals = @()
  $tasksDirGuard = Join-Path $EngineDir "tasks"
  if (Test-Path $tasksDirGuard) {
    foreach ($tf in (Get-ChildItem -Path $tasksDirGuard -File -Filter "T-*.md" -ErrorAction SilentlyContinue | Sort-Object Name)) {
      if ($tf.Name -like '*.spec.md') { continue }
      $content = Get-Content -Raw -Path $tf.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
      if ($content -notmatch '(?m)^\s*(>\s*)?status:\s*active') { continue }
      $guardIds += $tf.BaseName
      if ($guardIds.Count -le 3) {
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
        if ($goal.Length -gt 200) { $goal = $goal.Substring(0, 200) }
        $guardGoals += ($tf.BaseName + " GOAL: " + $goal)
      }
    }
  }
  if ($guardIds.Count -gt 0) {
    Write-Output ("[Engine Guard] ACTIVE: " + ($guardIds -join ', ') + " | Re-check before writing.")
    foreach ($g in $guardGoals) { Write-Output $g }
    Write-Output "BOUNDARY: write only inside YOUR card's WRITE-SET; PreToolUse union-gates across all active cards."
  } else {
    Write-Output "[Engine Guard] ACTIVE: none | v6.5+ ordinary writes are blocked; create/select a task card first."
  }
  Write-Output "PARALLEL: each session drives its own card; same-task workers write engine/workstreams/<task>/<agent>/; only the lease-holding coordinator writes shared memory."
  # v6.25.0 (T-082): canvas one-liner summary
  $canvasScript = Join-Path $EngineDir "scripts/engine-canvas.ps1"
  if (Test-Path $canvasScript) {
    try { & pwsh -NoProfile -File $canvasScript --guard 2>$null } catch {}
  }
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
# v6.12.0 (D-035): multi-card parallel - inject EVERY active card (<=3 full
# text, beyond that header-only) and hint the union gating boundary.
$tasksDir = Join-Path $EngineDir "tasks"
$activeTask = $null
$activeTaskId = $null
$activeCount = 0
$activeIds = @()
if (Test-Path $tasksDir) {
  $taskFiles = Get-ChildItem -Path $tasksDir -File -Filter "T-*.md" -ErrorAction SilentlyContinue | Sort-Object Name
  foreach ($tf in $taskFiles) {
    if ($tf.Name -like '*.spec.md') { continue }
    $content = Get-Content -Raw -Path $tf.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
    if ($content -notmatch '(?m)^\s*(>\s*)?status:\s*active') { continue }
    $activeCount++
    $activeIds += $tf.BaseName
    if (-not $activeTask) {
      $activeTask = $tf.FullName
      $activeTaskId = $tf.BaseName
    }
    if ($activeCount -le 3) {
      Write-Output ("---- Target: active task card (" + $tf.BaseName + ") ----")
      Write-Output "WARNING: every project path, including engine/*, must be inside SOME active card's WRITE-SET; this card's FORBIDDEN blocks on touch."
      Get-Content $tf.FullName | ForEach-Object { Write-Output $_ }
      Write-Output ""
    } else {
      Write-Output ("---- Additional active card: " + $tf.BaseName + " (read engine/tasks/" + $tf.BaseName + ".md) ----")
      Write-Output ""
    }
  }
}
if ($activeCount -eq 0) {
  Write-Output "---- Target: active task card (none) ----"
  Write-Output "contract-version 6.5+ blocks ordinary writes until a task card is active; finish with engine verify T-NNN."
  Write-Output ""
} elseif ($activeCount -gt 1) {
  Write-Output ("WARNING: Multi-card parallel (" + ($activeIds -join ', ') + "): work under ONE card; write only inside YOUR card's WRITE-SET (union gating).")
  Write-Output ""
}

# v6.25.0 (T-082): Mermaid task canvas
$canvasScript = Join-Path $EngineDir "scripts/engine-canvas.ps1"
if ($activeCount -gt 0 -and (Test-Path $canvasScript)) {
  Write-Output "──── 🗺️ Task Canvas ────"
  try { & pwsh -NoProfile -File $canvasScript 2>$null } catch {}
  Write-Output ""
}

# v6.11.0 (D-029/T-036): 多会话 lock 检测 + 协调者/worker 角色分配。
# v6.12.0 (D-035) RC-3 fix: lock 内 pid 是 hook shell 的瞬时 pid(写完即死),
# pid 存活检测恒判 stale → 人人接管 → 保护空转。液性改为租约:lock mtime 或持锁
# 会话 .hb 心跳 mtime 在 ENGINE_SESSION_TTL_MIN(默认 120 分钟)内即算活。
# 心跳由 PreToolUse(每次工具调用)与 UserPromptSubmit guard(每轮)续租。
# kill switch: ENGINE_DISABLE_MULTI_SESSION=1 或 .cache/multi-session.disabled 文件存在时跳过检测。
$msDisabled = $env:ENGINE_DISABLE_MULTI_SESSION
if (Test-Path (Join-Path $EngineDir ".cache\multi-session.disabled")) { $msDisabled = "1" }

if (-not $msDisabled) {
  $LockFile = Join-Path $EngineDir ".cache\session.lock"
  $SessionsDir = Join-Path $EngineDir ".cache\sessions"
  if (-not (Test-Path $SessionsDir)) { New-Item -ItemType Directory -Path $SessionsDir -Force | Out-Null }

  # v6.12.0 (D-035): GC orphan session files older than 7 days(旧会话的
  # role 旗标/心跳/账本不得阴魂不散地影响 resume 会话)。
  try {
    $gcCutoff = [DateTime]::UtcNow.AddDays(-7)
    Get-ChildItem -Path $SessionsDir -File -ErrorAction SilentlyContinue |
      Where-Object { $_.LastWriteTimeUtc -lt $gcCutoff } |
      Remove-Item -Force -ErrorAction SilentlyContinue
  } catch {}

  # 从 stdin JSON payload 读取 session_id(Claude Code 已传入)。
  # 防阻塞:使用 $input | Out-String 与 Stop hook 一致($input 在无 stdin 输入时不阻塞,返回空)。
  $msPayload = $input | Out-String
  $msSid = ""
  if ($msPayload -match '"session_id"\s*:\s*"([^"]*)"') { $msSid = $Matches[1] }
  # v6.11.1 (D-029/T-038) AC-3: UUID fallback 替换 anon-PID(PID 复用风险)
  if (-not $msSid) { $msSid = [guid]::NewGuid().ToString() }
  $msPid = $PID
  $msStarted = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
  $msTask = ""
  if ($activeTaskId) { $msTask = $activeTaskId }
  # key 算法与 Stop hook Safe-Id 完全一致(-replace '[^A-Za-z0-9._-]', '_',截 64)。
  $msKey = (($msSid + "-main") -replace '[^A-Za-z0-9._-]', '_')
  if ($msKey.Length -gt 64) { $msKey = $msKey.Substring(0, 64) }
  if (-not $msKey) { $msKey = "anon-main" }
  $msHb = Join-Path $SessionsDir ($msKey + ".hb")
  try {
    if (Test-Path $msHb) { [System.IO.File]::SetLastWriteTimeUtc($msHb, [DateTime]::UtcNow) }
    else { New-Item -ItemType File -Path $msHb -Force -ErrorAction SilentlyContinue | Out-Null }
  } catch {}
  $msRoleFile = Join-Path $SessionsDir ($msKey + ".role=worker")

  # 租约新鲜度:lock mtime 与持锁会话 .hb mtime 取最新,within TTL 即 fresh。
  function Test-MsLeaseFresh {
    if (-not (Test-Path $LockFile)) { return $false }
    $ttlMin = 120
    $ttlRaw = $env:ENGINE_SESSION_TTL_MIN
    if ($ttlRaw -and ($ttlRaw -match '^[0-9]+$')) { $ttlMin = [int]$ttlRaw }
    $newest = $null
    try { $newest = (Get-Item -Path $LockFile -ErrorAction Stop).LastWriteTimeUtc } catch {}
    $lockSid = ''
    try {
      $ll = (Get-Content -Path $LockFile -TotalCount 1 -ErrorAction Stop)
      $lp = ([string]$ll) -split '\|'
      if ($lp.Length -ge 2) { $lockSid = $lp[1] }
    } catch {}
    if ($lockSid) {
      $hkey = (($lockSid + "-main") -replace '[^A-Za-z0-9._-]', '_')
      if ($hkey.Length -gt 64) { $hkey = $hkey.Substring(0, 64) }
      $hpath = Join-Path $SessionsDir ($hkey + ".hb")
      if (Test-Path $hpath) {
        try {
          $ht = (Get-Item -Path $hpath -ErrorAction Stop).LastWriteTimeUtc
          if ((-not $newest) -or ($ht -gt $newest)) { $newest = $ht }
        } catch {}
      }
    }
    if (-not $newest) { return $false }
    $age = ([DateTime]::UtcNow - $newest).TotalSeconds
    return ($age -le ($ttlMin * 60))
  }

  # atomic 独占创建 lock (FileStream FileShare.None,无 TOCTOU;创建+写入一次完成)
  $lockAcquired = $false
  try {
    $fs = New-Object System.IO.FileStream($LockFile, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
    $writer = New-Object System.IO.StreamWriter($fs)
    $writer.WriteLine("$msPid|$msSid|coordinator|$msStarted|$msTask")
    $writer.Close()
    $fs.Close()
    $lockAcquired = $true
  } catch {}

  if ($lockAcquired) {
    Remove-Item -Path $msRoleFile -Force -ErrorAction SilentlyContinue
    # T-050 (v6.12.2): new coordinator -> old tombstone (previous transition record) is meaningless, clean it.
    # Symmetric to Stop hook writing tombstone; tombstone is historical event, not active state (lock + lease mtime is).
    Remove-Item -Path (Join-Path $EngineDir ".cache\session.tombstone") -Force -ErrorAction SilentlyContinue
    Write-Output "---- Coordinator (multi-session lease acquired) ----"
    Write-Output "This session is the coordinator: it may write shared memory (CONTEXT/HANDOFF/ENGINE_MAP). Parallel sessions should each drive their own task card."
  } else {
    $msLockSid = ""
    try {
      $ml = (Get-Content -Path $LockFile -TotalCount 1 -ErrorAction Stop)
      $mp = ([string]$ml) -split '\|'
      if ($mp.Length -ge 2) { $msLockSid = $mp[1] }
    } catch {}
    if ($msLockSid -eq $msSid) {
      # 同一会话 resume/clear/compact 重入:重盖自己的租约,清掉残留 worker 旗标(RC-3b)。
      try { Set-Content -Path $LockFile -Value "$msPid|$msSid|coordinator|$msStarted|$msTask" -Encoding ASCII -NoNewline } catch {}
      Remove-Item -Path $msRoleFile -Force -ErrorAction SilentlyContinue
      # T-050 (v6.12.2): resume also cleans tombstone (stale transition record from prior crash of same session).
      Remove-Item -Path (Join-Path $EngineDir ".cache\session.tombstone") -Force -ErrorAction SilentlyContinue
      Write-Output "---- Coordinator (own lease re-acquired) ----"
      Write-Output "This session restored its coordinator lease (resume/compact re-entry)."
    } elseif (Test-MsLeaseFresh) {
      # 租约新鲜 → 降级 worker:写 .role=worker 旗标(PreToolUse 双信号第 2 信号)。
      try { New-Item -ItemType File -Path $msRoleFile -Force | Out-Null } catch {}
      Write-Output "---- Worker (lease held by another live session) ----"
      Write-Output "This session is demoted to worker: activate or create YOUR OWN task card and work normally (union gating); only the coordinator writes shared memory."
      Write-Output "For same-card collaboration run 'engine workstream T-NNN <sid> --kind=session' to write your own shard."
    } else {
      # 租约超时 → 接管协调者(覆盖 lock + tombstone 通知 + 清自身旗标)。
      try { Set-Content -Path $LockFile -Value "$msPid|$msSid|coordinator|$msStarted|$msTask" -Encoding ASCII -NoNewline } catch {}
      $tombstoneFile = Join-Path $EngineDir ".cache\session.tombstone"
      $tsSid = if ($msLockSid) { $msLockSid } else { "unknown" }
      try {
        Set-Content -Path $tombstoneFile -Value "$((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))|$tsSid|stale-recovered" -Encoding ASCII -NoNewline
      } catch {}
      Remove-Item -Path $msRoleFile -Force -ErrorAction SilentlyContinue
      $ttlShow = if ($env:ENGINE_SESSION_TTL_MIN -and ($env:ENGINE_SESSION_TTL_MIN -match '^[0-9]+$')) { $env:ENGINE_SESSION_TTL_MIN } else { "120" }
      Write-Output "---- Coordinator (recovered from stale lease) ----"
      Write-Output ("This session took over as coordinator (previous holder's heartbeat exceeded TTL=" + $ttlShow + "min).")
    }
  }
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
    if ($cc -match '(?m)^\s*(>\s*)?status:\s*(active|paused)') {
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
    if ($pc -match '(?m)^\s*(>\s*)?status:\s*(active|paused)') {
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
    if ($content -match '(?m)^\s*(>\s*)?status:\s*proposed') {
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
