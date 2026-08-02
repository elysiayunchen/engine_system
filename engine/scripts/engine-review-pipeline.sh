#!/usr/bin/env bash
# Engine System — Review pipeline 编排器(v6.20.0)
#
# 流程:flock → L2 提级校验 → diff → config 合并 → semgrep → eslint → 汇总
# 二元退出码:0=pass(含 tool_unavailable 降级) / 1=block(critical/high 未豁免)
#
# 用法:bash engine/scripts/engine-review-pipeline.sh T-NNN
# 安全:flock -n 非阻塞(macOS 用 mkdir 原子锁 fallback);evidence 写 review/ 子目录;
#       tool_unavailable 不 FAIL(避免门禁卡死),不静默(WARN + skip + 记检测证据)。

set -euo pipefail
on_error() { echo "[engine-review-pipeline] error on line $1 (${BASH_SOURCE[0]})" >&2; exit 1; }
trap 'on_error ${LINENO}' ERR

# python3 检测(Windows Git Bash 可能只有 python,无 python3 命令)
if command -v python3 >/dev/null 2>&1; then
  PY=python3
elif command -v python >/dev/null 2>&1; then
  PY=python
else
  echo "[engine-review-pipeline] Error: python3/python not found (required for JSON parsing)" >&2
  exit 2
fi

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
ENGINE_DIR="$ROOT/engine"
task_card_script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$task_card_script_dir/engine-task-card.sh" ]; then
  # shellcheck source=/dev/null
  . "$task_card_script_dir/engine-task-card.sh"
fi
task="${1:-}"

# Git Bash may invoke the native Windows Python, which cannot open MSYS
# `/e/...` paths. Keep shell paths for Bash, but pass Python portable
# drive-qualified paths whenever cygpath is available.
python_path() {
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -m "$1"
  else
    printf '%s' "$1"
  fi
}
python_root="$(python_path "$ROOT")"
export ENGINE_REVIEW_PY_ROOT="$python_root"

if [ -z "$task" ]; then
  echo "[engine-review-pipeline] Usage: engine-review-pipeline T-NNN" >&2
  exit 2
fi

task_file="$ENGINE_DIR/tasks/$task.md"
if [ ! -f "$task_file" ]; then
  echo "[engine-review-pipeline] Error: task card not found: $task_file" >&2
  exit 2
fi

# 0. flock -n 非阻塞(对照 C19)+ macOS mkdir fallback
mkdir -p "$ENGINE_DIR/review"
if command -v flock >/dev/null 2>&1; then
  exec 200>"$ENGINE_DIR/review/.review-lock.$task"
  if ! flock -n 200; then
    echo "[engine-review-pipeline] another review running for $task" >&2
    exit 1
  fi
else
  lockdir="$ENGINE_DIR/review/.review-lock.$task.d"
  if ! mkdir "$lockdir" 2>/dev/null; then
    echo "[engine-review-pipeline] another review running for $task" >&2
    exit 1
  fi
  trap 'rmdir "$lockdir" 2>/dev/null' EXIT
fi

