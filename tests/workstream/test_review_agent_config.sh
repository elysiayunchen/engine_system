#!/usr/bin/env bash
# Test: engine review-agent config (T-071 AC-13, AC-14)
# AC-13: agent_review.enabled=false + 无 L2 → --package exit 0 skip
# AC-14: L2 add_dimensions: agent_review 覆盖 enabled=false

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
assert_output_contains() {
  local desc="$1" output="$2" needle="$3"
  if echo "$output" | grep -qi "$needle"; then
    PASS=$((PASS+1)); echo "  PASS: $desc"
  else
    FAIL=$((FAIL+1)); echo "  FAIL: $desc ('$needle' not in output)"
  fi
}

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

echo "=== test_review_agent_config.sh ==="

# Setup
TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT
cd "$TMPDIR_TEST"
git init -q
mkdir -p engine/tasks engine/scripts engine/review

cp "$ROOT/engine/scripts/engine-review-agent-package.sh" engine/scripts/
cp "$ROOT/engine/review/config.json" engine/review/
cp "$ROOT/engine/review/protocol.md" engine/review/ 2>/dev/null || true

# Config has agent_review.enabled=false by default (from repo config.json)

# Task WITHOUT L2 override
cat > engine/tasks/T-095.md << 'EOF'
# T-095: Config test no override
> status: active
GOAL: Test config disabled
## WRITE-SET
- test.sh
AC: AC-1 | verify: echo ok
EOF
echo 'echo hi' > test.sh
git add -A && git commit -q -m "init"

# S1: AC-13 — enabled=false, no L2 → skip
output=$(bash engine/scripts/engine-review-agent-package.sh T-095 2>&1); rc=$?
assert_exit "S1: disabled config exit 0" 0 $rc
assert_output_contains "S1: mentions not enabled/skipped" "$output" "not enabled\|skipped"

# S2: AC-14 — L2 override enables it
cat > engine/tasks/T-094.md << 'EOF'
# T-094: Config test with L2
> status: active
GOAL: Test L2 override
## WRITE-SET
- test.sh
## REVIEW-OVERRIDE
- add_dimensions: agent_review
AC: AC-1 | verify: echo ok
EOF
git add engine/tasks/T-094.md && git commit -q -m "add T-094"
# Modify test.sh to create a diff after task card commit
echo '# modified for T-094' >> test.sh
git add test.sh && git commit -q -m "modify test.sh for T-094"

output=$(bash engine/scripts/engine-review-agent-package.sh T-094 2>&1); rc=$?
assert_exit "S2: L2 override exit 0 (runs)" 0 $rc
# Should produce a package (not skip)
if [ -f "engine/review/evidence/T-094/review-package.md" ]; then
  PASS=$((PASS+1)); echo "  PASS: S2: package produced despite config disabled"
else
  # May skip if no diff — check output
  if echo "$output" | grep -q "package ready"; then
    PASS=$((PASS+1)); echo "  PASS: S2: package produced"
  else
    FAIL=$((FAIL+1)); echo "  FAIL: S2: no package produced (output: $output)"
  fi
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
