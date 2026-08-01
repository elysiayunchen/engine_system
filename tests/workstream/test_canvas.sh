#!/usr/bin/env bash
# Test: engine-canvas.sh (T-082, v6.25.0)
#
# Validates Mermaid task canvas generation:
#   S1: Active task with mixed evidence → correct status mapping + colors
#   S2: >8 AC → graph TD layout
#   S3: <=8 AC → graph LR layout
#   S4: No active task → silent (no output)
#   S5: Guard mode → one-line CANVAS summary
#   S6: Fail-open → broken evidence dir doesn't crash
#   S7: SessionStart integration → canvas block appears after task card

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
  if printf '%s' "$haystack" | grep -q "$needle"; then
    PASS=$((PASS+1)); echo "  PASS: $desc"
  else
    FAIL=$((FAIL+1)); echo "  FAIL: $desc ('$needle' not found)"
  fi
}
assert_not_contains() {
  local desc="$1" haystack="$2" needle="$3"
  if printf '%s' "$haystack" | grep -q "$needle"; then
    FAIL=$((FAIL+1)); echo "  FAIL: $desc ('$needle' unexpectedly found)"
  else
    PASS=$((PASS+1)); echo "  PASS: $desc"
  fi
}

echo "=== test_canvas.sh ==="

REAL_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CANVAS_SCRIPT="$REAL_ROOT/engine/scripts/engine-canvas.sh"
[ -f "$CANVAS_SCRIPT" ] || { echo "FATAL: $CANVAS_SCRIPT not found"; exit 2; }

# ─── Fixture: temp git repo with engine structure ───
FIXTURE="$(mktemp -d 2>/dev/null || echo "/tmp/canvas-test-$$")"
mkdir -p "$FIXTURE"
cd "$FIXTURE" || exit 2
git init -q . 2>/dev/null
mkdir -p engine/tasks engine/evidence/T-100 engine/scripts engine/domains/engine-runtime

# Copy canvas script
cp "$CANVAS_SCRIPT" engine/scripts/engine-canvas.sh

# Task card with 5 ACs (<=8 → LR)
cat > engine/tasks/T-100.md << 'CARD'
# T-100: Canvas test task

status: active
lane: main
domain: engine-runtime

## GOAL

Test canvas generation with mixed evidence states.

## WRITE-SET

- src/foo.ts

## AC

AC: AC-1 First check | verify: true
AC: AC-2 Second check | verify: true
AC: AC-3 Third check | verify: true
AC: AC-4 Fourth check | verify: true
AC: AC-5 Fifth check | verify: true
CARD

# Evidence: AC-1 pass, AC-2 pass, AC-3 fail, AC-4/5 no evidence
echo '{"ac":"AC-1","status":"pass","timestamp":"2026-08-01T10:00:00Z"}' > engine/evidence/T-100/AC-1.json
echo '{"ac":"AC-2","status":"pass","timestamp":"2026-08-01T11:00:00Z"}' > engine/evidence/T-100/AC-2.json
echo '{"ac":"AC-3","status":"fail","exit":1}' > engine/evidence/T-100/AC-3.json

# ─── S1: Mixed evidence → correct status mapping ───
echo "--- S1: status mapping ---"
out="$(CLAUDE_PROJECT_DIR="$FIXTURE" bash engine/scripts/engine-canvas.sh T-100 2>&1)"
rc=$?
assert_exit "canvas exits 0" 0 $rc
assert_contains "AC-1 done/green" "$out" 'AC1\["AC-1<br/>status: done'
assert_contains "AC-1 color green" "$out" 'style AC1 fill:#9f9'
assert_contains "AC-3 blocked/red" "$out" 'AC3\["AC-3<br/>status: blocked'
assert_contains "AC-3 color red" "$out" 'style AC3 fill:#f99'
assert_contains "AC-4 todo/purple" "$out" 'AC4\["AC-4<br/>status: todo'
assert_contains "AC-4 color purple" "$out" 'style AC4 fill:#f9f'
assert_contains "progress 2/5" "$out" 'progress: "2/5"'
assert_contains "cardStatus active" "$out" 'cardStatus: "active"'

