#!/usr/bin/env bash
# Test: Doctor check_agent_review_evidence (T-072, v6.21.0)
#
# Scenarios:
#   S1: agent_review enabled + done card missing evidence → FAIL
#   S2: agent_review enabled + status=block → FAIL
#   S3: agent_review enabled + status=concerns → WARN
#   S4: agent_review enabled + status=pass → PASS (no output)
#   S5: agent_review disabled → skip (no FAIL/WARN)
#   S6: L2 override (config disabled but card has REVIEW-OVERRIDE) → FAIL if missing

set -u
PASS=0; FAIL=0
assert_exit() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$actual" -eq "$expected" ]; then
    PASS=$((PASS+1)); echo "  PASS: $desc (exit $actual)"
  else
    FAIL=$((FAIL+1)); echo "  FAIL: $desc (expected exit $expected, got $actual)"
  fi
}
assert_output_contains() {
  local desc="$1" output="$2" needle="$3"
  if echo "$output" | grep -q "$needle"; then
    PASS=$((PASS+1)); echo "  PASS: $desc"
  else
    FAIL=$((FAIL+1)); echo "  FAIL: $desc ('$needle' not in output)"
  fi
}
assert_output_not_contains() {
  local desc="$1" output="$2" needle="$3"
  if echo "$output" | grep -q "$needle"; then
    FAIL=$((FAIL+1)); echo "  FAIL: $desc ('$needle' found in output)"
  else
    PASS=$((PASS+1)); echo "  PASS: $desc"
  fi
}

echo "=== test_doctor_agent_review.sh ==="

ROOT_REPO="$(cd "$(dirname "$0")/../.." && pwd)"
TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# python detection
PY=python3
command -v python3 >/dev/null 2>&1 || PY=python

# --- Extracted doctor logic (mirrors check_agent_review_evidence) ---
# Args: $1=tasks_dir $2=config_file $3=evidence_base_dir
# Outputs FAIL/WARN/PASS lines
doctor_agent_review_check() {
  local tasks_dir="$1" config_file="$2" evidence_base="$3"

  local ar_enabled=false
  if [ -f "$config_file" ]; then
    ar_enabled="$(CONFIG_FILE="$config_file" "$PY" -c "
import json, os
try:
    with open(os.environ['CONFIG_FILE']) as f: cfg = json.load(f)
except: cfg = {}
ar = cfg.get('defaults',{}).get('agent_review',{})
ar_ov = cfg.get('overrides',{}).get('agent_review',{})
if isinstance(ar_ov, dict): ar = {**ar, **ar_ov}
print('true' if ar.get('enabled', False) else 'false')
" 2>/dev/null || echo "false")"
  fi

  for f in "$tasks_dir"/T-*.md; do
    [ -f "$f" ] || continue
    # check status: done
    grep -Eq '^[[:space:]]*(>[[:space:]]*)?status:[[:space:]]*done' "$f" || continue
    local tid; tid="$(basename "$f" .md)"

    local needs_agent_review=false
    if [ "$ar_enabled" = "true" ]; then
      needs_agent_review=true
    else
      if awk '/^## REVIEW-OVERRIDE/{f=1;next} /^## /{f=0} f' "$f" 2>/dev/null | grep -q 'add_dimensions:.*agent_review'; then
        needs_agent_review=true
      fi
    fi
    [ "$needs_agent_review" = true ] || continue

    local agent_review_file="$evidence_base/$tid/AGENT-REVIEW.json"

    if [ ! -f "$agent_review_file" ]; then
      echo "FAIL newly-done task $tid missing agent review evidence"
      continue
    fi

    local agent_status
    agent_status="$(grep -oE '"status":"[^"]*"' "$agent_review_file" | head -1 | sed 's/"status":"//;s/"//')"
    case "$agent_status" in
      block) echo "FAIL $tid done task has agent review block status" ;;
      concerns) echo "WARN $tid agent review has concerns" ;;
      pass) echo "PASS $tid agent review pass" ;;
      *) echo "WARN $tid agent review unknown status: $agent_status" ;;
    esac
  done
}

# --- Setup ---
cd "$TMPDIR_TEST"
mkdir -p engine/tasks engine/review/evidence

