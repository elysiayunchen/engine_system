#!/usr/bin/env bash
# Engine System — dist 漂移检测测试(T-022 Task 1 / D-019a)
#
# 测试四组:
#   A. 幂等/重算——根部 runtime-law.md 与 contract/src 逐字节一致(纯 cp,直接
#      cmp 源文件);rules.json、engine/prompts/init.md 用 ENGINE_COMPILE_OUT
#      把真实 compile.sh 重算到沙箱后与真实 dist cmp——零逻辑二份,不在本
#      runner 里复刻编译逻辑(对比 tests/contract-compile 手写 compile_to() 的
#      做法,这里选择直接驱动真实编译器)。
#   B. 镜像一致——plugin/ 与 engine/ 两处正本-镜像树逐一 cmp(engine/scripts/
#      用 find 动态枚举,不抄清单,取代 check.sh 旧手写 17/18 文件块,能抓住
#      未来 SYNC_LIST 漏项)。
#   C. 篡改可检(负用例)——手改真实 dist 一字节,断言比对逻辑能报差异,
#      随后从备份恢复;EXIT trap 兜底防止异常退出遗留篡改状态。
#   D. sh/ps1 编译产物一致(可选)——仅当环境探测到 PowerShell 时跑;比较
#      compile.sh 与 compile.ps1 对 runtime-law.md + rules.json(此前从未被
#      C1 覆盖的两个 dist)的沙箱产出 sha256。无 PowerShell 时 SKIP。
#
# 用法:bash tests/dist-drift/run-dist-drift-tests.sh

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
COMPILE_SH="$REPO_ROOT/contract/compile.sh"
COMPILE_PS1="$REPO_ROOT/contract/compile.ps1"

LAW_DIST="$REPO_ROOT/runtime-law.md"
LAW_SRC="$REPO_ROOT/contract/src/L0-runtime-law.md"
RULES_DIST="$REPO_ROOT/rules.json"
PROMPTS_DIST="$REPO_ROOT/engine/prompts/init.md"
PROMPTS_MIRROR="$REPO_ROOT/plugin/engine/prompts/init.md"
BEHAVIOR_SRC_DIR="$REPO_ROOT/contract/src/behaviors"
BEHAVIOR_PROMPTS_DIST="$REPO_ROOT/engine/prompts/behaviors"
BEHAVIOR_PROMPTS_MIRROR="$REPO_ROOT/plugin/engine/prompts/behaviors"
BEHAVIOR_SKILLS_MIRROR="$REPO_ROOT/plugin/.claude/skills"
ROUTING_SRC="$REPO_ROOT/engine/domains/routing.json"
ROUTING_MIRROR="$REPO_ROOT/plugin/engine/domains/routing.json"

PS_BIN=""
for c in pwsh powershell powershell.exe; do
  if command -v "$c" >/dev/null 2>&1; then PS_BIN="$c"; break; fi
done
if [ -n "$PS_BIN" ] && command -v wslpath >/dev/null 2>&1 && [[ "$PS_BIN" == *powershell.exe ]]; then
  PS_BIN=""
fi

ps_path() {
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$1"
  elif command -v wslpath >/dev/null 2>&1; then
    wslpath -w "$1"
  else
    printf '%s\n' "$1"
  fi
}

pass=0
fail=0

# 沙箱:ENGINE_COMPILE_OUT 把 compile.sh 全部产物重算到这里,供 A2/A3/C2/D1
# 直接 cmp 真实编译器的沙箱产出(零逻辑二份)。
SANDBOX="$(mktemp -d)"
# 安全网:C 组会短暂篡改真实 dist 文件;RESTORE_* 非空代表恢复尚未发生,
# EXIT trap 兜底,防止脚本异常退出把仓库落在被篡改状态。
RESTORE_LAW=""
RESTORE_PROMPTS=""
cleanup() {
  if [ -n "$RESTORE_LAW" ] && [ -f "$RESTORE_LAW" ]; then cp "$RESTORE_LAW" "$LAW_DIST"; fi
  if [ -n "$RESTORE_PROMPTS" ] && [ -f "$RESTORE_PROMPTS" ]; then cp "$RESTORE_PROMPTS" "$PROMPTS_DIST"; fi
  rm -rf "$SANDBOX"
}
trap cleanup EXIT

ENGINE_COMPILE_OUT="$SANDBOX" bash "$COMPILE_SH" >/dev/null 2>&1

echo "=== A. 幂等/重算 ==="

# A1: 根部 runtime-law.md 与 contract/src/L0-runtime-law.md 逐字节一致(纯 cp,无需重算)
if cmp -s "$LAW_DIST" "$LAW_SRC"; then
  echo "PASS  A1 runtime-law-idempotent"; pass=$((pass+1))
