# T-036 AC-18 end-to-end: PreToolUse dual-signal worker detection.
# PowerShell mirror of test_double_signal.sh.
#
# Scenario: v6.11.0 extends PreToolUse from single signal (agent_id non-empty) to
# dual-signal OR (agent_id OR .role=worker marker). The new signal 2 covers top-level
# sessions (no agent_id) that have been degraded to worker by SessionStart.

$ErrorActionPreference = "Continue"

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent (Split-Path -Parent $Here)
$StopPS1 = Join-Path $RepoRoot "plugin\engine\scripts\engine-hook-stop.ps1"

$script:pass = 0
$script:fail = 0
function Ok($name) { Write-Output "PASS  $name"; $script:pass++ }
function Bad($name) { Write-Output "FAIL  $name"; $script:fail++ }

function Classify($out) {
  if ($out -match '"decision":"block"') { return "block" }
  if ($out -match '"systemMessage"') { return "warn" }
  return "pass"
}

$TmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("eng-ac18-ds-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $TmpRoot | Out-Null
try {
  function New-Fixture {
    $d = Join-Path $TmpRoot ("repo-" + [Guid]::NewGuid().ToString("N").Substring(0, 8))
    New-Item -ItemType Directory -Force -Path $d | Out-Null
    git -C $d init -q 2>&1 | Out-Null
    git -C $d config user.email "ds@test"
    git -C $d config user.name "ds"
    git -C $d config core.quotepath true
    git -C $d config core.autocrlf false
    git -C $d config commit.gpgsign false
    $engineDir = Join-Path $d "engine"
    $tasksDir = Join-Path $engineDir "tasks"
    $cacheSessions = Join-Path $engineDir ".cache\sessions"
    $workstreamDir = Join-Path $engineDir "workstreams\T-001\worker-top"
    $srcDir = Join-Path $d "src"
    New-Item -ItemType Directory -Force -Path $tasksDir, $cacheSessions, $workstreamDir, $srcDir | Out-Null
    Set-Content -Path (Join-Path $engineDir "CONTEXT.md") -Value "ctx" -NoNewline
    Set-Content -Path (Join-Path $engineDir "HANDOFF.md") -Value "hf" -NoNewline
    Set-Content -Path (Join-Path $engineDir "ENGINE_MAP.md") -Value "map" -NoNewline
    Set-Content -Path (Join-Path $srcDir "app.js") -Value "code" -NoNewline
    # T-001 WRITE-SET explicitly includes engine/CONTEXT.md + engine/HANDOFF.md so that
    # block_scope does not block shared-memory writes by the coordinator (signal-less) mode.
    # Workers are blocked from shared memory by the is_shared_memory check, not by block_scope.
    $taskContent = @"
# T-001
> status: active | lane: main | decision: | domain: root
GOAL: test dual signal
WRITE-SET: src/**,engine/workstreams/**,engine/CONTEXT.md,engine/HANDOFF.md
FORBIDDEN:
AC: AC-1 test | verify: true
"@
    Set-Content -Path (Join-Path $tasksDir "T-001.md") -Value $taskContent -NoNewline
    git -C $d add -A 2>$null
    git -C $d commit -qm "init" 2>$null
    return $d
  }

  Write-Output "=== PreToolUse dual-signal (ps1) ==="

  # D1: Top-level session (no agent_id) + .role=worker marker exists -> MUST block shared write.
  $r = New-Fixture
  New-Item -ItemType File -Force -Path (Join-Path $r "engine\.cache\sessions\s-top-main.role=worker") | Out-Null
  $payload = '{"session_id":"s-top","tool_name":"Edit","tool_input":{"file_path":"engine/CONTEXT.md"}}'
  $env:CLAUDE_PROJECT_DIR = $r
  $out = $payload | & pwsh -NoProfile -File $StopPS1 -Mode --pre-tool-use 2>$null
  $env:CLAUDE_PROJECT_DIR = ""
  $got = Classify $out
  if ($got -eq "block") { Ok "D1 signal-2 blocks shared write (no agent_id, marker present)" } else { Bad "D1 signal-2 blocks shared write -> got=$got" }

  # D2: Top-level session + NO .role=worker marker + NO agent_id -> coordinator mode (no block).
  $r = New-Fixture
  Add-Content -Path (Join-Path $r "engine\CONTEXT.md") -Value "updated" -NoNewline
  $env:CLAUDE_PROJECT_DIR = $r
  $out = $payload | & pwsh -NoProfile -File $StopPS1 -Mode --pre-tool-use 2>$null
  $env:CLAUDE_PROJECT_DIR = ""
  $got = Classify $out
  if ($got -ne "block") { Ok "D2 no signal = coordinator mode (got=$got)" } else { Bad "D2 no signal = coordinator mode -> got=$got" }

  # D3: Top-level session + .role=worker marker + writes own workstream shard -> pass.
  # session_id="s-top" (no agent_id) -> worker_key=s-top-main -> allowed shard path =
  # engine/workstreams/T-001/s-top-main/*
  $r = New-Fixture
  New-Item -ItemType File -Force -Path (Join-Path $r "engine\.cache\sessions\s-top-main.role=worker") | Out-Null
  $payload = '{"session_id":"s-top","tool_name":"Write","tool_input":{"file_path":"engine/workstreams/T-001/s-top-main/HANDOFF.md"}}'
  $env:CLAUDE_PROJECT_DIR = $r
  $out = $payload | & pwsh -NoProfile -File $StopPS1 -Mode --pre-tool-use 2>$null
  $env:CLAUDE_PROJECT_DIR = ""
  $got = Classify $out
  if ($got -eq "pass") { Ok "D3 signal-2 worker writes own shard -> pass" } else { Bad "D3 signal-2 worker writes own shard -> got=$got" }

  # D4: Top-level session + .role=worker marker + writes sibling's shard -> block.
  $r = New-Fixture
  New-Item -ItemType File -Force -Path (Join-Path $r "engine\.cache\sessions\s-top-main.role=worker") | Out-Null
  New-Item -ItemType Directory -Force -Path (Join-Path $r "engine\workstreams\T-001\worker-sibling") | Out-Null
  $payload = '{"session_id":"s-top","tool_name":"Write","tool_input":{"file_path":"engine/workstreams/T-001/worker-sibling/HANDOFF.md"}}'
  $env:CLAUDE_PROJECT_DIR = $r
  $out = $payload | & pwsh -NoProfile -File $StopPS1 -Mode --pre-tool-use 2>$null
  $env:CLAUDE_PROJECT_DIR = ""
  $got = Classify $out
  if ($got -eq "block") { Ok "D4 signal-2 worker blocked on sibling shard" } else { Bad "D4 signal-2 worker blocked on sibling shard -> got=$got" }

  Write-Output ""
  Write-Output "double_signal result: $($script:pass) passed, $($script:fail) failed"
  if ($script:fail -ne 0) { exit 1 }
}
finally {
  Remove-Item -Recurse -Force -ErrorAction SilentlyContinue -Path $TmpRoot
}
