#!/usr/bin/env bash
# Test: engine review-agent --validate (T-071 AC-8,9,10,11,12)
# AC-8: 缺 AGENT-REVIEW.json → exit 1 E_MISSING
# AC-9: schema 不完整 → exit 1 E_SCHEMA
# AC-10: 反橡皮图章不达标 → exit 1 E_SHALLOW
# AC-11: package_sha256 不匹配 → exit 1 E_PROVENANCE
# AC-12: 通过 → 更新 REVIEW.json + manifest hash

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

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

echo "=== test_review_agent_validate.sh ==="

# Setup temp repo
TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT
cd "$TMPDIR_TEST"
git init -q
mkdir -p engine/tasks engine/scripts engine/review/evidence/T-096

cp "$ROOT/engine/scripts/engine-review-agent-validate.sh" engine/scripts/
cp "$ROOT/engine/review/config.json" engine/review/

# Enable agent_review
python3 -c "
import json
with open('engine/review/config.json') as f: cfg = json.load(f)
cfg['defaults']['agent_review']['enabled'] = True
with open('engine/review/config.json','w') as f: json.dump(cfg, f, indent=2)
" 2>/dev/null || python -c "
import json
with open('engine/review/config.json') as f: cfg = json.load(f)
cfg['defaults']['agent_review']['enabled'] = True
with open('engine/review/config.json','w') as f: json.dump(cfg, f, indent=2)
"

cat > engine/tasks/T-096.md << 'EOF'
# T-096: Validate test
> status: active
GOAL: Test validate
## WRITE-SET
- test.sh
AC: AC-1 | verify: echo ok
EOF
echo 'echo hi' > test.sh
git add -A && git commit -q -m "init"

# Create a review-package.md (needed for provenance check)
PKG="engine/review/evidence/T-096/review-package.md"
cat > "$PKG" << EOF
# Code Review Package: T-096

