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

# v6.12.0 (D-035) RC-1 fix: collect EVERY active card, not the lexicographically
# first one. Multiple top-level sessions may each hold their own active card;
# gating is per-path union across cards (see block_scope).
find_active_tasks() {
  local f
  for f in "$ENGINE_DIR"/tasks/T-*.md; do
    [ -f "$f" ] || continue
    case "$f" in *.spec.md) continue ;; esac
    # v6.12.1 (issue #11 C-1): anchored to line start. The old unanchored
    # 'status:.*active' matched prose that merely QUOTED the pattern, pinning
    # done cards as active and locking the whole repo.
    if grep -Eq '^[[:space:]]*(>[[:space:]]*)?status:[[:space:]]*active' "$f" 2>/dev/null; then
      printf '%s\n' "$f"
    fi
  done
}

# Once an active card is edited to done, it is no longer discoverable as active.
# A dirty done card remains a governing boundary through Stop/commit.
find_closing_tasks() {
  local f rel
  for f in "$ENGINE_DIR"/tasks/T-*.md; do
    [ -f "$f" ] || continue
    case "$f" in *.spec.md) continue ;; esac
    grep -Eq '^[[:space:]]*(>[[:space:]]*)?status:[[:space:]]*done' "$f" 2>/dev/null || continue
    rel="engine/tasks/$(basename "$f")"
    [ -n "$(git -C "$ROOT" status --porcelain -- "$rel" 2>/dev/null)" ] || continue
    printf '%s\n' "$f"
  done
}

# Supports all three accepted spellings (v6.12.1, issue #11 B-1 - aligned with
# the pre-commit parser from T-043): inline `WRITE-SET: a,b`, markdown section
# `## WRITE-SET` list, and YAML frontmatter multi-line `write-set:` list.
# Before this, a card written only in the frontmatter (spec) format was
# rejected by the hook with "no readable WRITE-SET", pausing all writes.
parse_task_patterns() {
  local field="$1" file="$2" inline
  inline="$(grep "^${field}:" "$file" 2>/dev/null | head -1 | sed "s/^${field}:[[:space:]]*//;s/\r$//")"
  if [ -n "$inline" ]; then
    printf '%s' "$inline"
    return 0
  fi
  awk -v field="$field" '
    BEGIN { in_section=0; in_frontmatter_block=0; in_frontmatter_field=0; out=""; field_lc=tolower(field) }
    {
      sub(/\r$/, "")
      if ($0 ~ /^---[[:space:]]*$/) {
        in_frontmatter_block = !in_frontmatter_block
        in_frontmatter_field = 0
        next
      }
      line_lc = tolower($0)
      if (line_lc ~ "^##[[:space:]]+" field_lc "[[:space:]]*$") { in_section=1; in_frontmatter_field=0; next }
      if (in_section && $0 ~ "^##[[:space:]]+") { exit }
      if (in_frontmatter_block && line_lc ~ "^" field_lc ":$") {
        in_frontmatter_field=1; in_section=0; next
      }
      if (in_frontmatter_field && $0 !~ /^[[:space:]]/ && $0 != "") { in_frontmatter_field=0 }
      if (in_frontmatter_field && $0 ~ /^[[:space:]]+-[[:space:]]+/) {
        sub(/^[[:space:]]+-[[:space:]]+/, "")
        sub(/[[:space:]]+\(.*/, "")
        if ($0 != "") out = (out == "" ? $0 : out "," $0)
        next
      }
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
    # v6.12.1 (issue #11 B-3): a bare directory entry also matches its
    # children - `engine/evidence/T-049` covers `engine/evidence/T-049/x.json`.
    case "$path" in $p|$p/*) IFS="$saved_ifs"; set +f; return 0 ;; esac
  done
  IFS="$saved_ifs"
  set +f
  return 1
}

is_runtime_cache() {
  case "$1" in engine/.cache/*|.engine/*) return 0 ;; *) return 1 ;; esac
}

# v6.12.0 (D-035) RC-4 fix: split the old is_shared_memory blanket.
# - Shared singletons: one authoritative copy repo-wide; coordinator-only for
#   every worker kind (top-level worker session or in-session subagent).
# - Task-local files (per-task progress/checkpoint): governed by the owning
#   card's WRITE-SET union instead, so a worker session driving its OWN card
#   can still record progress. In-session subagents (agent_id set) keep the
#   old blanket: they shard everything and the coordinator merges (v6.5).
is_shared_singleton() {
  case "$1" in
    AGENTS.md|CLAUDE.md|engine/ENGINE_MAP.md|engine/SYSTEM.md|engine/REPO_GUIDE.md|\
    engine/CONTEXT.md|engine/HANDOFF.md|engine/PITFALLS.md|engine/SPRINT.md|engine/ROADMAP.md|\
    engine/domains/*/CONTEXT.md|engine/domains/*/PITFALLS.md|engine/domains/*/INVENTORY.md|\
    engine/plans/*|docs/*/specs/*|docs/specs/*)
      return 0 ;;
    *) return 1 ;;
  esac
}

is_task_local() {
  case "$1" in
    engine/tasks/T-*/progress.md|engine/evidence/T-*/checkpoint.md) return 0 ;;
    *) return 1 ;;
  esac
}

