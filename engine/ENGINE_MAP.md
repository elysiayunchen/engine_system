# ENGINE_MAP — 引擎索引

> Engine System (engine_system) · Revision: 8 · Last updated: 2026-07-03
> ⚠️ MVP dogfood 实例（精简版）。完整 v5.5 注册表（§1.1 / §1.2 / §2 / §3 / 预算）待 `/engine-reconcile` 或 `/engine-init` 补全。

## §0 Profile & Read-Gate

- Active profile: **CLI-LEAN**（Claude Code 可直接读代码，只持久化 irreducible 知识；derivable 内容按需现生）。
- Read-gate：编辑前先读本文件 + 相关规则/锚点；在工作报告里声明 `read-gate:` 证据。

## §1 文件注册表

| 文件 | Class | 说明 | Last verified |
|------|-------|------|---------------|
| ENGINE_MAP.md | index | 本索引,每次会话最先读;含联邦表 | 2026-07-03 |
| CONTEXT.md | irreducible | 当前状态面板 + 本轮决策 + 域仪表盘 | 2026-07-03 |
| HANDOFF.md | irreducible | 会话交接历史 + 立即恢复点 | 2026-07-03 |
| AGENT_ADAPTERS.md | irreducible | 跨 agent 自维护适配策略（A/B/C 三档） | 2026-06-21 |
| ENGINE_DOCTOR.md | irreducible | 引擎健康检查、自维护脚本契约与旧项目 contract migrator 契约 | 2026-06-22 |

> 维护脚本：`plugin/engine/scripts/engine-hook-session-start.{sh,ps1}`、`engine-hook-stop.{sh,ps1}`、`engine-doctor.{sh,ps1}`、`engine-migrate-contract.{sh,ps1}`、`githooks/pre-commit`。
> 按 v5.5 完整注册路由，脚本属维护工具，**不登记为权威文件**；其契约见 ENGINE_DOCTOR.md 与 AGENT_ADAPTERS.md。

## §3 联邦表（Federation Table · v6 S2）

path-glob → domain 路由表。机读源:`engine/domains/federation.json`;SessionStart 据此装配 L2,Stop hook 据此校验路由一致性。

| Domain | Path-glob | 摘要 |
|--------|-----------|------|
| engine-runtime | `plugin/engine/scripts/**`, `engine/scripts/**`, `plugin/.claude/commands/**`, `engine/ENGINE_DOCTOR.md`, `ENGINE_FILE_SYSTEM_v5.md`, `scripts/check.sh`, `scripts/check.ps1` | 引擎运行时:hook 门禁 / Doctor / 迁移器 / 契约 —— 产品本身 |
| project-meta | `engine/tasks/**`, `engine/decisions/**`, `engine/changes/**`, `engine/domains/**`, `engine/CONTEXT.md`, `engine/HANDOFF.md`, `engine/ENGINE_MAP.md`, `engine/AGENT_ADAPTERS.md`, `docs/**`, `tests/**` | 项目运营记忆:任务 / 决策 / 变更 / 规划 / 测试 —— 引擎自己的狗粮 |
| _default_ | (不匹配任何域的路径) | root |

域文件:`engine/domains/<domain>/{CONTEXT.md, PITFALLS.md}`。域 CONTEXT 首行摘要提升到 SessionStart 域仪表盘;域 PITFALLS 自带预算 + 检索配方(无全局 500 行天花板)。

## §4 完整性与新鲜度

- 全局 revision：8
- 状态：MVP dogfood 阶段,已注册 hooks 闭环所需的最小文件集;v5.7 已加入 Project Self-View、change capsule、Doctor 自审门禁;**v6 方向已获架构师批准**。S0「诚实门禁」已落地:stop hook porcelain -z + capsule WARN、engine-hook.cmd 垫片、contract-version 标记、tests/hook-parity 等价测试。S1「意图内核数据层」已落地:任务卡 + 决策台账 + 三层门禁 + SessionStart 重注入 + pre-commit 决策引用 + tests/task-card。**S2「分形记忆」已落地**:联邦表 `engine/domains/federation.json`(path-glob → domain)、域引擎目录 `engine/domains/<domain>/{CONTEXT,PITFALLS}.md`、路由 read-gate(Stop hook 校验 code_path 所属域 ∈ 任务卡 domain 集合)、L2 装配(SessionStart 按 domain 注入域 CONTEXT+PITFALLS)、汇总协议(域仪表盘)、检索配方、INIT 采访加「项目分几大块」、tests/fractal-memory 21/21。本仓库自托管铺设 2 域(engine-runtime + project-meta)补 D6 缺口。
- 运营工件层（不登记为权威文件,不进 §1）：`engine/tasks/T-*.md`、`engine/decisions/D-*.md`、`engine/decisions/rules.json`、`engine/domains/**`（联邦表 + 域文件）、`engine/changes/CHANGE-*.md`、`engine/evidence/*`。
- 最近 change capsule：`engine/changes/CHANGE-2026-07-03-03.md`
- 活跃任务卡：`engine/tasks/T-002.md`（S2 分形记忆）
- 已批准决策：`engine/decisions/D-001.md`（v6 路线 A→B 主线）、`engine/decisions/D-002.md`（S2 分形记忆）
- 已知缺口：SYSTEM.md、ARCHITECTURE.md 等尚未生成;根锚点尚未铺设(S2 已补域级 CONTEXT/PITFALLS,根级待 S3 契约编译时收口)。