> generated: 2026-07-31T12:00:00Z
> package_sha256: PLACEHOLDER
> head_commit: $(git rev-parse HEAD)
> task: Test validate
EOF
# Compute sha256 using normalization (replace sha line with COMPUTE)
if command -v python3 >/dev/null 2>&1; then PY=python3; else PY=python; fi
final_sha=$($PY -c "
import hashlib, re
p = '$PKG'
with open(p, encoding='utf-8', newline='') as f:
    content = f.read()
# normalize: replace sha line value with COMPUTE (first occurrence only)
normalized = re.sub(r'(> package_sha256: ).*', r'\1COMPUTE', content, count=1)
sha = hashlib.sha256(normalized.encode('utf-8')).hexdigest()
# write final file with actual sha
content = content.replace('package_sha256: PLACEHOLDER', f'package_sha256: {sha}', 1)
with open(p, 'w', encoding='utf-8', newline='') as f:
    f.write(content)
print(sha)
")

HEAD_SHA=$(git rev-parse HEAD)

# S1: AC-8 — missing AGENT-REVIEW.json
output=$(bash engine/scripts/engine-review-agent-validate.sh T-096 2>&1); rc=$?
assert_exit "S1: missing file exit 1" 1 $rc
assert_output_contains "S1: E_MISSING" "$output" "E_MISSING"

# S2: AC-9 — invalid schema (missing fields)
echo '{"task":"T-096"}' > engine/review/evidence/T-096/AGENT-REVIEW.json
output=$(bash engine/scripts/engine-review-agent-validate.sh T-096 2>&1); rc=$?
assert_exit "S2: incomplete schema exit 1" 1 $rc
assert_output_contains "S2: E_SCHEMA" "$output" "E_SCHEMA"

# S3: AC-9 — invalid JSON
echo 'not json at all' > engine/review/evidence/T-096/AGENT-REVIEW.json
output=$(bash engine/scripts/engine-review-agent-validate.sh T-096 2>&1); rc=$?
assert_exit "S3: invalid JSON exit 1" 1 $rc
assert_output_contains "S3: E_SCHEMA" "$output" "E_SCHEMA"

# S4: AC-10 — shallow review (valid schema but too short)
$PY -c "
import json
data = {
    'task': 'T-096', 'timestamp': '2026-07-31T12:00:00Z', 'status': 'pass',
    'dimensions': {
        'correctness': {'entries': [{'id':'agent-correctness-test.sh:1','severity':'info','type':'strength','file':'test.sh','line':1,'message':'ok'}], 'summary': 'ok'},
        'design': {'entries': [{'id':'agent-design-test.sh:1','severity':'info','type':'strength','file':'test.sh','line':1,'message':'ok'}], 'summary': 'ok'},
        'consistency': {'entries': [{'id':'agent-consistency-test.sh:1','severity':'info','type':'strength','file':'test.sh','line':1,'message':'ok'}], 'summary': 'ok'},
        'readability': {'entries': [{'id':'agent-readability-test.sh:1','severity':'info','type':'strength','file':'test.sh','line':1,'message':'ok'}], 'summary': 'ok'},
        'completeness': {'entries': [{'id':'agent-completeness-test.sh:1','severity':'info','type':'strength','file':'test.sh','line':1,'message':'ok'}], 'summary': 'ok'}
    },
    'adversarial_responses': [
        {'challenge': 'q1', 'response': 'short'},
        {'challenge': 'q2', 'response': 'short'},
        {'challenge': 'q3', 'response': 'short'}
    ],
    'overall_assessment': 'too short',
    'write_provenance': {'writer': 'agent-reviewer', 'commit': '$HEAD_SHA', 'package_sha256': '$final_sha'}
}
with open('engine/review/evidence/T-096/AGENT-REVIEW.json','w') as f:
    json.dump(data, f)
"
output=$(bash engine/scripts/engine-review-agent-validate.sh T-096 2>&1); rc=$?
assert_exit "S4: shallow review exit 1" 1 $rc
assert_output_contains "S4: E_SHALLOW" "$output" "E_SHALLOW"

# S5: AC-11 — provenance mismatch (wrong package_sha256)
$PY -c "
import json
data = {
    'task': 'T-096', 'timestamp': '2026-07-31T12:00:00Z', 'status': 'pass',
    'dimensions': {
        'correctness': {'entries': [{'id':'agent-correctness-test.sh:1','severity':'info','type':'strength','file':'test.sh','line':1,'message':'This is a sufficiently long message for testing'}], 'summary': 'The correctness of this simple script is adequate for its purpose.'},
        'design': {'entries': [{'id':'agent-design-test.sh:1','severity':'info','type':'strength','file':'test.sh','line':1,'message':'The design is minimal and appropriate for the task'}], 'summary': 'Design is simple and fit for purpose.'},
        'consistency': {'entries': [{'id':'agent-consistency-test.sh:1','severity':'info','type':'strength','file':'test.sh','line':1,'message':'No cross-file consistency issues detected here'}], 'summary': 'No consistency issues found in this change.'},
        'readability': {'entries': [{'id':'agent-readability-test.sh:1','severity':'info','type':'strength','file':'test.sh','line':1,'message':'The code is clear and easy to understand'}], 'summary': 'Code is readable and straightforward.'},
        'completeness': {'entries': [{'id':'agent-completeness-test.sh:1','severity':'info','type':'strength','file':'test.sh','line':1,'message':'All necessary components are present'}], 'summary': 'The implementation is complete for scope.'}
    },
    'adversarial_responses': [
        {'challenge': 'q1', 'response': 'Empty input would cause the echo to output nothing, which is safe behavior.'},
        {'challenge': 'q2', 'response': 'No other files depend on this script so no assumptions are broken.'},
        {'challenge': 'q3', 'response': 'The simplicity means there is very little comprehension barrier.'}
    ],
    'overall_assessment': 'This is a very simple script that echoes a greeting. No significant issues found during review.',
    'write_provenance': {'writer': 'agent-reviewer', 'commit': '$HEAD_SHA', 'package_sha256': 'wrong_hash_value'}
}
with open('engine/review/evidence/T-096/AGENT-REVIEW.json','w') as f:
    json.dump(data, f)
"
output=$(bash engine/scripts/engine-review-agent-validate.sh T-096 2>&1); rc=$?
assert_exit "S5: provenance mismatch exit 1" 1 $rc
assert_output_contains "S5: E_PROVENANCE" "$output" "E_PROVENANCE"

# S6: AC-12 — valid review passes + updates REVIEW.json
$PY -c "
import json
data = {
    'task': 'T-096', 'timestamp': '2026-07-31T12:00:00Z', 'status': 'pass',
    'dimensions': {
        'correctness': {'entries': [{'id':'agent-correctness-test.sh:1','severity':'info','type':'strength','file':'test.sh','line':1,'message':'This is a sufficiently long message for testing'}], 'summary': 'The correctness of this simple script is adequate for its purpose.'},
        'design': {'entries': [{'id':'agent-design-test.sh:1','severity':'info','type':'strength','file':'test.sh','line':1,'message':'The design is minimal and appropriate for the task'}], 'summary': 'Design is simple and fit for purpose.'},
        'consistency': {'entries': [{'id':'agent-consistency-test.sh:1','severity':'info','type':'strength','file':'test.sh','line':1,'message':'No cross-file consistency issues detected here'}], 'summary': 'No consistency issues found in this change.'},
        'readability': {'entries': [{'id':'agent-readability-test.sh:1','severity':'info','type':'strength','file':'test.sh','line':1,'message':'The code is clear and easy to understand'}], 'summary': 'Code is readable and straightforward.'},
        'completeness': {'entries': [{'id':'agent-completeness-test.sh:1','severity':'info','type':'strength','file':'test.sh','line':1,'message':'All necessary components are present'}], 'summary': 'The implementation is complete for scope.'}
    },
    'adversarial_responses': [
        {'challenge': 'q1', 'response': 'Empty input would cause the echo to output nothing, which is safe behavior.'},
        {'challenge': 'q2', 'response': 'No other files depend on this script so no assumptions are broken.'},
        {'challenge': 'q3', 'response': 'The simplicity means there is very little comprehension barrier.'}
    ],
    'overall_assessment': 'This is a very simple script that echoes a greeting. No significant issues found during review.',
    'write_provenance': {'writer': 'agent-reviewer', 'commit': '$HEAD_SHA', 'package_sha256': '$final_sha', 'reviewer_session': 'test-reviewer-session'}
}
with open('engine/review/evidence/T-096/AGENT-REVIEW.json','w') as f:
    json.dump(data, f)
"
output=$(bash engine/scripts/engine-review-agent-validate.sh T-096 2>&1); rc=$?
assert_exit "S6: valid review exit 0" 0 $rc
assert_output_contains "S6: PASS in output" "$output" "PASS"

# Check REVIEW.json was created/updated
if [ -f "engine/review/evidence/T-096/REVIEW.json" ]; then
  PASS=$((PASS+1)); echo "  PASS: S6: REVIEW.json exists"
  if grep -q "agent_review" "engine/review/evidence/T-096/REVIEW.json"; then
    PASS=$((PASS+1)); echo "  PASS: S6: REVIEW.json has agent_review dimension"
  else
    FAIL=$((FAIL+1)); echo "  FAIL: S6: REVIEW.json missing agent_review"
  fi
  if grep -q "evidence_manifest_sha256" "engine/review/evidence/T-096/REVIEW.json"; then
    PASS=$((PASS+1)); echo "  PASS: S6: REVIEW.json has manifest hash"
  else
    FAIL=$((FAIL+1)); echo "  FAIL: S6: REVIEW.json missing manifest hash"
  fi
else
  FAIL=$((FAIL+1)); echo "  FAIL: S6: REVIEW.json not created"
fi

# Check validated_by was appended
if grep -q "validated_by" "engine/review/evidence/T-096/AGENT-REVIEW.json"; then
  PASS=$((PASS+1)); echo "  PASS: S6: validated_by appended"
else
  FAIL=$((FAIL+1)); echo "  FAIL: S6: validated_by not appended"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
