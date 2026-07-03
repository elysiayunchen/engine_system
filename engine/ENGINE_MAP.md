# ENGINE_MAP — 引擎索引

> Engine System (engine_system) · Revision: 7 · Last updated: 2026-07-03
> ⚠️ MVP dogfood 实例（精简版）。完整 v5.5 注册表（§1.1 / §1.2 / §2 / §3 / 预算）待 `/engine-reconcile` 或 `/engine-init` 补全。

## §0 Profile & Read-Gate

- Active profile: **CLI-LEAN**（Claude Code 可直接读代码，只持久化 irreducible 知识；derivable 内容按需现生）。
- Read-gate：编辑前先读本文件 + 相关规则/锚点；在工作报告里声明 `read-gate:` 证据。

## §1 文件注册表

| 文件 | Class | 说明 | Last verified |
|------|-------|------|---------------|
| ENGINE_MAP.md | index | 本索引，每次会话最先读 | 2026-06-22 |
| CONTEXT.md | irreducible | 当前状态面板 + 本轮决策 | 2026-06-22 |
| HANDOFF.md | irreducible | 会话交接历史 + 立即恢复点 | 2026-06-22 |
| AGENT_ADAPTERS.md | irreducible | 跨 agent 自维护适配策略（A/B/C 三档） | 2026-06-21 |
| ENGINE_DOCTOR.md | irreducible | 引擎健康检查、自维护脚本契约与旧项目 contract migrator 契约 | 2026-06-22 |

> 维护脚本：`plugin/engine/scripts/engine-hook-session-start.{sh,ps1}`、`engine-hook-stop.{sh,ps1}`、`engine-doctor.{sh,ps1}`、`engine-migrate-contract.{sh,ps1}`、`githooks/pre-commit`。
> 按 v5.5 完整注册路由，脚本属维护工具，**不登记为权威文件**；其契约见 ENGINE_DOCTOR.md 与 AGENT_ADAPTERS.md。

## §4 完整性与新鲜度

- 全局 revision：7
- 状态：MVP dogfood 阶段，已注册 hooks 闭环所需的最小文件集（ENGINE_MAP / CONTEXT / HANDOFF / AGENT_ADAPTERS / ENGINE_DOCTOR）；v5.7 已加入 Project Self-View、change capsule、Doctor 自审门禁，并新增 `engine-migrate-contract.{sh,ps1}` 作为旧项目可执行契约迁移层；web 端初始机根目录只保留 `ENGINE_FILE_SYSTEM_v5.md`，历史版本归档到 `archive/engine-file-system/`。**v6 方向已获架构师批准**（`docs/superpowers/specs/2026-07-03-engine-v6-direction-design.md`），S0「诚实门禁」已落地：stop hook porcelain -z + capsule WARN、engine-hook.cmd 垫片、contract-version 标记、tests/hook-parity 等价测试。**S1「意图内核数据层」已落地**：任务卡 `engine/tasks/T-NNN.md`（WRITE-SET/FORBIDDEN 机器校验）、决策台账 `engine/decisions/D-NNN.md`（受保护路径须引用 approved 决策）、SessionStart 重注入 active 任务卡、pre-commit 决策引用门禁、tests/task-card 等价测试。
- 运营工件层（不登记为权威文件，不进 §1）：`engine/tasks/T-*.md`（任务卡）、`engine/decisions/D-*.md`（决策台账）、`engine/decisions/rules.json`（受保护路径声明）、`engine/changes/CHANGE-*.md`（变更胶囊）、`engine/evidence/*`（验收证据）。
- 最近 change capsule：`engine/changes/CHANGE-2026-07-03-01.md`
- 活跃任务卡：`engine/tasks/T-001.md`（S1 意图内核数据层）
- 已批准决策：`engine/decisions/D-001.md`（v6 路线 A→B 主线）
- 已知缺口：SYSTEM.md、PITFALLS.md、ARCHITECTURE.md 等尚未生成；锚点（根 CLAUDE.md/AGENTS.md）尚未铺设。