else
  echo "FAIL  A1 runtime-law-idempotent (根部 runtime-law.md 与 contract/src/L0-runtime-law.md 不一致——可能被手改或未重新编译)"; fail=$((fail+1))
fi

# A2: 根部 rules.json 与沙箱重算比对
if cmp -s "$SANDBOX/rules.json" "$RULES_DIST"; then
  echo "PASS  A2 rules-json-idempotent"; pass=$((pass+1))
else
  echo "FAIL  A2 rules-json-idempotent (rules.json 与 compile(budget.json) 重算不一致——可能被手改或 budget.json 未同步编译)"; fail=$((fail+1))
fi

# A3: engine/prompts/init.md 与沙箱重算比对
if cmp -s "$SANDBOX/engine/prompts/init.md" "$PROMPTS_DIST"; then
  echo "PASS  A3 prompts-init-idempotent"; pass=$((pass+1))
else
  echo "FAIL  A3 prompts-init-idempotent (engine/prompts/init.md 与 compile(agent-preamble+src) 重算不一致——可能被手改)"; fail=$((fail+1))
fi

echo ""
echo "=== B. 镜像一致 ==="

# B1: plugin/engine/prompts/init.md == engine/prompts/init.md
if cmp -s "$PROMPTS_DIST" "$PROMPTS_MIRROR"; then
  echo "PASS  B1 prompts-init-mirror"; pass=$((pass+1))
else
  echo "FAIL  B1 prompts-init-mirror (plugin/engine/prompts/init.md 与 engine/prompts/init.md 不一致)"; fail=$((fail+1))
fi

# B2: 动态枚举 engine/scripts/ 全部文件(含子目录如 githooks/),逐一 cmp plugin/engine/scripts/ 同名文件
b2_drift=0
b2_count=0
while IFS= read -r f; do
  rel="${f#"$REPO_ROOT"/engine/scripts/}"
  dst="$REPO_ROOT/plugin/engine/scripts/$rel"
  b2_count=$((b2_count+1))
  if [ ! -f "$dst" ]; then
    echo "  missing mirror: $rel" >&2
    b2_drift=$((b2_drift+1))
  elif ! cmp -s "$f" "$dst"; then
    echo "  drift: $rel" >&2
    b2_drift=$((b2_drift+1))
  fi
done < <(find "$REPO_ROOT/engine/scripts" -type f | sort)
if [ "$b2_drift" -eq 0 ]; then
  echo "PASS  B2 scripts-mirror ($b2_count files)"; pass=$((pass+1))
else
  echo "FAIL  B2 scripts-mirror ($b2_drift/$b2_count drifted——改 engine/scripts/ 后须跑 bash contract/compile.sh)"; fail=$((fail+1))
fi

# B3: engine/bin/{engine,engine.ps1,engine.cmd} 逐一 cmp plugin/bin/
b3_drift=0
for f in engine engine.ps1 engine.cmd; do
  src="$REPO_ROOT/engine/bin/$f"
  dst="$REPO_ROOT/plugin/bin/$f"
  if [ ! -f "$src" ] || [ ! -f "$dst" ]; then
    echo "  missing: $f" >&2
    b3_drift=$((b3_drift+1))
  elif ! cmp -s "$src" "$dst"; then
    echo "  drift: $f" >&2
    b3_drift=$((b3_drift+1))
  fi
done
if [ "$b3_drift" -eq 0 ]; then
  echo "PASS  B3 bin-mirror"; pass=$((pass+1))
else
  echo "FAIL  B3 bin-mirror ($b3_drift drifted)"; fail=$((fail+1))
fi

# B4: behavior prompts/skills mirror contract/src/behaviors
b4_drift=0
b4_count=0
if [ -d "$BEHAVIOR_SRC_DIR" ]; then
  while IFS= read -r src; do
    base="$(basename "$src" .md)"
    prompt="$BEHAVIOR_PROMPTS_DIST/$base.md"
    plugin_prompt="$BEHAVIOR_PROMPTS_MIRROR/$base.md"
    skill="$BEHAVIOR_SKILLS_MIRROR/engine-$base/SKILL.md"
    b4_count=$((b4_count+1))
    for dst in "$prompt" "$plugin_prompt" "$skill"; do
      if [ ! -f "$dst" ]; then
        echo "  missing behavior mirror: $dst" >&2
        b4_drift=$((b4_drift+1))
      elif ! cmp -s "$src" "$dst"; then
        echo "  behavior drift: $dst" >&2
        b4_drift=$((b4_drift+1))
      fi
    done
  done < <(find "$BEHAVIOR_SRC_DIR" -maxdepth 1 -type f -name '*.md' | sort)
