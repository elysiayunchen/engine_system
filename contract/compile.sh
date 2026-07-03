#!/usr/bin/env bash
# Engine System — 契约编译器(v6 S3 + S3-b)
#
# 把契约源 contract/src/[0-9]*.md(按文件名排序的多模块)编译为 dist ENGINE_FILE_SYSTEM_v5.md。
# 编译 = 头部加编译横幅 + 拼接所有源模块。幂等:compile(src) == dist。
#
# 用法:bash contract/compile.sh
# 编辑契约:改 src 模块,不改 dist;改完跑本脚本重新编译,再 bash scripts/check.sh 验证。

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC_DIR="$ROOT/contract/src"
DIST="$ROOT/ENGINE_FILE_SYSTEM_v5.md"

if [ ! -d "$SRC_DIR" ]; then
  echo "compile: 源目录不存在: $SRC_DIR" >&2
  exit 1
fi

# 编译横幅(HTML 注释,不影响 agent 阅读,机器可 grep)。
BANNER='<!-- ENGINE_FILE_SYSTEM_v5.md: compiled from contract/src/*.md by engine compile. Do not edit dist directly; edit src and recompile. -->'

# 原子写:先写临时文件再 mv,避免半写状态。模块按文件名排序(00/10/20/30)。
tmp="$(mktemp)"
{
  printf '%s\n' "$BANNER"
  for m in "$SRC_DIR"/[0-9]*.md; do
    [ -f "$m" ] || continue
    cat "$m"
  done
} > "$tmp"
mv "$tmp" "$DIST"

echo "compile: $SRC_DIR/*.md -> $DIST ($(wc -l < "$DIST") lines)"
