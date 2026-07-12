# AGENTS.md — Engine System (engine_system)

> Bootloader / anchor (class: anchor). 把 agent 引到 ENGINE_MAP;权威规则在引擎文件,不在这里。

## Session Protocol（强制 · 所有 agent 适用）

> Applies to ALL AI agents (Claude Code, Cursor, Copilot, Codex CLI, Gemini, Aider, web chat).

1. **Session Start**: Claude Code = hook auto-injects. All others = **run `engine context`** first.
2. **Before Coding**: 改动 ⊆ active 任务卡 WRITE-SET ∉ FORBIDDEN。受保护路径须 approved 决策覆盖。
3. **Write-back**: 每完成一个单元,增量更新 CONTEXT.md + HANDOFF.md。

Agent Tiers: C(hooks, auto) / B(git pre-commit) / A(self-enforce via this file). All share the same scripts.
CLI: `engine context` (load context) · `engine doctor` (health) · `engine verify T-NNN` · `engine migrate` · `engine check-update`
入口: 契约 `ENGINE_FILE_SYSTEM_v5.md` · 索引 `engine/ENGINE_MAP.md` · 状态 `engine/CONTEXT.md`

<!-- ENGINE_SYSTEM_CONTRACT_MIGRATIONS_START -->
<!-- contract-version: 6.2.0 -->
## Engine System Current Contract
> Managed by Engine System contract migration. Preserve project-specific rules outside this block.

- Read `engine/ENGINE_MAP.md` first, then run the path-driven read-gate via `engine/domains/federation.json` (path-glob -> domain routing).
- Task cards (`engine/tasks/T-NNN.md`) carry a machine-readable header: GOAL / WRITE-SET / FORBIDDEN / AC+verify / CONSTRAINTS + status / lane / decision / domain. Work MUST stay within WRITE-SET and outside FORBIDDEN.
- Decision ledger (`engine/decisions/D-NNN.md`) records non-obvious choices with status / scope / expiry. Protected paths require a decision reference at commit time.
- Fractal memory: the federation table routes paths to domains; each domain may have CONTEXT.md (summary) + PITFALLS.md (budget + retrieval recipe). L2 assembly stays within the <=400 line session budget (N1).
- Three-layer gate: Stop hook (WRITE-SET / routing / FORBIDDEN -> block; missing write-back -> block; missing capsule -> warn) + git pre-commit (decision reference, done fallback) + Doctor. All three layers are agent-agnostic scripts; Claude Code hooks are the best-UX tier but not required.
- Universal context: `engine context` outputs the full session memory snapshot for any agent. Claude Code gets this automatically via SessionStart hook; other agents MUST run it at session start.
- Contract compile: `contract/src/*.md` is the single source of truth; `contract/compile.sh` compiles to dist; `contract/budget.json` enforces subtraction (line count <= baseline, new Rules must net-zero). Contract debt counter (N4) is tracked by Doctor.
- Cockpit: `engine verify T-NNN` runs behavior verification (AC verify commands -> PASS/FAIL + sha256 fingerprint in `engine/evidence/`). A task card may be marked `done` only when verify is all-green or the architect grants an `exempt` marker (N3).
- After meaningful code, doc, dependency, engine-tooling, test, or behavior changes, update `CONTEXT.md` + `HANDOFF.md` and create `engine/changes/CHANGE-*.md` (Goal / Actual Changes / Impact Scope / Risk & Watchpoints / Verification / Rollback / Next Step / Responsibility Boundary).
- Plans may be marked `done` only when every AC has evidence in the spec twin Evidence column, `engine/evidence/*`, or a relevant change capsule.
- Shared engine-file writes are single-writer: parallel agents may gather drafts/evidence, but one writer lands `ENGINE_MAP.md`, `SYSTEM.md`, `PITFALLS.md`, `CONTEXT.md`, `HANDOFF.md`, anchors, and plan/spec edits.
- Enforcement is three-tiered (see Agent Tiers above): C-tier native hooks auto-inject context and block violations, B-tier git pre-commit blocks unwritten commits, A-tier anchor contract requires agent self-discipline. All tiers share the same underlying scripts — the tier determines how they're triggered, not what they check.
- Developer Communication Rule (v6.2): detect the developer's language, use GLOSSARY.md Plain meaning column, frame operations in workflow terms not engine internals. Applies to ALL agents.
- Update check: `engine check-update` compares local `engine/VERSION` against the remote; session-start prints a non-blocking hint when a newer version exists.
<!-- ENGINE_SYSTEM_CONTRACT_MIGRATIONS_END -->
