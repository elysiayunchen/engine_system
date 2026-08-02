#!/usr/bin/env bash
# Engine System — Gate: 质量门禁聚合器 (v6.24.0)
#
# 聚合 verify/review/review-agent/prove 各门禁证据 → 写 GATE.json
# 二元退出码: 0=全部通过(可标 done) / 1=存在失败或待跑门禁
#
# 用法:
#   engine gate T-NNN          聚合当前证据状态 → 写 GATE.json
#   engine gate T-NNN --run    对 pending 门禁依次执行后聚合
#
# 证据: engine/evidence/T-NNN/GATE.json
# 安全: flock 防并发; provenance 写入; 工具缺失 → skipped(不 block)

set -euo pipefail
on_error() { echo "[engine-gate] error on line $1 (${BASH_SOURCE[0]})" >&2; exit 1; }
trap 'on_error ${LINENO}' ERR

# python3 检测
if command -v python3 >/dev/null 2>&1; then
  PY=python3
elif command -v python >/dev/null 2>&1; then
  PY=python
else
  echo "[engine-gate] Error: python3/python not found (required for JSON parsing)" >&2
  exit 2
fi

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
ENGINE_DIR="$ROOT/engine"
task_card_script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$task_card_script_dir/engine-task-card.sh" ]; then
  # Shared AC/WRITE-SET grammar.  The fallback below keeps older copied test
  # fixtures executable while they migrate to the distributed helper.
  # shellcheck source=/dev/null
  . "$task_card_script_dir/engine-task-card.sh"
fi
task=""
run_mode=0

# 参数解析
for arg in "$@"; do
  case "$arg" in
    --run) run_mode=1 ;;
    T-[0-9]*) task="$arg" ;;
    *) echo "[engine-gate] Unknown argument: $arg" >&2; exit 2 ;;
  esac
done

if [ -z "$task" ]; then
  echo "[engine-gate] Usage: engine gate T-NNN [--run]" >&2
  exit 2
fi

task_file="$ENGINE_DIR/tasks/$task.md"
if [ ! -f "$task_file" ]; then
  echo "[engine-gate] Error: task card not found: $task_file" >&2
  exit 2
fi

# Evidence must tell a real CLI invocation from a direct script call. The
# latter remains supported for tests/maintenance, but is never mislabeled as
# `engine gate`.
gate_argv="${ENGINE_CLI_ENTRYPOINT:-engine-gate.sh $*}"

# 0. flock 防并发
mkdir -p "$ENGINE_DIR/evidence/$task"
if command -v flock >/dev/null 2>&1; then
  exec 200>"$ENGINE_DIR/evidence/.gate-lock.$task"
  if ! flock -n 200; then
    echo "[engine-gate] another gate check running for $task" >&2
    exit 1
  fi
else
  lockdir="$ENGINE_DIR/evidence/.gate-lock.$task.d"
  if ! mkdir "$lockdir" 2>/dev/null; then
    echo "[engine-gate] another gate check running for $task" >&2
    exit 1
  fi
  trap 'rmdir "$lockdir" 2>/dev/null' EXIT
fi

# 1. 读 gate config (L0 defaults + L1 overrides)
config_file="$ENGINE_DIR/gate/config.json"
if [ ! -f "$config_file" ]; then
  echo "[engine-gate] Error: gate config not found: $config_file" >&2
  exit 2
fi

