#!/usr/bin/env bash
# Engine System — 行为化验收器(v6 S4)
#
# 执行任务卡 AC 的 verify 命令,PASS/FAIL + 输出指纹(sha256)写入
# engine/evidence/T-NNN/AC-N.json。完成 N3(完成有证据)的机器化——
# 架构师判断行为而非代码,done 门 = verify 全绿 或 架构师明示豁免。
#
# 用法:bash engine/scripts/engine-verify.sh T-NNN
# 安全:verify 命令由任务卡声明,架构师批准任务卡时即批准 verify。用户主动跑,非 hook 自动。

set -euo pipefail
on_error() { echo "[engine-verify] error on line $1 (${BASH_SOURCE[0]})" >&2; exit 1; }
trap 'on_error ${LINENO}' ERR
ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
ENGINE_DIR="$ROOT/engine"
task="${1:-}"

if [ -z "$task" ]; then
  echo "Usage: engine verify T-NNN" >&2
  exit 2
fi

task_file="$ENGINE_DIR/tasks/$task.md"
if [ ! -f "$task_file" ]; then
  echo "Error: 任务卡不存在: $task_file" >&2
  exit 2
fi

evidence_dir="$ENGINE_DIR/evidence/$task"
mkdir -p "$evidence_dir"

pass_count=0
fail_count=0
skip_count=0

echo "【Engine System · 行为化验收】$task"
echo ""

while IFS= read -r line; do
  ac_id="$(printf '%s' "$line" | sed -n 's/^AC:[[:space:]]*\(AC-[0-9]*\).*/\1/p')"
  [ -n "$ac_id" ] || continue
  verify_cmd="$(printf '%s' "$line" | sed -n 's/.*verify:[[:space:]]*\(.*\)[[:space:]]*$/\1/p')"
  if [ -z "$verify_cmd" ]; then
    echo "SKIP  $ac_id (无 verify 命令)"
    skip_count=$((skip_count+1))
    continue
  fi
  echo "── $ac_id ──"
  echo "verify: $verify_cmd"
  tmp_out="$(mktemp)"
  rc=0
  ( cd "$ROOT" && eval "$verify_cmd" ) >"$tmp_out" 2>&1 || rc=$?
  rc=${rc:-0}
  fp="$(sha256sum "$tmp_out" | cut -d' ' -f1)"
  if [ "$rc" -eq 0 ]; then
    status="pass"; pass_count=$((pass_count+1))
    echo "PASS  (exit=0, fp=${fp:0:12})"
  else
    status="fail"; fail_count=$((fail_count+1))
    echo "FAIL  (exit=$rc, fp=${fp:0:12})"
    sed -n '1,5p' "$tmp_out" 2>/dev/null
  fi
  verify_escaped="$(printf '%s' "$verify_cmd" | sed 's/\\/\\\\/g; s/"/\\"/g')"
  printf '{"ac":"%s","verify":"%s","status":"%s","exit":%d,"fingerprint":"sha256:%s","timestamp":"%s"}\n' \
    "$ac_id" "$verify_escaped" "$status" "$rc" "$fp" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    > "$evidence_dir/$ac_id.json"
  rm -f "$tmp_out"
done < <(grep '^AC:' "$task_file")

echo ""
echo "=========================================="
echo "$task: $pass_count pass, $fail_count fail, $skip_count skip"
[ "$fail_count" -eq 0 ]
