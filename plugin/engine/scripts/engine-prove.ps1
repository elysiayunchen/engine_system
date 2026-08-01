# Engine System — Prove: 执行验证子系统 (v6.23.0) [PowerShell behavioral mirror]
#
# 从 diff 自动推断测试断言并执行。两原子命令 (D-019):
#   engine prove T-NNN --infer    → 产出 prove-package.md (上下文)
#   engine prove T-NNN --execute  → 执行 prove-assertions.json + 门禁
#
# 证据: engine/evidence/T-NNN/PROVE.json
# 安全: 命令黑名单 + 反套言 + 陈旧指纹检测 + timeout
#
# Usage: pwsh -File engine/scripts/engine-prove.ps1 -Task T-NNN -Mode --infer|--execute

param(
    [Parameter(Mandatory=$false)][string]$Task,
    [Parameter(Mandatory=$false)][string]$Mode
)

$ErrorActionPreference = 'Stop'
trap { [Console]::Error.WriteLine("[engine-prove] error: $_"); exit 1 }

$ROOT = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (Get-Location).Path }
$ENGINE_DIR = Join-Path $ROOT 'engine'
$PROVE_DIR = Join-Path $ENGINE_DIR 'prove'

Set-Location $ROOT

# python detection
$PY = 'python3'
if (-not (Get-Command python3 -ErrorAction SilentlyContinue)) { $PY = 'python' }
if (-not (Get-Command $PY -ErrorAction SilentlyContinue)) {
    [Console]::Error.WriteLine("[engine-prove] error: python not found")
    exit 1
}

# === Usage ===
if (-not $Task -or -not $Mode) {
    [Console]::Error.WriteLine("Usage: engine prove T-NNN --infer|--execute")
    exit 2
}
if ($Mode -notin @('--infer', '--execute')) {
    [Console]::Error.WriteLine("Usage: engine prove T-NNN --infer|--execute")
    exit 2
}

# === FileStream lock (concurrency guard) ===
if (-not (Test-Path $PROVE_DIR)) { New-Item -ItemType Directory -Path $PROVE_DIR -Force | Out-Null }
$lockPath = Join-Path $PROVE_DIR ".prove-lock.$Task"
try {
    $lockStream = [System.IO.File]::Open($lockPath, 'Create', 'ReadWrite', 'None')
} catch {
    [Console]::Error.WriteLine("[engine-prove] another prove process running for $Task")
    exit 1
}

