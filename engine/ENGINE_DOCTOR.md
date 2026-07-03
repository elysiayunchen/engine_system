# ENGINE_DOCTOR — 引擎健康检查契约

> Engine System (engine_system) · Last updated: 2026-06-22
> 说明：本 dogfood 实例的轻量维护契约。完整模板见 `plugin/engine/ENGINE_DOCTOR.md`。

## 当前检查范围

- `engine/ENGINE_MAP.md` 必须存在，并作为会话第一读取入口。
- `engine-doctor.{sh,ps1}` 支持两种模式：默认项目模式验证已初始化的 `engine/`；`--package-mode` / `-PackageMode` 验证 `plugin/` 发行模板，不要求模板里已有 `ENGINE_MAP.md`。
- `ENGINE_MAP.md` §1 注册的权威文件必须存在于 `engine/`。
- `engine/*.md` 中看起来像权威文件的文档必须登记到 §1，或明确是 README / archive / cache / external。
- 维护脚本必须由插件分发，但不作为权威文件登记；脚本契约由本文件和插件模板共同说明。
- Claude Code hook、git pre-commit、跨 agent anchor sync 缺失时，Doctor 应报告 warning 并提示运行 `/engine-sync`。
- `engine/bin/engine*` CLI shim 缺失时，Doctor 应报告 warning；安装器负责将其复制到用户级 PATH 位置以支持 `engine update`。
- 已注册的热路径记忆文件需要做语义健康检查：`CONTEXT.md` 要有可用状态面板，`HANDOFF.md` 要有立即恢复点和日期化历史，`PITFALLS.md` 条目要能描述触发条件、影响范围、避免方式与验证方式，`SPRINT.md` 要有完成标准和验证方法。
- 有意义的代码 / 文档 / 引擎工具改动需要有 `engine/changes/CHANGE-*.md` change capsule，面向非技术架构师说明目标、实际变化、影响范围、风险、验证、回滚、下一步和责任边界。
- 已标记 `done` 的 plan/spec twin 必须能指向验收证据：spec twin 的 Evidence 列、`engine/evidence/*`，或相关 `engine/changes/CHANGE-*.md`。
- `engine/.cache/project-view.generated.md` 属于可重建 self-view 快照；如生成，不登记为权威文件，使用前应由 `/engine-status` 或 `/engine-reconcile` 重新生成/核对。
- 仓库级 release health 由 `scripts/check.ps1` / `scripts/check.sh` 统一执行：项目 Doctor、插件 package Doctor、PowerShell 语法、shell 语法、installer manifest、`engine/` 与 `plugin/` 副本漂移检查。

## 自维护脚本

- `engine-hook-session-start.{sh,ps1}`：会话开始自动注入 CONTEXT / HANDOFF / pending note。
- `engine-hook-stop.{sh,ps1}`：代码改动但未回写 CONTEXT / HANDOFF 时，拦截一次结束。判定契约（v6 S0）：解析一律 `git status --porcelain -z`（防 quotepath 转义击穿；rename 取新路径）；capsule 缺失走 WARN（systemMessage，不拦截）；sh/ps1 判定必须一致，由 `tests/hook-parity/run-parity.sh` 机器背书。
- `engine-hook-session-end.{sh,ps1}`：非阻塞运行 Doctor，把 warning/failure 缓存到 `engine/.cache/pending.txt`。
- `engine-hook.cmd`：Windows C 层调度垫片（bash → Git for Windows bash.exe → PowerShell 孪生逐级回退），消灭 `bash` 不在 cmd PATH 时 hooks 静默哑火。
- `engine-sync-agent-anchors.{sh,ps1}`：生成或更新 Copilot / Cursor / Gemini / Cline / Roo / Aider 等薄引导文件。
- `engine-migrate-contract.{sh,ps1}`：旧项目契约迁移器，幂等写入当前 Engine System managed contract block（首行携带 `<!-- contract-version: X -->`，Doctor 与增量迁移由此识别项目所载契约版本），并生成 migration change capsule。
- `githooks/pre-commit`：B 层门禁，防止提交代码改动但没有引擎回写。
- `engine/bin/engine*`：终端远端更新入口，支持 `engine update`。
- `scripts/check.{ps1,sh}`：仓库维护入口，不随插件安装到用户项目；发布前必须全绿。

## 后续

当前文件是 CLI-LEAN dogfood 精简版。正式发布前，用 `/engine-reconcile` 将本实例升级为完整 v5.5 注册表结构。
