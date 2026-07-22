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
<!-- contract-version: 6.11.1 -->
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
12. Task-level progress.md (v6.7.0+): active/paused task cards MUST have a corresponding `engine/tasks/T-NNN/progress.md` (7-section recovery anchor, see `contract/src/20-file-templates.md` FILE 13); done task cards MUST have their progress.md archived to `engine/archive/tasks/T-NNN-progress.md` and the live copy removed (mirrors D-027 HANDOFF archive). Projects stamped `contract-version < 6.7.0` get WARN (migration grace period, see D-028 section 9); `>= 6.7.0` get FAIL.
13. Domain INVENTORY.md (v6.8.0+, D-028/T-033): bidirectional FAIL check enforced by `check_inventory_bidirectional` 鈥?(a) INVENTORY鈫抍ode: every Entry file path in any `engine/domains/<domain>/INVENTORY.md` row must exist (`test -f`); (b) code鈫扞NVENTORY: every file path touched by a `done` task card (per its WRITE-SET and change capsule file list) must be represented in its domain's INVENTORY (the Entry file column must mention the path, or the domain must have at least one row for the feature area). Projects stamped `contract-version < 6.8.0` get WARN (migration grace period, see D-028 搂9); `>= 6.8.0` get FAIL. INVENTORY total view 鈮?20 lines; sub-files `engine/domains/<domain>/INVENTORY/<feature>.md` 鈮?00 lines each. INVENTORY does not enter SessionStart full injection 鈥?only the first-line summary enters the domain dashboard.
14. INVENTORY API uniqueness (v6.8.0+, D-028 搂10 mechanism C): `check_inventory_api_uniqueness` scans the Public API column across all `engine/domains/*/INVENTORY.md` and `engine/domains/*/INVENTORY/*.md` files; the same API contract name must not appear more than once across the whole repo, duplicates = FAIL. Optional normalization (trim + lowercase) on the Feature column catches "same function different name" cases. Migration grace period same as #13: `contract-version < 6.8.0` WARN, `>= 6.8.0` FAIL.
15. Task granularity soft gate + depends-on + WRITE-SET budget (v6.9.0+, D-028/T-034): `check_task_granularity` enforces 4 thresholds on `active` cards — AC count > 12, WRITE-SET distinct paths > 15 (mirror pairs de-duped), `estimated_steps` > 20, and WRITE-SET total bytes > 30KB (mechanism A, `check_writeset_budget` sums `wc -c` of all listed files). Any threshold hit and no `checkpoint_plan` field declared = FAIL; declaring `checkpoint_plan` (non-empty, including `tryout` legal bypass value per D-028 §9) downgrades FAIL→WARN. `check_depends_on` blocks an `active` card when any task in its `depends-on: T-NNN, T-NNN` field is not `done` = FAIL (cross-domain split coordination). Migration grace period: `contract-version < 6.9.0` WARN, `>= 6.9.0` FAIL (D-028 §9). AC-level `checkpoint.md` (FILE 15) is written by `engine-verify` on every AC PASS and prioritized by SessionStart injection (priority chain #1, covers progress.md §4 and HANDOFF immediate-resume pointer).
16. WARN→done gate (v6.10.0+, D-028/T-035): `check_warn_done_gate` enforces that an `active`/`done` task card's `evidence/T-NNN/DEAD-CODE.json` `summary.warn_count` MUST be 0, or every non-zero entry MUST be marked `exempt: true` (with `exempt_reason`), or the top-level `exempt_all: true` (with `exempt_reason`) MUST be set to batch-exempt all entries (D-028 §9). `warn_count > 0` with unexempted entries = FAIL — the architect MUST review each warning and either fix the dead code or grant an explicit exemption before `done`. verify MUST self-check linter availability (`shellcheck` for .sh / `PSScriptAnalyzer` for .ps1; ps1 end includes `Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force -AllowClobber` bootstrap, falls back to grep scan on failure with `linter: "grep-fallback"` in DEAD-CODE.json), call `jscpd` for copy-paste detection on WRITE-SET-touched `.sh`/`.ps1`/`.md` files (skip + WARN when jscpd unavailable, output `evidence/T-NNN/COPY-PASTE.json`), and run reverse call-site scan (grep WRITE-SET-deleted identifiers across the repo). Migration grace period: `contract-version < 6.10.0` WARN, `>= 6.10.0` FAIL (D-028 §9).
17. Multi-session isolation (v6.11.0+, D-029/T-036): `check_multi_session_isolation` enforces that `engine/.cache/sessions/` directory exists with the coordinator lock file `engine/.cache/session.lock` following the 5-field format (`pid|session_id|role|started_at|task_id`). Tombstone files (`engine/.cache/session.tombstone`) MUST be inspected for staleness — any tombstone older than 24 hours is treated as a stale crash marker and triggers WARN (clear via `engine assume-coordinator`). SessionStart hook MUST use atomic exclusive creation (`set -C` / `noclobber` on bash; `FileMode.CreateNew` + `FileShare.None` on PowerShell) to assign coordinator/worker roles; the first session wins coordinator, subsequent sessions degrade to workers writing to `engine/workstreams/<task>/<session-id>/` shards. PreToolUse hook MUST treat a session as worker when EITHER signal is present (OR, not AND): `agent_id` non-empty OR `.cache/sessions/<key>.role=worker` marker file exists. Kill switch `ENGINE_DISABLE_MULTI_SESSION=1` or `engine/.cache/multi-session.disabled` flag file causes SessionStart hook to skip lock detection and all sessions degrade to single-session mode (fail-open equivalent). Migration grace period: `contract-version < 6.11.0` WARN (advisory), `>= 6.11.0` FAIL (D-028 §9).
18. Workstream orphan (v6.11.0+, D-029/T-036): `check_workstream_orphan` scans every `engine/workstreams/<task>/<worker>/` directory and checks for a matching `.cache/sessions/<worker-prefix>.meta` file (8-char short-prefix match tolerated). A workstream shard without a matching `.meta` is an orphan (WARN level — worker session crashed or ended without merging its shard). The architect MUST either run `engine merge-workstream <worker>` to absorb the shard into shared engine memory, or remove the orphan shard if obsolete. This check is WARN-only because shards may legitimately persist after merge for archival under `.merged-<session-id>/`.
19. Worker mode implementation layer (v6.11.1+, D-029/T-038): `check_worker_mode_implementation` enforces that PreToolUse hook's `is_shared_memory` / `Is-SharedMemory` function (in `engine/scripts/engine-hook-stop.{sh,ps1}` + plugin mirror) covers the three D-028 worker-write-boundary files: `engine/tasks/T-*/progress.md`, `engine/evidence/T-*/checkpoint.md`, `engine/domains/*/INVENTORY.md`. Missing any of these patterns = FAIL because it lets workers write shared progress.md/checkpoint.md/INVENTORY.md and re-introduces the exact抢写 race D-029 was designed to solve. Also verifies `engine/scripts/githooks/pre-commit` (and plugin mirror) contains `ENGINE_WORKER` worker mode detection (B 档兜底). Migration grace period: `contract-version < 6.11.1` WARN, `>= 6.11.1` FAIL.
<!-- ENGINE_SYSTEM_CONTRACT_MIGRATIONS_END -->

