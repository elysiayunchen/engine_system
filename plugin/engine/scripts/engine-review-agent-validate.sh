#!/usr/bin/env bash
# Engine System — Agent-Reviewer Validate(v6.22.0)
#
# Phase 3: 校验外部 agent 产出的 AGENT-REVIEW.json
#
# 校验层:schema 完整性(E_SCHEMA) → 反橡皮图章(E_SHALLOW) → provenance(E_PROVENANCE)
#        → staleness(E_STALE, WARN) → 更新 REVIEW.json + manifest hash
#
# 用法:bash engine/scripts/engine-review-agent-validate.sh T-NNN
# 安全:只写 engine/review/evidence/T-NNN/(AGENT-REVIEW.json 追加 validated_by + REVIEW.json 更新)

set -euo pipefail
on_error() { echo "[engine-review-agent-validate] error on line $1 (${BASH_SOURCE[0]})" >&2; exit 1; }
trap 'on_error ${LINENO}' ERR

# python3 检测
if command -v python3 >/dev/null 2>&1; then
  PY=python3
elif command -v python >/dev/null 2>&1; then
  PY=python
else
  echo "[engine-review-agent-validate] Error: python3/python not found" >&2
  exit 2
fi

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
ENGINE_DIR="$ROOT/engine"
task="${1:-}"

if [ -z "$task" ]; then
  echo "[engine-review-agent-validate] Usage: engine-review-agent-validate T-NNN" >&2
  exit 2
fi

evidence_dir="$ENGINE_DIR/review/evidence/$task"
review_file="$evidence_dir/AGENT-REVIEW.json"
package_file="$evidence_dir/review-package.md"

# === 0. flock ===
mkdir -p "$ENGINE_DIR/review"
if command -v flock >/dev/null 2>&1; then
  exec 200>"$ENGINE_DIR/review/.review-agent-lock.$task"
  if ! flock -n 200; then
    echo "[engine-review-agent-validate] another review-agent running for $task" >&2
    exit 1
  fi
else
  lockdir="$ENGINE_DIR/review/.review-agent-lock.$task.d"
  if ! mkdir "$lockdir" 2>/dev/null; then
    echo "[engine-review-agent-validate] another review-agent running for $task" >&2
    exit 1
  fi
  trap 'rmdir "$lockdir" 2>/dev/null' EXIT
fi

# === 1. E_MISSING: AGENT-REVIEW.json 存在性 ===
if [ ! -f "$review_file" ]; then
  echo "[engine-review-agent-validate] FAIL E_MISSING: $review_file not found" >&2
  echo "  The external agent must write AGENT-REVIEW.json before validation." >&2
  exit 1
fi

