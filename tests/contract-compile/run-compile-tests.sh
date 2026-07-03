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
SRC="$REPO_ROOT/contract/src/ENGINE_FILE_SYSTEM.md"
DIST="$REPO_ROOT/ENGINE_FILE_SYSTEM_v5.md"
BUDGET="$REPO_ROOT/contract/budget.json"

PS_BIN=""
for c in powershell.exe powershell pwsh; do
  if command -v "$c" >/dev/null 2>&1; then PS_BIN="$c"; break; fi
done

pass=0
fail=0

BANNER='<!-- ENGINE_FILE_SYSTEM_v5.md: compiled from contract/src/ENGINE_FILE_SYSTEM.md by engine compile. Do not edit dist directly; edit src and recompile. -->'

# 编译到指定文件(不覆盖 dist)。
compile_to() {
  { printf '%s\n' "$BANNER"; cat "$SRC"; } > "$1"
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

echo ""
echo "=== B. 减法规则 ==="

# B1: src 行数 ≤ budget.max_lines
max_lines=$(grep -o '"max_lines"[[:space:]]*:[[:space:]]*[0-9]*' "$BUDGET" | grep -o '[0-9]*$')
src_lines=$(wc -l < "$SRC")
if [ "$src_lines" -le "$max_lines" ]; then
  echo "PASS  B1 src-lines-budget ($src_lines ≤ $max_lines)"; pass=$((pass+1))
else
  echo "FAIL  B1 src-lines-budget ($src_lines > $max_lines)——减法规则:新增须净零增长,删并等量旧散文或提升基线(需决策)"; fail=$((fail+1))
fi

# B2: Rule 数 ≤ budget.max_rules
max_rules=$(grep -o '"max_rules"[[:space:]]*:[[:space:]]*[0-9]*' "$BUDGET" | grep -o '[0-9]*$')
rule_count=$(grep -cE '\*\*[^*]*Rule \(v' "$SRC")
if [ "$rule_count" -le "$max_rules" ]; then
  echo "PASS  B2 rule-count-budget ($rule_count ≤ $max_rules)"; pass=$((pass+1))
else
  echo "FAIL  B2 rule-count-budget ($rule_count > $max_rules)——新增 Rule 须删并旧 Rule 或提升基线"; fail=$((fail+1))
fi

echo ""
echo "=== C. sh/ps1 编译产物一致 ==="

# C1: compile.sh 与 compile.ps1 产出的 dist 相同
if [ -n "$PS_BIN" ]; then
  backup="$(mktemp)"; cp "$DIST" "$backup"
  bash "$COMPILE_SH" >/dev/null 2>&1; hash_sh=$(sha256sum "$DIST" | cut -d' ' -f1)
  "$PS_BIN" -NoProfile -ExecutionPolicy Bypass -File "$COMPILE_PS1" >/dev/null 2>&1; hash_ps=$(sha256sum "$DIST" | cut -d' ' -f1)
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
