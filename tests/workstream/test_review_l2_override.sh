#!/usr/bin/env bash
# Test: review L2 REVIEW-OVERRIDE(T-069 AC-7,8,19, v6.20.0)
set -euo pipefail
echo "[test_review_l2_override.sh] T-069 AC-7,8,19 L2 override"
PASS=0; FAIL=0
ok()  { echo "  PASS $1"; PASS=$((PASS+1)); }
bad() { echo "  FAIL $1"; FAIL=$((FAIL+1)); }

PIPELINE="$PWD/engine/scripts/engine-review-pipeline.sh"

# fake-bin mock tools
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

run_review() {
  local override="$1"
  local tmpdir="$2"
  cd "$tmpdir"
  git init -q; git config user.email "t@t.com"; git config user.name "t"
  mkdir -p engine/tasks engine/scripts engine/review/evidence
  echo "console.log('ok');" > code.js
  cat > engine/tasks/T-FIX.md <<EOF
> status: active
GOAL: fixture
## WRITE-SET
- code.js
## REVIEW-OVERRIDE

$override
AC: AC-1 pass | verify: true
EOF
  git add . && git commit -q -m "T-FIX"
  PATH="$FAKEBIN:$PATH" ENGINE_DIR="$PWD/engine" bash "$PIPELINE" T-FIX >/dev/null 2>&1
}

# S1: AC-7 降级失败(severity_threshold=low,L0=high)
TMPDIR1="$(new_tmp)"
rc=0
run_review "- severity_threshold: low" "$TMPDIR1" || rc=$?
if [ "$rc" -eq 1 ]; then ok "S1 downgrade rejected (exit 1)"; else bad "S1 should reject downgrade, got $rc"; fi

# S2: AC-8 提级允许(severity_threshold=critical)
TMPDIR2="$(new_tmp)"
rc=0
run_review "- severity_threshold: critical" "$TMPDIR2" || rc=$?
if [ "$rc" -eq 0 ]; then ok "S2 upgrade allowed (exit 0)"; else bad "S2 should allow upgrade, got $rc"; fi

# S3: AC-19 无 REVIEW-OVERRIDE 段不报错
TMPDIR3="$(new_tmp)"
cd "$TMPDIR3"
git init -q; git config user.email "t@t.com"; git config user.name "t"
mkdir -p engine/tasks engine/scripts engine/review/evidence
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
if [ "$rc" -eq 0 ]; then ok "S3 no override ok (exit 0)"; else bad "S3 should pass without override, got $rc"; fi

# S4: skip_dimensions 降级失败(新增 AC)
TMPDIR4="$(new_tmp)"
rc=0
run_review "- skip_dimensions: security" "$TMPDIR4" || rc=$?
if [ "$rc" -eq 1 ]; then ok "S4 skip_dimensions rejected (exit 1)"; else bad "S4 should reject skip, got $rc"; fi

# S5: add_dimensions 允许(新增维度)
TMPDIR5="$(new_tmp)"
rc=0
run_review "- add_dimensions: regression" "$TMPDIR5" || rc=$?
if [ "$rc" -eq 0 ]; then ok "S5 add_dimensions allowed (exit 0)"; else bad "S5 should allow add, got $rc"; fi

echo "Results: $PASS pass, $FAIL fail"
[ "$FAIL" -eq 0 ] || exit 1