is_shared_memory() {
  is_shared_singleton "$1" || is_task_local "$1"
}

strict_task_mode=0
is_strict_task_project && strict_task_mode=1

# v6.12.0 (D-035): cache every governing card (all active, else dirty-done
# closing cards). Parallel arrays: file / id / WRITE-SET / FORBIDDEN.
card_files=()
card_ids=()
card_ws=()
card_fb=()
task_phase="active"
while IFS= read -r _card; do
  [ -n "$_card" ] || continue
  card_files+=("$_card")
done < <(find_active_tasks 2>/dev/null)
# Closing (dirty done) cards always co-govern: one session may be closing its
# card while another session's card is still active (D-035).
_had_active="${#card_files[@]}"
while IFS= read -r _card; do
  [ -n "$_card" ] || continue
  card_files+=("$_card")
done < <(find_closing_tasks 2>/dev/null)
if [ "$_had_active" -eq 0 ] && [ "${#card_files[@]}" -gt 0 ]; then
  task_phase="closing"
fi
for _card in "${card_files[@]}"; do
  card_ids+=("$(basename "$_card" .md)")
  card_ws+=("$(parse_task_patterns WRITE-SET "$_card")")
  card_fb+=("$(parse_task_patterns FORBIDDEN "$_card")")
done
# Primary card = first found. Display/meta only; gating is per-path union.
active_task="${card_files[0]:-}"
active_task_id="${card_ids[0]:-}"

card_id_list() {
  local out="" id
  for id in "${card_ids[@]}"; do
    out="${out:+$out, }$id"
  done
  printf '%s' "$out"
}

# True when the argument names any governing card (worker shard path check).
is_governing_task_id() {
  local want="$1" id
  for id in "${card_ids[@]}"; do
    [ "$id" = "$want" ] && return 0
  done
  return 1
}

# Union gating (D-035 RC-1/RC-2): a path is allowed when at least one governing
# card lists it in WRITE-SET and not in that same card's FORBIDDEN. One card's
# FORBIDDEN no longer vetoes another card's WRITE-SET. Task/decision card files
# are always writable (bootstrap channel): creating or updating a card must
# never be blocked by someone else's card.
block_scope() {
  local path="$1" i ws fb readable=0
  if [ "${#card_files[@]}" -eq 0 ]; then
    if [ "$strict_task_mode" -eq 1 ] && ! is_task_bootstrap_path "$path"; then
      printf '{"decision":"block","reason":"[Engine System] No active task card governs %s. | developer: This project uses the v6.5 strict workflow. Create or activate engine/tasks/T-NNN.md before editing ordinary project files."}\n' "$path"
      return 0
    fi
    return 1
  fi
  is_task_bootstrap_path "$path" && return 1
  i=0
  while [ "$i" -lt "${#card_files[@]}" ]; do
    ws="${card_ws[$i]}"
    fb="${card_fb[$i]}"
    i=$((i + 1))
    [ -n "$ws" ] || continue
    readable=1
    if [ -n "$fb" ] && match_glob "$path" "$fb"; then continue; fi
    match_glob "$path" "$ws" && return 1
  done
  if [ "$readable" -eq 0 ]; then
    printf '{"decision":"block","reason":"[Engine System] No governing task card has a readable WRITE-SET (%s). | developer: The task boundary is malformed, so writes are paused until a card is fixed."}\n' "$(card_id_list)"
    return 0
  fi
  printf '{"decision":"block","reason":"[Engine System] Path %s is outside the WRITE-SET of every active card (%s). | developer: Add the path to YOUR card WRITE-SET, or create a task card for this goal."}\n' "$path" "$(card_id_list)"
  return 0
}

