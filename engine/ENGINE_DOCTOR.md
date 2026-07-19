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
- 已注册的热路径记忆文件需要做语义健康检查：`CONTEXT.md` 要有可用状态面板，`HANDOFF.md` 要有立即恢复点和日期化历史且会话历史表 ≤ 8 条(超出归档到 `engine/handoff-archive-YYYY-MM.md`，归档文件不进 SessionStart 注入、不进 §1 注册)，`PITFALLS.md` 条目要能描述触发条件、影响范围、避免方式与验证方式，`SPRINT.md` 要有完成标准和验证方法。
- 有意义的代码 / 文档 / 引擎工具改动需要有 `engine/changes/CHANGE-*.md` change capsule，面向非技术架构师说明目标、实际变化、影响范围、风险、验证、回滚、下一步和责任边界。
- 已标记 `done` 的 plan/spec twin 必须能指向验收证据：spec twin 的 Evidence 列、`engine/evidence/*`，或相关 `engine/changes/CHANGE-*.md`。
- `engine/.cache/project-view.generated.md` 属于可重建 self-view 快照；如生成，不登记为权威文件，使用前应由 `/engine-status` 或 `/engine-reconcile` 重新生成/核对。
- 仓库级 release health 由 `scripts/check.ps1` / `scripts/check.sh` 统一执行：项目 Doctor、插件 package Doctor、PowerShell 语法、shell 语法、installer manifest、`engine/` 与 `plugin/` 副本漂移检查。

## 自维护脚本

- `engine-hook-session-start.{sh,ps1}`（v6 S1 升级）：会话开始自动注入 CONTEXT / HANDOFF / pending note + active 任务卡（WRITE-SET/FORBIDDEN 锚点）+ proposed 决策队列。
- `engine-hook-stop.{sh,ps1}`：三层门禁（v6 S0+S1）。解析一律 `git status --porcelain -z -uall`（防 quotepath 转义击穿；rename 取新路径；未跟踪目录展开）。① 有 active 任务卡时校验代码路径 ⊆ WRITE-SET、∉ FORBIDDEN（越界=block）；② 硬门禁=CONTEXT/HANDOFF/ENGINE_MAP 被触碰；③ capsule 缺失走 WARN。sh/ps1 判定必须一致，由 `tests/hook-parity/run-parity.sh` + `tests/task-card/run-task-tests.sh` 机器背书。
- `engine-hook-session-end.{sh,ps1}`：非阻塞运行 Doctor，把 warning/failure 缓存到 `engine/.cache/pending.txt`。
- `engine-hook.cmd`：Windows C 层调度垫片（bash → Git for Windows bash.exe → PowerShell 孪生逐级回退），消灭 `bash` 不在 cmd PATH 时 hooks 静默哑火。
- `engine-sync-agent-anchors.{sh,ps1}`：生成或更新 Copilot / Cursor / Gemini / Cline / Roo / Aider 等薄引导文件。
- `engine-migrate-contract.{sh,ps1}`：旧项目契约迁移器，幂等写入当前 Engine System managed contract block（首行携带 `<!-- contract-version: X -->`，Doctor 与增量迁移由此识别项目所载契约版本），并生成 migration change capsule。
- `githooks/pre-commit`（v6 S1 升级）：B 层门禁。第 1 层=代码改动须回写引擎记忆；第 2 层=受保护路径（`engine/decisions/rules.json` 声明）变更须由 active 任务卡的 `decision:` 引用一个 status:approved 且 scope 覆盖的决策，否则拒绝提交。
- `engine/bin/engine*`：终端远端更新入口，支持 `engine update`。
- `scripts/check.{ps1,sh}`：仓库维护入口，不随插件安装到用户项目；发布前必须全绿。

## 后续

当前文件是 CLI-LEAN dogfood 精简版。正式发布前，用 `/engine-reconcile` 将本实例升级为完整 v5.5 注册表结构。


<!-- ENGINE_SYSTEM_CONTRACT_MIGRATIONS_START -->
<!-- contract-version: 6.7.0 -->
## Current Contract Checks
> Managed by Engine System contract migration. Preserve project-specific rules outside this block.

Doctor MUST validate the current Engine System v6 contract in addition to registry health:

1. Task cards carry readable inline or section-list WRITE-SET/FORBIDDEN; those sets govern all project paths, including engine files.
2. Done task cards have PASS acceptance evidence for every declared AC (`engine/evidence/T-NNN/AC-*.json`) or an `exempt` marker (N3 done-gate).
3. Federation table `engine/domains/federation.json` is valid JSON with at least a `default_domain`.
4. Session injection budget (N1): session-start hook output <= 400 lines.
5. Contract debt (N4): MUST count + gate Rule count + debt vs baseline tracked.
6. `engine/VERSION` exists and matches the installed tooling version.
7. Recent meaningful changes have an architect-readable `engine/changes/CHANGE-*.md` capsule with required sections.
8. Plans marked `done` point to acceptance evidence in the spec twin Evidence column, `engine/evidence/*`, or a related capsule.
9. Bootloaders (AGENTS.md / CLAUDE.md) stay thin: target 30 lines, hard cap 45 lines.
10. Generated self-view snapshots, when used, live under `engine/.cache/` and are never registered as authority.
11. HANDOFF.md session history table keeps <= 8 rows; older rows move to `engine/handoff-archive-YYYY-MM.md` (search-only, not registered in ENGINE_MAP section 1, not loaded by SessionStart). Verified items in CONTEXT.md "to-verify" sections are removed.
12. Task-level progress.md (v6.7.0+): active/paused task cards MUST have a corresponding `engine/tasks/T-NNN/progress.md` (7-section recovery anchor, see `contract/src/20-file-templates.md` FILE 13); done task cards MUST have their progress.md archived to `engine/archive/tasks/T-NNN-progress.md` and the live copy removed (mirrors D-027 HANDOFF archive). Projects stamped `contract-version < 6.7.0` get WARN (migration grace period, see D-028 §9); `>= 6.7.0` get FAIL.
<!-- ENGINE_SYSTEM_CONTRACT_MIGRATIONS_END -->
