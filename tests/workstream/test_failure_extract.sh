#!/usr/bin/env bash
# Test: failure mode auto-extraction (T-082, v6.25.0)
#
# Validates:
#   S1: Stop hook detects verify-fail (S12) → appends CAND to PITFALLS
#   S2: Stop hook detects memory-writeback (S5) → appends CAND
#   S3: Dedup — same signal not appended twice
#   S4: pre-commit EXIT trap writes .cache/last-commit-block
#   S5: Fail-open — missing PITFALLS doesn't crash stop hook
#   S6: Auto-detected section auto-created if missing

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

echo "=== test_failure_extract.sh ==="

REAL_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
STOP_SCRIPT="$REAL_ROOT/engine/scripts/engine-hook-stop.sh"
PRECOMMIT="$REAL_ROOT/engine/scripts/githooks/pre-commit"
[ -f "$STOP_SCRIPT" ] || { echo "FATAL: $STOP_SCRIPT not found"; exit 2; }
[ -f "$PRECOMMIT" ] || { echo "FATAL: $PRECOMMIT not found"; exit 2; }

# ─── Fixture ───
FIXTURE="$(mktemp -d 2>/dev/null || echo "/tmp/fe-test-$$")"
mkdir -p "$FIXTURE"
cd "$FIXTURE" || exit 2
git init -q . 2>/dev/null
git config user.email "test@test.com" 2>/dev/null
git config user.name "Test" 2>/dev/null

# Minimal engine structure
mkdir -p engine/tasks engine/evidence/T-100 engine/scripts/githooks
mkdir -p engine/domains/engine-runtime engine/.cache/sessions
mkdir -p src

# Copy scripts
cp "$STOP_SCRIPT" engine/scripts/engine-hook-stop.sh
cp "$PRECOMMIT" engine/scripts/githooks/pre-commit

# Task card
cat > engine/tasks/T-100.md << 'CARD'
# T-100: Failure extract test

status: active
lane: main
domain: engine-runtime

## GOAL

Test failure extraction.

## WRITE-SET

