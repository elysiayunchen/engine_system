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
