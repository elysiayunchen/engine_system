#!/usr/bin/env bash
# Engine System — 任务卡门禁测试(v6 S1)
#
# 测试三层:
#   A. Stop hook WRITE-SET / FORBIDDEN 校验(有 active 任务卡时)
#   B. Stop hook 向后兼容(无 active 任务卡时)
#   C. pre-commit 受保护路径决策引用门禁
#
# 用法:bash tests/task-card/run-task-tests.sh

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
STOP_SH="$REPO_ROOT/plugin/engine/scripts/engine-hook-stop.sh"
STOP_PS1="$REPO_ROOT/plugin/engine/scripts/engine-hook-stop.ps1"
PRE_COMMIT="$REPO_ROOT/plugin/engine/scripts/githooks/pre-commit"
PAYLOAD='{"stop_hook_active":false}'

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

classify() {
  case "$1" in
    *'"decision":"block"'*) echo block ;;
    *'"systemMessage"'*)    echo warn ;;
    *)                      echo pass ;;
  esac
}

new_repo() {
  d="$(mktemp -d "$TMP_ROOT/repo.XXXXXX")"
  git -C "$d" init -q
  git -C "$d" config user.email tc@test
  git -C "$d" config user.name tc
  git -C "$d" config core.quotepath true
  git -C "$d" config core.autocrlf false
  git -C "$d" config commit.gpgsign false
  mkdir -p "$d/engine/tasks" "$d/engine/decisions" "$d/engine/changes" "$d/src" "$d/lib" "$d/src/payment"
  printf 'ctx\n' > "$d/engine/CONTEXT.md"
  printf 'hf\n'  > "$d/engine/HANDOFF.md"
  printf 'code\n' > "$d/src/app.js"
  git -C "$d" add -A
  git -C "$d" commit -qm init
  printf '%s\n' "$d"
}

enable_strict_v65() {
  repo="$1"
  cat > "$repo/AGENTS.md" <<'EOF'
# AGENTS.md
<!-- ENGINE_SYSTEM_CONTRACT_MIGRATIONS_START -->
<!-- contract-version: 6.5.0 -->
strict fixture
<!-- ENGINE_SYSTEM_CONTRACT_MIGRATIONS_END -->
EOF
  git -C "$repo" add AGENTS.md
  git -C "$repo" commit -qm 'enable v6.5 strict workflow'
}

