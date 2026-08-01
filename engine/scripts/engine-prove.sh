#!/usr/bin/env bash
# Engine System — Prove: 执行验证子系统 (v6.23.0)
#
# 从 diff 自动推断测试断言并执行。两原子命令 (D-019):
#   engine prove T-NNN --infer    → 产出 prove-package.md (上下文)
#   engine prove T-NNN --execute  → 执行 prove-assertions.json + 门禁
#
# 证据: engine/evidence/T-NNN/PROVE.json
# 安全: 命令黑名单 + 反套言 + 陈旧指纹检测 + timeout

set -euo pipefail
on_error() { echo "[engine-prove] error on line $1" >&2; exit 1; }
trap 'on_error ${LINENO}' ERR

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
ENGINE_DIR="$ROOT/engine"
PROVE_DIR="$ENGINE_DIR/prove"
cd "$ROOT"

# python detection
PY=python3
command -v python3 >/dev/null 2>&1 || PY=python

usage() {
  echo "Usage: engine prove T-NNN --infer|--execute" >&2
  exit 2
}

task="${1:-}"
mode="${2:-}"
[ -z "$task" ] && usage
[ -z "$mode" ] && usage

# === Config loading ===
config_file="$PROVE_DIR/config.json"
load_config_value() {
  local key="$1" default="$2"
  if [ -f "$config_file" ]; then
    CONFIG_FILE="$config_file" KEY="$key" DEFAULT="$default" "$PY" -c "
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
" 2>/dev/null || echo "$default"
  else
    echo "$default"
  fi
}

MAX_ASSERTIONS=$(load_config_value "max_assertions" "10")
ASSERTION_TIMEOUT=$(load_config_value "assertion_timeout_s" "30")
OUTPUT_TRUNCATE=$(load_config_value "output_truncate_chars" "500")

