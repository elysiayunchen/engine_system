#!/usr/bin/env bash
# Test: engine review-agent CLI entry (T-071 AC-1, AC-15)
# AC-1: 无模式标志 exit 2, usage 含 review-agent
# AC-15: 并发锁(2 进程,1 持锁 1 exit 1)

set -u
PASS=0; FAIL=0
assert_exit() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$actual" -eq "$expected" ]; then
    PASS=$((PASS+1)); echo "  PASS: $desc (exit $actual)"
  else
    FAIL=$((FAIL+1)); echo "  FAIL: $desc (expected exit $expected, got $actual)"
  fi
}
assert_contains() {
  local desc="$1" haystack="$2" needle="$3"
  if echo "$haystack" | grep -q "$needle"; then
    PASS=$((PASS+1)); echo "  PASS: $desc"
  else
    FAIL=$((FAIL+1)); echo "  FAIL: $desc (output does not contain '$needle')"
  fi
}

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/engine/scripts/engine-review-agent.sh"

echo "=== test_review_agent_cli.sh ==="

# S1: no args → exit 2
output=$(bash "$SCRIPT" 2>&1); rc=$?
assert_exit "S1: no args exit 2" 2 $rc
assert_contains "S1: usage mentions --package" "$output" "package"
assert_contains "S1: usage mentions --validate" "$output" "validate"

# S2: task only, no mode → exit 2
output=$(bash "$SCRIPT" T-071 2>&1); rc=$?
assert_exit "S2: task without mode exit 2" 2 $rc
assert_contains "S2: error mentions mode flag" "$output" "mode flag required"

# S3: mode only, no task → exit 2
output=$(bash "$SCRIPT" --package 2>&1); rc=$?
assert_exit "S3: mode without task exit 2" 2 $rc
assert_contains "S3: error mentions task ID" "$output" "task ID required"

# S4: nonexistent task → exit 2
output=$(bash "$SCRIPT" T-999 --package 2>&1); rc=$?
assert_exit "S4: nonexistent task exit 2" 2 $rc
assert_contains "S4: error mentions not found" "$output" "not found"

# S5: unknown argument → exit 2
output=$(bash "$SCRIPT" T-071 --bogus 2>&1); rc=$?
assert_exit "S5: unknown arg exit 2" 2 $rc

# S6: dispatcher integration (engine review-agent without engine/ → exit 2)
# (skip if not in project root context)

# S7: AC-15 concurrency lock test
# Create a temp git repo with a task card
TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT
cd "$TMPDIR_TEST"
git init -q
mkdir -p engine/tasks engine/scripts engine/review engine/bin
cp "$SCRIPT" engine/scripts/
cp "$ROOT/engine/scripts/engine-review-agent-package.sh" engine/scripts/
cp "$ROOT/engine/scripts/engine-review-agent-validate.sh" engine/scripts/
cp "$ROOT/engine/review/config.json" engine/review/
cp "$ROOT/engine/review/protocol.md" engine/review/ 2>/dev/null || true

# Create task card with agent_review enabled via L2
cat > engine/tasks/T-099.md << 'EOF'
# T-099: Test task

> status: active

GOAL: Test task for concurrency

## WRITE-SET

- test.sh

## REVIEW-OVERRIDE

- add_dimensions: agent_review

AC: AC-1 test | verify: echo pass
EOF

echo '#!/bin/bash' > test.sh
echo 'echo hello' >> test.sh
git add -A && git commit -q -m "init" --allow-empty 2>/dev/null
git add test.sh engine/tasks/T-099.md && git commit -q -m "add task" 2>/dev/null

# Hold lock: use flock if available, otherwise mkdir fallback
mkdir -p engine/review
if command -v flock >/dev/null 2>&1; then
  exec 201>engine/review/.review-agent-lock.T-099
  flock -n 201
  # Second process should fail
  output2=$(bash engine/scripts/engine-review-agent-package.sh T-099 2>&1); rc2=$?
  flock -u 201
  exec 201>&-
else
  # mkdir fallback (same as package script uses)
  mkdir engine/review/.review-agent-lock.T-099.d
  output2=$(bash engine/scripts/engine-review-agent-package.sh T-099 2>&1); rc2=$?
  rmdir engine/review/.review-agent-lock.T-099.d 2>/dev/null
fi
assert_exit "S7: concurrent process exit 1 (locked)" 1 $rc2
assert_contains "S7: lock message" "$output2" "another review-agent running"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
