# ENGINE_MAP — 引擎索引

> Engine System (engine_system) · Revision: 45 · Last updated: 2026-08-01 (v6.24.0)
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
| engine/review/config.json | mixed | review 子系统配置(L0 defaults + L1 overrides) | 2026-07-30 |
| engine/review/protocol.md | irreducible | agent-reviewer L0 默认审查协议(5 维度 + 输出规则) | 2026-07-31 |
| engine/scripts/engine-review-agent.sh | derivable | agent-reviewer CLI 入口(package/validate 两原子命令) | 2026-07-31 |
| engine/scripts/engine-review-agent-package.sh | derivable | agent-reviewer review package 生成器 | 2026-07-31 |
| engine/scripts/engine-review-agent-validate.sh | derivable | agent-reviewer AGENT-REVIEW 校验器 | 2026-07-31 |
| engine/gate/config.json | mixed | 质量门禁配置(gates 列表 / block_on / seal / docs_only_skip) | 2026-08-01 |
| engine/scripts/engine-gate.sh | derivable | 门禁聚合器 Bash CLI(聚合 verify/review/prove 证据 → GATE.json) | 2026-08-01 |
| engine/scripts/engine-gate.ps1 | derivable | 门禁聚合器 PowerShell CLI(聚合 verify/review/prove 证据 → GATE.json) | 2026-08-01 |
| docs/tdai-engine-integration-analysis.md | irreducible | TencentDB-Agent-Memory × Engine 设计层统合分析(6 方案 + 优先级) | 2026-08-01 |
| docs/tdai-engine-deep-implementation-spec.md | irreducible | TDAI × Engine 深度实现规格(算法解剖 + bash 伪代码 + 路线图) | 2026-08-01 |

### §1.1 Section class breakdown (mixed 文件分段)

| 文件 | 段落 | Class | 说明 |
|------|------|-------|------|
| engine/review/config.json | defaults + overrides | mixed | L0 defaults + L1 overrides 两段配置 |
| engine/gate/config.json | gates + policy | mixed | 质量门禁列表与 seal/docs-only 策略配置 |

> 维护脚本：`plugin/engine/scripts/engine-hook-session-start.{sh,ps1}`、`engine-hook-stop.{sh,ps1}`、`engine-doctor.{sh,ps1}`、`engine-migrate-contract.{sh,ps1}`、`githooks/pre-commit`。
> 按 v5.5 完整注册路由，脚本属维护工具，**不登记为权威文件**；其契约见 ENGINE_DOCTOR.md 与 AGENT_ADAPTERS.md。

## §3 联邦表（Federation Table · v6 S2）

path-glob → domain 路由表。机读源:`engine/domains/federation.json`;SessionStart 据此装配 L2,Stop hook 据此校验路由一致性。

| Domain | Path-glob | 摘要 |
|--------|-----------|------|
| engine-runtime | `plugin/engine/scripts/**`, `plugin/.claude/skills/**`, `plugin/engine/prompts/**`, `plugin/engine/domains/**`, `engine/scripts/**`, `engine/review/**`, `engine/prompts/**`, `plugin/.claude/commands/**`, `engine/ENGINE_DOCTOR.md`, `ENGINE_FILE_SYSTEM_v5.md`, `scripts/check.sh`, `scripts/check.ps1` | 引擎运行时:hook 门禁 / Doctor / 迁移器 / 契约 / behavior skills —— 产品本身 |
| project-meta | `engine/tasks/**`, `engine/decisions/**`, `engine/changes/**`, `engine/domains/**`, `engine/workstreams/**`, `engine/CONTEXT.md`, `engine/HANDOFF.md`, `engine/ENGINE_MAP.md`, `engine/AGENT_ADAPTERS.md`, `docs/**`, `tests/**` | 项目运营记忆:任务 / 决策 / 变更 / 并行分片 / 规划 / 测试 —— 引擎自己的狗粮 |
| _default_ | (不匹配任何域的路径) | root |

域文件:`engine/domains/<domain>/{CONTEXT.md, PITFALLS.md}`。域 CONTEXT 首行摘要提升到 SessionStart 域仪表盘;域 PITFALLS 自带预算 + 检索配方(无全局 500 行天花板)。

## §4 完整性与新鲜度

