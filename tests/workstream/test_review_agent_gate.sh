#!/usr/bin/env bash
# Test: pre-commit agent-reviewer gate (T-072, v6.21.0)
#
# Validates the AGENT-REVIEW.json provenance extension in pre-commit.
# Extracted logic mirrors the pre-commit block (v6.21.0 T-072).
#
# Scenarios:
#   S1: AGENT-REVIEW.json writer=agent-reviewer + valid sha → PASS
#   S2: AGENT-REVIEW.json writer=wrong → FAIL
#   S3: AGENT-REVIEW.json package_sha256 tampered → FAIL
#   S4: AGENT-REVIEW.json stale commit → FAIL
#   S5: REVIEW.json writer=engine-review (regression) → PASS
#   S6: REVIEW.json writer=wrong (regression) → FAIL

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

echo "=== test_review_agent_gate.sh ==="

ROOT_REPO="$(cd "$(dirname "$0")/../.." && pwd)"
TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# python detection
PY=python3
command -v python3 >/dev/null 2>&1 || PY=python

# --- Extracted gate logic (mirrors pre-commit v6.21.0 T-072 block) ---
# Args: $1=root $2=file $3=tid
# Returns: 0=pass, 1=fail
agent_review_gate() {
  local root="$1" file="$2" tid="$3"
  local content prov_writer prov_commit head_commit

  content="$(cat "$root/$file" 2>/dev/null || true)"
  [ -n "$content" ] || return 1
  prov_writer="$(printf '%s\n' "$content" | grep -oE '"writer":"[^"]*"' | head -1 | sed 's/"writer":"//;s/"//')"
  prov_commit="$(printf '%s\n' "$content" | grep -oE '"commit":"[^"]*"' | head -1 | sed 's/"commit":"//;s/"//')"
  head_commit="$(git -C "$root" rev-parse HEAD 2>/dev/null || echo unknown)"

  local is_agent=false
  case "$file" in
    */AGENT-REVIEW.json) is_agent=true ;;
  esac

  if [ "$is_agent" = true ]; then
    # AGENT-REVIEW.json path
    [ "$prov_writer" = "agent-reviewer" ] || { echo "invalid writer: $prov_writer"; return 1; }
    [ "$prov_commit" = "$head_commit" ] || { echo "stale commit"; return 1; }
    # package_sha256 check
    local prov_sha pkg_file
    prov_sha="$(printf '%s\n' "$content" | grep -oE '"package_sha256":"[^"]*"' | head -1 | sed 's/"package_sha256":"//;s/"//')"
    pkg_file="$root/engine/review/evidence/$tid/review-package.md"
    if [ -n "$prov_sha" ] && [ -f "$pkg_file" ]; then
      local actual_sha
      actual_sha="$("$PY" -c "
import hashlib, re, sys
with open(sys.argv[1], encoding='utf-8') as f:
    c = f.read()
n = re.sub(r'(> package_sha256: ).*', r'\1COMPUTE', c)
print(hashlib.sha256(n.encode('utf-8')).hexdigest())
" "$pkg_file" 2>/dev/null || echo "")"
      if [ -n "$actual_sha" ] && [ "$prov_sha" != "$actual_sha" ]; then
        echo "package_sha256 mismatch"
        return 1
      fi
    fi
  else
    # REVIEW.json path (regression)
    local prov_argv
    prov_argv="$(printf '%s\n' "$content" | grep -oE '"argv":"[^"]*"' | head -1 | sed 's/"argv":"//;s/"//')"
    [ "$prov_writer" = "engine-review" ] || { echo "invalid writer: $prov_writer"; return 1; }
    [ "$prov_commit" = "$head_commit" ] || { echo "stale commit"; return 1; }
    [ "$prov_argv" = "engine review $tid" ] || { echo "argv mismatch: $prov_argv"; return 1; }
  fi
  return 0
}

# --- Setup temp repo ---
cd "$TMPDIR_TEST"
git init -q
mkdir -p engine/review/evidence/T-090 engine/tasks

# Create a review-package.md with known sha256
cat > engine/review/evidence/T-090/review-package.md << 'PKGEOF'
# Code Review Package: T-090

> generated: 2026-07-31T00:00:00Z
> package_sha256: PLACEHOLDER
> head_commit: abc123

## 1. Task Context
test
PKGEOF

# Compute and backfill sha256 (COMPUTE normalization)
PKG_SHA="$("$PY" -c "
import hashlib, re
with open('engine/review/evidence/T-090/review-package.md', encoding='utf-8') as f:
    c = f.read()
n = re.sub(r'(> package_sha256: ).*', r'\1COMPUTE', c)
print(hashlib.sha256(n.encode('utf-8')).hexdigest())
")"
sed -i "s/package_sha256: PLACEHOLDER/package_sha256: $PKG_SHA/" engine/review/evidence/T-090/review-package.md 2>/dev/null || \
  "$PY" -c "
import pathlib
p = pathlib.Path('engine/review/evidence/T-090/review-package.md')
t = p.read_text(encoding='utf-8')
p.write_text(t.replace('package_sha256: PLACEHOLDER', 'package_sha256: $PKG_SHA'), encoding='utf-8')
"

HEAD_COMMIT="$(git rev-parse HEAD 2>/dev/null || echo unknown)"
# Need a commit for HEAD to work
echo "test" > test.sh
git add test.sh engine/review/evidence/T-090/review-package.md
git -c core.hooksPath=nul commit -q -m "setup" --no-verify 2>/dev/null || git commit -q -m "setup" --no-verify
HEAD_COMMIT="$(git rev-parse HEAD)"

# --- S1: valid AGENT-REVIEW.json ---
echo ""
echo "--- S1: valid AGENT-REVIEW.json (writer=agent-reviewer, valid sha) ---"
cat > engine/review/evidence/T-090/AGENT-REVIEW.json << SEOF
{"task":"T-090","timestamp":"2026-07-31T00:00:00Z","status":"pass","write_provenance":{"writer":"agent-reviewer","commit":"$HEAD_COMMIT","package_sha256":"$PKG_SHA"}}
SEOF
out=$(agent_review_gate "$TMPDIR_TEST" "engine/review/evidence/T-090/AGENT-REVIEW.json" "T-090" 2>&1)
rc=$?
assert_exit "S1: valid agent review passes" 0 $rc

# --- S2: wrong writer ---
echo ""
echo "--- S2: AGENT-REVIEW.json wrong writer ---"
cat > engine/review/evidence/T-090/AGENT-REVIEW.json << SEOF
{"task":"T-090","timestamp":"2026-07-31T00:00:00Z","status":"pass","write_provenance":{"writer":"human-reviewer","commit":"$HEAD_COMMIT","package_sha256":"$PKG_SHA"}}
SEOF
out=$(agent_review_gate "$TMPDIR_TEST" "engine/review/evidence/T-090/AGENT-REVIEW.json" "T-090" 2>&1)
rc=$?
assert_exit "S2: wrong writer exit 1" 1 $rc
assert_output_contains "S2: mentions invalid writer" "$out" "invalid writer"

# --- S3: tampered package_sha256 ---
echo ""
echo "--- S3: AGENT-REVIEW.json tampered package_sha256 ---"
cat > engine/review/evidence/T-090/AGENT-REVIEW.json << SEOF
{"task":"T-090","timestamp":"2026-07-31T00:00:00Z","status":"pass","write_provenance":{"writer":"agent-reviewer","commit":"$HEAD_COMMIT","package_sha256":"deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef"}}
SEOF
out=$(agent_review_gate "$TMPDIR_TEST" "engine/review/evidence/T-090/AGENT-REVIEW.json" "T-090" 2>&1)
rc=$?
assert_exit "S3: tampered sha exit 1" 1 $rc
assert_output_contains "S3: mentions mismatch" "$out" "mismatch"

# --- S4: stale commit ---
echo ""
echo "--- S4: AGENT-REVIEW.json stale commit ---"
cat > engine/review/evidence/T-090/AGENT-REVIEW.json << SEOF
{"task":"T-090","timestamp":"2026-07-31T00:00:00Z","status":"pass","write_provenance":{"writer":"agent-reviewer","commit":"0000000000000000000000000000000000000000","package_sha256":"$PKG_SHA"}}
SEOF
out=$(agent_review_gate "$TMPDIR_TEST" "engine/review/evidence/T-090/AGENT-REVIEW.json" "T-090" 2>&1)
rc=$?
assert_exit "S4: stale commit exit 1" 1 $rc
assert_output_contains "S4: mentions stale" "$out" "stale"

# --- S5: REVIEW.json regression (writer=engine-review) ---
echo ""
echo "--- S5: REVIEW.json writer=engine-review (regression) ---"
cat > engine/review/evidence/T-090/REVIEW.json << SEOF
{"task":"T-090","timestamp":"2026-07-31T00:00:00Z","status":"pass","write_provenance":{"writer":"engine-review","commit":"$HEAD_COMMIT","argv":"engine review T-090"}}
SEOF
out=$(agent_review_gate "$TMPDIR_TEST" "engine/review/evidence/T-090/REVIEW.json" "T-090" 2>&1)
rc=$?
assert_exit "S5: REVIEW.json regression passes" 0 $rc

# --- S6: REVIEW.json wrong writer (regression) ---
echo ""
echo "--- S6: REVIEW.json wrong writer (regression) ---"
cat > engine/review/evidence/T-090/REVIEW.json << SEOF
{"task":"T-090","timestamp":"2026-07-31T00:00:00Z","status":"pass","write_provenance":{"writer":"agent-reviewer","commit":"$HEAD_COMMIT","argv":"engine review T-090"}}
SEOF
out=$(agent_review_gate "$TMPDIR_TEST" "engine/review/evidence/T-090/REVIEW.json" "T-090" 2>&1)
rc=$?
assert_exit "S6: REVIEW.json wrong writer exit 1" 1 $rc
assert_output_contains "S6: mentions invalid writer" "$out" "invalid writer"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
