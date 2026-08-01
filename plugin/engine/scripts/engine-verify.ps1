# Engine System - Behavior verifier (v6 S4)
#
# Executes task card AC verify commands, writes PASS/FAIL + output fingerprint
# to engine/evidence/T-NNN/AC-N.json. Machine-enforces N3 (done has evidence).
#
# Usage: pwsh -File engine/scripts/engine-verify.ps1 -Task T-NNN
# Safety: verify commands are declared in the task card; approving the card
# approves verify. User-run, not hook-automated.

param(
  [Parameter(Mandatory=$false)][string]$Task,
  [switch]$Preflight,
  [switch]$NoCov
)

$ErrorActionPreference = "Stop"
trap { [Console]::Error.WriteLine("[engine-verify] error: $_"); exit 1 }

$Root = $env:CLAUDE_PROJECT_DIR
if (-not $Root) { $Root = $PWD.Path }
$EngineDir = Join-Path $Root "engine"

if (-not $Task) {
  [Console]::Error.WriteLine("Usage: engine verify T-NNN")
  exit 2
}

# v6.10.0 (D-028/T-035): recursion guard. An AC verify command may itself
# invoke `pwsh -File engine/scripts/engine-verify.ps1 -Task T-NNN` (e.g.
# T-035 AC-2 dogfood). Without a guard, that would infinitely recurse (each
# call re-iterates ACs and re-spawns the recursive call). The guard env var
# carries the task ID being verified by the outer call; a recursive
# invocation for the SAME task exits 0 immediately. Other task IDs (e.g.
# behavior-verify test fixtures) run normally.
# Dead-code evidence (DEAD-CODE.json) is written by the outer (first) call only.
if ($env:ENGINE_VERIFY_RECURSE_GUARD -and ($env:ENGINE_VERIFY_RECURSE_GUARD -eq $Task)) {
  exit 0
}