try {

# === Config loading ===
$configFile = Join-Path $PROVE_DIR 'config.json'

function Load-ConfigValue {
    param([string]$Key, [string]$Default)
    if (-not (Test-Path $configFile)) { return $Default }
    $env:CONFIG_FILE = $configFile
    $env:KEY = $Key
    $env:DEFAULT = $Default
    $result = & $PY -c @"
import json, os
try:
    with open(os.environ['CONFIG_FILE']) as f:
        cfg = json.load(f)
except:
    cfg = {}
defaults = cfg.get('defaults', {})
overrides = cfg.get('overrides', {})
merged = dict(defaults)
for k, v in overrides.items():
    merged[k] = v
val = merged.get(os.environ['KEY'], os.environ['DEFAULT'])
print(val if not isinstance(val, list) else json.dumps(val))
"@ 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $result) { return $Default }
    return $result.Trim()
}

$MAX_ASSERTIONS = Load-ConfigValue -Key 'max_assertions' -Default '10'
$ASSERTION_TIMEOUT = Load-ConfigValue -Key 'assertion_timeout_s' -Default '30'
$OUTPUT_TRUNCATE = Load-ConfigValue -Key 'output_truncate_chars' -Default '500'

# === Shared: diff extraction (mirrors review-agent-package algorithm) ===
$script:PROVE_WRITE_SET = ''
$script:PROVE_CODE_FILES = ''
$script:PROVE_DIFF_FILES = ''
$script:PROVE_DIFF_BASE = ''
$script:PROVE_HEAD_COMMIT = ''
$script:PROVE_TASK_GOAL = ''

function Extract-DiffContext {
    param([string]$TaskId)
    $taskFile = Join-Path $ENGINE_DIR "tasks/$TaskId.md"

    if (-not (Test-Path $taskFile)) {
        [Console]::Error.WriteLine("[engine-prove] Error: task card not found: $taskFile")
        exit 1
    }

    # Parse WRITE-SET
    $writeSetFiles = @()
    $inWriteSet = $false
    foreach ($line in (Get-Content $taskFile -Encoding UTF8)) {
        if ($line -match '^## WRITE-SET') { $inWriteSet = $true; continue }
        if ($line -match '^## ' -and $inWriteSet) { $inWriteSet = $false; continue }
        if ($inWriteSet -and $line -match '^- (.+)') {
            $f = $Matches[1] -replace '\s*#.*$', ''
            $writeSetFiles += $f.Trim()
        }
    }
    $script:PROVE_WRITE_SET = ($writeSetFiles -join ' ')

    # Code extensions filter
    $codeExtensionsJson = Load-ConfigValue -Key 'code_extensions' -Default '[".sh",".ps1",".py",".js",".ts",".go",".rs",".java",".c",".cpp",".rb",".php"]'

    $env:ROOT_DIR = $ROOT
    $env:CODE_EXTS = $codeExtensionsJson
    $env:WRITE_SET_INPUT = ($writeSetFiles -join "`n")
    $codeFilesResult = & $PY -c @"
import json, sys, os
exts = set(json.loads(os.environ['CODE_EXTS']))
root = os.environ['ROOT_DIR']
out = []
for line in os.environ['WRITE_SET_INPUT'].splitlines():
    f = line.strip()
    if not f: continue
    if '*' in f or '?' in f: continue
    _, ext = os.path.splitext(f)
    if ext in exts and os.path.isfile(os.path.join(root, f)):
        out.append(f)
print(' '.join(out))
"@ 2>$null
    if ($LASTEXITCODE -ne 0) { $codeFilesResult = '' }
    $script:PROVE_CODE_FILES = if ($codeFilesResult) { $codeFilesResult.Trim() } else { '' }

    # Diff base (task_first_commit algorithm)
    $taskFirstCommit = (git -C $ROOT log --reverse --format="%H" -- "engine/tasks/$TaskId.md" 2>$null | Select-Object -First 1)
    if (-not $taskFirstCommit) {
        [Console]::Error.WriteLine("[engine-prove] Error: no git history for $taskFile")
        exit 1
    }

    $script:PROVE_HEAD_COMMIT = (git -C $ROOT rev-parse HEAD 2>$null)
    if (-not $script:PROVE_HEAD_COMMIT) { $script:PROVE_HEAD_COMMIT = 'unknown' }

    $diffBase = (cmd /c "git -C `"$ROOT`" rev-parse `"$taskFirstCommit^`" 2>nul")
    if (-not ($diffBase -match '^[0-9a-f]{40}$')) {
        $diffBase = '4b825dc642cb6eb9a060e54bf8d69288fbee4904'
    }
    $script:PROVE_DIFF_BASE = $diffBase.Trim()

    # Filter to files actually changed
    $diffFiles = @()
    $codeFileList = if ($script:PROVE_CODE_FILES) { $script:PROVE_CODE_FILES -split '\s+' } else { @() }
    foreach ($f in $codeFileList) {
        if (-not $f) { continue }
        $changed = (git -C $ROOT diff --name-only "$($script:PROVE_DIFF_BASE)..HEAD" -- $f 2>$null)
        if ($changed) { $diffFiles += $f }
    }
    $script:PROVE_DIFF_FILES = ($diffFiles -join ' ')

    # Extract GOAL
    $goalLines = @()
    $inGoal = $false
    foreach ($line in (Get-Content $taskFile -Encoding UTF8)) {
        if ($line -match '^## GOAL') { $inGoal = $true; continue }
        if ($line -match '^## ' -and $inGoal) { break }
        if ($inGoal) { $goalLines += $line }
    }
    $script:PROVE_TASK_GOAL = ($goalLines | Select-Object -First 5) -join "`n"
}

# === Phase 1: --infer ===
function Invoke-PhaseInfer {
    param([string]$TaskId)
    $evidenceDir = Join-Path $ENGINE_DIR "evidence/$TaskId"
    if (-not (Test-Path $evidenceDir)) { New-Item -ItemType Directory -Path $evidenceDir -Force | Out-Null }
    $packageFile = Join-Path $evidenceDir 'prove-package.md'

    Extract-DiffContext -TaskId $TaskId

    # No code files -> NO-OP
    if (-not $script:PROVE_DIFF_FILES) {
        $ts = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        $noopContent = @"
# Prove Package: $TaskId

> generated: $ts
> status: NO-OP
> reason: no code files in diff range

No assertions needed.
"@
        Set-Content -Path $packageFile -Value $noopContent -Encoding UTF8
        Write-Output "[engine-prove] ${TaskId}: no code changes, package marked NO-OP"
        exit 0
    }

    # Compute code fingerprint (sha256 of concatenated diffs + WRITE-SET file contents)
    $env:DIFF_BASE = $script:PROVE_DIFF_BASE
    $env:DIFF_FILES = $script:PROVE_DIFF_FILES
    $env:WRITE_SET = $script:PROVE_WRITE_SET
    $codeFingerprint = & $PY -c @"
import hashlib, subprocess, os
diff_base = os.environ['DIFF_BASE']
diff_files = os.environ['DIFF_FILES'].split()
write_set = os.environ.get('WRITE_SET', '').split()
all_files = list(dict.fromkeys(diff_files + write_set))
content = ''
for f in all_files:
    try:
        out = subprocess.check_output(['git', 'diff', diff_base + '..HEAD', '--', f], stderr=subprocess.DEVNULL)
        text = out.decode('utf-8', errors='replace')
        if text.strip():
            content += text
        elif os.path.isfile(f):
            with open(f, 'rb') as fh:
                content += fh.read().decode('utf-8', errors='replace')
    except:
        if os.path.isfile(f):
            with open(f, 'rb') as fh:
                content += fh.read().decode('utf-8', errors='replace')
print('sha256:' + hashlib.sha256(content.encode('utf-8')).hexdigest())
"@ 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $codeFingerprint) {
        $codeFingerprint = 'sha256:0000000000000000000000000000000000000000000000000000000000000000'
    }
    $codeFingerprint = $codeFingerprint.Trim()

    # Extract hunk symbols
    $diffFileList = $script:PROVE_DIFF_FILES -split '\s+'
    $hunkSymbols = (git -C $ROOT diff -U0 "$($script:PROVE_DIFF_BASE)..HEAD" -- @diffFileList 2>$null |
        Where-Object { $_ -match '^@@' } |
        ForEach-Object { $_ -replace '.*@@\s*', '' } |
        Where-Object { $_ -ne '' } |
        Select-Object -First 20)
    if (-not $hunkSymbols) { $hunkSymbols = @() }

    # Detect languages -> syntax checkers
    $syntaxChecks = @()
    foreach ($f in $diffFileList) {
        if (-not $f) { continue }
        $ext = [System.IO.Path]::GetExtension($f).TrimStart('.')
        switch ($ext) {
            'sh'   { $syntaxChecks += "- bash -n $f" }
            'py'   { $syntaxChecks += "- python -m py_compile $f" }
            'js'   { $syntaxChecks += "- node --check $f" }
            'json' { $syntaxChecks += "- python -m json.tool $f" }
        }
    }

    # Find existing test coverage
    $testCoverage = @()
    $testsDir = Join-Path $ROOT 'tests'
    foreach ($f in $diffFileList) {
        if (-not $f) { continue }
        $basenameF = [System.IO.Path]::GetFileName($f)
        if (Test-Path $testsDir) {
            $matchingTests = @()
            try {
                $matchingTests = @(Get-ChildItem -Path $testsDir -Recurse -File -ErrorAction SilentlyContinue |
                    Where-Object { (Get-Content $_.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue) -match [regex]::Escape($basenameF) } |
                    Select-Object -First 3 -ExpandProperty FullName)
            } catch {}
            if ($matchingTests.Count -gt 0) {
                $testCoverage += "- $f covered by:"
                foreach ($t in $matchingTests) {
                    $relT = $t -replace [regex]::Escape($ROOT + '\'), '' -replace [regex]::Escape($ROOT + '/'), ''
                    $testCoverage += "  - bash $relT"
                }
            }
        }
    }

    # Generate diff content
    $diffContent = ''
    foreach ($f in $diffFileList) {
        if (-not $f) { continue }
        $fileDiff = (git -C $ROOT diff "$($script:PROVE_DIFF_BASE)..HEAD" -- $f 2>$null | Out-String)
        if ($fileDiff.Trim()) {
            $diffContent += "`n### $f`n``````diff`n$fileDiff```````n"
        }
    }

    # Render prove-package.md
    $ts = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    $diffRangeBase = $script:PROVE_DIFF_BASE.Substring(0, [Math]::Min(8, $script:PROVE_DIFF_BASE.Length))
    $diffRangeHead = $script:PROVE_HEAD_COMMIT.Substring(0, [Math]::Min(8, $script:PROVE_HEAD_COMMIT.Length))
    $codeFileCount = @($diffFileList | Where-Object { $_ }).Count

    $writeSetSection = ($diffFileList | Where-Object { $_ } | ForEach-Object { "- $_" }) -join "`n"
    $hunkSection = if ($hunkSymbols.Count -gt 0) { ($hunkSymbols | ForEach-Object { "- $_" }) -join "`n" } else { '- (none detected)' }
    $syntaxSection = if ($syntaxChecks.Count -gt 0) { $syntaxChecks -join "`n" } else { '- (none auto-detected)' }
    $coverageSection = if ($testCoverage.Count -gt 0) { $testCoverage -join "`n" } else { '- (none found — agent should generate invariant assertions)' }

    $packageContent = @"
# Prove Package: $TaskId

> generated: $ts
> code_fingerprint: $codeFingerprint
> head_commit: $($script:PROVE_HEAD_COMMIT)
> diff_range: ${diffRangeBase}..${diffRangeHead}
> code_files: $codeFileCount

## GOAL
$($script:PROVE_TASK_GOAL)

## WRITE-SET (code files in diff)
$writeSetSection

## WRITE-SET (full, from task card)
$($script:PROVE_WRITE_SET -split '\s+' | Where-Object { $_ } | ForEach-Object { "- $_" } | Out-String)

## Hunk Symbols (modified functions/classes)
$hunkSection

## Syntax Checks (auto-detected)
$syntaxSection

## Existing Test Coverage
$coverageSection

## Unified Diff
$diffContent

## Assertion Generation Instructions

Generate prove-assertions.json with categories:
- **syntax**: Verify modified files parse correctly (use syntax checks above)
- **regression**: Run existing tests covering modified files (use test coverage above)
- **invariant**: Property tests specific to THIS change that would FAIL if reverted

### Anti-Tautology Rules (MANDATORY)
1. NEVER emit commands that always succeed (true, :, echo-only)
2. Each assertion MUST reference a specific file or symbol from this diff
3. Invariant assertions MUST have revert_would_fail=true
4. Maximum $MAX_ASSERTIONS assertions total
5. Commands must NOT contain: rm, mv, curl, wget, sudo, dd, mkfs, chmod, kill
6. rationale must be >=20 chars and explain WHY this assertion catches regressions

### Output Schema
Write engine/evidence/$TaskId/prove-assertions.json:
``````json
{
  "task_id": "$TaskId",
  "code_fingerprint": "$codeFingerprint",
  "assertions": [
    {
      "id": "A-01",
      "category": "syntax|regression|invariant",
      "command": "<shell command>",
      "expect_exit": 0,
      "timeout_s": 30,
      "rationale": "<why this matters, >=20 chars>",
      "revert_would_fail": false
    }
  ]
}
``````
"@

    Set-Content -Path $packageFile -Value $packageContent -Encoding UTF8

    $pkgLines = (Get-Content $packageFile).Count
    Write-Output "[engine-prove] ${TaskId}: prove-package ready ($pkgLines lines)"
    Write-Output "[engine-prove] code_fingerprint: $codeFingerprint"
    Write-Output "[engine-prove] Next: agent reads package, writes prove-assertions.json"
}

# === Phase 2: --execute ===
function Invoke-PhaseExecute {
    param([string]$TaskId)
    $evidenceDir = Join-Path $ENGINE_DIR "evidence/$TaskId"
    $assertionsFile = Join-Path $evidenceDir 'prove-assertions.json'
    $proveJson = Join-Path $evidenceDir 'PROVE.json'

    # 1. Check assertions file exists
    if (-not (Test-Path $assertionsFile)) {
        [Console]::Error.WriteLine("[engine-prove] FAIL: $assertionsFile not found. Run --infer first, then agent generates assertions.")
        exit 1
    }

    # 2. Schema validation (python-based, no jq dependency)
    $env:ASSERTIONS_FILE = $assertionsFile
    $env:MAX_A = $MAX_ASSERTIONS
    & $PY -c @"
import json, os, sys

with open(os.environ['ASSERTIONS_FILE'], encoding='utf-8') as f:
    try:
        data = json.load(f)
    except json.JSONDecodeError as e:
        print(f'[engine-prove] FAIL E_SCHEMA: invalid JSON: {e}', file=sys.stderr)
        sys.exit(1)

errors = []
max_a = int(os.environ['MAX_A'])

# Required fields
for field in ['task_id', 'code_fingerprint', 'assertions']:
    if field not in data:
        errors.append(f'missing field: {field}')

if errors:
    for e in errors:
        print(f'[engine-prove] FAIL E_SCHEMA: {e}', file=sys.stderr)
    sys.exit(1)

# task_id format
import re
if not re.match(r'^T-[0-9]{3}$', data['task_id']):
    errors.append(f'invalid task_id: {data["task_id"]}')

# fingerprint format
if not re.match(r'^sha256:[a-f0-9]{64}$', data.get('code_fingerprint', '')):
    errors.append('invalid code_fingerprint format')

# assertions array
assertions = data.get('assertions', [])
if not isinstance(assertions, list):
    errors.append('assertions must be array')
elif len(assertions) == 0:
    errors.append('assertions must have at least 1 item')
elif len(assertions) > max_a:
    errors.append(f'too many assertions ({len(assertions)} > {max_a})')

for i, a in enumerate(assertions):
    prefix = f'assertions[{i}]'
    for req in ['id', 'category', 'command', 'expect_exit', 'rationale']:
        if req not in a:
            errors.append(f'{prefix}: missing {req}')
    if a.get('category') not in ('syntax', 'regression', 'invariant'):
        errors.append(f'{prefix}: invalid category: {a.get("category")}')
    if not re.match(r'^A-[0-9]{2}$', a.get('id', '')):
        errors.append(f'{prefix}: invalid id format: {a.get("id")}')
    if len(a.get('command', '')) > 500:
        errors.append(f'{prefix}: command too long (>500 chars)')
    if len(a.get('rationale', '')) < 20:
        errors.append(f'{prefix}: rationale too short (<20 chars)')
    if a.get('category') == 'invariant' and a.get('revert_would_fail') is not True:
        errors.append(f'{prefix}: invariant must have revert_would_fail=true')

if errors:
    for e in errors:
        print(f'[engine-prove] FAIL E_SCHEMA: {e}', file=sys.stderr)
    sys.exit(1)
"@
    if ($LASTEXITCODE -ne 0) { exit 1 }

    # 3. Staleness guard: recompute fingerprint and compare
    Extract-DiffContext -TaskId $TaskId

    $env:DIFF_BASE = $script:PROVE_DIFF_BASE
    $env:DIFF_FILES = $script:PROVE_DIFF_FILES
    $env:WRITE_SET = $script:PROVE_WRITE_SET
    $currentFp = & $PY -c @"
import hashlib, subprocess, os
diff_base = os.environ['DIFF_BASE']
diff_files = os.environ['DIFF_FILES'].split()
write_set = os.environ.get('WRITE_SET', '').split()
all_files = list(dict.fromkeys(diff_files + write_set))
content = ''
for f in all_files:
    try:
        out = subprocess.check_output(['git', 'diff', diff_base + '..HEAD', '--', f], stderr=subprocess.DEVNULL)
        text = out.decode('utf-8', errors='replace')
        if text.strip():
            content += text
        elif os.path.isfile(f):
            with open(f, 'rb') as fh:
                content += fh.read().decode('utf-8', errors='replace')
    except:
        if os.path.isfile(f):
            with open(f, 'rb') as fh:
                content += fh.read().decode('utf-8', errors='replace')
print('sha256:' + hashlib.sha256(content.encode('utf-8')).hexdigest())
"@ 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $currentFp) {
        $currentFp = 'sha256:0000000000000000000000000000000000000000000000000000000000000000'
    }
    $currentFp = $currentFp.Trim()

    $env:ASSERTIONS_FILE = $assertionsFile
    $claimedFp = & $PY -c @"
import json, os
with open(os.environ['ASSERTIONS_FILE'], encoding='utf-8') as f:
    data = json.load(f)
print(data.get('code_fingerprint', ''))
"@ 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $claimedFp) { $claimedFp = '' }
    $claimedFp = $claimedFp.Trim()

    if ($currentFp -ne $claimedFp) {
        [Console]::Error.WriteLine("[engine-prove] FAIL E_STALE: code changed since inference (current=$currentFp, claimed=$claimedFp). Re-run --infer.")
        exit 1
    }

    # 4. Safety validation (blocklist + anti-tautology + relevance)
    $blockedJson = Load-ConfigValue -Key 'blocked_commands' -Default '["rm","mv","curl","wget","sudo","dd","mkfs","chmod","chown","kill","shutdown","reboot","format","unlink","nc","scp","ssh"]'
    $env:ASSERTIONS_FILE = $assertionsFile
    $env:DIFF_FILES = $script:PROVE_DIFF_FILES
    $env:WRITE_SET = $script:PROVE_WRITE_SET
    $env:ROOT_DIR = $ROOT
    $env:BLOCKED_JSON = $blockedJson
    & $PY -c @"
import json, os, sys, re

with open(os.environ['ASSERTIONS_FILE'], encoding='utf-8') as f:
    data = json.load(f)

blocked = json.loads(os.environ['BLOCKED_JSON'])
diff_files = os.environ['DIFF_FILES'].split()
write_set = os.environ.get('WRITE_SET', '').split()
all_relevant = list(set(diff_files + write_set))
errors = []

for a in data.get('assertions', []):
    cmd = a.get('command', '')
    aid = a.get('id', '?')

    # Blocklist check
    for b in blocked:
        if re.search(r'\b' + re.escape(b) + r'\b', cmd):
            errors.append(f'{aid}: blocked command word "{b}" in: {cmd[:80]}')

    # Tautology check (expanded patterns)
    stripped = cmd.strip()
    tautology_patterns = [
        r'^(true|:|exit 0)\s*$',
        r'^(echo|printf)\s',
        r'^/usr/bin/true',
        r'^bash -c ["\']?(true|:|exit 0)["\']?\s*$',
        r'^test -[efdz] ',
        r'^\[ -[efdz] ',
        r'^grep -c "" ',
    ]
    for pat in tautology_patterns:
        if re.match(pat, stripped):
            errors.append(f'{aid}: tautological command (always succeeds): {stripped[:60]}')
            break

    # Relevance: must reference at least one WRITE-SET/diff file or its basename
    referenced = False
    for f in all_relevant:
        if f in cmd or os.path.basename(f) in cmd:
            referenced = True
            break
    # Accept if command references an actual test script path (tests/*.sh)
    if not referenced:
        test_match = re.search(r'tests/[\w/.-]+\.sh', cmd)
        if test_match and os.path.isfile(os.path.join(os.environ.get('ROOT_DIR', '.'), test_match.group(0))):
            referenced = True
    if not referenced:
        errors.append(f'{aid}: command does not reference any changed file: {cmd[:80]}')

if errors:
    for e in errors:
        print(f'[engine-prove] FAIL E_SAFETY: {e}', file=sys.stderr)
    sys.exit(1)
"@
    if ($LASTEXITCODE -ne 0) { exit 1 }

    # 5. Execute assertions
    Write-Output "[engine-prove] ${TaskId}: executing assertions..."

    $env:ASSERTIONS_FILE = $assertionsFile
    $env:ROOT_DIR = $ROOT
    $env:TIMEOUT_DEFAULT = $ASSERTION_TIMEOUT
    $env:TRUNCATE = $OUTPUT_TRUNCATE
    $resultsJson = & $PY -c @"
import json, os, sys, subprocess, time, hashlib

with open(os.environ['ASSERTIONS_FILE'], encoding='utf-8') as f:
    data = json.load(f)

root = os.environ['ROOT_DIR']
timeout_default = int(os.environ['TIMEOUT_DEFAULT'])
truncate = int(os.environ['TRUNCATE'])

results = []
total = passed = failed = timed_out = 0

for a in data['assertions']:
    total += 1
    aid = a['id']
    cmd = a['command']
    expect_exit = a['expect_exit']
    timeout_s = a.get('timeout_s', timeout_default)

    start = time.time()
    try:
        proc = subprocess.run(
            cmd, shell=True, capture_output=True, timeout=timeout_s,
            cwd=root, stdin=subprocess.DEVNULL
        )
        exit_code = proc.returncode
        output = (proc.stdout + proc.stderr).decode('utf-8', errors='replace')
        status = 'PASS' if exit_code == expect_exit else 'FAIL'
    except subprocess.TimeoutExpired:
        exit_code = 124
        output = f'TIMEOUT after {timeout_s}s'
        status = 'TIMEOUT'
        timed_out += 1
    except Exception as e:
        exit_code = 1
        output = str(e)
        status = 'FAIL'

    duration_ms = int((time.time() - start) * 1000)

    # Output constraints
    if status == 'PASS':
        if a.get('expect_output_contains') and a['expect_output_contains'] not in output:
            status = 'FAIL'
        if a.get('expect_output_not_contains') and a['expect_output_not_contains'] in output:
            status = 'FAIL'

    if status == 'PASS':
        passed += 1
    elif status == 'TIMEOUT':
        pass  # already counted
    else:
        failed += 1

    results.append({
        'id': aid,
        'category': a['category'],
        'command': cmd[:200],
        'status': status,
        'exit_code': exit_code,
        'expect_exit': expect_exit,
        'duration_ms': duration_ms,
        'output_fingerprint': 'sha256:' + hashlib.sha256(output.encode('utf-8')).hexdigest(),
        'output_truncated': output[:truncate]
    })

    # Progress
    print(f'  {aid} [{a["category"]}] {status} ({duration_ms}ms)', file=sys.stderr)

print(json.dumps({'total': total, 'passed': passed, 'failed': failed, 'timed_out': timed_out, 'results': results}))
"@
    if ($LASTEXITCODE -ne 0 -or -not $resultsJson) {
        $resultsJson = '{"total":0,"passed":0,"failed":0,"timed_out":0,"results":[]}'
    }
    $resultsJson = ($resultsJson | Out-String).Trim()

    # Parse results
    $env:RESULTS_JSON = $resultsJson
    $total = & $PY -c "import json,sys,os; d=json.loads(os.environ['RESULTS_JSON']); print(d['total'])" 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $total) { $total = '0' }
    $total = $total.Trim()

    $passed = & $PY -c "import json,sys,os; d=json.loads(os.environ['RESULTS_JSON']); print(d['passed'])" 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $passed) { $passed = '0' }
    $passed = $passed.Trim()

    $failed = & $PY -c "import json,sys,os; d=json.loads(os.environ['RESULTS_JSON']); print(d['failed'])" 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $failed) { $failed = '0' }
    $failed = $failed.Trim()

    $timedOut = & $PY -c "import json,sys,os; d=json.loads(os.environ['RESULTS_JSON']); print(d['timed_out'])" 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $timedOut) { $timedOut = '0' }
    $timedOut = $timedOut.Trim()

    $gate = if ([int]$failed -gt 0 -or [int]$timedOut -gt 0 -or [int]$total -eq 0) { 'FAIL' } else { 'PASS' }

    # 5b. Quality warning: all-syntax-only coverage
    $env:ASSERTIONS_FILE = $assertionsFile
    $syntaxOnly = & $PY -c @"
