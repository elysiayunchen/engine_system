#!/usr/bin/env bash
# Engine System — engine-context · "universal context loader"
#
# Agent-agnostic session context dump. Any AI agent (Claude Code, Cursor,
# Copilot, Codex CLI, Gemini CLI, Aider, web chat) can run this command to
# get the full project memory snapshot that Claude Code gets automatically
# via the SessionStart hook.
#
# Usage: engine context          (via CLI shim)
#        bash engine/scripts/engine-context.sh [project_root]
#
# Safety: read-only. No engine writes, no code writes, no network calls.
# Always exits 0 (fail-open).

set -u
log_error() { echo "[engine-context] ERROR: $*" >&2; }

ROOT="${1:-${CLAUDE_PROJECT_DIR:-$PWD}}"
ENGINE_DIR="$ROOT/engine"

if [ ! -d "$ENGINE_DIR" ]; then
  echo "[Engine System] engine/ directory not found in $ROOT."
  echo "Run 'engine init' or 'engine migrate' to set up the project memory layer."
  exit 0
fi

# v6.19.0 (D-038c): Derived Status — real-time computed from git tag + engine/VERSION
# + latest done task evidence. Replaces static "上次完成" declaration with machine-verified view.
# v6.19.0 (D-038d): Trust-level classification (T1/T2/T3) based on evidence multi-anchor fields.
render_derived_status() {
  local latest_tag engine_ver latest_ver head_commit
  local latest_task="" ev_dir first_ac vac=""
  local tag_ver_match="?" has_code_fp="?" vac_match="?" trust="T3"

  latest_tag="$(cd "$ROOT" && git describe --tags --abbrev=0 2>/dev/null || echo 'none')"
  engine_ver="$(cat "$ENGINE_DIR/VERSION" 2>/dev/null | tr -d '[:space:]' || echo 'unknown')"
  latest_ver="${latest_tag#v}"
  head_commit="$(cd "$ROOT" && git rev-parse HEAD 2>/dev/null || echo 'unknown')"

  # Find latest done task (highest T-NNN with status:done, lexicographic for same digit count).
  for f in "$ENGINE_DIR"/tasks/T-*.md; do
    [ -f "$f" ] || continue
    case "$f" in *.spec.md) continue ;; esac
    if grep -Eq '^[[:space:]]*(>[[:space:]]*)?status:[[:space:]]*done' "$f" 2>/dev/null; then
      tid="$(basename "$f" .md)"
      if [ -z "$latest_task" ] || [ "$tid" \> "$latest_task" ]; then
        latest_task="$tid"
      fi
    fi
  done

  # Tag/VERSION consistency.
  if [ "$latest_ver" = "$engine_ver" ]; then
    tag_ver_match="yes"
  else
    tag_ver_match="no"
  fi

  # Evidence trust classification for latest done task.
  if [ -n "$latest_task" ]; then
    ev_dir="$ENGINE_DIR/evidence/$latest_task"
    if [ -d "$ev_dir" ]; then
      first_ac="$(ls "$ev_dir"/AC-*.json 2>/dev/null | LC_ALL=C sort | head -1)"
      if [ -n "$first_ac" ] && [ -f "$first_ac" ]; then
        if grep -q '"code_fingerprint"' "$first_ac" 2>/dev/null; then
          has_code_fp="yes"
          vac="$(printf '%s' "$(grep -oE '"verified_against_commit":"[^"]*"' "$first_ac" 2>/dev/null | head -1)" | sed 's/.*"verified_against_commit":"//;s/"//')"
          # Check if verified_against_commit is HEAD or an ancestor of HEAD (evidence
          # is written before the task's own commit, so vac is typically HEAD~1).
          if [ -n "$vac" ] && [ "$head_commit" != "unknown" ]; then
            if [ "$vac" = "$head_commit" ]; then
              vac_match="yes (==HEAD)"
            elif (cd "$ROOT" && git merge-base --is-ancestor "$vac" "$head_commit" 2>/dev/null); then
              vac_match="yes (ancestor of HEAD)"
            else
              vac_match="no (not ancestor)"
            fi
          else
            vac_match="no (missing vac or HEAD)"
          fi
        else
          has_code_fp="no"
        fi
      fi
    fi
  fi

  # Determine trust level (D-038d).
  # T1 (structural) = code_fingerprint exists + vac is HEAD/ancestor + tag/VERSION match.
  # Full T1 (drift-check green) is only confirmed by Doctor/engine drift-check.
  if [ "$tag_ver_match" = "yes" ] && [ "$has_code_fp" = "yes" ] && case "$vac_match" in yes*) true;; *) false;; esac; then
    trust="T1 (structural; run drift-check to confirm)"
  elif [ "$has_code_fp" = "no" ]; then
    trust="T2 (legacy-evidence: no code_fingerprint)"
  elif case "$vac_match" in no*) true;; *) false;; esac; then
    trust="T2 (stale: verified_against_commit not ancestor of HEAD)"
  elif [ "$tag_ver_match" = "no" ]; then
    trust="T3 (tag/VERSION mismatch)"
  fi

  echo "──── [T1] Derived Status (machine-verified, D-038c) ────"
  echo "Latest git tag: $latest_tag"
  echo "engine/VERSION: $engine_ver"
  echo "Tag/VERSION match: $tag_ver_match"
  echo "Latest done task: ${latest_task:-none}"
  if [ -n "$latest_task" ]; then
    echo "Evidence code_fingerprint: $has_code_fp"
    echo "verified_against_commit == HEAD: $vac_match"
  fi
  echo "Overall trust: [$trust]"
  echo ""
}

