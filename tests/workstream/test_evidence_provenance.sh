#!/usr/bin/env bash
# Test: pre-commit evidence provenance gate (T-066, v6.18.0, D-038d #7)
#
# Validates the provenance check added to engine/scripts/githooks/pre-commit
# (L408-444). Two legal paths exist for evidence committed with a done card:
#   (a) machine-written: write_provenance.writer="engine-verify" AND
#       provenance.commit == HEAD AND argv matches "engine verify <task>"
#   (b) manual edit: evidence JSON carries "evidence-manual-edit" marker
#       (covering decision enforced by protected-path gate upstream).
# Any other shape = tampering, commit blocked.
#
# Scenarios:
#   S1: clean machine evidence -> PASS
#   S2: missing write_provenance entirely -> FAIL (writer empty)
#   S3: writer=manual (not engine-verify) -> FAIL
#   S4: provenance.commit != HEAD -> FAIL
#   S5: evidence-manual-edit marker present -> PASS (exempt path)
#   S6: argv mismatch (not "engine verify <task>") -> FAIL
#
# Black-box test of the extracted provenance decision logic (mirrors
# pre-commit L408-444, T-066/D-038d #7).
# Pattern follows test_precommit_done_card_governing.sh (T-065/issue #21).

set -euo pipefail

echo "[test_evidence_provenance.sh] T-066 pre-commit evidence provenance gate"

PASS=0
FAIL=0
ok()  { echo "  PASS $1"; PASS=$((PASS+1)); }
bad() { echo "  FAIL $1"; FAIL=$((FAIL+1)); }

# --- Extracted provenance decision logic (mirrors pre-commit L408-444) ---
# Args: <evidence_json_file> <head_commit> <task_id>
# Returns: 0 = PASS (provenance valid OR manual-edit marker), 1 = FAIL (tamper)
check_provenance() {
  local ev_file="$1" head="$2" task_id="$3"
  local evidence prov_writer prov_commit prov_argv
  evidence="$(cat "$ev_file" 2>/dev/null || true)"

  # Path (b): manual-edit marker -> exempt
  if printf '%s\n' "$evidence" | grep -q '"evidence-manual-edit"'; then
    return 0
  fi

  # Path (a): machine-written provenance
  prov_writer="$(printf '%s\n' "$evidence" | grep -oE '"writer":"[^"]*"' | head -1 | sed 's/"writer":"//;s/"//')"
  prov_commit="$(printf '%s\n' "$evidence" | grep -oE '"commit":"[^"]*"' | head -1 | sed 's/"commit":"//;s/"//')"
  prov_argv="$(printf '%s\n' "$evidence" | grep -oE '"argv":"[^"]*"' | head -1 | sed 's/"argv":"//;s/"//')"

  [ "$prov_writer" = "engine-verify" ] || return 1
  [ "$prov_commit" = "$head" ] || return 1
  [ "$prov_argv" = "engine verify $task_id" ] || return 1
  return 0
}

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

HEAD="abc123def456abc123def456abc123def456abc1"
TASK="T-999"

write_ev() {
  local file="$1" content="$2"
  printf '%s\n' "$content" > "$file"
}

# =============================================================================
# S1: clean machine evidence -> PASS
# =============================================================================
echo "S1: clean machine evidence -> PASS"
write_ev "$TMPDIR/s1.json" '{"ac":"AC-1","status":"pass","write_provenance":{"writer":"engine-verify","commit":"'"$HEAD"'","argv":"engine verify '"$TASK"'"}}'
if check_provenance "$TMPDIR/s1.json" "$HEAD" "$TASK"; then ok "S1 pass"; else bad "S1 should pass"; fi

# =============================================================================
# S2: missing write_provenance entirely -> FAIL
# =============================================================================
echo "S2: missing write_provenance -> FAIL"
write_ev "$TMPDIR/s2.json" '{"ac":"AC-1","status":"pass"}'
if check_provenance "$TMPDIR/s2.json" "$HEAD" "$TASK"; then bad "S2 should fail"; else ok "S2 fail"; fi

# =============================================================================
# S3: writer=manual (not engine-verify) -> FAIL
# =============================================================================
echo "S3: writer=manual -> FAIL"
write_ev "$TMPDIR/s3.json" '{"ac":"AC-1","status":"pass","write_provenance":{"writer":"manual","commit":"'"$HEAD"'","argv":"engine verify '"$TASK"'"}}'
if check_provenance "$TMPDIR/s3.json" "$HEAD" "$TASK"; then bad "S3 should fail"; else ok "S3 fail"; fi

# =============================================================================
# S4: provenance.commit != HEAD -> FAIL
# =============================================================================
echo "S4: commit != HEAD -> FAIL"
write_ev "$TMPDIR/s4.json" '{"ac":"AC-1","status":"pass","write_provenance":{"writer":"engine-verify","commit":"0000000000000000000000000000000000000001","argv":"engine verify '"$TASK"'"}}'
if check_provenance "$TMPDIR/s4.json" "$HEAD" "$TASK"; then bad "S4 should fail"; else ok "S4 fail"; fi

# =============================================================================
# S5: evidence-manual-edit marker present -> PASS (exempt path)
# =============================================================================
echo "S5: evidence-manual-edit marker -> PASS"
write_ev "$TMPDIR/s5.json" '{"ac":"AC-1","status":"pass","evidence-manual-edit":true,"note":"covering D-999"}'
if check_provenance "$TMPDIR/s5.json" "$HEAD" "$TASK"; then ok "S5 pass (exempt)"; else bad "S5 should pass"; fi

# =============================================================================
# S6: argv mismatch (not "engine verify <task>") -> FAIL
# =============================================================================
echo "S6: argv mismatch -> FAIL"
write_ev "$TMPDIR/s6.json" '{"ac":"AC-1","status":"pass","write_provenance":{"writer":"engine-verify","commit":"'"$HEAD"'","argv":"engine verify T-888"}}'
if check_provenance "$TMPDIR/s6.json" "$HEAD" "$TASK"; then bad "S6 should fail"; else ok "S6 fail"; fi

echo ""
echo "=========================================="
echo "T-066 evidence provenance: $PASS pass, $FAIL fail"
[ "$FAIL" -eq 0 ] || exit 1
