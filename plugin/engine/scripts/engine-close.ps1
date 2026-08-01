# Engine System - agent-neutral lifecycle closure.
# Runs verify -> gate -> doctor through the public PowerShell CLI and records
# the closure audit. Workers close into their own shard; coordinators own the
# final shared-memory and change-capsule closure.

param(
  [Parameter(Position=0)][string]$Task = "",
  [Parameter(Position=1, ValueFromRemainingArguments=$true)][string[]]$RemainingArgs = @()
)

$ErrorActionPreference = "Continue"
$Root = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (Get-Location).Path }
$EngineDir = Join-Path $Root "engine"
$handoffAgent = if ($env:ENGINE_AGENT_ID) { $env:ENGINE_AGENT_ID } else { "" }

$closeArgs = @()
if ($args) { $closeArgs += $args }
if ($RemainingArgs) { $closeArgs += $RemainingArgs }
for ($i = 0; $i -lt $closeArgs.Count; $i++) {
  $a = "$($closeArgs[$i])"
  if ($a -eq '--handoff') {
    $i++
    if ($i -lt $closeArgs.Count) { $handoffAgent = "$($closeArgs[$i])" }
  } elseif ($a -match '^--handoff=(.+)$') {
    $handoffAgent = $Matches[1]
  } else {
    Write-Error "[engine-close] Unknown argument: $a"
    Write-Error "Usage: engine close T-NNN [--handoff AGENT]"
    exit 2
  }
}

if ($Task -notmatch '^T-[0-9]+$') {
  Write-Error "[engine-close] Usage: engine close T-NNN [--handoff AGENT]"
  exit 2
}

$taskFile = Join-Path $EngineDir ("tasks\$Task.md")
$cli = Join-Path $Root "engine\bin\engine.ps1"
if (-not (Test-Path $taskFile)) {
  Write-Error "[engine-close] task card not found: $taskFile"
  exit 2
}
if (-not (Test-Path $cli)) {
  Write-Error "[engine-close] public CLI not found: $cli"
  exit 2
}

New-Item -ItemType Directory -Force -Path (Join-Path $EngineDir "evidence\$Task") | Out-Null
$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$headCommit = try { ((git -C $Root rev-parse HEAD 2>$null) -join '').Trim() } catch { 'unknown' }
if (-not $headCommit) { $headCommit = 'unknown' }
$closeArgv = if ($env:ENGINE_CLI_ENTRYPOINT) { $env:ENGINE_CLI_ENTRYPOINT } else { "engine-close.ps1 -Task $Task" }

function Invoke-Stage {
  param([string]$Label, [scriptblock]$Action)
  Write-Host "[engine-close] running: $Label"
  $output = @(& $Action 2>&1)
  $rc = if ($null -ne $LASTEXITCODE) { [int]$LASTEXITCODE } else { 0 }
  foreach ($line in $output) { Write-Host "$line" }
  return $rc
}

Push-Location $Root
try {
  $verifyRc = Invoke-Stage -Label "verify" -Action { & $cli verify $Task }
  $gateRc = Invoke-Stage -Label "gate" -Action { & $cli gate $Task }
  $doctorRc = Invoke-Stage -Label "doctor" -Action { & $cli doctor }
} finally {
  Pop-Location
}

$memoryMode = 'single-session'
$memoryStatus = 'pass'
$handoffPath = ''
$lockFile = Join-Path $EngineDir '.cache\session.lock'
$currentSid = if ($env:ENGINE_SESSION_ID) { $env:ENGINE_SESSION_ID } elseif ($env:CLAUDE_SESSION_ID) { $env:CLAUDE_SESSION_ID } else { '' }
if (Test-Path $lockFile) {
  $lockLine = (Get-Content -Raw -Path $lockFile -ErrorAction SilentlyContinue).Trim()
  $parts = $lockLine -split '\|'
  $lockSid = if ($parts.Count -ge 2) { $parts[1] } else { '' }
  $lockRole = if ($parts.Count -ge 3) { $parts[2] } else { '' }
  if ($lockRole -eq 'coordinator' -and $currentSid -and $currentSid -eq $lockSid) {
    $memoryMode = 'coordinator'
    $ctx = Join-Path $EngineDir 'CONTEXT.md'
    $handoff = Join-Path $EngineDir 'HANDOFF.md'
    $ctxText = if (Test-Path $ctx) { Get-Content -Raw -Path $ctx -Encoding UTF8 } else { '' }
    $handoffText = if (Test-Path $handoff) { Get-Content -Raw -Path $handoff -Encoding UTF8 } else { '' }
    if (-not (Test-Path $ctx) -or -not (Test-Path $handoff) -or $ctxText -notmatch [regex]::Escape($Task) -or $handoffText -notmatch [regex]::Escape($Task)) {
      $memoryStatus = 'block'
      Write-Error "[engine-close] coordinator memory is not linked to $Task; update CONTEXT.md/HANDOFF.md"
    }
  } else {
    $memoryMode = 'worker'
    if (-not $handoffAgent -or $handoffAgent -notmatch '^[A-Za-z0-9._-]+$') {
      $memoryStatus = 'block'
      Write-Error "[engine-close] worker closure requires --handoff AGENT (writes only that workstream shard)"
    } else {
      & $cli workstream $Task $handoffAgent --kind session *> $null
      $wsRc = if ($null -ne $LASTEXITCODE) { [int]$LASTEXITCODE } else { 0 }
      $shardDir = Join-Path $EngineDir "workstreams\$Task\sessions\s-$handoffAgent"
      $handoffPath = "engine/workstreams/$Task/sessions/s-$handoffAgent/HANDOFF.md"
      $shardHandoff = Join-Path $shardDir 'HANDOFF.md'
      if ($wsRc -ne 0 -or -not (Test-Path $shardHandoff)) {
        $memoryStatus = 'block'
      } else {
        $closure = "`r`n## Closure audit ($timestamp)`r`n`r`n- verify exit: $verifyRc`r`n- gate exit: $gateRc`r`n- doctor exit: $doctorRc`r`n- coordinator merge: pending`r`n"
        [System.IO.File]::AppendAllText($shardHandoff, $closure, (New-Object System.Text.UTF8Encoding $false))
      }
    }
  }
}

