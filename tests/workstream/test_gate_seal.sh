#!/usr/bin/env bash
# Test: --no-verify seal mechanism (T-077, v6.24.0)
#
# Validates the bypass-detection seal in engine/scripts/githooks/pre-commit:
#   - engine/.cache/bypass-detected flag blocks all commits
#   - override_authored=true in gate config disables the seal
#   - No bypass flag → normal commit proceeds
#
# Scenarios:
#   S1: bypass-detected flag exists → commit blocked
#   S2: override_authored=true → bypass flag ignored
#   S3: No bypass flag → normal commit proceeds

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

echo "=== test_gate_seal.sh ==="

REAL_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK_SRC="$REAL_ROOT/engine/scripts/githooks/pre-commit"
[ -f "$HOOK_SRC" ] || { echo "FATAL: $HOOK_SRC not found"; exit 2; }

TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# --- Helper: create a fresh test repo with pre-commit hook installed ---
new_repo() {
  local d
  d="$(mktemp -d "$TMPDIR_TEST/repo.XXXXXX")"
  git -C "$d" init -q
  git -C "$d" config user.email "test@test.com"
  git -C "$d" config user.name "Test"
  git -C "$d" config core.autocrlf false
  git -C "$d" config commit.gpgsign false
  # Install pre-commit hook
  mkdir -p "$d/.git/hooks"
  cp "$HOOK_SRC" "$d/.git/hooks/pre-commit"
  chmod +x "$d/.git/hooks/pre-commit"
  # Engine structure
  mkdir -p "$d/engine/tasks" "$d/engine/gate" "$d/engine/.cache"
  # AGENTS.md with contract-version (enables strict_task_mode)
  cat > "$d/AGENTS.md" <<'EOF'
# AGENTS.md
contract-version: 6.24.0
EOF
  # gate config (default: override_authored=false, i.e. sealed)
  cat > "$d/engine/gate/config.json" <<'GCEOF'
{
  "defaults": {
    "gates": ["verify", "review", "review_agent", "prove"],
    "code_extensions": [".sh", ".py", ".js"],
    "docs_only_skip": ["review", "review_agent", "prove"]
  },
  "overrides": {},
  "seal": {
    "override_authored": false
  }
}
GCEOF
  # Active task card (so governing_files is non-empty, avoids no-card block)
  cat > "$d/engine/tasks/T-001.md" <<'EOF'
# T-001
> status: active | lane: engine-runtime

## WRITE-SET
- engine/tasks/**
- engine/evidence/**
- src/**

## FORBIDDEN

AC: AC-1 test | verify: true
EOF
  # Initial commit (bypass hook)
  git -C "$d" add -A
  git -C "$d" commit -qm "init" --no-verify
  printf '%s\n' "$d"
}

# --- Helper: attempt a commit, capture output ---
# Usage: try_commit "$repo" -> sets COMMIT_RC, COMMIT_ERR
try_commit() {
  local d="$1"
  COMMIT_ERR="$(cd "$d" && CLAUDE_PROJECT_DIR="$d" git -c user.email="test@test.com" -c user.name="Test" commit -m "test" 2>&1)"
  COMMIT_RC=$?
}

# ===========================================================================
# S1: bypass-detected flag exists → commit blocked
# ===========================================================================
echo ""
echo "--- S1: bypass-detected flag blocks commit ---"
R="$(new_repo)"
# Create the bypass-detected flag
echo "abc123" > "$R/engine/.cache/bypass-detected"
# Stage a trivial change (task card is bootstrap-exempt)
echo "# note" >> "$R/engine/tasks/T-001.md"
git -C "$R" add engine/tasks/T-001.md
try_commit "$R"
if [ "$COMMIT_RC" -ne 0 ]; then
  PASS=$((PASS+1)); echo "  PASS: S1 commit blocked (exit $COMMIT_RC)"
else
  FAIL=$((FAIL+1)); echo "  FAIL: S1 commit should be blocked but succeeded"
fi
assert_contains "S1: stderr mentions bypass detected" "$COMMIT_ERR" "bypass detected"

# ===========================================================================
# S2: override_authored=true → bypass flag ignored
# ===========================================================================
echo ""
echo "--- S2: override_authored=true ignores bypass flag ---"
R="$(new_repo)"
# Override gate config to allow bypass
cat > "$R/engine/gate/config.json" <<'GCEOF'
{
  "defaults": {
    "gates": ["verify", "review", "review_agent", "prove"],
    "code_extensions": [".sh", ".py", ".js"],
    "docs_only_skip": ["review", "review_agent", "prove"]
  },
  "overrides": {},
  "seal": {
    "override_authored": true
  }
}
GCEOF
# Create the bypass-detected flag (should be ignored)
echo "abc123" > "$R/engine/.cache/bypass-detected"
# Stage a trivial change (config.json is read from worktree, not index)
echo "# note" >> "$R/engine/tasks/T-001.md"
git -C "$R" add engine/tasks/T-001.md
try_commit "$R"
assert_exit "S2: commit succeeds with override_authored=true" 0 $COMMIT_RC

# ===========================================================================
# S3: No bypass flag → normal commit proceeds
# ===========================================================================
echo ""
echo "--- S3: No bypass flag, normal commit ---"
R="$(new_repo)"
# Ensure no bypass-detected file
rm -f "$R/engine/.cache/bypass-detected"
# Stage a trivial change
echo "# note" >> "$R/engine/tasks/T-001.md"
git -C "$R" add engine/tasks/T-001.md
try_commit "$R"
assert_exit "S3: normal commit succeeds without bypass flag" 0 $COMMIT_RC
assert_not_contains "S3: no bypass message in output" "$COMMIT_ERR" "bypass detected"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && echo "ALL PASS" || echo "SOME FAILURES"
exit "$FAIL"
