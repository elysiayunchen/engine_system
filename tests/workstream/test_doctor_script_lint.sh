#!/usr/bin/env bash
# Test: O1 check_script_lint() in engine-doctor.sh
# Verifies ShellCheck-pattern grep detection catches known violations and passes clean scripts.
set -u -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENGINE_DIR="$ROOT/engine"
PASS_COUNT=0
FAIL_COUNT=0

assert_contains() {
  local desc="$1" haystack="$2" needle="$3"
  if printf '%s' "$haystack" | grep -qF "$needle"; then
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "FAIL: $desc — expected to find '$needle'"
  fi
}

assert_not_contains() {
  local desc="$1" haystack="$2" needle="$3"
  if printf '%s' "$haystack" | grep -qF "$needle"; then
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "FAIL: $desc — did NOT expect '$needle'"
  else
    PASS_COUNT=$((PASS_COUNT + 1))
  fi
}

# --- Setup: create a temp project with dirty scripts ---
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT
mkdir -p "$TMPDIR_TEST/engine/scripts"
mkdir -p "$TMPDIR_TEST/engine/tasks"
mkdir -p "$TMPDIR_TEST/engine/domains"

# Minimal ENGINE_MAP so doctor doesn't crash
cat > "$TMPDIR_TEST/engine/ENGINE_MAP.md" <<'EOF'
# ENGINE_MAP
## §1 File Registry
| Path | Role |
|------|------|
| engine/ENGINE_MAP.md | registry |
EOF

# Dirty script with known violations
cat > "$TMPDIR_TEST/engine/scripts/dirty-test.sh" <<'DIRTY'
local result=$(some_command)
cd /tmp
read input
val=`date`
which python
cat file.txt | grep foo
DIRTY

# Clean script (no violations)
cat > "$TMPDIR_TEST/engine/scripts/clean-test.sh" <<'CLEAN'
#!/usr/bin/env bash
set -euo pipefail
local result
result="$(some_command)"
cd /tmp || exit 1
read -r input
val="$(date)"
command -v python
grep foo < file.txt
CLEAN

# --- Run doctor on dirty project ---
output_dirty="$(cd "$TMPDIR_TEST" && bash "$ENGINE_DIR/scripts/engine-doctor.sh" "$TMPDIR_TEST" 2>&1 || true)"

# S1: SC2155 detected
assert_contains "SC2155 local+assign" "$output_dirty" "SC2155"
# S2: SC2164 detected
assert_contains "SC2164 cd no error" "$output_dirty" "SC2164"
# S3: SC2162 detected
assert_contains "SC2162 read no -r" "$output_dirty" "SC2162"
# S4: SC2006 detected
assert_contains "SC2006 backticks" "$output_dirty" "SC2006"
# S5: SC2230 detected
assert_contains "SC2230 which" "$output_dirty" "SC2230"
# S6: SC2002 detected
assert_contains "SC2002 useless cat" "$output_dirty" "SC2002"
# S7: SC2148 detected (dirty script has no shebang)
assert_contains "SC2148 no shebang" "$output_dirty" "SC2148"

# --- Run doctor on clean project ---
rm -f "$TMPDIR_TEST/engine/scripts/dirty-test.sh"
output_clean="$(cd "$TMPDIR_TEST" && bash "$ENGINE_DIR/scripts/engine-doctor.sh" "$TMPDIR_TEST" 2>&1 || true)"

# S8: clean script produces no lint warnings
assert_not_contains "clean no SC2155" "$output_clean" "SC2155"
# S9: clean passes lint summary
assert_contains "clean lint pass" "$output_clean" "script lint: no ShellCheck-pattern violations"

echo ""
echo "=== test_doctor_script_lint: $PASS_COUNT passed, $FAIL_COUNT failed ==="
[ "$FAIL_COUNT" -eq 0 ] && exit 0 || exit 1
