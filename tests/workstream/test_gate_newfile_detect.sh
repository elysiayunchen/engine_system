#!/usr/bin/env bash
# Test: engine gate has_code detection for new files (v6.26.1)
#
# Validates the fallback filesystem check in engine-gate.sh:
#   - WRITE-SET with annotated paths "(new)" -> code detected
#   - WRITE-SET with directory entries -> code files inside detected
#   - WRITE-SET with glob patterns -> expanded and code detected
#   - New file on disk not matching string extension -> fallback catches it
#
# All scenarios should result in review/prove NOT being skipped.

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

echo "=== test_gate_newfile_detect.sh ==="

REAL_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GATE_SCRIPT="$REAL_ROOT/engine/scripts/engine-gate.sh"
[ -f "$GATE_SCRIPT" ] || { echo "FATAL: $GATE_SCRIPT not found"; exit 2; }

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
  cat > "$d/engine/gate/config.json" <<'GCEOF'
{
  "defaults": {
    "gates": ["verify", "review", "review_agent", "prove"],
    "code_extensions": [".sh", ".ps1", ".py", ".js", ".ts"],
    "docs_only_skip": ["review", "review_agent", "prove"],
    "agent_review": {"enabled": true}
  },
  "overrides": {}
}
GCEOF
  mkdir -p "$d/engine/review"
  cat > "$d/engine/review/config.json" <<'RCEOF'
{"defaults": {"agent_review": {"enabled": true}}}
RCEOF
  echo "init" > "$d/README.md"
  git -C "$d" add -A
  git -C "$d" commit -qm "init" --no-verify
  printf '%s\n' "$d"
}

# --- Helper: provide all-pass evidence so gate exits 0 ---
provide_pass_evidence() {
  local d="$1"
  cat > "$d/engine/evidence/T-001/AC-1.json" <<'EOF'
{"ac":"AC-1","status":"pass","exit":0}
EOF
  cat > "$d/engine/review/evidence/T-001/REVIEW.json" <<'EOF'
{"task":"T-001","status":"pass"}
EOF
  cat > "$d/engine/review/evidence/T-001/AGENT-REVIEW.json" <<'EOF'
{"task":"T-001","status":"pass"}
EOF
  cat > "$d/engine/evidence/T-001/PROVE.json" <<'EOF'
{"task":"T-001","status":"pass"}
EOF
}

# ===========================================================================
# S1: Annotated WRITE-SET path "(new)" -> code detected, review NOT skipped
# ===========================================================================
echo ""
echo "--- S1: Annotated path (new) ---"
R="$(new_repo)"
mkdir -p "$R/src"
echo '#!/bin/bash' > "$R/src/helper.sh"
cat > "$R/engine/tasks/T-001.md" <<'EOF'
# T-001
> status: active | lane: engine-runtime

## WRITE-SET
- src/helper.sh (new)

## FORBIDDEN

AC: AC-1 test | verify: true
EOF
provide_pass_evidence "$R"
git -C "$R" add -A && git -C "$R" commit -qm "setup" --no-verify

out="$(cd "$R" && CLAUDE_PROJECT_DIR="$R" bash "$GATE_SCRIPT" T-001 2>&1)"
rc=$?
assert_exit "S1: annotated path exit 0" 0 $rc
gate_content="$(cat "$R/engine/evidence/T-001/GATE.json" 2>/dev/null || echo "")"
assert_not_contains "S1: review NOT skipped" "$gate_content" 'no code changes'

# ===========================================================================
# S2: Directory in WRITE-SET containing code files -> detected
# ===========================================================================
echo ""
echo "--- S2: Directory WRITE-SET entry ---"
R="$(new_repo)"
mkdir -p "$R/scripts"
echo 'print("hi")' > "$R/scripts/tool.py"
echo '# readme' > "$R/scripts/README.md"
cat > "$R/engine/tasks/T-001.md" <<'EOF'
# T-001
> status: active | lane: engine-runtime

## WRITE-SET
- scripts/

## FORBIDDEN

