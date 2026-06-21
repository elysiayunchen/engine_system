# CONTEXT — 当前状态

> Engine System (engine_system) · Last updated: 2026-06-21 · Profile: CLI-LEAN

## 状态面板

| 维度 | 状态 |
|------|------|
| 构建 | ✅ 正常（纯 markdown + shell 脚本，无构建步骤） |
| 上次完成 | 本轮完成仓库健康优化：新增 `scripts/check.ps1` / `scripts/check.sh` 一键检查、`plugin/manifest.json` 安装清单、Doctor package mode、Windows installer PowerShell hook 配置；两条检查入口均已全绿 |
| 进行中 | v5.6 自维护循环收尾：发布前保持 `scripts/check.*` 全绿，并决定未跟踪的 `ENGINE_FILE_SYSTEM_v5.2.md` 是归档、纳入版本还是忽略 |
| 阻塞 | 无 |

## 当前假设 / 决策（本轮拍板）

- **自维护强度 = 硬门禁**：改了代码不回写引擎记忆，Stop hook 拦截 agent 结束，自动补回写后才放行。
- **Web 端策略 = 双轨**：hooks 是 Claude Code 专属增强；Web 端 AI 靠「增量回写契约」+ 手动命令。
- **落地节奏 = 先 MVP 自试**：先验证 hooks 闭环手感，再补全三层（增量契约 + 完整 hooks + 零配置安装）并发版 v5.6。
- **健康门禁 = 一键入口**：发布前优先跑 `pwsh -NoProfile -File scripts/check.ps1 -Root .` 或 `bash scripts/check.sh`，覆盖 Doctor、脚本语法、manifest 和副本漂移。

## 待验证

- ✅ ~~Windows + Git Bash 下 Claude Code 执行 hook 的精确方式~~ — SessionStart 本会话成功注入，Stop hook 成功拦截。当前 `.claude/settings.json` 用 `bash` 命令工作正常。
- ✅ ~~Stop hook 硬门禁的真实手感~~ — 仅在有未提交代码改动 + 未回写引擎时拦一次，纯问答不扰。(本轮再次确认：引擎文件在 untracked 目录下时 hook 路径解析需逐文件匹配)
- ✅ ~~用户项目中 install.sh/install.ps1 铺 settings.json 的完整路径~~ — 新增 SessionEnd hook 分发，并补 `.git/hooks/pre-commit` 自动安装（已有 hook 时保留并提示手动合并）。
- ✅ ~~仓库级健康检查入口~~ — `scripts/check.ps1` 与 `scripts/check.sh` 均通过；shell Doctor 已兼容 CRLF manifest 路径。
- 待验证：Copilot CLI / Codex CLI 原生 hook 的 block 决策支持。