import json, os
with open(os.environ['ASSERTIONS_FILE'], encoding='utf-8') as f:
    data = json.load(f)
cats = [a.get('category') for a in data.get('assertions', [])]
print('true' if cats and all(c == 'syntax' for c in cats) else 'false')
"@ 2>$null
    if ($syntaxOnly -and $syntaxOnly.Trim() -eq 'true') {
        [Console]::Error.WriteLine("[engine-prove] WARN syntax-only: all assertions are syntax checks. Consider adding regression/invariant assertions for deeper coverage.")
    }

    # 6. Write PROVE.json evidence
    $env:RESULTS_JSON = $resultsJson
    $env:GATE = $gate
    $env:TASK_ID = $TaskId
    $env:FP = $currentFp
    $env:PROVE_FILE = $proveJson
    $env:PROVE_HEAD_COMMIT = $script:PROVE_HEAD_COMMIT
    & $PY -c @"
import json, os, hashlib
from datetime import datetime, timezone

results = json.loads(os.environ['RESULTS_JSON'])
gate = os.environ['GATE']
task_id = os.environ['TASK_ID']
fp = os.environ['FP']
prove_file = os.environ['PROVE_FILE']

# Compute assertions fingerprint
assertions_file = prove_file.replace('PROVE.json', 'prove-assertions.json')
af_hash = ''
if os.path.isfile(assertions_file):
    with open(assertions_file, 'rb') as f:
        af_hash = 'sha256:' + hashlib.sha256(f.read()).hexdigest()

