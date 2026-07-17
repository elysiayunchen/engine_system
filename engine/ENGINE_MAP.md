# ENGINE_MAP — 引擎索引

> Engine System (engine_system) · Revision: 29 · Last updated: 2026-07-17
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

- 全局 revision：27
- 状态：MVP dogfood 阶段,已注册 hooks 闭环所需的最小文件集;v5.7 已加入 Project Self-View、change capsule、Doctor 自审门禁;**v6 方向已获架构师批准**。S0「诚实门禁」已落地:stop hook porcelain -z + capsule WARN、engine-hook.cmd 垫片、contract-version 标记、tests/hook-parity 等价测试。S1「意图内核数据层」已落地:任务卡 + 决策台账 + 三层门禁 + SessionStart 重注入 + pre-commit 决策引用 + tests/task-card。S2「分形记忆」已落地:联邦表 + 域引擎 + 路由 read-gate + L2 装配 + 汇总协议 + 检索配方 + INIT 采访加「项目分几大块」+ tests/fractal-memory。S3「契约编译」已落地:contract/src 单源 + compile.sh/ps1 + dist 幂等 + 减法预算。S4「驾驶舱」已落地:engine verify + evidence。**D-019 P1 行为技能层已落地**(2026-07-12):`contract/src/behaviors/*.md` 单源生成 Claude Code skills + agent-neutral prompts + plugin 镜像;`engine/domains/routing.json` 行为路由表;manifest/install 双端分发;behavior-skills 测试含隔离目录 local install。**T-024 已纠正 SYSTEM/Doctor 边界**:`engine/SYSTEM.md` 是“发布可用性优先”项目开发准则的唯一权威来源;Doctor 不承载、不指向、不检查该准则。
- v6.5 增量（D-025/T-029）：全路径任务范围、无 active 卡严格采用门、done 逐 AC evidence、session/agent 写入归属、worker workstream 分片与协调者单写已落地；任务卡按可独立验收目标复用，Prompt guard 实测 4 行，done 历史由 Doctor 聚合，避免任务数量线性消耗 token。
- 运营工件层（不登记为权威文件,不进 §1）：`engine/tasks/T-*.md`、`engine/decisions/D-*.md`、`engine/decisions/rules.json`、`engine/domains/**`（联邦表 + 域文件）、`engine/workstreams/**`（并行 worker 冷分片）、`engine/changes/CHANGE-*.md`、`engine/evidence/*`（验收证据,generated-cache）、`engine/checks/**`（项目自定义 Doctor 检查脚本,不随引擎分发内容）、`contract/**`（契约源 + 编译器 + 减法基线——引擎产品本身的源码,非用户项目内容）。
- 最近 change capsule：`engine/changes/CHANGE-2026-07-17-02.md`
- 活跃任务卡：**T-030**（v6.5.0 发布与远端可更新验证，D-026；main CI 29593949520 全绿，待 tag Release）；T-028/T-029 done（均 5/5 PASS）；T-020(agent 检测器)paused。T-030 完成后下一步为真实下游迁移试点；待批决策：D-018(proposed)；Q2 基准试点库待拍板。
- 已批准决策：`engine/decisions/D-001.md`（v6 路线 A→B 主线）、`engine/decisions/D-002.md`（S2 分形记忆）、`engine/decisions/D-003.md`（S3 契约编译）、`engine/decisions/D-004.md`（S4 驾驶舱）、`engine/decisions/D-005.md`（体系完善批次1）、`engine/decisions/D-006.md`（批次2a pre-commit）、`engine/decisions/D-007.md`（批次3 S3-b）、`engine/decisions/D-008.md`（批次2b 根锚点）、`engine/decisions/D-009.md`（批次4 契约债）、`engine/decisions/D-010.md`（review 缺口）、`engine/decisions/D-011.md`（中优先）、`engine/decisions/D-012.md`（门禁严格度）、`engine/decisions/D-013.md`（v6 命名）、`engine/decisions/D-014.md`（v6 自动更新与迁移机制）、`engine/decisions/D-015.md`（v6 验收缺口修复）、`engine/decisions/D-017.md`（发布端方向）、`engine/decisions/D-024.md`（installer 完整性）、`engine/decisions/D-025.md`（长会话硬边界 + 并行记忆分片）、`engine/decisions/D-026.md`（v6.5 发布与 CI 加固）
- 已知缺口：SYSTEM.md、ARCHITECTURE.md 等尚未生成;根锚点尚未铺设;contract/src/ 已拆为 4 主题模块(00-core/10-interview/20-file-templates/30-operational);根锚点 AGENTS.md/CLAUDE.md 已铺;契约债计数器(N4)已落地(Doctor 报告 MUST/Rule/debt + 基线);v6 路线 S0-S4 核心阶段 + 体系完善批次1-4 全部完成,N1-N5 全部达成。review 缺口已修:dist 行尾根因 + N3 done-gate + §5.5 dist 3 产物(高优先)+ N1 注入计数器(check.sh ≤400 机器强制)+ L0 SessionStart 注入(runtime-law.md)+ flaky 消除(中优先)。低优先:Q3 门禁严格度决策(D-012)+ Q4 v6 命名(版本号 6.0,D-013)。**v6 自动更新机制已落地**(D-014/T-013):VERSION 文件(根+plugin+engine 三致)+ `engine check-update`/`migrate`/`update` 一站式(拉取→migrate→doctor)+ migrator 创建 v6 数据层(tasks/decisions/domains/changes/evidence + federation.json + rules.json + VERSION)+ session-start 24h 缓存更新提示(fail-open)+ Doctor `check_engine_version` + check.sh VERSION stamp + install/manifest 分发 + migrations/v6.0 版本化 step。**诚实标注(D-015 验收)**:N5 的「门禁全绿自托管」已机器达成;「对本仓库跑完整 init」(S2 验收后半句/D6 缺口:SYSTEM/ARCHITECTURE 未生成)与「真实大库试点」(§9.2/Q2)未完成,Q2 待架构师拍板;设计 §5.2「HANDOFF 行须含任务卡 ID」与 §5.6「回写定义进 rules.json」记为已知契约债(现由 parity fixtures 兜底)。
