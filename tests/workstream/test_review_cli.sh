#!/usr/bin/env bash
# Test: engine review CLI 入口(T-069, v6.20.0)
set -euo pipefail

echo "[test_review_cli.sh] T-069 AC-1 CLI 入口"

PASS=0; FAIL=0
ok()  { echo "  PASS $1"; PASS=$((PASS+1)); }
bad() { echo "  FAIL $1"; FAIL=$((FAIL+1)); }

# 用 $PWD(测试在项目根目录跑)
ENGINE_BIN="$PWD/engine/bin/engine"

# S1: engine review 无参数 exit 2
rc=0
bash "$ENGINE_BIN" review >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 2 ]; then
  ok "S1 no-arg exit 2"
else
  bad "S1 no-arg should exit 2, got $rc"
fi

# S2: usage() 含 engine review T-NNN 行
if bash "$ENGINE_BIN" help 2>&1 | grep -q "engine review T-NNN"; then
  ok "S2 usage has engine review T-NNN"
else
  bad "S2 usage missing engine review T-NNN"
fi

# S3: config.json 存在且含 defaults + overrides 段
if [ -f "$PWD/engine/review/config.json" ] \
  && grep -q '"defaults"' "$PWD/engine/review/config.json" \
  && grep -q '"overrides"' "$PWD/engine/review/config.json"; then
  ok "S3 config.json has defaults + overrides"
else
  bad "S3 config.json missing defaults or overrides"
fi

# S4: federation.json 含 engine/review/**
if grep -q 'engine/review' "$PWD/engine/domains/federation.json"; then
  ok "S4 federation has engine/review"
else
  bad "S4 federation missing engine/review"
fi

# S5: ENGINE_MAP §1 含 config.json Class=mixed
if grep -q 'engine/review/config.json' "$PWD/engine/ENGINE_MAP.md" \
  && grep -q '| mixed |' "$PWD/engine/ENGINE_MAP.md"; then
  ok "S5 ENGINE_MAP has config.json mixed"
else
  bad "S5 ENGINE_MAP missing config.json mixed"
fi

echo "Results: $PASS pass, $FAIL fail"
[ "$FAIL" -eq 0 ] || exit 1
