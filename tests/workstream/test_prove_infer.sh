#!/usr/bin/env bash
# Test: engine prove --infer (T-074, v6.23.0)
#
# Scenarios:
#   S1: basic single-file change → prove-package.md with diff/symbols/fingerprint
#   S2: no code files changed → NO-OP package
#   S3: multi-file change → all files in package

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

echo "=== test_prove_infer.sh ==="

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_REPO="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROVE_SH="$ROOT_REPO/engine/scripts/engine-prove.sh"

TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

setup_repo() {
  local dir="$1"
  mkdir -p "$dir/engine/scripts" "$dir/engine/prove" "$dir/engine/evidence" "$dir/engine/tasks" "$dir/src"
  cd "$dir"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"
  # Minimal config
  echo '{"defaults":{"assertion_timeout_s":30,"max_assertions":10,"code_extensions":[".sh",".py",".js"]},"overrides":{}}' > engine/prove/config.json
  # Copy prove script
  cp "$PROVE_SH" engine/scripts/engine-prove.sh
  git add -A && git commit -qm "init"
}

# --- S1: basic single-file change ---
echo ""
echo "--- S1: single .sh file modified → package with diff/symbols/fingerprint ---"
S1="$TMPDIR_TEST/s1"
setup_repo "$S1"

# Create task card
cat > engine/tasks/T-001.md << 'EOF'
# T-001: Test task
status: active
## GOAL
Test the prove system
## WRITE-SET
- src/hello.sh
EOF
git add -A && git commit -qm "task card"

# Make a code change
cat > src/hello.sh << 'SCRIPT'
#!/usr/bin/env bash
greet() {
  local name="$1"
  if [ -z "$name" ]; then
    echo "Hello, World!"
  else
    echo "Hello, $name!"
  fi
}
greet "$@"
SCRIPT
git add -A && git commit -qm "add hello.sh"

OUT1=$(CLAUDE_PROJECT_DIR="$S1" bash engine/scripts/engine-prove.sh T-001 --infer 2>&1); RC1=$?
assert_exit "S1 infer exits 0" 0 $RC1
assert_file_exists "S1 prove-package.md exists" "$S1/engine/evidence/T-001/prove-package.md"

PKG1=$(cat "$S1/engine/evidence/T-001/prove-package.md" 2>/dev/null || echo "")
assert_contains "S1 has code_fingerprint" "$PKG1" "code_fingerprint: sha256:"
assert_contains "S1 has diff content" "$PKG1" "greet"
assert_contains "S1 has hunk symbols" "$PKG1" "Hunk Symbols"
assert_contains "S1 has syntax checks" "$PKG1" "bash -n"
assert_contains "S1 has anti-tautology rules" "$PKG1" "Anti-Tautology"
assert_contains "S1 has output schema" "$PKG1" "prove-assertions.json"

# --- S2: no code files → NO-OP ---
echo ""
echo "--- S2: only .md changed → NO-OP package ---"
S2="$TMPDIR_TEST/s2"
setup_repo "$S2"

cat > engine/tasks/T-002.md << 'EOF'
# T-002: Docs only
status: active
## GOAL
Update documentation
## WRITE-SET
- README.md
EOF
git add -A && git commit -qm "task card"
echo "# Hello" > README.md
git add -A && git commit -qm "docs"

OUT2=$(CLAUDE_PROJECT_DIR="$S2" bash engine/scripts/engine-prove.sh T-002 --infer 2>&1); RC2=$?
assert_exit "S2 infer exits 0" 0 $RC2
PKG2=$(cat "$S2/engine/evidence/T-002/prove-package.md" 2>/dev/null || echo "")
assert_contains "S2 marked NO-OP" "$PKG2" "NO-OP"

# --- S3: multi-file change ---
echo ""
echo "--- S3: multiple code files → all in package ---"
S3="$TMPDIR_TEST/s3"
setup_repo "$S3"

cat > engine/tasks/T-003.md << 'EOF'
# T-003: Multi-file
status: active
## GOAL
Add utility functions
## WRITE-SET
- src/util.sh
- src/helper.py
EOF
git add -A && git commit -qm "task card"

echo 'util_func() { echo "util"; }' > src/util.sh
echo 'def helper(): return 42' > src/helper.py
git add -A && git commit -qm "code"

OUT3=$(CLAUDE_PROJECT_DIR="$S3" bash engine/scripts/engine-prove.sh T-003 --infer 2>&1); RC3=$?
assert_exit "S3 infer exits 0" 0 $RC3
PKG3=$(cat "$S3/engine/evidence/T-003/prove-package.md" 2>/dev/null || echo "")
assert_contains "S3 has util.sh" "$PKG3" "util.sh"
assert_contains "S3 has helper.py" "$PKG3" "helper.py"
assert_contains "S3 has python syntax check" "$PKG3" "py_compile"

# --- S4: WRITE-SET file not in diff → still in fingerprint ---
echo ""
echo "--- S4: WRITE-SET includes extra file → fingerprint covers it ---"
S4="$TMPDIR_TEST/s4"
setup_repo "$S4"

cat > engine/tasks/T-004.md << 'EOF'
# T-004: WRITE-SET broader than diff
status: active
## GOAL
Test fingerprint coverage
## WRITE-SET
- src/main.sh
- src/config.json
EOF
git add -A && git commit -qm "task card"

# Only modify main.sh; config.json exists but is unchanged (pre-committed)
echo '{"key":"value"}' > src/config.json
git add -A && git commit -qm "config"
echo '#!/usr/bin/env bash' > src/main.sh
echo 'echo "main"' >> src/main.sh
git add -A && git commit -qm "main"

OUT4=$(CLAUDE_PROJECT_DIR="$S4" bash engine/scripts/engine-prove.sh T-004 --infer 2>&1); RC4=$?
assert_exit "S4 infer exits 0" 0 $RC4
PKG4=$(cat "$S4/engine/evidence/T-004/prove-package.md" 2>/dev/null || echo "")
assert_contains "S4 has fingerprint" "$PKG4" "code_fingerprint: sha256:"
assert_contains "S4 has main.sh in diff" "$PKG4" "main.sh"
# config.json is in WRITE-SET so fingerprint includes it (different from diff-only)
assert_contains "S4 WRITE-SET listed" "$PKG4" "config.json"

# --- S5: task card not found → exit 1 ---
echo ""
echo "--- S5: missing task card → exit 1 ---"
S5="$TMPDIR_TEST/s5"
setup_repo "$S5"

OUT5=$(CLAUDE_PROJECT_DIR="$S5" bash engine/scripts/engine-prove.sh T-999 --infer 2>&1); RC5=$?
assert_exit "S5 infer exits 1" 1 $RC5
assert_contains "S5 error message" "$OUT5" "not found\|Error"

# --- Summary ---
echo ""
echo "=== RESULTS: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
