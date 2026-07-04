#!/usr/bin/env bash
# Engine System — 一键发版脚本
#
# 用法:  bash scripts/release.sh <new-version> [commit-message]
# 示例:  bash scripts/release.sh 6.1.0
#        bash scripts/release.sh 6.0.1 "Doctor 占位符误报修复"
#
# 执行顺序:
#   1. 预检(git 状态 + 版本号合法性)
#   2. Bump VERSION(根 / plugin / engine 三处同步)
#   3. 编译契约(4 dist)
#   4. 全量检查(check.sh)
#   5. 生成 CHANGELOG.md(从 engine/changes/ 聚合)
#   6. Commit + Tag
#
# 不会自动 push——跑完后看结果手动 push。

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

step()  { printf '\n%s== %s ==%s\n' "$CYAN" "$1" "$RESET"; }
pass()  { printf '%s✓%s %s\n' "$GREEN" "$RESET" "$1"; }
fail()  { printf '%s✗%s %s\n' "$RED" "$RESET" "$1" >&2; }

# ── 参数 ─────────────────────────────────────────────────────────────────────
if [[ $# -lt 1 ]]; then
  echo "用法: bash scripts/release.sh <new-version> [commit-message]" >&2
  exit 1
fi

NEW_VERSION="$1"
COMMIT_MSG="${2:-release v${NEW_VERSION}}"

# ── 预检 ─────────────────────────────────────────────────────────────────────
step "预检"

# 版本格式: x.y.z
if ! echo "$NEW_VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  fail "版本号格式错误: $NEW_VERSION (需要 x.y.z)"
  exit 1
fi

# 不允许有 staged 改动——release commit 只含版本 bump + 编译产物 + CHANGELOG
if git diff --cached --quiet 2>/dev/null; then
  pass "staging area 干净"
else
  fail "staging area 有未提交改动,请先 commit 或 reset 再发版"
  git diff --cached --name-only | sed 's/^/  /'
  exit 1
fi

# 已有 tag 不能重复
if git tag -l "v${NEW_VERSION}" | grep -q .; then
  fail "tag v${NEW_VERSION} 已存在"
  exit 1
fi

# 当前版本
CUR_VERSION="$(tr -d '[:space:]' < VERSION 2>/dev/null || echo unknown)"
pass "当前版本: $CUR_VERSION → 目标: $NEW_VERSION"

# ── Bump VERSION ─────────────────────────────────────────────────────────────
step "Bump VERSION"
printf '%s\n' "$NEW_VERSION" > VERSION
printf '%s\n' "$NEW_VERSION" > plugin/VERSION
printf '%s\n' "$NEW_VERSION" > engine/VERSION
pass "VERSION × 3 → $NEW_VERSION"

# ── 编译契约 ─────────────────────────────────────────────────────────────────
step "编译契约"
bash contract/compile.sh

# ── 全量检查 ─────────────────────────────────────────────────────────────────
step "全量检查"
if bash scripts/check.sh; then
  pass "check.sh 全绿"
else
  fail "check.sh 失败,发版中止"
  fail "VERSION 已 bump 到 $NEW_VERSION,如需回退: git checkout -- VERSION plugin/VERSION engine/VERSION"
  exit 1
fi

# ── 生成 CHANGELOG ───────────────────────────────────────────────────────────
step "生成 CHANGELOG"

LAST_TAG="$(git describe --tags --abbrev=0 2>/dev/null || true)"

# 收集 capsule:上次 tag 之后 → 现在(首次发版则收全部)
if [[ -n "$LAST_TAG" ]]; then
  CAPSULES="$(git diff --name-only "$LAST_TAG" HEAD -- engine/changes/CHANGE-*.md 2>/dev/null | sort)"
  pass "增量收集:自 $LAST_TAG 起的新 capsule"
else
  CAPSULES="$(ls engine/changes/CHANGE-*.md 2>/dev/null | sort)"
  pass "首次发版:收集全部 capsule"
fi

TODAY="$(date +%Y-%m-%d)"
TMPLOG="$(mktemp)"
{
  printf '## v%s (%s)\n\n' "$NEW_VERSION" "$TODAY"
  if [[ -n "$CAPSULES" ]]; then
    while IFS= read -r capsule; do
      [[ -f "$capsule" ]] || continue
      # 标题:第一行 "# CHANGE-... — <title>" 取 em dash 之后的部分
      title="$(head -1 "$capsule" | sed 's/^# CHANGE-[0-9-]* — *//' 2>/dev/null || true)"
      [[ -z "$title" || "$title" == "# CHANGE-"* ]] && title="$(basename "$capsule" .md)"
      date_part="$(basename "$capsule" .md | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' || true)"
      printf -- '- %s (%s)\n' "$title" "${date_part:-unknown}"
    done <<< "$CAPSULES"
  else
    printf -- '- (no capsules in this release)\n'
  fi
  printf '\n'
} > "$TMPLOG"

CHANGELOG="$ROOT/CHANGELOG.md"
if [[ -f "$CHANGELOG" ]]; then
  # 已有 CHANGELOG:在头部(header 之后)插入新版本段
  {
    head -2 "$CHANGELOG"        # "# Changelog" + 空行
    cat "$TMPLOG"               # 新版本段
    tail -n +3 "$CHANGELOG"    # 历史版本
  } > "${CHANGELOG}.tmp"
  mv "${CHANGELOG}.tmp" "$CHANGELOG"
  pass "CHANGELOG.md 已更新(追加 v${NEW_VERSION})"
else
  {
    printf '# Changelog\n\n'
    cat "$TMPLOG"
  } > "$CHANGELOG"
  pass "CHANGELOG.md 已创建"
fi
rm -f "$TMPLOG"

# ── Commit + Tag ─────────────────────────────────────────────────────────────
step "Commit + Tag"
git add VERSION plugin/VERSION engine/VERSION \
        ENGINE_FILE_SYSTEM_v5.md runtime-law.md rules.json \
        plugin/.claude/commands/engine-init.md \
        CHANGELOG.md

git commit -m "$COMMIT_MSG"
git tag "v${NEW_VERSION}"

pass "committed + tagged v${NEW_VERSION}"

printf '\n%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n' "$GREEN" "$RESET"
printf '%sRelease v%s 完成。%s\n' "$GREEN" "$NEW_VERSION" "$RESET"
echo ""
echo "下一步:"
echo "  git push && git push --tags"
echo ""
echo "创建 GitHub Release(含 release notes):"
echo "  gh release create v${NEW_VERSION} --title 'v${NEW_VERSION}' --notes-file CHANGELOG.md"
echo ""
