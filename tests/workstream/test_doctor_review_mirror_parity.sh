#!/usr/bin/env bash
# Test: doctor review sh/ps1 mirror parity(T-070 AC-13, v6.20.0)
# 验证 engine-doctor.sh + engine-doctor.ps1 都含 review evidence 检查逻辑(语义孪生)
set -euo pipefail
echo "[test_doctor_review_mirror_parity.sh] T-070 AC-13 doctor mirror parity"
PASS=0; FAIL=0
ok()  { echo "  PASS $1"; PASS=$((PASS+1)); }
bad() { echo "  FAIL $1"; FAIL=$((FAIL+1)); }

REPO="$PWD"
SH="$REPO/engine/scripts/engine-doctor.sh"
PS1="$REPO/engine/scripts/engine-doctor.ps1"

[ -f "$SH" ] || { bad "engine-doctor.sh missing"; echo "Results: 0 pass, 1 fail"; exit 1; }
[ -f "$PS1" ] || { bad "engine-doctor.ps1 missing"; echo "Results: 0 pass, 1 fail"; exit 1; }

# 语义孪生:两边都应含 review evidence 检查的关键标识
check_both() {
  local sh_pat="$1" ps1_pat="$2" label="$3"
  if grep -q "$sh_pat" "$SH" 2>/dev/null && grep -q "$ps1_pat" "$PS1" 2>/dev/null; then
    ok "$label"
  else
    bad "$label (sh or ps1 missing pattern)"
  fi
}

check_both "check_review_evidence" "Test-ReviewEvidence" "S1 review evidence function present"
check_both "check_review_config_protected" "Test-ReviewConfigProtected" "S2 review config protected function present"
check_both "engine-review" "engine-review" "S3 writer=engine-review check"
check_both "tool_unavailable" "tool_unavailable" "S4 tool_unavailable WARN check"
check_both '"status":"block"' "block" "S5 block FAIL check"
check_both "review/evidence" "review.evidence" "S6 review evidence path reference"

# plugin 镜像 byte-identical
for f in engine-doctor.sh engine-doctor.ps1; do
  if diff -q "$REPO/engine/scripts/$f" "$REPO/plugin/engine/scripts/$f" >/dev/null 2>&1; then
    ok "S7 $f byte-identical plugin mirror"
  else
    bad "S7 $f mirror drift"
  fi
done

echo ""
echo "=========================================="
echo "T-070 doctor mirror parity: $PASS pass, $FAIL fail"
[ "$FAIL" -eq 0 ] || exit 1