$taskFile = Join-Path $EngineDir ("tasks\" + $Task + ".md")
if (-not (Test-Path $taskFile)) {
  [Console]::Error.WriteLine("Error: task card not found: $taskFile")
  exit 2
}

$evidenceDir = Join-Path $EngineDir ("evidence\" + $Task)
New-Item -ItemType Directory -Path $evidenceDir -Force | Out-Null

$passCount = 0; $failCount = 0; $blockedCount = 0; $skipCount = 0
# v6.12.1 (issue #11 E-1): tautology heuristics. Track how many PASS ACs have
# the empty-output fingerprint; if ALL of them do, the verify commands may be
# tautologies. WARN only - never changes the exit code.
$emptyFpHash = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
$emptyFpPass = 0
Write-Output "[Engine System behavior verify] $Task"
Write-Output ""

# Prefer real Git Bash; exclude WSL stub in System32 which emits garbled output.
# v6.14.0 (T-055, issue #12): expanded detection. Previous version only checked
# C:\Program Files\Git\bin\bash.exe + Get-Command bash (excluding WSL stub).
# Missed: 32-bit Program Files path, custom installs (Scoop/Chocolatey), and
# environments where `bash` on PATH is the WSL stub but Git Bash exists in the
# git install dir. New: also check Program Files (x86) + derive bash location
# from `git --exec-path` (git is on PATH in virtually every Windows Git install).
$bashExe = ""
# 1. Standard 64-bit Git for Windows path
$gitBash = "C:\Program Files\Git\bin\bash.exe"
if (Test-Path $gitBash) {
  $bashExe = $gitBash
}
# 2. 32-bit Program Files variant (T-055, issue #12)
if (-not $bashExe) {
  $gitBash86 = "${env:ProgramFiles(x86)}\Git\bin\bash.exe"
  if (-not $gitBash86 -or -not (Test-Path $gitBash86)) {
    $gitBash86 = "C:\Program Files (x86)\Git\bin\bash.exe"
  }
  if (Test-Path $gitBash86) { $bashExe = $gitBash86 }
}
# 3. Get-Command bash (exclude WSL stub in System32)
if (-not $bashExe) {
  $cmd = Get-Command bash -ErrorAction SilentlyContinue
  if ($cmd -and $cmd.Source -notlike "*\System32\bash.exe") {
    $bashExe = $cmd.Source
  }
}
# 4. Derive from git --exec-path (T-055, issue #12): git is virtually always on
# PATH if Git for Windows is installed. exec-path is like
# C:\Program Files\Git\mingw64\libexec\git-core; bash is 3 levels up + bin\.
if (-not $bashExe) {
  $gitCmd = Get-Command git -ErrorAction SilentlyContinue
  if ($gitCmd) {
    try {
      $execPath = & git --exec-path 2>$null
      if ($execPath) {
        $gitRoot = Split-Path (Split-Path (Split-Path $execPath))
        $derivedBash = Join-Path $gitRoot "bin\bash.exe"
        if (Test-Path $derivedBash) { $bashExe = $derivedBash }
      }
    } catch { }
  }
}

# Parse-AcDeclarations: Extract (ac_id, verify_cmd) pairs from a task card.
# Supports 4 AC declaration formats (D-037 / v6.17.0):
#   1. Single-line:  AC: AC-N <desc> | verify: <cmd>
#   2. Section:      ### AC-N: <title> + body's first verify: line
#   3. List item:    - AC-N: <desc> | verify: <cmd>  (or next line verify:)
#   4. Table row:    | AC-N | <desc> | verify: <cmd> |
# Returns: array of objects with AcId and VerifyCmd properties (VerifyCmd may be empty for SKIP).
# AC id regex: AC-[A-Za-z]*[0-9]+(\.[0-9]+)* (v6.12.1 A-3).
# Separators: | verify: / |verify: / -> verify: / ->verify: / line-start verify:
function Parse-AcDeclarations {
  param([string]$Path)
  $results = @()
  if (-not (Test-Path $Path)) { return $results }
  $sepArrow = [string][char]0x2192
  $acIdPattern = 'AC-[A-Za-z]*\d+(?:\.\d+)*'
  $sectionAc = ""
  $pendingAc = ""
  foreach ($line in (Get-Content $Path -Encoding UTF8)) {
    # Format 2: section heading "### AC-N: <title>"
    if ($line -match "^###\s+($acIdPattern)") {
      $sectionAc = $Matches[1]
      $pendingAc = ""
      continue
    }
    # Any other ### heading ends the current section
    if ($line -match '^###') { $sectionAc = "" }
    # In section: look for first verify: line
    if ($sectionAc) {
      if ($line -match '^\s*verify:\s*(.+?)\s*$') {
        $results += [PSCustomObject]@{ AcId = $sectionAc; VerifyCmd = $Matches[1] }
        $sectionAc = ""
        continue
      }
      continue
    }
    # Format 1: "AC: AC-N <desc> | verify: <cmd>"
    if ($line -match "^AC:\s*($acIdPattern)") {
      $acId = $Matches[1]
      $verifyCmd = ""
      if ($line -match "[|$sepArrow]\s*verify:\s*(.+?)\s*$") { $verifyCmd = $Matches[1] }
      $results += [PSCustomObject]@{ AcId = $acId; VerifyCmd = $verifyCmd }
      $pendingAc = ""
      continue
    }
    # Format 3: "- AC-N: <desc>" with same-line or next-line verify:
    if ($line -match "^-\s+($acIdPattern)") {
      $acId = $Matches[1]
      $verifyCmd = ""
      if ($line -match '\|\s*verify:\s*(.+?)\s*$') { $verifyCmd = $Matches[1] }
      if ($verifyCmd) {
        $results += [PSCustomObject]@{ AcId = $acId; VerifyCmd = $verifyCmd }
      } else {
        $pendingAc = $acId
      }
      continue
    }
    # Pending Format 3: next line "  verify: <cmd>"
    if ($pendingAc) {
      if ($line -match '^\s*verify:\s*(.+?)\s*$') {
        $results += [PSCustomObject]@{ AcId = $pendingAc; VerifyCmd = $Matches[1] }
        $pendingAc = ""
        continue
      }
      $results += [PSCustomObject]@{ AcId = $pendingAc; VerifyCmd = "" }
      $pendingAc = ""
    }
    # Format 4: "| AC-N | <desc> | verify: <cmd> |"
    if ($line -match "^\|\s*($acIdPattern)") {
      $acId = $Matches[1]
      $verifyCmd = ""
      if ($line -match 'verify:\s*([^|]+)') { $verifyCmd = $Matches[1].Trim() }
      $results += [PSCustomObject]@{ AcId = $acId; VerifyCmd = $verifyCmd }
      continue
    }
  }
  if ($pendingAc) { $results += [PSCustomObject]@{ AcId = $pendingAc; VerifyCmd = "" } }
  if ($sectionAc) { $results += [PSCustomObject]@{ AcId = $sectionAc; VerifyCmd = "" } }
  return $results
}

# v6.18.0 (D-038/T-066): 防漂移 — 证据多锚辅助函数
function Test-EngineMetadata {
  param([string]$Path)
  $metaPatterns = @(
    'engine/tasks/', 'engine/decisions/', 'engine/changes/', 'engine/evidence/',
    'engine/domains/', 'engine/archive/', 'engine/CONTEXT.md', 'engine/HANDOFF.md',
    'engine/ENGINE_MAP.md', 'engine/handoff-archive-', 'VERSION', 'engine/VERSION',
    'plugin/VERSION', 'plugin/manifest.json', 'CHANGELOG.md'
  )
  foreach ($p in $metaPatterns) {
    if ($Path -like "$p*" -or $Path -eq $p) { return $true }
  }
  return $false
}

function Collect-CodeFingerprint {
  param([string]$TaskFile, [string]$Root)
  $codeFingerprint = @{}
  $wsSnapshot = @()
  $content = Get-Content -Path $TaskFile -Encoding UTF8
  $inWs = $false
  foreach ($line in $content) {
    if ($line -match '^## WRITE-SET') { $inWs = $true; continue }
    if ($line -match '^## ') { if ($inWs) { break } else { continue } }
    if (-not $inWs) { continue }
    if ($line -match '^-\s+(.+)') {
      $path = $Matches[1].Trim()
      if (Test-EngineMetadata -Path $path) { continue }
      $fullPath = Join-Path $Root $path
      if (-not (Test-Path $fullPath -PathType Leaf)) { continue }
      $wsSnapshot += $path
    }
  }
  $missing = @()
  foreach ($path in $wsSnapshot) {
    $blob = & git -C $Root ls-files -s $path 2>$null
    if ($blob -match '\s([0-9a-f]{40})\s') {
      $codeFingerprint[$path] = $Matches[1]
    } else {
      $missing += $path
    }
  }
  if ($missing.Count -gt 0) {
    Write-Error "[engine-verify] FAIL: WRITE-SET 代码文件未 git add 进 index,无法计算 code_fingerprint:`n  $($missing -join "`n  ")`n请先 git add 这些文件再跑 verify(D-038a 前置要求)"
    exit 1
  }
  return @{ CodeFingerprint = $codeFingerprint; WsSnapshot = $wsSnapshot }
}

function Build-CodeFingerprintJson {
  param([hashtable]$Hash)
  $keys = $Hash.Keys | Sort-Object
  $parts = @()
  foreach ($k in $keys) {
    $escK = $k -replace '\\', '\\' -replace '"', '\"'
    $parts += "`"$escK`":`"$($Hash[$k])`""
  }
  return '{' + ($parts -join ',') + '}'
}

function Build-WsSnapshotJson {
  param([array]$Arr)
  $sorted = $Arr | Sort-Object
  $parts = @()
  foreach ($p in $sorted) {
    $esc = $p -replace '\\', '\\' -replace '"', '\"'
    $parts += "`"$esc`""
  }
  return '[' + ($parts -join ',') + ']'
}

# v6.24.0 (T-078 / issue #25): acceptance preflight classification. The
# frozen command always runs first; these helpers classify its output and may
# run only the explicitly declared (or pytest --no-cov) behavior diagnostic.
function Escape-JsonString {
  param([AllowNull()][string]$Value)
  if ($null -eq $Value) { return "" }
  return $Value.Replace('\', '\\').Replace('"', '\"').Replace("`r", '').Replace("`n", ' ')
}

$verifyArgv = if ($env:ENGINE_CLI_ENTRYPOINT) { $env:ENGINE_CLI_ENTRYPOINT } else { "engine-verify.ps1 -Task $Task" }
$verifyArgvEscaped = Escape-JsonString -Value $verifyArgv
[Environment]::SetEnvironmentVariable('ENGINE_CLI_ENTRYPOINT', $null, 'Process')

function Get-EnvironmentStatus {
  param([string]$Output)
  if ($Output -match '(?im)ModuleNotFoundError|No module named|ImportError:|command not found|not recognized as an internal|No such file or directory|cannot find.*(python|pytest|executable)|executable.*not found|venv.*not found|failed to activate|Could not import') {
    return 'blocked'
  }
  return 'ok'
}

function Get-CoverageStatus {
  param([string]$Output)
  if ($Output -match '(?im)required test coverage.*not reached|coverage.*(fail[- ]under|below.*threshold|threshold.*not reached)|fail[- ]under.*coverage|coverage.*minimum.*not met') {
    return 'failed_threshold'
  }
  return 'not_applicable'
}

function Split-PreflightCommand {
  param([string]$Command)
  $commandPart = $Command.Trim()
  $coveragePolicy = 'auto'
  $behaviorCommand = ''

  $behaviorMarker = [regex]::Match($commandPart, '(?is)\s*\|\s*behavior:\s*')
  if ($behaviorMarker.Success) {
    $behaviorCommand = $commandPart.Substring($behaviorMarker.Index + $behaviorMarker.Length).Trim()
    $commandPart = $commandPart.Substring(0, $behaviorMarker.Index).Trim()
    $behaviorCommand = [regex]::Replace($behaviorCommand, '(?is)\s*\|\s*coverage:.*$', '').Trim()
  }

  $coverageMarker = [regex]::Match($commandPart, '(?is)\s*\|\s*coverage:\s*')
  if ($coverageMarker.Success) {
    $coveragePolicy = $commandPart.Substring($coverageMarker.Index + $coverageMarker.Length).Trim()
    $commandPart = $commandPart.Substring(0, $coverageMarker.Index).Trim()
  }
  if ($NoCov) {
    $coveragePolicy = 'no-cov'
    $commandPart = Add-NoCov -Command $commandPart
  } elseif ($commandPart -match '(?i)(^|\s)--no-cov(\s|$)') {
    $coveragePolicy = 'no-cov'
  }

  return [PSCustomObject]@{
    Command = $commandPart
    CoveragePolicy = if ($coveragePolicy) { $coveragePolicy } else { 'auto' }
    BehaviorCommand = $behaviorCommand
  }
}

function Add-NoCov {
  param([string]$Command)
  if ($Command -match '(?i)(^|\s)--no-cov(\s|$)') { return $Command }
  if ($Command -match '(?i)(^|\s)pytest(\s|$)') { return "$Command --no-cov" }
  return $Command
}

function Invoke-VerifyCommand {
  param([string]$Command, [string]$Root, [string]$TaskId, [string]$BashExe)
  $output = ''
  $exitCode = 1
  Push-Location $Root
  try {
    $env:ENGINE_VERIFY_RECURSE_GUARD = $TaskId
    try {
      if ($BashExe) {
        $output = & $BashExe -lc $Command 2>&1 | Out-String
      } else {
        Write-Warning "Git Bash not found; falling back to cmd /c (bash syntax may fail)" 2>&1
        $output = & cmd /c $Command 2>&1 | Out-String
      }
      $exitCode = $LASTEXITCODE
      if ($null -eq $exitCode) { $exitCode = 0 }
    } catch {
      $output = ($_ | Out-String)
      $exitCode = 1
    }
  } finally {
    [Environment]::SetEnvironmentVariable('ENGINE_VERIFY_RECURSE_GUARD', $null, 'Process')
    Pop-Location
  }
  return [PSCustomObject]@{ Output = [string]$output; ExitCode = [int]$exitCode }
}

function Write-EvidenceManifest {
  param([string]$EvDir, [string]$Commit)
  $files = Get-ChildItem -Path $EvDir -File | Where-Object { $_.Name -ne 'MANIFEST.json' -and ($_.Name -like '*.json' -or $_.Name -eq 'checkpoint.md') } | Sort-Object Name
  $manifestContent = ""
  $filesDict = @{}
  foreach ($f in $files) {
    $h = (Get-FileHash -Path $f.FullName -Algorithm SHA256).Hash.ToLower()
    $manifestContent += "$($f.Name):$h`n"
    $filesDict[$f.Name] = $h
  }
  $manifestBytes = [System.Text.Encoding]::UTF8.GetBytes($manifestContent)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  $manifestHash = ([System.BitConverter]::ToString($sha.ComputeHash($manifestBytes)) -replace '-', '').ToLower()
  $sha.Dispose()
  $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
  $filesJson = Build-CodeFingerprintJson -Hash $filesDict
  $json = '{"evidence_manifest_sha256":"sha256:' + $manifestHash + '","generated":"' + $ts + '","writer":"engine-verify","commit":"' + $Commit + '","files":' + $filesJson + '}'
  $json | Set-Content -Path (Join-Path $EvDir "MANIFEST.json") -Encoding UTF8
}

# v6.18.0 (D-038/T-066): 收集 code_fingerprint + 前置 git add 检查
$verifiedCommit = & git -C $Root rev-parse HEAD 2>$null
if (-not $verifiedCommit) { $verifiedCommit = "unknown" }
if ($Preflight) {
  # Preflight is intended to run before implementation and before WRITE-SET
  # files are staged. Do not let code-fingerprint enforcement mask the AC
  # command's environment/coverage result.
  $codeFpJson = '{}'
  $wsSnapJson = '[]'
} else {
  $cfResult = Collect-CodeFingerprint -TaskFile $taskFile -Root $Root
  $codeFpJson = Build-CodeFingerprintJson -Hash $cfResult.CodeFingerprint
  $wsSnapJson = Build-WsSnapshotJson -Arr $cfResult.WsSnapshot
}

foreach ($ac in (Parse-AcDeclarations -Path $taskFile)) {
  $acId = $ac.AcId
  $verifyCmd = $ac.VerifyCmd
  if (-not $verifyCmd) {
    Write-Output "SKIP  $acId (no verify command)"
    $skipCount++; continue
  }
  Write-Output "-- $acId --"
  Write-Output "verify: $verifyCmd"
  $commandParts = Split-PreflightCommand -Command $verifyCmd
  $executionCmd = $commandParts.Command
  if (-not $executionCmd) { $executionCmd = $verifyCmd }
  $coveragePolicy = $commandParts.CoveragePolicy
  $explicitBehaviorCommand = $commandParts.BehaviorCommand
  # v6.12.1 (issue #11 E-1): a verify command that checks this card's own
  # evidence directory proves only that a file was written, not behavior.
  if ($verifyCmd -like "*engine/evidence/$Task/*") {
    Write-Output "WARN suspicious verify (self-referential evidence path): $acId"
  }
  $runResult = Invoke-VerifyCommand -Command $executionCmd -Root $Root -TaskId $Task -BashExe $bashExe
  $output = $runResult.Output
  $rc = $runResult.ExitCode
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($output)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  $hashBytes = $sha.ComputeHash($bytes)
  $fp = ([System.BitConverter]::ToString($hashBytes) -replace '-', '').ToLower()
  $sha.Dispose()
  $environmentStatus = 'ok'
  $coverageStatus = 'not_applicable'
  $behaviorExitJson = [string]$rc
  $behaviorStatus = 'pass'
  $behaviorOutputFpJson = 'null'
  if ($rc -ne 0) {
    $environmentStatus = Get-EnvironmentStatus -Output $output
    $coverageStatus = Get-CoverageStatus -Output $output
  } elseif ($coveragePolicy -eq 'no-cov') {
    $coverageStatus = 'disabled'
  }

  if ($rc -eq 0) {
    $status = "pass"; $passCount++
    $behaviorStatus = 'pass'
    if ($fp -eq $emptyFpHash) { $emptyFpPass++ }
    Write-Output "PASS  (exit=0, fp=$($fp.Substring(0,12)))"
  } elseif ($Preflight -and $coverageStatus -eq 'failed_threshold') {
    $behaviorCommand = $explicitBehaviorCommand
    if (-not $behaviorCommand) { $behaviorCommand = Add-NoCov -Command $executionCmd }
    if ($behaviorCommand -and $behaviorCommand -ne $executionCmd) {
      $behaviorResult = Invoke-VerifyCommand -Command $behaviorCommand -Root $Root -TaskId $Task -BashExe $bashExe
      $behaviorOutput = $behaviorResult.Output
      $behaviorRc = $behaviorResult.ExitCode
      $behaviorBytes = [System.Text.Encoding]::UTF8.GetBytes($behaviorOutput)
      $behaviorSha = [System.Security.Cryptography.SHA256]::Create()
      $behaviorHashBytes = $behaviorSha.ComputeHash($behaviorBytes)
      $behaviorFp = ([System.BitConverter]::ToString($behaviorHashBytes) -replace '-', '').ToLower()
      $behaviorSha.Dispose()
      $behaviorOutputFpJson = '"sha256:' + $behaviorFp + '"'
      $behaviorExitJson = [string]$behaviorRc
      if ($behaviorRc -eq 0) {
        $behaviorStatus = 'pass'; $status = 'blocked'; $blockedCount++
        Write-Output "BLOCKED (coverage threshold in frozen command; behavior diagnostic passed with --no-cov)"
      } else {
        $behaviorStatus = 'fail'; $status = 'fail'; $failCount++
        Write-Output "FAIL  (coverage threshold plus behavior diagnostic exit=$behaviorRc)"
        ($behaviorOutput -split "`n")[0..4] | ForEach-Object { Write-Output $_ }
      }
    } else {
      $behaviorExitJson = 'null'; $behaviorStatus = 'not_run'
      $status = 'blocked'; $blockedCount++
      Write-Output "BLOCKED (coverage threshold; no pytest --no-cov diagnostic available)"
    }
  } elseif ($Preflight -and $explicitBehaviorCommand -and $environmentStatus -eq 'blocked') {
    $behaviorResult = Invoke-VerifyCommand -Command $explicitBehaviorCommand -Root $Root -TaskId $Task -BashExe $bashExe
    $behaviorOutput = $behaviorResult.Output
    $behaviorRc = $behaviorResult.ExitCode
    $behaviorBytes = [System.Text.Encoding]::UTF8.GetBytes($behaviorOutput)
    $behaviorSha = [System.Security.Cryptography.SHA256]::Create()
    $behaviorHashBytes = $behaviorSha.ComputeHash($behaviorBytes)
    $behaviorFp = ([System.BitConverter]::ToString($behaviorHashBytes) -replace '-', '').ToLower()
    $behaviorSha.Dispose()
    $behaviorOutputFpJson = '"sha256:' + $behaviorFp + '"'
    $behaviorExitJson = [string]$behaviorRc
    if ($behaviorRc -eq 0) { $behaviorStatus = 'pass' } else { $behaviorStatus = 'fail' }
    $status = 'blocked'; $blockedCount++
    Write-Output "BLOCKED (declared environment unavailable; explicit behavior diagnostic exit=$behaviorRc)"
  } elseif ($Preflight -and $environmentStatus -eq 'blocked') {
    $behaviorExitJson = 'null'; $behaviorStatus = 'not_run'
    $status = 'blocked'; $blockedCount++
    Write-Output "BLOCKED (command_exit=$rc, environment dependency unavailable)"
    ($output -split "`n")[0..4] | ForEach-Object { Write-Output $_ }
  } elseif ($Preflight -and $explicitBehaviorCommand) {
    $behaviorResult = Invoke-VerifyCommand -Command $explicitBehaviorCommand -Root $Root -TaskId $Task -BashExe $bashExe
    $behaviorOutput = $behaviorResult.Output
    $behaviorRc = $behaviorResult.ExitCode
    $behaviorBytes = [System.Text.Encoding]::UTF8.GetBytes($behaviorOutput)
    $behaviorSha = [System.Security.Cryptography.SHA256]::Create()
    $behaviorHashBytes = $behaviorSha.ComputeHash($behaviorBytes)
    $behaviorFp = ([System.BitConverter]::ToString($behaviorHashBytes) -replace '-', '').ToLower()
    $behaviorSha.Dispose()
    $behaviorOutputFpJson = '"sha256:' + $behaviorFp + '"'
    $behaviorExitJson = [string]$behaviorRc
    if ($behaviorRc -eq 0) { $behaviorStatus = 'pass' } else { $behaviorStatus = 'fail' }
    $status = 'fail'; $failCount++
    Write-Output "FAIL  (command_exit=$rc, behavior diagnostic exit=$behaviorRc)"
  } else {
    $status = "fail"; $failCount++
    $behaviorStatus = 'fail'
    Write-Output "FAIL  (exit=$rc, fp=$($fp.Substring(0,12)))"
    ($output -split "`n")[0..4] | ForEach-Object { Write-Output $_ }
  }
  $verifyEscaped = Escape-JsonString -Value $verifyCmd
  $executionEscaped = Escape-JsonString -Value $executionCmd
  $policyEscaped = Escape-JsonString -Value $coveragePolicy
  $preflightJson = $Preflight.IsPresent.ToString().ToLower()
  $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
  $json = '{"ac":"' + $acId + '","verify":"' + $verifyEscaped + '","execution_command":"' + $executionEscaped + '","status":"' + $status + '","exit":' + $rc + ',"command_exit":' + $rc + ',"behavior_exit":' + $behaviorExitJson + ',"behavior_status":"' + $behaviorStatus + '","environment_status":"' + $environmentStatus + '","coverage_status":"' + $coverageStatus + '","coverage_policy":"' + $policyEscaped + '","preflight":' + $preflightJson + ',"output_fingerprint":"sha256:' + $fp + '","behavior_output_fingerprint":' + $behaviorOutputFpJson + ',"code_fingerprint":' + $codeFpJson + ',"write_set_snapshot":' + $wsSnapJson + ',"verified_against_commit":"' + $verifiedCommit + '","write_provenance":{"writer":"engine-verify","commit":"' + $verifiedCommit + '","timestamp":"' + $ts + '","argv":"' + $verifyArgvEscaped + '"},"timestamp":"' + $ts + '"}'
  $json | Set-Content -Path (Join-Path $evidenceDir ($acId + ".json")) -Encoding UTF8

  # v6.9.0 (D-028/T-034): on AC PASS, write a line to checkpoint.md so
  # SessionStart can re-anchor from AC-level completion state (priority 1
  # in the re-anchor chain, see contract/src/20-file-templates.md FILE 15).
  # verify is the only writer of checkpoint.md; agents write progress.md.
  # v6.11.2 (T-039): dedup - replace existing AC-N line (update timestamp),
  # append if new AC-N. Original append-without-dedup caused unbounded growth.
  if ($status -eq "pass") {
    $checkpoint = Join-Path $evidenceDir "checkpoint.md"
    if (-not (Test-Path $checkpoint)) {
      $header = "# Checkpoint - $Task`r`n> Last updated: $ts by engine-verify | AC-level recovery anchor (compressed), see contract/src/20-file-templates.md FILE 15`r`n`r`n## Completed AC`r`n"
      Set-Content -Path $checkpoint -Value $header -Encoding UTF8
    }
    $summary = ($verifyCmd -replace '\s+', ' ').Trim()
    if ($summary.Length -gt 80) { $summary = $summary.Substring(0, 80) }
    $line = "- [x] $acId $summary - evidence/$acId.json PASS @ $ts"
    # Dedup: remove existing AC-N line(s) if any, then append fresh line.
    $existing = Get-Content -Path $checkpoint -Encoding UTF8
    $filtered = $existing | Where-Object { $_ -notmatch "^- \[x\] $acId " }
    Set-Content -Path $checkpoint -Value $filtered -Encoding UTF8
    Add-Content -Path $checkpoint -Value $line -Encoding UTF8
  }
}

# v6.18.0 (D-038/T-066): 写 MANIFEST.json(evidence 完整性自证)
Write-EvidenceManifest -EvDir $evidenceDir -Commit $verifiedCommit

# v6.10.0 (D-028/T-035): Dead code detection - runs AFTER all AC verify commands.
# Self-checks linter availability (PSScriptAnalyzer for .ps1; shellcheck twin
# is in engine-verify.sh), scans WRITE-SET-touched .ps1/.sh files, runs reverse
# call-site scan, and emits evidence/T-NNN/DEAD-CODE.json + COPY-PASTE.json.
# When linter unavailable -> linter field = "grep-fallback"; when available
# -> real linter name recorded. Architect reviews warn_count > 0 entries and
# marks exempt:true or sets exempt_all:true (D-028 section 9).
function Invoke-DeadCodeDetection {
  param([string]$TaskId, [string]$EvidenceDir, [string]$TaskFile)
  if (-not (Test-Path $TaskFile)) { return }

  # Collect WRITE-SET-touched .ps1 / .sh files (concrete paths only, skip globs).
  $content = Get-Content -Raw -Path $TaskFile -Encoding UTF8 -ErrorAction SilentlyContinue
  if (-not $content) { return }
  $writeSetLine = ""
  if ($content -match '(?m)^WRITE-SET:\s*(.*)$') { $writeSetLine = $Matches[1].Trim() }
  if ([string]::IsNullOrEmpty($writeSetLine)) { return }

  $shFiles = @()
  $ps1Files = @()
  foreach ($wsPath in ($writeSetLine -split ',')) {
    $p = $wsPath.Trim()
    if ([string]::IsNullOrEmpty($p)) { continue }
    if ($p -like '*\*' -or $p -like '*/**' -or $p -like '*\*' -or $p -like '*/*') { continue }
    if ($p -like '*.ps1' -and (Test-Path (Join-Path $Root $p))) { $ps1Files += $p }
    if ($p -like '*.sh' -and (Test-Path (Join-Path $Root $p))) { $shFiles += $p }
  }
  if ($shFiles.Count -eq 0 -and $ps1Files.Count -eq 0) { return }

  # Self-check linter availability: Get-Module -ListAvailable PSScriptAnalyzer.
  # If unavailable, attempt Install-Module -Scope CurrentUser -Force -AllowClobber
  # bootstrap (D-028 Open Question #4). If still unavailable, linter = "grep-fallback".
  $linterPs1 = "grep-fallback"
  $psaAvailable = $false
  if (Get-Module -ListAvailable PSScriptAnalyzer -ErrorAction SilentlyContinue) {
    $psaAvailable = $true
    $linterPs1 = "PSScriptAnalyzer"
  } else {
    try {
      Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
      if (Get-Module -ListAvailable PSScriptAnalyzer -ErrorAction SilentlyContinue) {
        $psaAvailable = $true
        $linterPs1 = "PSScriptAnalyzer"
      }
    } catch {
      # Install failed (no PSGallery, offline, etc.); stay grep-fallback.
      $linterPs1 = "grep-fallback"
    }
  }

  # Overall linter label: prefer PSScriptAnalyzer if .ps1 files present;
  # if only .sh files (no .ps1), the .sh twin handles shellcheck. Mark
  # as "grep-fallback" for the .sh-only case when called from PowerShell
  # (PowerShell cannot directly invoke shellcheck).
  $linterOverall = $linterPs1
  if ($ps1Files.Count -eq 0 -and $shFiles.Count -gt 0) {
    $linterOverall = "grep-fallback"
  }

  $dcEntries = @()
  $warnCount = 0
  $exemptCount = 0

  # Run PSScriptAnalyzer (Invoke-ScriptAnalyzer) on .ps1 files (if available).
  if ($psaAvailable -and $ps1Files.Count -gt 0) {
    try {
      Import-Module PSScriptAnalyzer -ErrorAction Stop
      foreach ($f in $ps1Files) {
        $full = Join-Path $Root $f
        $results = Invoke-ScriptAnalyzer -Path $full -Severity Warning,Error -ErrorAction SilentlyContinue
        foreach ($r in $results) {
          $msgEscaped = ($r.Message -replace '\\', '\\' -replace '"', '\"')
          $dcEntries += [PSCustomObject]@{
            type = "linter"
            file = $f
            line = $r.Line
            severity = $r.Severity
            message = $msgEscaped
            exempt = $false
            exempt_reason = $null
          }
          $warnCount++
        }
      }
    } catch {
      # Invoke-ScriptAnalyzer failed; stay silent (linter label already set).
    }
  }

  # reverse-call-site scan (ReverseCallSite): for each function defined in
  # WRITE-SET .ps1 files, grep the whole repo for call sites. If only the
  # definition file matches, the function is a dead-code candidate.
  foreach ($f in $ps1Files) {
    $full = Join-Path $Root $f
    $lines = Get-Content -Path $full -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $lines) { continue }
    $funcs = @()
    foreach ($l in $lines) {
      if ($l -match '^(?:function\s+)([A-Za-z_][A-Za-z0-9_]*)') { $funcs += $Matches[1] }
      elseif ($l -match '^\s*function\s+([A-Za-z_][A-Za-z0-9_]*)') { $funcs += $Matches[1] }
    }
    $funcs = $funcs | Sort-Object -Unique
    foreach ($fn in $funcs) {
      # Skip very common / generic function names (high false-positive rate).
      switch ($fn) {
        'Main' { continue }
        'Write-Fail' { continue }
        'Write-Warn' { continue }
        'Write-Pass' { continue }
        'Test-Path' { continue }
        'Get-Content' { continue }
        default { }
      }
      # Search repo (excluding the definition file) for occurrences.
      $hits = @()
      try {
        $grepFiles = Get-ChildItem -Path $Root -Recurse -File -Include '*.sh','*.ps1','*.md','*.json' -ErrorAction SilentlyContinue |
          Where-Object { $_.FullName -notlike '*\.git\*' -and $_.FullName -notlike '*\archive\*' -and $_.FullName -notlike '*\node_modules\*' -and $_.FullName -notlike '*\.workbuddy\*' }
        foreach ($gf in $grepFiles) {
          if ($gf.FullName -eq $full) { continue }
          $match = Select-String -Path $gf.FullName -Pattern "\b$([regex]::Escape($fn))\b" -List -ErrorAction SilentlyContinue
          if ($match) { $hits += $gf.FullName; if ($hits.Count -ge 5) { break } }
        }
      } catch { }
      if ($hits.Count -eq 0) {
        $dcEntries += [PSCustomObject]@{
          type = "reverse-call-site"
          identifier = $fn
          referenced_in = @()
          exempt = $false
          exempt_reason = $null
        }
        $warnCount++
      }
    }
  }

  # jscpd copy-paste detection (D-028 section 10 mechanism B). If jscpd
  # unavailable, skip + WARN (jscpd_available=false in COPY-PASTE.json).
  $jscpdAvailable = $false
  $jscpdCmd = Get-Command jscpd -ErrorAction SilentlyContinue
  if ($jscpdCmd) {
    $jscpdAvailable = $true
  } else {
    $npxCmd = Get-Command npx -ErrorAction SilentlyContinue
    if ($npxCmd) {
      try {
        & npx --no-install jscpd --version 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { $jscpdAvailable = $true }
      } catch { }
    }
  }

  # Write DEAD-CODE.json.
  $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
  $jsonFile = Join-Path $EvidenceDir "DEAD-CODE.json"
  $entriesJson = ""
  for ($i = 0; $i -lt $dcEntries.Count; $i++) {
    $e = $dcEntries[$i]
    if ($e.type -eq "linter") {
      $entryStr = "    {`"type`":`"linter`",`"file`":`"$($e.file)`",`"line`":$($e.line),`"severity`":`"$($e.severity)`",`"message`":`"$($e.message)`",`"exempt`":false,`"exempt_reason`":null}"
    } else {
      $entryStr = "    {`"type`":`"reverse-call-site`",`"identifier`":`"$($e.identifier)`",`"referenced_in`":[],`"exempt`":false,`"exempt_reason`":null}"
    }
    if ($i -lt $dcEntries.Count - 1) { $entryStr += "," }
    $entriesJson += $entryStr + "`n"
  }
  $json = "{`n"
  $json += "  `"task`": `"$TaskId`",`n"
  $json += "  `"timestamp`": `"$ts`",`n"
  $json += "  `"exempt_all`": false,`n"
  $json += "  `"exempt_reason`": null,`n"
  $json += "  `"linter`": `"$linterOverall`",`n"
  $json += "  `"entries`": [`n$entriesJson  ],`n"
  $json += "  `"summary`": {`n"
  $json += "    `"warn_count`": $warnCount,`n"
  $json += "    `"exempt_count`": $exemptCount`n"
  $json += "  }`n"
  $json += "}`n"
  $json | Set-Content -Path $jsonFile -Encoding UTF8 -NoNewline

  # Write COPY-PASTE.json (jscpd delegated, D-028 section 10 mechanism B).
  $cpFile = Join-Path $EvidenceDir "COPY-PASTE.json"
  $cpJson = "{`n"
  $cpJson += "  `"task`": `"$TaskId`",`n"
  $cpJson += "  `"timestamp`": `"$ts`",`n"
  $cpJson += "  `"tool`": `"jscpd`",`n"
  $cpJson += "  `"jscpd_available`": $($jscpdAvailable.ToString().ToLower()),`n"
  $cpJson += "  `"duplications`": [],`n"
  $cpJson += "  `"warn_count`": 0`n"
  $cpJson += "}`n"
  $cpJson | Set-Content -Path $cpFile -Encoding UTF8 -NoNewline
}

Invoke-DeadCodeDetection -TaskId $Task -EvidenceDir $evidenceDir -TaskFile $taskFile

Write-Output ""
Write-Output "=========================================="
Write-Output "$Task`: $passCount pass, $failCount fail, $blockedCount blocked, $skipCount skip"
# v6.12.1 (issue #11 A-1): all-SKIP is a parse failure, not a clean result.
$totalAcs = $passCount + $failCount + $skipCount
if ($totalAcs -gt 0 -and $passCount -eq 0 -and $failCount -eq 0) {
  [Console]::Error.WriteLine("ERROR: $totalAcs ACs declared but no parseable verify command was found.")
  [Console]::Error.WriteLine("4 accepted AC spellings; see contract/src/20-file-templates.md FILE 15")
  [Console]::Error.WriteLine("This is a parse failure, not a clean result.")
  exit 3
}
if ($passCount -gt 0 -and $emptyFpPass -eq $passCount) {
  Write-Output "WARN all PASS fingerprints are the empty-string hash - verify commands may be tautologies"
}
if ($failCount -ne 0 -or $blockedCount -ne 0) { exit 1 }
