#!/usr/bin/env bash
# Engine System — 更新流测试(D-015)
#
# 测试三组:
#   A. check-update 版本归一化(6.0 ≡ 6.0.0 判等;真更新仍报 exit 7)
#   B. run_migrate 版本化调度(仅应用新于本地 VERSION 的步、按版本序、每步回写 VERSION、
#      无待应用步回退幂等契约修复)+ 迁移 rules.json 基线含 protected_paths
#   C. histexpand 防御静态回归(MARK 单引号 + set +H)
#
# 用法:bash tests/update-flow/run-update-tests.sh

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"

pass=0
fail=0
ok()  { echo "PASS  $1"; pass=$((pass+1)); }
bad() { echo "FAIL  $1"; fail=$((fail+1)); }

# 假 curl:拦截网络,固定输出"远程版本"。check-update 走 command -v curl,PATH 前置即可。
make_fake_curl() { # $1=bin目录 $2=远程版本串
  mkdir -p "$1"
  { echo '#!/usr/bin/env bash'; echo "printf '%s' '$2'"; } > "$1/curl"
  chmod +x "$1/curl"
}

echo "=== A. check-update 版本归一化 ==="

# U1: 本地 6.0,远程 6.0.0 → 归一化判等 → exit 0(不再伪报更新)
tmp="$(mktemp -d)"
mkdir -p "$tmp/proj/engine"
printf '6.0\n' > "$tmp/proj/engine/VERSION"
make_fake_curl "$tmp/bin" "6.0.0"
if PATH="$tmp/bin:$PATH" bash "$REPO_ROOT/plugin/engine/scripts/engine-check-update.sh" "$tmp/proj" >/dev/null 2>&1; then
  ok "U1 normalize-equal (6.0 vs 6.0.0 -> up to date)"
else
  bad "U1 normalize-equal (6.0 vs 6.0.0 应判等)"
fi
rm -rf "$tmp"

# U2: 本地 6.0.0,远程 6.0.1 → 真更新 → exit 7
tmp="$(mktemp -d)"
mkdir -p "$tmp/proj/engine"
printf '6.0.0\n' > "$tmp/proj/engine/VERSION"
make_fake_curl "$tmp/bin" "6.0.1"
PATH="$tmp/bin:$PATH" bash "$REPO_ROOT/plugin/engine/scripts/engine-check-update.sh" "$tmp/proj" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 7 ]; then
  ok "U2 real-update-detected (6.0.0 vs 6.0.1 -> exit 7)"
else
  bad "U2 real-update-detected (期望 exit 7,实得 $rc)"
fi
rm -rf "$tmp"

echo ""
echo "=== B. run_migrate 版本化调度 ==="

# U3: 本地 6.0.0 + 步 v6.0/v6.0.1/v6.1.0 → 跳过 v6.0,按序应用 v6.0.1、v6.1.0,VERSION 回写 6.1.0
tmp="$(mktemp -d)"
proj="$tmp/proj"
mkdir -p "$proj/engine/migrations" "$proj/engine/scripts"
printf '6.0.0\n' > "$proj/engine/VERSION"
for v in 6.0 6.0.1 6.1.0; do
  cat > "$proj/engine/migrations/v$v.sh" <<EOF
#!/usr/bin/env bash
echo "v$v" >> "\$1/order.log"
EOF
done
( cd "$proj" && bash "$REPO_ROOT/plugin/bin/engine" migrate >/dev/null 2>&1 )
order="$(tr '\n' ' ' < "$proj/order.log" 2>/dev/null | sed 's/ $//')"
if [ "$order" = "v6.0.1 v6.1.0" ]; then
  ok "U3a step-order (跳过 v6.0,按序应用 v6.0.1 v6.1.0)"
else
  bad "U3a step-order (期望 'v6.0.1 v6.1.0',实得 '$order')"
fi
ver="$(tr -d '[:space:]' < "$proj/engine/VERSION")"
if [ "$ver" = "6.1.0" ]; then
  ok "U3b version-writeback (engine/VERSION -> 6.1.0)"
else
  bad "U3b version-writeback (期望 6.1.0,实得 '$ver')"
fi
rm -rf "$tmp"

# U4: 无待应用步(本地已最新)→ 回退直接跑契约迁移器(幂等修复语义保留)
tmp="$(mktemp -d)"
proj="$tmp/proj"
mkdir -p "$proj/engine/migrations" "$proj/engine/scripts"
printf '6.1.0\n' > "$proj/engine/VERSION"
cat > "$proj/engine/scripts/engine-migrate-contract.sh" <<'EOF'
#!/usr/bin/env bash
touch "$1/repaired.marker"
EOF
cat > "$proj/engine/migrations/v6.0.sh" <<'EOF'
#!/usr/bin/env bash
echo "should-not-run" >> "$1/order.log"
EOF
( cd "$proj" && bash "$REPO_ROOT/plugin/bin/engine" migrate >/dev/null 2>&1 )
if [ -f "$proj/repaired.marker" ] && [ ! -f "$proj/order.log" ]; then
  ok "U4 fallback-repair (旧步不重跑,迁移器幂等修复仍执行)"
else
  bad "U4 fallback-repair (marker=$(test -f "$proj/repaired.marker" && echo yes || echo no) order-log=$(test -f "$proj/order.log" && echo leaked || echo clean))"
fi
rm -rf "$tmp"

# U5: 迁移创建的 rules.json 基线含 protected_paths(pre-commit 读取契约对齐)
tmp="$(mktemp -d)"
mkdir -p "$tmp/engine"
echo "# stub" > "$tmp/engine/ENGINE_MAP.md"
if bash "$REPO_ROOT/plugin/engine/scripts/engine-migrate-contract.sh" "$tmp" >/dev/null 2>&1 \
  && grep -q '"protected_paths"' "$tmp/engine/decisions/rules.json"; then
  ok "U5 rules-baseline-protected-paths"
else
  bad "U5 rules-baseline-protected-paths (迁移 rules.json 缺 protected_paths 键)"
fi
rm -rf "$tmp"

echo ""
echo "=== C. histexpand 防御(静态回归)==="

# U6: MARK 赋值单引号 + set +H(双引号内 !- 在交互式 bash 触发历史展开 → set -u unbound)
u6_ok=1
for f in \
  "$REPO_ROOT/engine/scripts/engine-migrate-contract.sh" \
  "$REPO_ROOT/plugin/engine/scripts/engine-migrate-contract.sh" \
  "$REPO_ROOT/engine/scripts/engine-sync-agent-anchors.sh" \
  "$REPO_ROOT/plugin/engine/scripts/engine-sync-agent-anchors.sh"; do
  if ! grep -q "^MARK_START='" "$f" || ! grep -q '^set +H' "$f"; then
    u6_ok=0
    echo "  missing guard: $f"
  fi
done
if [ "$u6_ok" -eq 1 ]; then
  ok "U6 histexpand-guard (单引号 MARK + set +H ×4 脚本)"
else
  bad "U6 histexpand-guard"
fi

echo ""
echo "=========================================="
echo "PASS=$pass  FAIL=$fail"
[ "$fail" -eq 0 ]
