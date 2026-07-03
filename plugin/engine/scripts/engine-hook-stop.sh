#!/usr/bin/env bash
# Engine System — Stop hook · "收尾守门员 / session-close gatekeeper"（硬门禁）
#
# 当 agent 想结束本轮,但本会话改了代码却没回写引擎记忆(CONTEXT.md / HANDOFF.md)时,
# 拦截这次停止,要求 agent 先增量回写,然后才放行。这把"会话结束应更新"的软契约
# 变成不做就过不去的硬执行,消灭架构师手动敲 /engine-update 的 loop。
#
# 回写定义与契约对齐(v6 S0):
#   硬门禁 = engine/CONTEXT.md / HANDOFF.md / ENGINE_MAP.md 至少其一被触碰;
#   change capsule(engine/changes/CHANGE-*.md)计入观察,缺失只 WARN 不拦截。
#
# 解析契约:git status --porcelain -z(NUL 分隔),不做逐行解析:
#   非 ASCII 路径在默认 core.quotepath=true 下会被引号+八进制转义包裹,击穿列位解析;
#   -z 输出从不引号转义,rename/copy 记录为 "XY 新路径\0旧路径\0" → 取新路径,跳过旧路径。
#   语义必须与 PowerShell 孪生实现一致,由 tests/hook-parity/run-parity.sh 强制。
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

# 逐记录判断:本会话是否动了"代码"(非引擎文件),引擎记忆是否回写,capsule 是否更新。
code_changed=0
engine_written=0
capsule_written=0
skip_next=0
while IFS= read -r -d '' rec || [ -n "$rec" ]; do
  if [ "$skip_next" -eq 1 ]; then skip_next=0; continue; fi   # rename/copy 的旧路径字段,丢弃
  [ "${#rec}" -ge 4 ] || continue
  st="${rec:0:2}"                              # porcelain: 2 字符状态位 + 空格 + 路径
  path="${rec:3}"
  case "$st" in *R*|*C*) skip_next=1 ;; esac   # -z 下 rename/copy 的下一个 NUL 字段是旧路径
  case "$path" in
    engine/CONTEXT.md|engine/HANDOFF.md|engine/ENGINE_MAP.md) engine_written=1 ;;
    engine/changes/CHANGE-*.md) capsule_written=1 ;;   # capsule 计入观察(WARN 级)
    engine/.cache/*|.engine/*) : ;;              # 缓存不计
    engine/*) : ;;                               # 其它引擎文档不算"代码"
    *) code_changed=1 ;;
  esac
done < <(git -C "$ROOT" status --porcelain -z -uall 2>/dev/null)
# -uall:未跟踪文件逐个列出。默认 -unormal 会把整个未跟踪目录折叠成 "?? dir/",
# 首个 capsule(engine/changes/ 目录首次出现)会被折叠遮蔽,门禁看不见——parity 测试抓出的真实病灶。

# 硬门禁:改了代码但没回写引擎记忆 → 拦截一次。
if [ "$code_changed" -eq 1 ] && [ "$engine_written" -eq 0 ]; then
  reason="【Engine System · 收尾守门员】本次会话改动了代码,但项目记忆(engine/CONTEXT.md / HANDOFF.md)还没同步。结束前请先增量回写:1) 更新 CONTEXT 状态面板的『上次完成』『进行中』;2) 在 HANDOFF 顶部追加一行交接(日期 | 做了什么 | 下一步 | 改动文件);3) 若这是一次有意义的改动,建议补一份 change capsule(engine/changes/CHANGE-YYYY-MM-DD-nn.md)。完成后即可结束。"
  printf '{"decision":"block","reason":"%s"}\n' "$reason"
  exit 0
fi

# 软门禁(WARN,不拦截):记忆已回写,但代码改动没有 change capsule → 提示架构师。
if [ "$code_changed" -eq 1 ] && [ "$engine_written" -eq 1 ] && [ "$capsule_written" -eq 0 ]; then
  printf '{"systemMessage":"【Engine System】代码改动已回写 CONTEXT/HANDOFF,但未见 change capsule(engine/changes/CHANGE-*.md)。若这是一次有意义的改动,建议让 agent 补一份架构师可读的变更胶囊。(WARN,不拦截)"}\n'
  exit 0
fi

exit 0