# === Shared: diff extraction (mirrors review-agent-package algorithm) ===
extract_diff_context() {
  local task_id="$1"
  local task_file="$ENGINE_DIR/tasks/$task_id.md"

  if [ ! -f "$task_file" ]; then
    echo "[engine-prove] Error: task card not found: $task_file" >&2
    return 1
  fi

  # Parse WRITE-SET
  local write_set_files
  write_set_files=$(awk '
    /^## WRITE-SET/{f=1;next}
    /^## /{f=0}
    f && /^- /{sub(/^- /,"");sub(/ *#.*/,"");print}
  ' "$task_file" | tr '\n' ' ')

  # Code extensions filter
  local code_extensions_json
  code_extensions_json=$(load_config_value "code_extensions" '[".sh",".ps1",".py",".js",".ts",".go",".rs",".java",".c",".cpp",".rb",".php"]')

  local code_files
  code_files=$(printf '%s\n' $write_set_files | ROOT_DIR="$ROOT" CODE_EXTS="$code_extensions_json" "$PY" -c "
import json, sys, os
exts = set(json.loads(os.environ['CODE_EXTS']))
root = os.environ['ROOT_DIR']
out = []
for line in sys.stdin:
    f = line.strip()
    if not f: continue
    if '*' in f or '?' in f: continue
    _, ext = os.path.splitext(f)
    if ext in exts and os.path.isfile(os.path.join(root, f)):
        out.append(f)
print(' '.join(out))
" 2>/dev/null || echo "")

  # Diff base (task_first_commit algorithm)
  local task_first_commit
  task_first_commit=$(git log --reverse --format="%H" -- "$task_file" 2>/dev/null | head -1 || true)
  if [ -z "$task_first_commit" ]; then
    echo "[engine-prove] Error: no git history for $task_file" >&2
    return 1
  fi

  local head_commit
  head_commit=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
  local diff_base
  diff_base=$(git rev-parse "$task_first_commit^" 2>/dev/null || true)
  if ! printf '%s' "$diff_base" | grep -qE '^[0-9a-f]{40}$'; then
    diff_base="4b825dc642cb6eb9a060e54bf8d69288fbee4904"
  fi

  # Filter to files actually changed
  local diff_files=""
  for f in $code_files; do
    if git diff --name-only "$diff_base"..HEAD -- "$f" 2>/dev/null | grep -q .; then
      diff_files="$diff_files $f"
    fi
  done
  diff_files=$(echo "$diff_files" | tr -s ' ' | sed 's/^ //')

  # Export for caller
  PROVE_WRITE_SET="$write_set_files"
  PROVE_CODE_FILES="$code_files"
  PROVE_DIFF_FILES="$diff_files"
  PROVE_DIFF_BASE="$diff_base"
  PROVE_HEAD_COMMIT="$head_commit"
  PROVE_TASK_GOAL=$(awk '/^## GOAL/{f=1;next}/^## /{f=0}f{print}' "$task_file" | head -5)
}

# === Phase 1: --infer ===
phase_infer() {
  local task_id="$1"
  local evidence_dir="$ENGINE_DIR/evidence/$task_id"
  mkdir -p "$evidence_dir"
  local package_file="$evidence_dir/prove-package.md"

  extract_diff_context "$task_id"

  # No code files → NO-OP
  if [ -z "$PROVE_DIFF_FILES" ]; then
    cat > "$package_file" << EOF
# Prove Package: $task_id

> generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
> status: NO-OP
> reason: no code files in diff range

No assertions needed.
EOF
    echo "[engine-prove] $task_id: no code changes, package marked NO-OP"
    exit 0
  fi

  # Compute code fingerprint (sha256 of concatenated diffs + WRITE-SET file contents)
  local code_fingerprint
  code_fingerprint=$(DIFF_BASE="$PROVE_DIFF_BASE" DIFF_FILES="$PROVE_DIFF_FILES" WRITE_SET="$PROVE_WRITE_SET" "$PY" -c "
import hashlib, subprocess, os
diff_base = os.environ['DIFF_BASE']
diff_files = os.environ['DIFF_FILES'].split()
write_set = os.environ.get('WRITE_SET', '').split()
all_files = list(dict.fromkeys(diff_files + write_set))  # dedupe, preserve order
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
" 2>/dev/null || echo "sha256:0000000000000000000000000000000000000000000000000000000000000000")

  # Extract hunk symbols
  local hunk_symbols
  hunk_symbols=$(git diff -U0 "$PROVE_DIFF_BASE"..HEAD -- $PROVE_DIFF_FILES 2>/dev/null | grep '^@@' | sed 's/.*@@[[:space:]]*//' | grep -v '^$' | head -20 || true)

  # Detect languages → syntax checkers
  local syntax_checks=""
  for f in $PROVE_DIFF_FILES; do
    local ext="${f##*.}"
    case "$ext" in
      sh)  syntax_checks="$syntax_checks\n- bash -n $f" ;;
      py)  syntax_checks="$syntax_checks\n- python -m py_compile $f" ;;
      js)  syntax_checks="$syntax_checks\n- node --check $f" ;;
      json) syntax_checks="$syntax_checks\n- python -m json.tool $f" ;;
    esac
  done

  # Find existing test coverage
  local test_coverage=""
  for f in $PROVE_DIFF_FILES; do
    local basename_f
    basename_f=$(basename "$f")
    local matching_tests
    matching_tests=$(grep -rl "$basename_f" "$ROOT/tests/" 2>/dev/null | head -3 || true)
    if [ -n "$matching_tests" ]; then
      test_coverage="$test_coverage\n- $f covered by:"
      for t in $matching_tests; do
        local rel_t="${t#$ROOT/}"
        test_coverage="$test_coverage\n  - bash $rel_t"
      done
    fi
  done

  # Generate diff content
  local diff_content=""
  for f in $PROVE_DIFF_FILES; do
    local file_diff
    file_diff=$(git diff "$PROVE_DIFF_BASE"..HEAD -- "$f" 2>/dev/null || true)
    if [ -n "$file_diff" ]; then
      diff_content="$diff_content
### $f
\`\`\`diff
$file_diff
\`\`\`
"
    fi
  done

  # Render prove-package.md
  cat > "$package_file" << PKGEOF
# Prove Package: $task_id

> generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
> code_fingerprint: $code_fingerprint
> head_commit: $PROVE_HEAD_COMMIT
> diff_range: ${PROVE_DIFF_BASE:0:8}..${PROVE_HEAD_COMMIT:0:8}
> code_files: $(echo "$PROVE_DIFF_FILES" | wc -w | tr -d ' ')

## GOAL
$PROVE_TASK_GOAL

## WRITE-SET (code files in diff)
$(for f in $PROVE_DIFF_FILES; do echo "- $f"; done)

## WRITE-SET (full, from task card)
$(for f in $PROVE_WRITE_SET; do echo "- $f"; done)

## Hunk Symbols (modified functions/classes)
$(echo "$hunk_symbols" | sed 's/^/- /' | head -20)

## Syntax Checks (auto-detected)
$(echo -e "$syntax_checks")

## Existing Test Coverage
$(if [ -n "$test_coverage" ]; then echo -e "$test_coverage"; else echo "- (none found — agent should generate invariant assertions)"; fi)

## Unified Diff
$diff_content

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
Write engine/evidence/$task_id/prove-assertions.json:
\`\`\`json
{
  "task_id": "$task_id",
  "code_fingerprint": "$code_fingerprint",
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
\`\`\`
PKGEOF

  local pkg_lines
  pkg_lines=$(wc -l < "$package_file" | tr -d ' ')
  echo "[engine-prove] $task_id: prove-package ready ($pkg_lines lines)"
  echo "[engine-prove] code_fingerprint: $code_fingerprint"
  echo "[engine-prove] Next: agent reads package, writes prove-assertions.json"
}

# === Phase 2: --execute ===
phase_execute() {
  local task_id="$1"
  local evidence_dir="$ENGINE_DIR/evidence/$task_id"
  local assertions_file="$evidence_dir/prove-assertions.json"
  local prove_json="$evidence_dir/PROVE.json"
  local lock_file="$evidence_dir/.prove-lock"

  # 0. Concurrent execution lock
  mkdir -p "$evidence_dir"
  if [ -f "$lock_file" ]; then
    local lock_pid
    lock_pid=$(cat "$lock_file" 2>/dev/null || echo "")
    if [ -n "$lock_pid" ] && kill -0 "$lock_pid" 2>/dev/null; then
      echo "[engine-prove] FAIL: another execute is running (pid $lock_pid). Wait or remove $lock_file" >&2
      exit 1
    fi
    # Stale lock — remove
    rm -f "$lock_file"
  fi
  echo "$$" > "$lock_file"
  trap 'rm -f "$lock_file"' EXIT

  # 1. Check assertions file exists
  if [ ! -f "$assertions_file" ]; then
    echo "[engine-prove] FAIL: $assertions_file not found. Run --infer first, then agent generates assertions." >&2
    exit 1
  fi

  # 2. Schema validation (python-based, no jq dependency)
  ASSERTIONS_FILE="$assertions_file" MAX_A="$MAX_ASSERTIONS" "$PY" -c "
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
    errors.append(f'invalid task_id: {data[\"task_id\"]}')

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
        errors.append(f'{prefix}: invalid category: {a.get(\"category\")}')
    if not re.match(r'^A-[0-9]{2}$', a.get('id', '')):
        errors.append(f'{prefix}: invalid id format: {a.get(\"id\")}')
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
" || exit 1

  # 3. Staleness guard: recompute fingerprint and compare
  extract_diff_context "$task_id"
  local current_fp
  current_fp=$(DIFF_BASE="$PROVE_DIFF_BASE" DIFF_FILES="$PROVE_DIFF_FILES" WRITE_SET="$PROVE_WRITE_SET" "$PY" -c "
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
" 2>/dev/null || echo "sha256:0000000000000000000000000000000000000000000000000000000000000000")

  local claimed_fp
  claimed_fp=$(ASSERTIONS_FILE="$assertions_file" "$PY" -c "
import json, os
with open(os.environ['ASSERTIONS_FILE'], encoding='utf-8') as f:
    data = json.load(f)
print(data.get('code_fingerprint', ''))
" 2>/dev/null || echo "")

  if [ "$current_fp" != "$claimed_fp" ]; then
    echo "[engine-prove] FAIL E_STALE: code changed since inference (current=$current_fp, claimed=$claimed_fp). Re-run --infer." >&2
    exit 1
  fi

  # 4. Safety validation (blocklist + anti-tautology + relevance)
  ASSERTIONS_FILE="$assertions_file" DIFF_FILES="$PROVE_DIFF_FILES" WRITE_SET="$PROVE_WRITE_SET" ROOT_DIR="$ROOT" BLOCKED_JSON="$(load_config_value 'blocked_commands' '["rm","mv","curl","wget","sudo","dd","mkfs","chmod","chown","kill","shutdown","reboot","format","unlink","nc","scp","ssh"]')" "$PY" -c "
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
            errors.append(f'{aid}: blocked command word \"{b}\" in: {cmd[:80]}')

    # Tautology check (expanded patterns)
    stripped = cmd.strip()
    tautology_patterns = [
        r'^(true|:|exit 0)\s*$',
        r'^(echo|printf)\s',
        r'^/usr/bin/true',
        r'^bash -c [\"\']?(true|:|exit 0)[\"\']?\s*$',
        r'^test -[efdz] ',
        r'^\[ -[efdz] ',
        r'^grep -c \"\" ',
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
" || exit 1

  # 5. Execute assertions
  echo "[engine-prove] $task_id: executing assertions..."

  local results_json
  results_json=$(ASSERTIONS_FILE="$assertions_file" ROOT_DIR="$ROOT" TIMEOUT_DEFAULT="$ASSERTION_TIMEOUT" TRUNCATE="$OUTPUT_TRUNCATE" "$PY" -c "
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
    print(f'  {aid} [{a[\"category\"]}] {status} ({duration_ms}ms)', file=sys.stderr)

print(json.dumps({'total': total, 'passed': passed, 'failed': failed, 'timed_out': timed_out, 'results': results}))
" || echo '{"total":0,"passed":0,"failed":0,"timed_out":0,"results":[]}')

  # Parse results
  local total passed failed timed_out gate
  total=$(echo "$results_json" | "$PY" -c "import json,sys; d=json.load(sys.stdin); print(d['total'])" 2>/dev/null || echo "0")
  passed=$(echo "$results_json" | "$PY" -c "import json,sys; d=json.load(sys.stdin); print(d['passed'])" 2>/dev/null || echo "0")
  failed=$(echo "$results_json" | "$PY" -c "import json,sys; d=json.load(sys.stdin); print(d['failed'])" 2>/dev/null || echo "0")
  timed_out=$(echo "$results_json" | "$PY" -c "import json,sys; d=json.load(sys.stdin); print(d['timed_out'])" 2>/dev/null || echo "0")

  if [ "$failed" -gt 0 ] || [ "$timed_out" -gt 0 ] || [ "$total" -eq 0 ]; then
    gate="FAIL"
  else
    gate="PASS"
  fi

  # 5b. Quality warning: all-syntax-only coverage
  local syntax_only
  syntax_only=$(ASSERTIONS_FILE="$assertions_file" "$PY" -c "
import json, os
with open(os.environ['ASSERTIONS_FILE'], encoding='utf-8') as f:
    data = json.load(f)
cats = [a.get('category') for a in data.get('assertions', [])]
print('true' if cats and all(c == 'syntax' for c in cats) else 'false')
" 2>/dev/null || echo "false")
  if [ "$syntax_only" = "true" ]; then
    echo "[engine-prove] WARN syntax-only: all assertions are syntax checks. Consider adding regression/invariant assertions for deeper coverage." >&2
  fi

  # 5c. AC cross-anchoring: verify assertions cover task card AC verify commands
  local task_file="$ENGINE_DIR/tasks/$task_id.md"
  local ac_coverage="OK"
  if [ -f "$task_file" ]; then
    ac_coverage=$(TASK_FILE="$task_file" ASSERTIONS_FILE="$assertions_file" "$PY" -c "
import os, re, json

task_file = os.environ['TASK_FILE']
assertions_file = os.environ['ASSERTIONS_FILE']

# Extract AC verify commands from task card
with open(task_file, encoding='utf-8') as f:
    content = f.read()

# Find all verify: commands (multiple formats)
verify_cmds = re.findall(r'verify:\s*(.+)', content)
if not verify_cmds:
    print('OK')  # No ACs declared, nothing to cross-check
    raise SystemExit(0)

# Extract file references from AC verify commands
ac_files = set()
for cmd in verify_cmds:
    # Match path-like tokens (word/word.ext patterns)
    for m in re.finditer(r'[\w./-]+\.\w+', cmd):
        ac_files.add(m.group(0))
    # Also match bare filenames referenced in grep/test commands
    for m in re.finditer(r'(?:grep|cat|bash|source)\s+[\w./-]*?([\w-]+\.\w+)', cmd):
        ac_files.add(m.group(1))

if not ac_files:
    print('OK')  # ACs exist but reference no files, skip
    raise SystemExit(0)

# Extract file references from prove assertions
with open(assertions_file, encoding='utf-8') as f:
    data = json.load(f)

assertion_files = set()
for a in data.get('assertions', []):
    cmd = a.get('command', '')
    for m in re.finditer(r'[\w./-]+\.\w+', cmd):
        assertion_files.add(m.group(0))

# Compute coverage: what fraction of AC-referenced files appear in assertions
covered = ac_files & assertion_files
# Also check basename matches
ac_basenames = {os.path.basename(f) for f in ac_files}
assertion_basenames = {os.path.basename(f) for f in assertion_files}
covered_basenames = ac_basenames & assertion_basenames

total_ac = len(ac_basenames)
covered_count = len(covered_basenames)
ratio = covered_count / total_ac if total_ac > 0 else 1.0

if ratio == 0:
    print('FAIL')
elif ratio < 0.5:
    print('WARN')
else:
    print('OK')
" 2>/dev/null || echo "OK")

    if [ "$ac_coverage" = "FAIL" ]; then
      echo "[engine-prove] FAIL ac-coverage: prove assertions have ZERO overlap with task card AC verify commands." >&2
      gate="FAIL"
    elif [ "$ac_coverage" = "WARN" ]; then
      echo "[engine-prove] WARN ac-coverage: prove assertions cover <50% of files referenced in AC verify commands." >&2
    fi
  fi

  # 6. Write PROVE.json evidence
  RESULTS_JSON="$results_json" GATE="$gate" TASK_ID="$task_id" FP="$current_fp" PROVE_FILE="$prove_json" AC_COVERAGE="$ac_coverage" MODEL_ID="${ENGINE_MODEL_ID:-}" "$PY" -c "
import json, os, hashlib
from datetime import datetime, timezone

results = json.loads(os.environ['RESULTS_JSON'])
gate = os.environ['GATE']
task_id = os.environ['TASK_ID']
fp = os.environ['FP']
prove_file = os.environ['PROVE_FILE']
ac_coverage = os.environ.get('AC_COVERAGE', 'OK')
model_id = os.environ.get('MODEL_ID', '')

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
    'ac_coverage': ac_coverage,
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
        'model_id': model_id,
        'commit': os.environ.get('PROVE_HEAD_COMMIT', ''),
        'timestamp': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
        'argv': f'engine prove {task_id} --execute'
    }
}

with open(prove_file, 'w', encoding='utf-8', newline='\n') as f:
    json.dump(evidence, f, indent=2, ensure_ascii=False)
"

  # 7. Report + exit
  echo "[engine-prove] $task_id: $gate ($passed/$total passed, $failed failed, $timed_out timed out)"
  if [ "$gate" = "PASS" ]; then
    exit 0
  else
    exit 1
  fi
}

# === Dispatch ===
case "$mode" in
  --infer)   phase_infer "$task" ;;
  --execute) phase_execute "$task" ;;
  *)         usage ;;
esac
