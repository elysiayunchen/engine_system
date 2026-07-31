# Engine System — Agent-Reviewer Package (v6.22.0) [PowerShell behavioral mirror]
#
# Phase 1: Package review context -> engine/review/evidence/T-NNN/review-package.md
# Behavioral mirror of engine-review-agent-package.sh (same input -> same output)

param([string]$Task)

$ErrorActionPreference = 'Stop'
$ROOT = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { Get-Location }
$ENGINE_DIR = Join-Path $ROOT 'engine'

if (-not $Task) {
    [Console]::Error.WriteLine("[engine-review-agent-package] Usage: engine-review-agent-package T-NNN")
    exit 2
}

$taskFile = Join-Path $ENGINE_DIR "tasks/$Task.md"
if (-not (Test-Path $taskFile)) {
    [Console]::Error.WriteLine("[engine-review-agent-package] Error: task card not found: $taskFile")
    exit 2
}

# === 0. FileStream lock ===
$reviewDir = Join-Path $ENGINE_DIR 'review'
if (-not (Test-Path $reviewDir)) { New-Item -ItemType Directory -Path $reviewDir -Force | Out-Null }
$lockPath = Join-Path $reviewDir ".review-agent-lock.$Task"
try {
    $lockStream = [System.IO.File]::Open($lockPath, 'Create', 'ReadWrite', 'None')
} catch {
    [Console]::Error.WriteLine("[engine-review-agent-package] another review-agent running for $Task")
    exit 1
}

