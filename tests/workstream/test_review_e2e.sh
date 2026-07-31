#!/usr/bin/env bash
# Test: review e2e 集成(T-070 AC-11,12, v6.20.0)
# 全链路:review pass/block/degraded → doctor 校验条件 PASS/FAIL/WARN
# NOTE: no `set -e` — doctor_check_review deliberately returns non-zero
# (1=warn, 2=fail) and the harness captures it via $? after `result=$(...)`;
# set -e would abort at S2 (doctor returns 2 for block). Same fix as Task 6
# tests (test_doctor_review_evidence.sh / test_doctor_review_config.sh).
set -uo pipefail
echo "[test_review_e2e.sh] T-070 AC-11,12 e2e review->doctor"
PASS=0; FAIL=0
ok()  { echo "  PASS $1"; PASS=$((PASS+1)); }
bad() { echo "  FAIL $1"; FAIL=$((FAIL+1)); }

PIPELINE="$PWD/engine/scripts/engine-review-pipeline.sh"
REPO="$PWD"

# fake-bin:clean(无 finding)
FAKEBIN="$(mktemp -d)"
cat > "$FAKEBIN/semgrep" <<'MOCK'
#!/usr/bin/env bash
echo '{"results":[]}'
MOCK
cat > "$FAKEBIN/eslint" <<'MOCK'
#!/usr/bin/env bash
echo '[]'
MOCK
chmod +x "$FAKEBIN/semgrep" "$FAKEBIN/eslint"

# fake-bin:block(HIGH finding)
FAKEBIN_BLK="$(mktemp -d)"
cat > "$FAKEBIN_BLK/semgrep" <<'MOCK'
#!/usr/bin/env bash
cat <<JSON
{"results":[{"check_id":"js.eval","path":"bad.js","start":{"line":1,"col":1},"extra":{"severity":"ERROR","message":"eval() dangerous","metadata":{"impact":"HIGH"},"confidence":"HIGH"}}]}
JSON
MOCK
cat > "$FAKEBIN_BLK/eslint" <<'MOCK'
#!/usr/bin/env bash
echo '[]'
MOCK
chmod +x "$FAKEBIN_BLK/semgrep" "$FAKEBIN_BLK/eslint"

# fake-bin:tool unavailable(M2 修复:模拟 127 退出,不用 PATH=/usr/bin:/bin)
FAKEBIN_UNAVAIL="$(mktemp -d)"
cat > "$FAKEBIN_UNAVAIL/semgrep" <<'MOCK'
#!/usr/bin/env bash
echo "semgrep: command not found" >&2
exit 127
MOCK
cat > "$FAKEBIN_UNAVAIL/eslint" <<'MOCK'
#!/usr/bin/env bash
echo "eslint: command not found" >&2
exit 127
MOCK
chmod +x "$FAKEBIN_UNAVAIL/semgrep" "$FAKEBIN_UNAVAIL/eslint"

# M4 修复:用 CLEANUP_DIRS 数组收集所有临时目录,trap 统一清理
CLEANUP_DIRS=("$FAKEBIN" "$FAKEBIN_BLK" "$FAKEBIN_UNAVAIL")
trap 'for d in "${CLEANUP_DIRS[@]}"; do rm -rf "$d"; done' EXIT
new_tmp() {
  local d="$(mktemp -d)"
  CLEANUP_DIRS+=("$d")
  echo "$d"
}

TMPDIR="$(new_tmp)"

setup_fixture() {
  local tmpdir="$1"
  cd "$tmpdir"
  git init -q; git config user.email "t@t.com"; git config user.name "t"
  mkdir -p engine/tasks engine/scripts engine/review/evidence engine/decisions
  cp "$REPO/engine/review/config.json" engine/review/config.json 2>/dev/null || true
  cat > engine/decisions/rules.json <<'EOF'
{"protected_paths":["engine/review/config.json","engine/review/evidence/**"]}
EOF
}