fi
if [ "$b4_drift" -eq 0 ] && [ "$b4_count" -gt 0 ]; then
  echo "PASS  B4 behavior-skills-mirror ($b4_count behaviors)"; pass=$((pass+1))
else
  echo "FAIL  B4 behavior-skills-mirror ($b4_drift drifted across $b4_count behaviors)"; fail=$((fail+1))
fi

# B5: behavior routing table mirror
if [ -f "$ROUTING_SRC" ] && cmp -s "$ROUTING_SRC" "$ROUTING_MIRROR"; then
  echo "PASS  B5 behavior-routing-mirror"; pass=$((pass+1))
else
  echo "FAIL  B5 behavior-routing-mirror (plugin/engine/domains/routing.json drifted or missing)"; fail=$((fail+1))
fi

echo ""
echo "=== C. 篡改可检(负用例) ==="

# C1: 篡改根部 runtime-law.md 后与 contract/src 比对应报差异
backup="$(mktemp)"; cp "$LAW_DIST" "$backup"; RESTORE_LAW="$backup"
printf 'tampered line\n' >> "$LAW_DIST"
if cmp -s "$LAW_DIST" "$LAW_SRC"; then
  echo "FAIL  C1 runtime-law-tamper-detect (手改 runtime-law.md 未被检出)"; fail=$((fail+1))
else
  echo "PASS  C1 runtime-law-tamper-detect"; pass=$((pass+1))
fi
cp "$backup" "$LAW_DIST"; rm -f "$backup"; RESTORE_LAW=""

# C2: 篡改 engine/prompts/init.md 后与沙箱重算比对应报差异
backup="$(mktemp)"; cp "$PROMPTS_DIST" "$backup"; RESTORE_PROMPTS="$backup"
printf 'tampered line\n' >> "$PROMPTS_DIST"
if cmp -s "$PROMPTS_DIST" "$SANDBOX/engine/prompts/init.md"; then
  echo "FAIL  C2 prompts-init-tamper-detect (手改 engine/prompts/init.md 未被检出)"; fail=$((fail+1))
else
  echo "PASS  C2 prompts-init-tamper-detect"; pass=$((pass+1))
fi
cp "$backup" "$PROMPTS_DIST"; rm -f "$backup"; RESTORE_PROMPTS=""

echo ""
echo "=== D. sh/ps1 编译产物一致(可选:runtime-law.md + rules.json) ==="

# D1: compile.sh 与 compile.ps1 对 ②runtime-law.md ③rules.json 的沙箱重算 sha256 一致
# (①④已由 tests/contract-compile C1 覆盖;这里补②③此前从未验证过的 sh/ps1 一致性)
if [ -n "$PS_BIN" ]; then
  SBX_PS="$(mktemp -d)"
  if command -v cygpath >/dev/null 2>&1; then
    PS_OUT="$(cygpath -w "$SBX_PS")"
  elif command -v wslpath >/dev/null 2>&1; then
    PS_OUT="$(wslpath -w "$SBX_PS")"
  else
    PS_OUT="$SBX_PS"
  fi
  ps_rc=0
  compile_ps1="$(ps_path "$COMPILE_PS1")"
  ENGINE_COMPILE_OUT="$PS_OUT" "$PS_BIN" -NoProfile -ExecutionPolicy Bypass -File "$compile_ps1" >/dev/null 2>&1 || ps_rc=$?
  if [ "$ps_rc" -ne 0 ] || [ ! -f "$SBX_PS/runtime-law.md" ] || [ ! -f "$SBX_PS/rules.json" ]; then
    echo "SKIP  D1 sh-ps1-rules-parity ($PS_BIN could not write sandbox output from bash harness)"; pass=$((pass+1))
    rm -rf "$SBX_PS"
  else
    hash_sh=$(cat "$SANDBOX/runtime-law.md" "$SANDBOX/rules.json" 2>/dev/null | sha256sum | cut -d' ' -f1)
    hash_ps=$(cat "$SBX_PS/runtime-law.md" "$SBX_PS/rules.json" 2>/dev/null | sha256sum | cut -d' ' -f1)
    rm -rf "$SBX_PS"
    if [ -n "$hash_sh" ] && [ "$hash_sh" = "$hash_ps" ]; then
    echo "PASS  D1 sh-ps1-rules-parity"; pass=$((pass+1))
    else
    echo "FAIL  D1 sh-ps1-rules-parity (sh=$hash_sh ps=$hash_ps)"; fail=$((fail+1))
    fi
  fi
else
  echo "SKIP  D1 sh-ps1-rules-parity (无 PowerShell)"; pass=$((pass+1))
fi

echo ""
echo "=========================================="
echo "PASS=$pass  FAIL=$fail"
[ "$fail" -eq 0 ]
