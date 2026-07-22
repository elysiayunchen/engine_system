# T-038 AC-10 end-to-end: D-029 three-file worker write boundary (progress.md / checkpoint.md / INVENTORY.md).
# PowerShell mirror of test_worker_writes_shard.sh.
#
# Scenario: v6.11.1 (D-029/T-038) extends Is-SharedMemory in engine-hook-stop.{sh,ps1}
# to include the three D-028 worker-write-boundary files. Worker mode (signal 1
# agent_id non-empty OR signal 2 .role=worker marker) MUST:
#   - Block worker writing shared engine/tasks/T-NNN/progress.md
#   - Block worker writing shared engine/evidence/T-NNN/checkpoint.md
#   - Block worker writing shared engine/domains/<d>/INVENTORY.md
#   - Allow worker writing own engine/workstreams/T-NNN/<worker_id>/progress.md (shard)
#   - Allow coordinator (no worker signal) writing shared progress.md

$ErrorActionPreference = "Continue"

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent (Split-Path -Parent $Here)
$StopPS1 = Join-Path $RepoRoot "plugin\engine\scripts\engine-hook-stop.ps1"

# Determine PowerShell host: prefer pwsh (PS 7+), fall back to powershell (PS 5.1).
$PSHost = "pwsh"
if (-not (Get-Command $PSHost -ErrorAction SilentlyContinue)) { $PSHost = "powershell" }

$script:pass = 0
$script:fail = 0
function Ok($name) { Write-Output "PASS  $name"; $script:pass++ }
function Bad($name) { Write-Output "FAIL  $name"; $script:fail++ }

function Classify($out) {
  if ($out -match '"decision":"block"') { return "block" }
  if ($out -match '"systemMessage"') { return "warn" }
  return "pass"
}

$TmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("eng-t038-ws-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $TmpRoot | Out-Null
try {
  function New-Fixture {
    $d = Join-Path $TmpRoot ("repo-" + [Guid]::NewGuid().ToString("N").Substring(0, 8))
    New-Item -ItemType Directory -Force -Path $d | Out-Null
    git -C $d init -q 2>&1 | Out-Null
    git -C $d config user.email "ws@test"
    git -C $d config user.name "ws"
    git -C $d config core.quotepath true
    git -C $d config core.autocrlf false
    git -C $d config commit.gpgsign false
    $engineDir = Join-Path $d "engine"
    $taskDir = Join-Path $engineDir "tasks\T-001"
    $evidenceDir = Join-Path $engineDir "evidence\T-001"
    $domainDir = Join-Path $engineDir "domains\routing"
    $cacheSessions = Join-Path $engineDir ".cache\sessions"
    $workstreamDir = Join-Path $engineDir "workstreams\T-001\s-worker-1-main"
    $srcDir = Join-Path $d "src"
    New-Item -ItemType Directory -Force -Path $taskDir, $evidenceDir, $domainDir, $cacheSessions, $workstreamDir, $srcDir | Out-Null
    Set-Content -Path (Join-Path $engineDir "CONTEXT.md") -Value "ctx" -NoNewline
    Set-Content -Path (Join-Path $engineDir "HANDOFF.md") -Value "hf" -NoNewline
    Set-Content -Path (Join-Path $engineDir "ENGINE_MAP.md") -Value "map" -NoNewline
    Set-Content -Path (Join-Path $domainDir "INVENTORY.md") -Value "inv" -NoNewline
    Set-Content -Path (Join-Path $taskDir "progress.md") -Value "prog" -NoNewline
    Set-Content -Path (Join-Path $evidenceDir "checkpoint.md") -Value "ckpt" -NoNewline
    Set-Content -Path (Join-Path $srcDir "app.js") -Value "code" -NoNewline
    # WRITE-SET includes the three boundary files so that the coordinator (signal-less)
    # control case is not blocked by block_scope; workers are blocked by Is-SharedMemory.
    $taskContent = @"
# T-001
> status: active | lane: main | decision: | domain: root
GOAL: test worker write boundary
WRITE-SET: src/**,engine/workstreams/**,engine/CONTEXT.md,engine/HANDOFF.md,engine/tasks/T-001/**,engine/evidence/T-001/**,engine/domains/routing/INVENTORY.md
FORBIDDEN:
AC: AC-1 test | verify: true
"@
    Set-Content -Path (Join-Path $engineDir "tasks\T-001.md") -Value $taskContent -NoNewline
    git -C $d add -A 2>$null
    git -C $d commit -qm "init" 2>$null
    return $d
  }

  Write-Output "=== Worker writes shard boundary (ps1) ==="

  # W1: Worker (signal 1 = agent_id) writes shared progress.md -> block (AC-1 new pattern)
  $r = New-Fixture
  $payload = '{"session_id":"s-1","agent_id":"agent-1","tool_name":"Edit","tool_input":{"file_path":"engine/tasks/T-001/progress.md"}}'
  $env:CLAUDE_PROJECT_DIR = $r
  $out = $payload | & $PSHost -NoProfile -File $StopPS1 -Mode --pre-tool-use 2>$null
  $env:CLAUDE_PROJECT_DIR = ""
  $got = Classify $out
  if ($got -eq "block") { Ok "W1 worker blocked on shared progress.md" } else { Bad "W1 worker blocked on shared progress.md -> got=$got" }

  # W2: Worker writes shared checkpoint.md -> block (AC-1 new pattern)
  $r = New-Fixture
  $payload = '{"session_id":"s-1","agent_id":"agent-1","tool_name":"Edit","tool_input":{"file_path":"engine/evidence/T-001/checkpoint.md"}}'
  $env:CLAUDE_PROJECT_DIR = $r
  $out = $payload | & $PSHost -NoProfile -File $StopPS1 -Mode --pre-tool-use 2>$null
  $env:CLAUDE_PROJECT_DIR = ""
  $got = Classify $out
  if ($got -eq "block") { Ok "W2 worker blocked on shared checkpoint.md" } else { Bad "W2 worker blocked on shared checkpoint.md -> got=$got" }

  # W3: Worker writes shared INVENTORY.md -> block (AC-1 new pattern)
  $r = New-Fixture
  $payload = '{"session_id":"s-1","agent_id":"agent-1","tool_name":"Edit","tool_input":{"file_path":"engine/domains/routing/INVENTORY.md"}}'
  $env:CLAUDE_PROJECT_DIR = $r
  $out = $payload | & $PSHost -NoProfile -File $StopPS1 -Mode --pre-tool-use 2>$null
  $env:CLAUDE_PROJECT_DIR = ""
  $got = Classify $out
  if ($got -eq "block") { Ok "W3 worker blocked on shared INVENTORY.md" } else { Bad "W3 worker blocked on shared INVENTORY.md -> got=$got" }

  # W4: Worker writes own shard progress.md -> pass (worker writes own shard)
  # session_id="s-worker-1" -> session_key=safe_id("s-worker-1-main")="s-worker-1-main" -> worker_id="s-worker-1-main"
  # Allowed shard path = engine/workstreams/T-001/s-worker-1-main/*
  $r = New-Fixture
  New-Item -ItemType File -Force -Path (Join-Path $r "engine\.cache\sessions\s-worker-1-main.role=worker") | Out-Null
  $payload = '{"session_id":"s-worker-1","tool_name":"Write","tool_input":{"file_path":"engine/workstreams/T-001/s-worker-1-main/progress.md"}}'
  $env:CLAUDE_PROJECT_DIR = $r
  $out = $payload | & $PSHost -NoProfile -File $StopPS1 -Mode --pre-tool-use 2>$null
  $env:CLAUDE_PROJECT_DIR = ""
  $got = Classify $out
  if ($got -eq "pass") { Ok "W4 worker writes own shard progress.md -> pass" } else { Bad "W4 worker writes own shard progress.md -> got=$got" }

  # W5: Worker writes own shard checkpoint.md -> pass
  $r = New-Fixture
  New-Item -ItemType File -Force -Path (Join-Path $r "engine\.cache\sessions\s-worker-1-main.role=worker") | Out-Null
  $payload = '{"session_id":"s-worker-1","tool_name":"Write","tool_input":{"file_path":"engine/workstreams/T-001/s-worker-1-main/checkpoint.md"}}'
  $env:CLAUDE_PROJECT_DIR = $r
  $out = $payload | & $PSHost -NoProfile -File $StopPS1 -Mode --pre-tool-use 2>$null
  $env:CLAUDE_PROJECT_DIR = ""
  $got = Classify $out
  if ($got -eq "pass") { Ok "W5 worker writes own shard checkpoint.md -> pass" } else { Bad "W5 worker writes own shard checkpoint.md -> got=$got" }

  # W6: Coordinator (no worker signal) writes shared progress.md -> pass (control)
  $r = New-Fixture
  $payload = '{"session_id":"s-coord","tool_name":"Edit","tool_input":{"file_path":"engine/tasks/T-001/progress.md"}}'
  Add-Content -Path (Join-Path $r "engine\CONTEXT.md") -Value "updated" -NoNewline
  $env:CLAUDE_PROJECT_DIR = $r
  $out = $payload | & $PSHost -NoProfile -File $StopPS1 -Mode --pre-tool-use 2>$null
  $env:CLAUDE_PROJECT_DIR = ""
  $got = Classify $out
  if ($got -ne "block") { Ok "W6 coordinator writes shared progress.md -> pass (got=$got)" } else { Bad "W6 coordinator writes shared progress.md -> got=$got" }

  Write-Output ""
  Write-Output "worker_writes_shard result: $($script:pass) passed, $($script:fail) failed"
  if ($script:fail -ne 0) { exit 1 }
}
finally {
  Remove-Item -Recurse -Force -ErrorAction SilentlyContinue -Path $TmpRoot
}
