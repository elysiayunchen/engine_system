#!/usr/bin/env bash
# Test: sh/ps1 behavioral mirror for review-agent (T-071 AC-16)
# Verifies: same input → same behavioral output (not byte-identical)
# Requires: Windows with Git Bash + PowerShell, or Unix with pwsh

set -u
PASS=0; FAIL=0
assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    PASS=$((PASS+1)); echo "  PASS: $desc"
  else
    FAIL=$((FAIL+1)); echo "  FAIL: $desc (expected='$expected' actual='$actual')"
  fi
}
assert_ok() {
  local desc="$1" rc="$2"
  if [ "$rc" -eq 0 ]; then
    PASS=$((PASS+1)); echo "  PASS: $desc"
  else
    FAIL=$((FAIL+1)); echo "  FAIL: $desc (exit $rc)"
  fi
}

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# Detect PowerShell
PS_CMD=""
if command -v powershell.exe >/dev/null 2>&1; then
  PS_CMD="powershell.exe -NoProfile -ExecutionPolicy Bypass -File"
elif command -v pwsh >/dev/null 2>&1; then
  PS_CMD="pwsh -NoProfile -File"
fi

echo "=== test_review_agent_mirror.sh ==="

if [ -z "$PS_CMD" ]; then
  echo "  SKIP: PowerShell not available (need powershell.exe or pwsh)"
  echo "=== Results: 0 passed, 0 failed (skipped) ==="
  exit 0
fi

# --- Setup fixture repo ---
TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT
cd "$TMPDIR_TEST"
git init -q
mkdir -p engine/tasks engine/scripts engine/review

# Windows path for PowerShell (CLAUDE_PROJECT_DIR)
if command -v cygpath >/dev/null 2>&1; then
  WIN_TMPDIR=$(cygpath -w "$TMPDIR_TEST")
else
  WIN_TMPDIR="$TMPDIR_TEST"
fi

# Copy scripts
cp "$ROOT/engine/scripts/engine-review-agent-package.sh" engine/scripts/
cp "$ROOT/engine/scripts/engine-review-agent-validate.sh" engine/scripts/
cp "$ROOT/engine/scripts/engine-review-agent-package.ps1" engine/scripts/
cp "$ROOT/engine/scripts/engine-review-agent-validate.ps1" engine/scripts/
cp "$ROOT/engine/review/config.json" engine/review/
cp "$ROOT/engine/review/protocol.md" engine/review/ 2>/dev/null || true

# Enable agent_review
if command -v python3 >/dev/null 2>&1; then PY=python3; else PY=python; fi
$PY -c "
import json
with open('engine/review/config.json') as f: cfg = json.load(f)
cfg['defaults']['agent_review']['enabled'] = True
with open('engine/review/config.json','w') as f: json.dump(cfg, f, indent=2)
"

# Task card + code
cat > engine/tasks/T-099.md << 'EOF'
# T-099: Mirror test
> status: active
GOAL: Test sh/ps1 mirror
## WRITE-SET
- src/main.sh
AC: AC-1 | verify: echo ok
EOF
mkdir -p src
echo '#!/bin/bash' > src/main.sh
echo 'echo "hello"' >> src/main.sh
git add -A && git commit -q -m "init"
echo 'echo "world"' >> src/main.sh
git add -A && git commit -q -m "change"

# =============================================
# M1: Package — sh vs ps1 behavioral equivalence
# =============================================
echo ""
echo "--- M1: package behavioral mirror ---"

# Run sh version
mkdir -p engine/review/evidence/T-099
bash engine/scripts/engine-review-agent-package.sh T-099 > /dev/null 2>&1
sh_rc=$?
sh_pkg_exists="no"
sh_sha=""
sh_sections=""
if [ -f engine/review/evidence/T-099/review-package.md ]; then
  sh_pkg_exists="yes"
  sh_sha=$(grep '^> package_sha256:' engine/review/evidence/T-099/review-package.md | sed 's/.*: //')
  sh_sections=$(grep -c '^## ' engine/review/evidence/T-099/review-package.md)
fi
# Save sh output for comparison (use relative path to avoid MSYS /tmp/ issue)
cp engine/review/evidence/T-099/review-package.md mirror-sh-package.md 2>/dev/null || true
rm -f engine/review/evidence/T-099/review-package.md

