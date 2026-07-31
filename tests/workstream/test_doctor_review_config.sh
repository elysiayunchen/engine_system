#!/usr/bin/env bash
# Test: doctor check_review_config_protected (T-070 AC-10, v6.20.0)
# NOTE: no `set -e` — the extracted function deliberately returns non-zero
# (1=warn, 2=fail) and the harness captures it via $?; set -e would abort
# at the first expected FAIL/WARN. Final [ "$FAIL" -eq 0 ] gate enforces exit.
set -uo pipefail
echo "[test_doctor_review_config.sh] T-070 AC-10 doctor review config protected"
PASS=0; FAIL=0
ok()  { echo "  PASS $1"; PASS=$((PASS+1)); }
bad() { echo "  FAIL $1"; FAIL=$((FAIL+1)); }

# --- Extracted doctor logic (mirrors spec §3.3 check_review_config_protected) ---
# Args: <rules_json> <config_path> <covering_decisions_csv>
# Returns: 0 = pass, 1 = warn, 2 = fail
check_review_config_protected() {
  local rules_json="$1" config_path="$2" covering_decisions="$3"

  # 1. config_path 在 protected_paths?
  if ! grep -q '"engine/review/config.json"' "$rules_json" 2>/dev/null; then
    echo "WARN: engine/review/config.json not in protected_paths (rule gap)"
    return 1
  fi

  # 2. config 修改是否有 covering decision?
  if [ -z "$covering_decisions" ]; then
    echo "FAIL: engine/review/config.json modified without approved decision"
    return 2
  fi

  echo "PASS: engine/review/config.json protected + covering decision=$covering_decisions"
  return 0
}

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

# 造 rules.json fixture(含 config.json protected)
cat > "$TMPDIR/rules.json" <<'EOF'
{
  "protected_paths": [
    "engine/decisions/**",
    "engine/review/config.json",
    "engine/review/evidence/**"
  ]
}
EOF

# S1: config 修改无 covering decision → FAIL
echo "S1: AC-10 config modified without decision -> FAIL"
result=$(check_review_config_protected "$TMPDIR/rules.json" "$TMPDIR/engine/review/config.json" "")
rc=$?
if [ "$rc" -eq 2 ] && echo "$result" | grep -q "FAIL: engine/review/config.json modified without approved decision"; then ok "S1 FAIL no decision"; else bad "S1 should FAIL (rc=$rc): $result"; fi

# S2: config 修改有 covering decision → PASS
echo "S2: AC-10 config modified with decision -> PASS"
result=$(check_review_config_protected "$TMPDIR/rules.json" "$TMPDIR/engine/review/config.json" "D-040")
rc=$?
if [ "$rc" -eq 0 ] && echo "$result" | grep -q "PASS: engine/review/config.json protected"; then ok "S2 PASS with decision"; else bad "S2 should PASS (rc=$rc): $result"; fi

# S3: config 未在 protected_paths → WARN(rule gap)
echo "S3: AC-10 config not in protected -> WARN"
cat > "$TMPDIR/rules_no_protect.json" <<'EOF'
{
  "protected_paths": ["engine/decisions/**"]
}
EOF
result=$(check_review_config_protected "$TMPDIR/rules_no_protect.json" "$TMPDIR/engine/review/config.json" "D-040")
rc=$?
if [ "$rc" -eq 1 ] && echo "$result" | grep -q "WARN: engine/review/config.json not in protected_paths"; then ok "S3 WARN rule gap"; else bad "S3 should WARN (rc=$rc): $result"; fi

echo ""
echo "=========================================="
echo "T-070 doctor review config: $PASS pass, $FAIL fail"
[ "$FAIL" -eq 0 ] || exit 1
