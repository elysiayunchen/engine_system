#!/usr/bin/env bash
# Engine System — 契约编译器(v6 S3)
#
# 把契约源 contract/src/ENGINE_FILE_SYSTEM.md 编译为 dist ENGINE_FILE_SYSTEM_v5.md。
# 编译 = 头部加编译横幅 + src 内容。幂等:compile(src) == dist。
#
# 用法:bash contract/compile.sh
# 编辑契约:改 src,不改 dist;改完跑本脚本重新编译,再 bash scripts/check.sh 验证。

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/contract/src/ENGINE_FILE_SYSTEM.md"
DIST="$ROOT/ENGINE_FILE_SYSTEM_v5.md"

if [ ! -f "$SRC" ]; then
  echo "compile: 源文件不存在: $SRC" >&2
  exit 1
fi

# 编译横幅(HTML 注释,不影响 agent 阅读,机器可 grep)。
BANNER='<!-- ENGINE_FILE_SYSTEM_v5.md: compiled from contract/src/ENGINE_FILE_SYSTEM.md by engine compile. Do not edit dist directly; edit src and recompile. -->'

# 原子写:先写临时文件再 mv,避免半写状态。
tmp="$(mktemp)"
{
  printf '%s\n' "$BANNER"
  cat "$SRC"
} > "$tmp"
mv "$tmp" "$DIST"

echo "compile: $SRC -> $DIST ($(wc -l < "$DIST") lines)"
