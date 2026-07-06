# CONTEXT — 当前状态

> Engine System (engine_system) · Last updated: 2026-07-06 · Profile: CLI-LEAN

## 状态面板

| 维度 | 状态 |
|------|------|
| 构建 | ✅ 正常（纯 markdown + shell 脚本，无构建步骤） |
| 上次完成 | **install.sh PATH fix**: 修复 Windows 终端下 `engine` 命令无 .cmd/.ps1 联动导致打开文本编辑器的 bug。install.sh 新增复制 engine.cmd/engine.ps1 到 PATH,三种 Shell 均可直接使用。 |
| 进行中 | ① Phase 1 剩余:T-020(agent 检测器)/ T-021(安装骨架),均 paused; ② D-018 待架构师批准(proposed); ③ Q2 试点库待拍板 |
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

## 待验证

- ✅ ~~Windows + Git Bash 下 Claude Code 执行 hook 的精确方式~~ — SessionStart 本会话成功注入，Stop hook 成功拦截。当前 `.claude/settings.json` 用 `bash` 命令工作正常。
- ✅ ~~Stop hook 硬门禁的真实手感~~ — 仅在有未提交代码改动 + 未回写引擎时拦一次，纯问答不扰。(本轮再次确认：引擎文件在 untracked 目录下时 hook 路径解析需逐文件匹配)
- ✅ ~~用户项目中 install.sh/install.ps1 铺 settings.json 的完整路径~~ — 新增 SessionEnd hook 分发，并补 `.git/hooks/pre-commit` 自动安装（已有 hook 时保留并提示手动合并）。
- ✅ ~~仓库级健康检查入口~~ — `scripts/check.ps1` 与 `scripts/check.sh` 均通过；shell Doctor 已兼容 CRLF manifest 路径。
- ✅ ~~v5.7 自视图门禁~~ — Doctor 已能检测最近 change capsule、必备章节和 done plan 验收证据；`scripts/check.ps1` 与 `scripts/check.sh` 均通过。
- ✅ ~~旧项目机制迁移不能只靠文档~~ — 新增 `engine-migrate-contract.{sh,ps1}` 并接入 `/engine-sync`、install、manifest、Doctor bundled script checks 和 duplicate drift checks。
- 待验证：Copilot CLI / Codex CLI 原生 hook 的 block 决策支持。