evidence = {
    'schema_version': '1.0',
    'task_id': task_id,
    'command': f'engine prove {task_id} --execute',
    'timestamp': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    'status': gate,
    'code_fingerprint': fp,
    'assertions_fingerprint': af_hash,
    'summary': {
        'total': results['total'],
        'passed': results['passed'],
        'failed': results['failed'],
        'timed_out': results['timed_out']
    },
    'results': results['results'],
    'gate': {
        'decision': gate,
        'rule': 'ALL assertions must pass; any FAIL or TIMEOUT = gate FAIL'
    },
    'write_provenance': {
        'writer': 'engine-prove',
        'commit': os.environ.get('PROVE_HEAD_COMMIT', ''),
        'timestamp': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
        'argv': f'engine prove {task_id} --execute'
    }
}

with open(prove_file, 'w', encoding='utf-8', newline='\n') as f:
    json.dump(evidence, f, indent=2, ensure_ascii=False)
"@
    if ($LASTEXITCODE -ne 0) {
        [Console]::Error.WriteLine("[engine-prove] error writing PROVE.json")
        exit 1
    }

    # 7. Report + exit
    Write-Output "[engine-prove] ${TaskId}: $gate ($passed/$total passed, $failed failed, $timedOut timed out)"
    if ($gate -eq 'PASS') {
        exit 0
    } else {
        exit 1
    }
}

# === Dispatch ===
switch ($Mode) {
    '--infer'   { Invoke-PhaseInfer -TaskId $Task }
    '--execute' { Invoke-PhaseExecute -TaskId $Task }
    default {
        [Console]::Error.WriteLine("Usage: engine prove T-NNN --infer|--execute")
        exit 2
    }
}

} finally {
    if ($lockStream) { $lockStream.Dispose() }
}