# Which governing card covers this path? Prints the card index; rc 1 when none.
covering_card_index() {
  local path="$1" i ws fb
  i=0
  while [ "$i" -lt "${#card_files[@]}" ]; do
    ws="${card_ws[$i]}"
    fb="${card_fb[$i]}"
    if [ -n "$ws" ] && match_glob "$path" "$ws"; then
      if [ -z "$fb" ] || ! match_glob "$path" "$fb"; then
        printf '%s' "$i"
        return 0
      fi
    fi
    i=$((i + 1))
  done
  return 1
}

# v6.12.0 (D-035) RC-3 fix: lease freshness by heartbeat mtime, not pid
# liveness. The lock records the transient hook shell pid (always dead by the
# next check), so instead each session renews .cache/sessions/<key>.hb on every
# PreToolUse and the holder re-stamps the lock at UserPromptSubmit. Fresh =
# newest of lock/.hb mtime within ENGINE_SESSION_TTL_MIN (default 120 minutes).
mtime_epoch() {
  stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || printf ''
}

lease_fresh() {
  local lock="$1" ttl_min="${ENGINE_SESSION_TTL_MIN:-120}" lock_sid hb newest m now age
  [ -f "$lock" ] || return 1
  case "$ttl_min" in ''|*[!0-9]*) ttl_min=120 ;; esac
  newest="$(mtime_epoch "$lock")"
  lock_sid="$(cut -d'|' -f2 "$lock" 2>/dev/null | head -1)"
  if [ -n "$lock_sid" ]; then
    hb="$ENGINE_DIR/.cache/sessions/$(safe_id "${lock_sid}-main").hb"
    m="$(mtime_epoch "$hb")"
    if [ -n "$m" ]; then
      if [ -z "$newest" ] || [ "$m" -gt "$newest" ] 2>/dev/null; then newest="$m"; fi
    fi
  fi
  [ -n "$newest" ] || return 1
  now="$(date +%s 2>/dev/null)" || return 0
  age=$((now - newest))
  [ "$age" -le $((ttl_min * 60)) ]
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

  # v6.12.0 (D-035): every tool call renews this session's lease heartbeat.
  if [ -n "$session_key" ]; then
    mkdir -p "$ENGINE_DIR/.cache/sessions" 2>/dev/null || true
    touch "$ENGINE_DIR/.cache/sessions/$session_key.hb" 2>/dev/null || true
  fi

  # Shell commands can write arbitrary paths. Mark the session for conservative
  # whole-worktree validation at Stop instead of pretending attribution is exact.
  if [ "$tool_name" = "Bash" ] || [ "$tool_name" = "Shell" ]; then
    if [ -n "$session_key" ]; then
      : > "$ENGINE_DIR/.cache/sessions/$session_key.global" 2>/dev/null || true
    fi
    exit 0
  fi

  [ -n "$file_path" ] || exit 0
  path="$(normalize_path "$file_path")"
  # Still absolute after ROOT-stripping = outside this worktree (scratchpad,
  # temp dirs, other repos). Not a project path; not governed (v6.12.1).
  case "$path" in
    /*|[A-Za-z]:/*) exit 0 ;;
  esac
  is_runtime_cache "$path" && exit 0

  # v6.11.0 (D-029/T-036) AC-4 dual-signal, scope narrowed by v6.12.0 (D-035):
  # signal 1: agent_id set (in-session subagent, passed by Claude Code)
  # signal 2: .cache/sessions/<session_key>.role=worker flag (demoted top-level session)
  is_worker=0
  if [ -n "$agent_id" ]; then
    is_worker=1
  elif [ -n "$session_key" ] && [ -f "$ENGINE_DIR/.cache/sessions/$session_key.role=worker" ]; then
    is_worker=1
  fi
  worker_id="${agent_id:-$session_key}"

  # Shared singleton writes resolve against the coordinator lease (D-035):
  # - in-session subagents never own the lease -> always shard
  # - top-level sessions: holder writes; non-holder blocked while the lease is
  #   fresh; a stale or free lease is claimed on the spot (self-healing, incl.
  #   sessions stuck with an obsolete .role=worker flag from RC-3b)
  if is_shared_singleton "$path"; then
    if [ -n "$agent_id" ]; then
      printf '{"decision":"block","reason":"[Engine System] Worker %s cannot write shared memory %s. | developer: Parallel workers write their own engine/workstreams/<task>/%s/ shard; the coordinator merges shared CONTEXT/HANDOFF once."}\n' "$worker_id" "$path" "$(safe_id "$worker_id")"
      exit 0
    fi
    if [ -n "$session_id" ]; then
      lock_file="$ENGINE_DIR/.cache/session.lock"
      now_iso="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date 2>/dev/null || echo unknown)"
      if [ ! -f "$lock_file" ]; then
        mkdir -p "$ENGINE_DIR/.cache" 2>/dev/null || true
        ( set -C; printf '%s|%s|coordinator|%s|%s\n' "$$" "$session_id" "$now_iso" "${active_task_id:-}" > "$lock_file" ) 2>/dev/null || true
      fi
      lock_sid="$(cut -d'|' -f2 "$lock_file" 2>/dev/null | head -1)"
      if [ -n "$lock_sid" ] && [ "$lock_sid" != "$session_id" ]; then
        if lease_fresh "$lock_file"; then
          if [ "$is_worker" -eq 1 ]; then
            printf '{"decision":"block","reason":"[Engine System] Worker %s cannot write shared memory %s. | developer: Parallel workers write their own engine/workstreams/<task>/%s/ shard; the coordinator merges shared CONTEXT/HANDOFF once."}\n' "$worker_id" "$path" "$(safe_id "$worker_id")"
          else
            printf '{"decision":"block","reason":"[Engine System] Shared memory %s is leased by another live session. | developer: Run engine assume-coordinator to take over, or write your own workstreams shard and let the coordinator merge."}\n' "$path"
          fi
          exit 0
        fi
        # Stale lease: take over and continue as coordinator.
        printf '%s|%s|coordinator|%s|%s\n' "$$" "$session_id" "$now_iso" "${active_task_id:-}" > "$lock_file" 2>/dev/null || true
        printf '%s|%s|stale-recovered\n' "$now_iso" "unknown" > "$ENGINE_DIR/.cache/session.tombstone" 2>/dev/null || true
      fi
      # Holding (or just claimed) the lease: coordinator from here on.
      if [ -n "$session_key" ]; then
        rm -f "$ENGINE_DIR/.cache/sessions/$session_key.role=worker" 2>/dev/null || true
      fi
      is_worker=0
    elif [ "$is_worker" -eq 1 ]; then
      # No session identity (non-Claude harness): keep the flag-based block.
      printf '{"decision":"block","reason":"[Engine System] Worker %s cannot write shared memory %s. | developer: Parallel workers write their own engine/workstreams/<task>/%s/ shard; the coordinator merges shared CONTEXT/HANDOFF once."}\n' "$worker_id" "$path" "$(safe_id "$worker_id")"
      exit 0
    fi
  fi

  # In-session subagents keep the v6.5 blanket: task-local progress/checkpoint
  # files also go through their shard; the coordinator merges. Top-level worker
  # sessions write task-local files of their OWN card via WRITE-SET union.
  if [ -n "$agent_id" ] && is_task_local "$path"; then
    printf '{"decision":"block","reason":"[Engine System] Subagent %s cannot write task file %s directly. | developer: Record it in your engine/workstreams/<task>/%s/ shard; the coordinator merges."}\n' "$agent_id" "$path" "$(safe_id "$agent_id")"
    exit 0
  fi

  if [ "$is_worker" -eq 1 ]; then
    case "$path" in
      engine/workstreams/*)
        agent_safe="$(safe_id "$worker_id")"
        shard_task="${path#engine/workstreams/}"
        shard_task="${shard_task%%/*}"
        case "$path" in
          engine/workstreams/"$shard_task"/"$agent_safe"/*)
            # v6.12.0 (D-035) RC-4 fix: a shard may live under ANY governing
            # card, not only the lexicographically first one. A validated own
            # shard is the sanctioned worker write channel: allow it directly
            # instead of demanding every card list workstreams in WRITE-SET.
            if [ "${#card_ids[@]}" -gt 0 ] && ! is_governing_task_id "$shard_task"; then
              printf '{"decision":"block","reason":"[Engine System] Workstream shard task %s is not an active card (%s). | developer: Run engine workstream against your own active card."}\n' "$shard_task" "$(card_id_list)"
              exit 0
            fi
            if [ -n "$session_key" ]; then
              ledger="$ENGINE_DIR/.cache/sessions/$session_key.paths"
              grep -Fxq "$path" "$ledger" 2>/dev/null || printf '%s\n' "$path" >> "$ledger" 2>/dev/null || true
            fi
            exit 0
            ;;
          *)
            printf '{"decision":"block","reason":"[Engine System] Worker %s may only write its own workstream shard: engine/workstreams/<task>/%s/."}\n' "$worker_id" "$agent_safe"
            exit 0
            ;;
        esac
        ;;
    esac
  fi

  if block_scope "$path"; then exit 0; fi

  if [ -n "$session_key" ]; then
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

if [ "${#card_files[@]}" -gt 0 ] || [ "$strict_task_mode" -eq 1 ]; then
  for path in "${governed_paths[@]}"; do
    if [ -n "$agent_id" ] && is_shared_memory "$path"; then
      printf '{"decision":"block","reason":"[Engine System] Worker agent %s changed shared memory %s. Use engine/workstreams/<task>/%s/ and let the coordinator merge."}\n' "$agent_id" "$path" "$(safe_id "$agent_id")"
      exit 0
    fi
    # Workstream shards are the sanctioned worker channel; the conservative
    # whole-worktree fallback may also see sibling sessions' shards - never block.
    case "$path" in engine/workstreams/*/*/*) continue ;; esac
    if block_scope "$path"; then exit 0; fi
  done
fi

if [ "$code_changed" -eq 1 ] && [ "$engine_written" -eq 0 ]; then
  # v6.25.0 (T-082): S5 failure candidate before block exit
  (
    _s5_task="${active_task_id:-}"
    if [ -n "$_s5_task" ]; then
      _s5_dom="engine-runtime"
      _s5_card="$ENGINE_DIR/tasks/$_s5_task.md"
      if [ -f "$_s5_card" ]; then
        _s5_dl="$(sed -n 's/.*domain:[[:space:]]*\([^|]*\).*/\1/p' "$_s5_card" | head -1 | sed 's/[[:space:]]*$//')"
        [ -n "$_s5_dl" ] && _s5_dom="$(printf '%s' "$_s5_dl" | cut -d, -f1)"
      fi
      _s5_pfile="$ENGINE_DIR/domains/$_s5_dom/PITFALLS.md"
      [ -f "$_s5_pfile" ] || _s5_pfile="$ENGINE_DIR/domains/engine-runtime/PITFALLS.md"
      if [ -f "$_s5_pfile" ]; then
        _s5_dk="$(printf 'S5|%s|%s' "$_s5_task" "$_s5_dom" | cksum | cut -d' ' -f1 | cut -c1-12)"
        _s5_seen="$ENGINE_DIR/.cache/seen-keys"
        mkdir -p "$ENGINE_DIR/.cache" 2>/dev/null || true
        touch "$_s5_seen" 2>/dev/null || true
        if ! grep -qF "$_s5_dk" "$_s5_seen" 2>/dev/null && ! grep -qF "$_s5_dk" "$_s5_pfile" 2>/dev/null; then
          grep -q '^## Auto-detected' "$_s5_pfile" 2>/dev/null || printf '
