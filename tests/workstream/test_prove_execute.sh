#!/usr/bin/env bash
# Test: engine prove --execute (T-074, v6.23.0)
#
# Scenarios:
#   S1: all assertions pass → exit 0, PROVE.json status=PASS
#   S2: one assertion fails → exit 1, PROVE.json status=FAIL
#   S3: blocked command → exit 1, E_SAFETY
#   S4: tautology command → exit 1, E_SAFETY
#   S5: stale fingerprint → exit 1, E_STALE
#   S6: missing assertions file → exit 1
#   S7: schema violation (missing rationale) → exit 1, E_SCHEMA

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
  if echo "$haystack" | grep -qi "$needle"; then
    PASS=$((PASS+1)); echo "  PASS: $desc"
  else
    FAIL=$((FAIL+1)); echo "  FAIL: $desc ('$needle' not found)"
  fi
}
assert_file_exists() {
  local desc="$1" path="$2"
  if [ -f "$path" ]; then
    PASS=$((PASS+1)); echo "  PASS: $desc"
  else
    FAIL=$((FAIL+1)); echo "  FAIL: $desc (file not found: $path)"
  fi
}

echo "=== test_prove_execute.sh ==="

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_REPO="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROVE_SH="$ROOT_REPO/engine/scripts/engine-prove.sh"

PY=python3
command -v python3 >/dev/null 2>&1 || PY=python

TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# Setup a repo with a code change and run --infer to get fingerprint
setup_execute_env() {
  local dir="$1"
  mkdir -p "$dir/engine/scripts" "$dir/engine/prove" "$dir/engine/evidence/T-001" "$dir/src" "$dir/engine/tasks"
  cd "$dir"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"
  echo '{"defaults":{"assertion_timeout_s":30,"max_assertions":10,"output_truncate_chars":500,"blocked_commands":["rm","mv","curl","wget","sudo","dd","mkfs","chmod","chown","kill","shutdown","reboot","format"],"code_extensions":[".sh",".py",".js"]},"overrides":{}}' > engine/prove/config.json
  cp "$PROVE_SH" engine/scripts/engine-prove.sh

  cat > engine/tasks/T-001.md << 'EOF'
# T-001: Test
status: active
## GOAL
Test prove execute
## WRITE-SET
- src/app.sh
EOF
  echo '#!/usr/bin/env bash' > src/app.sh
  echo 'echo "v1"' >> src/app.sh
  git add -A && git commit -qm "init"

  # Modify code
  echo 'echo "v2"' >> src/app.sh
  git add -A && git commit -qm "change"

  # Run infer to get fingerprint
  CLAUDE_PROJECT_DIR="$dir" bash engine/scripts/engine-prove.sh T-001 --infer >/dev/null 2>&1

  # Extract fingerprint from package
  grep 'code_fingerprint:' engine/evidence/T-001/prove-package.md | head -1 | sed 's/.*code_fingerprint: //'
}

make_assertions() {
  local dir="$1" fp="$2"
  shift 2
  # remaining args are JSON assertion objects
  local assertions=""
  for a in "$@"; do
    assertions="$assertions$a,"
  done
  assertions="${assertions%,}"

  cat > "$dir/engine/evidence/T-001/prove-assertions.json" << JSONEOF
{
  "task_id": "T-001",
  "code_fingerprint": "$fp",
  "assertions": [$assertions]
}
JSONEOF
}

# --- S1: all pass ---
echo ""
echo "--- S1: all assertions pass → exit 0, PROVE.json PASS ---"
S1="$TMPDIR_TEST/s1"
FP1=$(setup_execute_env "$S1")
make_assertions "$S1" "$FP1" \
  '{"id":"A-01","category":"syntax","command":"bash -n src/app.sh","expect_exit":0,"timeout_s":10,"rationale":"Verify app.sh has no syntax errors after modification","revert_would_fail":false}' \
  '{"id":"A-02","category":"invariant","command":"bash -c \"source src/app.sh 2>/dev/null; true\"","expect_exit":0,"timeout_s":10,"rationale":"Verify app.sh can be sourced without crashing the shell","revert_would_fail":true}'

OUT1=$(CLAUDE_PROJECT_DIR="$S1" bash engine/scripts/engine-prove.sh T-001 --execute 2>&1); RC1=$?
assert_exit "S1 execute exits 0" 0 $RC1
assert_file_exists "S1 PROVE.json exists" "$S1/engine/evidence/T-001/PROVE.json"
PROVE1=$(cat "$S1/engine/evidence/T-001/PROVE.json" 2>/dev/null || echo "")
assert_contains "S1 status PASS" "$PROVE1" '"status": "PASS"'

