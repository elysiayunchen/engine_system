# CONTEXT — 当前状态

> Engine System (engine_system) · Last updated: 2026-07-22 · Profile: CLI-LEAN

## 状态面板

| 维度 | 状态 |
|------|------|
| 构建 | ✅ 正常（纯 markdown + shell 脚本，无构建步骤） |
| 上次完成 | **v6.11.2 patch(T-039 checkpoint.md append→dedup 修复)**:T-039 7/7 AC PASS。修复 `engine-verify.{sh,ps1}` 的 checkpoint.md append-without-dedup bug——同 AC-N 重复 PASS 无信息价值(verify 是幂等的),改为 dedup 写(同 AC-N replace 最新时间戳行,新 AC-N append)。契约源 FILE 15 "追加写"→"dedup 写" 7 处 + compile.sh 重生成 dist;verify 脚本 ×4(engine + plugin 镜像)实现 dedup(grep -v + append sh / Where-Object + Set/Add-Content ps1);skeleton ×2 注释更新;5 个 checkpoint.md 清理(T-036 111→22 行 / T-034 60→15 / T-035 51→15 / T-037 6→5 / T-038 35→14);端到端测试 test_checkpoint_dedup.{sh,ps1} 双版本 4 用例 PASS;版本 6.11.2 + CHANGELOG + manifest SHA256 更新;init.md ×3 契约文本同步;T-038 progress.md 归档 + DEAD-CODE 豁免。check.sh CHECK PASSED,engine verify T-039 7/7 PASS。 |
| 进行中 | **D-028 LPHP 大型项目接管方向已收尾**:5 版本(v6.7.0 T-032 progress.md / v6.8.0 T-033 INVENTORY / v6.9.0 T-034 checkpoint / v6.10.0 T-035 死代码检测 / v6.11.0 T-036 多会话隔离 / v6.11.1 T-038 隔离层 gap 修复 / v6.11.2 T-039 checkpoint dedup)全部 done。后续可考虑 T-034 checkpoint.md 长任务断点(weakly dependent)或新任务待规划。 |
| 阻塞 | 无。 |

## 当前假设 / 决策（本轮拍板）

- **并行记忆 = 分片写、单点汇总（D-025）**：worker 只写 `engine/workstreams/<task>/<agent>/`，共享 CONTEXT/HANDOFF 等由协调者在 merge point 汇总；子 agent 直接抢写共享记忆由写前 hook 拦截。
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
- 已验证：T-036 v6.11.0 done(18/18 AC PASS)——D-029 多 Claude Code 实例并行抢写引擎记忆三件套的隔离机制已落地:多会话锁 + worker 自动降级 + PreToolUse 双信号 + Active Sessions 面板 + workstream 命令。expiry 2026-11-30,早期预警 2026-09-15。
- 已验证：T-037(done 2026-07-20)engine/SYSTEM.md「项目开发准则」段加 `### Trae agent 工具对话延续准则` 子段——运行在 Trae 相关开发 agent 工具(TRAE IDE/Work/CLI/Plugin)时 NEVER 主动中止对话,用 AskUserQuestion 延续,避免浪费用户发起对话额度。AC-1 PASS(fp=e3b0c44298fc)。与 user_profile.md Trae agent tool continuity 准则双轨(机器自动注入 + 项目级 system 显式声明)。
