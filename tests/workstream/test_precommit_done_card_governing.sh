#!/usr/bin/env bash
# Test: pre-commit governing collection skips already-done cards (T-065, v6.17.4, issue #21)
#
# Validates that the closing_paths collection (pre-commit L234-245) only adds
# cards TRANSITIONING into done (HEAD status != done) to governing_files.
# Already-done cards being modified (HEAD=done) are NOT closing and must not
# govern — otherwise their WRITE-SET blocks unrelated staged files.
#
# Scenarios:
#   S1 (AC-2): active->done transition (HEAD=active, staging=done) -> CLOSING (govern)
#   S2 (AC-3): new card first done (HEAD missing, staging=done) -> CLOSING (govern)
#   S3 (AC-4): already-done modified (HEAD=done, staging=done) -> NOT closing (skip)
#   S4: staging active -> NOT closing (skip)
#
# Black-box test of the extracted HEAD-vs-staging decision logic (mirrors
# pre-commit L234-245 closing_paths block, T-065/issue #21).
# Pattern follows test_precommit_done_card_drift.sh (T-054/issue #18).

set -euo pipefail

echo "[test_precommit_done_card_governing.sh] T-065 done-card governing gate (issue #21)"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

PASS=0
FAIL=0
ok() { echo "  PASS $1"; PASS=$((PASS+1)); }
bad() { echo "  FAIL $1"; FAIL=$((FAIL+1)); }

# --- Extracted decision logic (mirrors pre-commit T-065 block L234-245) ---
# Args: <head_snapshot_file> <staged_snapshot_file>
# Returns: 0 = NOT closing (skip, don't add to governing), 1 = CLOSING (add to governing)
is_closing_card() {
  local head_file="$1" staged_file="$2"
  # Staging must be status:done — otherwise not a close at all
  grep -Eq '^[[:space:]]*(>[[:space:]]*)?status:[[:space:]]*done' "$staged_file" || return 0
  # v6.17.4 (T-065, issue #21): HEAD already done -> not closing (done-card modification)
  if [ -f "$head_file" ]; then
    grep -Eq '^[[:space:]]*(>[[:space:]]*)?status:[[:space:]]*done' "$head_file" && return 0
  fi
  # HEAD not done (active/missing/other) + staging done -> closing (active->done transition or new card)
  return 1
}

# ===========================================================================
# S1 (AC-2): active->done transition -> CLOSING (add to governing)
# ===========================================================================
echo "S1: active->done transition -> closing (govern)"
cat > "$TMPDIR/s1-head.md" <<'EOF'
# T-XXX
> status: active | lane: engine-runtime
## WRITE-SET
- src/foo.py
AC: AC-1 | verify: echo ok
EOF
cat > "$TMPDIR/s1-staged.md" <<'EOF'
# T-XXX
> status: done | lane: engine-runtime
## WRITE-SET
- src/foo.py
AC: AC-1 | verify: echo ok
EOF
if ! is_closing_card "$TMPDIR/s1-head.md" "$TMPDIR/s1-staged.md"; then ok "S1 transition -> closing"; else bad "S1 should be closing"; fi

# ===========================================================================
# S2 (AC-3): new card first done (HEAD missing) -> CLOSING (add to governing)
# ===========================================================================
echo "S2: new card first done (HEAD missing) -> closing (govern)"
cat > "$TMPDIR/s2-staged.md" <<'EOF'
# T-YYY
> status: done | lane: engine-runtime
AC: AC-1 | verify: echo ok
EOF
# HEAD file does not exist (new card)
rm -f "$TMPDIR/s2-head.md"
if ! is_closing_card "$TMPDIR/s2-head.md" "$TMPDIR/s2-staged.md"; then ok "S2 new card -> closing"; else bad "S2 should be closing"; fi

# ===========================================================================
# S3 (AC-4): already-done modified (HEAD=done, staging=done) -> NOT closing (skip)
# This is the bug from issue #21: modifying a done card should NOT add it to
# governing, otherwise its WRITE-SET blocks unrelated staged files.
# ===========================================================================
echo "S3: already-done modified -> NOT closing (skip, don't govern)"
cat > "$TMPDIR/s3-head.md" <<'EOF'
# T-ZZZ
> status: done | lane: engine-runtime
## WRITE-SET
- engine/evidence/T-ZZZ/**
AC: AC-1 | verify: grep -q 6.12.1 VERSION
EOF
cat > "$TMPDIR/s3-staged.md" <<'EOF'
# T-ZZZ
> status: done | lane: engine-runtime
## WRITE-SET
- engine/evidence/T-ZZZ/**
AC: AC-1 | verify: grep -q 6.17.4 VERSION
EOF
if is_closing_card "$TMPDIR/s3-head.md" "$TMPDIR/s3-staged.md"; then ok "S3 done-modified -> skip"; else bad "S3 should skip (not closing)"; fi

# ===========================================================================
# S4: staging active -> NOT closing (not done)
# ===========================================================================
echo "S4: staging active -> NOT closing (not done)"
cat > "$TMPDIR/s4-head.md" <<'EOF'
# T-WWW
> status: active | lane: engine-runtime
EOF
cat > "$TMPDIR/s4-staged.md" <<'EOF'
# T-WWW
> status: active | lane: engine-runtime
EOF
if is_closing_card "$TMPDIR/s4-head.md" "$TMPDIR/s4-staged.md"; then ok "S4 active -> skip"; else bad "S4 should skip (not done)"; fi

# ===========================================================================
# S5: HEAD missing + staging active -> NOT closing (new active card, not done)
# ===========================================================================
echo "S5: new active card (HEAD missing) -> NOT closing"
cat > "$TMPDIR/s5-staged.md" <<'EOF'
# T-VVV
> status: active | lane: engine-runtime
EOF
rm -f "$TMPDIR/s5-head.md"
if is_closing_card "$TMPDIR/s5-head.md" "$TMPDIR/s5-staged.md"; then ok "S5 new active -> skip"; else bad "S5 should skip (not done)"; fi

echo ""
echo "=========================================="
echo "T-065 done-card governing: $PASS pass, $FAIL fail"
[ "$FAIL" -eq 0 ] || exit 1
