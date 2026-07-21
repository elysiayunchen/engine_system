# T-036 AC-18 end-to-end: kill switch for multi-session lock.
# PowerShell mirror of test_kill_switch.sh.
#
# Scenarios:
#   K1: ENGINE_DISABLE_MULTI_SESSION=1 env var -> SessionStart skips lock detection
#   K2: engine/.cache/multi-session.disabled flag file -> SessionStart skips lock detection
#   K3: engine disable-multi-session on -> creates flag file
#   K4: engine disable-multi-session off -> removes flag file
#   K5: engine disable-multi-session status -> reports current state

$ErrorActionPreference = "Continue"

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent (Split-Path -Parent $Here)
$StartPS1 = Join-Path $RepoRoot "plugin\engine\scripts\engine-hook-session-start.ps1"
$EngineBinPS1 = Join-Path $RepoRoot "plugin\engine\bin\engine.ps1"

$script:pass = 0
$script:fail = 0
function Ok($name) { Write-Output "PASS  $name"; $script:pass++ }
function Bad($name) { Write-Output "FAIL  $name"; $script:fail++ }

$TmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("eng-ac18-ks-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $TmpRoot | Out-Null
try {
  function New-Fixture {
    $d = Join-Path $TmpRoot ("repo-" + [Guid]::NewGuid().ToString("N").Substring(0, 8))
    New-Item -ItemType Directory -Force -Path $d | Out-Null
    git -C $d init -q 2>&1 | Out-Null
    git -C $d config user.email "ks@test"
    git -C $d config user.name "ks"
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
GOAL: test kill switch
WRITE-SET: src/**,engine/workstreams/**
FORBIDDEN:
AC: AC-1 test | verify: true
"@
    Set-Content -Path (Join-Path $tasksDir "T-001.md") -Value $taskContent -NoNewline
    git -C $d add -A 2>$null
    git -C $d commit -qm "init" 2>$null
    return $d
  }

  Write-Output "=== kill switch (ps1) ==="

  # K1: ENGINE_DISABLE_MULTI_SESSION=1 -> SessionStart skips lock detection entirely.
  $r = New-Fixture
  $lockFile = Join-Path $r "engine\.cache\session.lock"
  $started = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
  Set-Content -Path $lockFile -Value "$PID|other-coordinator|coordinator|$started|T-001" -NoNewline
  $lockBefore = (Get-FileHash -Path $lockFile -Algorithm SHA256).Hash

  $env:CLAUDE_PROJECT_DIR = $r
  $env:ENGINE_DISABLE_MULTI_SESSION = "1"
  $payload = '{"session_id":"kill-switch-session"}'
  $out = $payload | & pwsh -NoProfile -File $StartPS1 2>$null
  $env:ENGINE_DISABLE_MULTI_SESSION = ""
  $env:CLAUDE_PROJECT_DIR = ""
  if ($out -notmatch 'multi-session lock') { Ok "K1 env var skips lock detection" } else { Bad "K1 env var skips lock detection" }
  $lockAfter = (Get-FileHash -Path $lockFile -Algorithm SHA256).Hash
  if ($lockBefore -eq $lockAfter) { Ok "K1 lock file untouched" } else { Bad "K1 lock file untouched" }
  $marker = Join-Path $r "engine\.cache\sessions\kill-switch-session-main.role=worker"
  if (-not (Test-Path $marker)) { Ok "K1 no worker marker created" } else { Bad "K1 no worker marker created" }

  # K2: .cache/multi-session.disabled flag file -> SessionStart skips lock detection.
  $r2 = New-Fixture
  New-Item -ItemType File -Force -Path (Join-Path $r2 "engine\.cache\multi-session.disabled") | Out-Null
  $lockFile2 = Join-Path $r2 "engine\.cache\session.lock"
  Set-Content -Path $lockFile2 -Value "$PID|other-coord-2|coordinator|$started|T-001" -NoNewline
  $lockBefore2 = (Get-FileHash -Path $lockFile2 -Algorithm SHA256).Hash

  $env:CLAUDE_PROJECT_DIR = $r2
  $payload2 = '{"session_id":"flag-disabled-session"}'
  $out2 = $payload2 | & pwsh -NoProfile -File $StartPS1 2>$null
  $env:CLAUDE_PROJECT_DIR = ""
  if ($out2 -notmatch 'multi-session lock') { Ok "K2 flag file skips lock detection" } else { Bad "K2 flag file skips lock detection" }
  $lockAfter2 = (Get-FileHash -Path $lockFile2 -Algorithm SHA256).Hash
  if ($lockBefore2 -eq $lockAfter2) { Ok "K2 lock file untouched" } else { Bad "K2 lock file untouched" }

  # K3: engine disable-multi-session on -> creates flag file.
  $r3 = New-Fixture
  Push-Location $r3
  try {
    $out3 = & pwsh -NoProfile -File $EngineBinPS1 disable-multi-session on 2>&1
    $rc3 = $LASTEXITCODE
  } finally { Pop-Location }
  if ($rc3 -eq 0) { Ok "K3 disable on exit=0" } else { Bad "K3 disable on exit=$rc3" }
  if (Test-Path (Join-Path $r3 "engine\.cache\multi-session.disabled")) { Ok "K3 flag file created" } else { Bad "K3 flag file created" }
  if ($out3 -match 'DISABLED') { Ok "K3 DISABLED message shown" } else { Bad "K3 DISABLED message shown" }

  # K4: engine disable-multi-session off -> removes flag file.
  Push-Location $r3
  try {
    $out4 = & pwsh -NoProfile -File $EngineBinPS1 disable-multi-session off 2>&1
    $rc4 = $LASTEXITCODE
  } finally { Pop-Location }
  if ($rc4 -eq 0) { Ok "K4 disable off exit=0" } else { Bad "K4 disable off exit=$rc4" }
  if (-not (Test-Path (Join-Path $r3 "engine\.cache\multi-session.disabled"))) { Ok "K4 flag file removed" } else { Bad "K4 flag file removed" }
  if ($out4 -match 'ENABLED') { Ok "K4 ENABLED message shown" } else { Bad "K4 ENABLED message shown" }

  # K5: status reports ENABLED when no flag/env.
  $r5 = New-Fixture
  Push-Location $r5
  try {
    $out5 = & pwsh -NoProfile -File $EngineBinPS1 disable-multi-session status 2>&1
    $rc5 = $LASTEXITCODE
  } finally { Pop-Location }
  if ($rc5 -eq 0) { Ok "K5 status exit=0" } else { Bad "K5 status exit=$rc5" }
  if ($out5 -match 'ENABLED') { Ok "K5 status reports ENABLED" } else { Bad "K5 status reports ENABLED" }

  # K6: status reports DISABLED when flag file exists.
  New-Item -ItemType File -Force -Path (Join-Path $r5 "engine\.cache\multi-session.disabled") | Out-Null
  Push-Location $r5
  try {
    $out6 = & pwsh -NoProfile -File $EngineBinPS1 disable-multi-session status 2>&1
  } finally { Pop-Location }
  if ($out6 -match 'DISABLED') { Ok "K6 status reports DISABLED (flag)" } else { Bad "K6 status reports DISABLED (flag)" }

  # K7: status reports DISABLED when env var set (no flag file).
  Remove-Item -Force -ErrorAction SilentlyContinue -Path (Join-Path $r5 "engine\.cache\multi-session.disabled")
  Push-Location $r5
  try {
    $env:ENGINE_DISABLE_MULTI_SESSION = "1"
    $out7 = & pwsh -NoProfile -File $EngineBinPS1 disable-multi-session status 2>&1
    $env:ENGINE_DISABLE_MULTI_SESSION = ""
  } finally { Pop-Location }
  if ($out7 -match 'DISABLED') { Ok "K7 status reports DISABLED (env)" } else { Bad "K7 status reports DISABLED (env)" }

  Write-Output ""
  Write-Output "kill_switch result: $($script:pass) passed, $($script:fail) failed"
  if ($script:fail -ne 0) { exit 1 }
}
finally {
  Remove-Item -Recurse -Force -ErrorAction SilentlyContinue -Path $TmpRoot
}