config_data=$("$PY" -c "
import json, sys
with open(sys.argv[1], encoding='utf-8') as f:
    cfg = json.load(f)
d = cfg.get('defaults', {})
o = cfg.get('overrides', {})
merged = {**d, **o}
print(json.dumps(merged))
" "$config_file")

# 提取配置字段
gates_list=$(echo "$config_data" | "$PY" -c "import json,sys; print(' '.join(json.load(sys.stdin).get('gates',['verify','review','review_agent','prove'])))")
code_extensions=$(echo "$config_data" | "$PY" -c "import json,sys; print(' '.join(json.load(sys.stdin).get('code_extensions',['.sh','.py','.js'])))")
docs_only_skip=$(echo "$config_data" | "$PY" -c "import json,sys; print(' '.join(json.load(sys.stdin).get('docs_only_skip',['review','review_agent','prove'])))")

# 2. 判断 WRITE-SET 是否含代码文件
has_code=0
if declare -F task_card_parse_patterns >/dev/null 2>&1; then
  write_set_paths="$(task_card_parse_patterns WRITE-SET "$task_file" | tr ',' '\n')"
else
  write_set_paths=$("$PY" -c "
import sys, re
with open(sys.argv[1], encoding='utf-8') as f:
    content = f.read()
m = re.search(r'^## WRITE-SET\s*\n(.*?)(?=^## |\Z)', content, re.M | re.S)
if m:
    for line in m.group(1).strip().split('\n'):
        line = line.strip()
        if line.startswith('- '):
            print(line[2:].strip())
" "$task_file")
fi

# Fast path: check path string extensions directly
while IFS= read -r p; do
  p="${p%%(*}"
  p="${p%%\[*}"
  p="${p%"${p##*[![:space:]]}"}"
  p="${p#"${p%%[![:space:]]*}"}"
  [ -n "$p" ] || continue
  ext=".${p##*.}"
  for ce in $code_extensions; do
    if [ "$ext" = "$ce" ]; then
      has_code=1
      break 2
    fi
  done
done <<< "$write_set_paths"

# Fallback: expand WRITE-SET paths on disk (covers new files, dirs, globs, annotations)
if [ "$has_code" -eq 0 ] && [ -n "$write_set_paths" ]; then
  has_code=$("$PY" -c "
import sys, os, glob

root = sys.argv[1]
paths_str = sys.argv[2]
code_exts = set(sys.argv[3].split())

paths = [p.strip() for p in paths_str.strip().split('\n') if p.strip()]
for p in paths:
    # Strip annotations like (new), (modified)
    if '(' in p:
        p = p[:p.index('(')].strip()
    p = p.replace('\\\\', '/')  # normalize Windows separators
    full = os.path.join(root, p)
    # Direct file check
    if os.path.isfile(full):
        if os.path.splitext(full)[1] in code_exts:
            print('1'); sys.exit(0)
        continue
    # Glob expansion (supports ** recursive)
    matched = glob.glob(full, recursive=True)
    for f in matched:
        if os.path.isfile(f) and os.path.splitext(f)[1] in code_exts:
            print('1'); sys.exit(0)
    # Directory scan (1 level deep)
    if os.path.isdir(full):
        for fn in os.listdir(full):
            fp = os.path.join(full, fn)
            if os.path.isfile(fp) and os.path.splitext(fp)[1] in code_exts:
                print('1'); sys.exit(0)
print('0')
" "$ROOT" "$write_set_paths" "$code_extensions")
fi

# 3. 逐门禁聚合
gate_results=""
overall_status="pass"
fail_count=0

check_verify() {
  local evidence_dir="$ENGINE_DIR/evidence/$task"
  local ac_count=0 pass_count=0
  # 计算 AC 数量 with the same four-format parser used by verify.
  if declare -F task_card_parse_ac_declarations >/dev/null 2>&1; then
    ac_count=$(task_card_parse_ac_declarations "$task_file" | awk 'NF {n++} END {print n+0}')
  else
    ac_count=$(grep -cE '(^AC-|^AC:.*AC-)' "$task_file" 2>/dev/null || true)
  fi
  [ -z "$ac_count" ] && ac_count=0
  if [ "$ac_count" -eq 0 ]; then
    echo "pass|0/0 AC (no ACs declared)|"
    return
  fi
  # 检查每个 AC evidence
  for f in "$evidence_dir"/AC-*.json; do
    [ -f "$f" ] || continue
    if grep -q '"status"[[:space:]]*:[[:space:]]*"pass"' "$f" 2>/dev/null; then
      pass_count=$((pass_count + 1))
    fi
  done
  if [ "$pass_count" -ge "$ac_count" ]; then
    echo "pass|$pass_count/$ac_count AC PASS|"
  else
    echo "block|$pass_count/$ac_count AC PASS (need $ac_count)|engine verify $task"
  fi
}

check_review() {
  local review_file="$ENGINE_DIR/review/evidence/$task/REVIEW.json"
  if [ ! -f "$review_file" ]; then
    echo "pending|REVIEW.json not found|engine review $task"
    return
  fi
  local status
  status=$("$PY" -c "
import json, sys
with open(sys.argv[1], encoding='utf-8') as f:
    d = json.load(f)
print(d.get('status', 'unknown'))
" "$review_file" 2>/dev/null || echo "unknown")
  case "$status" in
    pass) echo "pass|linter review passed|" ;;
    block) echo "block|linter found blocking issues|engine review $task" ;;
    degraded) echo "pass|linter degraded (tool unavailable)|" ;;
    skipped) echo "skipped|tool unavailable|" ;;
    *) echo "pending|unknown review status: $status|engine review $task" ;;
  esac
}

