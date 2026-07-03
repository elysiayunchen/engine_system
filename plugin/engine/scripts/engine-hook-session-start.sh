#!/usr/bin/env bash
# Engine System — SessionStart hook · "自动接手 / auto-handoff"
#
# 在新会话开始时读取项目记忆,把状态摘要打到 stdout 注入 agent 上下文,
# 让 agent 无需架构师重新介绍即可接手上次的工作。
#
# v6 S1: 始终注入 active 任务卡。压缩后(compact)/恢复(resume)是漂移最危险
# 的时刻——任务卡把 GOAL/WRITE-SET/FORBIDDEN 重新打到 agent 眼前,锚住意图。
#
# 安全契约:只读。不写引擎文件、不碰代码、不联网。任何失败都绝不致命(始终 exit 0)。
# 触发:SessionStart(新会话 / --resume / /clear / 自动压缩后)。

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
ENGINE_DIR="$ROOT/engine"

if [ ! -d "$ENGINE_DIR" ]; then
  echo "【Engine System】未检测到 engine/ 目录。建议运行 /engine-init 生成项目记忆层。"
  exit 0
fi

echo "【Engine System · 自动接手】下面是项目记忆当前快照。请先用一句简体中文复述当前状态,再开始工作。"
echo ""

if [ -f "$ENGINE_DIR/CONTEXT.md" ]; then
  echo "──── 当前状态 (engine/CONTEXT.md) ────"
  sed -n '1,50p' "$ENGINE_DIR/CONTEXT.md" 2>/dev/null
  echo ""
fi

if [ -f "$ENGINE_DIR/HANDOFF.md" ]; then
  echo "──── 上次交接 (engine/HANDOFF.md，最新在上) ────"
  grep -m 4 '^|' "$ENGINE_DIR/HANDOFF.md" 2>/dev/null
  echo ""
fi

# v6 S2: 域仪表盘(汇总协议)——每个域一句话摘要,根文件规模 = O(域数),不是 O(仓库)。
fed="$ENGINE_DIR/domains/federation.json"
if [ -f "$fed" ]; then
  echo "──── 🗺️ 域仪表盘 (federation) ────"
  awk '
    /^[[:space:]]*"[A-Za-z0-9_-]+"[[:space:]]*:[[:space:]]*\{/ { if (match($0, /"([A-Za-z0-9_-]+)"/, m)) { domain=m[1]; next } }
    /"summary"/ { if (match($0, /"summary"[[:space:]]*:[[:space:]]*"([^"]+)"/, m)) print "• " domain ": " m[1]; next }
  ' "$fed" 2>/dev/null
  echo ""
fi

# v6 S1: active 任务卡重注入——对抗漂移的核心锚点。
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
  echo "──── 🎯 当前任务卡 ($task_id) ────"
  echo "⚠️ 你的所有代码改动必须在 WRITE-SET 内;FORBIDDEN 是架构师否决权,碰了即被拦截。"
  cat "$active_task" 2>/dev/null
  echo ""
fi

# v6 S2: L2 所属域装配——按 active 任务卡 domain 拉取对应域的 CONTEXT+PITFALLS(各受预算约束)。
if [ -n "$active_task" ] && [ -f "$fed" ]; then
  task_domains_l2="$(grep '^>.*domain:' "$active_task" 2>/dev/null | head -1 | sed 's/.*domain:[[:space:]]*//' | sed 's/|.*//' | tr -d ' ')"
  if [ -n "$task_domains_l2" ]; then
    saved_IFS="$IFS"; IFS=','
    for dom in $task_domains_l2; do
      [ -n "$dom" ] || continue
      dom_ctx="$ENGINE_DIR/domains/$dom/CONTEXT.md"
      dom_pit="$ENGINE_DIR/domains/$dom/PITFALLS.md"
      if [ -f "$dom_ctx" ] || [ -f "$dom_pit" ]; then
        echo "──── 📦 L2 域: $dom ────"
        [ -f "$dom_ctx" ] && sed -n '1,50p' "$dom_ctx" 2>/dev/null
        [ -f "$dom_pit" ] && sed -n '1,40p' "$dom_pit" 2>/dev/null
        echo ""
      fi
    done
    IFS="$saved_IFS"
  fi
fi

# 「等你拍板」队列:proposed 决策,提示架构师需要拍板。
proposed_count=0
for f in "$ENGINE_DIR"/decisions/D-*.md; do
  [ -f "$f" ] || continue
  if grep -q 'status:.*proposed' "$f" 2>/dev/null; then
    if [ "$proposed_count" -eq 0 ]; then
      echo "──── ⏳ 等你拍板 (proposed 决策) ────"
    fi
    head -3 "$f" 2>/dev/null
    echo ""
    proposed_count=$((proposed_count + 1))
  fi
done

# SessionEnd hook 会把遗留待办/Doctor 结果写到这里，由本钩子读出。
if [ -f "$ENGINE_DIR/.cache/pending.txt" ]; then
  echo "──── ⚠️ 上次会话遗留待办 ────"
  cat "$ENGINE_DIR/.cache/pending.txt" 2>/dev/null
  echo ""
fi

exit 0
