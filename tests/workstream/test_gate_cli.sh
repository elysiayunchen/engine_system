#!/usr/bin/env bash
# Test: engine gate CLI (T-077, v6.24.0)
#
# Validates engine/scripts/engine-gate.sh aggregation logic:
#   - Reads evidence files (AC-*.json, REVIEW.json, AGENT-REVIEW.json, PROVE.json)
#   - Writes GATE.json with overall status
#   - Exit 0 = all pass, exit 1 = block/pending, exit 2 = usage/config error
#
# Scenarios:
#   S1: All gates pass → exit 0, GATE.json status=pass
#   S2: Review block → exit 1, GATE.json status=block
#   S3: Missing evidence → exit 1, gate pending
#   S4: Docs-only card → review/prove skipped
#   S5: No task card → exit 2
#   S6: Tool unavailable (review skipped) → still pass

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
assert_contains() {
  local desc="$1" haystack="$2" needle="$3"
  if printf '%s' "$haystack" | grep -q "$needle"; then
    PASS=$((PASS+1)); echo "  PASS: $desc"
  else
    FAIL=$((FAIL+1)); echo "  FAIL: $desc ('$needle' not found)"
  fi
}
assert_not_contains() {
  local desc="$1" haystack="$2" needle="$3"
  if printf '%s' "$haystack" | grep -q "$needle"; then
    FAIL=$((FAIL+1)); echo "  FAIL: $desc ('$needle' unexpectedly found)"
  else
    PASS=$((PASS+1)); echo "  PASS: $desc"
  fi
}

echo "=== test_gate_cli.sh ==="

REAL_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GATE_SCRIPT="$REAL_ROOT/engine/scripts/engine-gate.sh"
[ -f "$GATE_SCRIPT" ] || { echo "FATAL: $GATE_SCRIPT not found"; exit 2; }

# python detection
PY=python3
command -v python3 >/dev/null 2>&1 || PY=python

TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# --- Helper: create a fresh test repo ---
new_repo() {
  local d
  d="$(mktemp -d "$TMPDIR_TEST/repo.XXXXXX")"
  git -C "$d" init -q
  git -C "$d" config user.email "test@test.com"
  git -C "$d" config user.name "Test"
  git -C "$d" config core.autocrlf false
  mkdir -p "$d/engine/tasks" "$d/engine/evidence/T-001" "$d/engine/gate" "$d/engine/review/evidence/T-001"
  # gate config (required by engine-gate.sh)
  cat > "$d/engine/gate/config.json" <<'GCEOF'
{
  "defaults": {
    "gates": ["verify", "review", "review_agent", "prove"],
    "code_extensions": [".sh", ".py", ".js", ".ts"],
    "docs_only_skip": ["review", "review_agent", "prove"],
    "agent_review": {"enabled": true}
  },
  "overrides": {}
}
GCEOF
  # review config (needed by check_review_agent)
  mkdir -p "$d/engine/review"
  cat > "$d/engine/review/config.json" <<'RCEOF'
{"defaults": {"agent_review": {"enabled": true}}}
RCEOF
  # initial commit
  echo "init" > "$d/README.md"
  git -C "$d" add -A
  git -C "$d" commit -qm "init" --no-verify
  printf '%s\n' "$d"
}

# --- Helper: write a task card with code in WRITE-SET ---
write_task_card_code() {
  local d="$1"
  cat > "$d/engine/tasks/T-001.md" <<'EOF'
# T-001
> status: active | lane: engine-runtime

## WRITE-SET
- src/main.sh

## FORBIDDEN

AC: AC-1 test gate | verify: true
EOF
}

# --- Helper: write a docs-only task card ---
write_task_card_docs() {
  local d="$1"
  cat > "$d/engine/tasks/T-001.md" <<'EOF'
# T-001
> status: active | lane: docs

## WRITE-SET
- docs/guide.md
- README.md

## FORBIDDEN

AC: AC-1 docs update | verify: true
EOF
}

# ===========================================================================
# S1: All gates pass → exit 0, GATE.json status=pass
# ===========================================================================
echo ""
echo "--- S1: All gates pass ---"
R="$(new_repo)"
write_task_card_code "$R"
# Create passing evidence
cat > "$R/engine/evidence/T-001/AC-1.json" <<'EOF'
{"ac":"AC-1","status":"pass","exit":0}
EOF
cat > "$R/engine/review/evidence/T-001/REVIEW.json" <<'EOF'
{"task":"T-001","status":"pass"}
EOF
cat > "$R/engine/review/evidence/T-001/AGENT-REVIEW.json" <<'EOF'
{"task":"T-001","status":"pass"}
EOF
cat > "$R/engine/evidence/T-001/PROVE.json" <<'EOF'
{"task":"T-001","status":"pass"}
EOF
git -C "$R" add -A && git -C "$R" commit -qm "evidence" --no-verify

out="$(cd "$R" && CLAUDE_PROJECT_DIR="$R" bash "$GATE_SCRIPT" T-001 2>&1)"
rc=$?
assert_exit "S1: all pass exit 0" 0 $rc
if [ -f "$R/engine/evidence/T-001/GATE.json" ]; then
  PASS=$((PASS+1)); echo "  PASS: S1 GATE.json exists"
else
  FAIL=$((FAIL+1)); echo "  FAIL: S1 GATE.json missing"
