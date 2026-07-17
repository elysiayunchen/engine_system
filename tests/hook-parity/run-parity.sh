#!/usr/bin/env bash
# Engine System — 收尾守门员 sh/ps1 等价测试(hook parity fixtures)
#
# 目的:同一套真实 git 仓库场景,分别喂给 engine-hook-stop.sh 与 engine-hook-stop.ps1,
# 断言两个实现给出完全一致的判定(block / warn / pass)。这是 v6 S0"诚实门禁"的
# 机器背书:跨语言孪生实现的语义分歧(如 rename 取旧路径 vs 新路径)在这里现形,
# 而不是在用户的项目里现形。
#
# 场景特意覆盖两类历史病灶:
#   - 中文路径:默认 core.quotepath=true 会引号+八进制转义,击穿逐行列位解析(旧实现假阳性);
#   - rename:porcelain 普通格式 "R old -> new" 的箭头解析曾在 sh/ps1 两边语义相反。
#
# 用法:bash tests/hook-parity/run-parity.sh
# 无 PowerShell 的环境自动跳过 ps1 侧(打印 SKIP),sh 侧仍全量断言。
# 退出码:0 = 全部通过;1 = 存在失败。

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
STOP_SH="$REPO_ROOT/plugin/engine/scripts/engine-hook-stop.sh"
STOP_PS1="$REPO_ROOT/plugin/engine/scripts/engine-hook-stop.ps1"
PRE_COMMIT="$REPO_ROOT/plugin/engine/scripts/githooks/pre-commit"
PAYLOAD_DEFAULT='{"stop_hook_active":false}'

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
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

# 判定归一化:两个实现的 reason 文案是双语的,比对的是"判定类别"而非全文。
classify() {
  case "$1" in
    *'"decision":"block"'*) echo block ;;
    *'"systemMessage"'*)    echo warn ;;
    *)                      echo pass ;;
  esac
}

# 新建一个带引擎层的干净仓库(显式钉住 core.quotepath=true:测的就是默认转义行为)。
new_repo() {
  d="$(mktemp -d "$TMP_ROOT/repo.XXXXXX")"
  git -C "$d" init -q
  git -C "$d" config user.email parity@test
  git -C "$d" config user.name parity
  git -C "$d" config core.quotepath true
  git -C "$d" config core.autocrlf false
  git -C "$d" config commit.gpgsign false
  mkdir -p "$d/engine/changes" "$d/engine/tasks" "$d/engine/workstreams" "$d/src"
  printf 'ctx\n' > "$d/engine/CONTEXT.md"
  printf 'hf\n'  > "$d/engine/HANDOFF.md"
  printf 'code\n' > "$d/src/app.js"
  printf 'notes\n' > "$d/engine/设计笔记.md"
  git -C "$d" add -A
  git -C "$d" commit -qm init
  printf '%s\n' "$d"
}

