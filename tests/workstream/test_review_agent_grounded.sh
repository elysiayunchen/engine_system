#!/usr/bin/env bash
# Test: E_GROUNDED + E_INDEPENDENCE validation (T-073, v6.22.0)
#
# Validates that engine-review-agent-validate.sh enforces:
#   - E_GROUNDED: finding file:line references must exist (>50% ungrounded → FAIL)
#   - E_INDEPENDENCE: reviewer_session should differ from packaged_by (WARN)
#
# Scenarios:
#   S1: all findings reference valid file:line → PASS
#   S2: >50% findings reference non-existent file → FAIL E_GROUNDED
#   S3: <=50% ungrounded → PASS with WARN
#   S4: reviewer_session matches packaged_by → PASS with WARN
#   S5: reviewer_session missing → PASS with WARN (grace period)

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

echo "=== test_review_agent_grounded.sh ==="

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_REPO="$(cd "$SCRIPT_DIR/../.." && pwd)"
VALIDATE_SH="$ROOT_REPO/engine/scripts/engine-review-agent-validate.sh"

TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# python detection
PY=python3
command -v python3 >/dev/null 2>&1 || PY=python

setup_validate_env() {
  local dir="$1"
  mkdir -p "$dir/engine/review/evidence/T-099" "$dir/src"
  cd "$dir"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"
  echo '{"defaults":{"agent_review":{"enabled":true,"min_entries_per_dimension":1,"min_narrative_chars":50,"min_entry_message_chars":10,"max_package_age_hours":72}},"overrides":{}}' > engine/review/config.json
  echo "real content line 1" > src/real.sh
  echo "real content line 2" >> src/real.sh
  echo "real content line 3" >> src/real.sh
  # Create package with packaged_by header
  cat > engine/review/evidence/T-099/review-package.md << 'PKGEOF'
# Code Review Package: T-099

> generated: 2026-07-31T10:00:00Z
> package_sha256: PLACEHOLDER
> head_commit: COMMITPLACEHOLDER
> packaged_by: packager-session-abc
> task: test task
> scope: abcd1234..efgh5678, 1 code files

## 1. Task Context
### GOAL
test
PKGEOF
  # Backfill sha256 (COMPUTE normalization)
  local head_commit
  git add -A && git commit -qm "init"
  head_commit=$(git rev-parse HEAD)
  sed -i "s/COMMITPLACEHOLDER/$head_commit/" engine/review/evidence/T-099/review-package.md
  # Compute sha with COMPUTE normalization
  local sha
  sha=$("$PY" -c "
import hashlib, re, os
f = os.environ['PKG']
with open(f, encoding='utf-8', newline='') as fh:
    content = fh.read()
normalized = re.sub(r'(> package_sha256: ).*', r'\1COMPUTE', content, count=1)
print(hashlib.sha256(normalized.encode('utf-8')).hexdigest())
" 2>/dev/null) || sha="deadbeef"
  PKG="$dir/engine/review/evidence/T-099/review-package.md" "$PY" -c "
import hashlib, re, os
f = os.environ['PKG']
with open(f, encoding='utf-8', newline='') as fh:
    content = fh.read()
normalized = re.sub(r'(> package_sha256: ).*', r'\1COMPUTE', content, count=1)
sha = hashlib.sha256(normalized.encode('utf-8')).hexdigest()
content = content.replace('package_sha256: PLACEHOLDER', f'package_sha256: {sha}', 1)
with open(f, 'w', encoding='utf-8', newline='') as fh:
    fh.write(content)
" 2>/dev/null
  git add -A && git commit -qm "package" --allow-empty 2>/dev/null || true
  echo "$head_commit"
}

make_review_json() {
  local dir="$1" commit="$2" sha="$3" session="$4"
  local entries=""
  shift 4
  # remaining args are "file:line:type" tuples for correctness entries
  local corr_entries=""
  for spec in "$@"; do
    local fpath=$(echo "$spec" | cut -d: -f1)
    local fline=$(echo "$spec" | cut -d: -f2)
    local etype=$(echo "$spec" | cut -d: -f3)
    corr_entries="$corr_entries{\"id\":\"agent-correctness-$fpath:$fline\",\"severity\":\"medium\",\"type\":\"$etype\",\"file\":\"$fpath\",\"line\":$fline,\"message\":\"This is a test finding message that is long enough\"},"
  done
  corr_entries="${corr_entries%,}"

  local reviewer_session_field=""
  if [ -n "$session" ]; then
    reviewer_session_field="\"reviewer_session\": \"$session\","
  fi

  cat > "$dir/engine/review/evidence/T-099/AGENT-REVIEW.json" << JSONEOF
{
  "task": "T-099",
  "timestamp": "2026-07-31T10:05:00Z",
  "reviewer": {"type": "agent"},
  "status": "pass",
  "dimensions": {
    "correctness": {"entries": [$corr_entries], "summary": "Test correctness summary for validation"},
    "design": {"entries": [{"id":"agent-design-1","severity":"info","type":"strength","file":"src/real.sh","line":1,"message":"Good design pattern observed here"}], "summary": "Test design summary"},
    "consistency": {"entries": [{"id":"agent-consistency-1","severity":"info","type":"strength","file":"src/real.sh","line":1,"message":"Consistent naming conventions"}], "summary": "Test consistency summary"},
    "readability": {"entries": [{"id":"agent-readability-1","severity":"info","type":"strength","file":"src/real.sh","line":2,"message":"Clear and readable code structure"}], "summary": "Test readability summary"},
    "completeness": {"entries": [{"id":"agent-completeness-1","severity":"info","type":"strength","file":"src/real.sh","line":3,"message":"Complete implementation coverage"}], "summary": "Test completeness summary"}
  },
  "adversarial_responses": [
    {"challenge": "q1", "response": "This is a substantive response to challenge one that exceeds thirty characters"},
    {"challenge": "q2", "response": "This is a substantive response to challenge two that exceeds thirty characters"},
    {"challenge": "q3", "response": "This is a substantive response to challenge three that exceeds thirty characters"}
  ],
  "overall_assessment": "This is a comprehensive overall assessment that covers the review findings and provides context for the pass status decision made by the reviewer agent.",
  "write_provenance": {
    "writer": "agent-reviewer",
    "commit": "$commit",
    "timestamp": "2026-07-31T10:05:00Z",
    "package_sha256": "$sha",
    $reviewer_session_field
    "argv": "test"
  }
}
JSONEOF
}

get_package_sha() {
  local dir="$1"
  "$PY" -c "
import hashlib, re, os
f = os.environ['PKG']
with open(f, encoding='utf-8', newline='') as fh:
    content = fh.read()
normalized = re.sub(r'(> package_sha256: ).*', r'\1COMPUTE', content, count=1)
print(hashlib.sha256(normalized.encode('utf-8')).hexdigest())
" 2>/dev/null
}

# --- S1: all findings grounded → PASS ---
echo ""
echo "--- S1: all findings reference valid files → PASS ---"
S1="$TMPDIR_TEST/s1"
HEAD1=$(setup_validate_env "$S1")
SHA1=$(PKG="$S1/engine/review/evidence/T-099/review-package.md" get_package_sha "$S1")
make_review_json "$S1" "$HEAD1" "$SHA1" "reviewer-xyz" "src/real.sh:1:finding" "src/real.sh:2:finding"
OUT1=$(CLAUDE_PROJECT_DIR="$S1" bash "$VALIDATE_SH" T-099 2>&1); RC1=$?
assert_exit "S1 validate exits 0" 0 $RC1
assert_not_contains "S1 no E_GROUNDED error" "$OUT1" "FAIL E_GROUNDED"

# --- S2: >50% ungrounded → FAIL ---
echo ""
echo "--- S2: >50% findings reference non-existent files → FAIL E_GROUNDED ---"
S2="$TMPDIR_TEST/s2"
HEAD2=$(setup_validate_env "$S2")
SHA2=$(PKG="$S2/engine/review/evidence/T-099/review-package.md" get_package_sha "$S2")
# 3 findings: 2 reference non-existent files (>50%)
make_review_json "$S2" "$HEAD2" "$SHA2" "reviewer-xyz" "src/real.sh:1:finding" "src/ghost.sh:5:finding" "src/phantom.py:99:finding"
OUT2=$(CLAUDE_PROJECT_DIR="$S2" bash "$VALIDATE_SH" T-099 2>&1); RC2=$?
assert_exit "S2 validate exits 1" 1 $RC2
assert_contains "S2 E_GROUNDED in output" "$OUT2" "E_GROUNDED"

# --- S3: <=50% ungrounded → PASS with WARN ---
echo ""
echo "--- S3: <=50% ungrounded → PASS with WARN ---"
S3="$TMPDIR_TEST/s3"
HEAD3=$(setup_validate_env "$S3")
SHA3=$(PKG="$S3/engine/review/evidence/T-099/review-package.md" get_package_sha "$S3")
# 3 findings: 1 non-existent (33% <= 50%)
make_review_json "$S3" "$HEAD3" "$SHA3" "reviewer-xyz" "src/real.sh:1:finding" "src/real.sh:2:finding" "src/ghost.sh:5:finding"
OUT3=$(CLAUDE_PROJECT_DIR="$S3" bash "$VALIDATE_SH" T-099 2>&1); RC3=$?
assert_exit "S3 validate exits 0" 0 $RC3
assert_contains "S3 WARN about grounded" "$OUT3" "non-existent file\|exceeds file length"

# --- S4: reviewer_session matches packaged_by → FAIL ---
echo ""
echo "--- S4: reviewer_session == packaged_by → FAIL E_INDEPENDENCE ---"
S4="$TMPDIR_TEST/s4"
HEAD4=$(setup_validate_env "$S4")
SHA4=$(PKG="$S4/engine/review/evidence/T-099/review-package.md" get_package_sha "$S4")
# session matches packaged_by (packager-session-abc)
make_review_json "$S4" "$HEAD4" "$SHA4" "packager-session-abc" "src/real.sh:1:finding"
OUT4=$(CLAUDE_PROJECT_DIR="$S4" bash "$VALIDATE_SH" T-099 2>&1); RC4=$?
assert_exit "S4 validate exits 1 (FAIL)" 1 $RC4
assert_contains "S4 independence error" "$OUT4" "E_INDEPENDENCE\|separate agent"

# --- S5: reviewer_session missing → FAIL ---
echo ""
echo "--- S5: reviewer_session missing → FAIL E_INDEPENDENCE ---"
S5="$TMPDIR_TEST/s5"
HEAD5=$(setup_validate_env "$S5")
SHA5=$(PKG="$S5/engine/review/evidence/T-099/review-package.md" get_package_sha "$S5")
make_review_json "$S5" "$HEAD5" "$SHA5" "" "src/real.sh:1:finding"
OUT5=$(CLAUDE_PROJECT_DIR="$S5" bash "$VALIDATE_SH" T-099 2>&1); RC5=$?
assert_exit "S5 validate exits 1 (FAIL)" 1 $RC5
assert_contains "S5 mandatory subagent error" "$OUT5" "E_INDEPENDENCE\|mandatory"

# --- Summary ---
echo ""
echo "=== RESULTS: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
