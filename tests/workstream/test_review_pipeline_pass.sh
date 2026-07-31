#!/usr/bin/env bash
# Test: review pipeline 全 pass(T-069 AC-2, v6.20.0)
set -euo pipefail
echo "[test_review_pipeline_pass.sh] T-069 AC-2 pipeline pass"
PASS=0; FAIL=0
ok()  { echo "  PASS $1"; PASS=$((PASS+1)); }
bad() { echo "  FAIL $1"; FAIL=$((FAIL+1)); }

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

# 用 $PWD 定位 pipeline(测试在项目根目录跑,对照 C16)
PIPELINE="$PWD/engine/scripts/engine-review-pipeline.sh"

cd "$TMPDIR"
git init -q
git config user.email "test@test.com"; git config user.name "test"
mkdir -p engine/tasks engine/scripts engine/review/evidence

# 干净代码(无 finding)
echo "console.log('hello');" > clean_code.js

cat > engine/tasks/T-FIX.md <<'EOF'
> status: active
GOAL: fixture
## WRITE-SET
- clean_code.js
AC: AC-1 pass | verify: true
EOF
git add . && git commit -q -m "T-FIX fixture"

# mock semgrep 不可用(确保不依赖真实工具;对照 C17)
mkdir -p .fake-bin
cat > .fake-bin/semgrep <<'MOCK'
#!/usr/bin/env bash
echo '{"results":[]}'
MOCK
cat > .fake-bin/eslint <<'MOCK'
#!/usr/bin/env bash
echo '[]'
MOCK
chmod +x .fake-bin/semgrep .fake-bin/eslint

rc=0
PATH="$TMPDIR/.fake-bin:$PATH" ENGINE_DIR="$PWD/engine" bash "$PIPELINE" T-FIX >/dev/null 2>&1 || rc=$?

if [ "$rc" -eq 0 ]; then ok "S1 exit 0"; else bad "S1 should exit 0, got $rc"; fi
if [ -f engine/review/evidence/T-FIX/REVIEW.json ]; then
  if grep -q '"status":"pass"' engine/review/evidence/T-FIX/REVIEW.json; then
    ok "S2 REVIEW.json status=pass"
  else
    bad "S2 REVIEW.json status should be pass"
  fi
else
  bad "S2 REVIEW.json missing"
fi

echo "Results: $PASS pass, $FAIL fail"
[ "$FAIL" -eq 0 ] || exit 1
