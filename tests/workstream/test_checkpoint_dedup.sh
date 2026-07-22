#!/usr/bin/env bash
# Test: engine-verify checkpoint.md dedup behavior (T-039, v6.11.2)
#
# Simulates the dedup logic from engine/scripts/engine-verify.sh and validates:
#   (1) First AC PASS creates checkpoint.md with exactly 1 AC line.
#   (2) Same AC re-PASS keeps only 1 line (timestamp updated, no duplicate).
#   (3) Different AC PASS appends a new line (total 2 ACs).
#   (4) Re-PASS of first AC keeps total at 2 lines (dedup, no growth).
#
# This is a black-box test of the dedup algorithm (grep -v + append), which is
# the core fix in T-039. The real engine-verify.sh uses the same algorithm on
# engine/evidence/T-NNN/checkpoint.md; this test isolates it in a tmpdir.

set -euo pipefail
ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
CHECKPOINT="$TMPDIR/checkpoint.md"

# Dedup logic extracted from engine/scripts/engine-verify.sh (T-039, lines 94-117).
# Reproduced here so the test does not depend on a live task card / verify run.
write_checkpoint_line() {
  local ac_id="$1" summary="$2" ts="$3"
  if [ ! -f "$CHECKPOINT" ]; then
    cat > "$CHECKPOINT" <<CPHD
# Checkpoint — T-TEST
> Last updated: $ts by engine-verify | AC 级压缩恢复锚点

## 已完成 AC
CPHD
  fi
  local new_line
  new_line="$(printf -- '- [x] %s %s — evidence/%s.json PASS @ %s' "$ac_id" "$summary" "$ac_id" "$ts")"
  # Dedup: remove existing AC-N line(s) if any, then append fresh line.
  grep -v "^- \[x\] ${ac_id} " "$CHECKPOINT" > "$CHECKPOINT.tmp" 2>/dev/null || true
  if [ -s "$CHECKPOINT.tmp" ]; then
    mv "$CHECKPOINT.tmp" "$CHECKPOINT"
  else
    rm -f "$CHECKPOINT.tmp"
  fi
  printf -- '%s\n' "$new_line" >> "$CHECKPOINT"
}

count_ac_lines() {
  grep -c '^- \[x\] AC-' "$CHECKPOINT"
}

echo "[test_checkpoint_dedup.sh] T-039 dedup behavior"

# Test 1: First PASS creates checkpoint.md with 1 AC line.
write_checkpoint_line "AC-1" "verify cmd 1" "2026-07-22T10:00:00Z"
n=$(count_ac_lines)
if [ "$n" != "1" ]; then
  echo "FAIL: Test 1 expected 1 AC, got $n"; exit 1
fi
echo "PASS: Test 1 (first PASS creates 1 AC line)"

# Test 2: Same AC re-PASS keeps only 1 line (timestamp updated).
# Note: only the AC-1 line's timestamp is checked; the header "Last updated"
# line is created once at first PASS and intentionally not refreshed on re-PASS
# (matches engine-verify.sh behavior — header timestamp stays at creation time).
write_checkpoint_line "AC-1" "verify cmd 1" "2026-07-22T11:00:00Z"
n=$(count_ac_lines)
if [ "$n" != "1" ]; then
  echo "FAIL: Test 2 expected 1 AC after re-PASS, got $n"; exit 1
fi
ac1_line=$(grep '^- \[x\] AC-1 ' "$CHECKPOINT")
if printf '%s' "$ac1_line" | grep -q '2026-07-22T11:00:00Z' && ! printf '%s' "$ac1_line" | grep -q '2026-07-22T10:00:00Z'; then
  echo "PASS: Test 2 (re-PASS dedup, AC-1 timestamp updated)"
else
  echo "FAIL: Test 2 AC-1 timestamp not updated correctly: $ac1_line"; exit 1
fi

# Test 3: Different AC PASS appends new line.
write_checkpoint_line "AC-2" "verify cmd 2" "2026-07-22T12:00:00Z"
n=$(count_ac_lines)
if [ "$n" != "2" ]; then
  echo "FAIL: Test 3 expected 2 ACs, got $n"; exit 1
fi
echo "PASS: Test 3 (different AC appends new line)"

# Test 4: Re-PASS AC-1 keeps total at 2 (dedup, no growth).
write_checkpoint_line "AC-1" "verify cmd 1" "2026-07-22T13:00:00Z"
n=$(count_ac_lines)
if [ "$n" != "2" ]; then
  echo "FAIL: Test 4 expected 2 ACs after AC-1 re-PASS, got $n"; exit 1
fi
echo "PASS: Test 4 (AC-1 re-PASS keeps 2 lines)"

echo ""
echo "All tests passed: checkpoint.md dedup behavior verified"
