#!/usr/bin/env bash
# Engine System — 行为化验收测试(v6 S4)
#
# 测试 engine-verify 脚本:AC verify 命令的 pass/fail/skip + evidence JSON。
#
# 用法:bash tests/behavior-verify/run-verify-tests.sh

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
VERIFY_SH="$REPO_ROOT/engine/scripts/engine-verify.sh"
VERIFY_PS1="$REPO_ROOT/engine/scripts/engine-verify.ps1"
CLI_SH="$REPO_ROOT/engine/bin/engine"
CLI_PS1="$REPO_ROOT/engine/bin/engine.ps1"

PS_BIN=""
for c in powershell.exe powershell pwsh; do
  if command -v "$c" >/dev/null 2>&1; then PS_BIN="$c"; break; fi
done

pass=0
fail=0
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

new_repo() {
  d="$(mktemp -d "$TMP_ROOT/repo.XXXXXX")"
  mkdir -p "$d/engine/tasks"
  printf 'ctx\n' > "$d/engine/CONTEXT.md"
  printf '%s\n' "$d"
}

write_task_mixed() {
  repo="$1"
  cat > "$repo/engine/tasks/T-TEST.md" <<'EOF'
# TASK CARD — T-TEST
> status: active | lane: test | decision: | plan: none | domain: root
GOAL: test
WRITE-SET: src/**
FORBIDDEN: none
AC: AC-1 pass case → verify: true
AC: AC-2 fail case → verify: false
AC: AC-3 no verify here
CONSTRAINTS: none
EOF
}

write_task_fail_then_pass() {
  repo="$1"
  cat > "$repo/engine/tasks/T-TEST.md" <<'EOF'
# TASK CARD — T-TEST
> status: active | lane: test | decision: | plan: none | domain: root
GOAL: test
WRITE-SET: src/**
FORBIDDEN: none
AC: AC-1 fail case → verify: false
AC: AC-2 pass case → verify: true
CONSTRAINTS: none
EOF
}

check_json_field() {
  name="$1"; repo="$2"; ac="$3"; field="$4"; expect="$5"
  f="$repo/engine/evidence/T-TEST/$ac.json"
  if [ ! -f "$f" ]; then
    echo "FAIL  $name ($ac.json 不存在)"; fail=$((fail+1)); return
  fi
  val="$(grep -o "\"$field\":\"[^\"]*\"" "$f" | sed 's/.*:.*"\([^"]*\)"/\1/')"
  if [ "$val" = "$expect" ]; then
    echo "PASS  $name ($ac.$field=$val)"; pass=$((pass+1))
  else
    echo "FAIL  $name ($ac.$field expect=$expect got=$val)"; fail=$((fail+1))
  fi
}

check_no_file() {
  name="$1"; repo="$2"; ac="$3"
  if [ ! -f "$repo/engine/evidence/T-TEST/$ac.json" ]; then
    echo "PASS  $name ($ac.json 不存在=skip)"; pass=$((pass+1))
  else
    echo "FAIL  $name ($ac.json 应不存在)"; fail=$((fail+1))
  fi
}

# Convert repo path for PowerShell if running under Git Bash (cygpath available).
repo_ps1() {
  repo="$1"
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$repo"
  else
    printf '%s' "$repo"
  fi
}

echo "=== A. verify pass/fail/skip ==="

r="$(new_repo)"; write_task_mixed "$r"
out="$(CLAUDE_PROJECT_DIR="$r" bash "$VERIFY_SH" T-TEST 2>&1)"; rc=$?
if [ "$rc" = "1" ]; then
  echo "PASS  A1 verify-mixed-exit1 (fail_count>0)"; pass=$((pass+1))
else
  echo "FAIL  A1 verify-mixed-exit1 (expect rc=1 got rc=$rc)"; fail=$((fail+1))
fi
check_json_field "A2 ac1-pass" "$r" "AC-1" "status" "pass"
check_json_field "A3 ac2-fail" "$r" "AC-2" "status" "fail"
check_no_file "A4 ac3-skip" "$r" "AC-3"

if [ -n "$PS_BIN" ]; then
  r_ps1="$(new_repo)"; write_task_mixed "$r_ps1"
  out_ps1="$(CLAUDE_PROJECT_DIR="$(repo_ps1 "$r_ps1")" "$PS_BIN" -NoProfile -ExecutionPolicy Bypass -File "$VERIFY_PS1" -Task T-TEST 2>&1)"; rc_ps1=$?
  if [ "$rc_ps1" = "1" ]; then
    echo "PASS  A1-ps1 verify-mixed-exit1"; pass=$((pass+1))
  else
    echo "FAIL  A1-ps1 verify-mixed-exit1 (expect rc=1 got rc=$rc_ps1)"; fail=$((fail+1))
  fi
  check_json_field "A2-ps1 ac1-pass" "$r_ps1" "AC-1" "status" "pass"
  check_json_field "A3-ps1 ac2-fail" "$r_ps1" "AC-2" "status" "fail"
  check_no_file "A4-ps1 ac3-skip" "$r_ps1" "AC-3"
else
  echo "SKIP  ps1  A1-A4 (no PowerShell on this host)"
fi

echo ""
echo "=== B. evidence JSON 格式 ==="

f="$r/engine/evidence/T-TEST/AC-1.json"
if grep -q '"fingerprint":"sha256:[0-9a-f]\{64\}"' "$f"; then
  echo "PASS  B1 fingerprint-format (sha256:64hex)"; pass=$((pass+1))
else
  echo "FAIL  B1 fingerprint-format"; fail=$((fail+1))
fi
if grep -q '"exit":0' "$f"; then
  echo "PASS  B2 exit-field"; pass=$((pass+1))
else
  echo "FAIL  B2 exit-field"; fail=$((fail+1))
fi
if grep -q '"ac":"AC-1"' "$f" && grep -q '"verify":"true"' "$f"; then
  echo "PASS  B3 ac+verify-fields"; pass=$((pass+1))
else
  echo "FAIL  B3 ac+verify-fields"; fail=$((fail+1))
fi

if [ -n "$PS_BIN" ]; then
  f_ps1="$r_ps1/engine/evidence/T-TEST/AC-1.json"
  if grep -q '"fingerprint":"sha256:[0-9a-f]\{64\}"' "$f_ps1"; then
    echo "PASS  B1-ps1 fingerprint-format"; pass=$((pass+1))
  else
    echo "FAIL  B1-ps1 fingerprint-format"; fail=$((fail+1))
  fi
  if grep -q '"exit":0' "$f_ps1"; then
    echo "PASS  B2-ps1 exit-field"; pass=$((pass+1))
  else
    echo "FAIL  B2-ps1 exit-field"; fail=$((fail+1))
  fi
  if grep -q '"ac":"AC-1"' "$f_ps1" && grep -q '"verify":"true"' "$f_ps1"; then
    echo "PASS  B3-ps1 ac+verify-fields"; pass=$((pass+1))
  else
    echo "FAIL  B3-ps1 ac+verify-fields"; fail=$((fail+1))
  fi
else
  echo "SKIP  ps1  B1-B3 (no PowerShell on this host)"
fi

echo ""
echo "=== C. 任务卡不存在 ==="

r2="$(new_repo)"
out="$(CLAUDE_PROJECT_DIR="$r2" bash "$VERIFY_SH" T-NOPE 2>&1)"; rc=$?
if [ "$rc" = "2" ]; then
  echo "PASS  C1 missing-task-exit2"; pass=$((pass+1))
else
  echo "FAIL  C1 missing-task-exit2 (rc=$rc)"; fail=$((fail+1))
fi

if [ -n "$PS_BIN" ]; then
  r2_ps1="$(new_repo)"
  out_ps1="$(CLAUDE_PROJECT_DIR="$(repo_ps1 "$r2_ps1")" "$PS_BIN" -NoProfile -ExecutionPolicy Bypass -File "$VERIFY_PS1" -Task T-NOPE 2>&1)"; rc_ps1=$?
  if [ "$rc_ps1" = "2" ]; then
    echo "PASS  C1-ps1 missing-task-exit2"; pass=$((pass+1))
  else
    echo "FAIL  C1-ps1 missing-task-exit2 (rc=$rc_ps1)"; fail=$((fail+1))
  fi
else
  echo "SKIP  ps1  C1 (no PowerShell on this host)"
fi

echo ""
echo "=== D. 全 pass 任务 → exit 0 ==="

r3="$(new_repo)"
cat > "$r3/engine/tasks/T-OK.md" <<'EOF'
# TASK CARD — T-OK
> status: active | lane: test | decision: | plan: none | domain: root
GOAL: ok
WRITE-SET: src/**
FORBIDDEN: none
AC: AC-1 ok → verify: true
CONSTRAINTS: none
EOF
out="$(CLAUDE_PROJECT_DIR="$r3" bash "$VERIFY_SH" T-OK 2>&1)"; rc=$?
if [ "$rc" = "0" ]; then
  echo "PASS  D1 all-pass-exit0"; pass=$((pass+1))
else
  echo "FAIL  D1 all-pass-exit0 (rc=$rc)"; fail=$((fail+1))
fi

if [ -n "$PS_BIN" ]; then
  r3_ps1="$(new_repo)"
  cat > "$r3_ps1/engine/tasks/T-OK.md" <<'EOF'
# TASK CARD — T-OK
> status: active | lane: test | decision: | plan: none | domain: root
GOAL: ok
WRITE-SET: src/**
FORBIDDEN: none
AC: AC-1 ok → verify: true
CONSTRAINTS: none
EOF
  out_ps1="$(CLAUDE_PROJECT_DIR="$(repo_ps1 "$r3_ps1")" "$PS_BIN" -NoProfile -ExecutionPolicy Bypass -File "$VERIFY_PS1" -Task T-OK 2>&1)"; rc_ps1=$?
  if [ "$rc_ps1" = "0" ]; then
    echo "PASS  D1-ps1 all-pass-exit0"; pass=$((pass+1))
  else
    echo "FAIL  D1-ps1 all-pass-exit0 (rc=$rc_ps1)"; fail=$((fail+1))
  fi
else
  echo "SKIP  ps1  D1 (no PowerShell on this host)"
fi

echo ""
echo "=== E. engine CLI verify 子命令 ==="

out="$(CLAUDE_PROJECT_DIR="$r3" bash "$CLI_SH" verify T-OK 2>&1)"; rc=$?
if [ "$rc" = "0" ]; then
  echo "PASS  E1 cli-verify-pass"; pass=$((pass+1))
else
  echo "FAIL  E1 cli-verify-pass (rc=$rc out=${out:0:60})"; fail=$((fail+1))
fi

if [ -n "$PS_BIN" ]; then
  out_ps1="$(CLAUDE_PROJECT_DIR="$(repo_ps1 "$r3_ps1")" "$PS_BIN" -NoProfile -ExecutionPolicy Bypass -File "$CLI_PS1" verify T-OK 2>&1)"; rc_ps1=$?
  if [ "$rc_ps1" = "0" ]; then
    echo "PASS  E1-ps1 cli-verify-pass"; pass=$((pass+1))
  else
    echo "FAIL  E1-ps1 cli-verify-pass (rc=$rc_ps1 out=${out_ps1:0:60})"; fail=$((fail+1))
  fi
else
  echo "SKIP  ps1  E1 (no PowerShell on this host)"
fi

echo ""
echo "=== F. fail-then-pass rc bug (sh) ==="

r4="$(new_repo)"; write_task_fail_then_pass "$r4"
out="$(CLAUDE_PROJECT_DIR="$r4" bash "$VERIFY_SH" T-TEST 2>&1)"; rc=$?
if [ "$rc" = "1" ]; then
  echo "PASS  F1 fail-then-pass-exit1"; pass=$((pass+1))
else
  echo "FAIL  F1 fail-then-pass-exit1 (expect rc=1 got rc=$rc)"; fail=$((fail+1))
fi
check_json_field "F2 ac2-pass-after-fail" "$r4" "AC-2" "status" "pass"

if [ -n "$PS_BIN" ]; then
  r4_ps1="$(new_repo)"; write_task_fail_then_pass "$r4_ps1"
  out_ps1="$(CLAUDE_PROJECT_DIR="$(repo_ps1 "$r4_ps1")" "$PS_BIN" -NoProfile -ExecutionPolicy Bypass -File "$VERIFY_PS1" -Task T-TEST 2>&1)"; rc_ps1=$?
  if [ "$rc_ps1" = "1" ]; then
    echo "PASS  F1-ps1 fail-then-pass-exit1"; pass=$((pass+1))
  else
    echo "FAIL  F1-ps1 fail-then-pass-exit1 (expect rc=1 got rc=$rc_ps1)"; fail=$((fail+1))
  fi
  check_json_field "F2-ps1 ac2-pass-after-fail" "$r4_ps1" "AC-2" "status" "pass"
else
  echo "SKIP  ps1  F1-F2 (no PowerShell on this host)"
fi

echo ""
echo "=========================================="
echo "PASS=$pass  FAIL=$fail"
[ "$fail" -eq 0 ]
