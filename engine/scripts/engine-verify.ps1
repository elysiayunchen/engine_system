# Engine System - Behavior verifier (v6 S4)
#
# Executes task card AC verify commands, writes PASS/FAIL + output fingerprint
# to engine/evidence/T-NNN/AC-N.json. Machine-enforces N3 (done has evidence).
#
# Usage: pwsh -File engine/scripts/engine-verify.ps1 -Task T-NNN
# Safety: verify commands are declared in the task card; approving the card
# approves verify. User-run, not hook-automated.

param([Parameter(Mandatory=$false)][string]$Task)

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

$passCount = 0; $failCount = 0; $skipCount = 0
Write-Output "[Engine System behavior verify] $Task"
Write-Output ""

# Prefer real Git Bash; exclude WSL stub in System32 which emits garbled output.
$bashExe = ""
$gitBash = "C:\Program Files\Git\bin\bash.exe"
if (Test-Path $gitBash) {
  $bashExe = $gitBash
} else {
  $cmd = Get-Command bash -ErrorAction SilentlyContinue
  if ($cmd -and $cmd.Source -notlike "*\System32\bash.exe") {
    $bashExe = $cmd.Source
  }
}

foreach ($line in (Get-Content $taskFile -Encoding UTF8)) {
  if ($line -notmatch '^AC:') { continue }
  $acId = ""
  if ($line -match '^AC:\s*(AC-\d+(?:\.\d+)*)') { $acId = $Matches[1] }
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
  # v6.10.0 (T-035): set ENGINE_VERIFY_RECURSE_GUARD=<task> so any AC verify
  # that recursively invokes engine-verify for the SAME task exits 0
  # immediately (no infinite loop). Other task IDs (e.g. test fixtures) run
  # normally.
  $env:ENGINE_VERIFY_RECURSE_GUARD = $Task
  if ($bashExe) {
    $output = & $bashExe -lc $verifyCmd 2>&1 | Out-String
  } else {
    Write-Warning "Git Bash not found; falling back to cmd /c (bash syntax may fail)" 2>&1
    $output = & cmd /c $verifyCmd 2>&1 | Out-String
  }
  $rc = $LASTEXITCODE
  # Clear guard after each AC verify so subsequent code paths are unaffected.
  Remove-Item Env:ENGINE_VERIFY_RECURSE_GUARD -ErrorAction SilentlyContinue
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
Write-Output "$Task`: $passCount pass, $failCount fail, $skipCount skip"
if ($failCount -ne 0) { exit 1 }
