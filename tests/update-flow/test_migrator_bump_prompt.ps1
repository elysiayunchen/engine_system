# Test: migrator contract-version bump prompt (T-063, v6.17.2, issue #15)
#
# Validates the bump-detection prompt added to engine-migrate-contract.ps1.
# When the migrator detects a contract-version change (OLD stamp in the existing
# managed block != NEW stamp from engine/VERSION), it prints a prompt listing
# active/paused task cards. Idempotent repair (no version change) stays silent.
#
# Scenarios:
#   S1 (AC-1, AC-2): bump (OLD=6.16.0, NEW=6.17.2) + active card -> prompt fires + card listed
#   S2 (AC-3): idempotent repair (OLD=6.17.2 == NEW=6.17.2) -> prompt silent + "already current"
#   S3 (AC-2): bump with no active cards -> prompt fires + "No active/paused task cards found."
#   S4 (regression): fresh install (no prior managed block) -> migrator succeeds, no prompt, stamp written
#
# Black-box test: invokes the real migrator against a throwaway project tree.

$ErrorActionPreference = 'Stop'

Write-Host "[test_migrator_bump_prompt.ps1] T-063 migrator contract-version bump prompt"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$Migrator = Join-Path $RepoRoot 'engine\scripts\engine-migrate-contract.ps1'

$script:Pass = 0
$script:Fail = 0
$testRoots = @()

function Assert-Contains {
  param($Label, $Haystack, $Needle)
  if ($Haystack -like "*$Needle*") {
    Write-Host "  PASS: $Label"
    $script:Pass++
  } else {
    Write-Host "  FAIL: $Label"
    Write-Host "    expected to contain: $Needle"
    Write-Host "    actual output (last 25 lines):"
    ($Haystack -split "`n") | Select-Object -Last 25 | ForEach-Object { Write-Host "      $_" }
    $script:Fail++
  }
}

function Assert-NotContains {
  param($Label, $Haystack, $Needle)
  if ($Haystack -like "*$Needle*") {
    Write-Host "  FAIL: $Label"
    Write-Host "    expected NOT to contain: $Needle"
    Write-Host "    actual output (last 25 lines):"
    ($Haystack -split "`n") | Select-Object -Last 25 | ForEach-Object { Write-Host "      $_" }
    $script:Fail++
  } else {
    Write-Host "  PASS: $Label"
    $script:Pass++
  }
}

function Make-MinProject {
  param($Root, $Stamp, $Version)
  New-Item -ItemType Directory -Force -Path (Join-Path $Root 'engine\tasks') | Out-Null
  Set-Content -Path (Join-Path $Root 'engine\VERSION') -Value $Version -Encoding UTF8
  Set-Content -Path (Join-Path $Root 'engine\ENGINE_MAP.md') -Value @'
# Engine Map
| File | Purpose |
|------|---------|
| ENGINE_MAP.md | TOC |
'@ -Encoding UTF8
  $agents = @"
<!-- ENGINE_SYSTEM_CONTRACT_MIGRATIONS_START -->
<!-- contract-version: $Stamp -->
## Engine System Current Contract
> Managed by Engine System contract migration.

old content
<!-- ENGINE_SYSTEM_CONTRACT_MIGRATIONS_END -->
"@
  Set-Content -Path (Join-Path $Root 'AGENTS.md') -Value $agents -Encoding UTF8
}

function Invoke-Migrator {
  param($Root)
  # Capture ALL streams (Write-Host goes to Information stream in PS 5.0+) to a
  # temp log file, then read it back. This is the most reliable cross-PS-version
  # way to capture Write-Host output alongside Write-Output/Error.
  $log = [System.IO.Path]::GetTempFileName()
  try {
    # Use try/catch so an early `exit 0` inside the migrator (idempotent path)
    # does not abort the test harness. exit 0 is a normal process exit; under
    # $ErrorActionPreference=Stop the host still respects it as a clean stop.
    & powershell -NoProfile -Command "& '$Migrator' -Root '$Root' *> '$log'; exit 0" 2>&1 | Out-Null
    return (Get-Content -Path $log -Raw -Encoding UTF8)
  } finally {
    Remove-Item -Path $log -Force -ErrorAction SilentlyContinue
  }
}

# --- S1: bump scenario (OLD=6.16.0 -> NEW=6.17.2) with an active card ---
Write-Host "=== S1: bump scenario (OLD=6.16.0 -> NEW=6.17.2) + active card T-999 ==="
$S1 = Join-Path $env:TEMP "test-migrator-bump-S1"
if (Test-Path $S1) { Remove-Item -Recurse -Force $S1 }
$testRoots += $S1
Make-MinProject $S1 "6.16.0" "6.17.2"
Set-Content -Path (Join-Path $S1 'engine\tasks\T-999.md') -Value @'
# T-999: test active card
> status: active | lane: test | decision: none | plan: none | domain: test
GOAL: test bump prompt listing
'@ -Encoding UTF8