write_task() {
  repo="$1"; id="$2"; status="$3"; write_set="$4"; forbidden="$5"; decision="${6:-}"
  cat > "$repo/engine/tasks/$id.md" <<EOF
# TASK CARD — $id
> status: $status | lane: main | decision: $decision | plan: none | domain: root
GOAL: test task
WRITE-SET: $write_set,engine/CONTEXT.md,engine/HANDOFF.md,engine/changes/**
FORBIDDEN: $forbidden
AC: AC-1 test → verify: true
CONSTRAINTS: none
EOF
  git -C "$repo" add "engine/tasks/$id.md"
  git -C "$repo" commit -qm "task $id"
}

write_task_section() {
  repo="$1"; id="$2"; status="$3"; write_set="$4"; forbidden="$5"; decision="${6:-}"
  cat > "$repo/engine/tasks/$id.md" <<EOF
# TASK CARD — $id
> status: $status | lane: main | decision: $decision | plan: none | domain: root

## GOAL
test task

## WRITE-SET
- $write_set
- engine/CONTEXT.md
- engine/HANDOFF.md
- engine/changes/**

## FORBIDDEN
EOF
  if [ -n "$forbidden" ]; then printf '%s\n' "- $forbidden (architect veto)" >> "$repo/engine/tasks/$id.md"; fi
  cat >> "$repo/engine/tasks/$id.md" <<EOF

## AC
AC: AC-1 test → verify: true
EOF
  git -C "$repo" add "engine/tasks/$id.md"
  git -C "$repo" commit -qm "section task $id"
}

write_decision() {
  repo="$1"; id="$2"; status="$3"; scope="$4"
  cat > "$repo/engine/decisions/$id.md" <<EOF
# $id — test decision
> status: $status
> date: 2026-07-03
> expiry: none
> scope: $scope
选项: A test(选定) / B alt
理由: test
后果: test
EOF
}

write_capsule() {
  repo="$1"
  printf '# CHANGE-test\ntest capsule\n' > "$repo/engine/changes/CHANGE-2026-07-03-01.md"
}

write_rules() {
  repo="$1"; shift
  printf '{\n  "protected_paths": [\n' > "$repo/engine/decisions/rules.json"
  first=1
  for p in "$@"; do
    [ "$first" -eq 1 ] || printf ',\n' >> "$repo/engine/decisions/rules.json"
    printf '    "%s"' "$p" >> "$repo/engine/decisions/rules.json"
    first=0
  done
  printf '\n  ]\n}\n' >> "$repo/engine/decisions/rules.json"
}

run_stop() {
  name="$1"; repo="$2"; expect="$3"
  out="$(printf '%s' "$PAYLOAD" | CLAUDE_PROJECT_DIR="$repo" bash "$STOP_SH" 2>/dev/null)"
  got="$(classify "$out")"
  if [ "$got" = "$expect" ]; then
    echo "PASS  sh  $name -> $got"; pass=$((pass+1))
  else
    echo "FAIL  sh  $name -> expect=$expect got=$got out=${out:0:80}"; fail=$((fail+1))
  fi
  if [ -n "$PS_BIN" ]; then
    repo_ps="$(ps_path "$repo")"
    stop_ps1="$(ps_path "$STOP_PS1")"
    out_ps="$(printf '%s' "$PAYLOAD" | CLAUDE_PROJECT_DIR="$repo_ps" "$PS_BIN" -NoProfile -ExecutionPolicy Bypass -File "$stop_ps1" 2>/dev/null)"
    got_ps="$(classify "$out_ps")"
    if [ "$got_ps" = "$expect" ]; then
      echo "PASS  ps1 $name -> $got_ps"; pass=$((pass+1))
    else
      echo "FAIL  ps1 $name -> expect=$expect got=$got_ps out=${out_ps:0:80}"; fail=$((fail+1))
    fi
  fi
}

run_pre() {
  name="$1"; repo="$2"; expect="$3"; pre_payload="$4"
  out="$(printf '%s' "$pre_payload" | CLAUDE_PROJECT_DIR="$repo" bash "$STOP_SH" --pre-tool-use 2>/dev/null)"
  got="$(classify "$out")"
  if [ "$got" = "$expect" ]; then
    echo "PASS  sh  $name -> $got"; pass=$((pass+1))
  else
    echo "FAIL  sh  $name -> expect=$expect got=$got out=${out:0:120}"; fail=$((fail+1))
  fi
  if [ -n "$PS_BIN" ]; then
    repo_ps="$(ps_path "$repo")"
    stop_ps1="$(ps_path "$STOP_PS1")"
    out_ps="$(printf '%s' "$pre_payload" | CLAUDE_PROJECT_DIR="$repo_ps" "$PS_BIN" -NoProfile -ExecutionPolicy Bypass -File "$stop_ps1" -Mode --pre-tool-use 2>/dev/null)"
    got_ps="$(classify "$out_ps")"
    if [ "$got_ps" = "$expect" ]; then
      echo "PASS  ps1 $name -> $got_ps"; pass=$((pass+1))
    else
      echo "FAIL  ps1 $name -> expect=$expect got=$got_ps out=${out_ps:0:120}"; fail=$((fail+1))
    fi
  fi
}

run_pc() {
  name="$1"; repo="$2"; expect_rc="$3"
  pc_out="$(cd "$repo" && CLAUDE_PROJECT_DIR="$repo" sh "$PRE_COMMIT" 2>&1)"
  rc=$?
  if [ "$rc" -eq "$expect_rc" ]; then
    echo "PASS  pc  $name -> rc=$rc"; pass=$((pass+1))
  else
    echo "FAIL  pc  $name -> expect rc=$expect_rc got rc=$rc out=${pc_out:0:240}"; fail=$((fail+1))
  fi
}

echo "=== A. Stop hook WRITE-SET / FORBIDDEN 校验 ==="

# A1. 代码路径在 WRITE-SET 内 + 回写 + capsule → pass
r="$(new_repo)"; write_task "$r" T-001 active "src/**" ""; write_capsule "$r"
printf 'x\n' >> "$r/src/app.js"; printf 'x\n' >> "$r/engine/CONTEXT.md"
run_stop "in-write-set" "$r" pass

# A2. 代码路径不在 WRITE-SET + 回写 → block(写集越界)
r="$(new_repo)"; write_task "$r" T-001 active "src/**" ""; write_capsule "$r"
printf 'x\n' >> "$r/src/app.js"; printf 'x\n' >> "$r/lib/util.js"; printf 'x\n' >> "$r/engine/CONTEXT.md"
run_stop "out-of-write-set" "$r" block

# A3. 代码路径在 FORBIDDEN → block(禁区)
r="$(new_repo)"; write_task "$r" T-001 active "src/**" "src/payment/**"; write_capsule "$r"
printf 'x\n' >> "$r/src/payment/charge.js"; printf 'x\n' >> "$r/engine/CONTEXT.md"
run_stop "forbidden-path" "$r" block

# A4. FORBIDDEN 优先于 WRITE-SET(路径同时在两者中 → block)
r="$(new_repo)"; write_task "$r" T-001 active "src/**" "src/app.js"; write_capsule "$r"
printf 'x\n' >> "$r/src/app.js"; printf 'x\n' >> "$r/engine/CONTEXT.md"
run_stop "forbidden-overrides-write-set" "$r" block

# A5. 引擎文件不再享有 blanket exemption:不在 WRITE-SET → block
r="$(new_repo)"; write_task "$r" T-001 active "src/**" ""; write_capsule "$r"
printf 'system\n' > "$r/engine/SYSTEM.md"
run_stop "engine-out-of-write-set" "$r" block

# A6. 引擎文件显式进入 WRITE-SET → pass
r="$(new_repo)"; write_task "$r" T-001 active "src/**,engine/SYSTEM.md" ""; write_capsule "$r"
printf 'system\n' > "$r/engine/SYSTEM.md"
run_stop "engine-in-write-set" "$r" pass

# A7. section-list WRITE-SET/FORBIDDEN 与 inline 语义相同
r="$(new_repo)"; write_task_section "$r" T-001 active "src/**" "lib/**"; write_capsule "$r"
printf 'x\n' >> "$r/src/app.js"; printf 'x\n' >> "$r/engine/CONTEXT.md"
run_stop "section-write-set-pass" "$r" pass
printf 'x\n' >> "$r/lib/section.js"
run_stop "section-forbidden-block" "$r" block

# A8. active 卡无法解析 WRITE-SET 时 fail-closed
r="$(new_repo)"
cat > "$r/engine/tasks/T-001.md" <<'EOF'
# malformed
> status: active | lane: main | decision: | domain: root
EOF
git -C "$r" add engine/tasks/T-001.md && git -C "$r" commit -qm malformed
printf 'system\n' > "$r/engine/SYSTEM.md"
run_stop "malformed-write-set" "$r" block

echo ""
echo "=== B. 向后兼容(无 active 任务卡) ==="

# B1. 无任务卡 + 代码 + 回写 + capsule → pass
r="$(new_repo)"; write_capsule "$r"
printf 'x\n' >> "$r/src/app.js"; printf 'x\n' >> "$r/lib/other.js"; printf 'x\n' >> "$r/engine/CONTEXT.md"
run_stop "no-task-card-pass" "$r" pass

# B2. 无任务卡 + 代码 + 无回写 → block(硬门禁仍生效)
r="$(new_repo)"
printf 'x\n' >> "$r/src/app.js"; printf 'x\n' >> "$r/lib/other.js"
run_stop "no-task-card-no-writeback" "$r" block

# B3. paused 任务卡不激活写集校验
r="$(new_repo)"; write_task "$r" T-001 paused "src/**" ""; write_capsule "$r"
printf 'x\n' >> "$r/src/app.js"; printf 'x\n' >> "$r/lib/other.js"; printf 'x\n' >> "$r/engine/CONTEXT.md"
run_stop "paused-task-ignored" "$r" pass

echo ""
echo "=== C. v6.5 strict task adoption + done evidence ==="

# C1. v6.5 项目无 active 卡时,即使有旧式回写也不能改普通路径
r="$(new_repo)"; enable_strict_v65 "$r"; write_capsule "$r"
printf 'x\n' >> "$r/src/app.js"; printf 'x\n' >> "$r/engine/CONTEXT.md"
run_stop "strict-no-active-stop-block" "$r" block

# C2. 写入前门禁同样拦普通路径,但允许先创建任务/决策卡来建立边界
r="$(new_repo)"; enable_strict_v65 "$r"
pre_payload='{"session_id":"strict-main","tool_name":"Edit","tool_input":{"file_path":"src/app.js"}}'
run_pre "strict-no-active-pre-block" "$r" block "$pre_payload"
pre_payload='{"session_id":"strict-main","tool_name":"Write","tool_input":{"file_path":"engine/tasks/T-001.md"}}'
run_pre "strict-task-bootstrap-pass" "$r" pass "$pre_payload"

# C3. B-tier 提交门禁不能让无任务卡的 engine-only 改动漏过
r="$(new_repo)"; enable_strict_v65 "$r"
printf 'x\n' >> "$r/engine/HANDOFF.md"; git -C "$r" add engine/HANDOFF.md
run_pc "strict-no-active-precommit-block" "$r" 1

# C4. active -> done 必须逐 AC 有 PASS evidence;补齐后才放行
r="$(new_repo)"; enable_strict_v65 "$r"
write_task "$r" T-001 active "src/**,engine/tasks/T-001.md,engine/evidence/T-001/**" ""
printf 'x\n' >> "$r/src/app.js"; printf 'x\n' >> "$r/engine/CONTEXT.md"
sed -i 's/status: active/status: done/' "$r/engine/tasks/T-001.md"
git -C "$r" add src/app.js engine/CONTEXT.md engine/tasks/T-001.md
run_pc "strict-done-without-evidence-block" "$r" 1
mkdir -p "$r/engine/evidence/T-001"
# v6.18.0 (D-038/T-066): evidence now requires either write_provenance
# (machine-written) or evidence-manual-edit marker (manual edit). Test
# fixture uses manual-edit path since it's constructed by hand, not by
# engine-verify.
printf '{"ac":"AC-1","status":"pass","evidence-manual-edit":true}\n' > "$r/engine/evidence/T-001/AC-1.json"
cat > "$r/engine/evidence/T-001/GATE.json" <<GATE_EOF
{"task":"T-001","status":"pass","write_provenance":{"writer":"engine-gate","commit":"$(git -C "$r" rev-parse HEAD)"}}
GATE_EOF
git -C "$r" add engine/evidence/T-001/AC-1.json engine/evidence/T-001/GATE.json
run_pc "strict-done-all-pass-evidence" "$r" 0

echo ""
echo "=== D. pre-commit 受保护路径决策引用门禁 ==="

# C1. 受保护路径变更,有 approved 决策 + scope 覆盖 → rc=0
r="$(new_repo)"; write_rules "$r" "engine/decisions/**"
write_task "$r" T-001 active "engine/**" "" "D-001"
write_decision "$r" D-001 approved "engine/decisions/**,engine/tasks/**"
git -C "$r" add engine/decisions/rules.json engine/decisions/D-001.md engine/tasks/T-001.md engine/CONTEXT.md
run_pc "protected-with-approved-decision" "$r" 0

# C2. 受保护路径变更,无任务卡 → rc=1
r="$(new_repo)"; write_rules "$r" "engine/decisions/**"
git -C "$r" add engine/decisions/rules.json engine/CONTEXT.md
run_pc "protected-no-task-card" "$r" 1

# C3. 受保护路径变更,任务卡引用的决策未批准(proposed) → rc=1
r="$(new_repo)"; write_rules "$r" "engine/decisions/**"
write_task "$r" T-001 active "engine/**" "" "D-001"
write_decision "$r" D-001 proposed "engine/decisions/**"
git -C "$r" add engine/decisions/rules.json engine/CONTEXT.md
run_pc "protected-proposed-decision" "$r" 1

# C4. 受保护路径变更,approved 决策但 scope 不覆盖 → rc=1
r="$(new_repo)"; write_rules "$r" "engine/decisions/**"
write_task "$r" T-001 active "engine/**" "" "D-001"
write_decision "$r" D-001 approved "engine/tasks/**"
git -C "$r" add engine/decisions/rules.json engine/CONTEXT.md
run_pc "protected-scope-not-covering" "$r" 1

# C5. 非受保护路径变更 → rc=0(不触发决策门禁)
r="$(new_repo)"; write_rules "$r" "engine/decisions/**"
write_task "$r" T-001 active "src/**,engine/**" ""
git -C "$r" add src/app.js engine/CONTEXT.md
run_pc "unprotected-path-ok" "$r" 0

# C6. 受保护路径变更,无 active 但有 done 任务卡 → rc=1(T-044/D-032: legacy fallback 移除,done 卡不再 govern,protected 文件无 task_decision 覆盖 → block)
r="$(new_repo)"; write_rules "$r" "engine/decisions/**"
write_task "$r" T-001 done "engine/**" "" "D-001"
write_decision "$r" D-001 approved "engine/decisions/**"
git -C "$r" add engine/decisions/rules.json engine/CONTEXT.md
run_pc "protected-done-fallback" "$r" 1

# C7. 受保护路径变更,无 active,done 任务卡 decision scope 不覆盖 → rc=1(同 C6,done 卡不 govern)
r="$(new_repo)"; write_rules "$r" "engine/decisions/**"
write_task "$r" T-001 done "engine/**" "" "D-001"
write_decision "$r" D-001 approved "engine/tasks/**"
git -C "$r" add engine/decisions/rules.json engine/CONTEXT.md
run_pc "protected-done-fallback-scope-not-covering" "$r" 1

# C8. runtime-law.md 受保护,有 approved 决策 scope 覆盖 → rc=0
# 注:必须实际修改 engine/CONTEXT.md 使其进入暂存区,否则第1层回写门禁会拦截。
r="$(new_repo)"; write_rules "$r" "runtime-law.md"
write_task "$r" T-001 active "runtime-law.md" "" "D-001"
write_decision "$r" D-001 approved "runtime-law.md"
printf 'test\n' > "$r/runtime-law.md"
printf 'updated\n' > "$r/engine/CONTEXT.md"
git -C "$r" add runtime-law.md engine/CONTEXT.md
run_pc "runtime-law-protected-with-approved-decision" "$r" 0

# C9. runtime-law.md 受保护,无任务卡 → rc=1
r="$(new_repo)"; write_rules "$r" "runtime-law.md"
printf 'test\n' > "$r/runtime-law.md"
printf 'updated\n' > "$r/engine/CONTEXT.md"
git -C "$r" add runtime-law.md engine/CONTEXT.md
run_pc "runtime-law-protected-no-task-card" "$r" 1

# C10. pre-commit 对 engine 路径同样执行 WRITE-SET
r="$(new_repo)"; write_task "$r" T-001 active "src/**" ""
printf 'system\n' > "$r/engine/SYSTEM.md"
git -C "$r" add engine/SYSTEM.md
run_pc "precommit-engine-out-of-scope" "$r" 1

# C11. pre-commit 能解析 section-list WRITE-SET
r="$(new_repo)"; write_task_section "$r" T-001 active "engine/SYSTEM.md" ""
printf 'system\n' > "$r/engine/SYSTEM.md"
git -C "$r" add engine/SYSTEM.md
run_pc "precommit-section-write-set" "$r" 0

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "task-card gate result: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
