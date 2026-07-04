# CONTEXT — 当前状态

> Engine System (engine_system) · Last updated: 2026-07-04 · Profile: CLI-LEAN

## 状态面板

| 维度 | 状态 |
|------|------|
| 构建 | ✅ 正常（纯 markdown + shell 脚本，无构建步骤） |
| 上次完成 | 落地 **D-015 v6 验收缺口修复 + 外部 4 bug**(T-014):① engine-init.md 纳入契约编译(第 4 dist = cli-preamble + 同一模块,消灭双份实现/横幅漂移,doctor+tests 幂等扩展);② S3 拆分时丢失的 16a 采访问题(域划分来源)回补唯一真相源,budget 2439→2441(D-015 背书);③ histexpand 修复(migrate/sync 双树 MARK 单引号 + set +H);④ VERSION 语义化 6.0.0(三处一致)+ check-update/session-start 归一化比较(6.0≡6.0.0 防伪更新提示);⑤ 迁移 rules.json 基线补 protected_paths(pre-commit 契约对齐);⑥ run_migrate 版本化调度(归一化版本列排序→仅应用新步→每步 VERSION 回写,无待应用步回退幂等修复)。tests/update-flow 7/7 新套件入 check.sh;contract-compile 8/8;`engine verify T-014` 全绿;capsule:`engine/changes/CHANGE-2026-07-04-01.md` |
| 进行中 | ① PR #8 待合 main(含 D-015 全修复 + VERSION 6.0.1 bump + D-016 Doctor 占位符误报补丁 T-015);② Q2 真实大库试点待拍板;③ VERSION 6.0.1 合 main 后触发存量 6.0 用户更新提示(归一化下 6.0≠6.0.1) |
| 阻塞 | 无 |

## 当前假设 / 决策（本轮拍板）

- **自维护强度 = 硬门禁**：改了代码不回写引擎记忆，Stop hook 拦截 agent 结束，自动补回写后才放行。
- **Web 端策略 = 双轨**：hooks 是 Claude Code 专属增强；Web 端 AI 靠「增量回写契约」+ 手动命令。
- **落地节奏 = 先 MVP 自试**：先验证 hooks 闭环手感，再补全三层（增量契约 + 完整 hooks + 零配置安装）并发版 v5.6。
- **健康门禁 = 一键入口**：发布前优先跑 `pwsh -NoProfile -File scripts/check.ps1 -Root .` 或 `bash scripts/check.sh`，覆盖 Doctor、脚本语法、manifest 和副本漂移。
- **Web 初始机 = 单一稳定入口**：根目录只保留 `ENGINE_FILE_SYSTEM_v5.md`；历史版本进入 `archive/engine-file-system/`，不要作为活跃入口；每次改 plugin 初始化规则时必须同步更新该稳定 prompt。
- **架构师审核层 = change capsule + Project Self-View**：无基础用户不审 raw diff；由 `engine/changes/CHANGE-*.md` 和 `/engine-status` 把目标、影响、风险、验证、回滚、责任边界翻译成人话。
- **旧项目升级 = 可执行契约迁移层**：`engine update` 只负责工具分发；`/engine-sync` 必须运行 `engine-migrate-contract.{sh,ps1}`，把当前规则作为托管区块写入 `AGENTS.md`、`engine/SYSTEM.md`、`engine/ENGINE_DOCTOR.md`，保留项目专属记忆在区块外。以后新增机制应追加到 migrator，而不是只改提示词。

## 待验证

- ✅ ~~Windows + Git Bash 下 Claude Code 执行 hook 的精确方式~~ — SessionStart 本会话成功注入，Stop hook 成功拦截。当前 `.claude/settings.json` 用 `bash` 命令工作正常。
- ✅ ~~Stop hook 硬门禁的真实手感~~ — 仅在有未提交代码改动 + 未回写引擎时拦一次，纯问答不扰。(本轮再次确认：引擎文件在 untracked 目录下时 hook 路径解析需逐文件匹配)
- ✅ ~~用户项目中 install.sh/install.ps1 铺 settings.json 的完整路径~~ — 新增 SessionEnd hook 分发，并补 `.git/hooks/pre-commit` 自动安装（已有 hook 时保留并提示手动合并）。
- ✅ ~~仓库级健康检查入口~~ — `scripts/check.ps1` 与 `scripts/check.sh` 均通过；shell Doctor 已兼容 CRLF manifest 路径。
- ✅ ~~v5.7 自视图门禁~~ — Doctor 已能检测最近 change capsule、必备章节和 done plan 验收证据；`scripts/check.ps1` 与 `scripts/check.sh` 均通过。
- ✅ ~~旧项目机制迁移不能只靠文档~~ — 新增 `engine-migrate-contract.{sh,ps1}` 并接入 `/engine-sync`、install、manifest、Doctor bundled script checks 和 duplicate drift checks。
- 待验证：Copilot CLI / Codex CLI 原生 hook 的 block 决策支持。
