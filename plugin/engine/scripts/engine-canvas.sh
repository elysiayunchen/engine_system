#!/usr/bin/env bash
# Engine System — Mermaid 任务状态画布(v6.25.0 / T-082)
#
# 纯证据派生，无 LLM，无持久化（view not state）。
# 从 engine/evidence/T-NNN/AC-N.json 实时读取状态，生成 Mermaid flowchart。
#
# 用法:
#   bash engine/scripts/engine-canvas.sh [T-NNN]
#   --guard   输出一行摘要（CANVAS: T-NNN M/N AC PASS）
#   无参数    对所有 active 任务生成画布
#
# 集成点: SessionStart（Active Task Card 之后）、Guard（一行摘要）
# 安全: fail-open，任何错误静默退出 0。

set -u

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
ENGINE_DIR="$ROOT/engine"
MODE="${1:-full}"

# fail-open: 任何未预期错误不阻断宿主 hook
trap 'exit 0' ERR

[ -d "$ENGINE_DIR" ] || exit 0

# ─── 辅助函数 ───────────────────────────────────────────────

# 从 AC-N.json 提取 status 字段（纯 sed，不依赖 jq）
ac_status() {
  local file="$1"
  [ -f "$file" ] || { echo "none"; return; }
  sed -n 's/.*"status"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$file" | head -1
}

# 从任务卡提取 GOAL 段第一行（截断 80 字符）
extract_goal() {
  local card="$1" goal_line
  goal_line="$(sed -n '/^## GOAL/,/^## /{/^## GOAL/d;/^## /d;/^$/d;p;}' "$card" | head -1)"
  printf '%s' "${goal_line:0:80}"
}

# 从任务卡提取 AC 编号列表（复用 engine-verify 的 4 种格式）
extract_ac_ids() {
  local card="$1"
  # Format 1: AC: AC-N ... | verify:
  grep -oE 'AC-[A-Za-z]*[0-9]+(\.[0-9]+)*' "$card" 2>/dev/null | sort -t'-' -k2 -V | uniq
}

# 从 GATE.json 提取 status
gate_status() {
  local task="$1" gate_file="$ENGINE_DIR/evidence/$1/GATE.json"
  [ -f "$gate_file" ] || { echo "none"; return; }
  sed -n 's/.*"status"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$gate_file" | head -1
}

# ─── 画布生成 ───────────────────────────────────────────────