fi
gate_status="$("$PY" -c "
import json, sys
with open(sys.argv[1], encoding='utf-8') as f:
    d = json.load(f)
print(d.get('status',''))
" "$R/engine/evidence/T-001/GATE.json" 2>/dev/null || echo "")"
if [ "$gate_status" = "pass" ]; then
  PASS=$((PASS+1)); echo "  PASS: S1 GATE.json status=pass"
else
  FAIL=$((FAIL+1)); echo "  FAIL: S1 GATE.json status='$gate_status' (expected pass)"
fi

# ===========================================================================
# S2: Review block → exit 1, GATE.json status=block
# ===========================================================================
echo ""
echo "--- S2: Review block ---"
R="$(new_repo)"
write_task_card_code "$R"
cat > "$R/engine/evidence/T-001/AC-1.json" <<'EOF'
{"ac":"AC-1","status":"pass","exit":0}
EOF
cat > "$R/engine/review/evidence/T-001/REVIEW.json" <<'EOF'
{"task":"T-001","status":"block"}
EOF
cat > "$R/engine/review/evidence/T-001/AGENT-REVIEW.json" <<'EOF'
{"task":"T-001","status":"pass"}
EOF
cat > "$R/engine/evidence/T-001/PROVE.json" <<'EOF'
{"task":"T-001","status":"pass"}
EOF
git -C "$R" add -A && git -C "$R" commit -qm "evidence" --no-verify

out="$(cd "$R" && CLAUDE_PROJECT_DIR="$R" bash "$GATE_SCRIPT" T-001 2>&1)"
rc=$?
assert_exit "S2: review block exit 1" 1 $rc
gate_status="$("$PY" -c "
import json, sys
with open(sys.argv[1], encoding='utf-8') as f:
    d = json.load(f)
print(d.get('status',''))
" "$R/engine/evidence/T-001/GATE.json" 2>/dev/null || echo "")"
assert_contains "S2: GATE.json contains block" "$gate_status" "block"

# ===========================================================================
# S3: Missing evidence → exit 1, gate pending
# ===========================================================================
echo ""
echo "--- S3: Missing evidence ---"
R="$(new_repo)"
write_task_card_code "$R"
# No evidence files at all
git -C "$R" add -A && git -C "$R" commit -qm "setup" --no-verify

out="$(cd "$R" && CLAUDE_PROJECT_DIR="$R" bash "$GATE_SCRIPT" T-001 2>&1)"
rc=$?
assert_exit "S3: missing evidence exit 1" 1 $rc
# Output should mention pending or FAIL
if printf '%s' "$out" | grep -qiE 'pending|FAIL'; then
  PASS=$((PASS+1)); echo "  PASS: S3 output mentions pending/FAIL"
else
  FAIL=$((FAIL+1)); echo "  FAIL: S3 output does not mention pending/FAIL"
fi

# ===========================================================================
# S4: Docs-only card → review/prove skipped
# ===========================================================================
echo ""
echo "--- S4: Docs-only card ---"
R="$(new_repo)"
write_task_card_docs "$R"
cat > "$R/engine/evidence/T-001/AC-1.json" <<'EOF'
{"ac":"AC-1","status":"pass","exit":0}
EOF
git -C "$R" add -A && git -C "$R" commit -qm "evidence" --no-verify

out="$(cd "$R" && CLAUDE_PROJECT_DIR="$R" bash "$GATE_SCRIPT" T-001 2>&1)"
rc=$?
assert_exit "S4: docs-only exit 0" 0 $rc
gate_content="$(cat "$R/engine/evidence/T-001/GATE.json" 2>/dev/null || echo "")"
assert_contains "S4: GATE.json has skipped" "$gate_content" "skipped"

# ===========================================================================
# S5: No task card → exit 2
# ===========================================================================
echo ""
echo "--- S5: No task card ---"
R="$(new_repo)"
# Do NOT create T-001.md
git -C "$R" add -A && git -C "$R" commit -qm "setup" --no-verify

out="$(cd "$R" && CLAUDE_PROJECT_DIR="$R" bash "$GATE_SCRIPT" T-001 2>&1)"
rc=$?
assert_exit "S5: no task card exit 2" 2 $rc

# ===========================================================================
# S6: Tool unavailable (review skipped) → still pass
# ===========================================================================
echo ""
echo "--- S6: Review skipped (tool unavailable) ---"
R="$(new_repo)"
write_task_card_code "$R"
cat > "$R/engine/evidence/T-001/AC-1.json" <<'EOF'
{"ac":"AC-1","status":"pass","exit":0}
EOF
cat > "$R/engine/review/evidence/T-001/REVIEW.json" <<'EOF'
{"task":"T-001","status":"skipped"}
EOF
cat > "$R/engine/review/evidence/T-001/AGENT-REVIEW.json" <<'EOF'
{"task":"T-001","status":"pass"}
EOF
cat > "$R/engine/evidence/T-001/PROVE.json" <<'EOF'
{"task":"T-001","status":"pass"}
EOF
git -C "$R" add -A && git -C "$R" commit -qm "evidence" --no-verify

out="$(cd "$R" && CLAUDE_PROJECT_DIR="$R" bash "$GATE_SCRIPT" T-001 2>&1)"
rc=$?
assert_exit "S6: review skipped still pass exit 0" 0 $rc

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && echo "ALL PASS" || echo "SOME FAILURES"
exit "$FAIL"
