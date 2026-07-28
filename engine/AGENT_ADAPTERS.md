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

## C 档扩展:多会话租约使用约束(v6.11.0+ D-029/T-036,v6.12.0 D-035/T-048 租约化)

> 多会话机制让多个 Claude Code 实例并行运行:共享单例记忆由「协调者租约」独占,任务门禁按 union gating 逐卡判定——**每个会话各持一张任务卡即可并行,不再互相拦截**。以下规则适用于所有支持 C 档 hook 的 agent。

### 租约基础(v6.12.0)

- **主用法**: 每个并行会话激活/新建**自己的**任务卡直接干活。三层门禁按「路径 ∈ 任一 active 卡 WRITE-SET 且 ∉ 该卡 FORBIDDEN」放行;建卡/改卡(bootstrap)永不被别人的卡拦。
- **协调者/worker 角色**: 持有租约的会话可写共享单例(CONTEXT/HANDOFF/ENGINE_MAP 等);其他会话降级 worker——照常干自己的卡(含自己任务的 progress/checkpoint),只是不写共享单例。
- **lock file**: `engine/.cache/session.lock` 5 字段 `pid|session_id|role|started_at|task_id`。**pid 仅诊断**——活性 = 租约新鲜度:lock mtime 或持锁会话 `.hb` 心跳在 `ENGINE_SESSION_TTL_MIN`(默认 120 分钟)内。心跳由 PreToolUse(每次工具调用)与 guard(每轮)自动续租。
- **写时验租约**: 写共享单例逐次验锁——持锁放行;他人租约 fresh 拦截;free/stale 当场原子抢占(含残留 worker 旗标的自愈升格)。
- **tombstone**: `engine/.cache/session.tombstone` 是**历史 transition 记录**(`coordinator-exited` / `stale-recovered` / `forced-replaced`),非 active 状态信号——lock + lease mtime 才是状态源。新 coordinator 上任(fresh / same-sid resume)时由 SessionStart hook 自动清理;stale-recovery 路径覆盖写入。Doctor 对 >24h tombstone 报 WARN(cv>=6.12.2),不再 FAIL。
- **双信号 PreToolUse 拦截**: worker 身份 = `agent_id` 非空 **或** `.cache/sessions/<key>.role=worker` 旗标存在。旗标由 coordinator 上位路径自动清理 + 7 天孤儿 GC(不会把 resume 会话钉死为 worker)。

### `engine assume-coordinator [--force]` 使用约束

- **租约 stale 时免 --force**:崩溃恢复是无参主场景,stale 租约直接接管并写 `stale-recovered` tombstone。
- **--force 仅用于抢占 fresh 租约**(架构师明确要切换协调者且确认旧会话已停工)。滥用 --force 会绕过排他性,导致并发写竞争回潮。
- **非法使用**: worker 想改共享记忆时 --force(应由协调者 `engine merge-workstream <session-id>` 合并);多会话互相 --force 抢锁(tombstone 风暴)。
- Doctor 通过 `check_multi_session_isolation` 检查 tombstone 数量与时间分布,异常高频触发 WARN。

### 并行模式选择

- **默认**: 不同任务卡由不同会话并行(v6.12.0 union gating 直接支持,无需分片)。卡作者应收窄 WRITE-SET——两张卡声明交集路径时 union 放行两边,交集竞态回到 git 层。
- **同一任务卡多 worker**: 仍走分片协议(`engine workstream T-NNN <id> --kind=session` 写 `engine/workstreams/<task>/<id>/`,协调者 merge)。原因:同卡共享 WRITE-SET/evidence/checkpoint,直接并行写必冲突。
- **同会话 subagent**(agent_id 非空): 保持 v6.5 一揽子语义——共享单例与任务局部文件都走分片。

### kill switch

- 环境变量 `ENGINE_DISABLE_MULTI_SESSION=1` 或 `engine/.cache/multi-session.disabled` 标志文件存在时,SessionStart hook 跳过租约检测,所有会话降级单会话模式(fail-open)。
- 仅用于机制故障时的紧急回退。长期开启等于放弃多会话保护,应尽快定位问题并重新启用。

### Worker 写分片目录约定(v6.11.1+, D-029/T-038)

- **s-/a- 前缀 + sessions/agents 目录隔离**:`engine workstream T-NNN AGENT --kind=subagent|session` 自动按 kind 切换目录:
  - `--kind=subagent` → `engine/workstreams/<task>/agents/a-<agent>/`(subagent 由 Claude Code 派生,PreToolUse 第 1 信号 `agent_id` 非空)
  - `--kind=session` → `engine/workstreams/<task>/sessions/s-<agent>/`(顶层会话降级,PreToolUse 第 2 信号 `.role=worker` 文件存在)
- 前缀只是人类可读视觉提示,机器识别通过 `.role=worker` 标志 + workstream 目录路径(不依赖前缀)。
- `.cache/sessions/<agent>.role=worker` 标志 key 用 AGENT 不加 s- 前缀(与 SessionStart hook 算的 `<sid>-main` key 一致,确保 PreToolUse 检测匹配)。
- 已有 workstreams 目录不存在(.gitignore),无 migration 风险。

### ENGINE_WORKER 环境变量(B 档兜底, v6.11.1+)

- B 档适配器(Codex / Cursor / Aider)无 SessionStart hook 自动写 `.role=worker` 标志,需用户显式设 `ENGINE_WORKER=1` 环境变量后,pre-commit hook 拒绝共享三件套 staged:
  ```bash
  export ENGINE_WORKER=1
  ```
- 这是 B 档手动标记,与 C 档 PreToolUse 双信号机器强制互补。未来若 B 档适配器支持 SessionStart hook 自动检测则替换。
- Coordinator 会话不应设 `ENGINE_WORKER=1`(否则无法 stage 共享三件套用于回写)。
- Worker 模式下不应同时设 `ENGINE_WORKER=1` 与 `engine assume-coordinator --force`(语义冲突)。

### Worker 模式条件化写入实现(v6.11.1+, D-029/T-038)

- **D-028 三文件 worker 写分片边界已落地到实现层**(契约源 `contract/src/30-operational.md` 第 359-367 行):
  - **progress.md**: worker 写 `engine/workstreams/<task>/<sid>/progress.md` 分片(7 栏结构同共享版本),不写共享 `engine/tasks/T-NNN/progress.md`(被 PreToolUse hook `is_shared_memory` 拦截)。
  - **checkpoint.md**: worker 写分片,不写共享 `engine/evidence/T-NNN/checkpoint.md`(被拦截)。
  - **INVENTORY.md**: worker **不写**共享 `engine/domains/<domain>/INVENTORY.md`(被拦截),改为在自己分片 HANDOFF.md 的 "Merge Notes" 段记录 INVENTORY entry 变更清单。
- **HANDOFF 归档角色门控**: HANDOFF 历史表归档只在协调者执行;worker 不增行不归档,只写自己分片 HANDOFF.md。
- Doctor 通过 `check_worker_mode_implementation` 检查 `is_shared_memory` 是否含三类文件 pattern,缺失任一 = FAIL。