write_task() {
  repo="$1"
  cat > "$repo/engine/tasks/T-001.md" <<'EOF'
# TASK CARD — T-001
> status: active | lane: main | decision: | plan: none | domain: root
GOAL: parity
WRITE-SET: src/**,engine/CONTEXT.md,engine/HANDOFF.md,engine/workstreams/**
FORBIDDEN: engine/SECRET.md
AC: AC-1 parity → verify: true
EOF
  git -C "$repo" add engine/tasks/T-001.md
  git -C "$repo" commit -qm task
}

# run_case <场景名> <仓库路径> <期望判定> [payload]
run_case() {
  name="$1"; repo="$2"; expect="$3"; payload="${4:-$PAYLOAD_DEFAULT}"

  out_sh="$(printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$repo" bash "$STOP_SH" 2>/dev/null)"
  got_sh="$(classify "$out_sh")"
  if [ "$got_sh" = "$expect" ]; then
    echo "PASS  sh   $name -> $got_sh"
    pass=$((pass + 1))
  else
    echo "FAIL  sh   $name -> expect=$expect got=$got_sh out=${out_sh:-<empty>}"
    fail=$((fail + 1))
  fi

  if [ -n "$PS_BIN" ]; then
    repo_ps="$(ps_path "$repo")"
    stop_ps1="$(ps_path "$STOP_PS1")"
    out_ps="$(printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$repo_ps" "$PS_BIN" -NoProfile -ExecutionPolicy Bypass -File "$stop_ps1" 2>/dev/null)"
    got_ps="$(classify "$out_ps")"
    if [ "$got_ps" = "$expect" ]; then
      echo "PASS  ps1  $name -> $got_ps"
      pass=$((pass + 1))
    else
      echo "FAIL  ps1  $name -> expect=$expect got=$got_ps out=${out_ps:-<empty>}"
      fail=$((fail + 1))
    fi
  else
    echo "SKIP  ps1  $name (no PowerShell on this host)"
  fi
}

run_pre_case() {
  name="$1"; repo="$2"; expect="$3"; payload="$4"
  out_sh="$(printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$repo" bash "$STOP_SH" --pre-tool-use 2>/dev/null)"
  got_sh="$(classify "$out_sh")"
  if [ "$got_sh" = "$expect" ]; then
    echo "PASS  sh   $name -> $got_sh"; pass=$((pass + 1))
  else
    echo "FAIL  sh   $name -> expect=$expect got=$got_sh out=${out_sh:-<empty>}"; fail=$((fail + 1))
  fi

  if [ -n "$PS_BIN" ]; then
    repo_ps="$(ps_path "$repo")"
    stop_ps1="$(ps_path "$STOP_PS1")"
    out_ps="$(printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$repo_ps" "$PS_BIN" -NoProfile -ExecutionPolicy Bypass -File "$stop_ps1" -Mode --pre-tool-use 2>/dev/null)"
    got_ps="$(classify "$out_ps")"
    if [ "$got_ps" = "$expect" ]; then
      echo "PASS  ps1  $name -> $got_ps"; pass=$((pass + 1))
    else
      echo "FAIL  ps1  $name -> expect=$expect got=$got_ps out=${out_ps:-<empty>}"; fail=$((fail + 1))
    fi
  else
    echo "SKIP  ps1  $name (no PowerShell on this host)"
  fi
}

echo "=== Stop hook parity: $(basename "$STOP_SH") vs $(basename "$STOP_PS1") ==="

# 1. 纯代码改动,无回写 → 硬门禁拦截
r="$(new_repo)"; printf 'x\n' >> "$r/src/app.js"
run_case "code-only" "$r" block

# 2. 代码改动 + CONTEXT 回写,无 capsule → 软门禁 WARN
r="$(new_repo)"; printf 'x\n' >> "$r/src/app.js"; printf 'x\n' >> "$r/engine/CONTEXT.md"
run_case "writeback-no-capsule" "$r" warn

# 3. 代码 + 回写 + capsule → 完整回写,放行
r="$(new_repo)"; printf 'x\n' >> "$r/src/app.js"; printf 'x\n' >> "$r/engine/CONTEXT.md"
printf 'capsule\n' > "$r/engine/changes/CHANGE-2026-01-01-01.md"
run_case "full-writeback" "$r" pass

# 4. 只动引擎文档 → 非代码,放行
r="$(new_repo)"; printf 'x\n' >> "$r/engine/HANDOFF.md"
run_case "engine-only" "$r" pass

# 5. 中文引擎文档改动 → 放行(回归:quotepath 引号转义曾把它击穿成"代码"而误拦)
r="$(new_repo)"; printf 'x\n' >> "$r/engine/设计笔记.md"
run_case "unicode-engine-doc" "$r" pass

# 6. 代码 rename + CONTEXT 回写 → WARN(回归:-z 的旧路径字段若没跳过,会吞掉后续记录)
r="$(new_repo)"; git -C "$r" mv src/app.js src/app-renamed.js; printf 'x\n' >> "$r/engine/CONTEXT.md"
run_case "rename-then-writeback" "$r" warn

# 7. stop_hook_active=true → 防死循环,直接放行
r="$(new_repo)"; printf 'x\n' >> "$r/src/app.js"
run_case "stop-hook-active" "$r" pass '{"stop_hook_active":true}'

# 8. 只写 capsule,没动代码 → 放行(capsule 属引擎层)
r="$(new_repo)"; printf 'capsule\n' > "$r/engine/changes/CHANGE-2026-01-01-01.md"
run_case "capsule-only" "$r" pass

echo ""
echo "=== PreToolUse attribution + worker isolation ==="

# 9. 主 agent 写前也受 WRITE-SET 约束
r="$(new_repo)"; write_task "$r"
payload='{"session_id":"s-main","tool_name":"Edit","tool_input":{"file_path":"engine/SYSTEM.md"}}'
run_pre_case "pre-main-out-of-scope" "$r" block "$payload"

# 10. 子 agent 不能抢写共享 CONTEXT，即使它在任务写集内
r="$(new_repo)"; write_task "$r"
payload='{"session_id":"s-worker","agent_id":"worker-1","tool_name":"Edit","tool_input":{"file_path":"engine/CONTEXT.md"}}'
run_pre_case "pre-worker-shared-block" "$r" block "$payload"

# 11. 子 agent 只能写自己的 workstream 分片
r="$(new_repo)"; write_task "$r"
payload='{"session_id":"s-worker","agent_id":"worker-1","tool_name":"Write","tool_input":{"file_path":"engine/workstreams/T-001/worker-1/HANDOFF.md"}}'
run_pre_case "pre-worker-own-shard" "$r" pass "$payload"
payload='{"session_id":"s-worker","agent_id":"worker-1","tool_name":"Write","tool_input":{"file_path":"engine/workstreams/T-001/worker-2/HANDOFF.md"}}'
run_pre_case "pre-worker-sibling-shard" "$r" block "$payload"

# 12. session 路径清单防止兄弟 agent 的 CONTEXT 改动替本 agent 满足回写
r="$(new_repo)"; write_task "$r"
payload='{"session_id":"s-owned","agent_id":"worker-1","tool_name":"Edit","tool_input":{"file_path":"src/app.js"}}'
run_pre_case "pre-owned-code" "$r" pass "$payload"
printf 'x\n' >> "$r/src/app.js"
printf 'sibling\n' >> "$r/engine/CONTEXT.md"
run_case "session-does-not-borrow-sibling-writeback" "$r" block "$payload"

echo ""
echo "=== pre-commit parity (B 层门禁) ==="

# pc_case <场景名> <仓库路径> <期望退出码>
pc_case() {
  name="$1"; repo="$2"; expect_rc="$3"
  ( cd "$repo" && sh "$PRE_COMMIT" >/dev/null 2>&1 )
  rc=$?
  if [ "$rc" -eq "$expect_rc" ]; then
    echo "PASS  pc   $name -> rc=$rc"
    pass=$((pass + 1))
  else
    echo "FAIL  pc   $name -> expect rc=$expect_rc got rc=$rc"
    fail=$((fail + 1))
  fi
}

# 9. 暂存纯代码,无回写 → 拦截(rc=1)
r="$(new_repo)"; printf 'x\n' >> "$r/src/app.js"; git -C "$r" add src/app.js
pc_case "staged-code-only" "$r" 1

# 10. 暂存中文引擎文档 → 放行(回归:quotepath 曾把它误判成代码拦下)
r="$(new_repo)"; printf 'x\n' >> "$r/engine/设计笔记.md"; git -C "$r" add "engine/设计笔记.md"
pc_case "staged-unicode-engine-doc" "$r" 0

# 11. 暂存代码 + CONTEXT → 放行
r="$(new_repo)"; printf 'x\n' >> "$r/src/app.js"; printf 'x\n' >> "$r/engine/CONTEXT.md"; git -C "$r" add -A
pc_case "staged-code-plus-writeback" "$r" 0

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "parity result: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
