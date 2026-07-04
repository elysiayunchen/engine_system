#!/usr/bin/env bash
# Engine System — Doctor 占位符检测回归测试(D-016)
#
# 验证 check_change_capsule_semantics 的占位符正则在剔除代码块(```...``` )
# 与内联代码(`...` )后,不再误报 JSON [] ,且真 [TBD] 占位符仍被检出。
#   D1. 内联代码 `{"rules":[]}` 不误报
#   D2. 代码块 ```json {"rules":[]} ``` 不误报
#   D3. 真 [TBD] 占位符仍检出
#   D4. sh 与 ps1 行为一致(若 pwsh 可用)
#
# 用法:bash tests/doctor-parity/run-doctor-tests.sh

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"

pass=0
fail=0
ok()  { echo "PASS  $1"; pass=$((pass+1)); }
bad() { echo "FAIL  $1"; fail=$((fail+1)); }

# 临时胶囊:放到真实 engine/changes/ 以复用项目 doctor 上下文;
# touch 未来时间确保它成为"最新"胶囊(find %T@ sort -nr / LastWriteTime desc)
CAP="$REPO_ROOT/engine/changes/CHANGE-2099-12-31-DOCTOR-TEST.md"
cleanup() { rm -f "$CAP"; }
trap cleanup EXIT

# 写胶囊:8 个 section 齐全(避免 missing-section 噪声),Goal 段由 $1 提供;
# 用 printf '%s' 而非 echo/heredoc,防反引号触发命令替换
write_capsule() {
  {
    printf '%s\n' "## Goal"
    printf '%s\n' "$1"
    printf '\n'
    printf '%s\n\n' "## Actual Changes"
    printf '%s\n\n' "## Impact Scope"
    printf '%s\n\n' "## Risk & Watchpoints"
    printf '%s\n\n' "## Verification"
    printf '%s\n\n' "## Rollback"
    printf '%s\n\n' "## Next Step"
    printf '%s\n\n' "## Responsibility Boundary"
  } > "$CAP"
  touch -t 209912312359 "$CAP" 2>/dev/null || touch "$CAP"
}

warned() { grep -q "CHANGE-2099-12-31-DOCTOR-TEST.md still contains placeholders" <<< "$1"; }

echo "=== Doctor 占位符检测(D-016)==="

# D1: 内联代码 `{"rules":[]}` 不误报
write_capsule '基线由 `{"rules":[]}` 改为 `{"rules":[],"protected_paths":[]}`。'
out="$(bash "$REPO_ROOT/engine/scripts/engine-doctor.sh" "$REPO_ROOT" 2>&1)"
if warned "$out"; then bad "D1 inline-code JSON [] 误报"; else ok "D1 inline-code JSON [] 不误报"; fi

# D2: 代码块 JSON [] 不误报(代码块里的 [] 应被 sed 剔除)
write_capsule $'基线见下:\n```json\n{"rules":[],"protected_paths":[]}\n```'
out="$(bash "$REPO_ROOT/engine/scripts/engine-doctor.sh" "$REPO_ROOT" 2>&1)"
if warned "$out"; then bad "D2 code-block JSON [] 误报"; else ok "D2 code-block JSON [] 不误报"; fi

# D3: 真 [TBD] 占位符仍检出
write_capsule '[TBD] 待填写目标'
out="$(bash "$REPO_ROOT/engine/scripts/engine-doctor.sh" "$REPO_ROOT" 2>&1)"
if warned "$out"; then ok "D3 real [TBD] placeholder detected"; else bad "D3 真 [TBD] 占位符未检出"; fi

# D4: sh 与 ps1 行为一致(若 pwsh 可用)
if command -v pwsh >/dev/null 2>&1; then
  write_capsule '基线由 `{"rules":[]}` 改为 `{"rules":[],"protected_paths":[]}`。'
  out_sh="$(bash "$REPO_ROOT/engine/scripts/engine-doctor.sh" "$REPO_ROOT" 2>&1)"
  out_ps="$(pwsh -NoProfile -File "$REPO_ROOT/engine/scripts/engine-doctor.ps1" -Root "$REPO_ROOT" 2>&1)"
  sh_w="$(grep -c "still contains placeholders" <<< "$out_sh" || true)"
  ps_w="$(grep -c "still contains placeholders" <<< "$out_ps" || true)"
  if [ "$sh_w" = "$ps_w" ]; then
    ok "D4 sh/ps1 parity (both=$sh_w)"
  else
    bad "D4 sh/ps1 parity (sh=$sh_w ps=$ps_w)"
  fi
else
  ok "D4 pwsh unavailable, skip parity"
fi

echo ""
echo "=========================================="
echo "PASS=$pass  FAIL=$fail"
[ "$fail" -eq 0 ]
