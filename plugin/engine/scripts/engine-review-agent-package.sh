#!/usr/bin/env bash
# Engine System — Agent-Reviewer Package(v6.21.0)
#
# Phase 1: 打包审查上下文 → engine/review/evidence/T-NNN/review-package.md
#
# 流程:flock → config 检查 → diff → 筛代码文件 → 周边上下文 → 域知识
#       → protocol + 挑战 → linter 摘要 → 大小控制 → 写 package
#
# 用法:bash engine/scripts/engine-review-agent-package.sh T-NNN
# 安全:只写 engine/review/evidence/T-NNN/review-package.md;不动其他文件。

set -euo pipefail
on_error() { echo "[engine-review-agent-package] error on line $1 (${BASH_SOURCE[0]})" >&2; exit 1; }
trap 'on_error ${LINENO}' ERR

# python3 检测
if command -v python3 >/dev/null 2>&1; then
  PY=python3
elif command -v python >/dev/null 2>&1; then
  PY=python
else
  echo "[engine-review-agent-package] Error: python3/python not found" >&2
  exit 2
fi

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
ENGINE_DIR="$ROOT/engine"
task="${1:-}"

if [ -z "$task" ]; then
  echo "[engine-review-agent-package] Usage: engine-review-agent-package T-NNN" >&2
  exit 2
fi

task_file="$ENGINE_DIR/tasks/$task.md"
if [ ! -f "$task_file" ]; then
  echo "[engine-review-agent-package] Error: task card not found: $task_file" >&2
  exit 2
fi

# === 0. flock -n 非阻塞 + macOS mkdir fallback ===
mkdir -p "$ENGINE_DIR/review"
if command -v flock >/dev/null 2>&1; then
  exec 200>"$ENGINE_DIR/review/.review-agent-lock.$task"
  if ! flock -n 200; then
    echo "[engine-review-agent-package] another review-agent running for $task" >&2
    exit 1
  fi
else
  lockdir="$ENGINE_DIR/review/.review-agent-lock.$task.d"
  if ! mkdir "$lockdir" 2>/dev/null; then
    echo "[engine-review-agent-package] another review-agent running for $task" >&2
    exit 1
  fi
  trap 'rmdir "$lockdir" 2>/dev/null' EXIT
fi

