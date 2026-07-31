#!/usr/bin/env bash
# Test: review diff 算法(T-069 AC-5,6, v6.20.0)
set -euo pipefail
echo "[test_review_diff_algorithm.sh] T-069 AC-5,6 diff algorithm"
PASS=0; FAIL=0
ok()  { echo "  PASS $1"; PASS=$((PASS+1)); }
bad() { echo "  FAIL $1"; FAIL=$((FAIL+1)); }

PIPELINE="$PWD/engine/scripts/engine-review-pipeline.sh"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

# mock tools(避免依赖真实 semgrep/eslint)
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

# S1: AC-5 跨 2 commit(对照 C15 真跑 git diff)
cd "$TMPDIR"
git init -q; git config user.email "t@t.com"; git config user.name "t"
mkdir -p engine/tasks engine/scripts engine/review/evidence
echo "console.log('v1');" > code.js
cat > engine/tasks/T-FIX.md <<'EOF'
> status: active
GOAL: fixture
## WRITE-SET
- code.js
AC: AC-1 pass | verify: true
EOF
git add . && git commit -q -m "T-FIX initial"
echo "console.log('v2');" > code.js
git add . && git commit -q -m "T-FIX update"

rc=0
PATH="$TMPDIR/fake-bin:$PATH" ENGINE_DIR="$PWD/engine" bash "$PIPELINE" T-FIX >/dev/null 2>&1 || rc=$?
first_commit=$(git log --reverse --format="%H" -- engine/tasks/T-FIX.md | head -1)
if [ "$rc" -eq 0 ] && grep -q "$first_commit" engine/review/evidence/T-FIX/REVIEW.json; then
  ok "S1 base_commit=first commit, exit 0"
else
  bad "S1 base_commit should be first commit (rc=$rc)"
fi

# S2: AC-6 fail-closed(任务卡从未提交)
cd "$TMPDIR"
rm -rf engine/review/evidence/T-NOCOMMIT
mkdir -p engine/tasks
cat > engine/tasks/T-NOCOMMIT.md <<'EOF'
> status: active
GOAL: no commit
## WRITE-SET
- code.js
AC: AC-1 pass | verify: true
EOF
# 不 git add 任务卡
rc=0
PATH="$TMPDIR/fake-bin:$PATH" ENGINE_DIR="$PWD/engine" bash "$PIPELINE" T-NOCOMMIT >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 1 ]; then ok "S2 exit 1 (fail-closed)"; else bad "S2 should exit 1, got $rc"; fi

# S3: AC-9 no_tool_for_language(eslint 跑 .py 文件)
cd "$TMPDIR"
rm -rf engine/review/evidence/T-PY
mkdir -p engine/tasks
echo "print('hello')" > code.py
cat > engine/tasks/T-PY.md <<'EOF'
> status: active
GOAL: python only
## WRITE-SET
- code.py
AC: AC-1 pass | verify: true
EOF
git add . && git commit -q -m "T-PY fixture"
rc=0
PATH="$TMPDIR/fake-bin:$PATH" ENGINE_DIR="$PWD/engine" bash "$PIPELINE" T-PY >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 0 ] && grep -q '"status":"no_tool_for_language"' engine/review/evidence/T-PY/QUALITY.json 2>/dev/null; then
  ok "S3 QUALITY.json status=no_tool_for_language (py)"
else
  bad "S3 should set no_tool_for_language, got rc=$rc"
fi

echo "Results: $PASS pass, $FAIL fail"
[ "$FAIL" -eq 0 ] || exit 1
