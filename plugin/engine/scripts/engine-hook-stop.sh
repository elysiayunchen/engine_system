#!/usr/bin/env bash
# Engine System - write/stop gate (fail-open on runtime errors, fail-closed on malformed active tasks).
#
# Modes:
#   default          Claude Code Stop hook: validate this session's changed paths.
#   --pre-tool-use   Claude Code PreToolUse hook: validate and attribute a planned write.
#
# The task boundary covers every project path, including engine files. Runtime caches
# under engine/.cache and .engine are the only built-in exclusions.
set -u

log_error() { echo "[engine-hook-stop] ERROR: $*" >&2; }

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
ENGINE_DIR="$ROOT/engine"
MODE="${1:-stop}"
payload="$(cat 2>/dev/null || true)"

case "$payload" in
  *'"stop_hook_active":true'*|*'"stop_hook_active": true'*) exit 0 ;;
esac

[ -d "$ENGINE_DIR" ] || exit 0
command -v git >/dev/null 2>&1 || exit 0
git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

json_field() {
  local name="$1"
  printf '%s' "$payload" | sed -n 's/.*"'"$name"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1
}

safe_id() {
  printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '_'
}

normalize_path() {
  local path="$1" root_norm
  path="${path//\\\\/\\}"
  path="${path//\\//}"
  root_norm="${ROOT//\\//}"
  case "$path" in
    "$root_norm"/*) path="${path#"$root_norm"/}" ;;
  esac
  printf '%s' "${path#./}"
}

# v6.5+ closes the adoption gap: ordinary writes require an active task card.
# Older/no marker projects retain the legacy write-back gate until migrated.
is_strict_task_project() {
  local marker_file version major minor
  for marker_file in "$ROOT/AGENTS.md" "$ENGINE_DIR/SYSTEM.md" "$ENGINE_DIR/ENGINE_DOCTOR.md"; do
    [ -f "$marker_file" ] || continue
    version="$(sed -n 's/.*contract-version:[[:space:]]*\([0-9][0-9.]*\).*/\1/p' "$marker_file" 2>/dev/null | head -1)"
    [ -n "$version" ] && break
  done
  [ -n "${version:-}" ] || return 1
  major="${version%%.*}"
  minor="${version#*.}"; minor="${minor%%.*}"
  case "$major:$minor" in *[!0-9:]*|:*) return 1 ;; esac
  [ "$major" -gt 6 ] 2>/dev/null || { [ "$major" -eq 6 ] 2>/dev/null && [ "$minor" -ge 5 ] 2>/dev/null; }
}

is_task_bootstrap_path() {
  case "$1" in engine/tasks/T-*.md|engine/decisions/D-*.md) return 0 ;; *) return 1 ;; esac
}

find_active_task() {
  local f
  for f in "$ENGINE_DIR"/tasks/T-*.md; do
    [ -f "$f" ] || continue
    if grep -q 'status:.*active' "$f" 2>/dev/null; then
      printf '%s' "$f"
      return 0
    fi
  done
  return 1
}

# Once an active card is edited to done, it is no longer discoverable as active.
# A dirty done card remains the governing boundary through Stop/commit.
find_closing_task() {
  local f rel
  for f in "$ENGINE_DIR"/tasks/T-*.md; do
    [ -f "$f" ] || continue
    grep -q 'status:.*done' "$f" 2>/dev/null || continue
    rel="engine/tasks/$(basename "$f")"
    [ -n "$(git -C "$ROOT" status --porcelain -- "$rel" 2>/dev/null)" ] || continue
    printf '%s' "$f"
    return 0
  done
  return 1
}

