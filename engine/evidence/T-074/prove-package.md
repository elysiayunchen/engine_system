# Prove Package: T-074

> generated: 2026-08-01T05:52:09Z
> code_fingerprint: sha256:c50685cb8d49dcdb32d188edd075a465e5b9aff564fad14ade5ed645b7f382e2
> head_commit: 5dc5f97a3ccae7283a777280bf4ea59d0595db6a
> diff_range: 1929578d..5dc5f97a
> code_files: 6

## GOAL

从 diff 自动推断测试断言并执行，让 viber 不需要人工判断代码正确性。两原子命令：`engine prove T-NNN --infer`（准备上下文）→ agent 写断言 → `engine prove T-NNN --execute`（执行 + 门禁）。

## WRITE-SET (code files in diff)
- engine/scripts/engine-prove.sh
- engine/scripts/engine-prove.ps1
- plugin/engine/scripts/engine-prove.sh
- plugin/engine/scripts/engine-prove.ps1
- tests/workstream/test_prove_infer.sh
- tests/workstream/test_prove_execute.sh

## Hunk Symbols (modified functions/classes)
- 

## Syntax Checks (auto-detected)

- bash -n engine/scripts/engine-prove.sh
- bash -n plugin/engine/scripts/engine-prove.sh
- bash -n tests/workstream/test_prove_infer.sh
- bash -n tests/workstream/test_prove_execute.sh

## Existing Test Coverage

- engine/scripts/engine-prove.sh covered by:
  - bash tests/workstream/test_prove_execute.sh
  - bash tests/workstream/test_prove_infer.sh
- plugin/engine/scripts/engine-prove.sh covered by:
  - bash tests/workstream/test_prove_execute.sh
  - bash tests/workstream/test_prove_infer.sh
- tests/workstream/test_prove_infer.sh covered by:
  - bash tests/workstream/test_prove_infer.sh
- tests/workstream/test_prove_execute.sh covered by:
  - bash tests/workstream/test_prove_execute.sh

## Unified Diff

### engine/scripts/engine-prove.sh
```diff
diff --git a/engine/scripts/engine-prove.sh b/engine/scripts/engine-prove.sh
new file mode 100644
index 0000000..7952ed9
--- /dev/null
+++ b/engine/scripts/engine-prove.sh
@@ -0,0 +1,596 @@
+#!/usr/bin/env bash
+# Engine System — Prove: 执行验证子系统 (v6.23.0)
+#
+# 从 diff 自动推断测试断言并执行。两原子命令 (D-019):
+#   engine prove T-NNN --infer    → 产出 prove-package.md (上下文)
+#   engine prove T-NNN --execute  → 执行 prove-assertions.json + 门禁
+#
+# 证据: engine/evidence/T-NNN/PROVE.json
+# 安全: 命令黑名单 + 反套言 + 陈旧指纹检测 + timeout
+
+set -euo pipefail
+on_error() { echo "[engine-prove] error on line $1" >&2; exit 1; }
+trap 'on_error ${LINENO}' ERR
+
+ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
+ENGINE_DIR="$ROOT/engine"
+PROVE_DIR="$ENGINE_DIR/prove"
+cd "$ROOT"
+
+# python detection
+PY=python3
+command -v python3 >/dev/null 2>&1 || PY=python
+
+usage() {
+  echo "Usage: engine prove T-NNN --infer|--execute" >&2
+  exit 2
+}
+
+task="${1:-}"
+mode="${2:-}"
+[ -z "$task" ] && usage
+[ -z "$mode" ] && usage
+
+# === Config loading ===
+config_file="$PROVE_DIR/config.json"
+load_config_value() {
+  local key="$1" default="$2"
+  if [ -f "$config_file" ]; then
+    CONFIG_FILE="$config_file" KEY="$key" DEFAULT="$default" "$PY" -c "
+import json, os
+try:
+    with open(os.environ['CONFIG_FILE']) as f:
+        cfg = json.load(f)
+except:
+    cfg = {}
+defaults = cfg.get('defaults', {})
+overrides = cfg.get('overrides', {})
+merged = dict(defaults)
+for k, v in overrides.items():
+    merged[k] = v
+val = merged.get(os.environ['KEY'], os.environ['DEFAULT'])
+print(val if not isinstance(val, list) else json.dumps(val))
+" 2>/dev/null || echo "$default"
+  else
+    echo "$default"
+  fi
+}
+
+MAX_ASSERTIONS=$(load_config_value "max_assertions" "10")
+ASSERTION_TIMEOUT=$(load_config_value "assertion_timeout_s" "30")
+OUTPUT_TRUNCATE=$(load_config_value "output_truncate_chars" "500")
+
+# === Shared: diff extraction (mirrors review-agent-package algorithm) ===
+extract_diff_context() {
+  local task_id="$1"
+  local task_file="$ENGINE_DIR/tasks/$task_id.md"
+
+  if [ ! -f "$task_file" ]; then
+    echo "[engine-prove] Error: task card not found: $task_file" >&2
+    return 1
+  fi
+
+  # Parse WRITE-SET
+  local write_set_files
+  write_set_files=$(awk '
+    /^## WRITE-SET/{f=1;next}
+    /^## /{f=0}
+    f && /^- /{sub(/^- /,"");sub(/ *#.*/,"");print}
+  ' "$task_file" | tr '\n' ' ')
+
+  # Code extensions filter
+  local code_extensions_json
+  code_extensions_json=$(load_config_value "code_extensions" '[".sh",".ps1",".py",".js",".ts",".go",".rs",".java",".c",".cpp",".rb",".php"]')
+
+  local code_files
+  code_files=$(printf '%s\n' $write_set_files | ROOT_DIR="$ROOT" CODE_EXTS="$code_extensions_json" "$PY" -c "
+import json, sys, os
+exts = set(json.loads(os.environ['CODE_EXTS']))
+root = os.environ['ROOT_DIR']
+out = []
+for line in sys.stdin:
+    f = line.strip()
+    if not f: continue
+    if '*' in f or '?' in f: continue
+    _, ext = os.path.splitext(f)
+    if ext in exts and os.path.isfile(os.path.join(root, f)):
+        out.append(f)
+print(' '.join(out))
+" 2>/dev/null || echo "")
+
+  # Diff base (task_first_commit algorithm)
+  local task_first_commit
+  task_first_commit=$(git log --reverse --format="%H" -- "$task_file" 2>/dev/null | head -1 || true)
+  if [ -z "$task_first_commit" ]; then
+    echo "[engine-prove] Error: no git history for $task_file" >&2
+    return 1
+  fi
+
+  local head_commit
+  head_commit=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
+  local diff_base
+  diff_base=$(git rev-parse "$task_first_commit^" 2>/dev/null || true)
+  if ! printf '%s' "$diff_base" | grep -qE '^[0-9a-f]{40}$'; then
+    diff_base="4b825dc642cb6eb9a060e54bf8d69288fbee4904"
+  fi
+
+  # Filter to files actually changed
+  local diff_files=""
+  for f in $code_files; do
+    if git diff --name-only "$diff_base"..HEAD -- "$f" 2>/dev/null | grep -q .; then
+      diff_files="$diff_files $f"
+    fi
+  done
+  diff_files=$(echo "$diff_files" | tr -s ' ' | sed 's/^ //')
+
+  # Export for caller
+  PROVE_WRITE_SET="$write_set_files"
+  PROVE_CODE_FILES="$code_files"
+  PROVE_DIFF_FILES="$diff_files"
+  PROVE_DIFF_BASE="$diff_base"
+  PROVE_HEAD_COMMIT="$head_commit"
+  PROVE_TASK_GOAL=$(awk '/^## GOAL/{f=1;next}/^## /{f=0}f{print}' "$task_file" | head -5)
+}
+
+# === Phase 1: --infer ===
+phase_infer() {
+  local task_id="$1"
+  local evidence_dir="$ENGINE_DIR/evidence/$task_id"
+  mkdir -p "$evidence_dir"
+  local package_file="$evidence_dir/prove-package.md"
+
+  extract_diff_context "$task_id"
+
+  # No code files → NO-OP
+  if [ -z "$PROVE_DIFF_FILES" ]; then
+    cat > "$package_file" << EOF
+# Prove Package: $task_id
+
+> generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
+> status: NO-OP
+> reason: no code files in diff range
+
+No assertions needed.
+EOF
+    echo "[engine-prove] $task_id: no code changes, package marked NO-OP"
+    exit 0
+  fi
+
+  # Compute code fingerprint (sha256 of concatenated diffs)
+  local code_fingerprint
+  code_fingerprint=$(DIFF_BASE="$PROVE_DIFF_BASE" DIFF_FILES="$PROVE_DIFF_FILES" "$PY" -c "
+import hashlib, subprocess, os
+diff_base = os.environ['DIFF_BASE']
+files = os.environ['DIFF_FILES'].split()
+content = ''
+for f in files:
+    try:
+        out = subprocess.check_output(['git', 'diff', diff_base + '..HEAD', '--', f], stderr=subprocess.DEVNULL)
+        content += out.decode('utf-8', errors='replace')
+    except:
+        pass
+print('sha256:' + hashlib.sha256(content.encode('utf-8')).hexdigest())
+" 2>/dev/null || echo "sha256:0000000000000000000000000000000000000000000000000000000000000000")
+
+  # Extract hunk symbols
+  local hunk_symbols
+  hunk_symbols=$(git diff -U0 "$PROVE_DIFF_BASE"..HEAD -- $PROVE_DIFF_FILES 2>/dev/null | grep '^@@' | sed 's/.*@@[[:space:]]*//' | grep -v '^$' | head -20 || true)
+
+  # Detect languages → syntax checkers
+  local syntax_checks=""
+  for f in $PROVE_DIFF_FILES; do
+    local ext="${f##*.}"
+    case "$ext" in
+      sh)  syntax_checks="$syntax_checks\n- bash -n $f" ;;
+      py)  syntax_checks="$syntax_checks\n- python -m py_compile $f" ;;
+      js)  syntax_checks="$syntax_checks\n- node --check $f" ;;
+      json) syntax_checks="$syntax_checks\n- python -m json.tool $f" ;;
+    esac
+  done
+
+  # Find existing test coverage
+  local test_coverage=""
+  for f in $PROVE_DIFF_FILES; do
+    local basename_f
+    basename_f=$(basename "$f")
+    local matching_tests
+    matching_tests=$(grep -rl "$basename_f" "$ROOT/tests/" 2>/dev/null | head -3 || true)
+    if [ -n "$matching_tests" ]; then
+      test_coverage="$test_coverage\n- $f covered by:"
+      for t in $matching_tests; do
+        local rel_t="${t#$ROOT/}"
+        test_coverage="$test_coverage\n  - bash $rel_t"
+      done
+    fi
+  done
+
+  # Generate diff content
+  local diff_content=""
+  for f in $PROVE_DIFF_FILES; do
+    local file_diff
+    file_diff=$(git diff "$PROVE_DIFF_BASE"..HEAD -- "$f" 2>/dev/null || true)
+    if [ -n "$file_diff" ]; then
+      diff_content="$diff_content
+### $f
+\`\`\`diff
+$file_diff
+\`\`\`
+"
+    fi
+  done
+
+  # Render prove-package.md
+  cat > "$package_file" << PKGEOF
+# Prove Package: $task_id
+
+> generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
+> code_fingerprint: $code_fingerprint
+> head_commit: $PROVE_HEAD_COMMIT
+> diff_range: ${PROVE_DIFF_BASE:0:8}..${PROVE_HEAD_COMMIT:0:8}
+> code_files: $(echo "$PROVE_DIFF_FILES" | wc -w | tr -d ' ')
+
+## GOAL
+$PROVE_TASK_GOAL
+
+## WRITE-SET (code files in diff)
+$(for f in $PROVE_DIFF_FILES; do echo "- $f"; done)
+
+## Hunk Symbols (modified functions/classes)
+$(echo "$hunk_symbols" | sed 's/^/- /' | head -20)
+
+## Syntax Checks (auto-detected)
+$(echo -e "$syntax_checks")
+
+## Existing Test Coverage
+$(if [ -n "$test_coverage" ]; then echo -e "$test_coverage"; else echo "- (none found — agent should generate invariant assertions)"; fi)
+
+## Unified Diff
+$diff_content
+
+## Assertion Generation Instructions
+
+Generate prove-assertions.json with categories:
+- **syntax**: Verify modified files parse correctly (use syntax checks above)
+- **regression**: Run existing tests covering modified files (use test coverage above)
+- **invariant**: Property tests specific to THIS change that would FAIL if reverted
+
+### Anti-Tautology Rules (MANDATORY)
+1. NEVER emit commands that always succeed (true, :, echo-only)
+2. Each assertion MUST reference a specific file or symbol from this diff
+3. Invariant assertions MUST have revert_would_fail=true
+4. Maximum $MAX_ASSERTIONS assertions total
+5. Commands must NOT contain: rm, mv, curl, wget, sudo, dd, mkfs, chmod, kill
+6. rationale must be >=20 chars and explain WHY this assertion catches regressions
+
+### Output Schema
+Write engine/evidence/$task_id/prove-assertions.json:
+\`\`\`json
+{
+  "task_id": "$task_id",
+  "code_fingerprint": "$code_fingerprint",
+  "assertions": [
+    {
+      "id": "A-01",
+      "category": "syntax|regression|invariant",
+      "command": "<shell command>",
+      "expect_exit": 0,
+      "timeout_s": 30,
+      "rationale": "<why this matters, >=20 chars>",
+      "revert_would_fail": false
+    }
+  ]
+}
+\`\`\`
+PKGEOF
+
+  local pkg_lines
+  pkg_lines=$(wc -l < "$package_file" | tr -d ' ')
+  echo "[engine-prove] $task_id: prove-package ready ($pkg_lines lines)"
+  echo "[engine-prove] code_fingerprint: $code_fingerprint"
+  echo "[engine-prove] Next: agent reads package, writes prove-assertions.json"
+}
+
+# === Phase 2: --execute ===
+phase_execute() {
+  local task_id="$1"
+  local evidence_dir="$ENGINE_DIR/evidence/$task_id"
+  local assertions_file="$evidence_dir/prove-assertions.json"
+  local prove_json="$evidence_dir/PROVE.json"
+
+  # 1. Check assertions file exists
+  if [ ! -f "$assertions_file" ]; then
+    echo "[engine-prove] FAIL: $assertions_file not found. Run --infer first, then agent generates assertions." >&2
+    exit 1
+  fi
+
+  # 2. Schema validation (python-based, no jq dependency)
+  ASSERTIONS_FILE="$assertions_file" MAX_A="$MAX_ASSERTIONS" "$PY" -c "
+import json, os, sys
+
+with open(os.environ['ASSERTIONS_FILE'], encoding='utf-8') as f:
+    try:
+        data = json.load(f)
+    except json.JSONDecodeError as e:
+        print(f'[engine-prove] FAIL E_SCHEMA: invalid JSON: {e}', file=sys.stderr)
+        sys.exit(1)
+
+errors = []
+max_a = int(os.environ['MAX_A'])
+
+# Required fields
+for field in ['task_id', 'code_fingerprint', 'assertions']:
+    if field not in data:
+        errors.append(f'missing field: {field}')
+
+if errors:
+    for e in errors:
+        print(f'[engine-prove] FAIL E_SCHEMA: {e}', file=sys.stderr)
+    sys.exit(1)
+
+# task_id format
+import re
+if not re.match(r'^T-[0-9]{3}$', data['task_id']):
+    errors.append(f'invalid task_id: {data[\"task_id\"]}')
+
+# fingerprint format
+if not re.match(r'^sha256:[a-f0-9]{64}$', data.get('code_fingerprint', '')):
+    errors.append('invalid code_fingerprint format')
+
+# assertions array
+assertions = data.get('assertions', [])
+if not isinstance(assertions, list):
+    errors.append('assertions must be array')
+elif len(assertions) == 0:
+    errors.append('assertions must have at least 1 item')
+elif len(assertions) > max_a:
+    errors.append(f'too many assertions ({len(assertions)} > {max_a})')
+
+for i, a in enumerate(assertions):
+    prefix = f'assertions[{i}]'
+    for req in ['id', 'category', 'command', 'expect_exit', 'rationale']:
+        if req not in a:
+            errors.append(f'{prefix}: missing {req}')
+    if a.get('category') not in ('syntax', 'regression', 'invariant'):
+        errors.append(f'{prefix}: invalid category: {a.get(\"category\")}')
+    if not re.match(r'^A-[0-9]{2}$', a.get('id', '')):
+        errors.append(f'{prefix}: invalid id format: {a.get(\"id\")}')
+    if len(a.get('command', '')) > 500:
+        errors.append(f'{prefix}: command too long (>500 chars)')
+    if len(a.get('rationale', '')) < 20:
+        errors.append(f'{prefix}: rationale too short (<20 chars)')
+    if a.get('category') == 'invariant' and a.get('revert_would_fail') is not True:
+        errors.append(f'{prefix}: invariant must have revert_would_fail=true')
+
+if errors:
+    for e in errors:
+        print(f'[engine-prove] FAIL E_SCHEMA: {e}', file=sys.stderr)
+    sys.exit(1)
+" || exit 1
+
+  # 3. Staleness guard: recompute fingerprint and compare
+  extract_diff_context "$task_id"
+  local current_fp
+  current_fp=$(DIFF_BASE="$PROVE_DIFF_BASE" DIFF_FILES="$PROVE_DIFF_FILES" "$PY" -c "
+import hashlib, subprocess, os
+diff_base = os.environ['DIFF_BASE']
+files = os.environ['DIFF_FILES'].split()
+content = ''
+for f in files:
+    try:
+        out = subprocess.check_output(['git', 'diff', diff_base + '..HEAD', '--', f], stderr=subprocess.DEVNULL)
+        content += out.decode('utf-8', errors='replace')
+    except:
+        pass
+print('sha256:' + hashlib.sha256(content.encode('utf-8')).hexdigest())
+" 2>/dev/null || echo "sha256:0000000000000000000000000000000000000000000000000000000000000000")
+
+  local claimed_fp
+  claimed_fp=$(ASSERTIONS_FILE="$assertions_file" "$PY" -c "
+import json, os
+with open(os.environ['ASSERTIONS_FILE'], encoding='utf-8') as f:
+    data = json.load(f)
+print(data.get('code_fingerprint', ''))
+" 2>/dev/null || echo "")
+
+  if [ "$current_fp" != "$claimed_fp" ]; then
+    echo "[engine-prove] FAIL E_STALE: code changed since inference (current=$current_fp, claimed=$claimed_fp). Re-run --infer." >&2
+    exit 1
+  fi
+
+  # 4. Safety validation (blocklist + anti-tautology + relevance)
+  ASSERTIONS_FILE="$assertions_file" DIFF_FILES="$PROVE_DIFF_FILES" BLOCKED_JSON="$(load_config_value 'blocked_commands' '["rm","mv","curl","wget","sudo","dd","mkfs"]')" "$PY" -c "
+import json, os, sys, re
+
+with open(os.environ['ASSERTIONS_FILE'], encoding='utf-8') as f:
+    data = json.load(f)
+
+blocked = json.loads(os.environ['BLOCKED_JSON'])
+diff_files = os.environ['DIFF_FILES'].split()
+errors = []
+
+for a in data.get('assertions', []):
+    cmd = a.get('command', '')
+    aid = a.get('id', '?')
+
+    # Blocklist check
+    for b in blocked:
+        if re.search(r'\b' + re.escape(b) + r'\b', cmd):
+            errors.append(f'{aid}: blocked command word \"{b}\" in: {cmd[:80]}')
+
+    # Tautology check
+    stripped = cmd.strip()
+    if stripped in ('true', ':', 'exit 0') or re.match(r'^(echo|printf)\s', stripped):
+        errors.append(f'{aid}: tautological command (always succeeds): {stripped[:60]}')
+
+    # Relevance: must reference at least one diff file or its basename
+    referenced = False
+    for f in diff_files:
+        if f in cmd or os.path.basename(f) in cmd:
+            referenced = True
+            break
+    # Also accept if command references a test file that covers diff files
+    if not referenced and 'test' in cmd.lower():
+        referenced = True  # test commands are assumed relevant
+    if not referenced:
+        errors.append(f'{aid}: command does not reference any changed file: {cmd[:80]}')
+
+if errors:
+    for e in errors:
+        print(f'[engine-prove] FAIL E_SAFETY: {e}', file=sys.stderr)
+    sys.exit(1)
+" || exit 1
+
+  # 5. Execute assertions
+  echo "[engine-prove] $task_id: executing assertions..."
+
+  local results_json
+  results_json=$(ASSERTIONS_FILE="$assertions_file" ROOT_DIR="$ROOT" TIMEOUT_DEFAULT="$ASSERTION_TIMEOUT" TRUNCATE="$OUTPUT_TRUNCATE" "$PY" -c "
+import json, os, sys, subprocess, time, hashlib
+
+with open(os.environ['ASSERTIONS_FILE'], encoding='utf-8') as f:
+    data = json.load(f)
+
+root = os.environ['ROOT_DIR']
+timeout_default = int(os.environ['TIMEOUT_DEFAULT'])
+truncate = int(os.environ['TRUNCATE'])
+
+results = []
+total = passed = failed = timed_out = 0
+
+for a in data['assertions']:
+    total += 1
+    aid = a['id']
+    cmd = a['command']
+    expect_exit = a['expect_exit']
+    timeout_s = a.get('timeout_s', timeout_default)
+
+    start = time.time()
+    try:
+        proc = subprocess.run(
+            cmd, shell=True, capture_output=True, timeout=timeout_s,
+            cwd=root, stdin=subprocess.DEVNULL
+        )
+        exit_code = proc.returncode
+        output = (proc.stdout + proc.stderr).decode('utf-8', errors='replace')
+        status = 'PASS' if exit_code == expect_exit else 'FAIL'
+    except subprocess.TimeoutExpired:
+        exit_code = 124
+        output = f'TIMEOUT after {timeout_s}s'
+        status = 'TIMEOUT'
+        timed_out += 1
+    except Exception as e:
+        exit_code = 1
+        output = str(e)
+        status = 'FAIL'
+
+    duration_ms = int((time.time() - start) * 1000)
+
+    # Output constraints
+    if status == 'PASS':
+        if a.get('expect_output_contains') and a['expect_output_contains'] not in output:
+            status = 'FAIL'
+        if a.get('expect_output_not_contains') and a['expect_output_not_contains'] in output:
+            status = 'FAIL'
+
+    if status == 'PASS':
+        passed += 1
+    elif status == 'TIMEOUT':
+        pass  # already counted
+    else:
+        failed += 1
+
+    results.append({
+        'id': aid,
+        'category': a['category'],
+        'command': cmd[:200],
+        'status': status,
+        'exit_code': exit_code,
+        'expect_exit': expect_exit,
+        'duration_ms': duration_ms,
+        'output_fingerprint': 'sha256:' + hashlib.sha256(output.encode('utf-8')).hexdigest(),
+        'output_truncated': output[:truncate]
+    })
+
+    # Progress
+    print(f'  {aid} [{a[\"category\"]}] {status} ({duration_ms}ms)', file=sys.stderr)
+
+print(json.dumps({'total': total, 'passed': passed, 'failed': failed, 'timed_out': timed_out, 'results': results}))
+" || echo '{"total":0,"passed":0,"failed":0,"timed_out":0,"results":[]}')
+
+  # Parse results
+  local total passed failed timed_out gate
+  total=$(echo "$results_json" | "$PY" -c "import json,sys; d=json.load(sys.stdin); print(d['total'])" 2>/dev/null || echo "0")
+  passed=$(echo "$results_json" | "$PY" -c "import json,sys; d=json.load(sys.stdin); print(d['passed'])" 2>/dev/null || echo "0")
+  failed=$(echo "$results_json" | "$PY" -c "import json,sys; d=json.load(sys.stdin); print(d['failed'])" 2>/dev/null || echo "0")
+  timed_out=$(echo "$results_json" | "$PY" -c "import json,sys; d=json.load(sys.stdin); print(d['timed_out'])" 2>/dev/null || echo "0")
+
+  if [ "$failed" -gt 0 ] || [ "$timed_out" -gt 0 ]; then
+    gate="FAIL"
+  else
+    gate="PASS"
+  fi
+
+  # 6. Write PROVE.json evidence
+  RESULTS_JSON="$results_json" GATE="$gate" TASK_ID="$task_id" FP="$current_fp" PROVE_FILE="$prove_json" "$PY" -c "
+import json, os, hashlib
+from datetime import datetime, timezone
+
+results = json.loads(os.environ['RESULTS_JSON'])
+gate = os.environ['GATE']
+task_id = os.environ['TASK_ID']
+fp = os.environ['FP']
+prove_file = os.environ['PROVE_FILE']
+
+# Compute assertions fingerprint
+assertions_file = prove_file.replace('PROVE.json', 'prove-assertions.json')
+af_hash = ''
+if os.path.isfile(assertions_file):
+    with open(assertions_file, 'rb') as f:
+        af_hash = 'sha256:' + hashlib.sha256(f.read()).hexdigest()
+
+evidence = {
+    'schema_version': '1.0',
+    'task_id': task_id,
+    'command': f'engine prove {task_id} --execute',
+    'timestamp': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
+    'status': gate,
+    'code_fingerprint': fp,
+    'assertions_fingerprint': af_hash,
+    'summary': {
+        'total': results['total'],
+        'passed': results['passed'],
+        'failed': results['failed'],
+        'timed_out': results['timed_out']
+    },
+    'results': results['results'],
+    'gate': {
+        'decision': gate,
+        'rule': 'ALL assertions must pass; any FAIL or TIMEOUT = gate FAIL'
+    },
+    'write_provenance': {
+        'writer': 'engine-prove',
+        'commit': os.environ.get('PROVE_HEAD_COMMIT', ''),
+        'timestamp': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
+        'argv': f'engine prove {task_id} --execute'
+    }
+}
+
+with open(prove_file, 'w', encoding='utf-8', newline='\n') as f:
+    json.dump(evidence, f, indent=2, ensure_ascii=False)
+"
+
+  # 7. Report + exit
+  echo "[engine-prove] $task_id: $gate ($passed/$total passed, $failed failed, $timed_out timed out)"
+  if [ "$gate" = "PASS" ]; then
+    exit 0
+  else
+    exit 1
+  fi
+}
+
+# === Dispatch ===
+case "$mode" in
+  --infer)   phase_infer "$task" ;;
+  --execute) phase_execute "$task" ;;
+  *)         usage ;;
+esac
```

