# Engine System - Behavior verifier (v6 S4)
#
# Executes task card AC verify commands, writes PASS/FAIL + output fingerprint
# to engine/evidence/T-NNN/AC-N.json. Machine-enforces N3 (done has evidence).
#
# Usage: pwsh -File engine/scripts/engine-verify.ps1 -Task T-NNN
# Safety: verify commands are declared in the task card; approving the card
# approves verify. User-run, not hook-automated.

param([Parameter(Mandatory=$false)][string]$Task)

$Root = $env:CLAUDE_PROJECT_DIR
if (-not $Root) { $Root = $PWD.Path }
$EngineDir = Join-Path $Root "engine"

if (-not $Task) {
  Write-Error "Usage: engine verify T-NNN"
  exit 2
}

$taskFile = Join-Path $EngineDir ("tasks\" + $Task + ".md")
if (-not (Test-Path $taskFile)) {
  Write-Error "Error: task card not found: $taskFile"
  exit 2
}

$evidenceDir = Join-Path $EngineDir ("evidence\" + $Task)
New-Item -ItemType Directory -Path $evidenceDir -Force | Out-Null

$passCount = 0; $failCount = 0; $skipCount = 0
Write-Output "[Engine System behavior verify] $Task"
Write-Output ""

foreach ($line in (Get-Content $taskFile -Encoding UTF8)) {
  if ($line -notmatch '^AC:') { continue }
  $acId = ""
  if ($line -match '^AC:\s*(AC-\d+)') { $acId = $Matches[1] }
  if (-not $acId) { continue }
  $verifyCmd = ""
  if ($line -match 'verify:\s*(.+?)\s*$') { $verifyCmd = $Matches[1] }
  if (-not $verifyCmd) {
    Write-Output "SKIP  $acId (no verify command)"
    $skipCount++; continue
  }
  Write-Output "-- $acId --"
  Write-Output "verify: $verifyCmd"
  Push-Location $Root
  $output = & cmd /c $verifyCmd 2>&1 | Out-String
  $rc = $LASTEXITCODE
  Pop-Location
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($output)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  $hashBytes = $sha.ComputeHash($bytes)
  $fp = ([System.BitConverter]::ToString($hashBytes) -replace '-', '').ToLower()
  $sha.Dispose()
  if ($rc -eq 0) {
    $status = "pass"; $passCount++
    Write-Output "PASS  (exit=0, fp=$($fp.Substring(0,12)))"
  } else {
    $status = "fail"; $failCount++
    Write-Output "FAIL  (exit=$rc, fp=$($fp.Substring(0,12)))"
    ($output -split "`n")[0..4] | ForEach-Object { Write-Output $_ }
  }
  $verifyEscaped = $verifyCmd -replace '\\', '\\' -replace '"', '\"'
  $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
  $json = '{"ac":"' + $acId + '","verify":"' + $verifyEscaped + '","status":"' + $status + '","exit":' + $rc + ',"fingerprint":"sha256:' + $fp + '","timestamp":"' + $ts + '"}'
  $json | Set-Content -Path (Join-Path $evidenceDir ($acId + ".json")) -Encoding UTF8
}

Write-Output ""
Write-Output "=========================================="
Write-Output "$Task`: $passCount pass, $failCount fail, $skipCount skip"
if ($failCount -ne 0) { exit 1 }