# Supports both historical `WRITE-SET: a,b` and current section-list form:
#   ## WRITE-SET
#   - a/**
parse_task_patterns() {
  local field="$1" file="$2" inline
  inline="$(grep "^${field}:" "$file" 2>/dev/null | head -1 | sed "s/^${field}:[[:space:]]*//;s/\r$//")"
  if [ -n "$inline" ]; then
    printf '%s' "$inline"
    return 0
  fi
  awk -v field="$field" '
    BEGIN { in_section=0; out="" }
    {
      sub(/\r$/, "")
      if ($0 ~ "^##[[:space:]]+" field "[[:space:]]*$") { in_section=1; next }
      if (in_section && $0 ~ "^##[[:space:]]+") { exit }
      if (in_section && $0 ~ "^-[[:space:]]+") {
        sub(/^-[[:space:]]+/, "")
        sub(/[[:space:]]+\(.*/, "")
        if ($0 != "") out = (out == "" ? $0 : out "," $0)
      }
    }
    END { print out }
  ' "$file" 2>/dev/null
}

match_glob() {
  local path="$1" patterns="$2" p saved_ifs
  [ -n "$patterns" ] || return 1
  set -f
  saved_ifs="$IFS"; IFS=','
  for p in $patterns; do
    p="${p#"${p%%[![:space:]]*}"}"
    p="${p%"${p##*[![:space:]]}"}"
    [ -n "$p" ] || continue
    case "$path" in $p) IFS="$saved_ifs"; set +f; return 0 ;; esac
  done
  IFS="$saved_ifs"
  set +f
  return 1
}

is_runtime_cache() {
  case "$1" in engine/.cache/*|.engine/*) return 0 ;; *) return 1 ;; esac
}

is_shared_memory() {
  case "$1" in
    AGENTS.md|CLAUDE.md|engine/ENGINE_MAP.md|engine/SYSTEM.md|engine/REPO_GUIDE.md|\
    engine/CONTEXT.md|engine/HANDOFF.md|engine/PITFALLS.md|engine/SPRINT.md|engine/ROADMAP.md|\
    engine/domains/*/CONTEXT.md|engine/domains/*/PITFALLS.md|engine/plans/*|docs/*/specs/*|docs/specs/*)
      return 0 ;;
    *) return 1 ;;
  esac
}

strict_task_mode=0
is_strict_task_project && strict_task_mode=1
active_task="$(find_active_task 2>/dev/null || true)"
task_phase="active"
if [ -z "$active_task" ] && [ "$strict_task_mode" -eq 1 ]; then
  active_task="$(find_closing_task 2>/dev/null || true)"
  [ -n "$active_task" ] && task_phase="closing"
fi
active_task_id=""
write_set=""
forbidden=""
if [ -n "$active_task" ]; then
  active_task_id="$(basename "$active_task" .md)"
  write_set="$(parse_task_patterns WRITE-SET "$active_task")"
  forbidden="$(parse_task_patterns FORBIDDEN "$active_task")"
fi

block_scope() {
  local path="$1"
  if [ -z "$active_task" ]; then
    if [ "$strict_task_mode" -eq 1 ] && ! is_task_bootstrap_path "$path"; then
      printf '{"decision":"block","reason":"[Engine System] No active task card governs %s. | developer: This project uses the v6.5 strict workflow. Create or activate engine/tasks/T-NNN.md before editing ordinary project files."}\n' "$path"
      return 0
    fi
    return 1
  fi
  if [ -n "$forbidden" ] && match_glob "$path" "$forbidden"; then
    printf '{"decision":"block","reason":"[Engine System] Path %s is in FORBIDDEN for %s. | developer: This file is explicitly off-limits for the current task."}\n' "$path" "$active_task_id"
    return 0
  fi
  if [ -z "$write_set" ]; then
    printf '{"decision":"block","reason":"[Engine System] Active task %s has no readable WRITE-SET. | developer: The task boundary is malformed, so writes are paused until the task card is fixed."}\n' "$active_task_id"
    return 0
  fi
  if ! match_glob "$path" "$write_set"; then
    printf '{"decision":"block","reason":"[Engine System] Path %s is outside the WRITE-SET of %s. | developer: This file is outside the current task scope. Current WRITE-SET: %s"}\n' "$path" "$active_task_id" "$write_set"
    return 0
  fi
  return 1
}

session_id="$(json_field session_id)"
agent_id="$(json_field agent_id)"
tool_name="$(json_field tool_name)"
session_key=""
if [ -n "$session_id" ]; then
  session_key="$(safe_id "${session_id}-${agent_id:-main}")"
fi

if [ "$MODE" = "--pre-tool-use" ]; then
  file_path="$(json_field file_path)"
  [ -n "$file_path" ] || file_path="$(json_field path)"

  # Shell commands can write arbitrary paths. Mark the session for conservative
  # whole-worktree validation at Stop instead of pretending attribution is exact.
  if [ "$tool_name" = "Bash" ] || [ "$tool_name" = "Shell" ]; then
    if [ -n "$session_key" ]; then
      mkdir -p "$ENGINE_DIR/.cache/sessions" 2>/dev/null || true
      : > "$ENGINE_DIR/.cache/sessions/$session_key.global" 2>/dev/null || true
    fi
    exit 0
  fi

  [ -n "$file_path" ] || exit 0
  path="$(normalize_path "$file_path")"
  is_runtime_cache "$path" && exit 0

  if [ -n "$agent_id" ] && is_shared_memory "$path"; then
    printf '{"decision":"block","reason":"[Engine System] Worker agent %s cannot write shared memory %s. | developer: Parallel workers write their own engine/workstreams/%s/%s/ shard; the coordinator merges shared CONTEXT/HANDOFF once."}\n' "$agent_id" "$path" "${active_task_id:-T-NNN}" "$(safe_id "$agent_id")"
    exit 0
  fi

  if [ -n "$agent_id" ]; then
    case "$path" in
      engine/workstreams/*)
        agent_safe="$(safe_id "$agent_id")"
        case "$path" in
          engine/workstreams/"${active_task_id:-T-NNN}"/"$agent_safe"/*) ;;
          *)
            printf '{"decision":"block","reason":"[Engine System] Worker %s may only write its own workstream shard: engine/workstreams/%s/%s/."}\n' "$agent_id" "${active_task_id:-T-NNN}" "$agent_safe"
            exit 0
            ;;
        esac
        ;;
    esac
  fi

  if block_scope "$path"; then exit 0; fi

  if [ -n "$session_key" ]; then
    mkdir -p "$ENGINE_DIR/.cache/sessions" 2>/dev/null || true
    ledger="$ENGINE_DIR/.cache/sessions/$session_key.paths"
    grep -Fxq "$path" "$ledger" 2>/dev/null || printf '%s\n' "$path" >> "$ledger" 2>/dev/null || true
  fi
  exit 0
fi

# Stop mode. Prefer paths attributed by PreToolUse. If the session used a shell
# tool, or no ledger exists, retain the conservative whole-worktree fallback.
owned_paths=""
attributed=0
if [ -n "$session_key" ] && [ -s "$ENGINE_DIR/.cache/sessions/$session_key.paths" ] && [ ! -f "$ENGINE_DIR/.cache/sessions/$session_key.global" ]; then
  owned_paths="$(cat "$ENGINE_DIR/.cache/sessions/$session_key.paths" 2>/dev/null)"
  attributed=1
fi

path_owned() {
  [ "$attributed" -eq 0 ] && return 0
  printf '%s\n' "$owned_paths" | grep -Fxq "$1"
}

code_changed=0
engine_written=0
capsule_written=0
code_paths=()
governed_paths=()
skip_next=0
while IFS= read -r -d '' rec || [ -n "$rec" ]; do
  if [ "$skip_next" -eq 1 ]; then skip_next=0; continue; fi
  [ "${#rec}" -ge 4 ] || continue
  st="${rec:0:2}"
  path="${rec:3}"
  case "$st" in *R*|*C*) skip_next=1 ;; esac
  path_owned "$path" || continue
  is_runtime_cache "$path" && continue
  governed_paths+=("$path")
  case "$path" in
    engine/CONTEXT.md|engine/HANDOFF.md|engine/ENGINE_MAP.md|engine/workstreams/*/*/CONTEXT.md|engine/workstreams/*/*/HANDOFF.md) engine_written=1 ;;
    engine/changes/CHANGE-*.md) capsule_written=1 ;;
    engine/*) : ;;
    *) code_changed=1; code_paths+=("$path") ;;
  esac
done < <(git -C "$ROOT" status --porcelain -z -uall 2>/dev/null)

if [ -n "$active_task" ] || [ "$strict_task_mode" -eq 1 ]; then
  for path in "${governed_paths[@]}"; do
    if [ -n "$agent_id" ] && is_shared_memory "$path"; then
      printf '{"decision":"block","reason":"[Engine System] Worker agent %s changed shared memory %s. Use engine/workstreams/%s/%s/ and let the coordinator merge."}\n' "$agent_id" "$path" "$active_task_id" "$(safe_id "$agent_id")"
      exit 0
    fi
    if block_scope "$path"; then exit 0; fi
  done
fi

if [ "$code_changed" -eq 1 ] && [ "$engine_written" -eq 0 ]; then
  printf '%s\n' '{"decision":"block","reason":"[Engine System] Code changed but this session did not update project memory. | developer: Save what changed and what comes next before ending. Parallel workers must write their own workstream shard; the coordinator updates shared CONTEXT/HANDOFF."}'
  exit 0
fi

# Domain routing remains a code-path concern. Engine-memory routing is governed by WRITE-SET.
if [ -n "$active_task" ] && [ "${#code_paths[@]}" -gt 0 ]; then
  fed="$ENGINE_DIR/domains/federation.json"
  task_domains="$(grep '^>.*domain:' "$active_task" 2>/dev/null | head -1 | sed 's/.*domain:[[:space:]]*//' | sed 's/|.*//' | tr -d ' ')"
  if [ -f "$fed" ] && [ -n "$task_domains" ]; then
    federation="$(awk '
      /"default_domain"/ { if (match($0, /"default_domain"[[:space:]]*:[[:space:]]*"([^"]+)"/, m)) print "DEFAULT\t" m[1]; next }
      /^[[:space:]]*"[A-Za-z0-9_-]+"[[:space:]]*:[[:space:]]*\{/ { if (match($0, /"([A-Za-z0-9_-]+)"/, m)) { domain=m[1]; in_paths=0 }; next }
      /"paths"/ { in_paths=1; s=$0; sub(/.*"paths"[[:space:]]*:[[:space:]]*/, "", s); if (s ~ /\]/) { in_paths=0; while (match(s, /"([^"]+)"/, m)) { if (domain!="") print domain "\t" m[1]; s=substr(s, RSTART+RLENGTH) } }; next }
      in_paths && /\]/ { in_paths=0; next }
      in_paths { s=$0; while (match(s, /"([^"]+)"/, m)) { if (domain!="") print domain "\t" m[1]; s=substr(s, RSTART+RLENGTH) } }
    ' "$fed" 2>/dev/null)"
    default_dom="$(printf '%s\n' "$federation" | awk -F'\t' '/^DEFAULT/{print $2; exit}')"
    for path in "${code_paths[@]}"; do
      path_dom=""
      while IFS=$'\t' read -r d g; do
        [ "$d" = "DEFAULT" ] && continue
        [ -n "$g" ] || continue
        case "$path" in $g) path_dom="$d"; break ;; esac
      done <<< "$federation"
      [ -n "$path_dom" ] || path_dom="${default_dom:-root}"
      if ! printf '%s' ",$task_domains," | grep -qF ",$path_dom,"; then
        printf '{"decision":"block","reason":"[Engine System] Path %s belongs to domain %s, outside task %s domains [%s]."}\n' "$path" "$path_dom" "$active_task_id" "$task_domains"
        exit 0
      fi
    done
  fi
fi

if [ "$code_changed" -eq 1 ] && [ "$engine_written" -eq 1 ] && [ "$capsule_written" -eq 0 ]; then
  printf '%s\n' '{"systemMessage":"[Engine System] Code and project memory changed, but no change capsule was found. Add engine/changes/CHANGE-*.md before completion. (WARN)"}'
fi

# v6.11.0 (D-029/T-036) AC-3: Stop hook 多会话收尾
# - 写 .cache/sessions/<session_key>.meta (role|stopped_at|task_id),供 engine-context.sh Active Sessions 面板读
# - 如果当前会话是协调者(持有 lock 且 session_id 匹配 lock 内 sid),释放 lock (rm session.lock)
# - 写 tombstone 文件通知其他会话(coordinator-exited,可接管)
# PreToolUse 双信号由 AC-4 扩展;本 AC-3 只做 .meta + lock release + tombstone。
if [ -n "$session_key" ] && [ -d "$ENGINE_DIR/.cache/sessions" ]; then
  lock_file="$ENGINE_DIR/.cache/session.lock"
  role="worker"
  lock_content=""
  if [ -f "$lock_file" ]; then
    lock_content="$(cat "$lock_file" 2>/dev/null || true)"
    lock_sid="$(printf '%s' "$lock_content" | cut -d'|' -f2)"
    if [ -n "$lock_sid" ] && [ "$lock_sid" = "$session_id" ]; then
      role="coordinator"
    fi
  else
    # No lock — single session mode (coordinator by default)
    role="coordinator"
  fi
  stopped_at="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || printf '%s' '')"
  meta_file="$ENGINE_DIR/.cache/sessions/$session_key.meta"
  printf '%s|%s|%s\n' "$role" "$stopped_at" "${active_task_id:-}" > "$meta_file" 2>/dev/null || true

  # 协调者退出:释放 lock (rm session.lock) + 写 tombstone 通知其他会话
  if [ "$role" = "coordinator" ] && [ -f "$lock_file" ]; then
    lock_pid="$(printf '%s' "$lock_content" | cut -d'|' -f1)"
    rm -f "$ENGINE_DIR/.cache/session.lock" 2>/dev/null || true
    # tombstone: coordinator-exited 通知,其他会话 SessionStart 检测到时可接管
    tombstone_file="$ENGINE_DIR/.cache/session.tombstone"
    printf '%s|%s|coordinator-exited\n' "$stopped_at" "$lock_pid" > "$tombstone_file" 2>/dev/null || true
  fi
fi

exit 0
