#!/usr/bin/env bash
# Engine System — Review CLI 入口(v6.20.0)
#
# 跑 post-task 代码 review(semgrep + eslint),产 REVIEW/SECURITY/QUALITY evidence。
# 必须在 engine verify T-NNN PASS 之后调用。
#
# 用法:bash engine/scripts/engine-review.sh T-NNN
# 安全:review 命令由任务卡声明(作为 AC verify 命令);用户主动跑,非 hook 自动。
#       evidence 写入 engine/review/evidence/T-NNN/(protected + provenance 校验在 T-NNN+1 加)。

set -euo pipefail
on_error() { echo "[engine-review] error on line $1 (${BASH_SOURCE[0]})" >&2; exit 1; }
trap 'on_error ${LINENO}' ERR

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
ENGINE_DIR="$ROOT/engine"
task="${1:-}"

if [ -z "$task" ]; then
  echo "Usage: engine review T-NNN" >&2
  exit 2
fi

if [ ! -f "$ENGINE_DIR/tasks/$task.md" ]; then
  echo "[engine-review] Error: task card not found: $ENGINE_DIR/tasks/$task.md" >&2
  exit 2
fi

bash "$ENGINE_DIR/scripts/engine-review-pipeline.sh" "$task"