# --- S2: one fails ---
echo ""
echo "--- S2: assertion expects wrong exit code → FAIL ---"
S2="$TMPDIR_TEST/s2"
FP2=$(setup_execute_env "$S2")
make_assertions "$S2" "$FP2" \
  '{"id":"A-01","category":"syntax","command":"bash -n src/app.sh","expect_exit":0,"timeout_s":10,"rationale":"Verify app.sh syntax is valid after the change","revert_would_fail":false}' \
  '{"id":"A-02","category":"invariant","command":"grep -q nonexistent_pattern_xyz src/app.sh","expect_exit":0,"timeout_s":10,"rationale":"This assertion deliberately fails because the pattern does not exist in app.sh","revert_would_fail":true}'

OUT2=$(CLAUDE_PROJECT_DIR="$S2" bash engine/scripts/engine-prove.sh T-001 --execute 2>&1); RC2=$?
assert_exit "S2 execute exits 1" 1 $RC2
PROVE2=$(cat "$S2/engine/evidence/T-001/PROVE.json" 2>/dev/null || echo "")
assert_contains "S2 status FAIL" "$PROVE2" '"status": "FAIL"'

# --- S3: blocked command ---
echo ""
echo "--- S3: command contains rm → E_SAFETY ---"
S3="$TMPDIR_TEST/s3"
FP3=$(setup_execute_env "$S3")
make_assertions "$S3" "$FP3" \
  '{"id":"A-01","category":"invariant","command":"rm -rf src/app.sh","expect_exit":0,"timeout_s":10,"rationale":"This should be blocked by safety validation","revert_would_fail":true}'

OUT3=$(CLAUDE_PROJECT_DIR="$S3" bash engine/scripts/engine-prove.sh T-001 --execute 2>&1); RC3=$?
assert_exit "S3 execute exits 1" 1 $RC3
assert_contains "S3 E_SAFETY" "$OUT3" "E_SAFETY\|blocked"

# --- S4: tautology ---
echo ""
echo "--- S4: command is 'true' → E_SAFETY tautology ---"
S4="$TMPDIR_TEST/s4"
FP4=$(setup_execute_env "$S4")
make_assertions "$S4" "$FP4" \
  '{"id":"A-01","category":"invariant","command":"true","expect_exit":0,"timeout_s":10,"rationale":"This is a tautological command that always passes","revert_would_fail":true}'

OUT4=$(CLAUDE_PROJECT_DIR="$S4" bash engine/scripts/engine-prove.sh T-001 --execute 2>&1); RC4=$?
assert_exit "S4 execute exits 1" 1 $RC4
assert_contains "S4 tautology detected" "$OUT4" "tautolog\|E_SAFETY"

# --- S5: stale fingerprint ---
echo ""
echo "--- S5: fingerprint mismatch → E_STALE ---"
S5="$TMPDIR_TEST/s5"
FP5=$(setup_execute_env "$S5")
# Use a wrong fingerprint
make_assertions "$S5" "sha256:0000000000000000000000000000000000000000000000000000000000000000" \
  '{"id":"A-01","category":"syntax","command":"bash -n src/app.sh","expect_exit":0,"timeout_s":10,"rationale":"Verify app.sh syntax is valid after the change","revert_would_fail":false}'

OUT5=$(CLAUDE_PROJECT_DIR="$S5" bash engine/scripts/engine-prove.sh T-001 --execute 2>&1); RC5=$?
assert_exit "S5 execute exits 1" 1 $RC5
assert_contains "S5 E_STALE" "$OUT5" "E_STALE\|stale\|Re-run"

# --- S6: missing assertions file ---
echo ""
echo "--- S6: no prove-assertions.json → exit 1 ---"
S6="$TMPDIR_TEST/s6"
FP6=$(setup_execute_env "$S6")
rm -f "$S6/engine/evidence/T-001/prove-assertions.json"

OUT6=$(CLAUDE_PROJECT_DIR="$S6" bash engine/scripts/engine-prove.sh T-001 --execute 2>&1); RC6=$?
assert_exit "S6 execute exits 1" 1 $RC6
assert_contains "S6 mentions missing" "$OUT6" "not found\|--infer"

