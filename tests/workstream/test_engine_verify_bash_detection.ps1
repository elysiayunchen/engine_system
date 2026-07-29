# Test: engine-verify.ps1 Git Bash detection (T-055, v6.14.0, issue #12)
#
# Validates that the bash detection block in engine-verify.ps1 L54-97 covers:
#   1. Standard 64-bit path (regression - existing behavior preserved)
#   2. 32-bit Program Files (x86) path
#   3. git --exec-path derivation
#
# This is a source-level test: it reads engine-verify.ps1 and verifies the
# detection branches exist and are structurally sound. It does NOT invoke
# engine-verify.ps1 itself (which would require a full task card setup).

$ErrorActionPreference = "Stop"

Write-Output "[test_engine_verify_bash_detection.ps1] T-055 bash detection"

$Pass = 0; $Fail = 0
function Ok($msg) { Write-Output "  PASS $msg"; $script:Pass++ }
function Bad($msg) { Write-Output "  FAIL $msg"; $script:Fail++ }

$Root = $env:CLAUDE_PROJECT_DIR
if (-not $Root) { $Root = $PWD.Path }
$verifyScript = Join-Path $Root "engine\scripts\engine-verify.ps1"

if (-not (Test-Path $verifyScript)) {
  Write-Output "FAIL engine-verify.ps1 not found at $verifyScript"
  exit 1
}

$content = Get-Content -Path $verifyScript -Raw -Encoding UTF8

# ===========================================================================
# S1 (AC-3): standard 64-bit path detection regression
# ===========================================================================
Write-Output "S1: standard 64-bit path detection (regression)"
if ($content -match 'C:\\Program Files\\Git\\bin\\bash\.exe') {
  Ok "S1 standard path present"
} else {
  Bad "S1 standard path missing (regression)"
}

# The standard path should be checked via Test-Path (not just string compare)
if ($content -match 'if\s*\(Test-Path\s*\$gitBash\)') {
  Ok "S1 Test-Path check preserved"
} else {
  Bad "S1 Test-Path check missing"
}

# ===========================================================================
# S2 (AC-1): 32-bit Program Files (x86) path
# ===========================================================================
Write-Output "S2: 32-bit Program Files (x86) path detection"
if ($content -match 'Program Files\s*\(x86\)\\Git\\bin\\bash\.exe') {
  Ok "S2 (x86) path present"
} else {
  Bad "S2 (x86) path missing"
}

# The (x86) path should use env var with fallback to hardcoded
if ($content -match 'env:ProgramFiles\(x86\)') {
  Ok "S2 env:ProgramFiles(x86) used"
} else {
  Bad "S2 env:ProgramFiles(x86) missing"
}

# ===========================================================================
# S3 (AC-2): git --exec-path derivation
# ===========================================================================
Write-Output "S3: git --exec-path derivation"
if ($content -match 'git\s+--exec-path') {
  Ok "S3 git --exec-path invocation present"
} else {
  Bad "S3 git --exec-path invocation missing"
}

# The derivation should use Split-Path to go up from exec-path
if ($content -match 'Split-Path.*Split-Path.*Split-Path.*\$execPath') {
  Ok "S3 3-level Split-Path from execPath"
} else {
  Bad "S3 Split-Path chain missing"
}

# The derived bash should be joined with bin\bash.exe
if ($content -match 'Join-Path\s*\$gitRoot.*bin\\bash\.exe') {
  Ok "S3 derived bash path construction"
} else {
  Bad "S3 derived bash path missing"
}

# The derivation should be wrapped in try/catch (git not found is OK).
# Search for '& git --exec-path' (code invocation, not comment mention) and
# check a window around it for try/catch.
$execCodeIdx = $content.IndexOf('& git --exec-path')
$windowStart = [Math]::Max(0, $execCodeIdx - 200)
$windowLen = [Math]::Min(500, $content.Length - $windowStart)
$window = $content.Substring($windowStart, $windowLen)
if ($window -match 'try' -and $window -match 'catch') {
  Ok "S3 try/catch wrapping"
} else {
  Bad "S3 try/catch wrapping missing"
}

# ===========================================================================
# S4: Get-Command bash fallback still present (regression)
# ===========================================================================
Write-Output "S4: Get-Command bash fallback (regression)"
if ($content -match 'Get-Command\s+bash') {
  Ok "S4 Get-Command bash preserved"
} else {
  Bad "S4 Get-Command bash missing (regression)"
}

# WSL stub exclusion still present
if ($content -match 'System32\\bash\.exe') {
  Ok "S4 WSL stub exclusion preserved"
} else {
  Bad "S4 WSL stub exclusion missing"
}

# ===========================================================================
# S5: detection order (standard -> x86 -> Get-Command -> git --exec-path)
# ===========================================================================
Write-Output "S5: detection order"
# Search in CODE lines (starting with $ or if), not comments. The comment block
# at L54-60 mentions all paths, so IndexOf on raw content hits comments first.
# Instead, find the first CODE occurrence of each marker.
$codeLines = $content -split "`n" | Where-Object { $_ -match '^\s*(\$|if\s)' }
$codeJoined = $codeLines -join "`n"
$stdIdx = $codeJoined.IndexOf('C:\Program Files\Git\bin\bash.exe')
$x86Idx = $codeJoined.IndexOf('Program Files (x86)\Git')
$gcIdx = $codeJoined.IndexOf('Get-Command bash')
$execIdx = $codeJoined.IndexOf('git --exec-path')
if ($stdIdx -ge 0 -and $x86Idx -gt $stdIdx -and $gcIdx -gt $x86Idx -and $execIdx -gt $gcIdx) {
  Ok "S5 detection order correct (std -> x86 -> Get-Command -> exec-path)"
} else {
  Bad "S5 detection order incorrect (std=$stdIdx x86=$x86Idx gc=$gcIdx exec=$execIdx)"
}

Write-Output ""
Write-Output "=========================================="
Write-Output "T-055 bash detection: $Pass pass, $Fail fail"
if ($Fail -ne 0) { exit 1 }