generate_canvas() {
  local task="$1"
  local card="$ENGINE_DIR/tasks/$task.md"
  local evidence_dir="$ENGINE_DIR/evidence/$task"
  local goal card_status g_status

  [ -f "$card" ] || return 0

  # 卡片状态
  # 兼容两种格式: "status: active" 和 "> status: active | lane: ..."
  card_status="$(sed -n 's/^>[[:space:]]*status:[[:space:]]*\([^|]*\).*/\1/p' "$card" | head -1 | sed 's/[[:space:]]*$//')"
  [ -n "$card_status" ] || card_status="$(sed -n 's/^status:[[:space:]]*//p' "$card" | head -1)"
  goal="$(extract_goal "$card")"
  g_status="$(gate_status "$task")"

  # 收集 AC 列表
  local ac_ids
  ac_ids="$(extract_ac_ids "$card")"
  [ -n "$ac_ids" ] || return 0

  local total=0 pass_count=0
  local nodes="" styles="" edges="" prev_id=""
  local first_todo_found=0
  local idx=0

  while IFS= read -r ac_id; do
    [ -n "$ac_id" ] || continue
    idx=$((idx + 1))
    total=$((total + 1))

    local status_file="$evidence_dir/$ac_id.json"
    local raw_status node_status color summary

    raw_status="$(ac_status "$status_file")"
    case "$raw_status" in
      pass)
        node_status="done"
        color="#9f9"
        pass_count=$((pass_count + 1))
        # 提取时间戳作摘要
        local ts
        ts="$(sed -n 's/.*"timestamp"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$status_file" 2>/dev/null | head -1)"
        summary="PASS"
        [ -n "$ts" ] && summary="PASS @ ${ts:0:10}"
        ;;
      fail)
        node_status="blocked"
        color="#f99"
        summary="FAIL"
        ;;
      blocked)
        node_status="blocked"
        color="#f99"
        summary="blocked"
        ;;
      *)
        # todo — 第一个 todo（前面全是 done）推断为 doing
        if [ "$first_todo_found" -eq 0 ]; then
          first_todo_found=1
          # 检查是否前面全是 done（pass_count == idx-1）
          if [ "$pass_count" -eq $((idx - 1)) ] && [ "$pass_count" -gt 0 ]; then
            node_status="doing"
            color="#ff9"
            summary="in progress"
          else
            node_status="todo"
            color="#f9f"
            summary="no evidence"
          fi
        else
          node_status="todo"
          color="#f9f"
          summary="no evidence"
        fi
        ;;
    esac

    local node_id="AC${idx}"
    # 节点文本（Mermaid 内不能有无转义双引号）
    local label="$ac_id<br/>status: $node_status<br/>summary: $summary"
    nodes="${nodes}    ${node_id}[\"${label}\"]\n"
    styles="${styles}    style ${node_id} fill:${color},stroke:#333\n"

    # 边
    if [ -n "$prev_id" ]; then
      edges="${edges}    ${prev_id} --> ${node_id}\n"
    fi
    prev_id="$node_id"
  done <<< "$ac_ids"

  [ "$total" -gt 0 ] || return 0

  # >8 AC 时纵向布局
  local direction="LR"
  [ "$total" -gt 8 ] && direction="TD"

  # 输出 Mermaid
  printf '%%%%{taskGoal: "%s", progress: "%d/%d", cardStatus: "%s", gateStatus: "%s"}%%%%\n' \
    "$goal" "$pass_count" "$total" "$card_status" "$g_status"
  printf 'graph %s\n' "$direction"
  printf '%b' "$nodes"
  printf '%b' "$edges"
  printf '%b' "$styles"
}

# ─── Guard 一行摘要 ─────────────────────────────────────────

generate_guard_summary() {
  local task="$1"
  local card="$ENGINE_DIR/tasks/$task.md"
  local evidence_dir="$ENGINE_DIR/evidence/$task"

  [ -f "$card" ] || return 0

  local ac_ids total=0 pass_count=0
  ac_ids="$(extract_ac_ids "$card")"
  [ -n "$ac_ids" ] || return 0

  while IFS= read -r ac_id; do
    [ -n "$ac_id" ] || continue
    total=$((total + 1))
    local raw_status
    raw_status="$(ac_status "$evidence_dir/$ac_id.json")"
    [ "$raw_status" = "pass" ] && pass_count=$((pass_count + 1))
  done <<< "$ac_ids"

  echo "CANVAS: $task $pass_count/$total AC PASS"
}

# ─── 主入口 ─────────────────────────────────────────────────

find_active_tasks() {
  local f task_id
  for f in "$ENGINE_DIR"/tasks/T-*.md; do
    [ -f "$f" ] || continue
    task_id="$(basename "$f" .md)"
    if grep -q '^status:[[:space:]]*active' "$f" 2>/dev/null; then
      echo "$task_id"
    fi
  done
}

case "$MODE" in
  --guard)
    # 一行摘要模式
    tasks="$(find_active_tasks)"
    [ -n "$tasks" ] || exit 0
    while IFS= read -r t; do
      generate_guard_summary "$t"
    done <<< "$tasks"
    ;;
  T-*)
    # 指定任务
    echo '```mermaid'
    generate_canvas "$MODE"
    echo '```'
    ;;
  *)
    # 全部 active 任务
    tasks="$(find_active_tasks)"
    [ -n "$tasks" ] || exit 0
    while IFS= read -r t; do
      echo '```mermaid'
      generate_canvas "$t"
      echo '```'
      echo ""
    done <<< "$tasks"
    ;;
esac

exit 0
