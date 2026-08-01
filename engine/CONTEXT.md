# CONTEXT — 当前状态

> Engine System (engine_system) · Last updated: 2026-08-01 (v6.26.0) · Profile: CLI-LEAN

## 状态面板

<!-- legacy: status-panel (double-write transition, v6.19.0~v6.20.0) -->
<!-- engine context 输出时实时重算 "Derived Status" 段(machine-verified),本静态段保留并标 legacy -->

| 维度 | 状态 |
|------|------|
| 构建 | ✅ 正常（纯 markdown + shell 脚本，无构建步骤） |
| 上次完成 | **v6.26.0(T-077 Gatekeeper 子系统)**:`engine gate T-NNN` 聚合门禁证据 → GATE.json;pre-commit done 过渡硬拦截(status=pass + provenance);--no-verify 封死(bypass-detected → block all commits);Doctor check_gate_registry;D-039 决策(budget 2940→2980)。测试 25 断言全 PASS(cli 11 + precommit 9 + seal 5)。前序 **v6.23.0(T-075/T-076 Prove 子系统)**。 |
| 进行中 | **T-080、T-069、T-082** 仍在维护中；**T-081 已 done**：已修复 root/plugin 跨 shell JSON 路径、PowerShell manifest 顺序、历史 evidence 分级与 Bash PowerShell 解析，并补齐 verify/close 的 MANIFEST 写入边界；完成 9/9 verify、review、agent-review、prove(4/4)、gate、close，Doctor 0 failure。已知债：旧卡/旧 evidence、tag/VERSION、CLI-LEAN 长度与孤儿 shard 仍为可见 warning。 |
| 阻塞 | 无。 |

## 当前假设 / 决策（本轮拍板）

- **多会话并行 = 任务卡即租约 + union gating（D-035, v6.12.0）**：每个并行会话各持一张 active 卡,门禁按「路径 ∈ 任一卡 WRITE-SET 且 ∉ 该卡 FORBIDDEN」放行;共享单例由协调者租约独占(lock/heartbeat mtime TTL 120min,写时验锁,stale 原子抢占);建卡/改卡 bootstrap 恒豁免。固有边界:两卡 WRITE-SET 交集竞态落 git 层(Doctor WARN 提示收窄)。
- **并行记忆 = 分片写、单点汇总（D-025,同卡协作场景）**：同一张卡的多 worker 只写 `engine/workstreams/<task>/<agent>/`，共享 CONTEXT/HANDOFF 等由协调者在 merge point 汇总；子 agent(agent_id)直接抢写共享记忆或任务局部文件由写前 hook 拦截。干自己卡的顶层会话直写自己任务的 progress/checkpoint(v6.12.0 收窄)。
- **长会话约束 = 写前硬检查 + 短版周期重锚（D-025）**：任务范围覆盖 engine 文件；每次写入不依赖模型记忆，UserPromptSubmit 只补短锚，Stop/pre-commit 收尾。
- **任务卡粒度 = 一项可独立验收的目标一卡**：多轮消息、多个 AC 与并行 worker 共用任务 ID；只读调查免卡；done 卡不注入上下文，Doctor 成功历史聚合输出，避免任务数线性消耗 token。
- **发布门 = main CI 全绿后才推 tag（D-026）**：workflow 必须走正式 `--local`；Windows 镜像行尾由 `.gitattributes` 对称固定；失败日志通过公开 annotation 暴露，不绕过门禁。
- **自维护强度 = 硬门禁**：改了代码不回写引擎记忆，Stop hook 拦截 agent 结束，自动补回写后才放行。
- **Web 端策略 = 双轨**：hooks 是 Claude Code 专属增强；Web 端 AI 靠「增量回写契约」+ 手动命令。
- **落地节奏 = 先 MVP 自试**：先验证 hooks 闭环手感，再补全三层（增量契约 + 完整 hooks + 零配置安装）并发版 v5.6。
- **健康门禁 = 一键入口**：发布前优先跑 `pwsh -NoProfile -File scripts/check.ps1 -Root .` 或 `bash scripts/check.sh`，覆盖 Doctor、脚本语法、manifest 和副本漂移。
- **Web 初始机 = 单一稳定入口**：根目录只保留 `ENGINE_FILE_SYSTEM_v5.md`；历史版本进入 `archive/engine-file-system/`，不要作为活跃入口；每次改 plugin 初始化规则时必须同步更新该稳定 prompt。
- **架构师审核层 = change capsule + Project Self-View**：无基础用户不审 raw diff；由 `engine/changes/CHANGE-*.md` 和 `/engine-status` 把目标、影响、风险、验证、回滚、责任边界翻译成人话。
- **旧项目升级 = 可执行契约迁移层**：`engine update` 只负责工具分发；`/engine-sync` 必须运行 `engine-migrate-contract.{sh,ps1}`，把当前规则作为托管区块写入 `AGENTS.md`、`engine/SYSTEM.md`、`engine/ENGINE_DOCTOR.md`，保留项目专属记忆在区块外。以后新增机制应追加到 migrator，而不是只改提示词。
- **Phase 1 口径 = D-017 原文四子项**：prompt 抽离 / CLI 扩展 / 快速安装 / agent 检测；实施设计见 D-018——「薄壳引用」修正为「编译同源 + 全量 dist」(编译已消除分叉,薄壳只剩间接层风险),proposed 待架构师批准。
- **产品面方向 = 行为引擎化(D-019,proposed)**：在既有三件套(单源编译/硬门禁/行为证据)之上长出技能面(该怎么做)+ 编排面(任务胶囊,谁去做)+ 账本面(token 可测)。三项拍板:独立立项分期落地、编排深度止于胶囊不直驱进程、防护整改(dist 漂移检测全覆盖/contract src 入 protected_paths/T-017 校验去空转)前置为 P0。技能红线:每条「必须」配机器查点或显式标注,防验收剧场搬家;净零增长照旧。
- **发布可用性优先 = SYSTEM 项目开发准则**：引擎系统是要安装到其他项目的产品,本仓通过不等于发布可用。权威位置仅为 `engine/SYSTEM.md`;Doctor 不承载、不指向、不检查该准则。涉及运行时/行为/prompt/skill/hook/迁移/安装/manifest/验证的改动,必须证明能通过 plugin+installer 进入隔离外部项目。
- **HANDOFF 历史归档 = 8 条上限 + 月度归档（D-027）**：HANDOFF.md「会话历史」表保留最近 8 条;超出时把最旧的整行迁移到 `engine/handoff-archive-YYYY-MM.md`(按月切分)。归档文件不进 SessionStart 注入、不进 ENGINE_MAP §1 注册、Doctor 不校验其预算——只供按需搜索考古。Doctor 在历史表 > 8 条时输出 WARN(不硬失败)。CONTEXT.md「待验证」段已 ✅ 验证的条目必须删除,不再以划线行留存。

## 待验证

- 待验证：Copilot CLI / Codex CLI 原生 hook 的 block 决策支持。
- 待验证：真实下游项目从旧 contract-version 迁移到 6.6 后的首次任务采用与并行 workstream 手感,以及 HANDOFF 历史归档触发是否如期在首次写入时执行。
- 待验证：v6.12.0 真实双会话并行试用——两个 Claude Code 实例各持一张卡,观察租约续期手感、TTL 默认 120min 是否合适、Doctor multi-card overlap WARN 噪声;方案 B(会话-任务强绑定)是否需要(D-035 Open Questions)。
