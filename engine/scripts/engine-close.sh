#!/usr/bin/env bash
# Engine System — agent-neutral lifecycle closure.
#
# Runs the public CLI in the canonical order (verify -> gate -> doctor), then
# records the closure audit. A worker may close into its own workstream shard;
# only a coordinator may claim the final shared-memory/capsule closure.

set -u -o pipefail

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
ENGINE_DIR="$ROOT/engine"
task_card_script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$task_card_script_dir/engine-task-card.sh" ]; then
  # shellcheck source=/dev/null
  . "$task_card_script_dir/engine-task-card.sh"
fi
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
  # Capture the stage before replaying its output. Piping the child directly
  # through tee lets an external log consumer closing early send SIGPIPE back
  # into the stage (notably Doctor's long report), turning a real exit 0 into
  # a false exit 141. The stage's exit code must be independent of display I/O.
  "$@" >"$tmp" 2>&1
  rc="$?"
  cat "$tmp" || true
  printf -v "${label}_rc" '%s' "$rc"
  rm -f "$tmp"
}

# Gate and close both write evidence files that are covered by MANIFEST.json.
# Refresh the manifest at each evidence-writer boundary so a done task's
# Doctor/drift check never observes a transient self-tamper state.
refresh_evidence_manifest() {
  local ev_dir="$ENGINE_DIR/evidence/$task"
  [ -d "$ev_dir" ] || return 0
  local manifest_content="" fname fhash
  while IFS= read -r fname; do
    [ -n "$fname" ] || continue
    fhash="$(sha256sum "$ev_dir/$fname" | cut -d' ' -f1)"
    manifest_content+="${fname}:${fhash}"$'\n'
  done < <(cd "$ev_dir" && find . -maxdepth 1 -type f \( -name '*.json' -o -name 'checkpoint.md' \) ! -name 'MANIFEST.json' -print 2>/dev/null | sed 's|^\./||' | LC_ALL=C sort)

  local manifest_hash="$(printf '%s' "$manifest_content" | sha256sum | cut -d' ' -f1)"
  local files_json="{" first=1
  while IFS=: read -r fname fhash; do
    [ -n "$fname" ] || continue
    [ "$first" = "1" ] || files_json+=",";
    files_json+="\"$fname\":\"$fhash\""
    first=0
  done <<< "$manifest_content"
  files_json+="}"
  printf '{"evidence_manifest_sha256":"sha256:%s","generated":"%s","writer":"engine-verify","commit":"%s","files":%s}\n' \
    "$manifest_hash" "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)" "$head_commit" "$files_json" \
    > "$ev_dir/MANIFEST.json"
}

verify_rc=0
gate_rc=0
doctor_rc=0
run_stage verify bash "$cli" verify "$task"
run_stage gate bash "$cli" gate "$task"
refresh_evidence_manifest
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


