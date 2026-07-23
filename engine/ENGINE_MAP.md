# ENGINE_MAP — 引擎索引

> Engine System (engine_system) · Revision: 33 · Last updated: 2026-07-23
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
| SYSTEM.md | irreducible | 项目环境/门禁配置（managed block 由 contract migrator 维护） | 2026-07-05 |
| AGENT_ADAPTERS.md | irreducible | 跨 agent 自维护适配策略（A/B/C 三档） | 2026-06-21 |
| GLOSSARY.md | irreducible | v6.2 开发者沟通规则-术语表（Developer Communication Rule 配套） | 2026-07-13 |
| ENGINE_DOCTOR.md | irreducible | 引擎健康检查、自维护脚本契约与旧项目 contract migrator 契约 | 2026-06-22 |

> 维护脚本：`plugin/engine/scripts/engine-hook-session-start.{sh,ps1}`、`engine-hook-stop.{sh,ps1}`、`engine-doctor.{sh,ps1}`、`engine-migrate-contract.{sh,ps1}`、`githooks/pre-commit`。
> 按 v5.5 完整注册路由，脚本属维护工具，**不登记为权威文件**；其契约见 ENGINE_DOCTOR.md 与 AGENT_ADAPTERS.md。

## §3 联邦表（Federation Table · v6 S2）

path-glob → domain 路由表。机读源:`engine/domains/federation.json`;SessionStart 据此装配 L2,Stop hook 据此校验路由一致性。

| Domain | Path-glob | 摘要 |
|--------|-----------|------|
| engine-runtime | `plugin/engine/scripts/**`, `plugin/.claude/skills/**`, `plugin/engine/prompts/**`, `plugin/engine/domains/**`, `engine/scripts/**`, `engine/prompts/**`, `plugin/.claude/commands/**`, `engine/ENGINE_DOCTOR.md`, `ENGINE_FILE_SYSTEM_v5.md`, `scripts/check.sh`, `scripts/check.ps1` | 引擎运行时:hook 门禁 / Doctor / 迁移器 / 契约 / behavior skills —— 产品本身 |
| project-meta | `engine/tasks/**`, `engine/decisions/**`, `engine/changes/**`, `engine/domains/**`, `engine/workstreams/**`, `engine/CONTEXT.md`, `engine/HANDOFF.md`, `engine/ENGINE_MAP.md`, `engine/AGENT_ADAPTERS.md`, `docs/**`, `tests/**` | 项目运营记忆:任务 / 决策 / 变更 / 并行分片 / 规划 / 测试 —— 引擎自己的狗粮 |
| _default_ | (不匹配任何域的路径) | root |

域文件:`engine/domains/<domain>/{CONTEXT.md, PITFALLS.md}`。域 CONTEXT 首行摘要提升到 SessionStart 域仪表盘;域 PITFALLS 自带预算 + 检索配方(无全局 500 行天花板)。

## §4 完整性与新鲜度

- 全局 revision：33

### 里程碑状态

| 阶段 | 状态 | 要点 |
|------|------|------|
| S0 诚实门禁 | ✅ | stop hook porcelain -z + capsule WARN、engine-hook.cmd 垫片、contract-version 标记、tests/hook-parity |
| S1 意图内核 | ✅ | 任务卡 + 决策台账 + 三层门禁 + SessionStart 重注入 + pre-commit 决策引用 + tests/task-card |
| S2 分形记忆 | ✅ | 联邦表 + 域引擎 + 路由 read-gate + L2 装配 + 汇总协议 + 检索配方 + tests/fractal-memory |
| S3 契约编译 | ✅ | contract/src 单源 + compile.sh/ps1 + dist 幂等 + 减法预算(2910/2940 行, 13/13 规则) |
| S4 驾驶舱 | ✅ | engine verify + evidence + checkpoint.md + DEAD-CODE/COPY-PASTE 扫描 |
| D-019 行为技能 | ✅ | behaviors/*.md 单源 → skills + prompts + plugin 镜像; routing.json 行为路由 |
| v6.5 (D-025/T-029) | ✅ | 全路径任务范围、严格采用门、done 逐 AC evidence、写入归属、workstream 分片 |
| v6.6 (D-027/T-031) | ✅ | HANDOFF 8 条上限 + 月归档、Doctor WARN、migrator item 11 |
| v6.11.0 (D-029/T-036) | ✅ | 多会话锁(coordinator/worker)、双信号检测、kill switch、stale 接管 |
| v6.11.4 行为层 + 安装器鲁棒性 | ✅ | (a) task-run.md 仪式缩放指导:契约最小格式 vs 项目可选增强,防下游误认自选仪式为引擎强制;(b) T-042 issue #9 PS 5.1 LF-only here-string 解析失败修复:install.ps1 加 Convert-ToCrlf + 3 个 engine.cmd pwsh 优先检测(方案 A+B 双保险,D-030 批准) |
| N1-N5 | ✅ | 全部达成 |

### 运营工件层

不登记为权威文件,不进 §1：`engine/tasks/T-*.md`、`engine/decisions/D-*.md`、`engine/decisions/rules.json`、`engine/domains/**`、`engine/workstreams/**`、`engine/changes/CHANGE-*.md`、`engine/evidence/*`(generated-cache)、`engine/checks/**`、`contract/**`(引擎产品源码)。

### 当前状态

- 最近 change capsule：`engine/changes/CHANGE-2026-07-23-01.md`
- 活跃任务卡：无。前序: T-042 done(issue #9 PS 5.1 LF fix + T-041 cleanup) / T-041 done(pre-commit 自身豁免) / T-040 done(v6.11.3) / T-039 done(v6.11.2) / T-038 done(v6.11.1) / T-036 done(v6.11.0 多会话锁)
- 待批决策：D-018(proposed); Q2 基准试点库待拍板
- 已批准决策：D-001~D-015, D-017, D-024~D-027, D-029, D-030, D-031（详见 `engine/decisions/`）

### 已知缺口

- SYSTEM.md、ARCHITECTURE.md 尚未生成（S2 验收后半句/D6 缺口）
- 契约债：§5.2「HANDOFF 行须含任务卡 ID」与 §5.6「回写定义进 rules.json」（parity fixtures 兜底）
- 契约预算已满（2910/2940 行, 13/13 规则）——新特性须先做减法
- workstreams 并行路径：实现完整 + 测试全绿，尚无真实并行场景验证
- Q2「真实大库试点」已完成（诺识 18 天试点, 2026-07-04~07-22）