## Auto-detected (pending review)

' >> "$_s5_pfile" 2>/dev/null
          _s5_ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)"
          printf -- '- **CAND-%s** Code changed but engine memory not written back
  - signal: S5
  - severity: low
  - task: %s
  - domain: %s
  - session: %s
  - cluster: %s
  - date: %s
  - dedup-key: %s
  - status: pending

'             "$(date -u +%Y%m%d%H%M%S 2>/dev/null || echo 000)" "$_s5_task" "$_s5_dom" "${session_id:-unknown}" "${_s5_task}@${session_id:-unknown}" "$_s5_ts" "$_s5_dk" >> "$_s5_pfile" 2>/dev/null || true
          printf '%s
' "$_s5_dk" >> "$_s5_seen" 2>/dev/null || true
        fi
      fi
    fi
  ) || true
  printf '%s\n' '{"decision":"block","reason":"[Engine System] Code changed but this session did not update project memory. | developer: Save what changed and what comes next before ending. Parallel workers must write their own workstream shard; the coordinator updates shared CONTEXT/HANDOFF."}'
  exit 0
fi

# Domain routing remains a code-path concern. Engine-memory routing is governed
# by WRITE-SET. v6.12.0 (D-035): each code path is judged against the domains of
# the card that covers it, not against the first active card.
if [ "${#card_files[@]}" -gt 0 ] && [ "${#code_paths[@]}" -gt 0 ]; then
  fed="$ENGINE_DIR/domains/federation.json"
  if [ -f "$fed" ]; then
    federation="$(awk '
      /"default_domain"/ { if (match($0, /"default_domain"[[:space:]]*:[[:space:]]*"([^"]+)"/, m)) print "DEFAULT\t" m[1]; next }
      /^[[:space:]]*"[A-Za-z0-9_-]+"[[:space:]]*:[[:space:]]*\{/ { if (match($0, /"([A-Za-z0-9_-]+)"/, m)) { domain=m[1]; in_paths=0 }; next }
      /"paths"/ { in_paths=1; s=$0; sub(/.*"paths"[[:space:]]*:[[:space:]]*/, "", s); if (s ~ /\]/) { in_paths=0; while (match(s, /"([^"]+)"/, m)) { if (domain!="") print domain "\t" m[1]; s=substr(s, RSTART+RLENGTH) } }; next }
      in_paths && /\]/ { in_paths=0; next }
      in_paths { s=$0; while (match(s, /"([^"]+)"/, m)) { if (domain!="") print domain "\t" m[1]; s=substr(s, RSTART+RLENGTH) } }
    ' "$fed" 2>/dev/null)"
    default_dom="$(printf '%s\n' "$federation" | awk -F'\t' '/^DEFAULT/{print $2; exit}')"
    for path in "${code_paths[@]}"; do
      cover_idx="$(covering_card_index "$path" || true)"
      [ -n "$cover_idx" ] || continue
      cover_file="${card_files[$cover_idx]}"
      cover_id="${card_ids[$cover_idx]}"
      task_domains="$(grep '^>.*domain:' "$cover_file" 2>/dev/null | head -1 | sed 's/.*domain:[[:space:]]*//' | sed 's/|.*//' | tr -d ' ')"
      [ -n "$task_domains" ] || continue
      path_dom=""
      while IFS=$'\t' read -r d g; do
        [ "$d" = "DEFAULT" ] && continue
        [ -n "$g" ] || continue
        case "$path" in $g) path_dom="$d"; break ;; esac
      done <<< "$federation"
      [ -n "$path_dom" ] || path_dom="${default_dom:-root}"
      if ! printf '%s' ",$task_domains," | grep -qF ",$path_dom,"; then
        printf '{"decision":"block","reason":"[Engine System] Path %s belongs to domain %s, outside task %s domains [%s]."}\n' "$path" "$path_dom" "$cover_id" "$task_domains"
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
  # P1 修复 (review):AC-3 复用 AC-4 双信号优先判定 worker,避免协调者先退出后
  # worker 因 lock_file 不存在被默认判定为 coordinator 污染 .meta role 字段
  is_worker_explicit=0
  if [ -n "$agent_id" ]; then
    is_worker_explicit=1
  elif [ -f "$ENGINE_DIR/.cache/sessions/$session_key.role=worker" ]; then
    is_worker_explicit=1
  fi
  if [ "$is_worker_explicit" -eq 0 ]; then
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
  fi
  stopped_at="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || printf '%s' '')"
  meta_file="$ENGINE_DIR/.cache/sessions/$session_key.meta"
  printf '%s|%s|%s\n' "$role" "$stopped_at" "${active_task_id:-}" > "$meta_file" 2>/dev/null || true

  # 协调者退出:释放 lock (rm session.lock) + 写 tombstone 通知其他会话
  if [ "$role" = "coordinator" ] && [ -f "$lock_file" ]; then
    lock_pid="$(printf '%s' "$lock_content" | cut -d'|' -f1)"
    # P2 修复 (review):tombstone lock_pid 空值 fallback "unknown",避免数据不完整
    [ -n "$lock_pid" ] || lock_pid="unknown"
    rm -f "$ENGINE_DIR/.cache/session.lock" 2>/dev/null || true
    # tombstone: coordinator-exited 通知,其他会话 SessionStart 检测到时可接管
    tombstone_file="$ENGINE_DIR/.cache/session.tombstone"
    printf '%s|%s|coordinator-exited\n' "$stopped_at" "$lock_pid" > "$tombstone_file" 2>/dev/null || true
  fi
fi


# v6.25.0 (T-082): 失败模式自动提取（纯模式匹配，fail-open）
# 检测可观测信号，追加 PITFALLS 候选条目。任何错误静默忽略。
(
  _fe_cache="$ENGINE_DIR/.cache"
  _fe_seen="$_fe_cache/seen-keys"
  _fe_task="${active_task_id:-}"
  [ -n "$_fe_task" ] || exit 0
  mkdir -p "$_fe_cache" 2>/dev/null || true
  touch "$_fe_seen" 2>/dev/null || true

  # 辅助: 计算 dedup key (signal|task|domain 的前12字符 hash)
  _fe_dedup_key() {
    local sig="$1" path="$2" dom="$3"
    # 简化 glob_normalize: 保留前2级目录+扩展名
    local norm
    norm="$(printf '%s' "$path" | sed 's|T-[0-9]\{3\}|T-*|g' | awk -F/ '{if(NF>2) print $1"/"$2"/..."; else print $0}')"
    printf '%s|%s|%s' "$sig" "$norm" "$dom" | cksum | cut -d' ' -f1 | cut -c1-12
  }

  # 辅助: 追加候选条目到 PITFALLS
  _fe_append_candidate() {
    local sig="$1" detail="$2" dom="$3" dkey="$4"
    # Severity by signal type (TDAI-inspired score)
    local sev="medium"
    case "$sig" in
      S18) sev="high" ;;
      S12|S13) sev="medium" ;;
      S5) sev="low" ;;
    esac
    local cluster="${_fe_task}@${session_id:-unknown}"
    local pfile="$ENGINE_DIR/domains/$dom/PITFALLS.md"
    [ -f "$pfile" ] || pfile="$ENGINE_DIR/domains/engine-runtime/PITFALLS.md"
    if [ ! -f "$pfile" ]; then
      mkdir -p "$(dirname "$pfile")" 2>/dev/null || true
      printf '# PITFALLS

## Auto-detected (pending review)

' > "$pfile" 2>/dev/null || true
    fi

    # 去重: seen-keys + PITFALLS 全文
    grep -qF "$dkey" "$_fe_seen" 2>/dev/null && exit 0
    grep -qF "$dkey" "$pfile" 2>/dev/null && exit 0

    # 确保 Auto-detected 区存在
    if ! grep -q '^## Auto-detected' "$pfile" 2>/dev/null; then
      printf '
## Auto-detected (pending review)

' >> "$pfile" 2>/dev/null || true
    fi

    local cand_id ts
    cand_id="CAND-$(date -u +%Y%m%d%H%M%S 2>/dev/null || echo 000)"
    ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)"
    printf -- '- **%s** %s
  - signal: %s
  - severity: %s
  - task: %s
  - domain: %s
  - session: %s
  - date: %s
  - dedup-key: %s
  - status: pending

