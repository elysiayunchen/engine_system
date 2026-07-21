# T-036 AC-18 end-to-end: lock recovery (stale lock + assume-coordinator override).
# PowerShell mirror of test_lock_recovery.sh.
#
# Scenarios:
#   L1: SessionStart detects stale lock (pid dead) -> auto-recovers coordinator role + writes tombstone
#   L2: engine assume-coordinator (no --force) refuses when lock held by live pid
#   L3: engine assume-coordinator --force overrides live lock + writes forced-replaced tombstone
#   L4: engine assume-coordinator on no-lock -> fresh coordinator (clears stale tombstone)

$ErrorActionPreference = "Continue"

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent (Split-Path -Parent $Here)
$StartPS1 = Join-Path $RepoRoot "plugin\engine\scripts\engine-hook-session-start.ps1"
$EngineBinPS1 = Join-Path $RepoRoot "plugin\engine\bin\engine.ps1"

$script:pass = 0
$script:fail = 0
function Ok($name) { Write-Output "PASS  $name"; $script:pass++ }
function Bad($name) { Write-Output "FAIL  $name"; $script:fail++ }

$TmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("eng-ac18-lr-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $TmpRoot | Out-Null
try {
  function New-Fixture {
    $d = Join-Path $TmpRoot ("repo-" + [Guid]::NewGuid().ToString("N").Substring(0, 8))
    New-Item -ItemType Directory -Force -Path $d | Out-Null
    git -C $d init -q 2>&1 | Out-Null
    git -C $d config user.email "lr@test"
    git -C $d config user.name "lr"
    git -C $d config core.quotepath true
    git -C $d config core.autocrlf false
    git -C $d config commit.gpgsign false
    $engineDir = Join-Path $d "engine"
    $tasksDir = Join-Path $engineDir "tasks"
    $cacheSessions = Join-Path $engineDir ".cache\sessions"
    New-Item -ItemType Directory -Force -Path $tasksDir, $cacheSessions | Out-Null
    Set-Content -Path (Join-Path $engineDir "CONTEXT.md") -Value "ctx" -NoNewline
    Set-Content -Path (Join-Path $engineDir "HANDOFF.md") -Value "hf" -NoNewline
    Set-Content -Path (Join-Path $engineDir "ENGINE_MAP.md") -Value "map" -NoNewline
    $taskContent = @"
# T-001
> status: active | lane: main | decision: | domain: root
GOAL: test lock recovery
WRITE-SET: src/**,engine/workstreams/**
FORBIDDEN:
AC: AC-1 test | verify: true
"@
    Set-Content -Path (Join-Path $tasksDir "T-001.md") -Value $taskContent -NoNewline
    git -C $d add -A 2>$null
    git -C $d commit -qm "init" 2>$null
    return $d
  }

  Write-Output "=== lock recovery (ps1) ==="

  # L1: Stale lock (pid dead, use 999999) -> SessionStart auto-recovers.
  $r = New-Fixture
  $lockFile = Join-Path $r "engine\.cache\session.lock"
  $tombstoneFile = Join-Path $r "engine\.cache\session.tombstone"
  $started = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
  Set-Content -Path $lockFile -Value "999999|stale-coordinator|coordinator|$started|T-001" -NoNewline

  $env:CLAUDE_PROJECT_DIR = $r
  $payload = '{"session_id":"recovery-session"}'
  $out = $payload | & pwsh -NoProfile -File $StartPS1 2>$null
  $env:CLAUDE_PROJECT_DIR = ""
  if ($out -match 'recovered from stale') { Ok "L1 stale lock auto-recovered message" } else { Bad "L1 stale lock auto-recovered message" }
  if (Test-Path $tombstoneFile) { Ok "L1 tombstone written" } else { Bad "L1 tombstone written" }
  $lockContent = Get-Content -Raw -Path $lockFile
  if ($lockContent -match 'recovery-session') { Ok "L1 lock now held by recovery-session" } else { Bad "L1 lock now held by recovery-session" }

  # L2: engine assume-coordinator (no --force) refuses when lock held by live pid.
  $r2 = New-Fixture
  $lockFile2 = Join-Path $r2 "engine\.cache\session.lock"
  $started2 = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
  Set-Content -Path $lockFile2 -Value "$PID|live-coordinator|coordinator|$started2|T-001" -NoNewline

  Push-Location $r2
  try {
    $out2 = & pwsh -NoProfile -File $EngineBinPS1 assume-coordinator 2>&1
    $rc = $LASTEXITCODE
  } finally { Pop-Location }
  if ($rc -ne 0) { Ok "L2 assume-coordinator refused (exit=$rc)" } else { Bad "L2 assume-coordinator refused -> exit=0 (expected non-zero)" }
  if ($out2 -match 'lock held') { Ok "L2 error message shows lock holder" } else { Bad "L2 error message shows lock holder" }
  $lockAfter = Get-Content -Raw -Path $lockFile2
  if ($lockAfter -match 'live-coordinator') { Ok "L2 lock untouched (still live-coordinator)" } else { Bad "L2 lock untouched" }

  # L3: engine assume-coordinator --force overrides live lock + writes forced-replaced tombstone.
  $r3 = New-Fixture
  $lockFile3 = Join-Path $r3 "engine\.cache\session.lock"
  $tombstone3 = Join-Path $r3 "engine\.cache\session.tombstone"
  $started3 = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
  Set-Content -Path $lockFile3 -Value "$PID|old-coordinator|coordinator|$started3|T-001" -NoNewline

  Push-Location $r3
  try {
    $out3 = & pwsh -NoProfile -File $EngineBinPS1 assume-coordinator --force 2>&1
    $rc3 = $LASTEXITCODE
  } finally { Pop-Location }
  if ($rc3 -eq 0) { Ok "L3 --force override success (exit=0)" } else { Bad "L3 --force override success -> exit=$rc3" }
  if ($out3 -match 'force-replaced') { Ok "L3 force-replaced message shown" } else { Bad "L3 force-replaced message shown" }
  if (Test-Path $tombstone3) { Ok "L3 tombstone written" } else { Bad "L3 tombstone written" }
  $tsContent = Get-Content -Raw -Path $tombstone3 -ErrorAction SilentlyContinue
  if ($tsContent -match 'forced-replaced') { Ok "L3 tombstone reason=forced-replaced" } else { Bad "L3 tombstone reason=forced-replaced" }
  $lockAfter3 = Get-Content -Raw -Path $lockFile3
  if ($lockAfter3 -notmatch 'old-coordinator') { Ok "L3 lock overwritten (old-coordinator gone)" } else { Bad "L3 lock overwritten" }

  # L4: engine assume-coordinator on no-lock -> fresh coordinator + clears stale tombstone.
  $r4 = New-Fixture
  $tombstone4 = Join-Path $r4 "engine\.cache\session.tombstone"
  Set-Content -Path $tombstone4 -Value "2026-01-01T00:00:00Z|999999|prior-crash" -NoNewline

  Push-Location $r4
  try {
    $out4 = & pwsh -NoProfile -File $EngineBinPS1 assume-coordinator 2>&1
    $rc4 = $LASTEXITCODE
  } finally { Pop-Location }
  if ($rc4 -eq 0) { Ok "L4 fresh coordinator success (exit=0)" } else { Bad "L4 fresh coordinator success -> exit=$rc4" }
  if ($out4 -match 'Cleared stale tombstone') { Ok "L4 stale tombstone cleared message" } else { Bad "L4 stale tombstone cleared message" }
  if (-not (Test-Path $tombstone4)) { Ok "L4 stale tombstone removed" } else { Bad "L4 stale tombstone removed" }
  if (Test-Path (Join-Path $r4 "engine\.cache\session.lock")) { Ok "L4 fresh lock created" } else { Bad "L4 fresh lock created" }

  Write-Output ""
  Write-Output "lock_recovery result: $($script:pass) passed, $($script:fail) failed"
  if ($script:fail -ne 0) { exit 1 }
}
finally {
  Remove-Item -Recurse -Force -ErrorAction SilentlyContinue -Path $TmpRoot
}
