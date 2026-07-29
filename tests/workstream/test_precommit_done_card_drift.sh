#!/usr/bin/env bash
# Test: pre-commit AC PASS check for done-card drift (T-054, v6.14.0, issue #18)
#
# Validates that the AC PASS check only fires for cards TRANSITIONING into done
# (HEAD status != done), not for already-done cards being modified.
#
# Scenarios:
#   S1 (AC-2): active->done transition (HEAD=active, staging=done) -> CHECK AC PASS
#   S2 (AC-3): new card first done (HEAD missing, staging=done) -> CHECK AC PASS
#   S3 (AC-4): already-done modified (HEAD=done, staging=done) -> SKIP (no block)
#   S4 (AC-5): exempt marker -> SKIP regardless of transition
#
# Black-box test of the extracted HEAD-vs-staging decision logic.

set -euo pipefail

echo "[test_precommit_done_card_drift.sh] T-054 done-card drift AC PASS gate"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

PASS=0
FAIL=0
ok() { echo "  PASS $1"; PASS=$((PASS+1)); }
bad() { echo "  FAIL $1"; FAIL=$((FAIL+1)); }

# --- Extracted decision logic (mirrors pre-commit T-054 block L260-287) ---
# Args: <head_snapshot_file> <staged_snapshot_file>
# Returns: 0 = skip AC PASS check, 1 = check AC PASS (transition into done)
should_check_ac_pass() {
  local head_file="$1" staged_file="$2"
  # Staging must be status:done
  grep -Eq '^[[:space:]]*(>[[:space:]]*)?status:[[:space:]]*done' "$staged_file" || return 0
  # Exempt marker -> skip
  grep -qi 'exempt' "$staged_file" && return 0
  # v6.14.0 (T-054): HEAD already done -> skip (done-card modification)
  if [ -f "$head_file" ]; then
    grep -Eq '^[[:space:]]*(>[[:space:]]*)?status:[[:space:]]*done' "$head_file" && return 0
  fi
  # HEAD not done (active/missing/other) + staging done -> check AC PASS
  return 1
}

# ===========================================================================
# S1 (AC-2): active->done transition -> CHECK AC PASS
# ===========================================================================
echo "S1: active->done transition -> check AC PASS"
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
if ! should_check_ac_pass "$TMPDIR/s1-head.md" "$TMPDIR/s1-staged.md"; then ok "S1 transition -> check"; else bad "S1 should check AC PASS"; fi

# ===========================================================================
# S2 (AC-3): new card first done (HEAD missing) -> CHECK AC PASS
# ===========================================================================
echo "S2: new card first done (HEAD missing) -> check AC PASS"
cat > "$TMPDIR/s2-staged.md" <<'EOF'
# T-YYY
> status: done | lane: engine-runtime
AC: AC-1 | verify: echo ok
EOF
# HEAD file does not exist (new card)
rm -f "$TMPDIR/s2-head.md"
if ! should_check_ac_pass "$TMPDIR/s2-head.md" "$TMPDIR/s2-staged.md"; then ok "S2 new card -> check"; else bad "S2 should check AC PASS"; fi

# ===========================================================================
# S3 (AC-4): already-done modified (HEAD=done, staging=done) -> SKIP
# ===========================================================================
echo "S3: already-done modified -> skip AC PASS check"
cat > "$TMPDIR/s3-head.md" <<'EOF'
# T-ZZZ
> status: done | lane: engine-runtime
AC: AC-1 | verify: grep -q 6.12.1 VERSION
EOF
cat > "$TMPDIR/s3-staged.md" <<'EOF'
# T-ZZZ
> status: done | lane: engine-runtime
AC: AC-1 | verify: grep -q 6.14.0 VERSION
EOF
if should_check_ac_pass "$TMPDIR/s3-head.md" "$TMPDIR/s3-staged.md"; then ok "S3 done-modified -> skip"; else bad "S3 should skip (content drift expected)"; fi

# ===========================================================================
# S4 (AC-5): exempt marker -> SKIP regardless of transition
# ===========================================================================
echo "S4: exempt marker -> skip"
cat > "$TMPDIR/s4-head.md" <<'EOF'
# T-WWW
> status: active | lane: engine-runtime
AC: AC-1 | verify: echo ok
EOF
cat > "$TMPDIR/s4-staged.md" <<'EOF'
# T-WWW
> status: done | lane: engine-runtime
exempt: true
AC: AC-1 | verify: echo ok
EOF
if should_check_ac_pass "$TMPDIR/s4-head.md" "$TMPDIR/s4-staged.md"; then ok "S4 exempt -> skip"; else bad "S4 should skip (exempt)"; fi

# ===========================================================================
# S5: staging not done -> skip (no status:done)
# ===========================================================================
echo "S5: staging active -> skip (not done)"
cat > "$TMPDIR/s5-head.md" <<'EOF'
# T-VVV
> status: active | lane: engine-runtime
EOF
cat > "$TMPDIR/s5-staged.md" <<'EOF'
# T-VVV
> status: active | lane: engine-runtime
EOF
if should_check_ac_pass "$TMPDIR/s5-head.md" "$TMPDIR/s5-staged.md"; then ok "S5 not-done -> skip"; else bad "S5 should skip (not done)"; fi

echo ""
echo "=========================================="
echo "T-054 done-card drift: $PASS pass, $FAIL fail"
[ "$FAIL" -eq 0 ] || exit 1
