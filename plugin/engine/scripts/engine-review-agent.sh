#!/usr/bin/env bash
# Engine System — Agent-Reviewer CLI 入口(v6.21.0)
#
# 两阶段原子命令:
#   engine review-agent T-NNN --package   → 打包审查上下文
#   engine review-agent T-NNN --validate  → 校验 agent 输出
#
# 无模式标志 → exit 2 + usage(与 engine review 风格一致)
# 安全:read-only(package) + evidence 写入(validate);不驱动外部进程。

set -euo pipefail
on_error() { echo "[engine-review-agent] error on line $1 (${BASH_SOURCE[0]})" >&2; exit 1; }
trap 'on_error ${LINENO}' ERR

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
ENGINE_DIR="$ROOT/engine"

usage() {
  cat >&2 <<'EOF'
Usage: engine review-agent T-NNN --package
       engine review-agent T-NNN --validate

Modes (exactly one required):
  --package   Package review context (diff + task card + protocol + challenges)
              Output: engine/review/evidence/T-NNN/review-package.md
  --validate  Validate agent-produced AGENT-REVIEW.json
              Requires: AGENT-REVIEW.json already written by external agent

Exit codes: 0=success | 1=validation failure | 2=usage error
EOF
}

# 解析参数
task=""
mode=""
mode_count=0
while [ $# -gt 0 ]; do
  case "$1" in
    --package) mode="package"; mode_count=$((mode_count + 1)) ;;
    --validate) mode="validate"; mode_count=$((mode_count + 1)) ;;
    T-[0-9]*) task="$1" ;;
    *) echo "[engine-review-agent] Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
  shift
done

if [ "$mode_count" -gt 1 ]; then
  echo "[engine-review-agent] Error: --package and --validate are mutually exclusive" >&2
  usage
  exit 2
fi

if [ -z "$task" ]; then
  echo "[engine-review-agent] Error: task ID required (e.g. T-071)" >&2
  usage
  exit 2
fi

if [ -z "$mode" ]; then
  echo "[engine-review-agent] Error: mode flag required (--package or --validate)" >&2
  usage
  exit 2
fi

task_file="$ENGINE_DIR/tasks/$task.md"
if [ ! -f "$task_file" ]; then
  echo "[engine-review-agent] Error: task card not found: $task_file" >&2
  exit 2
fi

case "$mode" in
  package)
    bash "$ENGINE_DIR/scripts/engine-review-agent-package.sh" "$task"
    ;;
  validate)
    bash "$ENGINE_DIR/scripts/engine-review-agent-validate.sh" "$task"
    ;;
esac