- 全局 revision：44

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
| v6.11.5 pre-commit parser 鲁棒性 | ✅ | T-043 issue #10 P038 parse_task_patterns 支持 YAML frontmatter 多行 write-set:awk 分支扩展 in_frontmatter_block 边界 + tolower case 不敏感 + frontmatter 字段头匹配 |
| v6.11.6 pre-commit fallback 移除 | ✅ | T-044 issue #10 P037 legacy fallback 移除(D-032 approved):删 L111-116(strict_task_mode=0 时 ls-1 T-*.md sort -r 扫 done 卡);strict_task_mode=0 无 active 卡 → fail-open(done 卡不再 govern);task-card gate C6/C7 更新;测试 test_precommit_no_legacy_fallback.sh 8/8 PASS |
| v6.11.7 CI 红灯修复 | ✅ | T-045 修复 GitHub Actions 自 v6.11.0 起持续红灯:engine-doctor.sh/ps1 `check_multi_session_isolation` 在 cv>=6.11.0 时硬 FAIL "`.cache/sessions` dir missing",但 CI 环境 SessionStart hook 不运行、.cache 被 .gitignore 钉住,导致每次 CI 红。检测 `CI=true`/`GITHUB_ACTIONS=true` 时降 FAIL→WARN;交互式环境行为不变。测试 test_doctor_ci_sessions.sh 3 场景 3/3 PASS。T-046 (伴随修复): install.sh/ps1 FILES 数组与 manifest.json src 列表不一致(缺 4 条 skeleton 条目,自 v6.7.0 起预存 bug)+ case 语句 blanket 重映射 bug 修复。 |
| v6.12.0 (D-035/T-048) 多卡并行 + 租约 | ✅ | 六项根因根治「激活一张卡拦死其他 agent」:三层门禁 union gating(∃active 卡覆盖即放行)+ 任务/决策卡 bootstrap 恒豁免 + protected 逐卡豁免 + lock 液性从瞬时 pid 改租约(lock/hb mtime TTL 120min,PreToolUse/guard 续租,写时验锁,stale 原子抢占 + 自愈升格)+ .role=worker 旗标全生命周期清理(7 天孤儿 GC)+ worker 面收窄(自己卡的 progress/checkpoint 直写;subagent 保持 v6.5)+ assume-coordinator stale 免 --force + 展示层多卡化 + doctor `check_multi_card_writeset_overlap` WARN。tests/multi-session 新套件 + 孤儿测试收编进 check.sh 链。契约 2896/2940(净减 14)。 |
| v6.12.1 (T-049) issue #11 九项修复 | ✅ | 门禁静默失效家族根治,原则「无法判定必须显式说出」:verify 全 SKIP → exit 3 parse-failure + 首分隔符锚定(兼容 `\| verify:`/`→ verify:`)+ AC id 字母分组 + 可疑模式 WARN(自引用 evidence/空串指纹);hook+doctor 统一三格式 WRITE-SET 解析(frontmatter 卡不再锁仓);裸目录条目覆盖子文件;status 全站点行首锚定 + active/done 冲突 FAIL;migrator 版本源 engine/VERSION 优先;INVENTORY 未初始化显式 SKIP;doctor unbound/未知旗标/整数比较修复;仓外路径不受治理;AC 模板三问 |
| v6.12.2 (T-050) tombstone 生命周期修复 | ✅ | 修双重 bug——把「历史 transition 记录」当成「active 状态信号」治理。Bug A:SessionStart hook 获取 fresh/same-sid coordinator 锁时不清理旧 tombstone(只有 assume-coordinator 命令清理)→ 安静 24h+ 仓库 doctor 必 FAIL;修复:hook 两条路径加 `rm -f .cache/session.tombstone`(对称 Stop hook 写入)。Bug B:Doctor `check_multi_session_isolation` 把 >24h tombstone 报 "exited abnormally" 并 FAIL,但 `coordinator-exited` 是正常退出标记 + 契约 #17 原文说 WARN 代码却 FAIL;修复:`tombstone_is_fail` cv 阈值切换(cv ≥ 6.12.2 WARN,cv < 6.12.2 旧 FAIL 迁移宽限)+ 消息删 "abnormally" 改 "historical transition record"。契约 #17 重写 + contract-version 升 6.12.2 + migrator + 文档同步。 |
| v6.12.3 (T-051) dist-stale pre-commit 门禁 | ✅ | v6.12.2 发版时直编编译产物 `ENGINE_FILE_SYSTEM_v5.md` 未跑 `compile.sh` 导致 CI Doctor `contract dist is not compile(src)` FAIL → CI/Release 双红 + re-tag,本版加前置防线:pre-commit hook 检测 staged 含 `contract/src/**` 或 6 个 dist 文件之一时,运行 `ENGINE_COMPILE_OUT=/tmp/xxx bash contract/compile.sh` 编译到临时目录,diff 6 个 dist 文件的工作树版本与编译输出。任一不匹配 → FAIL,消息提示 `bash contract/compile.sh`。无契约文件 staged → 跳过(零开销)。compile.sh 自身失败 → WARN(fail-open)。测试 `tests/workstream/test_precommit_dist_stale.sh` 5 场景 PASS。 |
| v6.13.0 (T-052) .engineignore 旁路通道 | ✅ | issue #17:非产品路径(跨 agent 锚点 GEMINI.md/AGENTS.md、engine 工具自身、项目 config)被 task-card union gating 拦截,要么建 throwaway 卡,要么 `--no-verify` 绕过。本版加 `.engineignore`(gitignore 风格)旁路:pre-commit hook 加 `is_engineignored()`(读 `$ROOT/.engineignore`,复用 `match_any_glob`,strip trailing `/**`,纯 shell 零子进程)+ `union_not_all_forbidden()`(命中 .engineignore 跳 WRITE-SET 检查,但不跳 FORBIDDEN——纠正 issue #17 提案设计错误)。旁路范围仅 no-card + union WRITE-SET 两块;protected-path/dist-stale 独立路径不受影响。`.engineignore` 入 rules.json protected_paths(需 covering decision D-036);Doctor `check_engineignore` 对 product 路径 WARN。`engine/skeleton/.engineignore` 模板供 engine-init。测试 7 场景 10 断言 PASS。 |
| v6.18.0 (T-066) 防漂移 P1 — 证据多锚 + drift-check | ✅ | D-038a/b 实施:evidence schema 升级为多锚(output_fingerprint + code_fingerprint via `git ls-files -s` + write_set_snapshot + verified_against_commit + write_provenance + MANIFEST.json 聚合 hash)。新增 `engine-drift-check.{sh,ps1}` 三步顺序校验(完整性自证 → WRITE-SET 二阶 → 代码指纹)。pre-commit 加 provenance gate(writer=engine-verify + commit=HEAD + argv 匹配;手动需 evidence-manual-edit 标注)。rules.json 加 `engine/evidence/**` + `engine-drift-check.*` protected_paths。engine-doctor 集成 drift-check。plugin 镜像 byte-identical(7 脚本)。测试:drift-check 5 场景 + provenance 6 场景。 |
| v6.19.0 (T-067) 防漂移 P2 — 状态面板视图化 + 信任分级注入 | ✅ | D-038c/d 实施:CONTEXT.md 状态面板从「权威声明」降级为「派生视图」(双写过渡期 v6.19.0~v6.20.0,旧静态段保留并标 `<!-- legacy: status-panel -->`,新 "Derived Status" 段由 engine context 实时重算 git tag + engine/VERSION + 最近 done 卡 evidence 信任级)。`engine-context.{sh,ps1}` 新增 `render_derived_status()` 输出 [T1]/[T2 legacy]/[T2 declared-only]/[T3 unverified] 信任标签(T1=code_fingerprint + verified_against_commit=HEAD/ancestor + tag/VERSION 一致;T2 分档 legacy-evidence/declared-only/stale;T3=待验证)。`engine-doctor.{sh,ps1}` 新增 `check_derived_status` 校验 legacy 标注 + tag/VERSION 一致性 + stale panel(双写过渡期 WARN 不 FAIL)。plugin 镜像 byte-identical(4 脚本)。测试 test_derived_status.sh 6 场景 9/9 PASS。 |
| v6.21.0 (T-071) Review P2 — agent-reviewer 语义审查 | ✅ | 两原子命令(--package 打包审查上下文 / --validate 校验 agent 产出)。5 维固定审查(correctness/design/consistency/readability/completeness) + 3 参数化静态挑战 + 反橡皮图章(E_SHALLOW) + provenance 回显模型(package_sha256 COMPUTE 归一化 + head_commit echo)。config.json agent_review 段(opt-in)。ps1 行为镜像(非 byte-identical)。60 断言全绿(CLI 12 + package 19 + validate 16 + config 4 + mirror 9)。 |
| N1-N5 | ✅ | 全部达成 |

