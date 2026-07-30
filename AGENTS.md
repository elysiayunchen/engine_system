# AGENTS.md — Engine System (engine_system)

> Bootloader / anchor (class: anchor). 把 agent 引到 ENGINE_MAP;权威规则在引擎文件,不在这里。

## Session Protocol（强制 · 所有 agent 适用）

> Applies to ALL AI agents (Claude Code, Cursor, Copilot, Codex CLI, Gemini, Aider, web chat).

1. **Session Start**: Claude Code = hook auto-injects. All others = **run `engine context`** first.
2. **Before Coding**: 无 active 任务先建卡；改动 ⊆ active 任务卡 WRITE-SET ∉ FORBIDDEN。受保护路径须 approved 决策覆盖。
3. **Write-back**: 协调者更新共享 CONTEXT/HANDOFF；并行 worker 运行 `engine workstream T-NNN <agent-id>`，只写自己的分片。

Agent Tiers: C(hooks, auto) / B(git pre-commit) / A(self-enforce via this file). All share the same scripts.
CLI: `engine context` · `engine workstream T-NNN <agent-id>` · `engine doctor` · `engine verify T-NNN` · `engine migrate` · `engine check-update`
入口: 契约 `ENGINE_FILE_SYSTEM_v5.md` · 索引 `engine/ENGINE_MAP.md` · 状态 `engine/CONTEXT.md`

<!-- ENGINE_SYSTEM_CONTRACT_MIGRATIONS_START -->
<!-- contract-version: 6.17.2 -->
## Engine System Current Contract
> Managed by Engine System contract migration. Preserve project-specific rules outside this block.

- Read `engine/ENGINE_MAP.md` first, then run the path-driven read-gate via `engine/domains/federation.json` (path-glob -> domain routing).
- Task cards (`engine/tasks/T-NNN.md`) carry GOAL / WRITE-SET / FORBIDDEN / AC+verify / CONSTRAINTS + status / lane / decision / domain. Every project path, including `engine/*`, MUST be covered by some active card's WRITE-SET outside that same card's FORBIDDEN (v6.12.0 union gating: multiple active cards may run in parallel, one per session; one card's FORBIDDEN never vetoes another card's WRITE-SET; task/decision card files themselves bootstrap freely).
- One independently verifiable goal uses one task card across prompts and workers; read-only investigation needs no card. Done cards stay cold and Doctor aggregates successful history.
- In contract-version 6.5+ projects, ordinary writes require an active/closing task; only task/decision card bootstrap is allowed without one. Staging `done` requires PASS evidence for every AC or an approved exemption.
- Decision ledger (`engine/decisions/D-NNN.md`) records non-obvious choices with status / scope / expiry. Protected paths require a decision reference at commit time.
- Fractal memory: the federation table routes paths to domains; each domain may have CONTEXT.md (summary) + PITFALLS.md (budget + retrieval recipe). L2 assembly stays within the <=400 line session budget (N1).
- Three-layer gate: UserPromptSubmit short refresh + PreToolUse write check + session-attributed Stop; pre-commit rechecks all staged paths (including engine files) + decision reference; Doctor checks structure/evidence.
- Contract compile: `contract/src/*.md` is the single source of truth; `contract/compile.sh` compiles to dist; `contract/budget.json` enforces subtraction (line count <= baseline, new Rules must net-zero). Contract debt counter (N4) is tracked by Doctor.
- Cockpit: `engine verify T-NNN` runs behavior verification (AC verify commands -> PASS/FAIL + sha256 fingerprint in `engine/evidence/`). A task card may be marked `done` only when verify is all-green or the architect grants an `exempt` marker (N3).
- After meaningful changes, the coordinator updates shared `CONTEXT.md` + `HANDOFF.md` + change capsule. Parallel workers run `engine workstream T-NNN <agent-id>` and update only `engine/workstreams/<task>/<agent>/` plus evidence.
- Plans may be marked `done` only when every AC has evidence in the spec twin Evidence column, `engine/evidence/*`, or a relevant change capsule.
- Shared singleton memory (CONTEXT/HANDOFF/ENGINE_MAP etc.) is lease-holder-only (v6.12.0): the coordinator lease lives in `engine/.cache/session.lock`, renewed by heartbeat on every tool call, stale after ENGINE_SESSION_TTL_MIN (default 120min); PreToolUse validates the lease at write time and a free/stale lease is claimed on the spot. Subagents and demoted worker sessions write workstream shards; a worker session driving its OWN card still writes that card's progress/checkpoint directly.
- Each parallel session drives its own task card; `engine assume-coordinator` takes a stale lease without --force, a fresh one only with --force.
- `engine context` shows unmerged workstream shards; the coordinator re-reads them at the merge point before one shared-memory update.
- Update check: `engine check-update` compares local `engine/VERSION` against the remote; session-start prints a non-blocking hint when a newer version exists.
<!-- ENGINE_SYSTEM_CONTRACT_MIGRATIONS_END -->