# --- S7: schema violation ---
echo ""
echo "--- S7: missing rationale → E_SCHEMA ---"
S7="$TMPDIR_TEST/s7"
FP7=$(setup_execute_env "$S7")
cat > "$S7/engine/evidence/T-001/prove-assertions.json" << JSONEOF
{
  "task_id": "T-001",
  "code_fingerprint": "$FP7",
  "assertions": [{"id":"A-01","category":"syntax","command":"bash -n src/app.sh","expect_exit":0}]
}
JSONEOF

OUT7=$(CLAUDE_PROJECT_DIR="$S7" bash engine/scripts/engine-prove.sh T-001 --execute 2>&1); RC7=$?
assert_exit "S7 execute exits 1" 1 $RC7
assert_contains "S7 E_SCHEMA" "$OUT7" "E_SCHEMA\|rationale"

# --- S8: lock file blocks concurrent execution ---
echo ""
echo "--- S8: existing lock file → exit 1 ---"
S8="$TMPDIR_TEST/s8"
FP8=$(setup_execute_env "$S8")
make_assertions "$S8" "$FP8" \
  '{"id":"A-01","category":"syntax","command":"bash -n src/app.sh","expect_exit":0,"timeout_s":10,"rationale":"Verify app.sh syntax is valid after the change","revert_would_fail":false}'
# Create a lock file with our own PID (which is alive)
echo "$$" > "$S8/engine/evidence/T-001/.prove-lock"

OUT8=$(CLAUDE_PROJECT_DIR="$S8" bash engine/scripts/engine-prove.sh T-001 --execute 2>&1); RC8=$?
assert_exit "S8 execute exits 1 (locked)" 1 $RC8
assert_contains "S8 mentions lock" "$OUT8" "another execute\|lock"

# --- S9: all-syntax → WARN ---
echo ""
echo "--- S9: all assertions syntax-only → WARN message ---"
S9="$TMPDIR_TEST/s9"
FP9=$(setup_execute_env "$S9")
make_assertions "$S9" "$FP9" \
  '{"id":"A-01","category":"syntax","command":"bash -n src/app.sh","expect_exit":0,"timeout_s":10,"rationale":"Verify app.sh syntax is valid after the change","revert_would_fail":false}'

OUT9=$(CLAUDE_PROJECT_DIR="$S9" bash engine/scripts/engine-prove.sh T-001 --execute 2>&1); RC9=$?
assert_exit "S9 execute exits 0" 0 $RC9
assert_contains "S9 syntax-only WARN" "$OUT9" "syntax-only\|WARN"

# --- S10: expanded tautology (bash -c "true") ---
echo ""
echo "--- S10: bash -c true → E_SAFETY tautology ---"
S10="$TMPDIR_TEST/s10"
FP10=$(setup_execute_env "$S10")
make_assertions "$S10" "$FP10" \
  '{"id":"A-01","category":"invariant","command":"bash -c \"true\"","expect_exit":0,"timeout_s":10,"rationale":"This is a disguised tautology using bash -c wrapper","revert_would_fail":true}'

OUT10=$(CLAUDE_PROJECT_DIR="$S10" bash engine/scripts/engine-prove.sh T-001 --execute 2>&1); RC10=$?
assert_exit "S10 execute exits 1" 1 $RC10
assert_contains "S10 tautology detected" "$OUT10" "tautolog\|E_SAFETY"

# --- S11: WRITE-SET relevance (command references WRITE-SET file not in diff) ---
echo ""
echo "--- S11: command references WRITE-SET file → passes relevance ---"
S11="$TMPDIR_TEST/s11"
FP11=$(setup_execute_env "$S11")
make_assertions "$S11" "$FP11" \
  '{"id":"A-01","category":"regression","command":"grep -q v2 src/app.sh","expect_exit":0,"timeout_s":10,"rationale":"Verify the v2 change is present in app.sh after modification","revert_would_fail":false}'

OUT11=$(CLAUDE_PROJECT_DIR="$S11" bash engine/scripts/engine-prove.sh T-001 --execute 2>&1); RC11=$?
assert_exit "S11 execute exits 0" 0 $RC11
assert_contains "S11 status PASS" "$(cat "$S11/engine/evidence/T-001/PROVE.json" 2>/dev/null)" '"status": "PASS"'

# --- Summary ---
echo ""
echo "=== RESULTS: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
