# AGENT ADAPTERS — 跨 Agent 自维护适配

> Engine System (engine_system) · Last updated: 2026-07-17
> 说明：本文件记录当前仓库 dogfood 的跨 agent 自维护策略。完整模板见 `plugin/engine/AGENT_ADAPTERS.md`。

## 三层策略

| 层 | 机制 | 当前状态 |
|----|------|----------|
| A · 锚点契约 | 所有 agent 遵守全路径写集；worker 写独立 workstream 分片 | plugin/AGENTS + managed block |
| B · git pre-commit | 全部 staged 路径查 WRITE-SET/FORBIDDEN；代码须带共享记忆或 worker 分片 | installer 分发 |
| C · 原生 hook | Start 全量接手；Prompt 短锚；PreTool 写前拦截；Stop 按 session 归属收尾 | Claude settings 已挂四类事件 |

## 当前决策

- 单 agent/协调者每完成一个单元更新共享 CONTEXT/HANDOFF；并行 worker 运行 `engine workstream T-NNN <agent-id>`，只更新自己的分片。
- 一项可独立验收的目标共用一张任务卡；多轮消息与并行 worker 都不增卡，只读调查免卡。
- Claude 子 agent 抢写共享记忆由 PreToolUse 拦截；Stop 使用 `session_id + agent_id` 清单，不借用兄弟 agent 的回写。
- 其他 CLI/Web agent 通过 workstream 目录隔离记忆，提交时由 B 层复查；代码需要物理隔离时使用宿主 git worktree。
- 跨 agent 引导文件由 `engine-sync-agent-anchors.{sh,ps1}` 生成薄托管块，用户手写规则必须先吸收进引擎权威文件，再清理锚点。

## 下一步

- 合并点由协调者重读全部 pending 分片、一次更新共享记忆并跑 Doctor。
- 后续用 `/engine-reconcile` 补齐 dogfood 实例的完整 v5.5 注册表。

---

## C 档扩展:多会话锁使用约束(v6.11.0+, D-029/T-036)

> 多会话锁机制让多个 Claude Code 实例并行运行时不再抢写共享引擎记忆。以下规则适用于所有支持 C 档 hook 的 agent。

### 多会话锁基础

- **协调者/worker 角色**: 第一个 SessionStart 获得协调者(写共享 CONTEXT/HANDOFF/ENGINE_MAP),后续会话自动降级为 worker(只写 `engine/workstreams/<task>/<session-id>/` 隔离分片)。
- **lock file**: `engine/.cache/session.lock` 5 字段 `pid|session_id|role|started_at|task_id`。
- **tombstone**: `engine/.cache/session.tombstone` 通知其他会话旧协调者已退出(正常退出写 `coordinator-exited`,强制替换写 `forced-replaced`)。
- **双信号 PreToolUse 拦截**: worker 身份由 OR 关系判定 — `agent_id` 非空 **或** `.cache/sessions/<key>.role=worker` 标记文件存在(任一即拦截共享记忆写入)。

### `engine assume-coordinator [--force]` 使用频率警示

- **--force 是逃生通道,不是常规操作**。滥用 `--force` 会绕过协调者排他性,导致并发写竞争回潮,抵消 v6.11.0 的核心收益。
- **合法使用场景**(频率应 ≤ 每周 1 次):
  1. 旧协调者崩溃后留下 stale lock(已超过 24h tombstone 过期阈值)。
  2. 协调者会话意外关闭但 lock 未释放(进程未正常退出)。
  3. 架构师明确要切换协调者到另一会话(罕见,需先确认旧协调者已停止工作)。
- **非法使用场景**:
  1. 为了"绕过 PreToolUse 拦截"而频繁 --force(应改用 `engine workstream --kind=session` 显式降级)。
  2. 在 worker 想直接改共享记忆时 --force(应改用 `engine merge-workstream <session-id>` 由协调者合并)。
  3. 多个 worker 同时 --force 抢协调者(必然产生 tombstone 风暴,失去锁的意义)。
- Doctor 通过 `check_multi_session_isolation` 检查 tombstone 文件数量与时间分布,异常高频会触发 WARN。

### 同一任务卡不同 AC 的并行约束

- **同一任务卡的不同 AC 不应同时由多个 worker 并行实现**,原因:
  1. **WRITE-SET 重叠**: 同一任务卡的 AC 共享同一 WRITE-SET 路径集合,多 worker 同时改同文件会产生 git 冲突。
  2. **evidence 顺序**: `engine-verify` 按 AC 编号顺序写 evidence,并行写会产生交错覆盖。
  3. **checkpoint.md 串行性**: AC-级 checkpoint 是单链表结构(每个 AC 完成后追加),并行写会破坏链表完整性。
- **合法并行模式**:
  - 同一任务卡的不同 AC 由**单一协调者串行推进**(默认)。
  - 不同任务卡可由不同 worker 并行(各自写自己的 workstreams/<task>/<worker>/ 分片)。
  - 同一任务卡需要并行时,先在决策卡(D-NNN)中拆分为多个子任务卡(T-NNN-a, T-NNN-b),每个 worker 认领一张独立卡。
- **PreToolUse 拦截兜底**: worker 写入非自己分片的路径时,Stop hook 会 block,但不会预先阻止"两个 worker 同时认领同一 AC" — 这是架构师的责任,通过任务卡分配避免。

### kill switch

- 环境变量 `ENGINE_DISABLE_MULTI_SESSION=1` 或 `engine/.cache/multi-session.disabled` 标志文件存在时,SessionStart hook 跳过 lock 检测,所有会话降级为单会话模式(等同 v6.10.0 行为,fail-open)。
- 仅用于 v6.11.0 升级期间发现兼容性问题时的紧急回退。长期开启 kill switch 等于放弃多会话锁保护,应尽快定位问题并重新启用。