$outputS1 = Invoke-Migrator $S1
Assert-Contains "S1: bump prompt fires" $outputS1 "contract-version bumped: 6.16.0 -> 6.17.2"
Assert-Contains "S1: lists active card T-999" $outputS1 "T-999.md"
Assert-Contains "S1: review guidance text" $outputS1 "Please review active/paused task cards"

# --- S2: idempotent repair (OLD=6.17.2 == NEW=6.17.2) ---
# Reuse S1's post-migration tree: all 3 managed blocks now stamped 6.17.2 with
# the current session/doctor protocol body, so upsert reports "current" for all
# 3 files -> TOUCHED empty -> "already current" exit -> prompt silent.
Write-Host "=== S2: idempotent repair (OLD=6.17.2 == NEW=6.17.2) ==="
$S2 = Join-Path $env:TEMP "test-migrator-bump-S2"
if (Test-Path $S2) { Remove-Item -Recurse -Force $S2 }
$testRoots += $S2
New-Item -ItemType Directory -Force -Path (Join-Path $S2 'engine\tasks') | Out-Null
Copy-Item (Join-Path $S1 'engine\VERSION') (Join-Path $S2 'engine\VERSION')
Copy-Item (Join-Path $S1 'engine\ENGINE_MAP.md') (Join-Path $S2 'engine\ENGINE_MAP.md')
Copy-Item (Join-Path $S1 'AGENTS.md') (Join-Path $S2 'AGENTS.md')
Copy-Item (Join-Path $S1 'engine\SYSTEM.md') (Join-Path $S2 'engine\SYSTEM.md')
Copy-Item (Join-Path $S1 'engine\ENGINE_DOCTOR.md') (Join-Path $S2 'engine\ENGINE_DOCTOR.md')

$outputS2 = Invoke-Migrator $S2
Assert-NotContains "S2: no bump prompt on idempotent repair" $outputS2 "contract-version bumped"
Assert-Contains "S2: reports already current" $outputS2 "already current"

# --- S3: bump with no active cards -> prompt fires + "No active/paused task cards found." ---
Write-Host "=== S3: bump (OLD=6.16.0 -> NEW=6.17.2) with no active cards ==="
$S3 = Join-Path $env:TEMP "test-migrator-bump-S3"
if (Test-Path $S3) { Remove-Item -Recurse -Force $S3 }
$testRoots += $S3
Make-MinProject $S3 "6.16.0" "6.17.2"
# engine/tasks dir exists but empty (no T-*.md cards)

$outputS3 = Invoke-Migrator $S3
Assert-Contains "S3: bump prompt fires" $outputS3 "contract-version bumped: 6.16.0 -> 6.17.2"
Assert-Contains "S3: reports no active cards" $outputS3 "No active/paused task cards found."

# --- S4 (regression): fresh install (no prior managed block) ---
# Cross-platform parity with the bash S4: a project tree with AGENTS.md present
# but WITHOUT a prior contract-version stamp. Migrator should succeed, write the
# stamp, and NOT fire the bump prompt (OLD is empty -> no bump).
Write-Host "=== S4: fresh install (no prior managed block) -> no prompt, stamp written ==="
$S4 = Join-Path $env:TEMP "test-migrator-bump-S4"
if (Test-Path $S4) { Remove-Item -Recurse -Force $S4 }
$testRoots += $S4
New-Item -ItemType Directory -Force -Path (Join-Path $S4 'engine\tasks') | Out-Null
Set-Content -Path (Join-Path $S4 'engine\VERSION') -Value "6.17.2" -Encoding UTF8
Set-Content -Path (Join-Path $S4 'engine\ENGINE_MAP.md') -Value @'
# Engine Map
| File | Purpose |
|------|---------|
| ENGINE_MAP.md | TOC |
'@ -Encoding UTF8
# AGENTS.md exists but has NO managed block (fresh install state)
Set-Content -Path (Join-Path $S4 'AGENTS.md') -Value "# Project Agents`nThin bootloader.`n" -Encoding UTF8

$outputS4 = Invoke-Migrator $S4
Assert-NotContains "S4: no bump prompt on fresh install" $outputS4 "contract-version bumped"
$agentsS4 = Get-Content -Path (Join-Path $S4 'AGENTS.md') -Raw -Encoding UTF8
Assert-Contains "S4: migrator wrote stamp to AGENTS.md" $agentsS4 "contract-version: 6.17.2"

# Cleanup
$testRoots | ForEach-Object { if (Test-Path $_) { Remove-Item -Recurse -Force $_ -ErrorAction SilentlyContinue } }

Write-Host ""
Write-Host "=== Summary: $script:Pass passed, $script:Fail failed ==="
if ($script:Fail -ne 0) { exit 1 }