# Run ps1 version (set CLAUDE_PROJECT_DIR so ps1 finds the right root)
CLAUDE_PROJECT_DIR="$WIN_TMPDIR" $PS_CMD "$TMPDIR_TEST/engine/scripts/engine-review-agent-package.ps1" T-099 > /dev/null 2>&1
ps_rc=$?
ps_pkg_exists="no"
ps_sha=""
ps_sections=""
if [ -f engine/review/evidence/T-099/review-package.md ]; then
  ps_pkg_exists="yes"
  ps_sha=$(grep '^> package_sha256:' engine/review/evidence/T-099/review-package.md | sed 's/.*: //')
  ps_sections=$(grep -c '^## ' engine/review/evidence/T-099/review-package.md)
fi

assert_eq "M1: both exit 0" "0|0" "$sh_rc|$ps_rc"
assert_eq "M1: both produce package" "yes|yes" "$sh_pkg_exists|$ps_pkg_exists"
assert_eq "M1: same section count" "$sh_sections" "$ps_sections"

# sha256: both should be valid (re-compute and compare)
if [ "$sh_pkg_exists" = "yes" ] && [ -f mirror-sh-package.md ]; then
  sh_verify=$($PY -c "
import hashlib, re
with open('mirror-sh-package.md', encoding='utf-8') as f:
    content = f.read()
normalized = re.sub(r'(> package_sha256: ).*', r'\1COMPUTE', content)
print(hashlib.sha256(normalized.encode('utf-8')).hexdigest())
")
  assert_eq "M1: sh sha256 self-consistent" "$sh_sha" "$sh_verify"
fi
if [ "$ps_pkg_exists" = "yes" ]; then
  ps_verify=$($PY -c "
import hashlib, re
with open('engine/review/evidence/T-099/review-package.md', encoding='utf-8') as f:
    content = f.read()
normalized = re.sub(r'(> package_sha256: ).*', r'\1COMPUTE', content)
print(hashlib.sha256(normalized.encode('utf-8')).hexdigest())
")
  assert_eq "M1: ps1 sha256 self-consistent" "$ps_sha" "$ps_verify"
fi

# =============================================
# M2: Validate — sh vs ps1 behavioral equivalence
# =============================================
echo ""
echo "--- M2: validate behavioral mirror ---"

# Create a valid AGENT-REVIEW.json fixture
HEAD_SHA=$(git rev-parse HEAD)
# Use the ps1-generated package for sha
PKG_SHA="$ps_sha"

$PY -c "
import json
data = {
    'task': 'T-099', 'timestamp': '2026-07-31T12:00:00Z', 'status': 'pass',
    'dimensions': {
        'correctness': {'entries': [{'id':'agent-correctness-main.sh:1','severity':'info','type':'strength','file':'src/main.sh','line':1,'message':'This is a sufficiently long message for testing'}], 'summary': 'The correctness of this simple script is adequate for its purpose.'},
        'design': {'entries': [{'id':'agent-design-main.sh:1','severity':'info','type':'strength','file':'src/main.sh','line':1,'message':'The design is minimal and appropriate for the task'}], 'summary': 'Design is simple and fit for purpose.'},
        'consistency': {'entries': [{'id':'agent-consistency-main.sh:1','severity':'info','type':'strength','file':'src/main.sh','line':1,'message':'No cross-file consistency issues detected here'}], 'summary': 'No consistency issues found in this change.'},
        'readability': {'entries': [{'id':'agent-readability-main.sh:1','severity':'info','type':'strength','file':'src/main.sh','line':1,'message':'The code is clear and easy to understand'}], 'summary': 'Code is readable and straightforward.'},
        'completeness': {'entries': [{'id':'agent-completeness-main.sh:1','severity':'info','type':'strength','file':'src/main.sh','line':1,'message':'All necessary components are present'}], 'summary': 'The implementation is complete for scope.'}
    },
    'adversarial_responses': [
        {'challenge': 'q1', 'response': 'Empty input would cause the echo to output nothing, which is safe behavior.'},
        {'challenge': 'q2', 'response': 'No other files depend on this script so no assumptions are broken.'},
        {'challenge': 'q3', 'response': 'The simplicity means there is very little comprehension barrier.'}
    ],
    'overall_assessment': 'This is a very simple script that echoes a greeting. No significant issues found during review.',
    'write_provenance': {'writer': 'agent-reviewer', 'commit': '$HEAD_SHA', 'package_sha256': '$PKG_SHA'}
}
with open('engine/review/evidence/T-099/AGENT-REVIEW.json','w') as f:
    json.dump(data, f)
"

# Run sh validate
bash engine/scripts/engine-review-agent-validate.sh T-099 > /dev/null 2>&1
sh_val_rc=$?
sh_review_json="no"
sh_has_agent_review="no"
if [ -f engine/review/evidence/T-099/REVIEW.json ]; then
  sh_review_json="yes"
  grep -q "agent_review" engine/review/evidence/T-099/REVIEW.json && sh_has_agent_review="yes"
fi
# Save and clean for ps1 run
cp engine/review/evidence/T-099/REVIEW.json mirror-sh-review.json 2>/dev/null || true
rm -f engine/review/evidence/T-099/REVIEW.json
# Reset AGENT-REVIEW.json (sh validate appended validated_by)
$PY -c "
import json
with open('engine/review/evidence/T-099/AGENT-REVIEW.json') as f:
    data = json.load(f)
data['write_provenance'].pop('validated_by', None)
data['write_provenance'].pop('validated_at', None)
with open('engine/review/evidence/T-099/AGENT-REVIEW.json','w') as f:
    json.dump(data, f)
"

# Run ps1 validate (set CLAUDE_PROJECT_DIR so ps1 finds the right root)
CLAUDE_PROJECT_DIR="$WIN_TMPDIR" $PS_CMD "$TMPDIR_TEST/engine/scripts/engine-review-agent-validate.ps1" T-099 > /dev/null 2>&1
ps_val_rc=$?
ps_review_json="no"
ps_has_agent_review="no"
if [ -f engine/review/evidence/T-099/REVIEW.json ]; then
  ps_review_json="yes"
  grep -q "agent_review" engine/review/evidence/T-099/REVIEW.json && ps_has_agent_review="yes"
fi

assert_eq "M2: both validate exit 0" "0|0" "$sh_val_rc|$ps_val_rc"
assert_eq "M2: both create REVIEW.json" "yes|yes" "$sh_review_json|$ps_review_json"
assert_eq "M2: both have agent_review dim" "yes|yes" "$sh_has_agent_review|$ps_has_agent_review"

# =============================================
# M3: Validate rejection — same invalid input rejected by both
# =============================================
echo ""
echo "--- M3: rejection behavioral mirror ---"

# Invalid: shallow review
$PY -c "
import json
data = {
    'task': 'T-099', 'timestamp': '2026-07-31T12:00:00Z', 'status': 'pass',
    'dimensions': {
        'correctness': {'entries': [{'id':'x','severity':'info','type':'strength','file':'f','line':1,'message':'ok'}], 'summary': 'ok'},
        'design': {'entries': [{'id':'x','severity':'info','type':'strength','file':'f','line':1,'message':'ok'}], 'summary': 'ok'},
        'consistency': {'entries': [{'id':'x','severity':'info','type':'strength','file':'f','line':1,'message':'ok'}], 'summary': 'ok'},
        'readability': {'entries': [{'id':'x','severity':'info','type':'strength','file':'f','line':1,'message':'ok'}], 'summary': 'ok'},
        'completeness': {'entries': [{'id':'x','severity':'info','type':'strength','file':'f','line':1,'message':'ok'}], 'summary': 'ok'}
    },
    'adversarial_responses': [
        {'challenge': 'q1', 'response': 'short'},
        {'challenge': 'q2', 'response': 'short'},
        {'challenge': 'q3', 'response': 'short'}
    ],
    'overall_assessment': 'too short',
    'write_provenance': {'writer': 'agent-reviewer', 'commit': '$HEAD_SHA', 'package_sha256': '$PKG_SHA'}
}
with open('engine/review/evidence/T-099/AGENT-REVIEW.json','w') as f:
    json.dump(data, f)
"
rm -f engine/review/evidence/T-099/REVIEW.json

bash engine/scripts/engine-review-agent-validate.sh T-099 > /dev/null 2>&1
sh_reject_rc=$?
# Reset
$PY -c "
import json
with open('engine/review/evidence/T-099/AGENT-REVIEW.json') as f:
    data = json.load(f)
data['write_provenance'].pop('validated_by', None)
data['write_provenance'].pop('validated_at', None)
with open('engine/review/evidence/T-099/AGENT-REVIEW.json','w') as f:
    json.dump(data, f)
"
CLAUDE_PROJECT_DIR="$WIN_TMPDIR" $PS_CMD "$TMPDIR_TEST/engine/scripts/engine-review-agent-validate.ps1" T-099 > /dev/null 2>&1
ps_reject_rc=$?

assert_eq "M3: both reject shallow (exit 1)" "1|1" "$sh_reject_rc|$ps_reject_rc"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1