# T-036 AC-18 end-to-end: worker mode activation when coordinator lock is held.
# PowerShell mirror of test_worker_mode.sh.
#
# Scenario: A live coordinator lock exists (pid=current). A new SessionStart hook
# invocation with a different session_id MUST:
#   - Detect the live lock holder
#   - Output "Worker" message indicating degraded mode
#   - Create .cache/sessions/<worker_key>.role=worker marker file
#   - NOT overwrite the existing lock file

$ErrorActionPreference = "Continue"

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent (Split-Path -Parent $Here)
$StartPS1 = Join-Path $RepoRoot "plugin\engine\scripts\engine-hook-session-start.ps1"

$script:pass = 0
$script:fail = 0
function Ok($name) { Write-Output "PASS  $name"; $script:pass++ }
function Bad($name) { Write-Output "FAIL  $name"; $script:fail++ }

$TmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("eng-ac18-wm-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $TmpRoot | Out-Null
try {
  function New-Fixture {
    $d = Join-Path $TmpRoot ("repo-" + [Guid]::NewGuid().ToString("N").Substring(0, 8))
    New-Item -ItemType Directory -Force -Path $d | Out-Null
    git -C $d init -q 2>&1 | Out-Null
    git -C $d config user.email "wm@test"
    git -C $d config user.name "wm"
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
    $taskFile = Join-Path $tasksDir "T-001.md"
    $taskContent = @"
# T-001
> status: active | lane: main | decision: | domain: root
GOAL: test worker mode
WRITE-SET: src/**,engine/workstreams/**
FORBIDDEN:
AC: AC-1 test | verify: true
"@
    Set-Content -Path $taskFile -Value $taskContent -NoNewline
    git -C $d add -A 2>$null
    git -C $d commit -qm "init" 2>$null
    return $d
  }

  Write-Output "=== worker mode activation (ps1) ==="

  # W1: Live lock holder -> new session degrades to worker + writes .role=worker marker.
  $r = New-Fixture
  $lockFile = Join-Path $r "engine\.cache\session.lock"
  $livePid = $PID
  $started = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
  Set-Content -Path $lockFile -Value "$livePid|coordinator-session-1|coordinator|$started|T-001" -NoNewline
  $lockBefore = (Get-FileHash -Path $lockFile -Algorithm SHA256).Hash

  $env:CLAUDE_PROJECT_DIR = $r
  $payload = '{"session_id":"worker-session-2"}'
  $out = $payload | & pwsh -NoProfile -File $StartPS1 2>$null
  $env:CLAUDE_PROJECT_DIR = ""

  if ($out -match 'Worker') { Ok "W1 worker message shown" } else { Bad "W1 worker message shown" }
  $markerFile = Join-Path $r "engine\.cache\sessions\worker-session-2-main.role=worker"
  if (Test-Path $markerFile) { Ok "W1 .role=worker marker created" } else { Bad "W1 .role=worker marker created" }
  $lockAfter = (Get-FileHash -Path $lockFile -Algorithm SHA256).Hash
  if ($lockBefore -eq $lockAfter) { Ok "W1 lock file untouched" } else { Bad "W1 lock file untouched (coordinator overwritten)" }

  # W2: No lock present -> new session becomes coordinator.
  $r2 = New-Fixture
  if (Test-Path (Join-Path $r2 "engine\.cache\session.lock")) { Bad "W2 precondition: lock absent" }
  $env:CLAUDE_PROJECT_DIR = $r2
  $payload2 = '{"session_id":"fresh-session"}'
  $out2 = $payload2 | & pwsh -NoProfile -File $StartPS1 2>$null
  $env:CLAUDE_PROJECT_DIR = ""
  if ($out2 -match 'Coordinator') { Ok "W2 coordinator message shown" } else { Bad "W2 coordinator message shown" }
  $lockCreated = Join-Path $r2 "engine\.cache\session.lock"
  if (Test-Path $lockCreated) { Ok "W2 lock file created" } else { Bad "W2 lock file created" }
  $lockContent = Get-Content -Raw -Path $lockCreated
  if ($lockContent -match 'fresh-session') { Ok "W2 lock contains session_id" } else { Bad "W2 lock contains session_id" }
  if ($lockContent -match 'coordinator') { Ok "W2 lock role=coordinator" } else { Bad "W2 lock role=coordinator" }

  Write-Output ""
  Write-Output "worker_mode result: $($script:pass) passed, $($script:fail) failed"
  if ($script:fail -ne 0) { exit 1 }
}
finally {
  Remove-Item -Recurse -Force -ErrorAction SilentlyContinue -Path $TmpRoot
}