### 运营工件层

不登记为权威文件,不进 §1：`engine/tasks/T-*.md`、`engine/decisions/D-*.md`、`engine/decisions/rules.json`、`engine/domains/**`、`engine/workstreams/**`、`engine/changes/CHANGE-*.md`、`engine/evidence/*`(generated-cache)、`engine/checks/**`、`contract/**`(引擎产品源码)。

### 当前状态

- 最近 change capsule：`engine/changes/CHANGE-2026-07-30-04.md`
- 活跃任务卡：T-071(agent-reviewer 语义审查子系统,v6.21.0)。前序: T-070 done(v6.20.0 Review P1 pipeline) / T-069 done(v6.20.0 Review P1 基础) / T-067 done(v6.19.0 防漂移 P2) / T-066 done(v6.18.0 防漂移 P1)
- 待批决策：D-018(proposed); Q2 基准试点库待拍板
- 已批准决策：D-001~D-015, D-017, D-024~D-027, D-029, D-030, D-031, D-032, D-033, D-034, D-035, D-036（详见 `engine/decisions/`）

### 已知缺口

- SYSTEM.md、ARCHITECTURE.md 尚未生成（S2 验收后半句/D6 缺口）
- 契约债：§5.2「HANDOFF 行须含任务卡 ID」与 §5.6「回写定义进 rules.json」（parity fixtures 兜底）
- 契约预算余量 44 行（2896/2940, 13/13 规则）——新特性仍应先做减法
- 多卡并行(v6.12.0)：实现完整 + 测试全绿，尚无真实双会话试用(待验证:TTL 手感 / overlap WARN 噪声 / 方案 B 必要性)
- Q2「真实大库试点」已完成（诺识 18 天试点, 2026-07-04~07-22）
