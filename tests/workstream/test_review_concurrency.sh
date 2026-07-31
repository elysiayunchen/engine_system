#!/usr/bin/env bash
# Test: review concurrency flock(T-069 AC-18, v6.20.0)
set -euo pipefail
echo "[test_review_concurrency.sh] T-069 AC-18 concurrency"
PASS=0; FAIL=0
ok()  { echo "  PASS $1"; PASS=$((PASS+1)); }
bad() { echo "  FAIL $1"; FAIL=$((FAIL+1)); }

PIPELINE="$PWD/engine/scripts/engine-review-pipeline.sh"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/fake-bin"
cat > "$TMPDIR/fake-bin/semgrep" <<'MOCK'
#!/usr/bin/env bash
echo '{"results":[]}'
MOCK
cat > "$TMPDIR/fake-bin/eslint" <<'MOCK'
#!/usr/bin/env bash
echo '[]'
MOCK
chmod +x "$TMPDIR/fake-bin/semgrep" "$TMPDIR/fake-bin/eslint"

cd "$TMPDIR"
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

# 起一个持锁后台进程(占用 30s)
(
  exec 200>"$PWD/engine/review/.review-lock.T-FIX"
  if command -v flock >/dev/null 2>&1; then
    flock 200
  fi
  sleep 30
) &
HOLDER_PID=$!

# 等后台拿到锁
sleep 1

# 起第二个进程,应 fail-closed exit 1
rc=0
PATH="$TMPDIR/fake-bin:$PATH" ENGINE_DIR="$PWD/engine" bash "$PIPELINE" T-FIX >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 1 ]; then ok "S1 second review fail-closed (exit 1) while lock held"; else bad "S1 should exit 1, got $rc"; fi

# 清理
kill "$HOLDER_PID" 2>/dev/null || true
wait "$HOLDER_PID" 2>/dev/null || true

echo "Results: $PASS pass, $FAIL fail"
[ "$FAIL" -eq 0 ] || exit 1