### engine/scripts/engine-prove.ps1
```diff
diff --git a/engine/scripts/engine-prove.ps1 b/engine/scripts/engine-prove.ps1
new file mode 100644
index 0000000..e2a7688
--- /dev/null
+++ b/engine/scripts/engine-prove.ps1
@@ -0,0 +1,712 @@
+# Engine System — Prove: 执行验证子系统 (v6.23.0) [PowerShell behavioral mirror]
+#
+# 从 diff 自动推断测试断言并执行。两原子命令 (D-019):
+#   engine prove T-NNN --infer    → 产出 prove-package.md (上下文)
+#   engine prove T-NNN --execute  → 执行 prove-assertions.json + 门禁
+#
+# 证据: engine/evidence/T-NNN/PROVE.json
+# 安全: 命令黑名单 + 反套言 + 陈旧指纹检测 + timeout
+#
+# Usage: pwsh -File engine/scripts/engine-prove.ps1 -Task T-NNN -Mode --infer|--execute
+
+param(
+    [Parameter(Mandatory=$false)][string]$Task,
+    [Parameter(Mandatory=$false)][string]$Mode
+)
+
+$ErrorActionPreference = 'Stop'
+trap { [Console]::Error.WriteLine("[engine-prove] error: $_"); exit 1 }
+
+$ROOT = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (Get-Location).Path }
+$ENGINE_DIR = Join-Path $ROOT 'engine'
+$PROVE_DIR = Join-Path $ENGINE_DIR 'prove'
+
+Set-Location $ROOT
+
+# python detection
+$PY = 'python3'
+if (-not (Get-Command python3 -ErrorAction SilentlyContinue)) { $PY = 'python' }
+if (-not (Get-Command $PY -ErrorAction SilentlyContinue)) {
+    [Console]::Error.WriteLine("[engine-prove] error: python not found")
+    exit 1
+}
+
+# === Usage ===
+if (-not $Task -or -not $Mode) {
+    [Console]::Error.WriteLine("Usage: engine prove T-NNN --infer|--execute")
+    exit 2
+}
+if ($Mode -notin @('--infer', '--execute')) {
+    [Console]::Error.WriteLine("Usage: engine prove T-NNN --infer|--execute")
+    exit 2
+}
+
+# === FileStream lock (concurrency guard) ===
+if (-not (Test-Path $PROVE_DIR)) { New-Item -ItemType Directory -Path $PROVE_DIR -Force | Out-Null }
+$lockPath = Join-Path $PROVE_DIR ".prove-lock.$Task"
+try {
+    $lockStream = [System.IO.File]::Open($lockPath, 'Create', 'ReadWrite', 'None')
+} catch {
+    [Console]::Error.WriteLine("[engine-prove] another prove process running for $Task")
+    exit 1
+}
+
+try {
+
+# === Config loading ===
+$configFile = Join-Path $PROVE_DIR 'config.json'
+
+function Load-ConfigValue {
+    param([string]$Key, [string]$Default)
+    if (-not (Test-Path $configFile)) { return $Default }
+    $env:CONFIG_FILE = $configFile
+    $env:KEY = $Key
+    $env:DEFAULT = $Default
+    $result = & $PY -c @"
+import json, os
+try:
+    with open(os.environ['CONFIG_FILE']) as f:
+        cfg = json.load(f)
+except:
+    cfg = {}
+defaults = cfg.get('defaults', {})
+overrides = cfg.get('overrides', {})
+merged = dict(defaults)
+for k, v in overrides.items():
+    merged[k] = v
+val = merged.get(os.environ['KEY'], os.environ['DEFAULT'])
+print(val if not isinstance(val, list) else json.dumps(val))
+"@ 2>$null
+    if ($LASTEXITCODE -ne 0 -or -not $result) { return $Default }
+    return $result.Trim()
+}
+
+$MAX_ASSERTIONS = Load-ConfigValue -Key 'max_assertions' -Default '10'
+$ASSERTION_TIMEOUT = Load-ConfigValue -Key 'assertion_timeout_s' -Default '30'
+$OUTPUT_TRUNCATE = Load-ConfigValue -Key 'output_truncate_chars' -Default '500'
+
+# === Shared: diff extraction (mirrors review-agent-package algorithm) ===
+$script:PROVE_WRITE_SET = ''
+$script:PROVE_CODE_FILES = ''
+$script:PROVE_DIFF_FILES = ''
+$script:PROVE_DIFF_BASE = ''
+$script:PROVE_HEAD_COMMIT = ''
+$script:PROVE_TASK_GOAL = ''
+
+function Extract-DiffContext {
+    param([string]$TaskId)
+    $taskFile = Join-Path $ENGINE_DIR "tasks/$TaskId.md"
+
+    if (-not (Test-Path $taskFile)) {
+        [Console]::Error.WriteLine("[engine-prove] Error: task card not found: $taskFile")
+        exit 1
+    }
+
+    # Parse WRITE-SET
+    $writeSetFiles = @()
+    $inWriteSet = $false
+    foreach ($line in (Get-Content $taskFile -Encoding UTF8)) {
+        if ($line -match '^## WRITE-SET') { $inWriteSet = $true; continue }
+        if ($line -match '^## ' -and $inWriteSet) { $inWriteSet = $false; continue }
+        if ($inWriteSet -and $line -match '^- (.+)') {
+            $f = $Matches[1] -replace '\s*#.*$', ''
+            $writeSetFiles += $f.Trim()
+        }
+    }
+    $script:PROVE_WRITE_SET = ($writeSetFiles -join ' ')
+
+    # Code extensions filter
+    $codeExtensionsJson = Load-ConfigValue -Key 'code_extensions' -Default '[".sh",".ps1",".py",".js",".ts",".go",".rs",".java",".c",".cpp",".rb",".php"]'
+
+    $env:ROOT_DIR = $ROOT
+    $env:CODE_EXTS = $codeExtensionsJson
+    $env:WRITE_SET_INPUT = ($writeSetFiles -join "`n")
+    $codeFilesResult = & $PY -c @"
+import json, sys, os
+exts = set(json.loads(os.environ['CODE_EXTS']))
+root = os.environ['ROOT_DIR']
+out = []
+for line in os.environ['WRITE_SET_INPUT'].splitlines():
+    f = line.strip()
+    if not f: continue
+    if '*' in f or '?' in f: continue
+    _, ext = os.path.splitext(f)
+    if ext in exts and os.path.isfile(os.path.join(root, f)):
+        out.append(f)
+print(' '.join(out))
+"@ 2>$null
+    if ($LASTEXITCODE -ne 0) { $codeFilesResult = '' }
+    $script:PROVE_CODE_FILES = if ($codeFilesResult) { $codeFilesResult.Trim() } else { '' }
+
+    # Diff base (task_first_commit algorithm)
+    $taskFirstCommit = (git -C $ROOT log --reverse --format="%H" -- "engine/tasks/$TaskId.md" 2>$null | Select-Object -First 1)
+    if (-not $taskFirstCommit) {
+        [Console]::Error.WriteLine("[engine-prove] Error: no git history for $taskFile")
+        exit 1
+    }
+
+    $script:PROVE_HEAD_COMMIT = (git -C $ROOT rev-parse HEAD 2>$null)
+    if (-not $script:PROVE_HEAD_COMMIT) { $script:PROVE_HEAD_COMMIT = 'unknown' }
+
+    $diffBase = (cmd /c "git -C `"$ROOT`" rev-parse `"$taskFirstCommit^`" 2>nul")
+    if (-not ($diffBase -match '^[0-9a-f]{40}$')) {
+        $diffBase = '4b825dc642cb6eb9a060e54bf8d69288fbee4904'
+    }
+    $script:PROVE_DIFF_BASE = $diffBase.Trim()
+
+    # Filter to files actually changed
+    $diffFiles = @()
+    $codeFileList = if ($script:PROVE_CODE_FILES) { $script:PROVE_CODE_FILES -split '\s+' } else { @() }
+    foreach ($f in $codeFileList) {
+        if (-not $f) { continue }
+        $changed = (git -C $ROOT diff --name-only "$($script:PROVE_DIFF_BASE)..HEAD" -- $f 2>$null)
+        if ($changed) { $diffFiles += $f }
+    }
+    $script:PROVE_DIFF_FILES = ($diffFiles -join ' ')
+
+    # Extract GOAL
+    $goalLines = @()
+    $inGoal = $false
+    foreach ($line in (Get-Content $taskFile -Encoding UTF8)) {
+        if ($line -match '^## GOAL') { $inGoal = $true; continue }
+        if ($line -match '^## ' -and $inGoal) { break }
+        if ($inGoal) { $goalLines += $line }
+    }
+    $script:PROVE_TASK_GOAL = ($goalLines | Select-Object -First 5) -join "`n"
+}
+
+# === Phase 1: --infer ===
+function Invoke-PhaseInfer {
+    param([string]$TaskId)
+    $evidenceDir = Join-Path $ENGINE_DIR "evidence/$TaskId"
+    if (-not (Test-Path $evidenceDir)) { New-Item -ItemType Directory -Path $evidenceDir -Force | Out-Null }
+    $packageFile = Join-Path $evidenceDir 'prove-package.md'
+
+    Extract-DiffContext -TaskId $TaskId
+
+    # No code files -> NO-OP
+    if (-not $script:PROVE_DIFF_FILES) {
+        $ts = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
+        $noopContent = @"
+# Prove Package: $TaskId
+
+> generated: $ts
+> status: NO-OP
+> reason: no code files in diff range
+
+No assertions needed.
+"@
+        Set-Content -Path $packageFile -Value $noopContent -Encoding UTF8
+        Write-Output "[engine-prove] ${TaskId}: no code changes, package marked NO-OP"
+        exit 0
+    }
+
+    # Compute code fingerprint (sha256 of concatenated diffs)
+    $env:DIFF_BASE = $script:PROVE_DIFF_BASE
+    $env:DIFF_FILES = $script:PROVE_DIFF_FILES
+    $codeFingerprint = & $PY -c @"
+import hashlib, subprocess, os
+diff_base = os.environ['DIFF_BASE']
+files = os.environ['DIFF_FILES'].split()
+content = ''
+for f in files:
+    try:
+        out = subprocess.check_output(['git', 'diff', diff_base + '..HEAD', '--', f], stderr=subprocess.DEVNULL)
+        content += out.decode('utf-8', errors='replace')
+    except:
+        pass
+print('sha256:' + hashlib.sha256(content.encode('utf-8')).hexdigest())
+"@ 2>$null
+    if ($LASTEXITCODE -ne 0 -or -not $codeFingerprint) {
+        $codeFingerprint = 'sha256:0000000000000000000000000000000000000000000000000000000000000000'
+    }
+    $codeFingerprint = $codeFingerprint.Trim()
+
+    # Extract hunk symbols
+    $diffFileList = $script:PROVE_DIFF_FILES -split '\s+'
+    $hunkSymbols = (git -C $ROOT diff -U0 "$($script:PROVE_DIFF_BASE)..HEAD" -- @diffFileList 2>$null |
+        Where-Object { $_ -match '^@@' } |
+        ForEach-Object { $_ -replace '.*@@\s*', '' } |
+        Where-Object { $_ -ne '' } |
+        Select-Object -First 20)
+    if (-not $hunkSymbols) { $hunkSymbols = @() }
+
+    # Detect languages -> syntax checkers
+    $syntaxChecks = @()
+    foreach ($f in $diffFileList) {
+        if (-not $f) { continue }
+        $ext = [System.IO.Path]::GetExtension($f).TrimStart('.')
+        switch ($ext) {
+            'sh'   { $syntaxChecks += "- bash -n $f" }
+            'py'   { $syntaxChecks += "- python -m py_compile $f" }
+            'js'   { $syntaxChecks += "- node --check $f" }
+            'json' { $syntaxChecks += "- python -m json.tool $f" }
+        }
+    }
+
+    # Find existing test coverage
+    $testCoverage = @()
+    $testsDir = Join-Path $ROOT 'tests'
+    foreach ($f in $diffFileList) {
+        if (-not $f) { continue }
+        $basenameF = [System.IO.Path]::GetFileName($f)
+        if (Test-Path $testsDir) {
+            $matchingTests = @()
+            try {
+                $matchingTests = @(Get-ChildItem -Path $testsDir -Recurse -File -ErrorAction SilentlyContinue |
+                    Where-Object { (Get-Content $_.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue) -match [regex]::Escape($basenameF) } |
+                    Select-Object -First 3 -ExpandProperty FullName)
+            } catch {}
+            if ($matchingTests.Count -gt 0) {
+                $testCoverage += "- $f covered by:"
+                foreach ($t in $matchingTests) {
+                    $relT = $t -replace [regex]::Escape($ROOT + '\'), '' -replace [regex]::Escape($ROOT + '/'), ''
+                    $testCoverage += "  - bash $relT"
+                }
+            }
+        }
+    }
+
+    # Generate diff content
+    $diffContent = ''
+    foreach ($f in $diffFileList) {
+        if (-not $f) { continue }
+        $fileDiff = (git -C $ROOT diff "$($script:PROVE_DIFF_BASE)..HEAD" -- $f 2>$null | Out-String)
+        if ($fileDiff.Trim()) {
+            $diffContent += "`n### $f`n``````diff`n$fileDiff```````n"
+        }
+    }
+
+    # Render prove-package.md
+    $ts = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
+    $diffRangeBase = $script:PROVE_DIFF_BASE.Substring(0, [Math]::Min(8, $script:PROVE_DIFF_BASE.Length))
+    $diffRangeHead = $script:PROVE_HEAD_COMMIT.Substring(0, [Math]::Min(8, $script:PROVE_HEAD_COMMIT.Length))
+    $codeFileCount = @($diffFileList | Where-Object { $_ }).Count
+
+    $writeSetSection = ($diffFileList | Where-Object { $_ } | ForEach-Object { "- $_" }) -join "`n"
+    $hunkSection = if ($hunkSymbols.Count -gt 0) { ($hunkSymbols | ForEach-Object { "- $_" }) -join "`n" } else { '- (none detected)' }
+    $syntaxSection = if ($syntaxChecks.Count -gt 0) { $syntaxChecks -join "`n" } else { '- (none auto-detected)' }
+    $coverageSection = if ($testCoverage.Count -gt 0) { $testCoverage -join "`n" } else { '- (none found — agent should generate invariant assertions)' }
+
+    $packageContent = @"
+# Prove Package: $TaskId
+
+> generated: $ts
+> code_fingerprint: $codeFingerprint
+> head_commit: $($script:PROVE_HEAD_COMMIT)
+> diff_range: ${diffRangeBase}..${diffRangeHead}
+> code_files: $codeFileCount
+
+## GOAL
+$($script:PROVE_TASK_GOAL)
+
+## WRITE-SET (code files in diff)
+$writeSetSection
+
+## Hunk Symbols (modified functions/classes)
+$hunkSection
+
+## Syntax Checks (auto-detected)
+$syntaxSection
+
+## Existing Test Coverage
+$coverageSection
+
+## Unified Diff
+$diffContent
+
+## Assertion Generation Instructions
+
+Generate prove-assertions.json with categories:
+- **syntax**: Verify modified files parse correctly (use syntax checks above)
+- **regression**: Run existing tests covering modified files (use test coverage above)
+- **invariant**: Property tests specific to THIS change that would FAIL if reverted
+
+### Anti-Tautology Rules (MANDATORY)
+1. NEVER emit commands that always succeed (true, :, echo-only)
+2. Each assertion MUST reference a specific file or symbol from this diff
+3. Invariant assertions MUST have revert_would_fail=true
+4. Maximum $MAX_ASSERTIONS assertions total
+5. Commands must NOT contain: rm, mv, curl, wget, sudo, dd, mkfs, chmod, kill
+6. rationale must be >=20 chars and explain WHY this assertion catches regressions
+
+### Output Schema
+Write engine/evidence/$TaskId/prove-assertions.json:
+``````json
+{
+  "task_id": "$TaskId",
+  "code_fingerprint": "$codeFingerprint",
+  "assertions": [
+    {
+      "id": "A-01",
+      "category": "syntax|regression|invariant",
+      "command": "<shell command>",
+      "expect_exit": 0,
+      "timeout_s": 30,
+      "rationale": "<why this matters, >=20 chars>",
+      "revert_would_fail": false
+    }
+  ]
+}
+``````
+"@
+
+    Set-Content -Path $packageFile -Value $packageContent -Encoding UTF8
+
+    $pkgLines = (Get-Content $packageFile).Count
+    Write-Output "[engine-prove] ${TaskId}: prove-package ready ($pkgLines lines)"
+    Write-Output "[engine-prove] code_fingerprint: $codeFingerprint"
+    Write-Output "[engine-prove] Next: agent reads package, writes prove-assertions.json"
+}
+
+# === Phase 2: --execute ===
+function Invoke-PhaseExecute {
+    param([string]$TaskId)
+    $evidenceDir = Join-Path $ENGINE_DIR "evidence/$TaskId"
+    $assertionsFile = Join-Path $evidenceDir 'prove-assertions.json'
+    $proveJson = Join-Path $evidenceDir 'PROVE.json'
+
+    # 1. Check assertions file exists
+    if (-not (Test-Path $assertionsFile)) {
+        [Console]::Error.WriteLine("[engine-prove] FAIL: $assertionsFile not found. Run --infer first, then agent generates assertions.")
+        exit 1
+    }
+
+    # 2. Schema validation (python-based, no jq dependency)
+    $env:ASSERTIONS_FILE = $assertionsFile
+    $env:MAX_A = $MAX_ASSERTIONS
+    & $PY -c @"
+import json, os, sys
+
+with open(os.environ['ASSERTIONS_FILE'], encoding='utf-8') as f:
+    try:
+        data = json.load(f)
+    except json.JSONDecodeError as e:
+        print(f'[engine-prove] FAIL E_SCHEMA: invalid JSON: {e}', file=sys.stderr)
+        sys.exit(1)
+
+errors = []
+max_a = int(os.environ['MAX_A'])
+
+# Required fields
+for field in ['task_id', 'code_fingerprint', 'assertions']:
+    if field not in data:
+        errors.append(f'missing field: {field}')
+
+if errors:
+    for e in errors:
+        print(f'[engine-prove] FAIL E_SCHEMA: {e}', file=sys.stderr)
+    sys.exit(1)
+
+# task_id format
+import re
+if not re.match(r'^T-[0-9]{3}$', data['task_id']):
+    errors.append(f'invalid task_id: {data["task_id"]}')
+
+# fingerprint format
+if not re.match(r'^sha256:[a-f0-9]{64}$', data.get('code_fingerprint', '')):
+    errors.append('invalid code_fingerprint format')
+
+# assertions array
+assertions = data.get('assertions', [])
+if not isinstance(assertions, list):
+    errors.append('assertions must be array')
+elif len(assertions) == 0:
+    errors.append('assertions must have at least 1 item')
+elif len(assertions) > max_a:
+    errors.append(f'too many assertions ({len(assertions)} > {max_a})')
+
+for i, a in enumerate(assertions):
+    prefix = f'assertions[{i}]'
+    for req in ['id', 'category', 'command', 'expect_exit', 'rationale']:
+        if req not in a:
+            errors.append(f'{prefix}: missing {req}')
+    if a.get('category') not in ('syntax', 'regression', 'invariant'):
+        errors.append(f'{prefix}: invalid category: {a.get("category")}')
+    if not re.match(r'^A-[0-9]{2}$', a.get('id', '')):
+        errors.append(f'{prefix}: invalid id format: {a.get("id")}')
+    if len(a.get('command', '')) > 500:
+        errors.append(f'{prefix}: command too long (>500 chars)')
+    if len(a.get('rationale', '')) < 20:
+        errors.append(f'{prefix}: rationale too short (<20 chars)')
+    if a.get('category') == 'invariant' and a.get('revert_would_fail') is not True:
+        errors.append(f'{prefix}: invariant must have revert_would_fail=true')
+
+if errors:
+    for e in errors:
+        print(f'[engine-prove] FAIL E_SCHEMA: {e}', file=sys.stderr)
+    sys.exit(1)
+"@
+    if ($LASTEXITCODE -ne 0) { exit 1 }
+
+    # 3. Staleness guard: recompute fingerprint and compare
+    Extract-DiffContext -TaskId $TaskId
+
+    $env:DIFF_BASE = $script:PROVE_DIFF_BASE
+    $env:DIFF_FILES = $script:PROVE_DIFF_FILES
+    $currentFp = & $PY -c @"
+import hashlib, subprocess, os
+diff_base = os.environ['DIFF_BASE']
+files = os.environ['DIFF_FILES'].split()
+content = ''
+for f in files:
+    try:
+        out = subprocess.check_output(['git', 'diff', diff_base + '..HEAD', '--', f], stderr=subprocess.DEVNULL)
+        content += out.decode('utf-8', errors='replace')
+    except:
+        pass
+print('sha256:' + hashlib.sha256(content.encode('utf-8')).hexdigest())
+"@ 2>$null
+    if ($LASTEXITCODE -ne 0 -or -not $currentFp) {
+        $currentFp = 'sha256:0000000000000000000000000000000000000000000000000000000000000000'
+    }
+    $currentFp = $currentFp.Trim()
+
+    $env:ASSERTIONS_FILE = $assertionsFile
+    $claimedFp = & $PY -c @"
+import json, os
+with open(os.environ['ASSERTIONS_FILE'], encoding='utf-8') as f:
+    data = json.load(f)
+print(data.get('code_fingerprint', ''))
+"@ 2>$null
+    if ($LASTEXITCODE -ne 0 -or -not $claimedFp) { $claimedFp = '' }
+    $claimedFp = $claimedFp.Trim()
+
+    if ($currentFp -ne $claimedFp) {
+        [Console]::Error.WriteLine("[engine-prove] FAIL E_STALE: code changed since inference (current=$currentFp, claimed=$claimedFp). Re-run --infer.")
+        exit 1
+    }
+
+    # 4. Safety validation (blocklist + anti-tautology + relevance)
+    $blockedJson = Load-ConfigValue -Key 'blocked_commands' -Default '["rm","mv","curl","wget","sudo","dd","mkfs"]'
+    $env:ASSERTIONS_FILE = $assertionsFile
+    $env:DIFF_FILES = $script:PROVE_DIFF_FILES
+    $env:BLOCKED_JSON = $blockedJson
+    & $PY -c @"
+import json, os, sys, re
+
+with open(os.environ['ASSERTIONS_FILE'], encoding='utf-8') as f:
+    data = json.load(f)
+
+blocked = json.loads(os.environ['BLOCKED_JSON'])
+diff_files = os.environ['DIFF_FILES'].split()
+errors = []
+
+for a in data.get('assertions', []):
+    cmd = a.get('command', '')
+    aid = a.get('id', '?')
+
+    # Blocklist check
+    for b in blocked:
+        if re.search(r'\b' + re.escape(b) + r'\b', cmd):
+            errors.append(f'{aid}: blocked command word "{b}" in: {cmd[:80]}')
+
+    # Tautology check
+    stripped = cmd.strip()
+    if stripped in ('true', ':', 'exit 0') or re.match(r'^(echo|printf)\s', stripped):
+        errors.append(f'{aid}: tautological command (always succeeds): {stripped[:60]}')
+
+    # Relevance: must reference at least one diff file or its basename
+    referenced = False
+    for f in diff_files:
+        if f in cmd or os.path.basename(f) in cmd:
+            referenced = True
+            break
+    # Also accept if command references a test file that covers diff files
+    if not referenced and 'test' in cmd.lower():
+        referenced = True  # test commands are assumed relevant
+    if not referenced:
+        errors.append(f'{aid}: command does not reference any changed file: {cmd[:80]}')
+
+if errors:
+    for e in errors:
+        print(f'[engine-prove] FAIL E_SAFETY: {e}', file=sys.stderr)
+    sys.exit(1)
+"@
+    if ($LASTEXITCODE -ne 0) { exit 1 }
+
+    # 5. Execute assertions
+    Write-Output "[engine-prove] ${TaskId}: executing assertions..."
+
+    $env:ASSERTIONS_FILE = $assertionsFile
+    $env:ROOT_DIR = $ROOT
+    $env:TIMEOUT_DEFAULT = $ASSERTION_TIMEOUT
+    $env:TRUNCATE = $OUTPUT_TRUNCATE
+    $resultsJson = & $PY -c @"
+import json, os, sys, subprocess, time, hashlib
+
+with open(os.environ['ASSERTIONS_FILE'], encoding='utf-8') as f:
+    data = json.load(f)
+
+root = os.environ['ROOT_DIR']
+timeout_default = int(os.environ['TIMEOUT_DEFAULT'])
+truncate = int(os.environ['TRUNCATE'])
+
+results = []
+total = passed = failed = timed_out = 0
+
+for a in data['assertions']:
+    total += 1
+    aid = a['id']
+    cmd = a['command']
+    expect_exit = a['expect_exit']
+    timeout_s = a.get('timeout_s', timeout_default)
+
+    start = time.time()
+    try:
+        proc = subprocess.run(
+            cmd, shell=True, capture_output=True, timeout=timeout_s,
+            cwd=root, stdin=subprocess.DEVNULL
+        )
+        exit_code = proc.returncode
+        output = (proc.stdout + proc.stderr).decode('utf-8', errors='replace')
+        status = 'PASS' if exit_code == expect_exit else 'FAIL'
+    except subprocess.TimeoutExpired:
+        exit_code = 124
+        output = f'TIMEOUT after {timeout_s}s'
+        status = 'TIMEOUT'
+        timed_out += 1
+    except Exception as e:
+        exit_code = 1
+        output = str(e)
+        status = 'FAIL'
+
+    duration_ms = int((time.time() - start) * 1000)
+
+    # Output constraints
+    if status == 'PASS':
+        if a.get('expect_output_contains') and a['expect_output_contains'] not in output:
+            status = 'FAIL'
+        if a.get('expect_output_not_contains') and a['expect_output_not_contains'] in output:
+            status = 'FAIL'
+
+    if status == 'PASS':
+        passed += 1
+    elif status == 'TIMEOUT':
+        pass  # already counted
+    else:
+        failed += 1
+
+    results.append({
+        'id': aid,
+        'category': a['category'],
+        'command': cmd[:200],
+        'status': status,
+        'exit_code': exit_code,
+        'expect_exit': expect_exit,
+        'duration_ms': duration_ms,
+        'output_fingerprint': 'sha256:' + hashlib.sha256(output.encode('utf-8')).hexdigest(),
+        'output_truncated': output[:truncate]
+    })
+
+    # Progress
+    print(f'  {aid} [{a["category"]}] {status} ({duration_ms}ms)', file=sys.stderr)
+
+print(json.dumps({'total': total, 'passed': passed, 'failed': failed, 'timed_out': timed_out, 'results': results}))
+"@
+    if ($LASTEXITCODE -ne 0 -or -not $resultsJson) {
+        $resultsJson = '{"total":0,"passed":0,"failed":0,"timed_out":0,"results":[]}'
+    }
+    $resultsJson = ($resultsJson | Out-String).Trim()
+
+    # Parse results
+    $env:RESULTS_JSON = $resultsJson
+    $total = & $PY -c "import json,sys,os; d=json.loads(os.environ['RESULTS_JSON']); print(d['total'])" 2>$null
+    if ($LASTEXITCODE -ne 0 -or -not $total) { $total = '0' }
+    $total = $total.Trim()
+
+    $passed = & $PY -c "import json,sys,os; d=json.loads(os.environ['RESULTS_JSON']); print(d['passed'])" 2>$null
+    if ($LASTEXITCODE -ne 0 -or -not $passed) { $passed = '0' }
+    $passed = $passed.Trim()
+
+    $failed = & $PY -c "import json,sys,os; d=json.loads(os.environ['RESULTS_JSON']); print(d['failed'])" 2>$null
+    if ($LASTEXITCODE -ne 0 -or -not $failed) { $failed = '0' }
+    $failed = $failed.Trim()
+
+    $timedOut = & $PY -c "import json,sys,os; d=json.loads(os.environ['RESULTS_JSON']); print(d['timed_out'])" 2>$null
+    if ($LASTEXITCODE -ne 0 -or -not $timedOut) { $timedOut = '0' }
+    $timedOut = $timedOut.Trim()
+
+    $gate = if ([int]$failed -gt 0 -or [int]$timedOut -gt 0) { 'FAIL' } else { 'PASS' }
+
+    # 6. Write PROVE.json evidence
+    $env:RESULTS_JSON = $resultsJson
+    $env:GATE = $gate
+    $env:TASK_ID = $TaskId
+    $env:FP = $currentFp
+    $env:PROVE_FILE = $proveJson
+    $env:PROVE_HEAD_COMMIT = $script:PROVE_HEAD_COMMIT
+    & $PY -c @"
+import json, os, hashlib
+from datetime import datetime, timezone
+
+results = json.loads(os.environ['RESULTS_JSON'])
+gate = os.environ['GATE']
+task_id = os.environ['TASK_ID']
+fp = os.environ['FP']
+prove_file = os.environ['PROVE_FILE']
+
+# Compute assertions fingerprint
+assertions_file = prove_file.replace('PROVE.json', 'prove-assertions.json')
+af_hash = ''
+if os.path.isfile(assertions_file):
+    with open(assertions_file, 'rb') as f:
+        af_hash = 'sha256:' + hashlib.sha256(f.read()).hexdigest()
+
+evidence = {
+    'schema_version': '1.0',
+    'task_id': task_id,
+    'command': f'engine prove {task_id} --execute',
+    'timestamp': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
+    'status': gate,
+    'code_fingerprint': fp,
+    'assertions_fingerprint': af_hash,
+    'summary': {
+        'total': results['total'],
+        'passed': results['passed'],
+        'failed': results['failed'],
+        'timed_out': results['timed_out']
+    },
+    'results': results['results'],
+    'gate': {
+        'decision': gate,
+        'rule': 'ALL assertions must pass; any FAIL or TIMEOUT = gate FAIL'
+    },
+    'write_provenance': {
+        'writer': 'engine-prove',
+        'commit': os.environ.get('PROVE_HEAD_COMMIT', ''),
+        'timestamp': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
+        'argv': f'engine prove {task_id} --execute'
+    }
+}
+
+with open(prove_file, 'w', encoding='utf-8', newline='\n') as f:
+    json.dump(evidence, f, indent=2, ensure_ascii=False)
+"@
+    if ($LASTEXITCODE -ne 0) {
+        [Console]::Error.WriteLine("[engine-prove] error writing PROVE.json")
+        exit 1
+    }
+
+    # 7. Report + exit
+    Write-Output "[engine-prove] ${TaskId}: $gate ($passed/$total passed, $failed failed, $timedOut timed out)"
+    if ($gate -eq 'PASS') {
+        exit 0
+    } else {
+        exit 1
+    }
+}
+
+# === Dispatch ===
+switch ($Mode) {
+    '--infer'   { Invoke-PhaseInfer -TaskId $Task }
+    '--execute' { Invoke-PhaseExecute -TaskId $Task }
+    default {
+        [Console]::Error.WriteLine("Usage: engine prove T-NNN --infer|--execute")
+        exit 2
+    }
+}
+
+} finally {
+    if ($lockStream) { $lockStream.Dispose() }
+}
```

### plugin/engine/scripts/engine-prove.sh
```diff
diff --git a/plugin/engine/scripts/engine-prove.sh b/plugin/engine/scripts/engine-prove.sh
new file mode 100644
index 0000000..7952ed9
--- /dev/null
+++ b/plugin/engine/scripts/engine-prove.sh
@@ -0,0 +1,596 @@
+#!/usr/bin/env bash
+# Engine System — Prove: 执行验证子系统 (v6.23.0)
+#
+# 从 diff 自动推断测试断言并执行。两原子命令 (D-019):
+#   engine prove T-NNN --infer    → 产出 prove-package.md (上下文)
+#   engine prove T-NNN --execute  → 执行 prove-assertions.json + 门禁
+#
+# 证据: engine/evidence/T-NNN/PROVE.json
+# 安全: 命令黑名单 + 反套言 + 陈旧指纹检测 + timeout
+
+set -euo pipefail
+on_error() { echo "[engine-prove] error on line $1" >&2; exit 1; }
+trap 'on_error ${LINENO}' ERR
+
+ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
+ENGINE_DIR="$ROOT/engine"
+PROVE_DIR="$ENGINE_DIR/prove"
+cd "$ROOT"
+
+# python detection
+PY=python3
+command -v python3 >/dev/null 2>&1 || PY=python
+
+usage() {
+  echo "Usage: engine prove T-NNN --infer|--execute" >&2
+  exit 2
+}
+
+task="${1:-}"
+mode="${2:-}"
+[ -z "$task" ] && usage
+[ -z "$mode" ] && usage
+
+# === Config loading ===
+config_file="$PROVE_DIR/config.json"
+load_config_value() {
+  local key="$1" default="$2"
+  if [ -f "$config_file" ]; then
+    CONFIG_FILE="$config_file" KEY="$key" DEFAULT="$default" "$PY" -c "
+import json, os
+try:
+    with open(os.environ['CONFIG_FILE']) as f:
+        cfg = json.load(f)
+except:
+    cfg = {}
+defaults = cfg.get('defaults', {})
+overrides = cfg.get('overrides', {})
+merged = dict(defaults)
+for k, v in overrides.items():
+    merged[k] = v
+val = merged.get(os.environ['KEY'], os.environ['DEFAULT'])
+print(val if not isinstance(val, list) else json.dumps(val))
+" 2>/dev/null || echo "$default"
+  else
+    echo "$default"
+  fi
+}
+
+MAX_ASSERTIONS=$(load_config_value "max_assertions" "10")
+ASSERTION_TIMEOUT=$(load_config_value "assertion_timeout_s" "30")
+OUTPUT_TRUNCATE=$(load_config_value "output_truncate_chars" "500")
+
+# === Shared: diff extraction (mirrors review-agent-package algorithm) ===
+extract_diff_context() {
+  local task_id="$1"
+  local task_file="$ENGINE_DIR/tasks/$task_id.md"
+
+  if [ ! -f "$task_file" ]; then
+    echo "[engine-prove] Error: task card not found: $task_file" >&2
+    return 1
+  fi
+
+  # Parse WRITE-SET
+  local write_set_files
+  write_set_files=$(awk '
+    /^## WRITE-SET/{f=1;next}
+    /^## /{f=0}
+    f && /^- /{sub(/^- /,"");sub(/ *#.*/,"");print}
+  ' "$task_file" | tr '\n' ' ')
+
+  # Code extensions filter
+  local code_extensions_json
+  code_extensions_json=$(load_config_value "code_extensions" '[".sh",".ps1",".py",".js",".ts",".go",".rs",".java",".c",".cpp",".rb",".php"]')
+
+  local code_files
+  code_files=$(printf '%s\n' $write_set_files | ROOT_DIR="$ROOT" CODE_EXTS="$code_extensions_json" "$PY" -c "
+import json, sys, os
+exts = set(json.loads(os.environ['CODE_EXTS']))
+root = os.environ['ROOT_DIR']
+out = []
+for line in sys.stdin:
+    f = line.strip()
+    if not f: continue
+    if '*' in f or '?' in f: continue
+    _, ext = os.path.splitext(f)
+    if ext in exts and os.path.isfile(os.path.join(root, f)):
+        out.append(f)
+print(' '.join(out))
+" 2>/dev/null || echo "")
+
+  # Diff base (task_first_commit algorithm)
+  local task_first_commit
+  task_first_commit=$(git log --reverse --format="%H" -- "$task_file" 2>/dev/null | head -1 || true)
+  if [ -z "$task_first_commit" ]; then
+    echo "[engine-prove] Error: no git history for $task_file" >&2
+    return 1
+  fi
+
+  local head_commit
+  head_commit=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
+  local diff_base
+  diff_base=$(git rev-parse "$task_first_commit^" 2>/dev/null || true)
+  if ! printf '%s' "$diff_base" | grep -qE '^[0-9a-f]{40}$'; then
+    diff_base="4b825dc642cb6eb9a060e54bf8d69288fbee4904"
+  fi
+
+  # Filter to files actually changed
+  local diff_files=""
+  for f in $code_files; do
+    if git diff --name-only "$diff_base"..HEAD -- "$f" 2>/dev/null | grep -q .; then
+      diff_files="$diff_files $f"
+    fi
+  done
+  diff_files=$(echo "$diff_files" | tr -s ' ' | sed 's/^ //')
+
+  # Export for caller
+  PROVE_WRITE_SET="$write_set_files"
+  PROVE_CODE_FILES="$code_files"
+  PROVE_DIFF_FILES="$diff_files"
+  PROVE_DIFF_BASE="$diff_base"
+  PROVE_HEAD_COMMIT="$head_commit"
+  PROVE_TASK_GOAL=$(awk '/^## GOAL/{f=1;next}/^## /{f=0}f{print}' "$task_file" | head -5)
+}
+
+# === Phase 1: --infer ===
+phase_infer() {
+  local task_id="$1"
+  local evidence_dir="$ENGINE_DIR/evidence/$task_id"
+  mkdir -p "$evidence_dir"
+  local package_file="$evidence_dir/prove-package.md"
+
+  extract_diff_context "$task_id"
+
+  # No code files → NO-OP
+  if [ -z "$PROVE_DIFF_FILES" ]; then
+    cat > "$package_file" << EOF
+# Prove Package: $task_id
+
+> generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
+> status: NO-OP
+> reason: no code files in diff range
+
+No assertions needed.
+EOF
+    echo "[engine-prove] $task_id: no code changes, package marked NO-OP"
+    exit 0
+  fi
+
+  # Compute code fingerprint (sha256 of concatenated diffs)
+  local code_fingerprint
+  code_fingerprint=$(DIFF_BASE="$PROVE_DIFF_BASE" DIFF_FILES="$PROVE_DIFF_FILES" "$PY" -c "
+import hashlib, subprocess, os
+diff_base = os.environ['DIFF_BASE']
+files = os.environ['DIFF_FILES'].split()
+content = ''
+for f in files:
+    try:
+        out = subprocess.check_output(['git', 'diff', diff_base + '..HEAD', '--', f], stderr=subprocess.DEVNULL)
+        content += out.decode('utf-8', errors='replace')
+    except:
+        pass
+print('sha256:' + hashlib.sha256(content.encode('utf-8')).hexdigest())
+" 2>/dev/null || echo "sha256:0000000000000000000000000000000000000000000000000000000000000000")
+
+  # Extract hunk symbols
+  local hunk_symbols
+  hunk_symbols=$(git diff -U0 "$PROVE_DIFF_BASE"..HEAD -- $PROVE_DIFF_FILES 2>/dev/null | grep '^@@' | sed 's/.*@@[[:space:]]*//' | grep -v '^$' | head -20 || true)
+
+  # Detect languages → syntax checkers
+  local syntax_checks=""
+  for f in $PROVE_DIFF_FILES; do
+    local ext="${f##*.}"
+    case "$ext" in
+      sh)  syntax_checks="$syntax_checks\n- bash -n $f" ;;
+      py)  syntax_checks="$syntax_checks\n- python -m py_compile $f" ;;
+      js)  syntax_checks="$syntax_checks\n- node --check $f" ;;
+      json) syntax_checks="$syntax_checks\n- python -m json.tool $f" ;;
+    esac
+  done
+
+  # Find existing test coverage
+  local test_coverage=""
+  for f in $PROVE_DIFF_FILES; do
+    local basename_f
+    basename_f=$(basename "$f")
+    local matching_tests
+    matching_tests=$(grep -rl "$basename_f" "$ROOT/tests/" 2>/dev/null | head -3 || true)
+    if [ -n "$matching_tests" ]; then
+      test_coverage="$test_coverage\n- $f covered by:"
+      for t in $matching_tests; do
+        local rel_t="${t#$ROOT/}"
+        test_coverage="$test_coverage\n  - bash $rel_t"
+      done
+    fi
+  done
+
+  # Generate diff content
+  local diff_content=""
+  for f in $PROVE_DIFF_FILES; do
+    local file_diff
+    file_diff=$(git diff "$PROVE_DIFF_BASE"..HEAD -- "$f" 2>/dev/null || true)
+    if [ -n "$file_diff" ]; then
+      diff_content="$diff_content
+### $f
+\`\`\`diff
+$file_diff
+\`\`\`
+"
+    fi
+  done
+
+  # Render prove-package.md
+  cat > "$package_file" << PKGEOF
+# Prove Package: $task_id
+
+> generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
+> code_fingerprint: $code_fingerprint
+> head_commit: $PROVE_HEAD_COMMIT
+> diff_range: ${PROVE_DIFF_BASE:0:8}..${PROVE_HEAD_COMMIT:0:8}
+> code_files: $(echo "$PROVE_DIFF_FILES" | wc -w | tr -d ' ')
+
+## GOAL
+$PROVE_TASK_GOAL
+
+## WRITE-SET (code files in diff)
+$(for f in $PROVE_DIFF_FILES; do echo "- $f"; done)
+
+## Hunk Symbols (modified functions/classes)
+$(echo "$hunk_symbols" | sed 's/^/- /' | head -20)
+
+## Syntax Checks (auto-detected)
+$(echo -e "$syntax_checks")
+
+## Existing Test Coverage
+$(if [ -n "$test_coverage" ]; then echo -e "$test_coverage"; else echo "- (none found — agent should generate invariant assertions)"; fi)
+
+## Unified Diff
+$diff_content
+
+## Assertion Generation Instructions
+
+Generate prove-assertions.json with categories:
+- **syntax**: Verify modified files parse correctly (use syntax checks above)
+- **regression**: Run existing tests covering modified files (use test coverage above)
+- **invariant**: Property tests specific to THIS change that would FAIL if reverted
+
+### Anti-Tautology Rules (MANDATORY)
+1. NEVER emit commands that always succeed (true, :, echo-only)
+2. Each assertion MUST reference a specific file or symbol from this diff
+3. Invariant assertions MUST have revert_would_fail=true
+4. Maximum $MAX_ASSERTIONS assertions total
+5. Commands must NOT contain: rm, mv, curl, wget, sudo, dd, mkfs, chmod, kill
+6. rationale must be >=20 chars and explain WHY this assertion catches regressions
+
+### Output Schema
+Write engine/evidence/$task_id/prove-assertions.json:
+\`\`\`json
+{
+  "task_id": "$task_id",
+  "code_fingerprint": "$code_fingerprint",
+  "assertions": [
+    {
+      "id": "A-01",
+      "category": "syntax|regression|invariant",
+      "command": "<shell command>",
+      "expect_exit": 0,
+      "timeout_s": 30,
+      "rationale": "<why this matters, >=20 chars>",
+      "revert_would_fail": false
+    }
+  ]
+}
+\`\`\`
+PKGEOF
+
+  local pkg_lines
+  pkg_lines=$(wc -l < "$package_file" | tr -d ' ')
+  echo "[engine-prove] $task_id: prove-package ready ($pkg_lines lines)"
+  echo "[engine-prove] code_fingerprint: $code_fingerprint"
+  echo "[engine-prove] Next: agent reads package, writes prove-assertions.json"
+}
+
+# === Phase 2: --execute ===
+phase_execute() {
+  local task_id="$1"
+  local evidence_dir="$ENGINE_DIR/evidence/$task_id"
+  local assertions_file="$evidence_dir/prove-assertions.json"
+  local prove_json="$evidence_dir/PROVE.json"
+
+  # 1. Check assertions file exists
+  if [ ! -f "$assertions_file" ]; then
+    echo "[engine-prove] FAIL: $assertions_file not found. Run --infer first, then agent generates assertions." >&2
+    exit 1
+  fi
+
+  # 2. Schema validation (python-based, no jq dependency)
+  ASSERTIONS_FILE="$assertions_file" MAX_A="$MAX_ASSERTIONS" "$PY" -c "
+import json, os, sys
+
+with open(os.environ['ASSERTIONS_FILE'], encoding='utf-8') as f:
+    try:
+        data = json.load(f)
+    except json.JSONDecodeError as e:
+        print(f'[engine-prove] FAIL E_SCHEMA: invalid JSON: {e}', file=sys.stderr)
+        sys.exit(1)
+
+errors = []
+max_a = int(os.environ['MAX_A'])
+
+# Required fields
+for field in ['task_id', 'code_fingerprint', 'assertions']:
+    if field not in data:
+        errors.append(f'missing field: {field}')
+
+if errors:
+    for e in errors:
+        print(f'[engine-prove] FAIL E_SCHEMA: {e}', file=sys.stderr)
+    sys.exit(1)
+
+# task_id format
+import re
+if not re.match(r'^T-[0-9]{3}$', data['task_id']):
+    errors.append(f'invalid task_id: {data[\"task_id\"]}')
+
+# fingerprint format
+if not re.match(r'^sha256:[a-f0-9]{64}$', data.get('code_fingerprint', '')):
+    errors.append('invalid code_fingerprint format')
+
+# assertions array
+assertions = data.get('assertions', [])
+if not isinstance(assertions, list):
+    errors.append('assertions must be array')
+elif len(assertions) == 0:
+    errors.append('assertions must have at least 1 item')
+elif len(assertions) > max_a:
+    errors.append(f'too many assertions ({len(assertions)} > {max_a})')
+
+for i, a in enumerate(assertions):
+    prefix = f'assertions[{i}]'
+    for req in ['id', 'category', 'command', 'expect_exit', 'rationale']:
+        if req not in a:
+            errors.append(f'{prefix}: missing {req}')
+    if a.get('category') not in ('syntax', 'regression', 'invariant'):
+        errors.append(f'{prefix}: invalid category: {a.get(\"category\")}')
+    if not re.match(r'^A-[0-9]{2}$', a.get('id', '')):
+        errors.append(f'{prefix}: invalid id format: {a.get(\"id\")}')
+    if len(a.get('command', '')) > 500:
+        errors.append(f'{prefix}: command too long (>500 chars)')
+    if len(a.get('rationale', '')) < 20:
+        errors.append(f'{prefix}: rationale too short (<20 chars)')
+    if a.get('category') == 'invariant' and a.get('revert_would_fail') is not True:
+        errors.append(f'{prefix}: invariant must have revert_would_fail=true')
+
+if errors:
+    for e in errors:
+        print(f'[engine-prove] FAIL E_SCHEMA: {e}', file=sys.stderr)
+    sys.exit(1)
+" || exit 1
+
+  # 3. Staleness guard: recompute fingerprint and compare
+  extract_diff_context "$task_id"
+  local current_fp
+  current_fp=$(DIFF_BASE="$PROVE_DIFF_BASE" DIFF_FILES="$PROVE_DIFF_FILES" "$PY" -c "
+import hashlib, subprocess, os
+diff_base = os.environ['DIFF_BASE']
+files = os.environ['DIFF_FILES'].split()
+content = ''
+for f in files:
+    try:
+        out = subprocess.check_output(['git', 'diff', diff_base + '..HEAD', '--', f], stderr=subprocess.DEVNULL)
+        content += out.decode('utf-8', errors='replace')
+    except:
+        pass
+print('sha256:' + hashlib.sha256(content.encode('utf-8')).hexdigest())
+" 2>/dev/null || echo "sha256:0000000000000000000000000000000000000000000000000000000000000000")
+
+  local claimed_fp
+  claimed_fp=$(ASSERTIONS_FILE="$assertions_file" "$PY" -c "
+import json, os
+with open(os.environ['ASSERTIONS_FILE'], encoding='utf-8') as f:
+    data = json.load(f)
+print(data.get('code_fingerprint', ''))
+" 2>/dev/null || echo "")
+
+  if [ "$current_fp" != "$claimed_fp" ]; then
+    echo "[engine-prove] FAIL E_STALE: code changed since inference (current=$current_fp, claimed=$claimed_fp). Re-run --infer." >&2
+    exit 1
+  fi
+
+  # 4. Safety validation (blocklist + anti-tautology + relevance)
+  ASSERTIONS_FILE="$assertions_file" DIFF_FILES="$PROVE_DIFF_FILES" BLOCKED_JSON="$(load_config_value 'blocked_commands' '["rm","mv","curl","wget","sudo","dd","mkfs"]')" "$PY" -c "
+import json, os, sys, re
+
+with open(os.environ['ASSERTIONS_FILE'], encoding='utf-8') as f:
+    data = json.load(f)
+
+blocked = json.loads(os.environ['BLOCKED_JSON'])
+diff_files = os.environ['DIFF_FILES'].split()
+errors = []
+
+for a in data.get('assertions', []):
+    cmd = a.get('command', '')
+    aid = a.get('id', '?')
+
+    # Blocklist check
+    for b in blocked:
+        if re.search(r'\b' + re.escape(b) + r'\b', cmd):
+            errors.append(f'{aid}: blocked command word \"{b}\" in: {cmd[:80]}')
+
+    # Tautology check
+    stripped = cmd.strip()
+    if stripped in ('true', ':', 'exit 0') or re.match(r'^(echo|printf)\s', stripped):
+        errors.append(f'{aid}: tautological command (always succeeds): {stripped[:60]}')
+
+    # Relevance: must reference at least one diff file or its basename
+    referenced = False
+    for f in diff_files:
+        if f in cmd or os.path.basename(f) in cmd:
+            referenced = True
+            break
+    # Also accept if command references a test file that covers diff files
+    if not referenced and 'test' in cmd.lower():
+        referenced = True  # test commands are assumed relevant
+    if not referenced:
+        errors.append(f'{aid}: command does not reference any changed file: {cmd[:80]}')
+
+if errors:
+    for e in errors:
+        print(f'[engine-prove] FAIL E_SAFETY: {e}', file=sys.stderr)
+    sys.exit(1)
+" || exit 1
+
+  # 5. Execute assertions
+  echo "[engine-prove] $task_id: executing assertions..."
+
+  local results_json
+  results_json=$(ASSERTIONS_FILE="$assertions_file" ROOT_DIR="$ROOT" TIMEOUT_DEFAULT="$ASSERTION_TIMEOUT" TRUNCATE="$OUTPUT_TRUNCATE" "$PY" -c "
+import json, os, sys, subprocess, time, hashlib
+
+with open(os.environ['ASSERTIONS_FILE'], encoding='utf-8') as f:
+    data = json.load(f)
+
+root = os.environ['ROOT_DIR']
+timeout_default = int(os.environ['TIMEOUT_DEFAULT'])
+truncate = int(os.environ['TRUNCATE'])
+
+results = []
+total = passed = failed = timed_out = 0
+
+for a in data['assertions']:
+    total += 1
+    aid = a['id']
+    cmd = a['command']
+    expect_exit = a['expect_exit']
+    timeout_s = a.get('timeout_s', timeout_default)
+
+    start = time.time()
+    try:
+        proc = subprocess.run(
+            cmd, shell=True, capture_output=True, timeout=timeout_s,
+            cwd=root, stdin=subprocess.DEVNULL
+        )
+        exit_code = proc.returncode
+        output = (proc.stdout + proc.stderr).decode('utf-8', errors='replace')
+        status = 'PASS' if exit_code == expect_exit else 'FAIL'
+    except subprocess.TimeoutExpired:
+        exit_code = 124
+        output = f'TIMEOUT after {timeout_s}s'
+        status = 'TIMEOUT'
+        timed_out += 1
+    except Exception as e:
+        exit_code = 1
+        output = str(e)
+        status = 'FAIL'
+
+    duration_ms = int((time.time() - start) * 1000)
+
+    # Output constraints
+    if status == 'PASS':
+        if a.get('expect_output_contains') and a['expect_output_contains'] not in output:
+            status = 'FAIL'
+        if a.get('expect_output_not_contains') and a['expect_output_not_contains'] in output:
+            status = 'FAIL'
+
+    if status == 'PASS':
+        passed += 1
+    elif status == 'TIMEOUT':
+        pass  # already counted
+    else:
+        failed += 1
+
+    results.append({
+        'id': aid,
+        'category': a['category'],
+        'command': cmd[:200],
+        'status': status,
+        'exit_code': exit_code,
+        'expect_exit': expect_exit,
+        'duration_ms': duration_ms,
+        'output_fingerprint': 'sha256:' + hashlib.sha256(output.encode('utf-8')).hexdigest(),
+        'output_truncated': output[:truncate]
+    })
+
+    # Progress
+    print(f'  {aid} [{a[\"category\"]}] {status} ({duration_ms}ms)', file=sys.stderr)
+
+print(json.dumps({'total': total, 'passed': passed, 'failed': failed, 'timed_out': timed_out, 'results': results}))
+" || echo '{"total":0,"passed":0,"failed":0,"timed_out":0,"results":[]}')
+
+  # Parse results
+  local total passed failed timed_out gate
+  total=$(echo "$results_json" | "$PY" -c "import json,sys; d=json.load(sys.stdin); print(d['total'])" 2>/dev/null || echo "0")
+  passed=$(echo "$results_json" | "$PY" -c "import json,sys; d=json.load(sys.stdin); print(d['passed'])" 2>/dev/null || echo "0")
+  failed=$(echo "$results_json" | "$PY" -c "import json,sys; d=json.load(sys.stdin); print(d['failed'])" 2>/dev/null || echo "0")
+  timed_out=$(echo "$results_json" | "$PY" -c "import json,sys; d=json.load(sys.stdin); print(d['timed_out'])" 2>/dev/null || echo "0")
+
+  if [ "$failed" -gt 0 ] || [ "$timed_out" -gt 0 ]; then
+    gate="FAIL"
+  else
+    gate="PASS"
+  fi
+
+  # 6. Write PROVE.json evidence
+  RESULTS_JSON="$results_json" GATE="$gate" TASK_ID="$task_id" FP="$current_fp" PROVE_FILE="$prove_json" "$PY" -c "
+import json, os, hashlib
+from datetime import datetime, timezone
+
+results = json.loads(os.environ['RESULTS_JSON'])
+gate = os.environ['GATE']
+task_id = os.environ['TASK_ID']
+fp = os.environ['FP']
+prove_file = os.environ['PROVE_FILE']
+
+# Compute assertions fingerprint
+assertions_file = prove_file.replace('PROVE.json', 'prove-assertions.json')
+af_hash = ''
+if os.path.isfile(assertions_file):
+    with open(assertions_file, 'rb') as f:
+        af_hash = 'sha256:' + hashlib.sha256(f.read()).hexdigest()
+
+evidence = {
+    'schema_version': '1.0',
+    'task_id': task_id,
+    'command': f'engine prove {task_id} --execute',
+    'timestamp': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
+    'status': gate,
+    'code_fingerprint': fp,
+    'assertions_fingerprint': af_hash,
+    'summary': {
+        'total': results['total'],
+        'passed': results['passed'],
+        'failed': results['failed'],
+        'timed_out': results['timed_out']
+    },
+    'results': results['results'],
+    'gate': {
+        'decision': gate,
+        'rule': 'ALL assertions must pass; any FAIL or TIMEOUT = gate FAIL'
+    },
+    'write_provenance': {
+        'writer': 'engine-prove',
+        'commit': os.environ.get('PROVE_HEAD_COMMIT', ''),
+        'timestamp': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
+        'argv': f'engine prove {task_id} --execute'
+    }
+}
+
+with open(prove_file, 'w', encoding='utf-8', newline='\n') as f:
+    json.dump(evidence, f, indent=2, ensure_ascii=False)
+"
+
+  # 7. Report + exit
+  echo "[engine-prove] $task_id: $gate ($passed/$total passed, $failed failed, $timed_out timed out)"
+  if [ "$gate" = "PASS" ]; then
+    exit 0
+  else
+    exit 1
+  fi
+}
+
+# === Dispatch ===
+case "$mode" in
+  --infer)   phase_infer "$task" ;;
+  --execute) phase_execute "$task" ;;
+  *)         usage ;;
+esac
```

### plugin/engine/scripts/engine-prove.ps1
```diff
diff --git a/plugin/engine/scripts/engine-prove.ps1 b/plugin/engine/scripts/engine-prove.ps1
new file mode 100644
index 0000000..e2a7688
--- /dev/null
+++ b/plugin/engine/scripts/engine-prove.ps1
@@ -0,0 +1,712 @@
+# Engine System — Prove: 执行验证子系统 (v6.23.0) [PowerShell behavioral mirror]
+#
+# 从 diff 自动推断测试断言并执行。两原子命令 (D-019):
+#   engine prove T-NNN --infer    → 产出 prove-package.md (上下文)
+#   engine prove T-NNN --execute  → 执行 prove-assertions.json + 门禁
+#
+# 证据: engine/evidence/T-NNN/PROVE.json
+# 安全: 命令黑名单 + 反套言 + 陈旧指纹检测 + timeout
+#
+# Usage: pwsh -File engine/scripts/engine-prove.ps1 -Task T-NNN -Mode --infer|--execute
+
+param(
+    [Parameter(Mandatory=$false)][string]$Task,
+    [Parameter(Mandatory=$false)][string]$Mode
+)
+
+$ErrorActionPreference = 'Stop'
+trap { [Console]::Error.WriteLine("[engine-prove] error: $_"); exit 1 }
+
+$ROOT = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (Get-Location).Path }
+$ENGINE_DIR = Join-Path $ROOT 'engine'
+$PROVE_DIR = Join-Path $ENGINE_DIR 'prove'
+
+Set-Location $ROOT
+
+# python detection
+$PY = 'python3'
+if (-not (Get-Command python3 -ErrorAction SilentlyContinue)) { $PY = 'python' }
+if (-not (Get-Command $PY -ErrorAction SilentlyContinue)) {
+    [Console]::Error.WriteLine("[engine-prove] error: python not found")
+    exit 1
+}
+
+# === Usage ===
+if (-not $Task -or -not $Mode) {
+    [Console]::Error.WriteLine("Usage: engine prove T-NNN --infer|--execute")
+    exit 2
+}
+if ($Mode -notin @('--infer', '--execute')) {
+    [Console]::Error.WriteLine("Usage: engine prove T-NNN --infer|--execute")
+    exit 2
+}
+
+# === FileStream lock (concurrency guard) ===
+if (-not (Test-Path $PROVE_DIR)) { New-Item -ItemType Directory -Path $PROVE_DIR -Force | Out-Null }
+$lockPath = Join-Path $PROVE_DIR ".prove-lock.$Task"
+try {
+    $lockStream = [System.IO.File]::Open($lockPath, 'Create', 'ReadWrite', 'None')
+} catch {
+    [Console]::Error.WriteLine("[engine-prove] another prove process running for $Task")
+    exit 1
+}
+
+try {
+
+# === Config loading ===
+$configFile = Join-Path $PROVE_DIR 'config.json'
+
+function Load-ConfigValue {
+    param([string]$Key, [string]$Default)
+    if (-not (Test-Path $configFile)) { return $Default }
+    $env:CONFIG_FILE = $configFile
+    $env:KEY = $Key
+    $env:DEFAULT = $Default
+    $result = & $PY -c @"
+import json, os
+try:
+    with open(os.environ['CONFIG_FILE']) as f:
+        cfg = json.load(f)
+except:
+    cfg = {}
+defaults = cfg.get('defaults', {})
+overrides = cfg.get('overrides', {})
+merged = dict(defaults)
+for k, v in overrides.items():
+    merged[k] = v
+val = merged.get(os.environ['KEY'], os.environ['DEFAULT'])
+print(val if not isinstance(val, list) else json.dumps(val))
+"@ 2>$null
+    if ($LASTEXITCODE -ne 0 -or -not $result) { return $Default }
+    return $result.Trim()
+}
+
+$MAX_ASSERTIONS = Load-ConfigValue -Key 'max_assertions' -Default '10'
+$ASSERTION_TIMEOUT = Load-ConfigValue -Key 'assertion_timeout_s' -Default '30'
+$OUTPUT_TRUNCATE = Load-ConfigValue -Key 'output_truncate_chars' -Default '500'
+
+# === Shared: diff extraction (mirrors review-agent-package algorithm) ===
+$script:PROVE_WRITE_SET = ''
+$script:PROVE_CODE_FILES = ''
+$script:PROVE_DIFF_FILES = ''
+$script:PROVE_DIFF_BASE = ''
+$script:PROVE_HEAD_COMMIT = ''
+$script:PROVE_TASK_GOAL = ''
+
+function Extract-DiffContext {
+    param([string]$TaskId)
+    $taskFile = Join-Path $ENGINE_DIR "tasks/$TaskId.md"
+
+    if (-not (Test-Path $taskFile)) {
+        [Console]::Error.WriteLine("[engine-prove] Error: task card not found: $taskFile")
+        exit 1
+    }
+
+    # Parse WRITE-SET
+    $writeSetFiles = @()
+    $inWriteSet = $false
+    foreach ($line in (Get-Content $taskFile -Encoding UTF8)) {
+        if ($line -match '^## WRITE-SET') { $inWriteSet = $true; continue }
+        if ($line -match '^## ' -and $inWriteSet) { $inWriteSet = $false; continue }
+        if ($inWriteSet -and $line -match '^- (.+)') {
+            $f = $Matches[1] -replace '\s*#.*$', ''
+            $writeSetFiles += $f.Trim()
+        }
+    }
+    $script:PROVE_WRITE_SET = ($writeSetFiles -join ' ')
+
+    # Code extensions filter
+    $codeExtensionsJson = Load-ConfigValue -Key 'code_extensions' -Default '[".sh",".ps1",".py",".js",".ts",".go",".rs",".java",".c",".cpp",".rb",".php"]'
+
+    $env:ROOT_DIR = $ROOT
+    $env:CODE_EXTS = $codeExtensionsJson
+    $env:WRITE_SET_INPUT = ($writeSetFiles -join "`n")
+    $codeFilesResult = & $PY -c @"
+import json, sys, os
+exts = set(json.loads(os.environ['CODE_EXTS']))
+root = os.environ['ROOT_DIR']
+out = []
+for line in os.environ['WRITE_SET_INPUT'].splitlines():
+    f = line.strip()
+    if not f: continue
+    if '*' in f or '?' in f: continue
+    _, ext = os.path.splitext(f)
+    if ext in exts and os.path.isfile(os.path.join(root, f)):
+        out.append(f)
+print(' '.join(out))
+"@ 2>$null
+    if ($LASTEXITCODE -ne 0) { $codeFilesResult = '' }
+    $script:PROVE_CODE_FILES = if ($codeFilesResult) { $codeFilesResult.Trim() } else { '' }
+
+    # Diff base (task_first_commit algorithm)
+    $taskFirstCommit = (git -C $ROOT log --reverse --format="%H" -- "engine/tasks/$TaskId.md" 2>$null | Select-Object -First 1)
+    if (-not $taskFirstCommit) {
+        [Console]::Error.WriteLine("[engine-prove] Error: no git history for $taskFile")
+        exit 1
+    }
+
+    $script:PROVE_HEAD_COMMIT = (git -C $ROOT rev-parse HEAD 2>$null)
+    if (-not $script:PROVE_HEAD_COMMIT) { $script:PROVE_HEAD_COMMIT = 'unknown' }
+
+    $diffBase = (cmd /c "git -C `"$ROOT`" rev-parse `"$taskFirstCommit^`" 2>nul")
+    if (-not ($diffBase -match '^[0-9a-f]{40}$')) {
+        $diffBase = '4b825dc642cb6eb9a060e54bf8d69288fbee4904'
+    }
+    $script:PROVE_DIFF_BASE = $diffBase.Trim()
+
+    # Filter to files actually changed
+    $diffFiles = @()
+    $codeFileList = if ($script:PROVE_CODE_FILES) { $script:PROVE_CODE_FILES -split '\s+' } else { @() }
+    foreach ($f in $codeFileList) {
+        if (-not $f) { continue }
+        $changed = (git -C $ROOT diff --name-only "$($script:PROVE_DIFF_BASE)..HEAD" -- $f 2>$null)
+        if ($changed) { $diffFiles += $f }
+    }
+    $script:PROVE_DIFF_FILES = ($diffFiles -join ' ')
+
+    # Extract GOAL
+    $goalLines = @()
+    $inGoal = $false
+    foreach ($line in (Get-Content $taskFile -Encoding UTF8)) {
+        if ($line -match '^## GOAL') { $inGoal = $true; continue }
+        if ($line -match '^## ' -and $inGoal) { break }
+        if ($inGoal) { $goalLines += $line }
+    }
+    $script:PROVE_TASK_GOAL = ($goalLines | Select-Object -First 5) -join "`n"
+}
+
+# === Phase 1: --infer ===
+function Invoke-PhaseInfer {
+    param([string]$TaskId)
+    $evidenceDir = Join-Path $ENGINE_DIR "evidence/$TaskId"
+    if (-not (Test-Path $evidenceDir)) { New-Item -ItemType Directory -Path $evidenceDir -Force | Out-Null }
+    $packageFile = Join-Path $evidenceDir 'prove-package.md'
+
+    Extract-DiffContext -TaskId $TaskId
+
+    # No code files -> NO-OP
+    if (-not $script:PROVE_DIFF_FILES) {
+        $ts = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
+        $noopContent = @"
+# Prove Package: $TaskId
+
+> generated: $ts
+> status: NO-OP
+> reason: no code files in diff range
+
+No assertions needed.
+"@
+        Set-Content -Path $packageFile -Value $noopContent -Encoding UTF8
+        Write-Output "[engine-prove] ${TaskId}: no code changes, package marked NO-OP"
+        exit 0
+    }
+
+    # Compute code fingerprint (sha256 of concatenated diffs)
+    $env:DIFF_BASE = $script:PROVE_DIFF_BASE
+    $env:DIFF_FILES = $script:PROVE_DIFF_FILES
+    $codeFingerprint = & $PY -c @"
+import hashlib, subprocess, os
+diff_base = os.environ['DIFF_BASE']
+files = os.environ['DIFF_FILES'].split()
+content = ''
+for f in files:
+    try:
+        out = subprocess.check_output(['git', 'diff', diff_base + '..HEAD', '--', f], stderr=subprocess.DEVNULL)
+        content += out.decode('utf-8', errors='replace')
+    except:
+        pass
+print('sha256:' + hashlib.sha256(content.encode('utf-8')).hexdigest())
+"@ 2>$null
+    if ($LASTEXITCODE -ne 0 -or -not $codeFingerprint) {
+        $codeFingerprint = 'sha256:0000000000000000000000000000000000000000000000000000000000000000'
+    }
+    $codeFingerprint = $codeFingerprint.Trim()
+
+    # Extract hunk symbols
+    $diffFileList = $script:PROVE_DIFF_FILES -split '\s+'
+    $hunkSymbols = (git -C $ROOT diff -U0 "$($script:PROVE_DIFF_BASE)..HEAD" -- @diffFileList 2>$null |
+        Where-Object { $_ -match '^@@' } |
+        ForEach-Object { $_ -replace '.*@@\s*', '' } |
+        Where-Object { $_ -ne '' } |
+        Select-Object -First 20)
+    if (-not $hunkSymbols) { $hunkSymbols = @() }
+
+    # Detect languages -> syntax checkers
+    $syntaxChecks = @()
+    foreach ($f in $diffFileList) {
+        if (-not $f) { continue }
+        $ext = [System.IO.Path]::GetExtension($f).TrimStart('.')
+        switch ($ext) {
+            'sh'   { $syntaxChecks += "- bash -n $f" }
+            'py'   { $syntaxChecks += "- python -m py_compile $f" }
+            'js'   { $syntaxChecks += "- node --check $f" }
+            'json' { $syntaxChecks += "- python -m json.tool $f" }
+        }
+    }
+
+    # Find existing test coverage
+    $testCoverage = @()
+    $testsDir = Join-Path $ROOT 'tests'
+    foreach ($f in $diffFileList) {
+        if (-not $f) { continue }
+        $basenameF = [System.IO.Path]::GetFileName($f)
+        if (Test-Path $testsDir) {
+            $matchingTests = @()
+            try {
+                $matchingTests = @(Get-ChildItem -Path $testsDir -Recurse -File -ErrorAction SilentlyContinue |
+                    Where-Object { (Get-Content $_.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue) -match [regex]::Escape($basenameF) } |
+                    Select-Object -First 3 -ExpandProperty FullName)
+            } catch {}
+            if ($matchingTests.Count -gt 0) {
+                $testCoverage += "- $f covered by:"
+                foreach ($t in $matchingTests) {
+                    $relT = $t -replace [regex]::Escape($ROOT + '\'), '' -replace [regex]::Escape($ROOT + '/'), ''
+                    $testCoverage += "  - bash $relT"
+                }
+            }
+        }
+    }
+
+    # Generate diff content
+    $diffContent = ''
+    foreach ($f in $diffFileList) {
+        if (-not $f) { continue }
+        $fileDiff = (git -C $ROOT diff "$($script:PROVE_DIFF_BASE)..HEAD" -- $f 2>$null | Out-String)
+        if ($fileDiff.Trim()) {
+            $diffContent += "`n### $f`n``````diff`n$fileDiff```````n"
+        }
+    }
+
+    # Render prove-package.md
+    $ts = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
+    $diffRangeBase = $script:PROVE_DIFF_BASE.Substring(0, [Math]::Min(8, $script:PROVE_DIFF_BASE.Length))
+    $diffRangeHead = $script:PROVE_HEAD_COMMIT.Substring(0, [Math]::Min(8, $script:PROVE_HEAD_COMMIT.Length))
+    $codeFileCount = @($diffFileList | Where-Object { $_ }).Count
+
+    $writeSetSection = ($diffFileList | Where-Object { $_ } | ForEach-Object { "- $_" }) -join "`n"
+    $hunkSection = if ($hunkSymbols.Count -gt 0) { ($hunkSymbols | ForEach-Object { "- $_" }) -join "`n" } else { '- (none detected)' }
+    $syntaxSection = if ($syntaxChecks.Count -gt 0) { $syntaxChecks -join "`n" } else { '- (none auto-detected)' }
+    $coverageSection = if ($testCoverage.Count -gt 0) { $testCoverage -join "`n" } else { '- (none found — agent should generate invariant assertions)' }
+
+    $packageContent = @"
+# Prove Package: $TaskId
+
+> generated: $ts
+> code_fingerprint: $codeFingerprint
+> head_commit: $($script:PROVE_HEAD_COMMIT)
+> diff_range: ${diffRangeBase}..${diffRangeHead}
+> code_files: $codeFileCount
+
+## GOAL
+$($script:PROVE_TASK_GOAL)
+
+## WRITE-SET (code files in diff)
+$writeSetSection
+
+## Hunk Symbols (modified functions/classes)
+$hunkSection
+
+## Syntax Checks (auto-detected)
+$syntaxSection
+
+## Existing Test Coverage
+$coverageSection
+
+## Unified Diff
+$diffContent
+
+## Assertion Generation Instructions
+
+Generate prove-assertions.json with categories:
+- **syntax**: Verify modified files parse correctly (use syntax checks above)
+- **regression**: Run existing tests covering modified files (use test coverage above)
+- **invariant**: Property tests specific to THIS change that would FAIL if reverted
+
+### Anti-Tautology Rules (MANDATORY)
+1. NEVER emit commands that always succeed (true, :, echo-only)
+2. Each assertion MUST reference a specific file or symbol from this diff
+3. Invariant assertions MUST have revert_would_fail=true
+4. Maximum $MAX_ASSERTIONS assertions total
+5. Commands must NOT contain: rm, mv, curl, wget, sudo, dd, mkfs, chmod, kill
+6. rationale must be >=20 chars and explain WHY this assertion catches regressions
+
+### Output Schema
+Write engine/evidence/$TaskId/prove-assertions.json:
+``````json
+{
+  "task_id": "$TaskId",
+  "code_fingerprint": "$codeFingerprint",
+  "assertions": [
+    {
+      "id": "A-01",
+      "category": "syntax|regression|invariant",
+      "command": "<shell command>",
+      "expect_exit": 0,
+      "timeout_s": 30,
+      "rationale": "<why this matters, >=20 chars>",
+      "revert_would_fail": false
+    }
+  ]
+}
+``````
+"@
+
+    Set-Content -Path $packageFile -Value $packageContent -Encoding UTF8
+
+    $pkgLines = (Get-Content $packageFile).Count
+    Write-Output "[engine-prove] ${TaskId}: prove-package ready ($pkgLines lines)"
+    Write-Output "[engine-prove] code_fingerprint: $codeFingerprint"
+    Write-Output "[engine-prove] Next: agent reads package, writes prove-assertions.json"
+}
+
+# === Phase 2: --execute ===
+function Invoke-PhaseExecute {
+    param([string]$TaskId)
+    $evidenceDir = Join-Path $ENGINE_DIR "evidence/$TaskId"
+    $assertionsFile = Join-Path $evidenceDir 'prove-assertions.json'
+    $proveJson = Join-Path $evidenceDir 'PROVE.json'
+
+    # 1. Check assertions file exists
+    if (-not (Test-Path $assertionsFile)) {
+        [Console]::Error.WriteLine("[engine-prove] FAIL: $assertionsFile not found. Run --infer first, then agent generates assertions.")
+        exit 1
+    }
+
+    # 2. Schema validation (python-based, no jq dependency)
+    $env:ASSERTIONS_FILE = $assertionsFile
+    $env:MAX_A = $MAX_ASSERTIONS
+    & $PY -c @"
+import json, os, sys
+
+with open(os.environ['ASSERTIONS_FILE'], encoding='utf-8') as f:
+    try:
+        data = json.load(f)
+    except json.JSONDecodeError as e:
+        print(f'[engine-prove] FAIL E_SCHEMA: invalid JSON: {e}', file=sys.stderr)
+        sys.exit(1)
+
+errors = []
+max_a = int(os.environ['MAX_A'])
+
+# Required fields
+for field in ['task_id', 'code_fingerprint', 'assertions']:
+    if field not in data:
+        errors.append(f'missing field: {field}')
+
+if errors:
+    for e in errors:
+        print(f'[engine-prove] FAIL E_SCHEMA: {e}', file=sys.stderr)
+    sys.exit(1)
+
+# task_id format
+import re
+if not re.match(r'^T-[0-9]{3}$', data['task_id']):
+    errors.append(f'invalid task_id: {data["task_id"]}')
+
+# fingerprint format
+if not re.match(r'^sha256:[a-f0-9]{64}$', data.get('code_fingerprint', '')):
+    errors.append('invalid code_fingerprint format')
+
+# assertions array
+assertions = data.get('assertions', [])
+if not isinstance(assertions, list):
+    errors.append('assertions must be array')
+elif len(assertions) == 0:
+    errors.append('assertions must have at least 1 item')
+elif len(assertions) > max_a:
+    errors.append(f'too many assertions ({len(assertions)} > {max_a})')
+
+for i, a in enumerate(assertions):
+    prefix = f'assertions[{i}]'
+    for req in ['id', 'category', 'command', 'expect_exit', 'rationale']:
+        if req not in a:
+            errors.append(f'{prefix}: missing {req}')
+    if a.get('category') not in ('syntax', 'regression', 'invariant'):
+        errors.append(f'{prefix}: invalid category: {a.get("category")}')
+    if not re.match(r'^A-[0-9]{2}$', a.get('id', '')):
+        errors.append(f'{prefix}: invalid id format: {a.get("id")}')
+    if len(a.get('command', '')) > 500:
+        errors.append(f'{prefix}: command too long (>500 chars)')
+    if len(a.get('rationale', '')) < 20:
+        errors.append(f'{prefix}: rationale too short (<20 chars)')
+    if a.get('category') == 'invariant' and a.get('revert_would_fail') is not True:
+        errors.append(f'{prefix}: invariant must have revert_would_fail=true')
+
+if errors:
+    for e in errors:
+        print(f'[engine-prove] FAIL E_SCHEMA: {e}', file=sys.stderr)
+    sys.exit(1)
+"@
+    if ($LASTEXITCODE -ne 0) { exit 1 }
+
+    # 3. Staleness guard: recompute fingerprint and compare
+    Extract-DiffContext -TaskId $TaskId
+
+    $env:DIFF_BASE = $script:PROVE_DIFF_BASE
+    $env:DIFF_FILES = $script:PROVE_DIFF_FILES
+    $currentFp = & $PY -c @"
+import hashlib, subprocess, os
+diff_base = os.environ['DIFF_BASE']
+files = os.environ['DIFF_FILES'].split()
+content = ''
+for f in files:
+    try:
+        out = subprocess.check_output(['git', 'diff', diff_base + '..HEAD', '--', f], stderr=subprocess.DEVNULL)
+        content += out.decode('utf-8', errors='replace')
+    except:
+        pass
+print('sha256:' + hashlib.sha256(content.encode('utf-8')).hexdigest())
+"@ 2>$null
+    if ($LASTEXITCODE -ne 0 -or -not $currentFp) {
+        $currentFp = 'sha256:0000000000000000000000000000000000000000000000000000000000000000'
+    }
+    $currentFp = $currentFp.Trim()
+
+    $env:ASSERTIONS_FILE = $assertionsFile
+    $claimedFp = & $PY -c @"
+import json, os
+with open(os.environ['ASSERTIONS_FILE'], encoding='utf-8') as f:
+    data = json.load(f)
+print(data.get('code_fingerprint', ''))
+"@ 2>$null
+    if ($LASTEXITCODE -ne 0 -or -not $claimedFp) { $claimedFp = '' }
+    $claimedFp = $claimedFp.Trim()
+
+    if ($currentFp -ne $claimedFp) {
+        [Console]::Error.WriteLine("[engine-prove] FAIL E_STALE: code changed since inference (current=$currentFp, claimed=$claimedFp). Re-run --infer.")
+        exit 1
+    }
+
+    # 4. Safety validation (blocklist + anti-tautology + relevance)
+    $blockedJson = Load-ConfigValue -Key 'blocked_commands' -Default '["rm","mv","curl","wget","sudo","dd","mkfs"]'
+    $env:ASSERTIONS_FILE = $assertionsFile
+    $env:DIFF_FILES = $script:PROVE_DIFF_FILES
+    $env:BLOCKED_JSON = $blockedJson
+    & $PY -c @"
+import json, os, sys, re
+
+with open(os.environ['ASSERTIONS_FILE'], encoding='utf-8') as f:
+    data = json.load(f)
+
+blocked = json.loads(os.environ['BLOCKED_JSON'])
+diff_files = os.environ['DIFF_FILES'].split()
+errors = []
+
+for a in data.get('assertions', []):
+    cmd = a.get('command', '')
+    aid = a.get('id', '?')
+
+    # Blocklist check
+    for b in blocked:
+        if re.search(r'\b' + re.escape(b) + r'\b', cmd):
+            errors.append(f'{aid}: blocked command word "{b}" in: {cmd[:80]}')
+
+    # Tautology check
+    stripped = cmd.strip()
+    if stripped in ('true', ':', 'exit 0') or re.match(r'^(echo|printf)\s', stripped):
+        errors.append(f'{aid}: tautological command (always succeeds): {stripped[:60]}')
+
+    # Relevance: must reference at least one diff file or its basename
+    referenced = False
+    for f in diff_files:
+        if f in cmd or os.path.basename(f) in cmd:
+            referenced = True
+            break
+    # Also accept if command references a test file that covers diff files
+    if not referenced and 'test' in cmd.lower():
+        referenced = True  # test commands are assumed relevant
+    if not referenced:
+        errors.append(f'{aid}: command does not reference any changed file: {cmd[:80]}')
+
+if errors:
+    for e in errors:
+        print(f'[engine-prove] FAIL E_SAFETY: {e}', file=sys.stderr)
+    sys.exit(1)
+"@
+    if ($LASTEXITCODE -ne 0) { exit 1 }
+
+    # 5. Execute assertions
+    Write-Output "[engine-prove] ${TaskId}: executing assertions..."
+
+    $env:ASSERTIONS_FILE = $assertionsFile
+    $env:ROOT_DIR = $ROOT
+    $env:TIMEOUT_DEFAULT = $ASSERTION_TIMEOUT
+    $env:TRUNCATE = $OUTPUT_TRUNCATE
+    $resultsJson = & $PY -c @"
+import json, os, sys, subprocess, time, hashlib
+
+with open(os.environ['ASSERTIONS_FILE'], encoding='utf-8') as f:
+    data = json.load(f)
+
+root = os.environ['ROOT_DIR']
+timeout_default = int(os.environ['TIMEOUT_DEFAULT'])
+truncate = int(os.environ['TRUNCATE'])
+
+results = []
+total = passed = failed = timed_out = 0
+
+for a in data['assertions']:
+    total += 1
+    aid = a['id']
+    cmd = a['command']
+    expect_exit = a['expect_exit']
+    timeout_s = a.get('timeout_s', timeout_default)
+
+    start = time.time()
+    try:
+        proc = subprocess.run(
+            cmd, shell=True, capture_output=True, timeout=timeout_s,
+            cwd=root, stdin=subprocess.DEVNULL
+        )
+        exit_code = proc.returncode
+        output = (proc.stdout + proc.stderr).decode('utf-8', errors='replace')
+        status = 'PASS' if exit_code == expect_exit else 'FAIL'
+    except subprocess.TimeoutExpired:
+        exit_code = 124
+        output = f'TIMEOUT after {timeout_s}s'
+        status = 'TIMEOUT'
+        timed_out += 1
+    except Exception as e:
+        exit_code = 1
+        output = str(e)
+        status = 'FAIL'
+
+    duration_ms = int((time.time() - start) * 1000)
+
+    # Output constraints
+    if status == 'PASS':
+        if a.get('expect_output_contains') and a['expect_output_contains'] not in output:
+            status = 'FAIL'
+        if a.get('expect_output_not_contains') and a['expect_output_not_contains'] in output:
+            status = 'FAIL'
+
+    if status == 'PASS':
+        passed += 1
+    elif status == 'TIMEOUT':
+        pass  # already counted
+    else:
+        failed += 1
+
+    results.append({
+        'id': aid,
+        'category': a['category'],
+        'command': cmd[:200],
+        'status': status,
+        'exit_code': exit_code,
+        'expect_exit': expect_exit,
+        'duration_ms': duration_ms,
+        'output_fingerprint': 'sha256:' + hashlib.sha256(output.encode('utf-8')).hexdigest(),
+        'output_truncated': output[:truncate]
+    })
+
+    # Progress
+    print(f'  {aid} [{a["category"]}] {status} ({duration_ms}ms)', file=sys.stderr)
+
+print(json.dumps({'total': total, 'passed': passed, 'failed': failed, 'timed_out': timed_out, 'results': results}))
+"@
+    if ($LASTEXITCODE -ne 0 -or -not $resultsJson) {
+        $resultsJson = '{"total":0,"passed":0,"failed":0,"timed_out":0,"results":[]}'
+    }
+    $resultsJson = ($resultsJson | Out-String).Trim()
+
+    # Parse results
+    $env:RESULTS_JSON = $resultsJson
+    $total = & $PY -c "import json,sys,os; d=json.loads(os.environ['RESULTS_JSON']); print(d['total'])" 2>$null
+    if ($LASTEXITCODE -ne 0 -or -not $total) { $total = '0' }
+    $total = $total.Trim()
+
+    $passed = & $PY -c "import json,sys,os; d=json.loads(os.environ['RESULTS_JSON']); print(d['passed'])" 2>$null
+    if ($LASTEXITCODE -ne 0 -or -not $passed) { $passed = '0' }
+    $passed = $passed.Trim()
+
+    $failed = & $PY -c "import json,sys,os; d=json.loads(os.environ['RESULTS_JSON']); print(d['failed'])" 2>$null
+    if ($LASTEXITCODE -ne 0 -or -not $failed) { $failed = '0' }
+    $failed = $failed.Trim()
+
+    $timedOut = & $PY -c "import json,sys,os; d=json.loads(os.environ['RESULTS_JSON']); print(d['timed_out'])" 2>$null
+    if ($LASTEXITCODE -ne 0 -or -not $timedOut) { $timedOut = '0' }
+    $timedOut = $timedOut.Trim()
+
+    $gate = if ([int]$failed -gt 0 -or [int]$timedOut -gt 0) { 'FAIL' } else { 'PASS' }
+
+    # 6. Write PROVE.json evidence
+    $env:RESULTS_JSON = $resultsJson
+    $env:GATE = $gate
+    $env:TASK_ID = $TaskId
+    $env:FP = $currentFp
+    $env:PROVE_FILE = $proveJson
+    $env:PROVE_HEAD_COMMIT = $script:PROVE_HEAD_COMMIT
+    & $PY -c @"
+import json, os, hashlib
+from datetime import datetime, timezone
+
+results = json.loads(os.environ['RESULTS_JSON'])
+gate = os.environ['GATE']
+task_id = os.environ['TASK_ID']
+fp = os.environ['FP']
+prove_file = os.environ['PROVE_FILE']
+
+# Compute assertions fingerprint
+assertions_file = prove_file.replace('PROVE.json', 'prove-assertions.json')
+af_hash = ''
+if os.path.isfile(assertions_file):
+    with open(assertions_file, 'rb') as f:
+        af_hash = 'sha256:' + hashlib.sha256(f.read()).hexdigest()
+
+evidence = {
+    'schema_version': '1.0',
+    'task_id': task_id,
+    'command': f'engine prove {task_id} --execute',
+    'timestamp': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
+    'status': gate,
+    'code_fingerprint': fp,
+    'assertions_fingerprint': af_hash,
+    'summary': {
+        'total': results['total'],
+        'passed': results['passed'],
+        'failed': results['failed'],
+        'timed_out': results['timed_out']
+    },
+    'results': results['results'],
+    'gate': {
+        'decision': gate,
+        'rule': 'ALL assertions must pass; any FAIL or TIMEOUT = gate FAIL'
+    },
+    'write_provenance': {
+        'writer': 'engine-prove',
+        'commit': os.environ.get('PROVE_HEAD_COMMIT', ''),
+        'timestamp': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
+        'argv': f'engine prove {task_id} --execute'
+    }
+}
+
+with open(prove_file, 'w', encoding='utf-8', newline='\n') as f:
+    json.dump(evidence, f, indent=2, ensure_ascii=False)
+"@
+    if ($LASTEXITCODE -ne 0) {
+        [Console]::Error.WriteLine("[engine-prove] error writing PROVE.json")
+        exit 1
+    }
+
+    # 7. Report + exit
+    Write-Output "[engine-prove] ${TaskId}: $gate ($passed/$total passed, $failed failed, $timedOut timed out)"
+    if ($gate -eq 'PASS') {
+        exit 0
+    } else {
+        exit 1
+    }
+}
+
+# === Dispatch ===
+switch ($Mode) {
+    '--infer'   { Invoke-PhaseInfer -TaskId $Task }
+    '--execute' { Invoke-PhaseExecute -TaskId $Task }
+    default {
+        [Console]::Error.WriteLine("Usage: engine prove T-NNN --infer|--execute")
+        exit 2
+    }
+}
+
+} finally {
+    if ($lockStream) { $lockStream.Dispose() }
+}
```

### tests/workstream/test_prove_infer.sh
```diff
diff --git a/tests/workstream/test_prove_infer.sh b/tests/workstream/test_prove_infer.sh
new file mode 100644
index 0000000..6d958df
--- /dev/null
+++ b/tests/workstream/test_prove_infer.sh
@@ -0,0 +1,157 @@
+#!/usr/bin/env bash
+# Test: engine prove --infer (T-074, v6.23.0)
+#
+# Scenarios:
+#   S1: basic single-file change → prove-package.md with diff/symbols/fingerprint
+#   S2: no code files changed → NO-OP package
+#   S3: multi-file change → all files in package
+
+set -u
+PASS=0; FAIL=0
+assert_exit() {
+  local desc="$1" expected="$2" actual="$3"
+  if [ "$actual" -eq "$expected" ]; then
+    PASS=$((PASS+1)); echo "  PASS: $desc (exit $actual)"
+  else
+    FAIL=$((FAIL+1)); echo "  FAIL: $desc (expected exit $expected, got $actual)"
+  fi
+}
+assert_contains() {
+  local desc="$1" haystack="$2" needle="$3"
+  if echo "$haystack" | grep -qi "$needle"; then
+    PASS=$((PASS+1)); echo "  PASS: $desc"
+  else
+    FAIL=$((FAIL+1)); echo "  FAIL: $desc ('$needle' not found)"
+  fi
+}
+assert_file_exists() {
+  local desc="$1" path="$2"
+  if [ -f "$path" ]; then
+    PASS=$((PASS+1)); echo "  PASS: $desc"
+  else
+    FAIL=$((FAIL+1)); echo "  FAIL: $desc (file not found: $path)"
+  fi
+}
+
+echo "=== test_prove_infer.sh ==="
+
+SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
+ROOT_REPO="$(cd "$SCRIPT_DIR/../.." && pwd)"
+PROVE_SH="$ROOT_REPO/engine/scripts/engine-prove.sh"
+
+TMPDIR_TEST=$(mktemp -d)
+trap 'rm -rf "$TMPDIR_TEST"' EXIT
+
+setup_repo() {
+  local dir="$1"
+  mkdir -p "$dir/engine/scripts" "$dir/engine/prove" "$dir/engine/evidence" "$dir/engine/tasks" "$dir/src"
+  cd "$dir"
+  git init -q
+  git config user.email "test@test.com"
+  git config user.name "Test"
+  # Minimal config
+  echo '{"defaults":{"assertion_timeout_s":30,"max_assertions":10,"code_extensions":[".sh",".py",".js"]},"overrides":{}}' > engine/prove/config.json
+  # Copy prove script
+  cp "$PROVE_SH" engine/scripts/engine-prove.sh
+  git add -A && git commit -qm "init"
+}
+
+# --- S1: basic single-file change ---
+echo ""
+echo "--- S1: single .sh file modified → package with diff/symbols/fingerprint ---"
+S1="$TMPDIR_TEST/s1"
+setup_repo "$S1"
+
+# Create task card
+cat > engine/tasks/T-001.md << 'EOF'
+# T-001: Test task
+status: active
+## GOAL
+Test the prove system
+## WRITE-SET
+- src/hello.sh
+EOF
+git add -A && git commit -qm "task card"
+
+# Make a code change
+cat > src/hello.sh << 'SCRIPT'
+#!/usr/bin/env bash
+greet() {
+  local name="$1"
+  if [ -z "$name" ]; then
+    echo "Hello, World!"
+  else
+    echo "Hello, $name!"
+  fi
+}
+greet "$@"
+SCRIPT
+git add -A && git commit -qm "add hello.sh"
+
+OUT1=$(CLAUDE_PROJECT_DIR="$S1" bash engine/scripts/engine-prove.sh T-001 --infer 2>&1); RC1=$?
+assert_exit "S1 infer exits 0" 0 $RC1
+assert_file_exists "S1 prove-package.md exists" "$S1/engine/evidence/T-001/prove-package.md"
+
+PKG1=$(cat "$S1/engine/evidence/T-001/prove-package.md" 2>/dev/null || echo "")
+assert_contains "S1 has code_fingerprint" "$PKG1" "code_fingerprint: sha256:"
+assert_contains "S1 has diff content" "$PKG1" "greet"
+assert_contains "S1 has hunk symbols" "$PKG1" "Hunk Symbols"
+assert_contains "S1 has syntax checks" "$PKG1" "bash -n"
+assert_contains "S1 has anti-tautology rules" "$PKG1" "Anti-Tautology"
+assert_contains "S1 has output schema" "$PKG1" "prove-assertions.json"
+
+# --- S2: no code files → NO-OP ---
+echo ""
+echo "--- S2: only .md changed → NO-OP package ---"
+S2="$TMPDIR_TEST/s2"
+setup_repo "$S2"
+
+cat > engine/tasks/T-002.md << 'EOF'
+# T-002: Docs only
+status: active
+## GOAL
+Update documentation
+## WRITE-SET
+- README.md
+EOF
+git add -A && git commit -qm "task card"
+echo "# Hello" > README.md
+git add -A && git commit -qm "docs"
+
+OUT2=$(CLAUDE_PROJECT_DIR="$S2" bash engine/scripts/engine-prove.sh T-002 --infer 2>&1); RC2=$?
+assert_exit "S2 infer exits 0" 0 $RC2
+PKG2=$(cat "$S2/engine/evidence/T-002/prove-package.md" 2>/dev/null || echo "")
+assert_contains "S2 marked NO-OP" "$PKG2" "NO-OP"
+
+# --- S3: multi-file change ---
+echo ""
+echo "--- S3: multiple code files → all in package ---"
+S3="$TMPDIR_TEST/s3"
+setup_repo "$S3"
+
+cat > engine/tasks/T-003.md << 'EOF'
+# T-003: Multi-file
+status: active
+## GOAL
+Add utility functions
+## WRITE-SET
+- src/util.sh
+- src/helper.py
+EOF
+git add -A && git commit -qm "task card"
+
+echo 'util_func() { echo "util"; }' > src/util.sh
+echo 'def helper(): return 42' > src/helper.py
+git add -A && git commit -qm "code"
+
+OUT3=$(CLAUDE_PROJECT_DIR="$S3" bash engine/scripts/engine-prove.sh T-003 --infer 2>&1); RC3=$?
+assert_exit "S3 infer exits 0" 0 $RC3
+PKG3=$(cat "$S3/engine/evidence/T-003/prove-package.md" 2>/dev/null || echo "")
+assert_contains "S3 has util.sh" "$PKG3" "util.sh"
+assert_contains "S3 has helper.py" "$PKG3" "helper.py"
+assert_contains "S3 has python syntax check" "$PKG3" "py_compile"
+
+# --- Summary ---
+echo ""
+echo "=== RESULTS: $PASS passed, $FAIL failed ==="
+[ "$FAIL" -eq 0 ] && exit 0 || exit 1
```

### tests/workstream/test_prove_execute.sh
```diff
diff --git a/tests/workstream/test_prove_execute.sh b/tests/workstream/test_prove_execute.sh
new file mode 100644
index 0000000..d688356
--- /dev/null
+++ b/tests/workstream/test_prove_execute.sh
@@ -0,0 +1,202 @@
+#!/usr/bin/env bash
+# Test: engine prove --execute (T-074, v6.23.0)
+#
+# Scenarios:
+#   S1: all assertions pass → exit 0, PROVE.json status=PASS
+#   S2: one assertion fails → exit 1, PROVE.json status=FAIL
+#   S3: blocked command → exit 1, E_SAFETY
+#   S4: tautology command → exit 1, E_SAFETY
+#   S5: stale fingerprint → exit 1, E_STALE
+#   S6: missing assertions file → exit 1
+#   S7: schema violation (missing rationale) → exit 1, E_SCHEMA
+
+set -u
+PASS=0; FAIL=0
+assert_exit() {
+  local desc="$1" expected="$2" actual="$3"
+  if [ "$actual" -eq "$expected" ]; then
+    PASS=$((PASS+1)); echo "  PASS: $desc (exit $actual)"
+  else
+    FAIL=$((FAIL+1)); echo "  FAIL: $desc (expected exit $expected, got $actual)"
+  fi
+}
+assert_contains() {
+  local desc="$1" haystack="$2" needle="$3"
+  if echo "$haystack" | grep -qi "$needle"; then
+    PASS=$((PASS+1)); echo "  PASS: $desc"
+  else
+    FAIL=$((FAIL+1)); echo "  FAIL: $desc ('$needle' not found)"
+  fi
+}
+assert_file_exists() {
+  local desc="$1" path="$2"
+  if [ -f "$path" ]; then
+    PASS=$((PASS+1)); echo "  PASS: $desc"
+  else
+    FAIL=$((FAIL+1)); echo "  FAIL: $desc (file not found: $path)"
+  fi
+}
+
+echo "=== test_prove_execute.sh ==="
+
+SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
+ROOT_REPO="$(cd "$SCRIPT_DIR/../.." && pwd)"
+PROVE_SH="$ROOT_REPO/engine/scripts/engine-prove.sh"
+
+PY=python3
+command -v python3 >/dev/null 2>&1 || PY=python
+
+TMPDIR_TEST=$(mktemp -d)
+trap 'rm -rf "$TMPDIR_TEST"' EXIT
+
+# Setup a repo with a code change and run --infer to get fingerprint
+setup_execute_env() {
+  local dir="$1"
+  mkdir -p "$dir/engine/scripts" "$dir/engine/prove" "$dir/engine/evidence/T-001" "$dir/src" "$dir/engine/tasks"
+  cd "$dir"
+  git init -q
+  git config user.email "test@test.com"
+  git config user.name "Test"
+  echo '{"defaults":{"assertion_timeout_s":30,"max_assertions":10,"output_truncate_chars":500,"blocked_commands":["rm","mv","curl","wget","sudo","dd","mkfs","chmod","chown","kill","shutdown","reboot","format"],"code_extensions":[".sh",".py",".js"]},"overrides":{}}' > engine/prove/config.json
+  cp "$PROVE_SH" engine/scripts/engine-prove.sh
+
+  cat > engine/tasks/T-001.md << 'EOF'
+# T-001: Test
+status: active
+## GOAL
+Test prove execute
+## WRITE-SET
+- src/app.sh
+EOF
+  echo '#!/usr/bin/env bash' > src/app.sh
+  echo 'echo "v1"' >> src/app.sh
+  git add -A && git commit -qm "init"
+
+  # Modify code
+  echo 'echo "v2"' >> src/app.sh
+  git add -A && git commit -qm "change"
+
+  # Run infer to get fingerprint
+  CLAUDE_PROJECT_DIR="$dir" bash engine/scripts/engine-prove.sh T-001 --infer >/dev/null 2>&1
+
+  # Extract fingerprint from package
+  grep 'code_fingerprint:' engine/evidence/T-001/prove-package.md | head -1 | sed 's/.*code_fingerprint: //'
+}
+
+make_assertions() {
+  local dir="$1" fp="$2"
+  shift 2
+  # remaining args are JSON assertion objects
+  local assertions=""
+  for a in "$@"; do
+    assertions="$assertions$a,"
+  done
+  assertions="${assertions%,}"
+
+  cat > "$dir/engine/evidence/T-001/prove-assertions.json" << JSONEOF
+{
+  "task_id": "T-001",
+  "code_fingerprint": "$fp",
+  "assertions": [$assertions]
+}
+JSONEOF
+}
+
+# --- S1: all pass ---
+echo ""
+echo "--- S1: all assertions pass → exit 0, PROVE.json PASS ---"
+S1="$TMPDIR_TEST/s1"
+FP1=$(setup_execute_env "$S1")
+make_assertions "$S1" "$FP1" \
+  '{"id":"A-01","category":"syntax","command":"bash -n src/app.sh","expect_exit":0,"timeout_s":10,"rationale":"Verify app.sh has no syntax errors after modification","revert_would_fail":false}' \
+  '{"id":"A-02","category":"invariant","command":"bash -c \"source src/app.sh 2>/dev/null; true\"","expect_exit":0,"timeout_s":10,"rationale":"Verify app.sh can be sourced without crashing the shell","revert_would_fail":true}'
+
+OUT1=$(CLAUDE_PROJECT_DIR="$S1" bash engine/scripts/engine-prove.sh T-001 --execute 2>&1); RC1=$?
+assert_exit "S1 execute exits 0" 0 $RC1
+assert_file_exists "S1 PROVE.json exists" "$S1/engine/evidence/T-001/PROVE.json"
+PROVE1=$(cat "$S1/engine/evidence/T-001/PROVE.json" 2>/dev/null || echo "")
+assert_contains "S1 status PASS" "$PROVE1" '"status": "PASS"'
+
+# --- S2: one fails ---
+echo ""
+echo "--- S2: assertion expects wrong exit code → FAIL ---"
+S2="$TMPDIR_TEST/s2"
+FP2=$(setup_execute_env "$S2")
+make_assertions "$S2" "$FP2" \
+  '{"id":"A-01","category":"syntax","command":"bash -n src/app.sh","expect_exit":0,"timeout_s":10,"rationale":"Verify app.sh syntax is valid after the change","revert_would_fail":false}' \
+  '{"id":"A-02","category":"invariant","command":"grep -q nonexistent_pattern_xyz src/app.sh","expect_exit":0,"timeout_s":10,"rationale":"This assertion deliberately fails because the pattern does not exist in app.sh","revert_would_fail":true}'
+
+OUT2=$(CLAUDE_PROJECT_DIR="$S2" bash engine/scripts/engine-prove.sh T-001 --execute 2>&1); RC2=$?
+assert_exit "S2 execute exits 1" 1 $RC2
+PROVE2=$(cat "$S2/engine/evidence/T-001/PROVE.json" 2>/dev/null || echo "")
+assert_contains "S2 status FAIL" "$PROVE2" '"status": "FAIL"'
+
+# --- S3: blocked command ---
+echo ""
+echo "--- S3: command contains rm → E_SAFETY ---"
+S3="$TMPDIR_TEST/s3"
+FP3=$(setup_execute_env "$S3")
+make_assertions "$S3" "$FP3" \
+  '{"id":"A-01","category":"invariant","command":"rm -rf src/app.sh","expect_exit":0,"timeout_s":10,"rationale":"This should be blocked by safety validation","revert_would_fail":true}'
+
+OUT3=$(CLAUDE_PROJECT_DIR="$S3" bash engine/scripts/engine-prove.sh T-001 --execute 2>&1); RC3=$?
+assert_exit "S3 execute exits 1" 1 $RC3
+assert_contains "S3 E_SAFETY" "$OUT3" "E_SAFETY\|blocked"
+
+# --- S4: tautology ---
+echo ""
+echo "--- S4: command is 'true' → E_SAFETY tautology ---"
+S4="$TMPDIR_TEST/s4"
+FP4=$(setup_execute_env "$S4")
+make_assertions "$S4" "$FP4" \
+  '{"id":"A-01","category":"invariant","command":"true","expect_exit":0,"timeout_s":10,"rationale":"This is a tautological command that always passes","revert_would_fail":true}'
+
+OUT4=$(CLAUDE_PROJECT_DIR="$S4" bash engine/scripts/engine-prove.sh T-001 --execute 2>&1); RC4=$?
+assert_exit "S4 execute exits 1" 1 $RC4
+assert_contains "S4 tautology detected" "$OUT4" "tautolog\|E_SAFETY"
+
+# --- S5: stale fingerprint ---
+echo ""
+echo "--- S5: fingerprint mismatch → E_STALE ---"
+S5="$TMPDIR_TEST/s5"
+FP5=$(setup_execute_env "$S5")
+# Use a wrong fingerprint
+make_assertions "$S5" "sha256:0000000000000000000000000000000000000000000000000000000000000000" \
+  '{"id":"A-01","category":"syntax","command":"bash -n src/app.sh","expect_exit":0,"timeout_s":10,"rationale":"Verify app.sh syntax is valid after the change","revert_would_fail":false}'
+
+OUT5=$(CLAUDE_PROJECT_DIR="$S5" bash engine/scripts/engine-prove.sh T-001 --execute 2>&1); RC5=$?
+assert_exit "S5 execute exits 1" 1 $RC5
+assert_contains "S5 E_STALE" "$OUT5" "E_STALE\|stale\|Re-run"
+
+# --- S6: missing assertions file ---
+echo ""
+echo "--- S6: no prove-assertions.json → exit 1 ---"
+S6="$TMPDIR_TEST/s6"
+FP6=$(setup_execute_env "$S6")
+rm -f "$S6/engine/evidence/T-001/prove-assertions.json"
+
+OUT6=$(CLAUDE_PROJECT_DIR="$S6" bash engine/scripts/engine-prove.sh T-001 --execute 2>&1); RC6=$?
+assert_exit "S6 execute exits 1" 1 $RC6
+assert_contains "S6 mentions missing" "$OUT6" "not found\|--infer"
+
+# --- S7: schema violation ---
+echo ""
+echo "--- S7: missing rationale → E_SCHEMA ---"
+S7="$TMPDIR_TEST/s7"
+FP7=$(setup_execute_env "$S7")
+cat > "$S7/engine/evidence/T-001/prove-assertions.json" << JSONEOF
+{
+  "task_id": "T-001",
+  "code_fingerprint": "$FP7",
+  "assertions": [{"id":"A-01","category":"syntax","command":"bash -n src/app.sh","expect_exit":0}]
+}
+JSONEOF
+
+OUT7=$(CLAUDE_PROJECT_DIR="$S7" bash engine/scripts/engine-prove.sh T-001 --execute 2>&1); RC7=$?
+assert_exit "S7 execute exits 1" 1 $RC7
+assert_contains "S7 E_SCHEMA" "$OUT7" "E_SCHEMA\|rationale"
+
+# --- Summary ---
+echo ""
+echo "=== RESULTS: $PASS passed, $FAIL failed ==="
+[ "$FAIL" -eq 0 ] && exit 0 || exit 1
```


## Assertion Generation Instructions

Generate prove-assertions.json with categories:
- **syntax**: Verify modified files parse correctly (use syntax checks above)
- **regression**: Run existing tests covering modified files (use test coverage above)
- **invariant**: Property tests specific to THIS change that would FAIL if reverted

### Anti-Tautology Rules (MANDATORY)
1. NEVER emit commands that always succeed (true, :, echo-only)
2. Each assertion MUST reference a specific file or symbol from this diff
3. Invariant assertions MUST have revert_would_fail=true
4. Maximum 10 assertions total
5. Commands must NOT contain: rm, mv, curl, wget, sudo, dd, mkfs, chmod, kill
6. rationale must be >=20 chars and explain WHY this assertion catches regressions

### Output Schema
Write engine/evidence/T-074/prove-assertions.json:
```json
{
  "task_id": "T-074",
  "code_fingerprint": "sha256:c50685cb8d49dcdb32d188edd075a465e5b9aff564fad14ade5ed645b7f382e2",
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
```