# ─── S2: >8 AC → graph TD ───
echo "--- S2: >8 AC → TD ---"
mkdir -p engine/evidence/T-200
cat > engine/tasks/T-200.md << 'CARD'
# T-200: Big task

status: active
lane: main
domain: engine-runtime

## GOAL

Nine AC task for TD layout test.

## AC

AC: AC-1 a | verify: true
AC: AC-2 b | verify: true
AC: AC-3 c | verify: true
AC: AC-4 d | verify: true
AC: AC-5 e | verify: true
AC: AC-6 f | verify: true
AC: AC-7 g | verify: true
AC: AC-8 h | verify: true
AC: AC-9 i | verify: true
CARD

out2="$(CLAUDE_PROJECT_DIR="$FIXTURE" bash engine/scripts/engine-canvas.sh T-200 2>&1)"
assert_contains "9 AC uses graph TD" "$out2" 'graph TD'

# ─── S3: <=8 AC → graph LR ───
echo "--- S3: <=8 AC → LR ---"
assert_contains "5 AC uses graph LR" "$out" 'graph LR'

# ─── S4: No active task → silent ───
echo "--- S4: no active → silent ---"
mkdir -p "$FIXTURE/empty_repo/engine/tasks" "$FIXTURE/empty_repo/engine/scripts"
cp "$CANVAS_SCRIPT" "$FIXTURE/empty_repo/engine/scripts/engine-canvas.sh"
cd "$FIXTURE/empty_repo"
git init -q . 2>/dev/null
out4="$(CLAUDE_PROJECT_DIR="$FIXTURE/empty_repo" bash engine/scripts/engine-canvas.sh 2>&1)"
rc4=$?
assert_exit "no active exits 0" 0 $rc4
if [ -z "$out4" ]; then
  PASS=$((PASS+1)); echo "  PASS: no active → empty output"
else
  FAIL=$((FAIL+1)); echo "  FAIL: no active → expected empty, got: $out4"
fi
cd "$FIXTURE"

# ─── S5: Guard mode → one-line summary ───
echo "--- S5: guard summary ---"
out5="$(CLAUDE_PROJECT_DIR="$FIXTURE" bash engine/scripts/engine-canvas.sh --guard 2>&1)"
assert_contains "guard CANVAS line" "$out5" 'CANVAS: T-100 2/5 AC PASS'

# ─── S6: Fail-open (broken evidence) ───
echo "--- S6: fail-open ---"
mkdir -p engine/evidence/T-300
cat > engine/tasks/T-300.md << 'CARD'
# T-300: Broken evidence

status: active
lane: main
domain: engine-runtime

## GOAL

Broken evidence test.

## AC

AC: AC-1 x | verify: true
CARD
echo 'NOT JSON' > engine/evidence/T-300/AC-1.json
out6="$(CLAUDE_PROJECT_DIR="$FIXTURE" bash engine/scripts/engine-canvas.sh T-300 2>&1)"
rc6=$?
assert_exit "broken evidence exits 0" 0 $rc6
assert_contains "broken evidence still renders" "$out6" 'status: todo'

# ─── S7: SessionStart integration ───
echo "--- S7: SessionStart integration ---"
SESSION_START="$REAL_ROOT/engine/scripts/engine-hook-session-start.sh"
if [ -f "$SESSION_START" ]; then
  grep -q "engine-canvas.sh" "$SESSION_START"
  assert_exit "SessionStart references canvas" 0 $?
  grep -q "Task Canvas" "$SESSION_START"
  assert_exit "SessionStart has canvas header" 0 $?
else
  FAIL=$((FAIL+2)); echo "  FAIL: SessionStart hook not found"
fi

# ─── Cleanup + Summary ───
cd /
rm -rf "$FIXTURE" 2>/dev/null || true
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
