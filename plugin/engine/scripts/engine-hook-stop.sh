#!/usr/bin/env bash
# Engine System — Stop hook · "收尾守门员 / session-close gatekeeper"（硬门禁）
#
# 当 agent 想结束本轮,但本会话改了代码却没回写引擎记忆(CONTEXT.md / HANDOFF.md)时,
# 拦截这次停止,要求 agent 先增量回写,然后才放行。这把"会话结束应更新"的软契约
# 变成不做就过不去的硬执行,消灭架构师手动敲 /engine-update 的 loop。
#
# 安全契约:只读引擎文件;仅读取 git status 判断改动。幂等:同一轮最多拦一次(靠
# stop_hook_active 防死循环)。任何异常都放行(宁可漏拦也不卡死会话)。
# 触发:Stop(主 agent 每轮响应完成时)。

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
ENGINE_DIR="$ROOT/engine"

# 读取 hook payload(JSON)。我们只需要 stop_hook_active。
payload="$(cat 2>/dev/null || true)"

# 防死循环:若本次 Stop 是上一次 block 触发的继续,直接放行,绝不二次拦截。
case "$payload" in
  *'"stop_hook_active":true'*|*'"stop_hook_active": true'*) exit 0 ;;
esac

# 没有引擎层 → 无可守门。
[ -d "$ENGINE_DIR" ] || exit 0

# 必须是 git 仓库才能比对改动。
command -v git >/dev/null 2>&1 || exit 0
git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

status="$(git -C "$ROOT" status --porcelain 2>/dev/null || true)"
[ -n "$status" ] || exit 0   # 工作区干净(纯问答会话)→ 放行,不打扰。

# 逐行判断:本会话是否动了"代码"(非引擎文件),引擎记忆是否被回写。
code_changed=0
engine_written=0
while IFS= read -r line; do
  [ -n "$line" ] || continue
  path="${line:3}"                         # porcelain: 前 2 字符状态 + 空格 + 路径
  path="${path%% -> *}"                     # 处理 rename：取箭头后的目标前先去尾,稳妥起见
  case "$path" in
    engine/CONTEXT.md|engine/HANDOFF.md|engine/ENGINE_MAP.md) engine_written=1 ;;
    engine/.cache/*|.engine/*) : ;;          # 缓存不计
    engine/*) : ;;                           # 其它引擎文档不算"代码"
    *) code_changed=1 ;;
  esac
done <<EOF
$status
EOF

# 硬门禁:改了代码但没回写引擎记忆 → 拦截一次。
if [ "$code_changed" -eq 1 ] && [ "$engine_written" -eq 0 ]; then
  reason="【Engine System · 收尾守门员】本次会话改动了代码,但项目记忆(engine/CONTEXT.md / HANDOFF.md)还没同步。结束前请先增量回写:1) 更新 CONTEXT 状态面板的『上次完成』『进行中』;2) 在 HANDOFF 顶部追加一行交接(日期 | 做了什么 | 下一步 | 改动文件)。完成后即可结束。"
  printf '{"decision":"block","reason":"%s"}\n' "$reason"
  exit 0
fi

exit 0
