#!/usr/bin/env bash
# Engine System — 契约编译器(v6 S3 + S3-b + review fix)
#
# 产出 3 个 dist:
#   1. ENGINE_FILE_SYSTEM_v5.md(横幅 + 拼接 4 模块)— web-prompt 全量
#   2. runtime-law.md(L0 宪法,从 L0-runtime-law.md)— ≤40 行常驻法
#   3. rules.json(机读规则表聚合索引)— Doctor/hooks 源文件聚合
#
# 幂等:compile(src) == dist。
# 用法:bash contract/compile.sh

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC_DIR="$ROOT/contract/src"
DIST="$ROOT/ENGINE_FILE_SYSTEM_v5.md"
LAW_DIST="$ROOT/runtime-law.md"
RULES_DIST="$ROOT/rules.json"

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

echo "compile: 3 dist files (web-prompt $(wc -l < "$DIST") lines, runtime-law, rules.json)"
