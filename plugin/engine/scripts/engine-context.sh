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

# CONTEXT.md — current project status dashboard.
if [ -f "$ENGINE_DIR/CONTEXT.md" ]; then
  echo "──── 📊 Current State (engine/CONTEXT.md, first 50 lines) ────"
  sed -n '1,50p' "$ENGINE_DIR/CONTEXT.md" 2>/dev/null
  echo ""
fi

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

# Active task card — core anti-drift anchor.
active_task=""
for f in "$ENGINE_DIR"/tasks/T-*.md; do
  [ -f "$f" ] || continue
  if grep -q 'status:.*active' "$f" 2>/dev/null; then
    active_task="$f"
    break
  fi
done
if [ -n "$active_task" ]; then
  task_id="$(basename "$active_task" .md)"
  echo "──── 🎯 Active Task Card ($task_id) ────"
  echo "Every project path, including engine/*, MUST be within WRITE-SET and outside FORBIDDEN."
  cat "$active_task" 2>/dev/null || log_error "failed to read active task card: $active_task"
  echo ""
else
  echo "──── 🎯 Active Task Card: none ────"
  echo "contract-version 6.5+ blocks ordinary writes until engine/tasks/T-NNN.md is created or activated. Completion requires: engine verify T-NNN."
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
if [ -n "$active_task" ]; then
  workstream_root="$ENGINE_DIR/workstreams/$task_id"
  if [ -d "$workstream_root" ]; then
    found_workstream=0
    for ctx in "$workstream_root"/*/CONTEXT.md; do
      [ -f "$ctx" ] || continue
      if [ "$found_workstream" -eq 0 ]; then
        echo "──── Parallel Workstreams (unmerged) ────"
        found_workstream=1
      fi
      owner="$(basename "$(dirname "$ctx")")"
      state="$(grep -m 1 '^>' "$ctx" 2>/dev/null)"
      progress="$(awk '/^## Progress/{on=1;next} on && /^-[[:space:]]/{print;exit}' "$ctx" 2>/dev/null)"
      echo "* $owner: ${state#> } ${progress:+| $progress}"
    done
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
  if grep -q 'status:.*proposed' "$f" 2>/dev/null; then
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
