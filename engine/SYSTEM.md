<!-- ENGINE_SYSTEM_CONTRACT_MIGRATIONS_START -->
<!-- contract-version: 6.8.0 -->
## Engine System Current Contract
> Managed by Engine System contract migration. Preserve project-specific rules outside this block.

- Read `engine/ENGINE_MAP.md` first, then run the path-driven read-gate via `engine/domains/federation.json` (path-glob -> domain routing).
- Task cards (`engine/tasks/T-NNN.md`) carry GOAL / WRITE-SET / FORBIDDEN / AC+verify / CONSTRAINTS + status / lane / decision / domain. Every project path, including `engine/*`, MUST stay within WRITE-SET and outside FORBIDDEN.
- One independently verifiable goal uses one task card across prompts and workers; read-only investigation needs no card. Done cards stay cold and Doctor aggregates successful history.
- In contract-version 6.5+ projects, ordinary writes require an active/closing task; only task/decision card bootstrap is allowed without one. Staging `done` requires PASS evidence for every AC or an approved exemption.
- Decision ledger (`engine/decisions/D-NNN.md`) records non-obvious choices with status / scope / expiry. Protected paths require a decision reference at commit time.
- Fractal memory: the federation table routes paths to domains; each domain may have CONTEXT.md (summary) + PITFALLS.md (budget + retrieval recipe). L2 assembly stays within the <=400 line session budget (N1).
- Three-layer gate: UserPromptSubmit short refresh + PreToolUse write check + session-attributed Stop; pre-commit rechecks all staged paths (including engine files) + decision reference; Doctor checks structure/evidence.
- Contract compile: `contract/src/*.md` is the single source of truth; `contract/compile.sh` compiles to dist; `contract/budget.json` enforces subtraction (line count <= baseline, new Rules must net-zero). Contract debt counter (N4) is tracked by Doctor.
- Cockpit: `engine verify T-NNN` runs behavior verification (AC verify commands -> PASS/FAIL + sha256 fingerprint in `engine/evidence/`). A task card may be marked `done` only when verify is all-green or the architect grants an `exempt` marker (N3).
- After meaningful changes, the coordinator updates shared `CONTEXT.md` + `HANDOFF.md` + change capsule. Parallel workers run `engine workstream T-NNN <agent-id>` and update only `engine/workstreams/<task>/<agent>/` plus evidence.
- Plans may be marked `done` only when every AC has evidence in the spec twin Evidence column, `engine/evidence/*`, or a relevant change capsule.
- Shared engine memory is coordinator-only. Claude PreToolUse blocks identified subagents from shared files; Stop uses session/agent path ledgers so sibling edits cannot satisfy write-back. Other harnesses use workstream shards + pre-commit and SHOULD isolate code in git worktrees.
- `engine context` shows unmerged workstream shards; the coordinator re-reads them at the merge point before one shared-memory update.
- Update check: `engine check-update` compares local `engine/VERSION` against the remote; session-start prints a non-blocking hint when a newer version exists.
<!-- ENGINE_SYSTEM_CONTRACT_MIGRATIONS_END -->

## 项目开发准则

### 发布可用性优先

Engine System 是一个要发布给其他项目使用的项目系统,不是只服务本仓库的 dogfood 配置。

本项目的开发唯一目的,是让引擎能力能稳定安装、迁移、更新并运行在其他真实项目中。任何只在 `E:\projects\engine_system` 成立、但不能通过发布包进入外部项目的实现,都不能算完成。

开发和验收必须遵守:

- 涉及运行时、行为、prompt、skill、hook、迁移、安装、manifest、验证的改动,必须证明能通过 `plugin/` + installer 进入隔离外部项目。
- 本仓自测通过只是必要条件,不是完成条件。分发面改动还必须覆盖 `plugin/manifest.json`、`install.sh`、`install.ps1`、plugin 镜像、哈希回填和隔离目录 local install 验证。
- Claude Code 原生增强可以存在,但面向通用 agent 的能力必须同时提供 agent-neutral 项目内入口,避免把引擎锁死在单一 agent 工具里。
- 项目级开发准则以本文件为唯一权威来源;Doctor 不承载、不指向、不检查该准则。