# Config with agent_review enabled
cat > engine/review/config-enabled.json << 'EOF'
{
  "defaults": {
    "agent_review": {
      "enabled": true,
      "min_entries_per_dimension": 1,
      "min_narrative_chars": 200
    }
  },
  "overrides": {}
}
EOF

# Config with agent_review disabled
cat > engine/review/config-disabled.json << 'EOF'
{
  "defaults": {
    "agent_review": {
      "enabled": false
    }
  },
  "overrides": {}
}
EOF

# --- S1: enabled + done card missing evidence → FAIL ---
echo ""
echo "--- S1: enabled + done missing evidence → FAIL ---"
cat > engine/tasks/T-091.md << 'EOF'
# T-091: Test done
> status: done
GOAL: Test
EOF
out=$(doctor_agent_review_check "engine/tasks" "engine/review/config-enabled.json" "engine/review/evidence" 2>&1)
assert_output_contains "S1: FAIL for missing evidence" "$out" "FAIL"
assert_output_contains "S1: mentions T-091" "$out" "T-091"

# --- S2: enabled + status=block → FAIL ---
echo ""
echo "--- S2: enabled + status=block → FAIL ---"
mkdir -p engine/review/evidence/T-091
cat > engine/review/evidence/T-091/AGENT-REVIEW.json << 'EOF'
{"task":"T-091","status":"block","write_provenance":{"writer":"agent-reviewer"}}
EOF
out=$(doctor_agent_review_check "engine/tasks" "engine/review/config-enabled.json" "engine/review/evidence" 2>&1)
assert_output_contains "S2: FAIL for block" "$out" "FAIL"
assert_output_contains "S2: mentions block" "$out" "block"

# --- S3: enabled + status=concerns → WARN ---
echo ""
echo "--- S3: enabled + status=concerns → WARN ---"
cat > engine/review/evidence/T-091/AGENT-REVIEW.json << 'EOF'
{"task":"T-091","status":"concerns","write_provenance":{"writer":"agent-reviewer"}}
EOF
out=$(doctor_agent_review_check "engine/tasks" "engine/review/config-enabled.json" "engine/review/evidence" 2>&1)
assert_output_contains "S3: WARN for concerns" "$out" "WARN"
assert_output_not_contains "S3: no FAIL" "$out" "FAIL"

# --- S4: enabled + status=pass → PASS ---
echo ""
echo "--- S4: enabled + status=pass → PASS ---"
cat > engine/review/evidence/T-091/AGENT-REVIEW.json << 'EOF'
{"task":"T-091","status":"pass","write_provenance":{"writer":"agent-reviewer"}}
EOF
out=$(doctor_agent_review_check "engine/tasks" "engine/review/config-enabled.json" "engine/review/evidence" 2>&1)
assert_output_contains "S4: PASS" "$out" "PASS"
assert_output_not_contains "S4: no FAIL" "$out" "FAIL"
assert_output_not_contains "S4: no WARN" "$out" "WARN"

# --- S5: disabled → skip ---
echo ""
echo "--- S5: disabled → skip ---"
rm -f engine/review/evidence/T-091/AGENT-REVIEW.json
out=$(doctor_agent_review_check "engine/tasks" "engine/review/config-disabled.json" "engine/review/evidence" 2>&1)
assert_output_not_contains "S5: no FAIL when disabled" "$out" "FAIL"
assert_output_not_contains "S5: no WARN when disabled" "$out" "WARN"

# --- S6: L2 override (config disabled but card has REVIEW-OVERRIDE) ---
echo ""
echo "--- S6: L2 override triggers check ---"
cat > engine/tasks/T-092.md << 'EOF'
# T-092: L2 override test
> status: done
GOAL: Test L2

## REVIEW-OVERRIDE
- add_dimensions: agent_review
EOF
out=$(doctor_agent_review_check "engine/tasks" "engine/review/config-disabled.json" "engine/review/evidence" 2>&1)
assert_output_contains "S6: FAIL for T-092 missing evidence via L2" "$out" "T-092"
assert_output_contains "S6: FAIL present" "$out" "FAIL"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
