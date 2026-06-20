# CONTEXT — 当前状态

> Engine System (engine_system) · Last updated: 2026-06-21 · Profile: CLI-LEAN

## 状态面板

| 维度 | 状态 |
|------|------|
| 构建 | ✅ 正常（纯 markdown + shell 脚本，无构建步骤） |
| 上次完成 | v5.6 自维护循环已 commit + PR #3 已开 (feature/v5.6-self-maintenance-loop)：三层架构(C hook + B git pre-commit + A 锚点契约)、.sh/.ps1 双版本、install 集成、跨 agent 适配文档、初始机 v5.6.0 升级 |
| 进行中 | 等待 PR review → 合并后推进：增量回写契约细则 + SessionEnd 体检 hook + 跨 agent 引导文件同步 |
| 阻塞 | 无 |

## 当前假设 / 决策（本轮拍板）

- **自维护强度 = 硬门禁**：改了代码不回写引擎记忆，Stop hook 拦截 agent 结束，自动补回写后才放行。
- **Web 端策略 = 双轨**：hooks 是 Claude Code 专属增强；Web 端 AI 靠「增量回写契约」+ 手动命令。
- **落地节奏 = 先 MVP 自试**：先验证 hooks 闭环手感，再补全三层（增量契约 + 完整 hooks + 零配置安装）并发版 v5.6。

## 待验证

- ✅ ~~Windows + Git Bash 下 Claude Code 执行 hook 的精确方式~~ — SessionStart 本会话成功注入，Stop hook 成功拦截。当前 `.claude/settings.json` 用 `bash` 命令工作正常。
- ✅ ~~Stop hook 硬门禁的真实手感~~ — 仅在有未提交代码改动 + 未回写引擎时拦一次，纯问答不扰。(本轮再次确认：引擎文件在 untracked 目录下时 hook 路径解析需逐文件匹配)
- 待验证：用户项目中 install.sh/install.ps1 铺 settings.json 的完整路径；Copilot CLI / Codex CLI 原生 hook 的 block 决策支持。