AC: AC-1 test | verify: true
EOF
provide_pass_evidence "$R"
git -C "$R" add -A && git -C "$R" commit -qm "setup" --no-verify

out="$(cd "$R" && CLAUDE_PROJECT_DIR="$R" bash "$GATE_SCRIPT" T-001 2>&1)"
rc=$?
assert_exit "S2: directory entry exit 0" 0 $rc
gate_content="$(cat "$R/engine/evidence/T-001/GATE.json" 2>/dev/null || echo "")"
assert_not_contains "S2: prove NOT skipped" "$gate_content" 'no code changes'

# ===========================================================================
# S3: Glob pattern in WRITE-SET -> expanded, code detected
# ===========================================================================
echo ""
echo "--- S3: Glob pattern WRITE-SET ---"
R="$(new_repo)"
mkdir -p "$R/lib"
echo 'export const x = 1;' > "$R/lib/mod.ts"
echo 'body {}' > "$R/lib/style.css"
cat > "$R/engine/tasks/T-001.md" <<'EOF'
# T-001
> status: active | lane: engine-runtime

## WRITE-SET
- lib/*

## FORBIDDEN

AC: AC-1 test | verify: true
EOF
provide_pass_evidence "$R"
git -C "$R" add -A && git -C "$R" commit -qm "setup" --no-verify

out="$(cd "$R" && CLAUDE_PROJECT_DIR="$R" bash "$GATE_SCRIPT" T-001 2>&1)"
rc=$?
assert_exit "S3: glob pattern exit 0" 0 $rc
gate_content="$(cat "$R/engine/evidence/T-001/GATE.json" 2>/dev/null || echo "")"
assert_not_contains "S3: review NOT skipped" "$gate_content" 'no code changes'

# ===========================================================================
# S4: Bracket annotation "[added]" -> fallback strips and detects code
# ===========================================================================
echo ""
echo "--- S4: Bracket annotation [added] ---"
R="$(new_repo)"
mkdir -p "$R/engine/scripts"
echo '#!/bin/bash' > "$R/engine/scripts/new-tool.sh"
cat > "$R/engine/tasks/T-001.md" <<'EOF'
# T-001
> status: active | lane: engine-runtime

## WRITE-SET
- engine/scripts/new-tool.sh [added]

## FORBIDDEN

AC: AC-1 test | verify: true
EOF
provide_pass_evidence "$R"
git -C "$R" add -A && git -C "$R" commit -qm "setup" --no-verify

out="$(cd "$R" && CLAUDE_PROJECT_DIR="$R" bash "$GATE_SCRIPT" T-001 2>&1)"
rc=$?
assert_exit "S4: bracket annotation exit 0" 0 $rc
gate_content="$(cat "$R/engine/evidence/T-001/GATE.json" 2>/dev/null || echo "")"
assert_not_contains "S4: review NOT skipped" "$gate_content" 'no code changes'

# ===========================================================================
# S5: True docs-only (no code anywhere) -> still correctly skipped
# ===========================================================================
echo ""
echo "--- S5: True docs-only still skipped ---"
R="$(new_repo)"
mkdir -p "$R/docs"
echo '# Guide' > "$R/docs/guide.md"
cat > "$R/engine/tasks/T-001.md" <<'EOF'
# T-001
> status: active | lane: docs

## WRITE-SET
- docs/guide.md

## FORBIDDEN

AC: AC-1 test | verify: true
EOF
provide_pass_evidence "$R"
git -C "$R" add -A && git -C "$R" commit -qm "setup" --no-verify

out="$(cd "$R" && CLAUDE_PROJECT_DIR="$R" bash "$GATE_SCRIPT" T-001 2>&1)"
rc=$?
assert_exit "S5: docs-only exit 0" 0 $rc
gate_content="$(cat "$R/engine/evidence/T-001/GATE.json" 2>/dev/null || echo "")"
assert_contains "S5: review IS skipped" "$gate_content" "skipped"

# ===========================================================================
# Summary
# ===========================================================================
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