if (-not (Test-Path $lockFile)) {
  $ctx = Join-Path $EngineDir 'CONTEXT.md'
  $handoff = Join-Path $EngineDir 'HANDOFF.md'
  $ctxText = if (Test-Path $ctx) { Get-Content -Raw -Path $ctx -Encoding UTF8 } else { '' }
  $handoffText = if (Test-Path $handoff) { Get-Content -Raw -Path $handoff -Encoding UTF8 } else { '' }
  if (-not (Test-Path $ctx) -or -not (Test-Path $handoff) -or $ctxText -notmatch [regex]::Escape($Task) -or $handoffText -notmatch [regex]::Escape($Task)) {
    $memoryStatus = 'block'
    Write-Error "[engine-close] single-session memory is not linked to $Task; update CONTEXT.md/HANDOFF.md"
  }
}

$capsuleStatus = 'not_required'
$capsulePath = ''
$taskText = Get-Content -Raw -Path $taskFile -Encoding UTF8
$writeSetText = ''
$writeSetMatch = [regex]::Match($taskText, '(?ms)^##\s+WRITE-SET\s*$([\s\S]*?)(?=^##\s+|\z)')
if ($writeSetMatch.Success) { $writeSetText = $writeSetMatch.Groups[1].Value }
if ($writeSetText -match '(?m)^-\s+.*\.(sh|ps1|py|js|ts|go|rs|java|c|cpp|rb|php)\s*$') {
  $capsuleStatus = 'block'
  $changesDir = Join-Path $EngineDir 'changes'
  if (Test-Path $changesDir) {
    foreach ($f in (Get-ChildItem -Path $changesDir -File -Filter 'CHANGE-*.md' -ErrorAction SilentlyContinue)) {
      $text = Get-Content -Raw -Path $f.FullName -Encoding UTF8
      if ($text -match [regex]::Escape($Task)) {
        $capsuleStatus = 'pass'
        $capsulePath = "engine/changes/$($f.Name)"
        break
      }
    }
  }
  if ($memoryMode -eq 'worker' -and $memoryStatus -eq 'pass') {
    $capsuleStatus = 'deferred_to_coordinator'
  } elseif ($capsuleStatus -eq 'block') {
    Write-Error "[engine-close] no task-linked change capsule found for $Task"
  }
}

$status = 'pass'
if ($verifyRc -ne 0 -or $gateRc -ne 0 -or $doctorRc -ne 0 -or $memoryStatus -eq 'block' -or $capsuleStatus -eq 'block') {
  $status = 'block'
} elseif ($memoryMode -eq 'worker') {
  $status = 'handoff'
}

$out = Join-Path $EngineDir "evidence\$Task\CLOSE.json"
$closeObj = [ordered]@{
  task = $Task
  timestamp = $timestamp
  status = $status
  stages = [ordered]@{
    verify = [ordered]@{ status = if ($verifyRc -eq 0) { 'pass' } else { 'fail' }; exit = $verifyRc }
    gate = [ordered]@{ status = if ($gateRc -eq 0) { 'pass' } else { 'fail' }; exit = $gateRc }
    doctor = [ordered]@{ status = if ($doctorRc -eq 0) { 'pass' } else { 'fail' }; exit = $doctorRc }
  }
  memory = [ordered]@{ mode = $memoryMode; status = $memoryStatus; handoff_agent = if ($handoffAgent) { $handoffAgent } else { $null }; handoff_path = if ($handoffPath) { $handoffPath } else { $null } }
  capsule = [ordered]@{ status = $capsuleStatus; path = if ($capsulePath) { $capsulePath } else { $null } }
  write_provenance = [ordered]@{ writer = 'engine-close'; commit = $headCommit; timestamp = $timestamp; argv = $closeArgv }
}
$closeObj | ConvertTo-Json -Depth 8 | Set-Content -Path $out -Encoding UTF8

Write-Host "[Engine System] Close status for ${Task}: $($status.ToUpperInvariant())"
Write-Host "  Evidence: engine/evidence/$Task/CLOSE.json"
if ($handoffPath) { Write-Host "  Worker handoff: $handoffPath" }
if ($status -eq 'block') { exit 1 }
exit 0
