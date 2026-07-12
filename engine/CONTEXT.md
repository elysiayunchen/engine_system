# CONTEXT — 当前状态

> Engine System (engine_system) · Last updated: 2026-07-12 · Profile: CLI-LEAN

## 状态面板

| 维度 | 状态 |
|------|------|
| 构建 | ✅ 正常（纯 markdown + shell 脚本，无构建步骤） |
| 上次完成 | **VERSION 6.0.1 → 6.2.0**: v6.2 提交(3f23fa2)漏更新 VERSION 文件,本次补回。VERSION、engine/VERSION、plugin/VERSION 三处同步为 6.2.0;contract-version 注释(agents.md/engine/SYSTEM.md/engine/ENGINE_DOCTOR.md)更新为 6.2.0;plugin/manifest.json VERSION sha256 重新计算。Doctor: 0 FAIL/1 WARN(契约负债 +1,已有问题)。 |
| 进行中 | ① D-019 P2(任务胶囊 + token 账本/HANDOFF 裁剪)待开卡; ② T-020(agent 检测器)paused; ③ D-018 待架构师批准(proposed); ④ Q2 试点库待拍板 |
| 阻塞 | 无 |

## 当前假设 / 决策（本轮拍板）

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

## 待验证

- ✅ ~~Windows + Git Bash 下 Claude Code 执行 hook 的精确方式~~ — SessionStart 本会话成功注入，Stop hook 成功拦截。当前 `.claude/settings.json` 用 `bash` 命令工作正常。
- ✅ ~~Stop hook 硬门禁的真实手感~~ — 仅在有未提交代码改动 + 未回写引擎时拦一次，纯问答不扰。(本轮再次确认：引擎文件在 untracked 目录下时 hook 路径解析需逐文件匹配)
- ✅ ~~用户项目中 install.sh/install.ps1 铺 settings.json 的完整路径~~ — 新增 SessionEnd hook 分发，并补 `.git/hooks/pre-commit` 自动安装（已有 hook 时保留并提示手动合并）。
- ✅ ~~仓库级健康检查入口~~ — `scripts/check.ps1` 与 `scripts/check.sh` 均通过；shell Doctor 已兼容 CRLF manifest 路径。
- ✅ ~~v5.7 自视图门禁~~ — Doctor 已能检测最近 change capsule、必备章节和 done plan 验收证据；`scripts/check.ps1` 与 `scripts/check.sh` 均通过。
- ✅ ~~旧项目机制迁移不能只靠文档~~ — 新增 `engine-migrate-contract.{sh,ps1}` 并接入 `/engine-sync`、install、manifest、Doctor bundled script checks 和 duplicate drift checks。
- ✅ ~~行为技能层不能只对 Claude Code 有效~~ — T-023 已将 5 个 behaviors 编译到 Claude Code skills + agent-neutral prompts,并通过隔离目录 local install 验证。
- 待验证：Copilot CLI / Codex CLI 原生 hook 的 block 决策支持。
