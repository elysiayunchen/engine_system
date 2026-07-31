#!/usr/bin/env bash
# Test: review config merge(T-069 AC-15,16,17, v6.20.0)
set -euo pipefail
echo "[test_review_config_merge.sh] T-069 AC-15,16,17 config merge"
PASS=0; FAIL=0
ok()  { echo "  PASS $1"; PASS=$((PASS+1)); }
bad() { echo "  FAIL $1"; FAIL=$((FAIL+1)); }

PIPELINE="$PWD/engine/scripts/engine-review-pipeline.sh"
REPO="$PWD"

# M4 修复:用 CLEANUP_DIRS 数组收集所有临时目录,trap 统一清理
CLEANUP_DIRS=()
trap 'for d in "${CLEANUP_DIRS[@]}"; do rm -rf "$d"; done' EXIT
new_tmp() {
  local d="$(mktemp -d)"
  CLEANUP_DIRS+=("$d")
  echo "$d"
}

FAKEBIN="$(new_tmp)"
cat > "$FAKEBIN/semgrep" <<'MOCK'
#!/usr/bin/env bash
echo '{"results":[]}'
MOCK
cat > "$FAKEBIN/eslint" <<'MOCK'
#!/usr/bin/env bash
echo '[]'
MOCK
chmod +x "$FAKEBIN/semgrep" "$FAKEBIN/eslint"

setup_fixture() {
  local tmpdir="$1"
  cd "$tmpdir"
  git init -q; git config user.email "t@t.com"; git config user.name "t"
  mkdir -p engine/tasks engine/scripts engine/review/evidence
  cp "$REPO/engine/review/config.json" engine/review/config.json
}

# S1: AC-15 L0=high L1=medium L2 未设 → 生效 medium
TMPDIR1="$(new_tmp)"
setup_fixture "$TMPDIR1"
# 改 L1 overrides 把 severity_threshold 设为 medium
python3 -c "
import json
with open('engine/review/config.json') as f: d=json.load(f)
d['overrides']['severity_threshold']='medium'
with open('engine/review/config.json','w') as f: json.dump(d,f)
"
echo "console.log('ok');" > code.js
cat > engine/tasks/T-FIX.md <<'EOF'
> status: active
GOAL: fixture
## WRITE-SET
- code.js
AC: AC-1 pass | verify: true
EOF
git add . && git commit -q -m "T-FIX"
rc=0
PATH="$FAKEBIN:$PATH" ENGINE_DIR="$PWD/engine" bash "$PIPELINE" T-FIX >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 0 ] && grep -q '"severity_threshold":"medium"' engine/review/evidence/T-FIX/REVIEW.json; then
  ok "S1 L1=medium overrides L0=high (severity_threshold=medium in REVIEW.json)"
else
  bad "S1 L1 override failed (rc=$rc)"
fi

# S2: AC-15 L2=critical 覆盖 L1
TMPDIR2="$(new_tmp)"
setup_fixture "$TMPDIR2"
python3 -c "
import json
with open('engine/review/config.json') as f: d=json.load(f)
d['overrides']['severity_threshold']='medium'
with open('engine/review/config.json','w') as f: json.dump(d,f)
"
echo "console.log('ok');" > code.js
cat > engine/tasks/T-FIX.md <<'EOF'
> status: active
GOAL: fixture
## WRITE-SET
- code.js
## REVIEW-OVERRIDE

- severity_threshold: critical
AC: AC-1 pass | verify: true
EOF
git add . && git commit -q -m "T-FIX"
rc=0
PATH="$FAKEBIN:$PATH" ENGINE_DIR="$PWD/engine" bash "$PIPELINE" T-FIX >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 0 ] && grep -q '"severity_threshold":"critical"' engine/review/evidence/T-FIX/REVIEW.json; then
  ok "S2 L2=critical overrides L1=medium"
else
  bad "S2 L2 override failed (rc=$rc)"
fi

# S3: AC-16 .py 触发 semgrep 不触发 eslint; .md 都不触发
TMPDIR3="$(new_tmp)"
setup_fixture "$TMPDIR3"
echo "print('ok')" > code.py
echo "console.log('ok');" > code.js
echo "# doc" > doc.md
cat > engine/tasks/T-FIX.md <<'EOF'
> status: active
GOAL: fixture
## WRITE-SET
- code.py
- code.js
- doc.md
AC: AC-1 pass | verify: true
EOF
git add . && git commit -q -m "T-FIX"
rc=0
PATH="$FAKEBIN:$PATH" ENGINE_DIR="$PWD/engine" bash "$PIPELINE" T-FIX >/dev/null 2>&1 || rc=$?
files_reviewed=$(grep -oE '"files_reviewed":\[[^]]*\]' engine/review/evidence/T-FIX/REVIEW.json)
if echo "$files_reviewed" | grep -q 'code.py' && echo "$files_reviewed" | grep -q 'code.js' && ! echo "$files_reviewed" | grep -q 'doc.md'; then
  ok "S3 .py+.js reviewed, .md skipped"
else
  bad "S3 file filtering wrong: $files_reviewed"
fi

# S4: AC-17 删 config.json 用 L0 默认
TMPDIR4="$(new_tmp)"
setup_fixture "$TMPDIR4"
rm engine/review/config.json
echo "console.log('ok');" > code.js
cat > engine/tasks/T-FIX.md <<'EOF'
> status: active
GOAL: fixture
## WRITE-SET
- code.js
AC: AC-1 pass | verify: true
EOF
git add . && git commit -q -m "T-FIX"
rc=0
PATH="$FAKEBIN:$PATH" ENGINE_DIR="$PWD/engine" bash "$PIPELINE" T-FIX >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 0 ] && grep -q '"severity_threshold":"high"' engine/review/evidence/T-FIX/REVIEW.json; then
  ok "S4 bootstrap L0 default (high) when config.json missing"
else
  bad "S4 bootstrap failed (rc=$rc)"
fi

echo "Results: $PASS pass, $FAIL fail"
[ "$FAIL" -eq 0 ] || exit 1
