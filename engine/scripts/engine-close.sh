#!/usr/bin/env bash
# Engine System — agent-neutral lifecycle closure.
#
# Runs the public CLI in the canonical order (verify -> gate -> doctor), then
# records the closure audit. A worker may close into its own workstream shard;
# only a coordinator may claim the final shared-memory/capsule closure.

set -u -o pipefail

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
ENGINE_DIR="$ROOT/engine"
task="${1:-}"
shift || true
handoff_agent="${ENGINE_AGENT_ID:-}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --handoff)
      shift
      handoff_agent="${1:-}"
      ;;
    --handoff=*) handoff_agent="${1#--handoff=}" ;;
    *)
      echo "[engine-close] Unknown argument: $1" >&2
      echo "Usage: engine close T-NNN [--handoff AGENT]" >&2
      exit 2
      ;;
  esac
  shift
done

if [[ ! "$task" =~ ^T-[0-9]+$ ]]; then
  echo "[engine-close] Usage: engine close T-NNN [--handoff AGENT]" >&2
  exit 2
fi

task_file="$ENGINE_DIR/tasks/$task.md"
cli="$ROOT/engine/bin/engine"
if [ ! -f "$task_file" ]; then
  echo "[engine-close] task card not found: $task_file" >&2
  exit 2
fi
if [ ! -f "$cli" ]; then
  echo "[engine-close] public CLI not found: $cli" >&2
  exit 2
fi

mkdir -p "$ENGINE_DIR/evidence/$task"
timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)"
head_commit="$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
close_argv="${ENGINE_CLI_ENTRYPOINT:-engine-close.sh $task}"

run_stage() {
  local label="$1"
  shift
  local tmp rc
  tmp="$(mktemp)"
  echo "[engine-close] running: $label"
  "$@" 2>&1 | tee "$tmp"
  rc="${PIPESTATUS[0]}"
  printf -v "${label}_rc" '%s' "$rc"
  rm -f "$tmp"
}

verify_rc=0
gate_rc=0
doctor_rc=0
run_stage verify bash "$cli" verify "$task"
run_stage gate bash "$cli" gate "$task"
run_stage doctor bash "$cli" doctor

memory_mode="single-session"
memory_status="pass"
handoff_path=""
lock_file="$ENGINE_DIR/.cache/session.lock"
current_sid="${ENGINE_SESSION_ID:-${CLAUDE_SESSION_ID:-}}"
if [ -f "$lock_file" ]; then
  lock_line="$(cat "$lock_file" 2>/dev/null || true)"
  lock_sid="$(printf '%s' "$lock_line" | cut -d'|' -f2)"
  lock_role="$(printf '%s' "$lock_line" | cut -d'|' -f3)"
  if [ "$lock_role" = "coordinator" ] && [ -n "$current_sid" ] && [ "$current_sid" = "$lock_sid" ]; then
    memory_mode="coordinator"
    if [ ! -f "$ENGINE_DIR/CONTEXT.md" ] || [ ! -f "$ENGINE_DIR/HANDOFF.md" ] || \
       ! grep -q "$task" "$ENGINE_DIR/CONTEXT.md" 2>/dev/null || \
       ! grep -q "$task" "$ENGINE_DIR/HANDOFF.md" 2>/dev/null; then
      memory_status="block"
      echo "[engine-close] coordinator memory is not linked to $task; update CONTEXT.md/HANDOFF.md" >&2
    fi
  else
    memory_mode="worker"
    if [ -z "$handoff_agent" ] || [[ ! "$handoff_agent" =~ ^[A-Za-z0-9._-]+$ ]]; then
      memory_status="block"
      echo "[engine-close] worker closure requires --handoff AGENT (writes only that workstream shard)" >&2
    else
      bash "$cli" workstream "$task" "$handoff_agent" --kind=session >/dev/null 2>&1 || memory_status="block"
      shard_dir="$ENGINE_DIR/workstreams/$task/sessions/s-$handoff_agent"
      handoff_path="engine/workstreams/$task/sessions/s-$handoff_agent/HANDOFF.md"
      if [ "$memory_status" = "pass" ] && [ -f "$shard_dir/HANDOFF.md" ]; then
        printf '\n## Closure audit (%s)\n\n- verify exit: %s\n- gate exit: %s\n- doctor exit: %s\n- coordinator merge: pending\n' \
          "$timestamp" "$verify_rc" "$gate_rc" "$doctor_rc" >> "$shard_dir/HANDOFF.md"
      else
        memory_status="block"
      fi
    fi
  fi
