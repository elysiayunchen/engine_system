# Test: engine-verify checkpoint.md dedup behavior (T-039, v6.11.2)
#
# Simulates the dedup logic from engine/scripts/engine-verify.ps1 and validates:
#   (1) First AC PASS creates checkpoint.md with exactly 1 AC line.
#   (2) Same AC re-PASS keeps only 1 line (timestamp updated, no duplicate).
#   (3) Different AC PASS appends a new line (total 2 ACs).
#   (4) Re-PASS of first AC keeps total at 2 lines (dedup, no growth).
#
# This is a black-box test of the dedup algorithm (Where-Object -notmatch +
# Add-Content), which is the core fix in T-039. The real engine-verify.ps1 uses
# the same algorithm on engine/evidence/T-NNN/checkpoint.md; this test isolates
# it in a tmpdir. Compatible with Windows PowerShell 5.1 (no pwsh-only syntax).

$ErrorActionPreference = "Stop"
$Root = $env:CLAUDE_PROJECT_DIR
if (-not $Root) { $Root = $PWD.Path }

$TmpDir = Join-Path $env:TEMP ("engine-dedup-test-" + [System.IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Path $TmpDir -Force | Out-Null
$Checkpoint = Join-Path $TmpDir "checkpoint.md"

try {
  function Write-CheckpointLine {
    param([string]$AcId, [string]$Summary, [string]$Ts)
    if (-not (Test-Path $Checkpoint)) {
      $header = "# Checkpoint - T-TEST`r`n> Last updated: $Ts by engine-verify | AC-level recovery anchor (compressed)`r`n`r`n## Completed AC`r`n"
      Set-Content -Path $Checkpoint -Value $header -Encoding UTF8
    }
    $line = "- [x] $AcId $Summary - evidence/$AcId.json PASS @ $Ts"
    # Dedup: remove existing AC-N line(s) if any, then append fresh line.
    $existing = Get-Content -Path $Checkpoint -Encoding UTF8
    $filtered = $existing | Where-Object { $_ -notmatch "^- \[x\] $AcId " }
    Set-Content -Path $Checkpoint -Value $filtered -Encoding UTF8
    Add-Content -Path $Checkpoint -Value $line -Encoding UTF8
  }

  function Get-AcLineCount {
    (Select-String -Path $Checkpoint -Pattern '^- \[x\] AC-' -Encoding UTF8 -ErrorAction SilentlyContinue).Count
  }

  Write-Output "[test_checkpoint_dedup.ps1] T-039 dedup behavior"

  # Test 1: First PASS creates checkpoint.md with 1 AC line.
  Write-CheckpointLine -AcId "AC-1" -Summary "verify cmd 1" -Ts "2026-07-22T10:00:00Z"
  $n = Get-AcLineCount
  if ($n -ne 1) { Write-Output "FAIL: Test 1 expected 1 AC, got $n"; exit 1 }
  Write-Output "PASS: Test 1 (first PASS creates 1 AC line)"

  # Test 2: Same AC re-PASS keeps only 1 line (timestamp updated).
  # Note: only the AC-1 line's timestamp is checked; the header "Last updated"
  # line is created once at first PASS and intentionally not refreshed on re-PASS
  # (matches engine-verify.ps1 behavior — header timestamp stays at creation time).
  Write-CheckpointLine -AcId "AC-1" -Summary "verify cmd 1" -Ts "2026-07-22T11:00:00Z"
  $n = Get-AcLineCount
  if ($n -ne 1) { Write-Output "FAIL: Test 2 expected 1 AC after re-PASS, got $n"; exit 1 }
  $ac1Line = (Get-Content -Path $Checkpoint -Encoding UTF8) | Where-Object { $_ -match '^- \[x\] AC-1 ' } | Select-Object -First 1
  if (($ac1Line -match '2026-07-22T11:00:00Z') -and ($ac1Line -notmatch '2026-07-22T10:00:00Z')) {
    Write-Output "PASS: Test 2 (re-PASS dedup, AC-1 timestamp updated)"
  } else {
    Write-Output "FAIL: Test 2 AC-1 timestamp not updated correctly: $ac1Line"; exit 1
  }

  # Test 3: Different AC PASS appends new line.
  Write-CheckpointLine -AcId "AC-2" -Summary "verify cmd 2" -Ts "2026-07-22T12:00:00Z"
  $n = Get-AcLineCount
  if ($n -ne 2) { Write-Output "FAIL: Test 3 expected 2 ACs, got $n"; exit 1 }
  Write-Output "PASS: Test 3 (different AC appends new line)"

  # Test 4: Re-PASS AC-1 keeps total at 2 (dedup, no growth).
  Write-CheckpointLine -AcId "AC-1" -Summary "verify cmd 1" -Ts "2026-07-22T13:00:00Z"
  $n = Get-AcLineCount
  if ($n -ne 2) { Write-Output "FAIL: Test 4 expected 2 ACs after AC-1 re-PASS, got $n"; exit 1 }
  Write-Output "PASS: Test 4 (AC-1 re-PASS keeps 2 lines)"

  Write-Output ""
  Write-Output "All tests passed: checkpoint.md dedup behavior verified"
} finally {
  Remove-Item -Path $TmpDir -Recurse -Force -ErrorAction SilentlyContinue
}