# === 1. Config 检查:agent_review.enabled 或 L2 override ===
config_file="$ENGINE_DIR/review/config.json"
agent_review_enabled=$(CONFIG_FILE="$config_file" "$PY" -c "
import json, sys, os
try:
    with open(os.environ['CONFIG_FILE']) as f:
        cfg = json.load(f)
except:
    cfg = {}
defaults = cfg.get('defaults', {})
overrides = cfg.get('overrides', {})
ar = defaults.get('agent_review', {})
# L1 override
ar_ov = overrides.get('agent_review', {})
if isinstance(ar_ov, dict):
    ar = {**ar, **ar_ov}
print('true' if ar.get('enabled', False) else 'false')
" 2>/dev/null || echo "false")

# L2 REVIEW-OVERRIDE: add_dimensions: agent_review
l2_override=$(awk '/^## REVIEW-OVERRIDE/{f=1;next} /^## /{f=0} f' "$task_file" | grep -E '^- ' | sed 's/^- //' || true)
l2_has_agent_review=false
if [ -n "$l2_override" ]; then
  if echo "$l2_override" | grep -q 'add_dimensions:.*agent_review'; then
    l2_has_agent_review=true
  fi
fi

if [ "$agent_review_enabled" != "true" ] && [ "$l2_has_agent_review" != "true" ]; then
  echo "[engine-review-agent-package] $task: agent_review not enabled (config or L2), skipped"
  exit 0
fi

# 读配置数值
read_config_val() {
  CONFIG_FILE="$config_file" "$PY" -c "
import json, os
try:
    with open(os.environ['CONFIG_FILE']) as f:
        cfg = json.load(f)
except:
    cfg = {}
defaults = cfg.get('defaults', {})
overrides = cfg.get('overrides', {})
ar = defaults.get('agent_review', {})
ar_ov = overrides.get('agent_review', {})
if isinstance(ar_ov, dict):
    ar = {**ar, **ar_ov}
print(ar.get('$1', $2))
" 2>/dev/null || echo "$2"
}

max_package_lines=$(read_config_val max_package_lines 2000)
max_surrounding=$(read_config_val max_surrounding_context_lines 500)
max_domain=$(read_config_val max_domain_knowledge_lines 150)

# === 2. 解析 WRITE-SET ===
write_set_files=$(awk '
  /^## WRITE-SET/{f=1;next}
  /^## /{f=0}
  f && /^- /{sub(/^- /,"");sub(/ *#.*/,"");print}
' "$task_file" | tr '\n' ' ')

if [ -z "$write_set_files" ]; then
  echo "[engine-review-agent-package] Error: review requires WRITE-SET to scope diff (task $task)" >&2
  exit 1
fi

# === 3. 算 diff(复用 v1 task_first_commit 算法) ===
task_first_commit=$(git log --reverse --format="%H" -- "$task_file" 2>/dev/null | head -1 || true)
if [ -z "$task_first_commit" ]; then
  echo "[engine-review-agent-package] Error: no git history for $task_file (commit the task card first)" >&2
  exit 1
fi
head_commit=$(git rev-parse HEAD 2>/dev/null || echo unknown)

diff_base=$(git rev-parse "$task_first_commit^" 2>/dev/null || true)
if ! printf '%s' "$diff_base" | grep -qE '^[0-9a-f]{40}$'; then
  diff_base="4b825dc642cb6eb9a060e54bf8d69288fbee4904"
fi

# === 4. 筛代码文件(code_extensions 白名单) ===
code_extensions_json=$(CONFIG_FILE="$config_file" "$PY" -c "
import json, os
try:
    with open(os.environ['CONFIG_FILE']) as f:
        cfg = json.load(f)
except:
    cfg = {}
defaults = cfg.get('defaults', {})
overrides = cfg.get('overrides', {})
merged = dict(defaults)
for k, v in overrides.items():
    merged[k] = v
exts = merged.get('code_extensions', ['.sh','.ps1','.py','.js','.ts','.go','.rs','.java','.c','.cpp','.rb','.php'])
print(json.dumps(exts))
" 2>/dev/null || echo '[".sh",".ps1",".py",".js",".ts",".go",".rs",".java",".c",".cpp",".rb",".php"]')

code_files=$(printf '%s\n' $write_set_files | ROOT_DIR="$ROOT" CODE_EXTS="$code_extensions_json" "$PY" -c "
import json,sys,os
exts=set(json.loads(os.environ['CODE_EXTS']))
root=os.environ['ROOT_DIR']
out=[]
for line in sys.stdin:
    f=line.strip()
    if not f: continue
    # skip glob patterns
    if '*' in f or '?' in f: continue
    _, ext=os.path.splitext(f)
    if ext in exts and os.path.isfile(os.path.join(root, f)):
        out.append(f)
print(' '.join(out))
")

# 无代码文件 → skip
if [ -z "$code_files" ]; then
  echo "[engine-review-agent-package] $task: no code changes in WRITE-SET, agent review skipped"
  exit 0
fi

# 只看 diff 范围内有改动的代码文件
diff_files=""
for f in $code_files; do
  if git diff --name-only "$diff_base"..HEAD -- "$f" 2>/dev/null | grep -q .; then
    diff_files="$diff_files $f"
  fi
done
diff_files=$(echo "$diff_files" | tr -s ' ' | sed 's/^ //')

if [ -z "$diff_files" ]; then
  echo "[engine-review-agent-package] $task: no code changes in WRITE-SET, agent review skipped"
  exit 0
fi

# === 5. 收集周边上下文(git diff hunk header + grep) ===
# 从 hunk headers 提取函数上下文(git 自带,语言无关)
hunk_symbols=$(git diff -U0 "$diff_base"..HEAD -- $diff_files 2>/dev/null | grep '^@@' | sed 's/.*@@[[:space:]]*//' | grep -v '^$' | head -20 || true)

surrounding_context=""
surrounding_lines=0
if [ -n "$hunk_symbols" ]; then
  # 提取符号名(取每行第一个标识符)
  symbols=$(printf '%s\n' "$hunk_symbols" | grep -oE '[A-Za-z_][A-Za-z_0-9]*' | sort -u | head -15 || true)
  if [ -n "$symbols" ]; then
    for sym in $symbols; do
      [ ${#sym} -lt 3 ] && continue  # 跳过太短的(噪声)
      # 在 WRITE-SET 其他文件中 grep
      for wf in $write_set_files; do
        # 跳过 diff 文件自身和 glob
        case "$diff_files" in *"$wf"*) continue ;; esac
        case "$wf" in *"*"*) continue ;; esac
        [ ! -f "$ROOT/$wf" ] && continue
        matches=$(grep -n "$sym" "$ROOT/$wf" 2>/dev/null | head -3 || true)
        if [ -n "$matches" ]; then
          # 取第一个匹配行 ± 10 行
          first_line=$(echo "$matches" | head -1 | cut -d: -f1)
          start=$((first_line > 10 ? first_line - 10 : 1))
          end=$((first_line + 10))
          ctx=$(sed -n "${start},${end}p" "$ROOT/$wf" 2>/dev/null || true)
          ctx_lines=$(printf '%s\n' "$ctx" | wc -l)
          if [ $((surrounding_lines + ctx_lines)) -le "$max_surrounding" ]; then
            surrounding_context="$surrounding_context
### $wf (references: $sym)
\`\`\`
$ctx
\`\`\`
"
            surrounding_lines=$((surrounding_lines + ctx_lines + 3))
          fi
        fi
      done
      [ "$surrounding_lines" -ge "$max_surrounding" ] && break
    done
  fi
fi

# === 6. 域知识(federation 路由) ===
domain_knowledge=""
federation_file="$ENGINE_DIR/domains/federation.json"
if [ -f "$federation_file" ]; then
  # 找第一个 diff 文件所属域
  first_diff_file=$(echo "$diff_files" | tr ' ' '\n' | head -1)
  domain=$(FED_FILE="$federation_file" DIFF_FILE="$first_diff_file" "$PY" -c "
import json, os
try:
    with open(os.environ['FED_FILE']) as f:
        fed = json.load(f)
except:
    fed = {}
domains = fed.get('domains', {})
path = os.environ['DIFF_FILE']
for dname, dinfo in domains.items():
    paths = dinfo.get('paths', [])
    for p in paths:
        # simple prefix match (strip trailing /**)
        prefix = p.rstrip('*').rstrip('/')
        if path.startswith(prefix):
            print(dname)
            raise SystemExit(0)
print('')
" 2>/dev/null || echo "")

  if [ -n "$domain" ]; then
    inv_file="$ENGINE_DIR/domains/$domain/INVENTORY.md"
    pit_file="$ENGINE_DIR/domains/$domain/PITFALLS.md"
    if [ -f "$inv_file" ]; then
      inv_content=$(head -"$max_domain" "$inv_file" 2>/dev/null || true)
      domain_knowledge="### Domain: $domain — INVENTORY
$inv_content
"
    fi
    if [ -f "$pit_file" ]; then
      pit_lines=$((max_domain - $(printf '%s\n' "$domain_knowledge" | wc -l)))
      [ "$pit_lines" -gt 0 ] && domain_knowledge="$domain_knowledge
### Domain: $domain — PITFALLS
$(head -"$pit_lines" "$pit_file" 2>/dev/null || true)
"
    fi
  fi
fi

# === 7. 静态挑战生成(参数化) ===
# most_changed_file: diff --stat 排序
most_changed_file=$(git diff --stat "$diff_base"..HEAD -- $diff_files 2>/dev/null | grep '|' | sort -t'|' -k2 -rn | head -1 | sed 's/|.*//' | tr -d ' ' || true)
[ -z "$most_changed_file" ] && most_changed_file=$(echo "$diff_files" | tr ' ' '\n' | head -1)

# largest_hunk_line: 最大 hunk 起始行
largest_hunk_line=$(git diff -U0 "$diff_base"..HEAD -- "$most_changed_file" 2>/dev/null | grep '^@@' | sed 's/@@[^+]*+\([0-9]*\).*/\1/' | sort -rn | head -1 || true)
[ -z "$largest_hunk_line" ] && largest_hunk_line="1"

# another_writeset_file: WRITE-SET 中除 most_changed_file 外的第一个代码文件
another_file=$(printf '%s\n' $diff_files | grep -v "^$most_changed_file$" | head -1 || true)
[ -z "$another_file" ] && another_file="(other WRITE-SET files)"

# === 8. v1 linter findings 摘要 ===
linter_summary=""
evidence_dir="$ENGINE_DIR/review/evidence/$task"
sec_file="$evidence_dir/SECURITY.json"
qual_file="$evidence_dir/QUALITY.json"
if [ -f "$sec_file" ] || [ -f "$qual_file" ]; then
  sec_count=0
  qual_count=0
  [ -f "$sec_file" ] && sec_count=$(SEC_FILE="$sec_file" "$PY" -c "
import json, os
try:
    with open(os.environ['SEC_FILE']) as f:
        d = json.load(f)
    print(sum(d.get('findings_count',{}).values()) if isinstance(d.get('findings_count'),dict) else len(d.get('findings',[])))
except:
    print(0)
" 2>/dev/null || echo 0)
  [ -f "$qual_file" ] && qual_count=$(QUAL_FILE="$qual_file" "$PY" -c "
import json, os
try:
    with open(os.environ['QUAL_FILE']) as f:
        d = json.load(f)
    print(sum(d.get('findings_count',{}).values()) if isinstance(d.get('findings_count'),dict) else len(d.get('findings',[])))
except:
    print(0)
" 2>/dev/null || echo 0)
  if [ "$sec_count" -gt 0 ] || [ "$qual_count" -gt 0 ]; then
    linter_summary="### Linter Findings Summary

v1 review (semgrep + eslint) has already reported: **$sec_count** security findings, **$qual_count** quality findings.
Please address these in your overall_assessment (agree / supplement / disagree).
"
  fi
fi

# === 9. 组装 review-package.md ===
mkdir -p "$evidence_dir"
package_file="$evidence_dir/review-package.md"
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# 提取任务卡关键段
goal_text=$(awk '/^GOAL:/{sub(/^GOAL:[[:space:]]*/,"");print;exit}' "$task_file" || true)
[ -z "$goal_text" ] && goal_text=$(awk '/^## GOAL/{f=1;next}/^## /{f=0}f&&NF{print;exit}' "$task_file" || true)
constraints_text=$(awk '/^CONSTRAINTS:/{sub(/^CONSTRAINTS:[[:space:]]*/,"");print}' "$task_file" || true)
ac_text=$(awk '/^AC:/{print}' "$task_file" || true)

# diff 内容
diff_content=""
for f in $diff_files; do
  file_diff=$(git diff "$diff_base"..HEAD -- "$f" 2>/dev/null || true)
  if [ -n "$file_diff" ]; then
    # 检测语言用于语法高亮
    ext="${f##*.}"
    diff_content="$diff_content
### $f
\`\`\`diff
$file_diff
\`\`\`
"
  fi
done

# protocol.md 内容(逐字包含)
protocol_file="$ENGINE_DIR/review/protocol.md"
protocol_content=""
if [ -f "$protocol_file" ]; then
  protocol_content=$(cat "$protocol_file")
else
  # L0 内嵌默认 protocol
  protocol_content="Review the code changes across 5 dimensions: correctness, design, consistency, readability, completeness.
For each dimension, provide at least one entry (finding or strength).
Each finding must have a specific file, line, and message (>=20 chars).
Answer all 3 adversarial challenges with substantive responses (>=30 chars each).
Write output as AGENT-REVIEW.json following the schema in section 6."
fi

# AGENT-REVIEW.json schema 示例
schema_example='{
  "task": "'"$task"'",
  "timestamp": "<ISO-8601>",
  "reviewer": {"type": "agent", "model": "<optional>"},
  "status": "pass|concerns|block",
  "dimensions": {
    "correctness": {"entries": [{"id": "agent-correctness-<file>:<line>", "severity": "high", "type": "finding", "file": "<path>", "line": 42, "message": "<>=20 chars>", "suggestion": "<optional>"}], "summary": "<1-2 sentences>"},
    "design": {"entries": [...], "summary": "..."},
    "consistency": {"entries": [...], "summary": "..."},
    "readability": {"entries": [...], "summary": "..."},
    "completeness": {"entries": [...], "summary": "..."}
  },
  "adversarial_responses": [
    {"challenge": "<question 1>", "response": "<>=30 chars>"},
    {"challenge": "<question 2>", "response": "<>=30 chars>"},
    {"challenge": "<question 3>", "response": "<>=30 chars>"}
  ],
  "overall_assessment": "<2-3 sentences, >=200 chars total with summaries>",
  "write_provenance": {
    "writer": "agent-reviewer",
    "commit": "'"$head_commit"'",
    "timestamp": "<write time>",
    "package_sha256": "<fill from package header>"
  }
}'

# 写 package(先写临时算 sha256,再回填 header)
cat > "$package_file" <<PACKAGE_EOF
# Code Review Package: $task

> generated: $timestamp
> package_sha256: PLACEHOLDER
> head_commit: $head_commit
> task: $goal_text
> scope: ${diff_base:0:8}..${head_commit:0:8}, $(echo "$diff_files" | wc -w | tr -d ' ') code files

## 1. Task Context

### GOAL
$goal_text

### WRITE-SET
$(printf '%s\n' $write_set_files | sed 's/^/- /')

### CONSTRAINTS
$constraints_text

### AC
$ac_text

## 2. Code Changes (diff)
$diff_content

## 3. Surrounding Context
$surrounding_context

## 4. Domain Knowledge
$domain_knowledge

## 5. Review Protocol

$protocol_content

### Adversarial Challenges (must answer all 3)

1. File \`$most_changed_file\` around line $largest_hunk_line contains the most complex change. What happens if it receives empty input or extremely long input?
2. Does this change break any assumptions that \`$another_file\` makes about \`$most_changed_file\`?
3. If someone needs to modify this code 6 months from now, what is the biggest comprehension barrier?

$linter_summary

## 6. Output Format (strict)

Write your review to: \`engine/review/evidence/$task/AGENT-REVIEW.json\`

Schema (all fields required):
\`\`\`json
$schema_example
\`\`\`

**Important**:
- \`write_provenance.commit\`: copy the \`head_commit\` value from this package header
- \`write_provenance.package_sha256\`: copy the \`package_sha256\` value from this package header
- Each finding.message >= 20 characters
- Each dimension must have >= 1 entry (use type="strength" + severity="info" if no issues found)
- Exactly 3 adversarial_responses, each response >= 30 characters
- severity values: critical | high | medium | low | info
- status: "pass" (no critical/high) | "concerns" (has high, acceptable) | "block" (has critical)
PACKAGE_EOF

# 回填 sha256(排除 sha256 行本身,避免鸡生蛋)
# 算法:将 package_sha256 行替换为固定占位符 "COMPUTE" 后计算 hash
package_sha256=$(PKG_FILE="$package_file" "$PY" -c "
import hashlib, re, os
with open(os.environ['PKG_FILE'], encoding='utf-8') as f:
    content = f.read()
# normalize: replace whatever is after 'package_sha256: ' with canonical placeholder
normalized = re.sub(r'(> package_sha256: ).*', r'\1COMPUTE', content)
print(hashlib.sha256(normalized.encode('utf-8')).hexdigest())
")
sed -i "s/package_sha256: PLACEHOLDER/package_sha256: $package_sha256/" "$package_file" 2>/dev/null || \
  PKG_FILE="$package_file" PKG_SHA="$package_sha256" "$PY" -c "
import pathlib, os
p = pathlib.Path(os.environ['PKG_FILE'])
t = p.read_text(encoding='utf-8')
p.write_text(t.replace('package_sha256: PLACEHOLDER', 'package_sha256: ' + os.environ['PKG_SHA']), encoding='utf-8')
"

# === 10. 大小控制(截断周边上下文 → 域知识) ===
package_lines=$(wc -l < "$package_file")
if [ "$package_lines" -gt "$max_package_lines" ]; then
  echo "[engine-review-agent-package] WARN: package is $package_lines lines (limit $max_package_lines), truncating" >&2
  PKG_FILE="$package_file" MAX_LINES="$max_package_lines" "$PY" -c "
import os, re

pkg = os.environ['PKG_FILE']
max_lines = int(os.environ['MAX_LINES'])

with open(pkg, encoding='utf-8') as f:
    lines = f.readlines()

def find_section(lines, header):
    start = end = None
    for i, l in enumerate(lines):
        if l.startswith(header):
            start = i
        elif start is not None and l.startswith('## '):
            end = i
            break
    if start is not None and end is None:
        end = len(lines)
    return start, end

def truncate_section(lines, header, keep_label):
    s, e = find_section(lines, header)
    if s is None:
        return lines, 0
    removed = e - s - 1
    lines[s+1:e] = ['\n', keep_label + '\n', '\n']
    return lines, removed

# Phase 1: truncate surrounding context
lines, r1 = truncate_section(lines, '## 3. Surrounding Context', '_(truncated for size)_')
# Phase 2: if still over, truncate domain knowledge
if len(lines) > max_lines:
    lines, r2 = truncate_section(lines, '## 4. Domain Knowledge', '_(truncated for size)_')
else:
    r2 = 0

with open(pkg, 'w', encoding='utf-8') as f:
    f.writelines(lines)

import sys
print(f'{r1} {r2}', file=sys.stderr)
"
  package_lines=$(wc -l < "$package_file")
fi

echo "[engine-review-agent-package] $task: package ready ($package_lines lines)"
echo "  Output: engine/review/evidence/$task/review-package.md"
echo "  Next: feed this package to your review agent, then run 'engine review-agent $task --validate'"
exit 0