else
  context_file="$ENGINE_DIR/CONTEXT.md"
  handoff_file="$ENGINE_DIR/HANDOFF.md"
  if [ ! -f "$context_file" ] || [ ! -f "$handoff_file" ] || \
     ! grep -q "$task" "$context_file" 2>/dev/null || \
     ! grep -q "$task" "$handoff_file" 2>/dev/null; then
    memory_status="block"
    echo "[engine-close] single-session memory is not linked to $task; update CONTEXT.md/HANDOFF.md" >&2
  fi
fi

# A code task needs a task-linked capsule. Workers report this as deferred: the
# coordinator owns engine/changes and must perform the final close after merge.
capsule_status="not_required"
capsule_path=""
write_set_code=0
while IFS= read -r write_path; do
  if [[ "$write_path" =~ \.(sh|ps1|py|js|ts|go|rs|java|c|cpp|rb|php)$ ]]; then
    write_set_code=1
    break
  fi
done < <(awk '
  /^##[[:space:]]+WRITE-SET[[:space:]]*$/ { on=1; next }
  on && /^##[[:space:]]+/ { on=0 }
  on && /^-[[:space:]]+/ { sub(/^-[[:space:]]+/, ""); print }
' "$task_file" 2>/dev/null)
if [ "$write_set_code" -eq 1 ]; then
  capsule_status="block"
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    if grep -q "$task" "$f" 2>/dev/null; then
      capsule_status="pass"
      capsule_path="${f#"$ROOT/"}"
      break
    fi
  done < <(find "$ENGINE_DIR/changes" -maxdepth 1 -type f -name 'CHANGE-*.md' 2>/dev/null)
  if [ "$memory_mode" = "worker" ] && [ "$memory_status" = "pass" ]; then
    capsule_status="deferred_to_coordinator"
  elif [ "$capsule_status" = "block" ]; then
    echo "[engine-close] no task-linked change capsule found for $task" >&2
  fi
fi

status="pass"
if [ "$verify_rc" -ne 0 ] || [ "$gate_rc" -ne 0 ] || [ "$doctor_rc" -ne 0 ] || [ "$memory_status" = "block" ] || [ "$capsule_status" = "block" ]; then
  status="block"
elif [ "$memory_mode" = "worker" ]; then
  status="handoff"
fi

py=""
if command -v python3 >/dev/null 2>&1; then py=python3
elif command -v python >/dev/null 2>&1; then py=python
fi
out="$ENGINE_DIR/evidence/$task/CLOSE.json"
if [ -n "$py" ]; then
  "$py" - "$out" "$task" "$timestamp" "$status" "$head_commit" "$close_argv" \
    "$verify_rc" "$gate_rc" "$doctor_rc" "$memory_mode" "$memory_status" "$handoff_agent" \
    "$handoff_path" "$capsule_status" "$capsule_path" <<'PY'
import json, sys

(out, task, timestamp, status, commit, argv, verify_rc, gate_rc, doctor_rc,
 memory_mode, memory_status, handoff_agent, handoff_path, capsule_status,
 capsule_path) = sys.argv[1:]

def stage(rc):
    rc = int(rc)
    return {'status': 'pass' if rc == 0 else 'fail', 'exit': rc}

data = {
    'task': task,
    'timestamp': timestamp,
    'status': status,
    'stages': {
        'verify': stage(verify_rc),
        'gate': stage(gate_rc),
        'doctor': stage(doctor_rc),
    },
    'memory': {
        'mode': memory_mode,
        'status': memory_status,
        'handoff_agent': handoff_agent or None,
        'handoff_path': handoff_path or None,
    },
    'capsule': {
        'status': capsule_status,
        'path': capsule_path or None,
    },
    'write_provenance': {
        'writer': 'engine-close',
        'commit': commit,
        'timestamp': timestamp,
        'argv': argv,
    },
}
with open(out, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write('\n')
PY
else
  echo "[engine-close] python3/python is required to write $out" >&2
  status="block"
fi

echo "[Engine System] Close status for $task: ${status^^}"
echo "  Evidence: ${out#"$ROOT/"}"
[ -n "$handoff_path" ] && echo "  Worker handoff: $handoff_path"
[ "$status" = "block" ] && exit 1
exit 0