try {
    # === 1. Config check ===
    $configFile = Join-Path $reviewDir 'config.json'
    $cfg = if (Test-Path $configFile) { Get-Content $configFile -Raw -Encoding UTF8 | ConvertFrom-Json } else { @{} }
    $ar = @{}
    if ($cfg.defaults.agent_review) { $ar = $cfg.defaults.agent_review }
    if ($cfg.overrides.agent_review) {
        $cfg.overrides.agent_review.PSObject.Properties | ForEach-Object { $ar[$_.Name] = $_.Value }
    }
    $agentReviewEnabled = if ($null -eq $ar.enabled) { $true } elseif ($ar.enabled) { $true } else { $false }

    # L2 REVIEW-OVERRIDE check
    $taskContent = Get-Content $taskFile -Raw -Encoding UTF8
    $l2HasAgentReview = $taskContent -match 'add_dimensions:.*agent_review'

    if (-not $agentReviewEnabled -and -not $l2HasAgentReview) {
        Write-Output "[engine-review-agent-package] $Task`: agent_review not enabled (config or L2), skipped"
        exit 0
    }

    $maxPackageLines = if ($ar.max_package_lines) { [int]$ar.max_package_lines } else { 2000 }
    $maxSurrounding = if ($ar.max_surrounding_context_lines) { [int]$ar.max_surrounding_context_lines } else { 500 }
    $maxDomain = if ($ar.max_domain_knowledge_lines) { [int]$ar.max_domain_knowledge_lines } else { 150 }

    # === 2. Parse WRITE-SET ===
    $writeSetLines = @()
    $inWriteSet = $false
    foreach ($line in (Get-Content $taskFile -Encoding UTF8)) {
        if ($line -match '^## WRITE-SET') { $inWriteSet = $true; continue }
        if ($line -match '^## ' -and $inWriteSet) { $inWriteSet = $false; continue }
        if ($inWriteSet -and $line -match '^- (.+)') {
            $f = $Matches[1] -replace '\s*#.*$', ''
            $writeSetLines += $f.Trim()
        }
    }
    if ($writeSetLines.Count -eq 0) {
        [Console]::Error.WriteLine("[engine-review-agent-package] Error: review requires WRITE-SET to scope diff (task $Task)")
        exit 1
    }

    # === 3. Diff (task_first_commit algorithm) ===
    $taskFirstCommit = (git -C $ROOT log --reverse --format="%H" -- "engine/tasks/$Task.md" 2>$null | Select-Object -First 1)
    if (-not $taskFirstCommit) {
        [Console]::Error.WriteLine("[engine-review-agent-package] Error: no git history for $taskFile (commit the task card first)")
        exit 1
    }
    $headCommit = (git -C $ROOT rev-parse HEAD 2>$null)
    # taskFirstCommit^ fails for root commits; suppress via cmd /c to avoid ErrorActionPreference Stop
    $diffBase = (cmd /c "git -C `"$ROOT`" rev-parse `"$taskFirstCommit^`" 2>nul")
    if (-not ($diffBase -match '^[0-9a-f]{40}$')) {
        $diffBase = '4b825dc642cb6eb9a060e54bf8d69288fbee4904'
    }

    # === 4. Filter code files ===
    $codeExts = @('.sh','.ps1','.py','.js','.ts','.go','.rs','.java','.c','.cpp','.rb','.php')
    if ($cfg.defaults.code_extensions) { $codeExts = @($cfg.defaults.code_extensions) }
    $codeFiles = @()
    foreach ($f in $writeSetLines) {
        if ($f -match '[*?]') { continue }
        $ext = [System.IO.Path]::GetExtension($f)
        $fullPath = Join-Path $ROOT $f
        if ($codeExts -contains $ext -and (Test-Path $fullPath)) { $codeFiles += $f }
    }
    if ($codeFiles.Count -eq 0) {
        Write-Output "[engine-review-agent-package] $Task`: no code changes in WRITE-SET, agent review skipped"
        exit 0
    }

    # Filter to files with actual diff
    $diffFiles = @()
    foreach ($f in $codeFiles) {
        $changed = git -C $ROOT diff --name-only "$diffBase..HEAD" -- $f 2>$null
        if ($changed) { $diffFiles += $f }
    }
    if ($diffFiles.Count -eq 0) {
        Write-Output "[engine-review-agent-package] $Task`: no code changes in WRITE-SET, agent review skipped"
        exit 0
    }

    # === 5. Surrounding context (hunk headers + grep) ===
    $hunkHeaders = git -C $ROOT diff -U0 "$diffBase..HEAD" -- @diffFiles 2>$null | Select-String '^@@' | ForEach-Object { ($_ -replace '.*@@\s*', '') } | Select-Object -First 20
    $surroundingContext = ''
    $surroundingLines = 0
    if ($hunkHeaders) {
        $symbols = $hunkHeaders | ForEach-Object { [regex]::Matches($_, '[A-Za-z_][A-Za-z_0-9]+') | ForEach-Object { $_.Value } } | Sort-Object -Unique | Select-Object -First 15
        foreach ($sym in $symbols) {
            if ($sym.Length -lt 3) { continue }
            foreach ($wf in $writeSetLines) {
                if ($diffFiles -contains $wf) { continue }
                if ($wf -match '[*?]') { continue }
                $wfPath = Join-Path $ROOT $wf
                if (-not (Test-Path $wfPath)) { continue }
                $matches2 = Select-String -Path $wfPath -Pattern $sym -SimpleMatch | Select-Object -First 3
                if ($matches2) {
                    $firstLine = $matches2[0].LineNumber
                    $start = [Math]::Max(1, $firstLine - 10)
                    $end = $firstLine + 10
                    $allLines = Get-Content $wfPath -Encoding UTF8
                    $ctx = ($allLines[($start-1)..([Math]::Min($end-1, $allLines.Count-1))] -join "`n")
                    $ctxLines = ($ctx -split "`n").Count
                    if (($surroundingLines + $ctxLines) -le $maxSurrounding) {
                        $surroundingContext += "`n### $wf (references: $sym)`n`````````n$ctx`n`````````n"
                        $surroundingLines += $ctxLines + 3
                    }
                }
            }
            if ($surroundingLines -ge $maxSurrounding) { break }
        }
    }

    # === 6. Domain knowledge ===
    $domainKnowledge = ''
    $fedFile = Join-Path $ENGINE_DIR 'domains/federation.json'
    if (Test-Path $fedFile) {
        $fed = Get-Content $fedFile -Raw -Encoding UTF8 | ConvertFrom-Json
        $firstDiff = $diffFiles[0]
        foreach ($prop in $fed.domains.PSObject.Properties) {
            $paths = $prop.Value.paths
            foreach ($p in $paths) {
                $prefix = $p -replace '\*+$', '' -replace '/+$', ''
                if ($firstDiff.StartsWith($prefix)) {
                    $invFile = Join-Path $ENGINE_DIR "domains/$($prop.Name)/INVENTORY.md"
                    if (Test-Path $invFile) {
                        $invContent = (Get-Content $invFile -Encoding UTF8 | Select-Object -First $maxDomain) -join "`n"
                        $domainKnowledge = "### Domain: $($prop.Name) - INVENTORY`n$invContent`n"
                    }
                    break
                }
            }
            if ($domainKnowledge) { break }
        }
    }

    # === 7. Dynamic challenges (v6.22.0: diff semantic signals -> parameterized challenges) ===
    # packaged_by: for reviewer independence validation
    $packagedBy = if ($env:CLAUDE_SESSION_ID) { $env:CLAUDE_SESSION_ID } else { "$([System.Net.Dns]::GetHostName()):$PID" }

    # most_changed_file (retained for fallback)
    $diffStat = git -C $ROOT diff --stat "$diffBase..HEAD" -- @diffFiles 2>$null
    $mostChanged = ($diffStat | Select-String '\|' | Sort-Object { [int]($_ -replace '.*\|\s*(\d+).*','$1') } -Descending | Select-Object -First 1) -replace '\s*\|.*$', ''
    $mostChanged = $mostChanged.Trim()
    if (-not $mostChanged) { $mostChanged = $diffFiles[0] }

    # Dynamic challenges: python analyzes diff semantic signals, generates 3 targeted challenges
    $pyCmd = $null
    foreach ($c in @('python3','python')) { try { $null = cmd /c "$c --version 2>nul"; if ($LASTEXITCODE -eq 0) { $pyCmd = $c; break } } catch {} }

    $challenges = $null
    if ($pyCmd) {
        $env:DIFF_BASE = $diffBase
        $env:HEAD_REF = 'HEAD'
        $env:DIFF_FILES = ($diffFiles -join ' ')
        $env:ROOT_DIR = $ROOT
        $pyScript = @'
import subprocess, os, re, sys

diff_base = os.environ['DIFF_BASE']
diff_files = os.environ['DIFF_FILES'].split()
root = os.environ['ROOT_DIR']

signals = []

for f in diff_files:
    try:
        diff = subprocess.check_output(
            ['git', 'diff', '-U3', f'{diff_base}..HEAD', '--', f],
            cwd=root, stderr=subprocess.DEVNULL
        ).decode('utf-8', errors='replace')
    except Exception:
        continue

    added_lines = []
    removed_count = 0
    hunk_sizes = []
    current_hunk = 0

    for line in diff.split('\n'):
        if line.startswith('@@'):
            if current_hunk > 0:
                hunk_sizes.append(current_hunk)
            current_hunk = 0
            m = re.search(r'\+(\d+)', line)
            hunk_start = int(m.group(1)) if m else 0
        elif line.startswith('+') and not line.startswith('+++'):
            current_hunk += 1
            added_lines.append((hunk_start + current_hunk, line[1:]))
        elif line.startswith('-') and not line.startswith('---'):
            removed_count += 1
            current_hunk += 1

    if current_hunk > 0:
        hunk_sizes.append(current_hunk)

    for lineno, content in added_lines:
        stripped = content.strip()
        if re.match(r'\b(if|case|switch|elif)\b', stripped) and not re.search(r'\belse\b', stripped):
            nearby = [c for l, c in added_lines if abs(l - lineno) < 10]
            if not any('else' in c for c in nearby):
                signals.append((90, f"File `{f}` line ~{lineno} adds a new branch (`{stripped[:60]}`) with no visible else/fallback. What happens when this condition is false?"))
                break

    for lineno, content in added_lines:
        stripped = content.strip()
        if re.match(r'\b(def|function|func|sub)\b', stripped) and '(' in stripped:
            signals.append((80, f"File `{f}` line ~{lineno} defines/modifies `{stripped[:60]}`. Are all callers updated to match the new signature?"))
            break

    if hunk_sizes and max(hunk_sizes) > 20:
        big_line = max(hunk_sizes)
        signals.append((70, f"File `{f}` has a hunk with {big_line} changed lines. Is this a single logical change, or should it be split?"))

    if removed_count > 15:
        signals.append((60, f"File `{f}` removes {removed_count} lines. Are there callers or tests that still depend on the removed behavior?"))

    for lineno, content in added_lines:
        stripped = content.strip()
        if re.search(r'\b(TODO|FIXME|HACK|XXX)\b', stripped):
            signals.append((50, f"File `{f}` line ~{lineno} adds `{stripped[:60]}`. Is this intentional tech debt, and is it tracked?"))
            break

    for lineno, content in added_lines:
        stripped = content.strip()
        if re.match(r'\b(catch|except|rescue|on error|trap)\b', stripped, re.IGNORECASE):
            signals.append((55, f"File `{f}` line ~{lineno} adds error handling (`{stripped[:60]}`). Does it swallow errors silently or propagate them correctly?"))
            break

signals.sort(key=lambda x: -x[0])
unique = []
seen = set()
for pri, text in signals:
    key = text[:40]
    if key not in seen:
        seen.add(key)
        unique.append(text)

if len(unique) >= 3:
    for i, c in enumerate(unique[:3], 1):
        print(f"{i}. {c}")
elif len(unique) > 0:
    for i, c in enumerate(unique, 1):
        print(f"{i}. {c}")
    statics = [
        "If someone needs to modify this code 6 months from now, what is the biggest comprehension barrier?",
        "What is the worst-case input for this change, and does it degrade gracefully?",
        "Does this change introduce any implicit coupling that is not documented?"
    ]
    for j in range(len(unique), 3):
        print(f"{j+1}. {statics[j - len(unique)]}")
else:
    print("SIGNAL_NONE")
'@
        try {
            $challenges = & $pyCmd -c $pyScript 2>$null
            $env:DIFF_BASE = $null; $env:HEAD_REF = $null; $env:DIFF_FILES = $null; $env:ROOT_DIR = $null
        } catch {
            $challenges = $null
        }
    }

    # Fallback: no signals or python unavailable -> static challenges
    if (-not $challenges -or $challenges -eq 'SIGNAL_NONE' -or ($challenges -join '').Trim() -eq '') {
        $hunkLines = git -C $ROOT diff -U0 "$diffBase..HEAD" -- $mostChanged 2>$null | Select-String '^@@' | ForEach-Object { if ($_ -match '\+(\d+)') { [int]$Matches[1] } } | Sort-Object -Descending | Select-Object -First 1
        if (-not $hunkLines) { $hunkLines = 1 }
        $anotherFile = ($diffFiles | Where-Object { $_ -ne $mostChanged } | Select-Object -First 1)
        if (-not $anotherFile) { $anotherFile = '(other WRITE-SET files)' }
        $challenges = "1. File ``$mostChanged`` around line $hunkLines contains the most complex change. What happens if it receives empty input or extremely long input?`n2. Does this change break any assumptions that ``$anotherFile`` makes about ``$mostChanged``?`n3. If someone needs to modify this code 6 months from now, what is the biggest comprehension barrier?"
    } else {
        $challenges = ($challenges -join "`n")
    }

    # === 8. Linter summary ===
    $linterSummary = ''
    $evidenceDir = Join-Path $reviewDir "evidence/$Task"
    $secFile = Join-Path $evidenceDir 'SECURITY.json'
    $qualFile = Join-Path $evidenceDir 'QUALITY.json'
    if ((Test-Path $secFile) -or (Test-Path $qualFile)) {
        $secCount = 0; $qualCount = 0
        if (Test-Path $secFile) {
            $sec = Get-Content $secFile -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($sec.findings_count) { $secCount = ($sec.findings_count.PSObject.Properties | Measure-Object -Property Value -Sum).Sum }
        }
        if (Test-Path $qualFile) {
            $qual = Get-Content $qualFile -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($qual.findings_count) { $qualCount = ($qual.findings_count.PSObject.Properties | Measure-Object -Property Value -Sum).Sum }
        }
        if ($secCount -gt 0 -or $qualCount -gt 0) {
            $linterSummary = "### Linter Findings Summary`n`nv1 review (semgrep + eslint) has already reported: **$secCount** security findings, **$qualCount** quality findings.`nPlease address these in your overall_assessment (agree / supplement / disagree).`n"
        }
    }

    # === 9. Assemble package ===
    if (-not (Test-Path $evidenceDir)) { New-Item -ItemType Directory -Path $evidenceDir -Force | Out-Null }
    $packageFile = Join-Path $evidenceDir 'review-package.md'
    $timestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')

    # Task card extracts (split into lines for ^ anchor matching)
    $taskLines = $taskContent -split "`n"
    $goalMatch = $taskLines | Select-String '^GOAL:\s*(.+)' | Select-Object -First 1
    $goalText = if ($goalMatch) { $goalMatch.Matches[0].Groups[1].Value.Trim() } else { '' }
    if (-not $goalText) { $goalText = '(see task card)' }
    $constraintsMatch = $taskLines | Select-String '^CONSTRAINTS:\s*(.+)' | Select-Object -First 1
    $constraintsText = if ($constraintsMatch) { $constraintsMatch.Matches[0].Groups[1].Value.Trim() } else { '' }
    $acLines = ($taskLines | Where-Object { $_ -match '^AC:' }) -join "`n"

    # Diff content
    $diffContent = ''
    foreach ($f in $diffFiles) {
        $fileDiff = git -C $ROOT diff "$diffBase..HEAD" -- $f 2>$null
        if ($fileDiff) { $diffContent += "`n### $f`n``````diff`n$fileDiff`n`````````n" }
    }

    # Protocol
    $protocolFile = Join-Path $reviewDir 'protocol.md'
    $protocolContent = if (Test-Path $protocolFile) { Get-Content $protocolFile -Raw -Encoding UTF8 } else { 'Review across 5 dimensions: correctness, design, consistency, readability, completeness.' }

    $scopeShort = "$($diffBase.Substring(0,8))..$($headCommit.Substring(0,8))"
    $writeSetFormatted = ($writeSetLines | ForEach-Object { "- $_" }) -join "`n"

    $packageContent = @"
# Code Review Package: $Task

> generated: $timestamp
> package_sha256: PLACEHOLDER
> head_commit: $headCommit
> packaged_by: $packagedBy
> task: $goalText
> scope: $scopeShort, $($diffFiles.Count) code files

## 1. Task Context

### GOAL
$goalText

### WRITE-SET
$writeSetFormatted

### CONSTRAINTS
$constraintsText

### AC
$acLines

## 2. Code Changes (diff)
$diffContent

## 3. Surrounding Context
$surroundingContext

## 4. Domain Knowledge
$domainKnowledge

## 5. Review Protocol

$protocolContent

### Adversarial Challenges (must answer all 3)

$challenges

$linterSummary

## 6. Output Format (strict)

Write your review to: ``engine/review/evidence/$Task/AGENT-REVIEW.json``

Schema (all fields required):
``````json
{
  "task": "$Task",
  "timestamp": "<ISO-8601>",
  "reviewer": {"type": "agent", "model": "<optional>"},
  "status": "pass|concerns|block",
  "dimensions": {
    "correctness": {"entries": [{"id": "agent-correctness-<file>:<line>", "severity": "high", "type": "finding", "file": "<path>", "line": 42, "message": "<>=20 chars>", "suggestion": "<optional>"}], "summary": "<1-2 sentences>"},
    "design": {"entries": [...], "summary": "..."},
    "consistency": {"entries": [...], "summary": "..."},
    "readability": {"entries": [...], "summary": "..."},
    "completeness": {"entries": [...], "summary": "..."}
  },
  "adversarial_responses": [
    {"challenge": "<question 1>", "response": "<>=30 chars>"},
    {"challenge": "<question 2>", "response": "<>=30 chars>"},
    {"challenge": "<question 3>", "response": "<>=30 chars>"}
  ],
  "overall_assessment": "<2-3 sentences, >=200 chars total with summaries>",
  "write_provenance": {
    "writer": "agent-reviewer",
    "commit": "$headCommit",
    "timestamp": "<write time>",
    "package_sha256": "<fill from package header>",
    "reviewer_session": "<your session/agent identifier, must differ from packaged_by>"
  }
}
``````

**Important**:
- ``write_provenance.commit``: copy the ``head_commit`` value from this package header
- ``write_provenance.package_sha256``: copy the ``package_sha256`` value from this package header
- Each finding.message >= 20 characters
- Each dimension must have >= 1 entry (use type="strength" + severity="info" if no issues found)
- Exactly 3 adversarial_responses, each response >= 30 characters
- severity values: critical | high | medium | low | info
- status: "pass" (no critical/high) | "concerns" (has high, acceptable) | "block" (has critical)
"@

    # Write + sha256 backfill (COMPUTE normalization: replace sha line with COMPUTE before hashing)
    [System.IO.File]::WriteAllText($packageFile, $packageContent, [System.Text.UTF8Encoding]::new($false))
    $normalized = [regex]::Replace($packageContent, '(> package_sha256: ).*', '${1}COMPUTE')
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $normBytes = [System.Text.Encoding]::UTF8.GetBytes($normalized)
    $finalHash = [BitConverter]::ToString($sha.ComputeHash($normBytes)).Replace('-','').ToLower()
    $packageContent = $packageContent.Replace('package_sha256: PLACEHOLDER', "package_sha256: $finalHash")
    [System.IO.File]::WriteAllText($packageFile, $packageContent, [System.Text.UTF8Encoding]::new($false))

    $packageLines = (Get-Content $packageFile).Count
    if ($packageLines -gt $maxPackageLines) {
        [Console]::Error.WriteLine("[engine-review-agent-package] WARN: package is $packageLines lines (limit $maxPackageLines), truncating")
        $pkgLinesArr = [System.Collections.Generic.List[string]]::new()
        Get-Content $packageFile -Encoding UTF8 | ForEach-Object { $pkgLinesArr.Add($_) }

        function Find-Section([System.Collections.Generic.List[string]]$lines, [string]$header) {
            $start = -1; $end = -1
            for ($i = 0; $i -lt $lines.Count; $i++) {
                if ($lines[$i].StartsWith($header)) { $start = $i }
                elseif ($start -ge 0 -and $lines[$i].StartsWith('## ')) { $end = $i; break }
            }
            if ($start -ge 0 -and $end -eq -1) { $end = $lines.Count }
            return @($start, $end)
        }
        function Remove-Section([System.Collections.Generic.List[string]]$lines, [string]$header, [string]$label) {
            $se = Find-Section $lines $header
            if ($se[0] -lt 0) { return 0 }
            $removed = $se[1] - $se[0] - 1
            for ($j = $se[1] - 1; $j -gt $se[0]; $j--) { $lines.RemoveAt($j) }
            $lines.Insert($se[0] + 1, $label)
            $lines.Insert($se[0] + 2, '')
            return $removed
        }

        [void](Remove-Section $pkgLinesArr '## 3. Surrounding Context' '_(truncated for size)_')
        if ($pkgLinesArr.Count -gt $maxPackageLines) {
            [void](Remove-Section $pkgLinesArr '## 4. Domain Knowledge' '_(truncated for size)_')
        }
        [System.IO.File]::WriteAllLines($packageFile, $pkgLinesArr.ToArray(), [System.Text.UTF8Encoding]::new($false))
        $packageLines = $pkgLinesArr.Count
    }

    Write-Output "[engine-review-agent-package] $Task`: package ready ($packageLines lines)"
    Write-Output "  Output: engine/review/evidence/$Task/review-package.md"
    Write-Output "  Next: feed this package to your review agent, then run 'engine review-agent $Task --validate'"
    exit 0

} finally {
    if ($lockStream) { $lockStream.Dispose() }
}
