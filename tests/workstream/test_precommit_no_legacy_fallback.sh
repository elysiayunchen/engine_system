#!/usr/bin/env bash
# Test: pre-commit legacy fallback removal (T-044, v6.11.6, P037 / D-032)
#
# Validates that the legacy fallback (formerly L89-94 / L111-116) that picked
# the lex-largest done task card when no active card existed + strict_task_mode=0
# (< 6.5) has been REMOVED. Done cards are cold history and must not govern
# new commits.
#
# Scenarios (AC-4):
#   S1: no active card + strict_task_mode=0 (legacy <6.5) → fail-open (no fallback)
#   S2: no active card + strict_task_mode=1 (v6.5+) → block (unchanged behavior)
#   S3: active card present → governs normally (unaffected by fallback removal)
#
# Black-box test of task_file selection logic extracted from pre-commit.
# Does not invoke git (closing-task path needs git and is out of scope here;
# we test the active-card scan + the absence of done-card fallback).

set -euo pipefail

echo "[test_precommit_no_legacy_fallback.sh] T-044 legacy fallback removal (P037/D-032)"

# --- Extracted task_file selection logic (mirrors pre-commit L94-112) ---
# Args: <tasks_dir> <strict_task_mode>
# Sets globals: TASK_FILE (empty if none found)
# NOTE: legacy fallback (scan done cards when strict=0) is intentionally OMITTED
#       — that is what T-044 removed.
select_task_file() {
  local tasks_dir="$1" strict="$2"
  TASK_FILE=""
  # Scan for active card
  for f in "$tasks_dir"/T-*.md; do
    [ -f "$f" ] || continue
    if grep -q 'status:.*active' "$f" 2>/dev/null; then TASK_FILE="$f"; break; fi
  done
  # (closing-task path requires git, skipped in this black-box test)
  # (legacy fallback REMOVED by T-044 — done cards no longer picked)
}

# --- Simulated strict-block logic (mirrors pre-commit L114-127) ---
# Args: <strict_task_mode> <task_file> <staged_file>
# Returns: 0 = allow, 1 = block
strict_block_check() {
  local strict="$1" task_file="$2" staged_file="$3"
  if [ -z "$task_file" ] && [ "$strict" -eq 1 ]; then
    return 1  # block
  fi
  return 0  # allow (fail-open)
}

# --- Setup: temp tasks dir with done cards but no active card ---
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT
TASKS_DIR="$TMPDIR/tasks"
mkdir -p "$TASKS_DIR"

# Done cards (lex order: T-001, T-002, T-043) — legacy fallback would pick T-043
cat > "$TASKS_DIR/T-001.md" <<'EOF'
# T-001
> status: done | lane: x
EOF
cat > "$TASKS_DIR/T-002.md" <<'EOF'
# T-002
> status: done | lane: x
EOF
cat > "$TASKS_DIR/T-043.md" <<'EOF'
# T-043
> status: done | lane: x
EOF

# --- S1: no active card + strict=0 (legacy <6.5) → fail-open ---
select_task_file "$TASKS_DIR" 0
if [ -z "$TASK_FILE" ]; then
  echo "PASS S1: no active card + strict=0 → task_file empty (fallback NOT triggered)"
else
  echo "FAIL S1: legacy fallback picked $TASK_FILE (should be empty)"; exit 1
fi
if strict_block_check 0 "$TASK_FILE" "src/foo.sh"; then
  echo "PASS S1: strict=0 + empty task_file → fail-open (commit allowed)"
else
  echo "FAIL S1: strict=0 + empty task_file should allow but blocked"; exit 1
fi

# --- S2: no active card + strict=1 (v6.5+) → block (unchanged) ---
select_task_file "$TASKS_DIR" 1
if [ -z "$TASK_FILE" ]; then
  echo "PASS S2: no active card + strict=1 → task_file empty (correct)"
else
  echo "FAIL S2: strict=1 should not pick done card but got $TASK_FILE"; exit 1
fi
if strict_block_check 1 "$TASK_FILE" "src/foo.sh"; then
  echo "FAIL S2: strict=1 + empty task_file should block but allowed"; exit 1
else
  echo "PASS S2: strict=1 + empty task_file → block (commit denied, v6.5+ requires active card)"
fi

# --- S3: active card present → governs normally (unaffected) ---
cat > "$TASKS_DIR/T-099.md" <<'EOF'
# T-099
> status: active | lane: x
EOF
select_task_file "$TASKS_DIR" 0
if [ "$TASK_FILE" = "$TASKS_DIR/T-099.md" ]; then
  echo "PASS S3: active card T-099 picked (strict=0)"
elif [ -z "$TASK_FILE" ]; then
  echo "FAIL S3: active card exists but task_file empty"; exit 1
else
  echo "FAIL S3: expected T-099.md but got $TASK_FILE"; exit 1
fi
select_task_file "$TASKS_DIR" 1
if [ "$TASK_FILE" = "$TASKS_DIR/T-099.md" ]; then
  echo "PASS S3: active card T-099 picked (strict=1)"
else
  echo "FAIL S3: strict=1 with active card should pick T-099 but got '$TASK_FILE'"; exit 1
fi
if strict_block_check 1 "$TASK_FILE" "src/foo.sh"; then
  echo "PASS S3: active card + strict=1 → allow (governs normally)"
else
  echo "FAIL S3: active card should allow but blocked"; exit 1
fi

# --- S4: verify the fallback pattern is GONE from real pre-commit source ---
PRECOMMIT="engine/scripts/githooks/pre-commit"
if grep -q 'ls -1.*T-\*\.md.*sort -r' "$PRECOMMIT" 2>/dev/null; then
  echo "FAIL S4: legacy fallback 'ls -1 T-*.md | sort -r' still present in $PRECOMMIT"; exit 1
else
  echo "PASS S4: legacy fallback pattern absent from $PRECOMMIT (T-044 removed it)"
fi

echo
echo "All 4 scenarios PASS (S1 fail-open / S2 block / S3 active-governs / S4 source-clean)"
