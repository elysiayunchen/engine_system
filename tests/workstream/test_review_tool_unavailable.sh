#!/usr/bin/env bash
# Test: review tool_unavailable 降级(T-069 AC-4, v6.20.0)
set -euo pipefail
echo "[test_review_tool_unavailable.sh] T-069 AC-4 tool unavailable"
PASS=0; FAIL=0
ok()  { echo "  PASS $1"; PASS=$((PASS+1)); }
bad() { echo "  FAIL $1"; FAIL=$((FAIL+1)); }

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

PIPELINE="$PWD/engine/scripts/engine-review-pipeline.sh"

cd "$TMPDIR"
git init -q
git config user.email "test@test.com"; git config user.name "test"
mkdir -p engine/tasks engine/scripts engine/review/evidence
echo "console.log('ok');" > code.js
cat > engine/tasks/T-FIX.md <<'EOF'
> status: active
GOAL: fixture
## WRITE-SET
- code.js
AC: AC-1 pass | verify: true
EOF
git add . && git commit -q -m "T-FIX fixture"

# 模拟 semgrep + eslint 不可用(fake-bin mock,对照 test_review_pipeline_block.sh)
# M2 修复:不用 PATH="/usr/bin:/bin"(会排除 git/python3),改用 fake-bin 假命令返回 127
mkdir -p "$TMPDIR/fake-bin"
cat > "$TMPDIR/fake-bin/semgrep" <<'MOCK'
#!/usr/bin/env bash
echo "semgrep: command not found" >&2
exit 127
MOCK
cat > "$TMPDIR/fake-bin/eslint" <<'MOCK'
#!/usr/bin/env bash
echo "eslint: command not found" >&2
exit 127
MOCK
chmod +x "$TMPDIR/fake-bin/semgrep" "$TMPDIR/fake-bin/eslint"
rc=0
PATH="$TMPDIR/fake-bin:$PATH" ENGINE_DIR="$PWD/engine" bash "$PIPELINE" T-FIX >/dev/null 2>&1 || rc=$?

if [ "$rc" -eq 0 ]; then ok "S1 exit 0 (degraded)"; else bad "S1 should exit 0, got $rc"; fi
if grep -q '"tool_unavailable":true' engine/review/evidence/T-FIX/REVIEW.json 2>/dev/null; then
  ok "S2 REVIEW.json tool_unavailable=true"
else
  bad "S2 REVIEW.json tool_unavailable should be true"
fi
if grep -q '"status":"skipped"' engine/review/evidence/T-FIX/SECURITY.json 2>/dev/null; then
  ok "S3 SECURITY.json status=skipped"
else
  bad "S3 SECURITY.json status should be skipped"
fi
if grep -q '"detection_command"' engine/review/evidence/T-FIX/REVIEW.json 2>/dev/null \
  && grep -q '"detection_exit_code"' engine/review/evidence/T-FIX/REVIEW.json 2>/dev/null; then
  ok "S4 tool_detection recorded (command+exit_code)"
else
  bad "S4 tool_detection missing"
fi

echo "Results: $PASS pass, $FAIL fail"
[ "$FAIL" -eq 0 ] || exit 1