check_review_agent() {
  # 检查 agent_review 是否 enabled
  local ar_enabled
  ar_enabled=$("$PY" -c "
import json, sys
with open(sys.argv[1], encoding='utf-8') as f:
    cfg = json.load(f)
ar = cfg.get('defaults', {}).get('agent_review', {})
print('true' if ar.get('enabled', True) else 'false')
" "$ENGINE_DIR/review/config.json" 2>/dev/null || echo "true")
  if [ "$ar_enabled" != "true" ]; then
    echo "skipped|disabled in config|"
    return
  fi
  local agent_file="$ENGINE_DIR/review/evidence/$task/AGENT-REVIEW.json"
  if [ ! -f "$agent_file" ]; then
    echo "pending|AGENT-REVIEW.json not found|engine review-agent $task --package"
    return
  fi
  local status
  status=$("$PY" -c "
import json, sys
with open(sys.argv[1], encoding='utf-8') as f:
    d = json.load(f)
print(d.get('status', 'unknown'))
" "$agent_file" 2>/dev/null || echo "unknown")
  case "$status" in
    pass) echo "pass|agent review passed|" ;;
    concerns) echo "concerns|agent review found high-severity issues|engine review-agent $task --package" ;;
    block) echo "block|agent review blocked|engine review-agent $task --package" ;;
    *) echo "pending|unknown agent review status: $status|engine review-agent $task --package" ;;
  esac
}

check_prove() {
  local prove_file="$ENGINE_DIR/evidence/$task/PROVE.json"
  if [ ! -f "$prove_file" ]; then
    echo "pending|PROVE.json not found|engine prove $task --execute"
    return
  fi
  local status
  status=$("$PY" -c "
import json, sys
with open(sys.argv[1], encoding='utf-8') as f:
    d = json.load(f)
print(d.get('status', 'unknown'))
" "$prove_file" 2>/dev/null || echo "unknown")
  case "$status" in
    pass|PASS) echo "pass|prove assertions passed|" ;;
    fail|FAIL) echo "block|prove assertions failed|engine prove $task --execute" ;;
    timeout) echo "block|prove timed out|engine prove $task --execute" ;;
    *) echo "pending|unknown prove status: $status|engine prove $task --execute" ;;
  esac
}

# --run 模式: 对 pending 门禁执行
if [ "$run_mode" -eq 1 ]; then
  echo "[engine-gate] Running pending gates for $task..."
  # verify
  if [ ! -d "$ENGINE_DIR/evidence/$task" ] || ! ls "$ENGINE_DIR/evidence/$task"/AC-*.json >/dev/null 2>&1; then
    echo "[engine-gate] Running: engine verify $task"
    if [ -f "$ROOT/engine/bin/engine" ]; then
      bash "$ROOT/engine/bin/engine" verify "$task" || true
    else
      bash "$ENGINE_DIR/scripts/engine-verify.sh" "$task" || true
    fi
  fi
  # review (需要代码文件)
  if [ "$has_code" -eq 1 ] && [ ! -f "$ENGINE_DIR/review/evidence/$task/REVIEW.json" ]; then
    echo "[engine-gate] Running: engine review $task"
    bash "$ENGINE_DIR/scripts/engine-review-pipeline.sh" "$task" || true
  fi
  # review_agent: 不能自动跑(需外部 agent), 打印指令
  if [ "$has_code" -eq 1 ] && [ ! -f "$ENGINE_DIR/review/evidence/$task/AGENT-REVIEW.json" ]; then
    echo "[engine-gate] Manual step required:"
    echo "  1. engine review-agent $task --package"
    echo "  2. Feed review-package.md to an external agent"
    echo "  3. engine review-agent $task --validate"
  fi
  # prove
  if [ "$has_code" -eq 1 ] && [ ! -f "$ENGINE_DIR/evidence/$task/PROVE.json" ]; then
    if [ -f "$ENGINE_DIR/scripts/engine-prove.sh" ]; then
      echo "[engine-gate] Running: engine prove $task --execute"
      bash "$ENGINE_DIR/scripts/engine-prove.sh" "$task" --execute || true
    fi
  fi
  echo ""
