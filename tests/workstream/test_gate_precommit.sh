#!/usr/bin/env bash
# Test: pre-commit GATE.json enforcement at done-transition (T-077, v6.24.0)
#
# Validates the quality gate check in engine/scripts/githooks/pre-commit:
#   - Cards transitioning to done require staged GATE.json with status=pass
#   - Provenance: writer=engine-gate, commit=HEAD
#   - Exempt cards skip the check
#   - Already-done cards skip the check
#
# Scenarios:
#   S1: Done-transition without GATE.json → commit blocked
#   S2: Done-transition with GATE.json status=pass → commit succeeds
#   S3: Done-transition with GATE.json status=block → commit blocked
#   S4: Exempt card → GATE.json check skipped
#   S5: Already-done card modification → check skipped
#   S6: GATE.json provenance stale → commit blocked

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

echo "=== test_gate_precommit.sh ==="

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
  mkdir -p "$d/engine/tasks" "$d/engine/evidence/T-001" "$d/engine/gate" "$d/engine/.cache"
  # AGENTS.md with contract-version (enables strict_task_mode)
  cat > "$d/AGENTS.md" <<'EOF'
# AGENTS.md
contract-version: 6.24.0
EOF
  # gate config (required for GATE.json enforcement)
  cat > "$d/engine/gate/config.json" <<'GCEOF'
{
  "defaults": {
    "gates": ["verify", "review", "review_agent", "prove"],
    "code_extensions": [".sh", ".py", ".js"],
    "docs_only_skip": ["review", "review_agent", "prove"]
  },
  "overrides": {}
}
GCEOF
  # Active task card (so governing_files is non-empty)
  cat > "$d/engine/tasks/T-001.md" <<'EOF'
# T-001
> status: active | lane: engine-runtime

