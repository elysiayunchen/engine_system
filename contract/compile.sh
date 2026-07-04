#!/usr/bin/env bash
# Engine System — 契约编译器(v6 S3 + S3-b + review fix + D-015)
#
# 产出 4 个 dist:
#   1. ENGINE_FILE_SYSTEM_v5.md(横幅 + 拼接 4 模块)— web-prompt 全量
#   2. runtime-law.md(L0 宪法,从 L0-runtime-law.md)— ≤40 行常驻法
#   3. rules.json(机读规则表聚合索引)— Doctor/hooks 源文件聚合
#   4. plugin/.claude/commands/engine-init.md(CLI 前言 + 同一契约模块)
#      — 消灭 init.md 双份实现(设计 §5.5 / D-015)
#
# 幂等:compile(src) == dist。
# 用法:bash contract/compile.sh

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC_DIR="$ROOT/contract/src"
DIST="$ROOT/ENGINE_FILE_SYSTEM_v5.md"
LAW_DIST="$ROOT/runtime-law.md"
RULES_DIST="$ROOT/rules.json"
INIT_DIST="$ROOT/plugin/.claude/commands/engine-init.md"

if [ ! -d "$SRC_DIR" ]; then
  echo "compile: 源目录不存在: $SRC_DIR" >&2
  exit 1
fi

BANNER='<!-- ENGINE_FILE_SYSTEM_v5.md: compiled from contract/src/*.md by engine compile. Do not edit dist directly; edit src and recompile. -->'

# 1. web-prompt(横幅 + 4 模块,按文件名排序)
tmp="$(mktemp)"
{
  printf '%s\n' "$BANNER"
  for m in "$SRC_DIR"/[0-9]*.md; do
    [ -f "$m" ] || continue
    cat "$m"
  done
} > "$tmp"
mv "$tmp" "$DIST"

# 2. runtime-law.md(L0 宪法,从 L0-runtime-law.md 复制)
LAW_SRC="$SRC_DIR/L0-runtime-law.md"
if [ -f "$LAW_SRC" ]; then
  cp "$LAW_SRC" "$LAW_DIST"
fi

# 3. rules.json(机读规则表聚合索引,从 budget.json 提取数字)
BUDGET="$ROOT/contract/budget.json"
max_lines="$(grep -o '"max_lines"[[:space:]]*:[[:space:]]*[0-9]*' "$BUDGET" 2>/dev/null | grep -o '[0-9]*$')"
max_rules="$(grep -o '"max_rules"[[:space:]]*:[[:space:]]*[0-9]*' "$BUDGET" 2>/dev/null | grep -o '[0-9]*$')"
debt="$(grep -o '"debt_baseline"[[:space:]]*:[[:space:]]*[0-9]*' "$BUDGET" 2>/dev/null | grep -o '[0-9]*$')"
{
  printf '{\n'
  printf '  "_comment": "机读规则表(编译产出)。Doctor/hooks 直接读源文件;本文件是聚合索引。",\n'
  printf '  "sources": {\n'
  printf '    "budget": "contract/budget.json",\n'
  printf '    "protected_paths": "engine/decisions/rules.json",\n'
  printf '    "federation": "engine/domains/federation.json"\n'
  printf '  },\n'
  printf '  "max_lines": %s,\n' "${max_lines:-0}"
  printf '  "max_rules": %s,\n' "${max_rules:-0}"
  printf '  "debt_baseline": %s\n' "${debt:-0}"
  printf '}\n'
} > "$RULES_DIST"

# 4. engine-init.md(CLI 命令 dist:前言 + 同一契约模块,D-015)
INIT_BANNER='<!-- plugin/.claude/commands/engine-init.md: compiled from contract/src/ (cli-preamble.md + [0-9]*.md) by engine compile. Do not edit dist directly; edit src and recompile. -->'
PREAMBLE="$SRC_DIR/cli-preamble.md"
if [ -f "$PREAMBLE" ] && [ -d "$(dirname "$INIT_DIST")" ]; then
  tmp="$(mktemp)"
  {
    printf '%s\n' "$INIT_BANNER"
    cat "$PREAMBLE"
    for m in "$SRC_DIR"/[0-9]*.md; do
      [ -f "$m" ] || continue
      cat "$m"
    done
  } > "$tmp"
  mv "$tmp" "$INIT_DIST"
fi

echo "compile: 4 dist files (web-prompt $(wc -l < "$DIST") lines, runtime-law, rules.json, engine-init)"

# 5. plugin/engine/scripts/ 镜像同步(engine/scripts/ 是唯一真相源)
# 改脚本只改 engine/scripts/;compile.sh 自动同步到 plugin/。
# check.sh 漂移检查兜底:若有人绕过 compile 直改 plugin/engine/scripts/ 会报警。
SYNC_LIST="
engine-check-update.ps1
engine-check-update.sh
engine-doctor.ps1
engine-doctor.sh
engine-hook-session-end.ps1
engine-hook-session-end.sh
engine-hook-session-start.ps1
engine-hook-session-start.sh
engine-hook-stop.ps1
engine-hook-stop.sh
engine-hook.cmd
engine-migrate-contract.ps1
engine-migrate-contract.sh
engine-sync-agent-anchors.ps1
engine-sync-agent-anchors.sh
engine-verify.ps1
engine-verify.sh
githooks/pre-commit
"
sync_count=0
for f in $SYNC_LIST; do
  src_file="$ROOT/engine/scripts/$f"
  dst_file="$ROOT/plugin/engine/scripts/$f"
  if [[ -f "$src_file" ]]; then
    mkdir -p "$(dirname "$dst_file")"
    cp "$src_file" "$dst_file"
    sync_count=$((sync_count + 1))
  fi
done
echo "compile: plugin/engine/scripts/ synced ($sync_count files from engine/scripts/)"
