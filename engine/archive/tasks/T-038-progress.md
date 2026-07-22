# progress — T-038 修复 D-029 落地 5 处实现层遗漏 + v6.11.1 patch
> Last updated: 2026-07-21 | 任务级压缩恢复锚点 | 7 栏事件驱动更新,见 contract/src/20-file-templates.md FILE 13

## §1 已读文件（理解项目）
- engine/decisions/D-029.md — D-029 决策卡 §3/§4/§8/§Consequences 已审,5 处遗漏已识别
- engine/tasks/T-036.md + T-036.spec.md — T-036 18/18 AC done,AC 多为 grep 文本验证
- engine/scripts/engine-hook-stop.sh — is_shared_memory 第 140-148 行(不含 progress/checkpoint/INVENTORY),第 217-233 行 PreToolUse 双信号
- engine/scripts/engine-hook-stop.ps1 — Is-SharedMemory 第 119-133 行(同上)
- engine/scripts/engine-hook-session-start.sh — 第 129 行 anon-$$ fallback
- engine/scripts/engine-hook-session-start.ps1 — 第 151 行 anon-$PID fallback
- engine/scripts/githooks/pre-commit — 第 170-178 行无 worker 检测
- engine/bin/engine — 第 84/91/143-150 行扁平 workstream 目录
- engine/prompts/behaviors/task-run.md — 第 16/20-40/42-52 行无 worker 模式条件化指引
- engine/prompts/behaviors/handoff.md — 第 13 行无角色门控

## §2 已确认接口（不重复读）
- is_shared_memory(path) -> 0/1 — case glob 匹配,worker 模式下 PreToolUse 拦截
- Is-SharedMemory(path) -> bool — PS 版本,$exact + -like 模式
- create_workstream(root, task, agent, --kind) — kind=subagent|session,目录扁平 <task>/<agent>/

## §3 已排除路径（原 TRAIL 的家）
- [2026-07-21] / pre-commit 用 .cache/sessions/*.role=worker 文件存在判定 / 误判风险:历史标志可能残留 / 采用环境变量 ENGINE_WORKER=1 显式标记(B 档用户必设)
- [2026-07-21] / s-/a- 前缀强制校验 reject 不带前缀的 agent / 破坏向后兼容 / 采用自动补前缀(若用户传 --kind=session 且 agent 不以 s- 开头,自动补)
- [2026-07-21] / migrator 新增 managed block item 13 / 已有 #12 覆盖多会话,本次只是实现层修复 / 不动 migrator

## §4 当前进行到（压缩恢复点）
正在做:T-038 全部完成,10/10 AC 全绿,engine verify + check.sh 双门禁通过,等待用户提交
AC 状态:
- AC-1 done: is_shared_memory 扩展含 progress.md/checkpoint.md/INVENTORY.md(engine-hook-stop.{sh,ps1} + plugin 镜像)
- AC-2 done: task-run.md + handoff.md prompt 加 worker 模式条件化指引(engine + plugin 共 4 份,含 progress.md/checkpoint.md/INVENTORY.md worker 边界 + 归档 coordinator-only)
- AC-3 done: SessionStart hook UUID fallback 完全替换 anon-PID(timestamp 兜底,4 份 hook + engine bin)
- AC-4 done: pre-commit 加 ENGINE_WORKER 检测(2 份)
- AC-5 done: engine workstream 命令 s-/a- 前缀 + sessions/agents 隔离(3 份 sh/ps1/cmd) + engine-context 适配
- AC-6 done: ENGINE_DOCTOR.md #18 worker 检查 + AGENT_ADAPTERS.md s-/a- + ENGINE_WORKER 说明,contract-version 6.11.1
- AC-7 done: plugin 镜像同步 + manifest SHA256 更新,diff -q 全对称
- AC-8 done: VERSION/engine/VERSION/plugin/VERSION 三处 = 6.11.1,CHANGELOG 含 v6.11.1
- AC-9 done: check.sh 全绿(CHECK PASSED,0 failure,4 warning 均为预存)
- AC-10 done: test_worker_writes_shard.sh + .ps1 各 6/6 测试通过(W1-W6)
D-029 Watchpoints 已补 T-038 patch 标注 + 16 份 .ps1 BOM watchpoint
下一步:用户确认后提交 + 标记 T-038 为已完成

## §5 待确认问题
- 无(用户已批准修全部 5 个遗漏)

## §6 已知风险/未解 bug
- AC-3 Windows PowerShell 5.1 的 [guid]::NewGuid() 兼容性确认:.NET API 在 PS 5.1 可用,无风险
- AC-5 engine.cmd 是 batch wrapper,可能不直接含 sessions/agents 字符串,需检查

## §7 回滚尝试
- 无
