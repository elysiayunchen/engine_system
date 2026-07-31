#!/usr/bin/env bash
# Test: doctor check_review_evidence (T-070 AC-6,7,8,9, v6.20.0)
# NOTE: no `set -e` — the extracted function deliberately returns non-zero
# (1=warn, 2=fail) and the harness captures it via $?; set -e would abort
# at the first expected FAIL/WARN. Final [ "$FAIL" -eq 0 ] gate enforces exit.
set -uo pipefail
echo "[test_doctor_review_evidence.sh] T-070 AC-6,7,8,9 doctor review evidence"
PASS=0; FAIL=0
ok()  { echo "  PASS $1"; PASS=$((PASS+1)); }
bad() { echo "  FAIL $1"; FAIL=$((FAIL+1)); }

# --- Extracted doctor logic (mirrors spec §3.3 check_review_evidence) ---
# Args: <task_id> <evidence_dir> <head_status_done> <head_commit>
#   head_status_done: "yes" = HEAD 已 done (历史, WARN); "no" = 新 done (FAIL)
# Returns: 0 = pass, 1 = warn (returns warn code), 2 = fail
# Outputs: "PASS" / "WARN: msg" / "FAIL: msg"
check_review_evidence_one() {
  local task_id="$1" evidence_dir="$2" head_status_done="$3" head_commit="$4"
  local review_file="$evidence_dir/REVIEW.json"

  if [ ! -f "$review_file" ]; then
    if [ "$head_status_done" = "yes" ]; then
      echo "WARN: done task $task_id missing review evidence (legacy)"
      return 1
    else
      echo "FAIL: newly-done task $task_id missing review evidence"
      return 2
    fi
  fi

  # 校验 write_provenance
  local prov_writer prov_commit prov_argv
  prov_writer="$(grep -oE '"writer":"[^"]*"' "$review_file" | head -1 | sed 's/"writer":"//;s/"//')"
  prov_commit="$(grep -oE '"commit":"[^"]*"' "$review_file" | head -1 | sed 's/"commit":"//;s/"//')"
  prov_argv="$(grep -oE '"argv":"[^"]*"' "$review_file" | head -1 | sed 's/"argv":"//;s/"//')"

  if [ "$prov_writer" != "engine-review" ]; then
    echo "WARN: $task_id review evidence writer=$prov_writer (expected engine-review)"
    return 1
  fi
  if [ "$prov_commit" != "$head_commit" ]; then
    echo "WARN: $task_id stale review evidence (commit=$prov_commit HEAD=$head_commit)"
    return 1
  fi
  if [ "$prov_argv" != "engine review $task_id" ]; then
    echo "WARN: $task_id review evidence argv mismatch: $prov_argv"
    return 1
  fi

  # tool_unavailable == true → WARN
  if grep -q '"tool_unavailable":true' "$review_file"; then
    echo "WARN: $task_id review degraded (tool_unavailable=true), architect should confirm"
    return 1
  fi

  # status == block → FAIL
  if grep -q '"status":"block"' "$review_file"; then
    echo "FAIL: $task_id done task has unresolved block findings"
    return 2
  fi

  echo "PASS: $task_id review evidence ok"
  return 0
}

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

HEAD="abcdef1234567890abcdef1234567890abcdef12"

write_ev() {
  local file="$1" content="$2"
  mkdir -p "$(dirname "$file")"
  printf '%s\n' "$content" > "$file"
}

# S1: AC-6 新 done(HEAD status≠done)无 REVIEW.json → FAIL
echo "S1: AC-6 newly-done missing evidence -> FAIL"
write_ev "$TMPDIR/T-NEW/REVIEW.json" '{"status":"pass"}'  # 故意先写,然后删
rm "$TMPDIR/T-NEW/REVIEW.json"
result=$(check_review_evidence_one "T-NEW" "$TMPDIR/T-NEW" "no" "$HEAD")
rc=$?
if [ "$rc" -eq 2 ] && echo "$result" | grep -q "FAIL: newly-done"; then ok "S1 FAIL newly-done missing evidence"; else bad "S1 should FAIL (rc=$rc): $result"; fi

# S2: AC-7 历史 done(HEAD 已 done)无 REVIEW.json → WARN
echo "S2: AC-7 legacy done missing evidence -> WARN"
result=$(check_review_evidence_one "T-OLD" "$TMPDIR/T-OLD" "yes" "$HEAD")
rc=$?
if [ "$rc" -eq 1 ] && echo "$result" | grep -q "WARN: done task T-OLD missing review evidence (legacy)"; then ok "S2 WARN legacy missing evidence"; else bad "S2 should WARN (rc=$rc): $result"; fi

# S3: AC-8 REVIEW.json.status=block → FAIL
echo "S3: AC-8 block findings -> FAIL"
write_ev "$TMPDIR/T-BLK/REVIEW.json" '{"status":"block","write_provenance":{"writer":"engine-review","commit":"'"$HEAD"'","argv":"engine review T-BLK"}}'
result=$(check_review_evidence_one "T-BLK" "$TMPDIR/T-BLK" "yes" "$HEAD")
rc=$?
if [ "$rc" -eq 2 ] && echo "$result" | grep -q "FAIL: T-BLK done task has unresolved block findings"; then ok "S3 FAIL block findings"; else bad "S3 should FAIL (rc=$rc): $result"; fi

# S4: AC-9 tool_unavailable=true → WARN
echo "S4: AC-9 tool_unavailable -> WARN"
write_ev "$TMPDIR/T-DGD/REVIEW.json" '{"status":"pass","tool_unavailable":true,"write_provenance":{"writer":"engine-review","commit":"'"$HEAD"'","argv":"engine review T-DGD"}}'
result=$(check_review_evidence_one "T-DGD" "$TMPDIR/T-DGD" "yes" "$HEAD")
rc=$?
if [ "$rc" -eq 1 ] && echo "$result" | grep -q "WARN: T-DGD review degraded"; then ok "S4 WARN tool_unavailable"; else bad "S4 should WARN (rc=$rc): $result"; fi

# S5: 干净 evidence → PASS
echo "S5: clean evidence -> PASS"
write_ev "$TMPDIR/T-OK/REVIEW.json" '{"status":"pass","tool_unavailable":false,"write_provenance":{"writer":"engine-review","commit":"'"$HEAD"'","argv":"engine review T-OK"}}'
result=$(check_review_evidence_one "T-OK" "$TMPDIR/T-OK" "no" "$HEAD")
rc=$?
if [ "$rc" -eq 0 ] && echo "$result" | grep -q "PASS: T-OK review evidence ok"; then ok "S5 PASS clean evidence"; else bad "S5 should PASS (rc=$rc): $result"; fi

echo ""
echo "=========================================="
echo "T-070 doctor review evidence: $PASS pass, $FAIL fail"
[ "$FAIL" -eq 0 ] || exit 1