# === 2-5. 全部校验逻辑在 python 中完成(结构化 JSON 解析) ===
# 读配置(路径通过环境变量传递,避免 MSYS 路径转换问题)
config_file="$ENGINE_DIR/review/config.json"
min_entries=$(CONFIG_FILE="$config_file" "$PY" -c "
import json, os
try:
    with open(os.environ['CONFIG_FILE']) as f: cfg = json.load(f)
except: cfg = {}
ar = cfg.get('defaults',{}).get('agent_review',{})
ar_ov = cfg.get('overrides',{}).get('agent_review',{})
if isinstance(ar_ov, dict): ar = {**ar, **ar_ov}
print(ar.get('min_entries_per_dimension', 1))
" 2>/dev/null || echo 1)

min_narrative=$(CONFIG_FILE="$config_file" "$PY" -c "
import json, os
try:
    with open(os.environ['CONFIG_FILE']) as f: cfg = json.load(f)
except: cfg = {}
ar = cfg.get('defaults',{}).get('agent_review',{})
ar_ov = cfg.get('overrides',{}).get('agent_review',{})
if isinstance(ar_ov, dict): ar = {**ar, **ar_ov}
print(ar.get('min_narrative_chars', 200))
" 2>/dev/null || echo 200)

min_message=$(CONFIG_FILE="$config_file" "$PY" -c "
import json, os
try:
    with open(os.environ['CONFIG_FILE']) as f: cfg = json.load(f)
except: cfg = {}
ar = cfg.get('defaults',{}).get('agent_review',{})
ar_ov = cfg.get('overrides',{}).get('agent_review',{})
if isinstance(ar_ov, dict): ar = {**ar, **ar_ov}
print(ar.get('min_entry_message_chars', 20))
" 2>/dev/null || echo 20)

max_age_hours=$(CONFIG_FILE="$config_file" "$PY" -c "
import json, os
try:
    with open(os.environ['CONFIG_FILE']) as f: cfg = json.load(f)
except: cfg = {}
ar = cfg.get('defaults',{}).get('agent_review',{})
ar_ov = cfg.get('overrides',{}).get('agent_review',{})
if isinstance(ar_ov, dict): ar = {**ar, **ar_ov}
print(ar.get('max_package_age_hours', 72))
" 2>/dev/null || echo 72)

# 主校验(python 一次性完成所有层)
VALIDATE_RESULT=$(REVIEW_FILE="$review_file" PACKAGE_FILE="$package_file" \
  MIN_ENTRIES="$min_entries" MIN_NARRATIVE="$min_narrative" \
  MIN_MESSAGE="$min_message" MAX_AGE_HOURS="$max_age_hours" \
  TASK="$task" ROOT_DIR="$ROOT" \
"$PY" << 'PYEOF'
import json, os, sys, hashlib
from datetime import datetime, timezone

review_file = os.environ['REVIEW_FILE']
package_file = os.environ['PACKAGE_FILE']
min_entries = int(os.environ.get('MIN_ENTRIES', '1'))
min_narrative = int(os.environ.get('MIN_NARRATIVE', '200'))
min_message = int(os.environ.get('MIN_MESSAGE', '20'))
max_age_hours = int(os.environ.get('MAX_AGE_HOURS', '72'))
task = os.environ.get('TASK', '')

errors = []  # (code, message)
warnings = []

# --- E_SCHEMA: parse + required fields ---
try:
    with open(review_file, encoding='utf-8') as f:
        data = json.load(f)
except json.JSONDecodeError as e:
    print(f"E_SCHEMA|invalid JSON: {e}")
    sys.exit(1)
except Exception as e:
    print(f"E_SCHEMA|cannot read file: {e}")
    sys.exit(1)

# Required top-level fields
for field in ['task', 'timestamp', 'status', 'dimensions', 'adversarial_responses', 'overall_assessment', 'write_provenance']:
    if field not in data:
        errors.append(('E_SCHEMA', f'missing required field: {field}'))

if errors:
    for code, msg in errors:
        print(f"{code}|{msg}")
    sys.exit(1)

# Status validation
if data.get('status') not in ('pass', 'concerns', 'block'):
    errors.append(('E_SCHEMA', f'invalid status: {data.get("status")} (must be pass|concerns|block)'))

# Dimensions: all 5 required
required_dims = ['correctness', 'design', 'consistency', 'readability', 'completeness']
dims = data.get('dimensions', {})
for dim in required_dims:
    if dim not in dims:
        errors.append(('E_SCHEMA', f'missing dimension: {dim}'))
    else:
        dim_data = dims[dim]
        if 'entries' not in dim_data:
            errors.append(('E_SCHEMA', f'dimension {dim}: missing entries array'))
        elif not isinstance(dim_data['entries'], list):
            errors.append(('E_SCHEMA', f'dimension {dim}: entries must be array'))
        if 'summary' not in dim_data or not dim_data.get('summary'):
            errors.append(('E_SCHEMA', f'dimension {dim}: missing summary'))

# Entry fields
for dim in required_dims:
    if dim not in dims:
        continue
    for i, entry in enumerate(dims.get(dim, {}).get('entries', [])):
        for field in ['id', 'severity', 'type', 'file', 'line', 'message']:
            if field not in entry:
                errors.append(('E_SCHEMA', f'{dim}.entries[{i}]: missing field {field}'))
        if 'severity' in entry and entry['severity'] not in ('critical', 'high', 'medium', 'low', 'info'):
            errors.append(('E_SCHEMA', f'{dim}.entries[{i}]: invalid severity {entry["severity"]}'))
        if 'type' in entry and entry['type'] not in ('finding', 'strength'):
            errors.append(('E_SCHEMA', f'{dim}.entries[{i}]: invalid type {entry["type"]}'))

# Adversarial responses
ar = data.get('adversarial_responses', [])
if not isinstance(ar, list) or len(ar) != 3:
    errors.append(('E_SCHEMA', f'adversarial_responses must have exactly 3 entries (got {len(ar) if isinstance(ar, list) else "non-array"})'))
else:
    for i, resp in enumerate(ar):
        if 'challenge' not in resp or 'response' not in resp:
            errors.append(('E_SCHEMA', f'adversarial_responses[{i}]: missing challenge or response'))

# Provenance fields
prov = data.get('write_provenance', {})
for field in ['writer', 'commit', 'package_sha256']:
    if field not in prov:
        errors.append(('E_SCHEMA', f'write_provenance: missing {field}'))

if errors:
    for code, msg in errors:
        print(f"{code}|{msg}")
    sys.exit(1)

# --- E_SHALLOW: anti-rubber-stamp ---
shallow_errors = []

# 1. min entries per dimension
for dim in required_dims:
    entries = dims.get(dim, {}).get('entries', [])
    if len(entries) < min_entries:
        shallow_errors.append(f'dimension {dim} has {len(entries)} entries (minimum {min_entries})')

# 2. message length
for dim in required_dims:
    for i, entry in enumerate(dims.get(dim, {}).get('entries', [])):
        msg = entry.get('message', '')
        if len(msg) < min_message:
            shallow_errors.append(f'{dim}.entries[{i}] message too terse ({len(msg)} < {min_message})')

# 3. narrative total chars
narrative_total = len(data.get('overall_assessment', ''))
for dim in required_dims:
    narrative_total += len(dims.get(dim, {}).get('summary', ''))
if narrative_total < min_narrative:
    shallow_errors.append(f'narrative too shallow ({narrative_total} chars < {min_narrative} minimum)')

# 4. adversarial response length
for i, resp in enumerate(ar):
    r = resp.get('response', '')
    if len(r) < 30:
        shallow_errors.append(f'adversarial_responses[{i}] response too short ({len(r)} < 30)')

if shallow_errors:
    for msg in shallow_errors:
        print(f"E_SHALLOW|{msg}")
    sys.exit(1)

# --- E_GROUNDED (v6.22.0): verify finding file:line references exist ---
grounded_errors = []
grounded_warnings = []
total_findings_for_grounding = 0
ungrounded_count = 0

root_dir = os.environ.get('ROOT_DIR', '.')
for dim in required_dims:
    for i, entry in enumerate(dims.get(dim, {}).get('entries', [])):
        if entry.get('type') != 'finding':
            continue
        total_findings_for_grounding += 1
        fpath = entry.get('file', '')
        fline = entry.get('line', 0)
        if not fpath or not fline:
            continue
        # check file exists
        full_path = os.path.join(root_dir, fpath)
        if not os.path.isfile(full_path):
            ungrounded_count += 1
            grounded_errors.append(f'{dim}.entries[{i}] references non-existent file: {fpath}')
            continue
        # check line number within file
        try:
            with open(full_path, encoding='utf-8', errors='replace') as ff:
                line_count = sum(1 for _ in ff)
            if fline > line_count:
                ungrounded_count += 1
                grounded_errors.append(f'{dim}.entries[{i}] line {fline} exceeds file length ({line_count} lines): {fpath}')
        except Exception:
            pass

if total_findings_for_grounding > 0 and ungrounded_count > 0:
    ratio = ungrounded_count / total_findings_for_grounding
    if ratio > 0.5:
        for msg in grounded_errors:
            print(f"E_GROUNDED|{msg}")
        sys.exit(1)
    else:
        for msg in grounded_errors:
            grounded_warnings.append(msg)

# --- E_PROVENANCE ---
prov_errors = []

# writer
if prov.get('writer') != 'agent-reviewer':
    prov_errors.append(f'invalid writer: {prov.get("writer")} (must be agent-reviewer)')

# package_sha256 (normalize: replace sha line with COMPUTE before hashing)
if os.path.isfile(package_file):
    import re
    with open(package_file, encoding='utf-8', newline='') as f:
        pkg_content = f.read()
    normalized = re.sub(r'(> package_sha256: ).*', r'\1COMPUTE', pkg_content, count=1)
    actual_sha = hashlib.sha256(normalized.encode('utf-8')).hexdigest()
    if prov.get('package_sha256') != actual_sha:
        prov_errors.append(f'package_sha256 mismatch (review based on different package)')
else:
    prov_errors.append('review-package.md not found (cannot verify provenance)')

# commit echo check (compare with package header)
if os.path.isfile(package_file):
    with open(package_file, encoding='utf-8', newline='') as f:
        for line in f:
            if line.startswith('> head_commit:'):
                pkg_head = line.split(':', 1)[1].strip()
                if prov.get('commit') != pkg_head:
                    prov_errors.append(f'commit mismatch: agent wrote {prov.get("commit")} but package has {pkg_head}')
                break

if prov_errors:
    for msg in prov_errors:
        print(f"E_PROVENANCE|{msg}")
    sys.exit(1)

# --- E_STALE (WARN only, uses embedded timestamp from package header) ---
if os.path.isfile(package_file):
    pkg_generated = None
    with open(package_file, encoding='utf-8', newline='') as f:
        for line in f:
            if line.startswith('> generated:'):
                pkg_generated = line.split(':', 1)[1].strip()
                break
    if pkg_generated:
        try:
            gen_time = datetime.strptime(pkg_generated, '%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=timezone.utc)
            age_hours = (datetime.now(timezone.utc) - gen_time).total_seconds() / 3600
            if age_hours > max_age_hours:
                warnings.append(f'package is {int(age_hours)} hours old (>{max_age_hours}h), consider regenerating')
        except ValueError:
            warnings.append('cannot parse package generated timestamp')

# --- E_INDEPENDENCE (v6.22.0, FAIL): reviewer_session must differ from packaged_by ---
if os.path.isfile(package_file):
    pkg_packaged_by = None
    with open(package_file, encoding='utf-8', newline='') as f:
        for line in f:
            if line.startswith('> packaged_by:'):
                pkg_packaged_by = line.split(':', 1)[1].strip()
                break
    reviewer_session = prov.get('reviewer_session', '')
    if not reviewer_session:
        print('E_INDEPENDENCE|reviewer_session missing in write_provenance (subagent review is mandatory)')
        sys.exit(1)
    elif pkg_packaged_by and reviewer_session == pkg_packaged_by:
        print(f'E_INDEPENDENCE|reviewer_session matches packaged_by ({reviewer_session}) — reviewer must be a separate agent/session')
        sys.exit(1)

# merge grounded warnings
warnings.extend(grounded_warnings)

# --- Output summary ---
total_findings = sum(
    len([e for e in dims.get(d, {}).get('entries', []) if e.get('type') == 'finding'])
    for d in required_dims
)
total_strengths = sum(
    len([e for e in dims.get(d, {}).get('entries', []) if e.get('type') == 'strength'])
    for d in required_dims
)
status = data.get('status', 'pass')

for w in warnings:
    print(f"WARN|{w}")
print(f"OK|{status}|{total_findings}|{total_strengths}")
sys.exit(0)
PYEOF
) || {
  # python 输出了错误码|消息 到 stdout
  echo "$VALIDATE_RESULT" | while IFS='|' read -r code msg; do
    echo "[engine-review-agent-validate] FAIL $code: $msg" >&2
  done
  exit 1
}

# 解析结果
validate_status=""
validate_findings=0
validate_strengths=0
while IFS='|' read -r code msg; do
  case "$code" in
    WARN) echo "[engine-review-agent-validate] WARN: $msg" >&2 ;;
    OK)
      validate_status=$(echo "$msg" | cut -d'|' -f1)
      validate_findings=$(echo "$msg" | cut -d'|' -f2)
      validate_strengths=$(echo "$msg" | cut -d'|' -f3)
      ;;
  esac
done <<< "$VALIDATE_RESULT"

# === 6-8. 追加 validated_by + 更新 REVIEW.json + 重算 manifest hash ===
# 全部路径通过环境变量传递(避免 MSYS 路径转换问题)
review_json="$evidence_dir/REVIEW.json"
validated_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
head_commit="$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"

REVIEW_FILE="$review_file" REVIEW_JSON="$review_json" EVIDENCE_DIR="$evidence_dir" \
  TASK="$task" VALIDATED_AT="$validated_at" HEAD_COMMIT="$head_commit" \
"$PY" << 'PYEOF'
import json, os, hashlib
from datetime import datetime, timezone

review_file = os.environ['REVIEW_FILE']
review_json = os.environ['REVIEW_JSON']
evidence_dir = os.environ['EVIDENCE_DIR']
task = os.environ['TASK']
validated_at = os.environ['VALIDATED_AT']
head_commit = os.environ['HEAD_COMMIT']

# --- 6. 追加 validated_by 到 AGENT-REVIEW.json ---
with open(review_file, encoding='utf-8') as f:
    data = json.load(f)
data['write_provenance']['validated_by'] = f'engine review-agent {task} --validate'
data['write_provenance']['validated_at'] = validated_at
with open(review_file, 'w', encoding='utf-8') as f:
    json.dump(data, f, separators=(',',':'), ensure_ascii=False)
    f.write('\n')

# --- 7. 更新 REVIEW.json(追加 agent_review 维度) ---
agent_status = data.get('status', 'pass')
dims = data.get('dimensions', {})
counts = {'critical':0,'high':0,'medium':0,'low':0,'info':0}
for d in dims.values():
    for e in d.get('entries', []):
        sev = e.get('severity', 'info')
        counts[sev] = counts.get(sev, 0) + 1

if os.path.isfile(review_json):
    with open(review_json, encoding='utf-8') as f:
        review = json.load(f)
    review.setdefault('dimensions', {})['agent_review'] = {
        'status': agent_status,
        'findings_count': counts,
        'protocol_version': 'v6.22.0'
    }
    if agent_status == 'block':
        review['status'] = 'block'
else:
    review = {
        'task': task,
        'timestamp': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
        'status': agent_status,
        'dimensions': {
            'agent_review': {
                'status': agent_status,
                'findings_count': counts,
                'protocol_version': 'v6.22.0'
            }
        },
        'write_provenance': {
            'writer': 'engine-review-agent-validate',
            'commit': head_commit,
            'timestamp': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
            'argv': f'engine review-agent {task} --validate',
            'pipeline_version': 'v6.22.0'
        }
    }

# --- 8. 重算 evidence_manifest_sha256 ---
files = sorted([f for f in os.listdir(evidence_dir) if f.endswith('.json') and f != 'REVIEW.json'])
h = hashlib.sha256()
for fname in files:
    with open(os.path.join(evidence_dir, fname), 'rb') as fp:
        h.update(fp.read())
pkg = os.path.join(evidence_dir, 'review-package.md')
if os.path.isfile(pkg):
    with open(pkg, 'rb') as fp:
        h.update(fp.read())
review['evidence_manifest_sha256'] = h.hexdigest()

with open(review_json, 'w', encoding='utf-8') as f:
    json.dump(review, f, separators=(',',':'), ensure_ascii=False)
    f.write('\n')
PYEOF

# === 9. 输出结果 ===
echo "[engine-review-agent-validate] $task: AGENT REVIEW ${validate_status^^} ($validate_findings findings, $validate_strengths strengths)"
exit 0
