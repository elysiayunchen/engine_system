# Changelog

## v6.11.0 (2026-07-20)

- 多 Claude Code 实例并行抢写引擎记忆三件套的隔离机制(D-029/T-036):SessionStart hook 复用 Claude Code payload 已传入的 `session_id`,用 atomic 独占 lock file(`engine/.cache/session.lock` 5 字段 `pid|session_id|role|started_at|task_id`)分配协调者/worker 角色,第一个会话获协调者(写共享三件套),后续会话降级 worker(写 `engine/workstreams/<task>/<session-id>/` 隔离分片)。
- atomic 独占 lock:bash 用 `set -C` / `noclobber` (POSIX,无外部依赖);PowerShell 用 `FileStream(FileMode.CreateNew, FileShare.None)` (OS 保证无 TOCTOU)。接管协调者时写 `engine/.cache/session.tombstone` 通知其他会话。
- PreToolUse 拦截扩展为双信号(OR 关系非 AND):`agent_id` 非空 **或** `.cache/sessions/<key>.role=worker` 标记文件存在,任一即拦截 worker 写共享记忆。Stop hook 写 `.meta` 文件(role|stopped_at|task_id)+ 协调者退出释放 lock + tombstone 通知。
- 两个逃生通道命令:`engine assume-coordinator [--force]`(强制接管 lock + 写 tombstone,三种场景:no lock/fresh、lock 无 --force 拒绝、lock 有 --force 写 forced-replaced tombstone)+ `engine merge-workstream <session-id>`(显示 worker 分片 + 提示协调者 5 步合并流程,不自动写共享记忆)。
- `engine workstream T-NNN AGENT` 加 `--kind=subagent|session` 参数(默认 subagent 向后兼容);`--kind=session` 创建 `.cache/sessions/<agent>.role=worker` 标记文件供 PreToolUse 信号 2 检测。
- kill switch:`ENGINE_DISABLE_MULTI_SESSION=1` 环境变量或 `engine/.cache/multi-session.disabled` 标志文件存在时,SessionStart hook 跳过 lock 检测,所有会话降级为单会话模式(等同 v6.10.0 fail-open)。
- engine-context 加 Active Sessions 面板(读 lock file 协调者 + .cache/sessions/*.meta workers)。
- engine-doctor 加 `check_multi_session_isolation`(FAIL 级 cv>=6.11.0,检查 lock file 5 字段格式 + tombstone 24h 过期)+ `check_workstream_orphan`(WARN 级,workstream 分片无对应 .meta 文件)。
- ENGINE_DOCTOR.md managed block 加 #17/#18 检查条款;contract-version 6.10.0→6.11.0;plugin/engine/ENGINE_DOCTOR.md 加 #29/#30 镜像条款。
- AGENT_ADAPTERS.md 加 C 档扩展子段:多会话锁基础 + assume-coordinator --force 使用频率警示(≤ 每周 1 次合法场景)+ 同一任务卡不同 AC 并行约束(WRITE-SET 重叠 / evidence 顺序 / checkpoint.md 串行性)+ kill switch 说明。
- migrator `engine-migrate-contract.{sh,ps1}` ×4 managed block 加 #17 #18 条目,幂等写入旧项目的 ENGINE_DOCTOR.md。
- 详见 `engine/changes/CHANGE-2026-07-20-03.md` 与 `engine/changes/CHANGE-2026-07-20-04.md`。

## v6.10.0 (2026-07-20)

- verify 死代码检测(D-028/T-035):verify 脚本入口自检 shellcheck/PSScriptAnalyzer 可用性,不可用时降级 grep fallback(.ps1 端含 `Install-Module -Scope CurrentUser -Force -AllowClobber` 兜底);对 WRITE-SET 触及的 .sh/.ps1 文件执行 linter + 反向调用点扫描(查函数定义在全仓的残留引用,无调用点 = 死代码候选)。
- evidence 输出:`engine/evidence/T-NNN/DEAD-CODE.json`(顶层 `exempt_all` 批量豁免 + per-entry `exempt` 细粒度 + `summary.warn_count` + `linter` 字段)+ `engine/evidence/T-NNN/COPY-PASTE.json`(jscpd 委托输出,D-028 §10 机制 B;不可用降级 skip + `jscpd_available: false`)。
- WARN→done 门项(D-028 §9):warn_count > 0 且未豁免时 done 须架构师显式豁免;`engine-doctor.{sh,ps1}` ×4 实现 `check_warn_done_gate`/`Test-WarnDoneGate`(FAIL 级;contract-version < 6.10.0 时降级 WARN 与 D-028 §9 一致;DEAD-CODE.json 顶层 `exempt_all: true` 视为全部 entry 已豁免)。
- 递归保护(`ENGINE_VERIFY_RECURSE_GUARD=$task`,task-specific guard):防止 AC verify 命令递归调用同任务 engine-verify 导致死循环;跨任务调用(如 behavior verify 测试 fixtures)正常执行。
- 迁移宽限期:contract-version < 6.10.0 时所有 WARN→done 检查 FAIL 降级为 WARN;≥ 6.10.0 时 FAIL(与 D-028 §9 一致)。
- 详见 `engine/changes/CHANGE-2026-07-20-02.md`。

## v6.9.0 (2026-07-20)

- AC 级 checkpoint.md 压缩恢复锚点：verify 脚本在每个 AC PASS 后追加写 `engine/evidence/T-NNN/checkpoint.md`（已完成 AC 列表 + 关键中间状态 + 下一 AC 指针），SessionStart 优先注入 checkpoint.md（覆盖 progress.md §4 与 HANDOFF 立即恢复点）。
- 任务粒度软门禁（D-028 §9）：AC 数量 > 12 / WRITE-SET 独立路径 > 15 / estimated_steps > 20 / WRITE-SET 字节数 > 30KB 任一触发且未声明 `checkpoint_plan` = FAIL；`checkpoint_plan: tryout` 是合法 bypass 值。
- depends-on 显式依赖字段（D-028 §9）：任务卡间逗号分隔的上游依赖列表，任一上游 status != done 时本卡置 active = FAIL（跨域拆卡协调）。
- WRITE-SET 静态预算软门禁（D-028 §10 机制 A）：`check_writeset_budget` 对 active 卡的 WRITE-SET 列出文件求 `wc -c` 之和，> 30KB 触发软门禁。
- 迁移宽限期：contract-version < 6.9.0 时所有软门禁 FAIL 降级为 WARN；≥ 6.9.0 时 FAIL（与 D-028 §9 一致）。
- 详见 `engine/changes/CHANGE-2026-07-20-01.md`。

## v6.8.0 (2026-07-20)

- (no capsules in this release)

## v6.7.0 (2026-07-19)

- v6.7.0 任务级 progress.md 压缩恢复锚点 (2026-07-19)

## v6.6.3 (2026-07-19)

- v6.6.3 hotfix (2026-07-19)

## v6.6.2 (2026-07-19)

- Doctor spec twin 误判 hotfix (2026-07-19)

## v6.6.1 (2026-07-19)

- (no capsules in this release)

## v6.6.0 (2026-07-19)

- HANDOFF 历史归档机制：会话历史表 8 条上限，超出迁移到 `engine/handoff-archive-YYYY-MM.md`（search-only，不进 SessionStart/§1，Doctor 不校验预算）。
- Doctor：sh/ps1 加 `check_handoff_history_cap`/`Test-HandoffHistoryCap` WARN 检查；`ENGINE_DOCTOR.md` 实例+模板加 #23 检查。
- Migrator：sh/ps1 加 v6.6 managed block item 11，旧项目升级时获得归档规则（不自动裁剪，由 agent 在下次写 HANDOFF 时触发）。
- Behaviors：`handoff.md` step 4 加归档触发；step 5 加 CONTEXT ✅ 划线行删除。
- 当前仓样本：HANDOFF 53→8 条 + 35 条 7 月归档 + 11 条 6 月归档；CONTEXT 删 8 条 ✅ 划线行。
- 详见 `engine/changes/CHANGE-2026-07-19-01.md`。

## v6.5.0 (2026-07-17)

- 长会话与全路径任务边界：v6.5+ 无 active/closing 任务卡时普通写入 fail-closed，done 逐 AC 要 PASS evidence。
- 并行 agent 记忆分片：worker 使用 `engine/workstreams/<task>/<agent>/`，共享 CONTEXT/HANDOFF 由协调者单写汇总。
- 低 token 重锚：UserPromptSubmit 周期提示实测 4 行；Doctor 聚合 done 历史，避免任务数量线性消耗上下文。
- 发布完整性：installer `--local` SHA256 校验、runtime-law 失败硬报错、双实现 parity 与完整隔离安装验证通过。
- 详见 `engine/changes/CHANGE-2026-07-17-01.md`、`CHANGE-2026-07-17-02.md`。

## v6.3.1 (2026-07-14)

- Doctor 补字节上限 + 单行宽度上限检查 (2026-07-14)

## v6.3.0 (2026-07-14)

- Architect self-view and change capsules (2026-06-22)
- CHANGE-2026-07-03-01 (2026-07-03)
- CHANGE-2026-07-03-02 (2026-07-03)
- v6 S2 Fractal Memory (2026-07-03)
- v6 S3 Contract Compile (2026-07-03)
- v6 S4 Cockpit (2026-07-03)
- v6 体系完善批次1：分发完整性 + Doctor 编译检查 (2026-07-03)
- v6 体系完善批次2a：pre-commit 认 done + 安装 (2026-07-03)
- v6 体系完善批次3：S3-b 源模块细分 (2026-07-03)
- v6 体系完善批次2b：D6 根锚点 (2026-07-03)
- v6 体系完善批次4：契约债计数器（N4） (2026-07-03)
- v6 review 缺口修复：dist 行尾 + N3 done-gate + dist 多产物 (2026-07-03)
- v6 中优先缺口：N1 注入计数器 + L0 注入 + flaky (2026-07-03)
- v6 低优先缺口：Q3 门禁严格度 + Q4 v6 命名 (2026-07-03)
- Engine v6 auto-update + migration mechanism (2026-07-03)
- v6 验收缺口修复 + 外部 4 bug(D-015/T-014) (2026-07-04)
- # CHANGE — 2026-07-05-01 (2026-07-05)
- # CHANGE — 2026-07-05-02 (2026-07-05)
- # CHANGE — 2026-07-05-03 (2026-07-05)
- T-018 离线安装包 (2026-07-05)
- T-019 Phase 1 核心设计(D-018)+ init prompt 通用化分发 + engine init (2026-07-05)
- CHANGE-2026-07-05-06 (2026-07-05)
- D-019 行为引擎化提案(proposed) (2026-07-06)
- T-022 P0 防护卡 + 分发盲区修复 (2026-07-06)
- T-023 行为技能层 + 发布可用性准则 (2026-07-12)
- T-024 SYSTEM/Doctor 职责边界修正 (2026-07-12)
- VERSION 6.0.1 → 6.2.0 补回遗漏更新 (2026-07-12)
- engine/checks/ 自定义检查扩展点 (2026-07-12)
- VERSION 卡死 bug 修复 + Doctor 格式特征检测 (2026-07-14)