# v6.25.0 (T-086/O4): auto-generate change capsule from conventional commits.
# Internalized from conventional-changelog (MIT) — parses git log for task-linked
# commits, groups by type, outputs engine/changes/CHANGE-<task>.md.
generate_capsule() {
  local task_id="$1"
  local changes_dir="$ENGINE_DIR/changes"
  mkdir -p "$changes_dir"
  local capsule_file="$changes_dir/CHANGE-${task_id}.md"

  # Collect commits: prefer task-mentioning commits, supplement with recent history
  local commits
  commits="$(git -C "$ROOT" log --grep="$task_id" --pretty=format:"%s" 2>/dev/null || true)"
  # Always include last 30 commits for full context (task work may not all reference ID)
  local recent
  recent="$(git -C "$ROOT" log -30 --pretty=format:"%s" 2>/dev/null || true)"
  if [ -n "$recent" ]; then
    if [ -n "$commits" ]; then
      # Merge: task-specific first, then recent (dedup via sort -u)
      commits="$(printf '%s\n%s' "$commits" "$recent" | awk '!seen[$0]++')"
    else
      commits="$recent"
    fi
  fi
  [ -z "$commits" ] && return 1

  # Parse conventional commits and group by type
  local feat_list="" fix_list="" refactor_list="" docs_list="" test_list="" chore_list="" other_list=""
  local line ctype cscope cdesc
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    # Conventional format: type(scope)!: description  OR  type: description
    if [[ "$line" =~ ^([a-z]+)(\([a-zA-Z0-9._/-]*\))?(!)?:[[:space:]]*(.*) ]]; then
      ctype="${BASH_REMATCH[1]}"
      cscope="${BASH_REMATCH[2]}"
      cdesc="${BASH_REMATCH[4]}"
      # Strip parens from scope
      cscope="${cscope#(}"; cscope="${cscope%)}"
      local entry="- ${cdesc}"
      [ -n "$cscope" ] && entry="- **${cscope}**: ${cdesc}"
      case "$ctype" in
        feat)     feat_list+="${entry}"$'\n' ;;
        fix)      fix_list+="${entry}"$'\n' ;;
        refactor) refactor_list+="${entry}"$'\n' ;;
        docs)     docs_list+="${entry}"$'\n' ;;
        test)     test_list+="${entry}"$'\n' ;;
        chore|ci|build|style|perf) chore_list+="${entry}"$'\n' ;;
        *)        other_list+="${entry}"$'\n' ;;
      esac
    else
      # Non-conventional commit
      other_list+="- ${line}"$'\n'
    fi
  done <<< "$commits"

  # Write capsule
  {
    printf '# CHANGE-%s\n\n' "$task_id"
    printf '> Auto-generated by engine-close (conventional-changelog internalized). %s\n\n' "$timestamp"
    [ -n "$feat_list" ] && printf '## Features\n\n%b\n' "$feat_list"
    [ -n "$fix_list" ] && printf '## Bug Fixes\n\n%b\n' "$fix_list"
    [ -n "$refactor_list" ] && printf '## Refactoring\n\n%b\n' "$refactor_list"
    [ -n "$docs_list" ] && printf '## Documentation\n\n%b\n' "$docs_list"
    [ -n "$test_list" ] && printf '## Tests\n\n%b\n' "$test_list"
    [ -n "$chore_list" ] && printf '## Chores\n\n%b\n' "$chore_list"
    [ -n "$other_list" ] && printf '## Other\n\n%b\n' "$other_list"
    printf '%s\n' "---"
    printf 'Provenance: commit %s | writer: engine-close/generate_capsule\n' "$head_commit"
  } > "$capsule_file"

  echo "[engine-close] generated capsule: ${capsule_file#"$ROOT/"}"
  return 0
}

# A code task needs a task-linked capsule. Workers report this as deferred: the
# coordinator owns engine/changes and must perform the final close after merge.
capsule_status="not_required"
capsule_path=""
write_set_code=0
if declare -F task_card_parse_patterns >/dev/null 2>&1; then
  write_set_paths="$(task_card_parse_patterns WRITE-SET "$task_file")"
else
  write_set_paths="$(awk '
    /^##[[:space:]]+WRITE-SET[[:space:]]*$/ { on=1; next }
    on && /^##[[:space:]]+/ { on=0 }
    on && /^-[[:space:]]+/ { sub(/^-[[:space:]]+/, ""); print }
  ' "$task_file" 2>/dev/null)"
fi
while IFS= read -r write_path; do
  write_path="${write_path%%(*}"
  write_path="${write_path%%\[*}"
  if [[ "$write_path" =~ \.(sh|ps1|py|js|ts|go|rs|java|c|cpp|rb|php)$ ]]; then
    write_set_code=1
    break
  fi
done <<< "$write_set_paths"
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
    # v6.25.0 (O4): auto-generate capsule from conventional commits
    if generate_capsule "$task"; then
      capsule_status="pass"
      capsule_path="engine/changes/CHANGE-${task}.md"
    else
      echo "[engine-close] no task-linked change capsule found for $task (auto-generation failed)" >&2
    fi
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

refresh_evidence_manifest

echo "[Engine System] Close status for $task: ${status^^}"
echo "  Evidence: ${out#"$ROOT/"}"
[ -n "$handoff_path" ] && echo "  Worker handoff: $handoff_path"
[ "$status" = "block" ] && exit 1
exit 0
