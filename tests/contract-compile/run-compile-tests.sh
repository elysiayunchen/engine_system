#!/usr/bin/env bash
# Engine System — 契约编译测试(v6 S3)
#
# 测试三组:
#   A. 编译幂等(compile(src) == dist)+ 篡改检测(手改 dist 被检出)
#   B. 减法规则(src 行数 ≤ max_lines,Rule 数 ≤ max_rules)
#   C. sh/ps1 编译产物一致
#
# 用法:bash tests/contract-compile/run-compile-tests.sh

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
COMPILE_SH="$REPO_ROOT/contract/compile.sh"
COMPILE_PS1="$REPO_ROOT/contract/compile.ps1"
SRC_DIR="$REPO_ROOT/contract/src"
DIST="$REPO_ROOT/ENGINE_FILE_SYSTEM_v5.md"
BUDGET="$REPO_ROOT/contract/budget.json"

PS_BIN=""
for c in powershell.exe powershell pwsh; do
  if command -v "$c" >/dev/null 2>&1; then PS_BIN="$c"; break; fi
done

pass=0
fail=0

BANNER='<!-- ENGINE_FILE_SYSTEM_v5.md: compiled from contract/src/*.md by engine compile. Do not edit dist directly; edit src and recompile. -->'
INIT_BANNER='<!-- plugin/.claude/commands/engine-init.md: compiled from contract/src/ (cli-preamble.md + [0-9]*.md) by engine compile. Do not edit dist directly; edit src and recompile. -->'
INIT_DIST="$REPO_ROOT/plugin/.claude/commands/engine-init.md"
PREAMBLE="$SRC_DIR/cli-preamble.md"

# 编译到指定文件(不覆盖 dist)。
compile_to() {
  { printf '%s\n' "$BANNER"; for m in "$SRC_DIR"/[0-9]*.md; do [ -f "$m" ] || continue; cat "$m"; done; } > "$1"
}

# 第 4 dist(engine-init.md,D-015)编译到指定文件。
compile_init_to() {
  { printf '%s\n' "$INIT_BANNER"; cat "$PREAMBLE"; for m in "$SRC_DIR"/[0-9]*.md; do [ -f "$m" ] || continue; cat "$m"; done; } > "$1"
}

echo "=== A. 编译幂等 + 篡改检测 ==="

# A1: compile(src) == dist
tmp="$(mktemp)"; compile_to "$tmp"
if diff -q "$tmp" "$DIST" >/dev/null 2>&1; then
  echo "PASS  A1 compile-idempotent"; pass=$((pass+1))
else
  echo "FAIL  A1 compile-idempotent (dist 与 compile(src) 不一致——可能被手改)"; fail=$((fail+1))
fi
rm -f "$tmp"

# A2: dist 头部含编译横幅
if head -1 "$DIST" | grep -q "compiled from contract/src"; then
  echo "PASS  A2 dist-banner-present"; pass=$((pass+1))
else
  echo "FAIL  A2 dist-banner-present"; fail=$((fail+1))
fi

# A3: 篡改检测——手改 dist 后 compile(src) != dist
backup="$(mktemp)"; cp "$DIST" "$backup"
printf 'tampered line\n' >> "$DIST"
tmp="$(mktemp)"; compile_to "$tmp"
if diff -q "$tmp" "$DIST" >/dev/null 2>&1; then
  echo "FAIL  A3 tamper-detect (手改 dist 未被检出)"; fail=$((fail+1))
else
  echo "PASS  A3 tamper-detect"; pass=$((pass+1))
fi
cp "$backup" "$DIST"; rm -f "$tmp" "$backup"

# A4: engine-init.md 幂等(D-015 第 4 dist——消灭 init.md 双份实现)
tmp="$(mktemp)"; compile_init_to "$tmp"
if diff -q "$tmp" "$INIT_DIST" >/dev/null 2>&1; then
  echo "PASS  A4 init-md-idempotent"; pass=$((pass+1))
else
  echo "FAIL  A4 init-md-idempotent (engine-init.md 与 compile(preamble+src) 不一致——可能被手改)"; fail=$((fail+1))
fi
rm -f "$tmp"

# A5: init dist 头部含编译横幅
if head -1 "$INIT_DIST" | grep -q "compiled from contract/src"; then
  echo "PASS  A5 init-banner-present"; pass=$((pass+1))
else
  echo "FAIL  A5 init-banner-present"; fail=$((fail+1))
fi

echo ""
echo "=== B. 减法规则 ==="

# B1: src 行数 ≤ budget.max_lines
max_lines=$(grep -o '"max_lines"[[:space:]]*:[[:space:]]*[0-9]*' "$BUDGET" | grep -o '[0-9]*$')
src_lines=$(cat "$SRC_DIR"/[0-9]*.md | wc -l)
if [ "$src_lines" -le "$max_lines" ]; then
  echo "PASS  B1 src-lines-budget ($src_lines ≤ $max_lines)"; pass=$((pass+1))
else
  echo "FAIL  B1 src-lines-budget ($src_lines > $max_lines)——减法规则:新增须净零增长,删并等量旧散文或提升基线(需决策)"; fail=$((fail+1))
fi

# B2: Rule 数 ≤ budget.max_rules
max_rules=$(grep -o '"max_rules"[[:space:]]*:[[:space:]]*[0-9]*' "$BUDGET" | grep -o '[0-9]*$')
rule_count=$(grep -hE '\*\*[^*]*Rule \(v' "$SRC_DIR"/[0-9]*.md | wc -l)
if [ "$rule_count" -le "$max_rules" ]; then
  echo "PASS  B2 rule-count-budget ($rule_count ≤ $max_rules)"; pass=$((pass+1))
else
  echo "FAIL  B2 rule-count-budget ($rule_count > $max_rules)——新增 Rule 须删并旧 Rule 或提升基线"; fail=$((fail+1))
fi

echo ""
echo "=== C. sh/ps1 编译产物一致 ==="

# C1: compile.sh 与 compile.ps1 产出的 dist(含 engine-init.md)相同
if [ -n "$PS_BIN" ]; then
  backup="$(mktemp)"; cp "$DIST" "$backup"
  bash "$COMPILE_SH" >/dev/null 2>&1; hash_sh=$(cat "$DIST" "$INIT_DIST" | sha256sum | cut -d' ' -f1)
  "$PS_BIN" -NoProfile -ExecutionPolicy Bypass -File "$COMPILE_PS1" >/dev/null 2>&1; hash_ps=$(cat "$DIST" "$INIT_DIST" | sha256sum | cut -d' ' -f1)
  # 恢复 dist 到 sh 产出(若一致则无变化)
  bash "$COMPILE_SH" >/dev/null 2>&1
  if [ "$hash_sh" = "$hash_ps" ]; then
    echo "PASS  C1 sh-ps1-compile-parity"; pass=$((pass+1))
  else
    echo "FAIL  C1 sh-ps1-compile-parity (sh=$hash_sh ps=$hash_ps)"; fail=$((fail+1))
  fi
  rm -f "$backup"
else
  echo "SKIP  C1 sh-ps1-compile-parity (无 PowerShell)"; pass=$((pass+1))
fi

echo ""
echo "=========================================="
echo "PASS=$pass  FAIL=$fail"
[ "$fail" -eq 0 ]