fi

# 4. 聚合各门禁结果
declare -A gate_status gate_detail gate_fix

for g in $gates_list; do
  # 适用性判断
  if [ "$has_code" -eq 0 ]; then
    skip=0
    for sg in $docs_only_skip; do
      [ "$g" = "$sg" ] && skip=1 && break
    done
    if [ "$skip" -eq 1 ]; then
      gate_status[$g]="skipped"
      gate_detail[$g]="no code changes in WRITE-SET"
      gate_fix[$g]=""
      continue
    fi
  fi

  result=""
  case "$g" in
    verify) result=$(check_verify) ;;
    review) result=$(check_review) ;;
    review_agent) result=$(check_review_agent) ;;
    prove) result=$(check_prove) ;;
    *) result="skipped|unknown gate: $g|" ;;
  esac

  IFS='|' read -r s d f <<< "$result"
  gate_status[$g]="$s"
  gate_detail[$g]="$d"
  gate_fix[$g]="$f"

  # 判断是否 block overall
  case "$s" in
    block|pending|concerns)
      overall_status="block"
      fail_count=$((fail_count + 1))
      ;;
  esac
done

# 5. 写 GATE.json
head_commit=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo "unknown")
timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "")

"$PY" -c "
import json, sys, os

task = sys.argv[1]
overall = sys.argv[2]
head_commit = sys.argv[3]
timestamp = sys.argv[4]
gate_data = json.loads(sys.argv[5])
out_path = sys.argv[6]

gate_json = {
    'task': task,
    'timestamp': timestamp,
    'status': overall,
    'gates': {},
    'config': {
        'gates_applicable': [],
        'gates_skipped': [],
        'skip_reasons': {}
    },
    'write_provenance': {
        'writer': 'engine-gate',
        'commit': head_commit,
        'timestamp': timestamp,
        'argv': sys.argv[7]
    }
}

for name, info in gate_data.items():
    status = info['status']
    entry = {
        'status': status,
        'detail': info['detail'],
        'checked_at': timestamp
    }
    if info.get('fix'):
        entry['fix_command'] = info['fix']
    gate_json['gates'][name] = entry

    if status == 'skipped':
        gate_json['config']['gates_skipped'].append(name)
        gate_json['config']['skip_reasons'][name] = info['detail']
    else:
        gate_json['config']['gates_applicable'].append(name)

os.makedirs(os.path.dirname(out_path), exist_ok=True)
with open(out_path, 'w', encoding='utf-8', newline='') as f:
    json.dump(gate_json, f, indent=2, ensure_ascii=False)
    f.write('\n')
" "$task" "$overall_status" "$head_commit" "$timestamp" \
  "$(for g in $gates_list; do
    printf '"%s":{"status":"%s","detail":"%s","fix":"%s"},' \
      "$g" "${gate_status[$g]}" "${gate_detail[$g]}" "${gate_fix[$g]}"
  done | sed 's/,$//' | sed 's/^/{/' | sed 's/$/}/')" \
  "$ENGINE_DIR/evidence/$task/GATE.json" "$gate_argv"

# 6. 打印人类可读摘要
echo ""
echo "[Engine System] Gate status for $task: $(echo "$overall_status" | tr '[:lower:]' '[:upper:]')"
echo ""
for g in $gates_list; do
  s="${gate_status[$g]}"
  d="${gate_detail[$g]}"
  f="${gate_fix[$g]}"
  case "$s" in
    pass)    printf '  PASS %s: %s\n' "$g" "$d" ;;
    skipped) printf '  SKIP %s: %s\n' "$g" "$d" ;;
    exempt)  printf '  EXEMPT %s: %s\n' "$g" "$d" ;;
    *)
      printf '  FAIL %s: %s\n' "$g" "$d"
      if [ -n "$f" ]; then
        printf '       Fix: %s\n' "$f"
      fi
      ;;
  esac
done
echo ""
if [ "$overall_status" = "pass" ]; then
  echo "All gates satisfied. Task $task can be marked done."
else
  echo "Run 'engine gate $task' after fixing, then stage engine/evidence/$task/GATE.json."
fi

# 7. 退出码
if [ "$overall_status" = "pass" ]; then
  exit 0
else
  exit 1
fi
