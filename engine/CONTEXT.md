# CONTEXT — 当前状态

> Engine System (engine_system) · Last updated: 2026-06-22 · Profile: CLI-LEAN

## 状态面板

| 维度 | 状态 |
|------|------|
| 构建 | ✅ 正常（纯 markdown + shell 脚本，无构建步骤） |
| 上次完成 | 完成引擎功能性优化与 web 初始机整理：Doctor 增加语义记忆检查，`/engine-status` 升级为仪表盘，pitfall 条目补触发/范围/验证字段；根目录只保留 `ENGINE_FILE_SYSTEM_v5.md`，v5.5/v5.2/v4 legacy 已归档 |
| 进行中 | 提交本轮改动；后续每次改动 engine-init 规则时，同步更新根目录唯一 web 初始机 `ENGINE_FILE_SYSTEM_v5.md` |
| 阻塞 | 无 |

## 当前假设 / 决策（本轮拍板）

- **自维护强度 = 硬门禁**：改了代码不回写引擎记忆，Stop hook 拦截 agent 结束，自动补回写后才放行。
- **Web 端策略 = 双轨**：hooks 是 Claude Code 专属增强；Web 端 AI 靠「增量回写契约」+ 手动命令。
- **落地节奏 = 先 MVP 自试**：先验证 hooks 闭环手感，再补全三层（增量契约 + 完整 hooks + 零配置安装）并发版 v5.6。
- **健康门禁 = 一键入口**：发布前优先跑 `pwsh -NoProfile -File scripts/check.ps1 -Root .` 或 `bash scripts/check.sh`，覆盖 Doctor、脚本语法、manifest 和副本漂移。
- **Web 初始机 = 单一稳定入口**：根目录只保留 `ENGINE_FILE_SYSTEM_v5.md`；历史版本进入 `archive/engine-file-system/`，不要作为活跃入口；每次改 plugin 初始化规则时必须同步更新该稳定 prompt。

## 待验证

- ✅ ~~Windows + Git Bash 下 Claude Code 执行 hook 的精确方式~~ — SessionStart 本会话成功注入，Stop hook 成功拦截。当前 `.claude/settings.json` 用 `bash` 命令工作正常。
- ✅ ~~Stop hook 硬门禁的真实手感~~ — 仅在有未提交代码改动 + 未回写引擎时拦一次，纯问答不扰。(本轮再次确认：引擎文件在 untracked 目录下时 hook 路径解析需逐文件匹配)
- ✅ ~~用户项目中 install.sh/install.ps1 铺 settings.json 的完整路径~~ — 新增 SessionEnd hook 分发，并补 `.git/hooks/pre-commit` 自动安装（已有 hook 时保留并提示手动合并）。
- ✅ ~~仓库级健康检查入口~~ — `scripts/check.ps1` 与 `scripts/check.sh` 均通过；shell Doctor 已兼容 CRLF manifest 路径。
- 待验证：Copilot CLI / Codex CLI 原生 hook 的 block 决策支持。