echo "═══════════════════════════════════════════════════"
echo " Engine System — Session Context"
echo " Agent: read the sections below to understand"
echo " the current project state before taking action."
echo "═══════════════════════════════════════════════════"
echo ""

# L0 constitution injection (runtime-law.md <=40 lines, top anti-drift anchor).
if [ -f "$ROOT/runtime-law.md" ]; then
  echo "──── ⚖️  L0 Constitution (runtime-law.md) ────"
  sed -n '1,40p' "$ROOT/runtime-law.md" 2>/dev/null
  echo ""
fi

# GLOSSARY injection — agent must use Plain meaning column with developer.
glossary="$ENGINE_DIR/GLOSSARY.md"
if [ -f "$glossary" ]; then
  echo "──── 📖 Glossary (engine/GLOSSARY.md) ────"
  echo "When communicating with the developer, use the Plain meaning column."
  echo "Match the developer's language. Full glossary: engine/GLOSSARY.md"
  echo ""
fi

# CONTEXT.md — current project status dashboard with trust-level labels (D-038d).
if [ -f "$ENGINE_DIR/CONTEXT.md" ]; then
  echo "──── 📊 Current State (engine/CONTEXT.md, first 50 lines) ────"
  echo "Trust levels: [T1]=machine-verified | [T2]=declared-only/legacy | [T3]=unverified"
  echo ""
  # Inject trust labels per section header (D-038d).
  sed -n '1,50p' "$ENGINE_DIR/CONTEXT.md" 2>/dev/null | while IFS= read -r line; do
    printf '%s\n' "$line"
    case "$line" in
      "## 状态面板"*)
        printf '> [T2 legacy] 静态声明 (double-write transition). 见下方 Derived Status 段获取 [T1] 机器校验值.\n' ;;
      "## 当前假设"*)
        printf '> [T2 declared-only] 人工决策声明,未经机器校验.\n' ;;
      "## 待验证"*)
        printf '> [T3 unverified] 待验证项,agent 须先跑校验或显式声明"未验证".\n' ;;
    esac
  done
  echo ""
fi

# Derived Status segment (D-038c) — machine-verified, real-time computed.
render_derived_status

# HANDOFF.md — latest session handoff records.
if [ -f "$ENGINE_DIR/HANDOFF.md" ]; then
  echo "──── 🔀 Last Handoff (engine/HANDOFF.md, newest first) ────"
  grep -m 4 '^|' "$ENGINE_DIR/HANDOFF.md" 2>/dev/null
  echo ""
fi