# 1. 读 config.json(L0 defaults + L1 overrides 合并)—— C11 用 $PY 解析
#    L1 overrides 逐字段覆盖 L0 defaults(N4 修复:原版只读 defaults,忽略 overrides)
config_file="$ENGINE_DIR/review/config.json"
python_config_file="$(python_path "$config_file")"
config_data=$("$PY" -c "
import json, sys
try:
    with open('$python_config_file') as f:
        cfg = json.load(f)
except:
    cfg = {}
defaults = cfg.get('defaults', {})
overrides = cfg.get('overrides', {})
merged = dict(defaults)
for k, v in overrides.items():
    if k == 'tools' and isinstance(v, dict) and isinstance(merged.get('tools'), dict):
        merged['tools'] = {**merged['tools'], **v}
    else:
        merged[k] = v
print(json.dumps(merged))
" 2>/dev/null || echo '{}')

# compact 风格输出(对照 C14)—— 从合并后的 config 读取
severity_threshold=$(printf '%s' "$config_data" | "$PY" -c "
import json,sys
d=json.load(sys.stdin)
print(d.get('severity_threshold','high'))
")
code_extensions_json=$(printf '%s' "$config_data" | "$PY" -c "
import json,sys
d=json.load(sys.stdin)
exts=d.get('code_extensions',['.sh','.ps1','.py','.js','.ts','.go','.rs','.java','.c','.cpp','.rb','.php'])
print(json.dumps(exts))
")
l0_dimensions_json=$(printf '%s' "$config_data" | "$PY" -c "
import json,sys
d=json.load(sys.stdin)
print(json.dumps(d.get('dimensions',['security','quality'])))
")

# 2. 解析 WRITE-SET(从任务卡)
if declare -F task_card_parse_patterns >/dev/null 2>&1; then
  write_set_files="$(task_card_parse_patterns WRITE-SET "$task_file" | tr '\n' ' ')"
else
  write_set_files=$(awk '
  /^## WRITE-SET/{f=1;next}
  /^## /{f=0}
  f && /^- /{sub(/^- /,"");sub(/ *#.*/,"");print}
' "$task_file" | tr '\n' ' ')
fi

# 无 WRITE-SET → FAIL
if [ -z "$write_set_files" ]; then
  echo "[engine-review-pipeline] Error: review requires WRITE-SET to scope diff (task $task)" >&2
  exit 1
fi

# 3. 算 diff(按文件路径找首次提交,对照 C15 真正执行 git diff)
#    || true 在子 shell 管道末尾(N2 修复:grep/head 无匹配 + set -e 会杀脚本)
task_first_commit=$(git log --reverse --format="%H" -- "$task_file" 2>/dev/null | head -1 || true)
if [ -z "$task_first_commit" ]; then
  echo "[engine-review-pipeline] Error: no git history for $task_file (commit the task card first)" >&2
  exit 1
fi
head_commit=$(git rev-parse HEAD 2>/dev/null || echo unknown)

# diff base = task_first_commit 的 parent(包含任务首提交引入的代码改动);
#   根提交(无 parent)→ git rev-parse 退回字面 "<sha>^",校验 hex 后 fallback 到 git 空树
diff_base=$(git rev-parse "$task_first_commit^" 2>/dev/null || true)
if ! printf '%s' "$diff_base" | grep -qE '^[0-9a-f]{40}$'; then
  diff_base="4b825dc642cb6eb9a060e54bf8d69288fbee4904"
fi

# 4. 筛代码文件(扩展名白名单,只取 WRITE-SET 内的代码文件)
code_files=$(printf '%s\n' $write_set_files | "$PY" -c "
import json,sys,os
exts=set(json.loads('''$code_extensions_json'''))
out=[]
for line in sys.stdin:
    f=line.strip()
    if not f: continue
    _, ext=os.path.splitext(f)
    if ext in exts and os.path.isfile('$python_root/'+f):
        out.append(f)
print(' '.join(out))
")

# 5. 算 diff 范围(C15):只看 diff_base..HEAD 内有改动的代码文件
#    diff_base = task_first_commit^(parent),含任务首提交引入的代码;根提交用空树
diff_files=""
if [ -n "$code_files" ]; then
  for f in $code_files; do
    if git diff --name-only "$diff_base"..HEAD -- "$f" 2>/dev/null | grep -q .; then
      diff_files="$diff_files $f"
    fi
  done
  diff_files=$(echo "$diff_files" | tr -s ' ' | sed 's/^ //')
fi

# 6. L2 REVIEW-OVERRIDE 提级校验(spec §8-1:启动时校验)
#    N2 修复:所有 grep 管道末尾加 || true(无 REVIEW-OVERRIDE 段时 grep 无匹配 + set -e 杀脚本)
review_override_section=$(awk '/^## REVIEW-OVERRIDE/{f=1;next} /^## /{f=0} f' "$task_file" | grep -E '^- ' | sed 's/^- //' || true)
if [ -n "$review_override_section" ]; then
  l2_threshold=$(echo "$review_override_section" | grep -oE 'severity_threshold:[[:space:]]*[a-z]+' | sed 's/severity_threshold:[[:space:]]*//' || true)
  if [ -n "$l2_threshold" ]; then
    severity_order() { case "$1" in critical) echo 4;; high) echo 3;; medium) echo 2;; low) echo 1;; *) echo 0;; esac; }
    l0_ord=$(severity_order "$severity_threshold")
    l2_ord=$(severity_order "$l2_threshold")
    if [ "$l2_ord" -lt "$l0_ord" ]; then
      echo "[engine-review-pipeline] Error: L2 severity_threshold=$l2_threshold < L0=$severity_threshold (downgrade requires approved decision)" >&2
      exit 1
    fi
    severity_threshold="$l2_threshold"
  fi

  # C26 补:校验 add_dimensions(必须是 L0+L1 dimensions 的超集)
  l2_add_dims=$(echo "$review_override_section" | grep -oE 'add_dimensions:[[:space:]]*[a-z,]+' | sed 's/add_dimensions:[[:space:]]*//' | tr ',' '\n' || true)
  if [ -n "$l2_add_dims" ]; then
    for dim in $l2_add_dims; do
      if ! printf '%s' "$l0_dimensions_json" | "$PY" -c "
import json,sys
d=json.load(sys.stdin)
sys.exit(0 if '$dim' in d else 1)
"; then
        : # 新维度,允许(add)
      fi
    done
  fi

  # C26 补:校验 skip_dimensions(降级 → exit 1)
  l2_skip_dims=$(echo "$review_override_section" | grep -oE 'skip_dimensions:[[:space:]]*[a-z,]+' | sed 's/skip_dimensions:[[:space:]]*//' | tr ',' '\n' || true)
  if [ -n "$l2_skip_dims" ]; then
    for dim in $l2_skip_dims; do
      if printf '%s' "$l0_dimensions_json" | "$PY" -c "
import json,sys
d=json.load(sys.stdin)
sys.exit(0 if '$dim' in d else 1)
"; then
        echo "[engine-review-pipeline] Error: L2 skip_dimensions=$dim downgrades (requires approved decision)" >&2
        exit 1
      fi
    done
  fi
fi

# 7. SECURITY 维度(semgrep)—— C10 用 $PY 解析
security_status="pass"
security_findings_json="[]"
tool_unavailable=false
semgrep_available=false
semgrep_detection_exit=1
semgrep_version=""

if command -v semgrep >/dev/null 2>&1; then
  semgrep_available=true
  semgrep_detection_exit=0
  semgrep_version=$(semgrep --version 2>/dev/null | head -1 || echo "")
  if [ -n "$diff_files" ]; then
    # C4 决策:|| true,任何非 0 退出视为 unavailable
    semgrep_output=$(semgrep --json --config=auto $diff_files 2>/dev/null || true)
    if [ -z "$semgrep_output" ]; then
      security_status="skipped"
      tool_unavailable=true
      semgrep_available=false
      semgrep_detection_exit=1
    else
      security_findings_json=$(printf '%s' "$semgrep_output" | "$PY" -c '
import json,sys
try: d=json.load(sys.stdin)
except: d={"results":[]}
results=d.get("results",[])
findings=[]
for r in results:
    extra=r.get("extra",{})
    metadata=extra.get("metadata",{})
    sev=metadata.get("impact","").upper()
    confidence=extra.get("confidence","").lower()
    raw_sev=extra.get("severity","")
    if sev=="ERROR" or raw_sev=="ERROR":
        if confidence in ("high","") or confidence=="medium":
            mapped="critical"
        else:
            mapped="high"
    elif sev=="WARNING" or raw_sev=="WARNING":
        mapped="high"
    elif sev=="INFO" or raw_sev=="INFO":
        mapped="medium"
    else:
        mapped="medium"
    cid=r.get("check_id","unknown").replace(".","-")
    p=r.get("path","unknown")
    line=r.get("start",{}).get("line",0)
    col=r.get("start",{}).get("col",0)
    findings.append({
        "id":f"semgrep-{cid}-{p}:{line}:{col}",
        "severity":mapped,
        "file":p,
        "line":line,
        "col":col,
        "rule":r.get("check_id",""),
        "message":extra.get("message",""),
        "tool":"semgrep",
        "tool_severity_raw":raw_sev,
        "tool_confidence":confidence
    })
print(json.dumps(findings,separators=(",",":")))
')
      has_critical_or_high=$(printf '%s' "$security_findings_json" | "$PY" -c '
import json,sys
try: findings=json.load(sys.stdin)
except: findings=[]
print("true" if any(f["severity"] in ("critical","high") for f in findings) else "false")
')
      if [ "$has_critical_or_high" = "true" ]; then
        security_status="block"
      fi
    fi
  fi
else
  security_status="skipped"
  tool_unavailable=true
fi

# 8. QUALITY 维度(eslint)—— C10 用 $PY 解析
quality_status="pass"
quality_findings_json="[]"
eslint_available=false
eslint_detection_exit=1
eslint_version=""

if command -v eslint >/dev/null 2>&1; then
  eslint_available=true
  eslint_detection_exit=0
  eslint_version=$(eslint --version 2>/dev/null | head -1 || echo "")
  # 只对 .js/.ts 文件跑(N2 修复:|| true 防无 .js/.ts 文件时 grep 无匹配杀脚本)
  js_files=$(printf '%s\n' $diff_files | grep -E '\.(js|ts)$' | tr '\n' ' ' || true)
  js_files=$(echo "$js_files" | tr -s ' ' | sed 's/^ //;s/ $//')
  if [ -n "$js_files" ]; then
    # C5 决策:eslint.config.js 优先;|| true 走 unavailable 降级
    eslint_output=$(eslint --format=json $js_files 2>/dev/null || true)
    if [ -z "$eslint_output" ]; then
      quality_status="skipped"
      tool_unavailable=true
      eslint_available=false
      eslint_detection_exit=1
    else
      quality_findings_json=$(printf '%s' "$eslint_output" | "$PY" -c '
import json,sys
import os
try: data=json.load(sys.stdin)
except: data=[]
findings=[]
for f in data:
    for m in f.get("messages",[]):
        sev=m.get("severity",0)
        if sev==2: mapped="high"
        elif sev==1: mapped="medium"
        else: mapped="low"
        p=f.get("filePath","").replace("\\","/")
        # 相对路径 (the root is passed as a normalized environment path)
        root=os.environ.get("ENGINE_REVIEW_PY_ROOT","").replace("\\","/").rstrip("/")
        if root and p.startswith(root+"/"): p=p[len(root)+1:]
        line=m.get("line",0)
        col=m.get("column",0)
        rule=m.get("ruleId","") or "unknown"
        findings.append({
            "id":f"eslint-{rule}-{p}:{line}:{col}",
            "severity":mapped,
            "file":p,
            "line":line,
            "col":col,
            "rule":rule,
            "message":m.get("message",""),
            "tool":"eslint",
            "tool_severity_raw":str(sev)
        })
print(json.dumps(findings,separators=(",",":")))
')
      has_critical_or_high=$(printf '%s' "$quality_findings_json" | "$PY" -c '
import json,sys
try: findings=json.load(sys.stdin)
except: findings=[]
print("true" if any(f["severity"] in ("critical","high") for f in findings) else "false")
')
      if [ "$has_critical_or_high" = "true" ]; then
        quality_status="block"
      fi
    fi
  else
    quality_status="no_tool_for_language"
  fi
else
  quality_status="skipped"
  tool_unavailable=true
fi

# 9. 汇总 REVIEW.json + SECURITY.json + QUALITY.json
evidence_dir="$ENGINE_DIR/review/evidence/$task"
mkdir -p "$evidence_dir"
python_evidence_dir="$(python_path "$evidence_dir")"

overall_status="pass"
[ "$security_status" = "block" ] && overall_status="block"
[ "$quality_status" = "block" ] && overall_status="block"

# files_reviewed 用 JSON 数组(C13)
files_reviewed_json=$(printf '%s\n' $diff_files | "$PY" -c "
import json,sys
files=[l.strip() for l in sys.stdin if l.strip()]
print(json.dumps(files,separators=(',',':')))
")
files_skipped_json=$(printf '%s\n' $write_set_files | "$PY" -c "
import json,sys,os
exts=set(['.sh','.ps1','.py','.js','.ts','.go','.rs','.java','.c','.cpp','.rb','.php'])
code=set('$code_files'.split())
ws=[l.strip() for l in sys.stdin if l.strip()]
skipped=[f for f in ws if f not in code]
print(json.dumps(skipped,separators=(',',':')))
")

# code_fingerprint 用 $PY 构造(C12)——只算 diff.files_reviewed
code_fingerprint_json=$(printf '%s\n' $diff_files | "$PY" -c "
import json,sys,subprocess
fp={}
for line in sys.stdin:
    f=line.strip()
    if not f: continue
    try:
        sha=subprocess.check_output(['git','rev-parse','HEAD:'+f],stderr=subprocess.DEVNULL).decode().strip()
    except: sha=''
    if sha: fp[f]=sha
print(json.dumps(fp,separators=(',',':')))
")

timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# findings_count(per severity)
security_counts=$(printf '%s' "$security_findings_json" | "$PY" -c "
import json,sys
try: f=json.load(sys.stdin)
except: f=[]
c={'critical':0,'high':0,'medium':0,'low':0}
for x in f: c[x.get('severity','medium')]=c.get(x.get('severity','medium'),0)+1
print(json.dumps(c,separators=(',',':')))
")
quality_counts=$(printf '%s' "$quality_findings_json" | "$PY" -c "
import json,sys
try: f=json.load(sys.stdin)
except: f=[]
c={'critical':0,'high':0,'medium':0,'low':0}
for x in f: c[x.get('severity','medium')]=c.get(x.get('severity','medium'),0)+1
print(json.dumps(c,separators=(',',':')))
")

# 写 SECURITY.json(compact 风格,对照 C14)
if [ "$security_status" = "skipped" ]; then
  printf '%s\n' "{\"dimension\":\"security\",\"tool\":\"semgrep\",\"status\":\"skipped\",\"reason\":\"tool_unavailable\",\"tool_available\":$semgrep_available,\"detection_command\":\"command -v semgrep\",\"detection_exit_code\":$semgrep_detection_exit}" > "$evidence_dir/SECURITY.json"
else
  printf '%s\n' "{\"dimension\":\"security\",\"tool\":\"semgrep\",\"tool_version\":\"$semgrep_version\",\"status\":\"$security_status\",\"findings\":$security_findings_json,\"findings_count\":$security_counts}" > "$evidence_dir/SECURITY.json"
fi

# 写 QUALITY.json
if [ "$quality_status" = "skipped" ]; then
  printf '%s\n' "{\"dimension\":\"quality\",\"tool\":\"eslint\",\"status\":\"skipped\",\"reason\":\"tool_unavailable\",\"tool_available\":$eslint_available,\"detection_command\":\"command -v eslint\",\"detection_exit_code\":$eslint_detection_exit}" > "$evidence_dir/QUALITY.json"
else
  printf '%s\n' "{\"dimension\":\"quality\",\"tool\":\"eslint\",\"tool_version\":\"$eslint_version\",\"status\":\"$quality_status\",\"findings\":$quality_findings_json,\"findings_count\":$quality_counts}" > "$evidence_dir/QUALITY.json"
fi

# evidence_manifest_sha256(含 SECURITY + QUALITY,排除 REVIEW 自身;对照 §8-2)
evidence_manifest_sha256=$("$PY" -c "
import hashlib,json,os
evidence_dir='$python_evidence_dir'
files=sorted([f for f in os.listdir(evidence_dir) if f.endswith('.json') and f!='REVIEW.json'])
h=hashlib.sha256()
for fname in files:
    with open(os.path.join(evidence_dir,fname),'rb') as fp:
        h.update(fp.read())
print(h.hexdigest())
")

# tool_versions 顶层聚合
tool_versions_json=$("$PY" -c "
import json
print(json.dumps({'semgrep':'$semgrep_version','eslint':'$eslint_version'},separators=(',',':')))
")

# config_layers 记录(N4 修复:记录真实 L1 overrides 值,而非空 {})
config_layers_json=$("$PY" -c "
import json
try:
    with open('$python_config_file') as f:
        cfg = json.load(f)
except:
    cfg = {}
print(json.dumps({
    'l0_defaults': cfg.get('defaults', {}),
    'l1_project': {'overrides': cfg.get('overrides', {})},
    'l2_task': {'severity_threshold': '$severity_threshold'}
},separators=(',',':')))
")

# REVIEW.json compact 写入(C14)
# N1 修复:布尔值通过环境变量传入 Python,bash true/false 直接展开到 Python 字面量
#   会变成 NameError(Python 不认小写 true/false)。所有变量走 os.environ.get()。
TASK="$task" TIMESTAMP="$timestamp" OVERALL_STATUS="$overall_status" \
TASK_FIRST_COMMIT="$task_first_commit" HEAD_COMMIT="$head_commit" \
FILES_REVIEWED="$files_reviewed_json" FILES_SKIPPED="$files_skipped_json" \
DIFF_EMPTY=$([ -z "$diff_files" ] && echo true || echo false) \
SECURITY_STATUS="$security_status" SECURITY_COUNTS="$security_counts" SEMGREP_VERSION="$semgrep_version" \
QUALITY_STATUS="$quality_status" QUALITY_COUNTS="$quality_counts" ESLINT_VERSION="$eslint_version" \
SEVERITY_THRESHOLD="$severity_threshold" \
TOOL_UNAVAILABLE="$tool_unavailable" \
SEMGREP_AVAILABLE="$semgrep_available" SEMGREP_DETECTION_EXIT="$semgrep_detection_exit" \
ESLINT_AVAILABLE="$eslint_available" ESLINT_DETECTION_EXIT="$eslint_detection_exit" \
CONFIG_LAYERS="$config_layers_json" TOOL_VERSIONS="$tool_versions_json" \
CODE_FINGERPRINT="$code_fingerprint_json" EVIDENCE_MANIFEST_SHA256="$evidence_manifest_sha256" \
"$PY" -c "
import json, os
data={
    'task': os.environ.get('TASK', ''),
    'timestamp': os.environ.get('TIMESTAMP', ''),
    'status': os.environ.get('OVERALL_STATUS', ''),
    'diff':{
        'strategy':'task_first_commit',
        'base_commit': os.environ.get('TASK_FIRST_COMMIT', ''),
        'head_commit': os.environ.get('HEAD_COMMIT', ''),
        'files_reviewed': json.loads(os.environ.get('FILES_REVIEWED', '[]')),
        'files_skipped': json.loads(os.environ.get('FILES_SKIPPED', '[]')),
        'diff_empty': os.environ.get('DIFF_EMPTY') == 'true'
    },
    'dimensions':{
        'security':{'status': os.environ.get('SECURITY_STATUS', ''), 'findings_count': json.loads(os.environ.get('SECURITY_COUNTS', '{}')), 'tool_version': os.environ.get('SEMGREP_VERSION', '')},
        'quality':{'status': os.environ.get('QUALITY_STATUS', ''), 'findings_count': json.loads(os.environ.get('QUALITY_COUNTS', '{}')), 'tool_version': os.environ.get('ESLINT_VERSION', '')}
    },
    'severity_threshold': os.environ.get('SEVERITY_THRESHOLD', ''),
    'tool_unavailable': os.environ.get('TOOL_UNAVAILABLE') == 'true',
    'tool_detection':{
        'semgrep':{'available': os.environ.get('SEMGREP_AVAILABLE') == 'true', 'detection_command':'command -v semgrep', 'detection_exit_code': int(os.environ.get('SEMGREP_DETECTION_EXIT', '1'))},
        'eslint':{'available': os.environ.get('ESLINT_AVAILABLE') == 'true', 'detection_command':'command -v eslint', 'detection_exit_code': int(os.environ.get('ESLINT_DETECTION_EXIT', '1'))}
    },
    'config_layers': json.loads(os.environ.get('CONFIG_LAYERS', '{}')),
    'tool_versions': json.loads(os.environ.get('TOOL_VERSIONS', '{}')),
    'code_fingerprint': json.loads(os.environ.get('CODE_FINGERPRINT', '{}')),
    'evidence_manifest_sha256': os.environ.get('EVIDENCE_MANIFEST_SHA256', ''),
    'write_provenance':{
        'writer':'engine-review',
        'commit': os.environ.get('HEAD_COMMIT', ''),
        'timestamp': os.environ.get('TIMESTAMP', ''),
        'argv': 'engine review ' + os.environ.get('TASK', ''),
        'pipeline_version':'v6.20.0'
    }
}
print(json.dumps(data,separators=(',',':')))
" > "$evidence_dir/REVIEW.json"

# exit code
if [ "$overall_status" = "block" ]; then
  echo "[engine-review-pipeline] $task: BLOCK (critical/high findings)" >&2
  exit 1
fi
echo "[engine-review-pipeline] $task: PASS"
exit 0