- src/**
- engine/CONTEXT.md

## AC

AC: AC-1 check | verify: true
CARD

# PITFALLS with Auto-detected section
cat > engine/domains/engine-runtime/PITFALLS.md << 'PIT'
# PITFALLS — engine-runtime

## Known pitfalls

- Some existing pitfall

## Auto-detected (pending review)

PIT

# Evidence: AC-1 FAIL
echo '{"ac":"AC-1","status":"fail","exit":1}' > engine/evidence/T-100/AC-1.json

# Initial commit so git is happy
git add -A 2>/dev/null
git commit -q -m "init" --no-verify 2>/dev/null

# ─── S1: verify-fail (S12) detection ───
echo "--- S1: S12 verify-fail ---"
# Simulate stop hook with active task + fail evidence
# The stop hook reads payload from stdin; provide minimal JSON
stop_payload='{"session_id":"test-s1","tool_input":{},"changed_paths":["src/foo.ts"]}'
out1="$(printf '%s' "$stop_payload" | CLAUDE_PROJECT_DIR="$FIXTURE" bash engine/scripts/engine-hook-stop.sh 2>&1)"
rc1=$?
assert_exit "stop hook exits 0 (fail-open)" 0 $rc1

pit_content="$(cat engine/domains/engine-runtime/PITFALLS.md)"
assert_contains "S12 candidate appended" "$pit_content" 'signal: S12'
assert_contains "candidate has task ref" "$pit_content" 'task: T-100'
assert_contains "candidate has dedup-key" "$pit_content" 'dedup-key:'

# ─── S2: memory-writeback (S5) detection ───
echo "--- S2: S5 memory-writeback ---"
# Reset PITFALLS and seen-keys
cat > engine/domains/engine-runtime/PITFALLS.md << 'PIT'
# PITFALLS — engine-runtime

## Auto-detected (pending review)

PIT
rm -f engine/.cache/seen-keys
# Remove fail evidence so S12 doesn't fire
rm -f engine/evidence/T-100/AC-1.json

# Simulate: code_changed=1, engine_written=0
# The stop hook determines code_changed from git diff; make a code change
echo "change" > src/bar.ts
git add src/bar.ts 2>/dev/null
# Pre-fill attribution ledger so path_owned recognizes the change
printf '%s
' "src/bar.ts" > engine/.cache/sessions/test-s1-main.paths

out2="$(printf '%s' "$stop_payload" | CLAUDE_PROJECT_DIR="$FIXTURE" bash engine/scripts/engine-hook-stop.sh 2>&1)"
rc2=$?
assert_exit "S5 stop hook exits 0" 0 $rc2
pit2="$(cat engine/domains/engine-runtime/PITFALLS.md)"
assert_contains "S5 candidate appended" "$pit2" 'signal: S5'

# ─── S3: Dedup — same signal not appended twice ───
echo "--- S3: dedup ---"
# Run again with same conditions
out3="$(printf '%s' "$stop_payload" | CLAUDE_PROJECT_DIR="$FIXTURE" bash engine/scripts/engine-hook-stop.sh 2>&1)"
pit3="$(cat engine/domains/engine-runtime/PITFALLS.md)"
s5_count="$(printf '%s' "$pit3" | grep -c 'signal: S5')"
if [ "$s5_count" -eq 1 ]; then
  PASS=$((PASS+1)); echo "  PASS: S5 not duplicated (count=1)"
else
  FAIL=$((FAIL+1)); echo "  FAIL: S5 duplicated (count=$s5_count)"
fi

# ─── S4: pre-commit EXIT trap writes signal file ───
echo "--- S4: pre-commit signal file ---"
rm -f engine/.cache/last-commit-block
# Create a commit that will be blocked (no active task WRITE-SET covers new file)
echo "blocked" > engine/protected_file.txt
git add engine/protected_file.txt 2>/dev/null
# Run pre-commit directly (it should block and write signal)
CLAUDE_PROJECT_DIR="$FIXTURE" bash engine/scripts/githooks/pre-commit >/dev/null 2>&1
# pre-commit may exit 1 (blocked) — that's expected
if [ -f engine/.cache/last-commit-block ]; then
  PASS=$((PASS+1)); echo "  PASS: last-commit-block written"
  sig_content="$(cat engine/.cache/last-commit-block)"
  assert_contains "signal file has signal ID" "$sig_content" 'S6-precommit'
else
  # pre-commit might pass if WRITE-SET covers it; check
  FAIL=$((FAIL+1)); echo "  FAIL: last-commit-block not written"
  FAIL=$((FAIL+1)); echo "  FAIL: (skipped signal content check)"
fi
git reset -q HEAD engine/protected_file.txt 2>/dev/null
rm -f engine/protected_file.txt

# ─── S5: Fail-open — missing PITFALLS ───
echo "--- S5: fail-open missing PITFALLS ---"
rm -f engine/domains/engine-runtime/PITFALLS.md
rm -f engine/.cache/seen-keys
echo '{"ac":"AC-1","status":"fail","exit":1}' > engine/evidence/T-100/AC-1.json
out5="$(printf '%s' "$stop_payload" | CLAUDE_PROJECT_DIR="$FIXTURE" bash engine/scripts/engine-hook-stop.sh 2>&1)"
rc5=$?
assert_exit "missing PITFALLS still exits 0" 0 $rc5

# ─── S6: Auto-detected section auto-created ───
echo "--- S6: auto-create section ---"
# Create PITFALLS without Auto-detected section
cat > engine/domains/engine-runtime/PITFALLS.md << 'PIT'
# PITFALLS — engine-runtime

## Known pitfalls

- Existing entry
PIT
rm -f engine/.cache/seen-keys
# Restore fail evidence for S12 detection
echo '{"ac":"AC-1","status":"fail","exit":1}' > engine/evidence/T-100/AC-1.json
# Ensure attribution ledger exists for path detection
# Include engine/CONTEXT.md so engine_written=1 (avoids S5 early-exit path)
printf '%s
%s
' "src/bar.ts" "engine/CONTEXT.md" > engine/.cache/sessions/test-s1-main.paths
echo "change2" >> src/bar.ts
echo "ctx" > engine/CONTEXT.md
out6="$(printf '%s' "$stop_payload" | CLAUDE_PROJECT_DIR="$FIXTURE" bash engine/scripts/engine-hook-stop.sh 2>&1)"
pit6="$(cat engine/domains/engine-runtime/PITFALLS.md)"
assert_contains "Auto-detected section created" "$pit6" '## Auto-detected'
assert_contains "candidate appended after auto-create" "$pit6" 'signal: S12'

# ─── Cleanup + Summary ───
cd /
rm -rf "$FIXTURE" 2>/dev/null || true
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