## WRITE-SET
- engine/tasks/**
- engine/evidence/**

## FORBIDDEN

## GOAL
Test gate

AC: AC-1 test | verify: true
EOF
  # Initial commit (bypass hook)
  git -C "$d" add -A
  git -C "$d" commit -qm "init" --no-verify
  # Create AC evidence with valid provenance (commit = HEAD after init).
  # Left UNCOMMITTED — tests stage it alongside the done card so that
  # HEAD == provenance.commit at done-transition time.
  local head_sha
  head_sha="$(git -C "$d" rev-parse HEAD)"
  cat > "$d/engine/evidence/T-001/AC-1.json" <<ACEOF
{"ac":"AC-1","status":"pass","exit":0,"write_provenance":{"writer":"engine-verify","commit":"$head_sha","argv":"engine verify T-001"}}
ACEOF
  printf '%s\n' "$d"
}

# --- Helper: attempt a commit, capture stderr ---
# Usage: try_commit "$repo" -> sets COMMIT_RC, COMMIT_ERR
try_commit() {
  local d="$1"
  COMMIT_ERR="$(cd "$d" && CLAUDE_PROJECT_DIR="$d" git -c user.email="test@test.com" -c user.name="Test" commit -m "test" 2>&1)"
  COMMIT_RC=$?
}

# ===========================================================================
# S1: Done-transition without GATE.json → commit blocked
# ===========================================================================
echo ""
echo "--- S1: Done-transition without GATE.json ---"
R="$(new_repo)"
# Transition card to done (stage only the task card - bootstrap exempt)
cat > "$R/engine/tasks/T-001.md" <<'EOF'
# T-001
> status: done | lane: engine-runtime

## WRITE-SET
- engine/tasks/**
- engine/evidence/**

## FORBIDDEN

## GOAL
Test gate

AC: AC-1 test | verify: true
EOF
git -C "$R" add engine/tasks/T-001.md engine/evidence/T-001/AC-1.json
try_commit "$R"
if [ "$COMMIT_RC" -ne 0 ]; then
  PASS=$((PASS+1)); echo "  PASS: S1 commit blocked (exit $COMMIT_RC)"
else
  FAIL=$((FAIL+1)); echo "  FAIL: S1 commit should be blocked but succeeded"
fi
assert_contains "S1: stderr mentions engine gate" "$COMMIT_ERR" "engine gate"

# ===========================================================================
# S2: Done-transition with GATE.json status=pass → commit succeeds
# ===========================================================================
echo ""
echo "--- S2: Done-transition with GATE.json pass ---"
R="$(new_repo)"
HEAD_SHA="$(git -C "$R" rev-parse HEAD)"
# Transition card to done
cat > "$R/engine/tasks/T-001.md" <<'EOF'
# T-001
> status: done | lane: engine-runtime

## WRITE-SET
- engine/tasks/**
- engine/evidence/**

## FORBIDDEN

## GOAL
Test gate enforcement

AC: AC-1 test | verify: true
EOF
# Create GATE.json with valid provenance
cat > "$R/engine/evidence/T-001/GATE.json" <<GEOF
{
  "task": "T-001",
  "timestamp": "2026-01-01T00:00:00Z",
  "status": "pass",
  "gates": {
    "verify": {"status": "pass", "detail": "1/1 AC PASS"},
    "review": {"status": "pass", "detail": "ok"},
    "review_agent": {"status": "pass", "detail": "ok"},
    "prove": {"status": "pass", "detail": "ok"}
  },
  "write_provenance": {
    "writer": "engine-gate",
    "commit": "$HEAD_SHA",
    "timestamp": "2026-01-01T00:00:00Z",
    "argv": "engine gate T-001"
  }
}
GEOF
# Stage task card + AC evidence + GATE.json
git -C "$R" add engine/tasks/T-001.md engine/evidence/T-001/AC-1.json engine/evidence/T-001/GATE.json
try_commit "$R"
assert_exit "S2: commit succeeds with GATE.json pass" 0 $COMMIT_RC

# ===========================================================================
# S3: Done-transition with GATE.json status=block → commit blocked
# ===========================================================================
echo ""
echo "--- S3: Done-transition with GATE.json block ---"
R="$(new_repo)"
HEAD_SHA="$(git -C "$R" rev-parse HEAD)"
cat > "$R/engine/tasks/T-001.md" <<'EOF'
# T-001
> status: done | lane: engine-runtime

## WRITE-SET
- engine/tasks/**
- engine/evidence/**

## FORBIDDEN

## GOAL
Test gate

AC: AC-1 test | verify: true
EOF
cat > "$R/engine/evidence/T-001/GATE.json" <<GEOF
{
  "task": "T-001",
  "timestamp": "2026-01-01T00:00:00Z",
  "status": "block",
  "gates": {
    "verify": {"status": "pass", "detail": "1/1 AC PASS"},
    "review": {"status": "block", "detail": "linter found issues"}
  },
  "write_provenance": {
    "writer": "engine-gate",
    "commit": "$HEAD_SHA",
    "timestamp": "2026-01-01T00:00:00Z",
    "argv": "engine gate T-001"
  }
}
GEOF
git -C "$R" add engine/tasks/T-001.md engine/evidence/T-001/AC-1.json engine/evidence/T-001/GATE.json
try_commit "$R"
if [ "$COMMIT_RC" -ne 0 ]; then
  PASS=$((PASS+1)); echo "  PASS: S3 commit blocked (exit $COMMIT_RC)"
else
  FAIL=$((FAIL+1)); echo "  FAIL: S3 commit should be blocked but succeeded"
fi
assert_contains "S3: stderr mentions quality gates not satisfied" "$COMMIT_ERR" "quality gates not satisfied"

# ===========================================================================
# S4: Exempt card → GATE.json check skipped
# ===========================================================================
echo ""
echo "--- S4: Exempt card ---"
R="$(new_repo)"
cat > "$R/engine/tasks/T-001.md" <<'EOF'
# T-001
> status: done | lane: engine-runtime
exempt: architect-approved

## WRITE-SET
- engine/tasks/**
- engine/evidence/**

## FORBIDDEN

## GOAL
Test gate

AC: AC-1 test | verify: true
EOF
# No GATE.json needed
git -C "$R" add engine/tasks/T-001.md
try_commit "$R"
assert_exit "S4: exempt card commit succeeds without GATE.json" 0 $COMMIT_RC

# ===========================================================================
# S5: Already-done card modification → check skipped
# ===========================================================================
echo ""
echo "--- S5: Already-done card modification ---"
R="$(new_repo)"
# First, make the card done in HEAD (bypass hook for setup)
cat > "$R/engine/tasks/T-001.md" <<'EOF'
# T-001
> status: done | lane: engine-runtime

## WRITE-SET
- engine/tasks/**
- engine/evidence/**

## FORBIDDEN

## GOAL
Test gate

AC: AC-1 test | verify: true
EOF
git -C "$R" add engine/tasks/T-001.md
git -C "$R" commit -qm "card done" --no-verify
# Now modify the already-done card (still done, just content change)
cat > "$R/engine/tasks/T-001.md" <<'EOF'
# T-001
> status: done | lane: engine-runtime

## WRITE-SET
- engine/tasks/**
- engine/evidence/**

## FORBIDDEN

## GOAL
Test gate updated

AC: AC-1 test | verify: true
EOF
git -C "$R" add engine/tasks/T-001.md
try_commit "$R"
assert_exit "S5: already-done modification succeeds without GATE.json" 0 $COMMIT_RC

# ===========================================================================
# S6: GATE.json provenance stale → commit blocked
# ===========================================================================
echo ""
echo "--- S6: GATE.json provenance stale ---"
R="$(new_repo)"
cat > "$R/engine/tasks/T-001.md" <<'EOF'
# T-001
> status: done | lane: engine-runtime

## WRITE-SET
- engine/tasks/**
- engine/evidence/**

## FORBIDDEN

## GOAL
Test gate

AC: AC-1 test | verify: true
EOF
# GATE.json with wrong commit (stale)
cat > "$R/engine/evidence/T-001/GATE.json" <<'GEOF'
{
  "task": "T-001",
  "timestamp": "2026-01-01T00:00:00Z",
  "status": "pass",
  "gates": {
    "verify": {"status": "pass", "detail": "1/1 AC PASS"}
  },
  "write_provenance": {
    "writer": "engine-gate",
    "commit": "0000000000000000000000000000000000000000",
    "timestamp": "2026-01-01T00:00:00Z",
    "argv": "engine gate T-001"
  }
}
GEOF
git -C "$R" add engine/tasks/T-001.md engine/evidence/T-001/AC-1.json engine/evidence/T-001/GATE.json
try_commit "$R"
if [ "$COMMIT_RC" -ne 0 ]; then
  PASS=$((PASS+1)); echo "  PASS: S6 commit blocked (exit $COMMIT_RC)"
else
  FAIL=$((FAIL+1)); echo "  FAIL: S6 commit should be blocked but succeeded"
fi
assert_contains "S6: stderr mentions stale" "$COMMIT_ERR" "stale"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && echo "ALL PASS" || echo "SOME FAILURES"
exit "$FAIL"
