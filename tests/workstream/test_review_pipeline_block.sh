#!/usr/bin/env bash
# Test: review pipeline block(T-069 AC-3, v6.20.0)
set -euo pipefail
echo "[test_review_pipeline_block.sh] T-069 AC-3 pipeline block"
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

# 含 eval() 的不安全代码
echo "eval('malicious code');" > bad_code.js

cat > engine/tasks/T-FIX.md <<'EOF'
> status: active
GOAL: fixture
## WRITE-SET
- bad_code.js
AC: AC-1 pass | verify: true
EOF
git add . && git commit -q -m "T-FIX fixture"

# fake semgrep 输出 HIGH impact finding(对照 C17,不用 SKIP 伪装 PASS)
mkdir -p .fake-bin
cat > .fake-bin/semgrep <<'MOCK'
#!/usr/bin/env bash
cat <<JSON
{"results":[{"check_id":"js.eval","path":"bad_code.js","start":{"line":1,"col":1},"extra":{"severity":"ERROR","message":"eval() is dangerous","metadata":{"impact":"HIGH"},"confidence":"HIGH"}}]}
JSON
MOCK
cat > .fake-bin/eslint <<'MOCK'
#!/usr/bin/env bash
echo '[]'
MOCK
chmod +x .fake-bin/semgrep .fake-bin/eslint

rc=0
PATH="$TMPDIR/.fake-bin:$PATH" ENGINE_DIR="$PWD/engine" bash "$PIPELINE" T-FIX >/dev/null 2>&1 || rc=$?

if [ "$rc" -eq 1 ]; then ok "S1 exit 1 (block)"; else bad "S1 should exit 1, got $rc"; fi
if grep -q '"status":"block"' engine/review/evidence/T-FIX/REVIEW.json 2>/dev/null; then
  ok "S2 REVIEW.json status=block"
else
  bad "S2 REVIEW.json status should be block"
fi

echo "Results: $PASS pass, $FAIL fail"
[ "$FAIL" -eq 0 ] || exit 1
