#!/usr/bin/env bash
# Test: dynamic challenge generation (T-073, v6.22.0)
#
# Validates that engine-review-agent-package.sh generates diff-aware
# adversarial challenges instead of static ones.
#
# Scenarios:
#   S1: diff with new branch (if without else) → challenge mentions branch/fallback
#   S2: diff with large hunk (>20 lines) → challenge mentions split/rollback
#   S3: trivial change (no signals) → fallback static challenges (3 questions)
#   S4: packaged_by header present in output package

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
assert_not_contains() {
  local desc="$1" haystack="$2" needle="$3"
  if echo "$haystack" | grep -qi "$needle"; then
    FAIL=$((FAIL+1)); echo "  FAIL: $desc ('$needle' should not be present)"
  else
    PASS=$((PASS+1)); echo "  PASS: $desc"
  fi
}

echo "=== test_review_agent_dynamic.sh ==="

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_REPO="$(cd "$SCRIPT_DIR/../.." && pwd)"
PACKAGE_SH="$ROOT_REPO/engine/scripts/engine-review-agent-package.sh"

TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# python detection
PY=python3
command -v python3 >/dev/null 2>&1 || PY=python

setup_repo() {
  local dir="$1"
  mkdir -p "$dir/engine/tasks" "$dir/engine/review"
  cd "$dir"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"
  # config with agent_review enabled
  cat > engine/review/config.json << 'EOF'
{"defaults":{"agent_review":{"enabled":true,"max_package_lines":2000,"max_surrounding_context_lines":500,"max_domain_knowledge_lines":150},"code_extensions":[".sh",".py",".js"]},"overrides":{}}
EOF
  git add -A && git commit -qm "init"
}

# --- S1: branch signal ---
echo ""
echo "--- S1: new branch without else → dynamic challenge ---"
S1="$TMPDIR_TEST/s1"
setup_repo "$S1"
cat > engine/tasks/T-001.md << 'EOF'
# T-001
GOAL: test branch signal
## WRITE-SET
- src/logic.sh
## FORBIDDEN
## AC:
AC: test passes
EOF
mkdir -p src
cat > src/logic.sh << 'SCRIPT'
#!/bin/bash
echo "hello"
SCRIPT
git add -A && git commit -qm "add task + base"
# Add branch without else
cat > src/logic.sh << 'SCRIPT'
#!/bin/bash
if [ "$1" = "danger" ]; then
  rm -rf /tmp/something
  echo "did dangerous thing"
fi
echo "done"
SCRIPT
git add -A && git commit -qm "add branch"
OUT1=$(CLAUDE_PROJECT_DIR="$S1" bash "$PACKAGE_SH" T-001 2>&1); RC1=$?
assert_exit "S1 package exits 0" 0 $RC1
PKG1=$(cat "$S1/engine/review/evidence/T-001/review-package.md" 2>/dev/null || echo "")
assert_contains "S1 challenge mentions branch/condition" "$PKG1" "branch\|condition\|else\|fallback"

# --- S2: large hunk signal ---
echo ""
echo "--- S2: large hunk (>20 lines) → dynamic challenge ---"
S2="$TMPDIR_TEST/s2"
setup_repo "$S2"
cat > engine/tasks/T-002.md << 'EOF'
# T-002
GOAL: test large hunk
## WRITE-SET
- src/big.py
## FORBIDDEN
## AC:
AC: test passes
EOF
mkdir -p src
echo "# base" > src/big.py
git add -A && git commit -qm "add task + base"
# Generate 30+ line change
python3 -c "
lines = ['# big module v2']
for i in range(35):
    lines.append(f'def func_{i}(x):')
    lines.append(f'    return x + {i}')
print('\n'.join(lines))
" > src/big.py 2>/dev/null || python -c "
lines = ['# big module v2']
for i in range(35):
    lines.append(f'def func_{i}(x):')
    lines.append(f'    return x + {i}')
print('\n'.join(lines))
" > src/big.py
git add -A && git commit -qm "big change"
OUT2=$(CLAUDE_PROJECT_DIR="$S2" bash "$PACKAGE_SH" T-002 2>&1); RC2=$?
assert_exit "S2 package exits 0" 0 $RC2
PKG2=$(cat "$S2/engine/review/evidence/T-002/review-package.md" 2>/dev/null || echo "")
assert_contains "S2 challenge mentions hunk/split/lines" "$PKG2" "hunk\|split\|changed lines\|logical change"

# --- S3: trivial change → fallback static ---
echo ""
echo "--- S3: trivial change → static fallback challenges ---"
S3="$TMPDIR_TEST/s3"
setup_repo "$S3"
cat > engine/tasks/T-003.md << 'EOF'
# T-003
GOAL: test fallback
## WRITE-SET
- src/tiny.sh
## FORBIDDEN
## AC:
AC: test passes
EOF
mkdir -p src
echo '#!/bin/bash' > src/tiny.sh
git add -A && git commit -qm "add task + base"
echo '#!/bin/bash' > src/tiny.sh
echo 'echo ok' >> src/tiny.sh
git add -A && git commit -qm "tiny change"
OUT3=$(CLAUDE_PROJECT_DIR="$S3" bash "$PACKAGE_SH" T-003 2>&1); RC3=$?
assert_exit "S3 package exits 0" 0 $RC3
PKG3=$(cat "$S3/engine/review/evidence/T-003/review-package.md" 2>/dev/null || echo "")
# Should have 3 numbered challenges regardless
assert_contains "S3 has challenge 1" "$PKG3" "^1\."
assert_contains "S3 has challenge 3" "$PKG3" "^3\."

# --- S4: packaged_by header present ---
echo ""
echo "--- S4: packaged_by header in package ---"
assert_contains "S4 packaged_by header exists" "$PKG1" "packaged_by:"
assert_contains "S4 reviewer_session in schema" "$PKG1" "reviewer_session"

# --- Summary ---
echo ""
echo "=== RESULTS: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