'       "$cand_id" "$detail" "$sig" "$sev" "$_fe_task" "$dom" "${session_id:-unknown}" "$cluster" "$ts" "$dkey" >> "$pfile" 2>/dev/null || true
    printf '%s
' "$dkey" >> "$_fe_seen" 2>/dev/null || true
  }

  # 确定当前任务的域
  _fe_domain="engine-runtime"
  _fe_card="$ENGINE_DIR/tasks/$_fe_task.md"
  if [ -f "$_fe_card" ]; then
    _fe_dom_line="$(sed -n 's/.*domain:[[:space:]]*\([^|]*\).*/\1/p' "$_fe_card" | head -1 | sed 's/[[:space:]]*$//')"
    [ -n "$_fe_dom_line" ] && _fe_domain="$(printf '%s' "$_fe_dom_line" | cut -d, -f1)"
  fi

  # S5: memory-writeback (code changed but engine memory not written)
  if [ "${code_changed:-0}" -eq 1 ] && [ "${engine_written:-0}" -eq 0 ]; then
    _dk="$(_fe_dedup_key S5 "$_fe_task" "$_fe_domain")"
    _fe_append_candidate "S5" "Code changed but engine memory (CONTEXT/HANDOFF/progress) not written back" "$_fe_domain" "$_dk"
  fi

  # S12: verify-fail (evidence contains status=fail)
  _fe_evid="$ENGINE_DIR/evidence/$_fe_task"
  if [ -d "$_fe_evid" ]; then
    _fe_fails="$(grep -l '"status"[[:space:]]*:[[:space:]]*"fail"' "$_fe_evid"/AC-*.json 2>/dev/null | head -3)"
    if [ -n "$_fe_fails" ]; then
      _fe_ac="$(basename "$(echo "$_fe_fails" | head -1)" .json 2>/dev/null)"
      _dk="$(_fe_dedup_key S12 "$_fe_ac" "$_fe_domain")"
      _fe_append_candidate "S12" "Verify FAIL in $_fe_ac during $_fe_task" "$_fe_domain" "$_dk"
    fi
  fi

  # S13: doctor-fail
  _fe_doc_log="$_fe_cache/session-end-doctor.log"
  if [ -f "$_fe_doc_log" ] && grep -q '^FAIL' "$_fe_doc_log" 2>/dev/null; then
    _fe_fail_check="$(grep '^FAIL' "$_fe_doc_log" 2>/dev/null | head -1 | cut -c1-60)"
    _dk="$(_fe_dedup_key S13 "$_fe_fail_check" "$_fe_domain")"
    _fe_append_candidate "S13" "Doctor FAIL: $_fe_fail_check" "$_fe_domain" "$_dk"
  fi

  # S18: capsule-missing (code+memory changed but no capsule)
  if [ "${code_changed:-0}" -eq 1 ] && [ "${engine_written:-0}" -eq 1 ] && [ "${capsule_written:-0}" -eq 0 ]; then
    _dk="$(_fe_dedup_key S18 "$_fe_task" "$_fe_domain")"
    _fe_append_candidate "S18" "Code and memory changed but no change capsule (CHANGE-*.md) written" "$_fe_domain" "$_dk"
  fi

  exit 0
) || true

exit 0
