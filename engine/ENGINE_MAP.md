# ENGINE_MAP — 引擎索引

> Engine System (engine_system) · Revision: 2 · Last updated: 2026-06-21
> ⚠️ MVP dogfood 实例（精简版）。完整 v5.5 注册表（§1.1 / §1.2 / §2 / §3 / 预算）待 `/engine-reconcile` 或 `/engine-init` 补全。

## §0 Profile & Read-Gate

- Active profile: **CLI-LEAN**（Claude Code 可直接读代码，只持久化 irreducible 知识；derivable 内容按需现生）。
- Read-gate：编辑前先读本文件 + 相关规则/锚点；在工作报告里声明 `read-gate:` 证据。

## §1 文件注册表

| 文件 | Class | 说明 | Last verified |
|------|-------|------|---------------|
| ENGINE_MAP.md | index | 本索引，每次会话最先读 | 2026-06-21 |
| CONTEXT.md | irreducible | 当前状态面板 + 本轮决策 | 2026-06-21 |
| HANDOFF.md | irreducible | 会话交接历史 + 立即恢复点 | 2026-06-21 |
| AGENT_ADAPTERS.md | irreducible | 跨 agent 自维护适配策略（A/B/C 三档） | 2026-06-21 |

> 维护脚本：`plugin/engine/scripts/engine-hook-session-start.{sh,ps1}`、`engine-hook-stop.{sh,ps1}`、`engine-doctor.{sh,ps1}`、`githooks/pre-commit`。
> 按 v5.5 完整注册路由，脚本属维护工具，**不登记为权威文件**；其契约见 ENGINE_DOCTOR.md 与 AGENT_ADAPTERS.md。

## §4 完整性与新鲜度

- 全局 revision：2
- 状态：MVP dogfood 阶段，仅注册 hooks 闭环所需的最小文件集（ENGINE_MAP / CONTEXT / HANDOFF）。
- 已知缺口：SYSTEM.md、PITFALLS.md、ARCHITECTURE.md 等尚未生成；锚点（根 CLAUDE.md/AGENTS.md）尚未铺设。
