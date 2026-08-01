#!/usr/bin/env bash
# Engine System — Review from workstream receipt (v6.24.0, D-041/issue #29)
#
# Converts a D-009 workstream reviewer receipt into canonical REVIEW.json.
# The receipt is produced by an independent Reviewer agent in the task's
# workstream shard; this command binds it to current HEAD and writes the
# standard evidence format consumed by doctor/pre-commit/prove.
#
# Usage: engine review T-NNN --from-receipt <agent-id>
# Receipt location: engine/workstreams/T-NNN/agents/<agent-id>/REVIEW-RECEIPT.json
# Output: engine/review/evidence/T-NNN/REVIEW.json (writer=engine-review-from-receipt)
#
# Exit codes: 0=converted | 1=receipt invalid/missing | 2=usage error

set -euo pipefail
on_error() { echo "[engine-review-receipt] error on line $1 (${BASH_SOURCE[0]})" >&2; exit 1; }
trap 'on_error ${LINENO}' ERR

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
ENGINE_DIR="$ROOT/engine"
task="${1:-}"
agent_id="${2:-}"

if [ -z "$task" ] || [ -z "$agent_id" ]; then
  echo "Usage: engine review T-NNN --from-receipt <agent-id>" >&2
  echo "  Converts a workstream reviewer receipt to canonical REVIEW.json." >&2
  echo "  Receipt: engine/workstreams/T-NNN/agents/<agent-id>/REVIEW-RECEIPT.json" >&2
  exit 2
fi

# Validate task card exists
if [ ! -f "$ENGINE_DIR/tasks/$task.md" ]; then
  echo "[engine-review-receipt] Error: task card not found: $ENGINE_DIR/tasks/$task.md" >&2
  exit 2
fi

# Locate receipt
receipt_file="$ENGINE_DIR/workstreams/$task/agents/$agent_id/REVIEW-RECEIPT.json"
if [ ! -f "$receipt_file" ]; then
  echo "[engine-review-receipt] Error: receipt not found: $receipt_file" >&2
  echo "  Expected a REVIEW-RECEIPT.json in the reviewer's workstream shard." >&2
  exit 1
fi

# Extract receipt fields (grep+sed, no jq dependency)
receipt_status="$(grep -oE '"status":"[^"]*"' "$receipt_file" | head -1 | sed 's/"status":"//;s/"//')"
receipt_task="$(grep -oE '"task":"[^"]*"' "$receipt_file" | head -1 | sed 's/"task":"//;s/"//')"
receipt_reviewer="$(grep -oE '"reviewer":"[^"]*"' "$receipt_file" | head -1 | sed 's/"reviewer":"//;s/"//')"
receipt_summary="$(grep -oE '"summary":"[^"]*"' "$receipt_file" | head -1 | sed 's/"summary":"//;s/"//')"

# Validate receipt content
if [ -z "$receipt_status" ]; then
  echo "[engine-review-receipt] Error: receipt missing 'status' field" >&2
  exit 1
fi
if [ "$receipt_status" != "pass" ]; then
  echo "[engine-review-receipt] Error: receipt status='$receipt_status' (only 'pass' can be converted)" >&2
  echo "  A review receipt with findings must be resolved before conversion." >&2
  exit 1
fi
if [ -n "$receipt_task" ] && [ "$receipt_task" != "$task" ]; then
  echo "[engine-review-receipt] Error: receipt task='$receipt_task' does not match requested '$task'" >&2
  exit 1
fi

# Bind to current HEAD
head_commit="$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo "")"
if [ -z "$head_commit" ]; then
  echo "[engine-review-receipt] Error: cannot determine HEAD commit (not a git repo?)" >&2
  exit 1
fi

timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)"

# Write canonical REVIEW.json
evidence_dir="$ENGINE_DIR/review/evidence/$task"
mkdir -p "$evidence_dir"

# Use Python for safe JSON output (consistent with engine-review-pipeline.sh pattern)
PY=""
if command -v python3 >/dev/null 2>&1; then PY=python3
elif command -v python >/dev/null 2>&1; then PY=python; fi

if [ -n "$PY" ]; then
  TASK="$task" TIMESTAMP="$timestamp" HEAD_COMMIT="$head_commit" \
  AGENT_ID="$agent_id" REVIEWER="${receipt_reviewer:-$agent_id}" \
  SUMMARY="$receipt_summary" RECEIPT_PATH="engine/workstreams/$task/agents/$agent_id/REVIEW-RECEIPT.json" \
  "$PY" -c "
import json, os
data={
    'task': os.environ.get('TASK', ''),
    'timestamp': os.environ.get('TIMESTAMP', ''),
    'status': 'pass',
    'source': 'workstream-receipt',
    'receipt': {
        'agent_id': os.environ.get('AGENT_ID', ''),
        'reviewer': os.environ.get('REVIEWER', ''),
        'summary': os.environ.get('SUMMARY', ''),
        'path': os.environ.get('RECEIPT_PATH', '')
    },
    'diff': {'strategy':'receipt','base_commit':'','head_commit': os.environ.get('HEAD_COMMIT', ''), 'files_reviewed':[], 'files_skipped':[], 'diff_empty': True},
    'dimensions': {'security':{'status':'not_applicable','findings_count':{},'tool_version':''}, 'quality':{'status':'not_applicable','findings_count':{},'tool_version':''}},
    'severity_threshold': 'N/A',
    'tool_unavailable': False,
    'write_provenance':{
        'writer':'engine-review-from-receipt',
        'commit': os.environ.get('HEAD_COMMIT', ''),
        'timestamp': os.environ.get('TIMESTAMP', ''),
        'argv': 'engine review ' + os.environ.get('TASK', '') + ' --from-receipt ' + os.environ.get('AGENT_ID', ''),
        'pipeline_version':'v6.24.0'
    }
}
print(json.dumps(data,separators=(',',':')))
" > "$evidence_dir/REVIEW.json"
else
  # Fallback: minimal JSON without Python (rare; all supported platforms have python)
  printf '{"task":"%s","timestamp":"%s","status":"pass","source":"workstream-receipt","receipt":{"agent_id":"%s","reviewer":"%s","summary":"%s","path":"engine/workstreams/%s/agents/%s/REVIEW-RECEIPT.json"},"diff":{"strategy":"receipt","base_commit":"","head_commit":"%s","files_reviewed":[],"files_skipped":[],"diff_empty":true},"dimensions":{"security":{"status":"not_applicable","findings_count":{},"tool_version":""},"quality":{"status":"not_applicable","findings_count":{},"tool_version":""}},"severity_threshold":"N/A","tool_unavailable":false,"write_provenance":{"writer":"engine-review-from-receipt","commit":"%s","timestamp":"%s","argv":"engine review %s --from-receipt %s","pipeline_version":"v6.24.0"}}\n' \
    "$task" "$timestamp" "$agent_id" "${receipt_reviewer:-$agent_id}" "$receipt_summary" "$task" "$agent_id" "$head_commit" "$timestamp" "$task" "$agent_id" \
    > "$evidence_dir/REVIEW.json"
fi

echo "[engine-review-receipt] $task: converted receipt from $agent_id -> $evidence_dir/REVIEW.json"
echo "[engine-review-receipt] writer=engine-review-from-receipt commit=$head_commit"