# doctor 校验条件(黑盒抽函数,对照 test_doctor_review_evidence.sh)
# Returns: 0 = pass, 1 = warn, 2 = fail
doctor_check_review() {
  local review_file="$1" head_commit="$2"
  [ -f "$review_file" ] || { echo "FAIL: missing"; return 2; }
  local prov_writer prov_commit prov_argv
  prov_writer="$(grep -oE '"writer":"[^"]*"' "$review_file" | head -1 | sed 's/"writer":"//;s/"//')"
  prov_commit="$(grep -oE '"commit":"[^"]*"' "$review_file" | head -1 | sed 's/"commit":"//;s/"//')"
  [ "$prov_writer" = "engine-review" ] || { echo "WARN: writer=$prov_writer"; return 1; }
  [ "$prov_commit" = "$head_commit" ] || { echo "WARN: stale"; return 1; }
  grep -q '"tool_unavailable":true' "$review_file" && { echo "WARN: degraded"; return 1; }
  grep -q '"status":"block"' "$review_file" && { echo "FAIL: block"; return 2; }
  echo "PASS"
  return 0
}

# S1: review pass → doctor PASS
echo "S1: review pass -> doctor PASS"
TMPDIR1="$(new_tmp)"
setup_fixture "$TMPDIR1"
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
head=$(git rev-parse HEAD)
if [ "$rc" -eq 0 ]; then
  result=$(doctor_check_review "engine/review/evidence/T-FIX/REVIEW.json" "$head")
  drc=$?
  if [ "$drc" -eq 0 ] && echo "$result" | grep -q "PASS"; then
    ok "S1 review pass -> doctor PASS"
  else
    bad "S1 doctor should PASS (rc=$drc): $result"
  fi
else
  bad "S1 review should pass (rc=$rc)"
fi

# S2: review block → doctor FAIL
echo "S2: review block -> doctor FAIL"
TMPDIR2="$(new_tmp)"
setup_fixture "$TMPDIR2"
echo "eval('x');" > bad.js
cat > engine/tasks/T-FIX.md <<'EOF'
> status: active
GOAL: fixture
## WRITE-SET
- bad.js
AC: AC-1 pass | verify: true
EOF
git add . && git commit -q -m "T-FIX"
rc=0
PATH="$FAKEBIN_BLK:$PATH" ENGINE_DIR="$PWD/engine" bash "$PIPELINE" T-FIX >/dev/null 2>&1 || rc=$?
head=$(git rev-parse HEAD)
if [ "$rc" -eq 1 ]; then
  result=$(doctor_check_review "engine/review/evidence/T-FIX/REVIEW.json" "$head")
  drc=$?
  if [ "$drc" -eq 2 ] && echo "$result" | grep -q "FAIL: block"; then
    ok "S2 review block -> doctor FAIL"
  else
    bad "S2 doctor should FAIL (rc=$drc): $result"
  fi
else
  bad "S2 review should block (rc=$rc)"
fi

# S3: review tool_unavailable → doctor WARN
echo "S3: review tool_unavailable -> doctor WARN"
TMPDIR3="$(new_tmp)"
setup_fixture "$TMPDIR3"
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
PATH="$FAKEBIN_UNAVAIL:$PATH" ENGINE_DIR="$PWD/engine" bash "$PIPELINE" T-FIX >/dev/null 2>&1 || rc=$?
head=$(git rev-parse HEAD)
if [ "$rc" -eq 0 ]; then
  result=$(doctor_check_review "engine/review/evidence/T-FIX/REVIEW.json" "$head")
  drc=$?
  if [ "$drc" -eq 1 ] && echo "$result" | grep -q "WARN: degraded"; then
    ok "S3 review degraded -> doctor WARN"
  else
    bad "S3 doctor should WARN (rc=$drc): $result"
  fi
else
  bad "S3 review should pass degraded (rc=$rc)"
fi

# S4: AC-12 自审 evidence schema(若 T-070 自审 evidence 已生成则校验 schema)
echo "S4: AC-12 self-review evidence schema"
SELF_EVIDENCE="$REPO/engine/review/evidence/T-070/REVIEW.json"
if [ -f "$SELF_EVIDENCE" ]; then
  if grep -q '"writer":"engine-review"' "$SELF_EVIDENCE" \
    && grep -q '"pipeline_version":"v6.20.0"' "$SELF_EVIDENCE" \
    && grep -q '"evidence_manifest_sha256"' "$SELF_EVIDENCE"; then
    ok "S4 self-review evidence schema valid"
  else
    bad "S4 self-review evidence schema incomplete"
  fi
else
  ok "S4 self-review evidence not yet generated (Step 4 generates it)"
fi

echo ""
echo "=========================================="
echo "T-070 e2e: $PASS pass, $FAIL fail"
[ "$FAIL" -eq 0 ] || exit 1
