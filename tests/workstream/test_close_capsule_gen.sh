#!/usr/bin/env bash
# Test: O4 generate_capsule() in engine-close.sh
# Verifies conventional commit parsing and CHANGE capsule auto-generation.
set -u -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REAL_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REAL_ENGINE_DIR="$REAL_ROOT/engine"
PASS_COUNT=0
FAIL_COUNT=0

assert_contains() {
  local desc="$1" haystack="$2" needle="$3"
  if printf '%s' "$haystack" | grep -qF "$needle"; then
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "FAIL: $desc — expected to find '$needle'"
  fi
}

assert_file_exists() {
  local desc="$1" path="$2"
  if [ -f "$path" ]; then
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "FAIL: $desc — file not found: $path"
  fi
}

# --- Setup: temp git repo with conventional commits ---
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

cd "$TMPDIR_TEST"
git init -q
git config user.email "test@test.com"
git config user.name "Test"

mkdir -p engine/scripts engine/tasks engine/changes engine/evidence/T-099 engine/domains

# Minimal ENGINE_MAP
cat > engine/ENGINE_MAP.md <<'EOF'
# ENGINE_MAP
## §1 File Registry
| Path | Role |
|------|------|
| engine/ENGINE_MAP.md | registry |
EOF

# Task card with code in WRITE-SET
cat > engine/tasks/T-099.md <<'EOF'
# T-099: Test capsule generation
status: active
## GOAL
Test capsule auto-gen
## WRITE-SET
- engine/scripts/test-feature.sh
## FORBIDDEN
- engine/gate/**
## AC
AC: AC-1 capsule generated | verify: test -f engine/changes/CHANGE-T-099.md
EOF

# Create a code file in WRITE-SET
echo '#!/bin/bash' > engine/scripts/test-feature.sh
echo 'echo hello' >> engine/scripts/test-feature.sh

# CONTEXT and HANDOFF referencing T-099
echo "# CONTEXT" > engine/CONTEXT.md
echo "T-099 active" >> engine/CONTEXT.md
echo "# HANDOFF" > engine/HANDOFF.md
echo "| T-099 | test |" >> engine/HANDOFF.md

git add -A
git commit -q -m "feat(engine): add test feature for T-099"

# More conventional commits
echo 'echo v2' >> engine/scripts/test-feature.sh
git add -A
git commit -q -m "fix(engine): correct output format"

echo '# docs' > engine/README.md
git add -A
git commit -q -m "docs: add readme"

echo 'test' > engine/scripts/test-feature_test.sh
git add -A
git commit -q -m "test(T-099): add unit test"

# --- Extract generate_capsule from the REAL engine-close.sh ---
ROOT="$TMPDIR_TEST"
ENGINE_DIR="$TMPDIR_TEST/engine"
timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
head_commit="$(git rev-parse HEAD)"
task="T-099"

# Extract the function definition from the real script
eval "$(sed -n '/^generate_capsule()/,/^}/p' "$REAL_ENGINE_DIR/scripts/engine-close.sh")"

# Run it
generate_capsule "T-099"
gen_rc=$?

# S1: function succeeds
if [ "$gen_rc" -eq 0 ]; then
  PASS_COUNT=$((PASS_COUNT + 1))
else
  FAIL_COUNT=$((FAIL_COUNT + 1))
  echo "FAIL: generate_capsule returned non-zero: $gen_rc"
fi

# S2: capsule file exists
assert_file_exists "capsule file created" "$TMPDIR_TEST/engine/changes/CHANGE-T-099.md"

capsule_content=""
[ -f "$TMPDIR_TEST/engine/changes/CHANGE-T-099.md" ] && capsule_content="$(cat "$TMPDIR_TEST/engine/changes/CHANGE-T-099.md")"

# S3: has Features section (from feat commit)
assert_contains "has Features section" "$capsule_content" "## Features"
# S4: has Bug Fixes section (from fix commit)
assert_contains "has Bug Fixes section" "$capsule_content" "## Bug Fixes"
# S5: has Documentation section (from docs commit)
assert_contains "has Documentation section" "$capsule_content" "## Documentation"
# S6: has Tests section (from test commit)
assert_contains "has Tests section" "$capsule_content" "## Tests"
# S7: scope rendered
assert_contains "scope rendered" "$capsule_content" "**engine**"
# S8: provenance line
assert_contains "provenance" "$capsule_content" "writer: engine-close/generate_capsule"

echo ""
echo "=== test_close_capsule_gen: $PASS_COUNT passed, $FAIL_COUNT failed ==="
[ "$FAIL_COUNT" -eq 0 ] && exit 0 || exit 1
