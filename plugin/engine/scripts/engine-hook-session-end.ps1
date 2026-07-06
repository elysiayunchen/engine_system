# Engine System - SessionEnd health hook (PowerShell)
#
# Runs Engine Doctor at the end of an agent turn/session and stores a short pending note
# for the next SessionStart hook. This hook never blocks; engine-hook-stop.ps1 is the
# gatekeeper.

param()

$ErrorActionPreference = "Continue"
trap { Write-Warning "[engine-hook-session-end.ps1] error: $_"; continue }

$Root = $env:CLAUDE_PROJECT_DIR
if (-not $Root) { $Root = $PWD.Path }

$EngineDir = Join-Path $Root "engine"
if (-not (Test-Path $EngineDir)) { exit 0 }

$CacheDir = Join-Path $EngineDir ".cache"
$PendingFile = Join-Path $CacheDir "pending.txt"
$LogFile = Join-Path $CacheDir "session-end-doctor.log"
New-Item -ItemType Directory -Force -Path $CacheDir | Out-Null

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Doctor = Join-Path $EngineDir "scripts\engine-doctor.ps1"
if (-not (Test-Path $Doctor)) {
  $Fallback = Join-Path $ScriptDir "engine-doctor.ps1"
  if (Test-Path $Fallback) { $Doctor = $Fallback }
}

$Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

if (-not (Test-Path $Doctor)) {
  @(
    "Engine Doctor pending ($Timestamp)"
    "- Doctor script not found. Run /engine-sync to restore bundled tooling."
  ) | Set-Content -Path $PendingFile -Encoding UTF8
  exit 0
}

$Output = & powershell -NoProfile -ExecutionPolicy Bypass -File $Doctor -Root $Root 2>&1
$ExitCode = $LASTEXITCODE
$Output | Set-Content -Path $LogFile -Encoding UTF8

$Summary = ($Output | Select-String "Engine Doctor:" | Select-Object -Last 1).Line
if (-not $Summary) { $Summary = "Engine Doctor exited with status $ExitCode" }

if ($ExitCode -eq 0 -and $Summary -like "*0 failure(s), 0 warning(s)*") {
  Remove-Item -Path $PendingFile -ErrorAction SilentlyContinue
  exit 0
}

@(
  "Engine Doctor pending ($Timestamp)"
  "- $Summary"
  "- Review with /engine-doctor, then run /engine-reconcile if the registry or anchors drifted."
  "- Log: engine/.cache/session-end-doctor.log"
) | Set-Content -Path $PendingFile -Encoding UTF8

exit 0
