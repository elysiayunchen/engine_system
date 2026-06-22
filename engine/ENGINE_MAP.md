# ENGINE_MAP — 引擎索引

> Engine System (engine_system) · Revision: 5 · Last updated: 2026-06-22
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
| ENGINE_DOCTOR.md | irreducible | 引擎健康检查与自维护脚本契约 | 2026-06-22 |

> 维护脚本：`plugin/engine/scripts/engine-hook-session-start.{sh,ps1}`、`engine-hook-stop.{sh,ps1}`、`engine-doctor.{sh,ps1}`、`githooks/pre-commit`。
> 按 v5.5 完整注册路由，脚本属维护工具，**不登记为权威文件**；其契约见 ENGINE_DOCTOR.md 与 AGENT_ADAPTERS.md。

## §4 完整性与新鲜度

- 全局 revision：5
- 状态：MVP dogfood 阶段，已注册 hooks 闭环所需的最小文件集（ENGINE_MAP / CONTEXT / HANDOFF / AGENT_ADAPTERS / ENGINE_DOCTOR）；v5.7 已加入 Project Self-View、change capsule、Doctor 自审门禁和旧项目 `/engine-sync` 契约迁移清单；web 端初始机根目录只保留 `ENGINE_FILE_SYSTEM_v5.md`，历史版本归档到 `archive/engine-file-system/`。
- 最近 change capsule：`engine/changes/CHANGE-2026-06-22-01.md`
- 已知缺口：SYSTEM.md、PITFALLS.md、ARCHITECTURE.md 等尚未生成；锚点（根 CLAUDE.md/AGENTS.md）尚未铺设。
