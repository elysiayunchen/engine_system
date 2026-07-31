#!/usr/bin/env bash
# Test: pre-commit review evidence provenance gate (T-070, v6.20.0)
#
# Validates the review evidence provenance check added to
# engine/scripts/githooks/pre-commit (independent block after AC-PASS check).
# Legal path: writer="engine-review" + commit==HEAD + argv="engine review <task>"
# Any other shape = tampering, commit blocked.
#
# Scenarios:
#   S1: clean machine evidence -> PASS
#   S2: writer=human (not engine-review) -> FAIL
#   S3: provenance.commit != HEAD -> FAIL (stale)
#   S4: argv mismatch -> FAIL
#   S5: cross-task review evidence (T-066 commits T-065 evidence) -> FAIL
#
# Black-box test of extracted provenance decision logic (mirrors pre-commit
# review block). Pattern follows test_evidence_provenance.sh.

set -euo pipefail

echo "[test_precommit_review_provenance.sh] T-070 pre-commit review provenance gate"

PASS=0
FAIL=0
ok()  { echo "  PASS $1"; PASS=$((PASS+1)); }
bad() { echo "  FAIL $1"; FAIL=$((FAIL+1)); }

# --- Extracted review provenance decision logic (mirrors pre-commit review block) ---
# Args: <evidence_json_file> <head_commit> <task_id>
# Returns: 0 = PASS, 1 = FAIL
check_review_provenance() {
  local ev_file="$1" head="$2" task_id="$3"
  local evidence prov_writer prov_commit prov_argv
  evidence="$(cat "$ev_file" 2>/dev/null || true)"

  prov_writer="$(printf '%s\n' "$evidence" | grep -oE '"writer":"[^"]*"' | head -1 | sed 's/"writer":"//;s/"//')"
  prov_commit="$(printf '%s\n' "$evidence" | grep -oE '"commit":"[^"]*"' | head -1 | sed 's/"commit":"//;s/"//')"
  prov_argv="$(printf '%s\n' "$evidence" | grep -oE '"argv":"[^"]*"' | head -1 | sed 's/"argv":"//;s/"//')"

  [ "$prov_writer" = "engine-review" ] || return 1
  [ "$prov_commit" = "$head" ] || return 1
  [ "$prov_argv" = "engine review $task_id" ] || return 1
  return 0
}

# --- card_owns_itself check (mirrors pre-commit) ---
# Args: <task_id> <staged_files_dir> <root>
# Returns: 0 = task is the active/staged-done card (owns itself)
check_card_owns_itself() {
  local task_id="$1" root="$2"
  local card="$root/engine/tasks/$task_id.md"
  if [ -f "$card" ] && grep -Eq '^[[:space:]]*(>[[:space:]]*)?status:[[:space:]]*active' "$card" 2>/dev/null; then return 0; fi
  return 1
}

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

HEAD="abc123def456abc123def456abc123def456abc1"
TASK="T-999"
OTHER_TASK="T-888"

write_ev() {
  local file="$1" content="$2"
  printf '%s\n' "$content" > "$file"
}

# Active card fixture(so card_owns_itself passes for TASK)
mkdir -p "$TMPDIR/engine/tasks"
cat > "$TMPDIR/engine/tasks/$TASK.md" <<EOF
> status: active | lane: engine-runtime | decision: D-0XX | domain: engine-runtime
GOAL: fixture
EOF
cat > "$TMPDIR/engine/tasks/$OTHER_TASK.md" <<EOF
> status: active | lane: engine-runtime | decision: D-0XX | domain: engine-runtime
GOAL: other fixture
EOF

# =============================================================================
# S1: clean machine evidence -> PASS
# =============================================================================
echo "S1: clean machine evidence -> PASS"
write_ev "$TMPDIR/s1.json" '{"task":"T-999","status":"pass","write_provenance":{"writer":"engine-review","commit":"'"$HEAD"'","argv":"engine review '"$TASK"'"}}'
if check_review_provenance "$TMPDIR/s1.json" "$HEAD" "$TASK"; then ok "S1 pass"; else bad "S1 should pass"; fi

# =============================================================================
# S2: writer=human (not engine-review) -> FAIL
# =============================================================================
echo "S2: writer=human -> FAIL"
write_ev "$TMPDIR/s2.json" '{"task":"T-999","status":"pass","write_provenance":{"writer":"human","commit":"'"$HEAD"'","argv":"engine review '"$TASK"'"}}'
if check_review_provenance "$TMPDIR/s2.json" "$HEAD" "$TASK"; then bad "S2 should fail"; else ok "S2 fail (writer=human rejected)"; fi

# =============================================================================
# S3: provenance.commit != HEAD -> FAIL (stale)
# =============================================================================
echo "S3: commit != HEAD -> FAIL"
write_ev "$TMPDIR/s3.json" '{"task":"T-999","status":"pass","write_provenance":{"writer":"engine-review","commit":"0000000000000000000000000000000000000001","argv":"engine review '"$TASK"'"}}'
if check_review_provenance "$TMPDIR/s3.json" "$HEAD" "$TASK"; then bad "S3 should fail"; else ok "S3 fail (stale commit rejected)"; fi

# =============================================================================
# S4: argv mismatch -> FAIL
# =============================================================================
echo "S4: argv mismatch -> FAIL"
write_ev "$TMPDIR/s4.json" '{"task":"T-999","status":"pass","write_provenance":{"writer":"engine-review","commit":"'"$HEAD"'","argv":"engine review T-888"}}'
if check_review_provenance "$TMPDIR/s4.json" "$HEAD" "$TASK"; then bad "S4 should fail"; else ok "S4 fail (argv mismatch rejected)"; fi

# =============================================================================
# S5: cross-task review evidence (T-066 commits T-065 evidence) -> FAIL
# T-066 是 active 卡,evidence 路径含 T-065 → card_owns_itself 失败
# =============================================================================
echo "S5: cross-task review evidence -> FAIL"
# 模拟:T-066 active,evidence 路径是 engine/review/evidence/T-065/REVIEW.json
# 提取 _tid=T-065 与 active 卡 T-066 不匹配 → 不豁免 → protected-path gate 拦
if check_card_owns_itself "T-065" "$TMPDIR"; then
  bad "S5 should fail (T-065 not active)"
else
  ok "S5 fail (cross-task evidence not exempt by card_owns_itself)"
fi

echo ""
echo "=========================================="
echo "T-070 review provenance: $PASS pass, $FAIL fail"
[ "$FAIL" -eq 0 ] || exit 1
