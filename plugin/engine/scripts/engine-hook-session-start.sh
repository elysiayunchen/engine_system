#!/usr/bin/env bash
# Engine System — SessionStart hook · "自动接手 / auto-handoff"
#
# 在新会话开始时读取项目记忆,把状态摘要打到 stdout 注入 agent 上下文,
# 让 agent 无需架构师重新介绍即可接手上次的工作。
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

# SessionEnd hook（后续阶段实现）会把遗留待办/Doctor 结果写到这里，由本钩子读出。
if [ -f "$ENGINE_DIR/.cache/pending.txt" ]; then
  echo "──── ⚠️ 上次会话遗留待办 ────"
  cat "$ENGINE_DIR/.cache/pending.txt" 2>/dev/null
  echo ""
fi

exit 0
