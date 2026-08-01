#!/usr/bin/env bash
# Test: capsule heat + Doctor check_capsule_heat (T-085, v6.26.0)
#
# Validates:
#   S1: META header parsed correctly (heat field)
#   S2: heat>=5 → WARN
#   S3: heat>=3 + no related-decisions → WARN
#   S4: heat<3 → no WARN
#   S5: no META header → silent (no crash)
#   S6: fail-open — malformed META doesn't crash doctor

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

echo "=== test_capsule_heat.sh ==="

REAL_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DOCTOR="$REAL_ROOT/engine/scripts/engine-doctor.sh"
[ -f "$DOCTOR" ] || { echo "FATAL: $DOCTOR not found"; exit 2; }

# ─── Fixture ───
FIXTURE="$(mktemp -d 2>/dev/null || echo "/tmp/heat-test-$$")"
mkdir -p "$FIXTURE"
cd "$FIXTURE" || exit 2
git init -q . 2>/dev/null
git config user.email "t@t" 2>/dev/null
git config user.name "T" 2>/dev/null
mkdir -p engine/changes engine/tasks engine/scripts engine/domains/engine-runtime engine/.cache

cp "$DOCTOR" engine/scripts/engine-doctor.sh

# Minimal task card (doctor needs at least one)
cat > engine/tasks/T-100.md << 'CARD'
# T-100: test
status: done
lane: main
domain: engine-runtime
## GOAL
Test.
## AC
AC: AC-1 x | verify: true
CARD

# Minimal engine files doctor expects
echo "6.26.0" > VERSION
echo "6.26.0" > engine/VERSION
touch engine/CONTEXT.md engine/HANDOFF.md engine/ENGINE_MAP.md

# ─── S1+S2: heat>=5 → WARN ───
echo "--- S1+S2: heat>=5 WARN ---"
cat > engine/changes/CHANGE-2026-01-01-01.md << 'CAP'
-----META-START-----
created: 2026-01-01T00:00:00Z
updated: 2026-08-01T00:00:00Z
heat: 6
related-decisions: D-001
related-tasks: T-010, T-020
domain: engine-runtime
-----META-END-----

# CHANGE-2026-01-01-01 — High heat capsule

## Goal
Test high heat.
CAP

out1="$(CLAUDE_PROJECT_DIR="$FIXTURE" bash engine/scripts/engine-doctor.sh 2>&1)"
rc1=$?
assert_contains "heat>=5 WARN present" "$out1" "heat=6"
assert_contains "suggests extraction" "$out1" "high-frequency"

# ─── S3: heat>=3 + no decisions → WARN ───
echo "--- S3: heat>=3 no decisions ---"
cat > engine/changes/CHANGE-2026-01-01-02.md << 'CAP'
-----META-START-----
created: 2026-01-01T00:00:00Z
updated: 2026-08-01T00:00:00Z
heat: 4
related-decisions:
related-tasks: T-030
domain: engine-runtime
-----META-END-----

# CHANGE-2026-01-01-02 — No decisions capsule

## Goal
Test no decisions.
CAP

out2="$(CLAUDE_PROJECT_DIR="$FIXTURE" bash engine/scripts/engine-doctor.sh 2>&1)"
assert_contains "heat>=3 no-decisions WARN" "$out2" "no related-decisions"

# ─── S4: heat<3 → no WARN ───
echo "--- S4: heat<3 silent ---"
rm -f engine/changes/CHANGE-2026-01-01-01.md engine/changes/CHANGE-2026-01-01-02.md
cat > engine/changes/CHANGE-2026-01-01-03.md << 'CAP'
-----META-START-----
created: 2026-01-01T00:00:00Z
updated: 2026-08-01T00:00:00Z
heat: 2
related-decisions:
related-tasks: T-040
domain: engine-runtime
-----META-END-----

# CHANGE-2026-01-01-03 — Low heat

## Goal
Test low heat.
CAP

out3="$(CLAUDE_PROJECT_DIR="$FIXTURE" bash engine/scripts/engine-doctor.sh 2>&1)"
assert_not_contains "no heat WARN for heat=2" "$out3" "heat=2"

# ─── S5: no META header → silent ───
echo "--- S5: no META → silent ---"
rm -f engine/changes/CHANGE-2026-01-01-03.md
cat > engine/changes/CHANGE-2026-01-01-04.md << 'CAP'
# CHANGE-2026-01-01-04 — Legacy capsule without META

## Goal
Old format.
CAP

out4="$(CLAUDE_PROJECT_DIR="$FIXTURE" bash engine/scripts/engine-doctor.sh 2>&1)"
rc4=$?
assert_not_contains "no crash on missing META" "$out4" "heat="

# ─── S6: malformed META → fail-open ───
echo "--- S6: malformed META ---"
cat > engine/changes/CHANGE-2026-01-01-05.md << 'CAP'
-----META-START-----
heat: abc_not_a_number
-----META-END-----

# CHANGE-2026-01-01-05 — Broken META

## Goal
Broken.
CAP

out5="$(CLAUDE_PROJECT_DIR="$FIXTURE" bash engine/scripts/engine-doctor.sh 2>&1)"
rc5=$?
assert_not_contains "malformed heat skipped" "$out5" "heat=abc"

# ─── Cleanup + Summary ───
cd /
rm -rf "$FIXTURE" 2>/dev/null || true
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