# Domain dashboard — one-line summary per domain from federation.json.
fed="$ENGINE_DIR/domains/federation.json"
if [ -f "$fed" ]; then
  echo "──── 🗺️  Domain Dashboard (federation.json) ────"
  awk '
    /^[[:space:]]*"[A-Za-z0-9_-]+"[[:space:]]*:[[:space:]]*\{/ { if (match($0, /"([A-Za-z0-9_-]+)"/, m)) { domain=m[1]; next } }
    /"summary"/ { if (match($0, /"summary"[[:space:]]*:[[:space:]]*"([^"]+)"/, m)) print "• " domain ": " m[1]; next }
  ' "$fed" 2>/dev/null
  echo ""
fi

# Active task cards — core anti-drift anchor.
# v6.12.0 (D-035): multiple active cards may run in parallel (one per session);
# show up to 3 in full, headers beyond.
active_task=""
active_count=0
active_ids=""
for f in "$ENGINE_DIR"/tasks/T-*.md; do
  [ -f "$f" ] || continue
  case "$f" in *.spec.md) continue ;; esac
  grep -Eq '^[[:space:]]*(>[[:space:]]*)?status:[[:space:]]*active' "$f" 2>/dev/null || continue
  task_id="$(basename "$f" .md)"
  active_count=$((active_count + 1))
  active_ids="${active_ids:+$active_ids, }$task_id"
  [ -n "$active_task" ] || active_task="$f"
  if [ "$active_count" -le 3 ]; then
    echo "──── 🎯 Active Task Card ($task_id) ────"
    echo "Every project path, including engine/*, MUST be covered by some active card's WRITE-SET (union gating) and outside that card's FORBIDDEN."
    cat "$f" 2>/dev/null || log_error "failed to read active task card: $f"
    echo ""
  else
    echo "──── 🎯 Additional active card: $task_id (read engine/tasks/$task_id.md) ────"
    echo ""
  fi
done
if [ "$active_count" -eq 0 ]; then
  echo "──── 🎯 Active Task Card: none ────"
  echo "contract-version 6.5+ blocks ordinary writes until engine/tasks/T-NNN.md is created or activated. Completion requires: engine verify T-NNN."
  echo ""
elif [ "$active_count" -gt 1 ]; then
  echo "Multi-card parallel ($active_ids): work under ONE card; write only inside YOUR card's WRITE-SET."
  echo ""
fi

# v6.11.0 (D-029/T-036) AC-5: Active Sessions 面板
# 数据源 1: engine/.cache/session.lock (协调者: pid|sid|role|started_at|task_id)
# 数据源 2: engine/.cache/sessions/*.meta (workers: role|stopped_at|task_id)
# 数据源 3: engine/.cache/sessions/*.role=worker (降级标记, 无 .meta 显示 degraded)
lock_file_ctx="$ENGINE_DIR/.cache/session.lock"
sessions_dir_ctx="$ENGINE_DIR/.cache/sessions"
if [ -f "$lock_file_ctx" ] || [ -d "$sessions_dir_ctx" ]; then
  echo "──── 👥 Active Sessions ────"
  # Coordinator (from lock file)
  if [ -f "$lock_file_ctx" ]; then
    lock_line_ctx="$(cat "$lock_file_ctx" 2>/dev/null || true)"
    if [ -n "$lock_line_ctx" ]; then
      c_pid="$(printf '%s' "$lock_line_ctx" | cut -d'|' -f1)"
      c_sid="$(printf '%s' "$lock_line_ctx" | cut -d'|' -f2)"
      c_started="$(printf '%s' "$lock_line_ctx" | cut -d'|' -f4)"
      c_task="$(printf '%s' "$lock_line_ctx" | cut -d'|' -f5)"
      c_sid_short="${c_sid:0:8}"
      printf 'Coordinator: pid=%s sid=%s started=%s task=%s\n' "$c_pid" "$c_sid_short" "$c_started" "${c_task:-none}"
    fi
  else
    echo "Coordinator: none (single-session mode)"
  fi
  # Workers (from .meta files; role=coordinator entries are exited coordinators, skip)
  if [ -d "$sessions_dir_ctx" ]; then
    for meta_ctx in "$sessions_dir_ctx"/*.meta; do
      [ -f "$meta_ctx" ] || continue
      meta_line_ctx="$(cat "$meta_ctx" 2>/dev/null || true)"
      [ -n "$meta_line_ctx" ] || continue
      m_role="$(printf '%s' "$meta_line_ctx" | cut -d'|' -f1)"
      m_stopped="$(printf '%s' "$meta_line_ctx" | cut -d'|' -f2)"
      m_task="$(printf '%s' "$meta_line_ctx" | cut -d'|' -f3)"
      w_key="$(basename "$meta_ctx" .meta)"
      w_key_short="${w_key:0:8}"
      if [ "$m_role" = "worker" ]; then
        printf 'Worker %s: stopped=%s task=%s\n' "$w_key_short" "$m_stopped" "${m_task:-none}"
      fi
    done
    # Degraded workers (.role=worker marker without matching .meta)
    for role_marker in "$sessions_dir_ctx"/*.role=worker; do
      [ -f "$role_marker" ] || continue
      r_key="$(basename "$role_marker" .role=worker)"
      r_key_short="${r_key:0:8}"
      if [ ! -f "$sessions_dir_ctx/$r_key.meta" ]; then
        printf 'Worker %s: degraded (no .meta)\n' "$r_key_short"
      fi
    done
  fi
  echo ""
fi

# Unmerged worker shards. Keep this dashboard compact; full shard content is read on demand.
# v6.11.1 (D-029/T-038) AC-5: support two-level agents/a-<id>/ and sessions/s-<id>/ layouts.
if [ -n "$active_task" ]; then
  workstream_root="$ENGINE_DIR/workstreams/$task_id"
  if [ -d "$workstream_root" ]; then
    found_workstream=0
    # Find CONTEXT.md anywhere under workstream_root (handles legacy flat + new agents/sessions trees).
    while IFS= read -r ctx; do
      [ -f "$ctx" ] || continue
      if [ "$found_workstream" -eq 0 ]; then
        echo "──── Parallel Workstreams (unmerged) ────"
        found_workstream=1
      fi
      owner="$(basename "$(dirname "$ctx")")"
      # Strip a-/s- prefix added in v6.11.1 for display only.
      owner="${owner#a-}"
      owner="${owner#s-}"
      state="$(grep -m 1 '^>' "$ctx" 2>/dev/null)"
      progress="$(awk '/^## Progress/{on=1;next} on && /^-[[:space:]]/{print;exit}' "$ctx" 2>/dev/null)"
      echo "* $owner: ${state#> } ${progress:+| $progress}"
    done < <(find "$workstream_root" -name CONTEXT.md -type f 2>/dev/null)
    [ "$found_workstream" -eq 0 ] || echo ""
  fi
fi

# L2 domain assembly — CONTEXT + PITFALLS for each domain in the task card.
if [ -n "$active_task" ] && [ -f "$fed" ]; then
  task_domains_l2="$(grep '^>.*domain:' "$active_task" 2>/dev/null | head -1 | sed 's/.*domain:[[:space:]]*//' | sed 's/|.*//' | tr -d ' ')"
  if [ -n "$task_domains_l2" ]; then
    saved_IFS="$IFS"; IFS=','
    for dom in $task_domains_l2; do
      [ -n "$dom" ] || continue
      dom_ctx="$ENGINE_DIR/domains/$dom/CONTEXT.md"
      dom_pit="$ENGINE_DIR/domains/$dom/PITFALLS.md"
      if [ -f "$dom_ctx" ] || [ -f "$dom_pit" ]; then
        echo "──── 📦 L2 Domain: $dom ────"
        [ -f "$dom_ctx" ] && sed -n '1,50p' "$dom_ctx" 2>/dev/null
        [ -f "$dom_pit" ] && sed -n '1,40p' "$dom_pit" 2>/dev/null
        echo ""
      fi
    done
    IFS="$saved_IFS"
  fi
fi

# Pending decisions queue.
proposed_count=0
for f in "$ENGINE_DIR"/decisions/D-*.md; do
  [ -f "$f" ] || continue
  if grep -Eq '^[[:space:]]*(>[[:space:]]*)?status:[[:space:]]*proposed' "$f" 2>/dev/null; then
    if [ "$proposed_count" -eq 0 ]; then
      echo "──── ⏳ Pending Decisions (proposed) ────"
    fi
    head -3 "$f" 2>/dev/null
    echo ""
    proposed_count=$((proposed_count + 1))
  fi
done

# Previous session pending notes (from SessionEnd hook).
if [ -f "$ENGINE_DIR/.cache/pending.txt" ]; then
  echo "──── ⚠️  Pending from Previous Session ────"
  cat "$ENGINE_DIR/.cache/pending.txt" 2>/dev/null
  echo ""
fi

# Update check (read from cache, non-blocking).
cache="$ENGINE_DIR/.cache/update-check.json"
if [ -f "$cache" ]; then
  norm_v() {
    v="$(printf '%s' "${1:-}" | tr -d '[:space:]')"
    case "$v" in ''|*[!0-9.]*) printf '%s' "$v"; return ;; esac
    case "$v" in *.*.*) ;; *.*) v="$v.0" ;; *) v="$v.0.0" ;; esac
    printf '%s' "$v"
  }
  latest="$(grep -oE '"latest":[[:space:]]*"[^"]*"' "$cache" 2>/dev/null | head -1 | sed 's/.*"latest":[[:space:]]*"//;s/"//')"
  current="$(grep -oE '"current":[[:space:]]*"[^"]*"' "$cache" 2>/dev/null | head -1 | sed 's/.*"current":[[:space:]]*"//;s/"//')"
  if [ -n "$latest" ] && [ "$latest" != "" ] && [ "$(norm_v "$latest")" != "$(norm_v "$current")" ]; then
    echo "──── 🔄 Engine Update Available ────"
    echo "Local $current -> Remote $latest. Run: engine update"
    echo ""
  fi
fi

echo "═══════════════════════════════════════════════════"
echo " End of Engine System context."
echo " Key files: engine/ENGINE_MAP.md (index)"
echo "            engine/CONTEXT.md    (current state)"
echo "            engine/HANDOFF.md    (session history)"
echo "═══════════════════════════════════════════════════"

exit 0
