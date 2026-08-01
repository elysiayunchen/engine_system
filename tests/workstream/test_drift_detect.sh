#!/usr/bin/env bash
# Test: guard drift detection (T-085, v6.26.0)
#
# Validates:
#   S1: prompt mentions non-active T-NNN → DRIFT ADVISORY (score>=3)
#   S2: prompt zero GOAL keyword overlap → score+2
#   S3: score 0 → silent (no drift output)
#   S4: fail-open — broken state doesn't crash guard

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

echo "=== test_drift_detect.sh ==="

REAL_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SESSION_START="$REAL_ROOT/engine/scripts/engine-hook-session-start.sh"
[ -f "$SESSION_START" ] || { echo "FATAL: $SESSION_START not found"; exit 2; }

# ─── Fixture ───
FIXTURE="$(mktemp -d 2>/dev/null || echo "/tmp/drift-test-$$")"
mkdir -p "$FIXTURE"
cd "$FIXTURE" || exit 2
git init -q . 2>/dev/null
mkdir -p engine/tasks engine/scripts engine/.cache/sessions

cp "$SESSION_START" engine/scripts/engine-hook-session-start.sh
# Also need canvas script for guard (fail-open if missing)
[ -f "$REAL_ROOT/engine/scripts/engine-canvas.sh" ] && cp "$REAL_ROOT/engine/scripts/engine-canvas.sh" engine/scripts/

# Active task card
cat > engine/tasks/T-100.md << 'CARD'
# T-100: Implement authentication system

status: active
lane: main
domain: engine-runtime

## GOAL

Implement JWT authentication with refresh tokens and session management.

## WRITE-SET

- src/auth/**

## AC

AC: AC-1 check | verify: true
CARD

# ─── S1: prompt mentions non-active T-NNN → DRIFT ADVISORY ───
echo "--- S1: non-active task mention ---"
payload='{"session_id":"drift-s1","prompt":"Please work on T-999 today"}'
out1="$(printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$FIXTURE" bash engine/scripts/engine-hook-session-start.sh --guard 2>&1)"
rc1=$?
assert_exit "guard exits 0" 0 $rc1
assert_contains "DRIFT ADVISORY present" "$out1" "DRIFT ADVISORY"
assert_contains "mentions T-999" "$out1" "T-999"

# ─── S2: zero GOAL keyword overlap → score+2 ───
echo "--- S2: zero keyword overlap ---"
payload2='{"session_id":"drift-s2","prompt":"banana pineapple watermelon"}'
out2="$(printf '%s' "$payload2" | CLAUDE_PROJECT_DIR="$FIXTURE" bash engine/scripts/engine-hook-session-start.sh --guard 2>&1)"
rc2=$?
assert_exit "guard exits 0 (s2)" 0 $rc2
assert_contains "drift output present" "$out2" "drift"

# ─── S3: score 0 → silent ───
echo "--- S3: no drift → silent ---"
payload3='{"session_id":"drift-s3","prompt":"Implement the JWT authentication refresh tokens"}'
out3="$(printf '%s' "$payload3" | CLAUDE_PROJECT_DIR="$FIXTURE" bash engine/scripts/engine-hook-session-start.sh --guard 2>&1)"
rc3=$?
assert_exit "guard exits 0 (s3)" 0 $rc3
assert_not_contains "no DRIFT ADVISORY" "$out3" "DRIFT ADVISORY"
assert_not_contains "no drift-hint" "$out3" "drift-hint"

# ─── S4: fail-open (no tasks dir) ───
echo "--- S4: fail-open ---"
rm -rf engine/tasks
payload4='{"session_id":"drift-s4","prompt":"T-999 something"}'
out4="$(printf '%s' "$payload4" | CLAUDE_PROJECT_DIR="$FIXTURE" bash engine/scripts/engine-hook-session-start.sh --guard 2>&1)"
rc4=$?
assert_exit "no tasks dir still exits 0" 0 $rc4

# ─── Cleanup + Summary ───
cd /
rm -rf "$FIXTURE" 2>/dev/null || true
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
