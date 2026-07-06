<!-- ENGINE_SYSTEM_CONTRACT_MIGRATIONS_START -->
<!-- contract-version: 6.0.1 -->
## Engine System Current Contract
> Managed by Engine System contract migration. Preserve project-specific rules outside this block.

- Read `engine/ENGINE_MAP.md` first, then run the path-driven read-gate via `engine/domains/federation.json` (path-glob -> domain routing).
- Task cards (`engine/tasks/T-NNN.md`) carry a machine-readable header: GOAL / WRITE-SET / FORBIDDEN / AC+verify / CONSTRAINTS + status / lane / decision / domain. Work MUST stay within WRITE-SET and outside FORBIDDEN.
- Decision ledger (`engine/decisions/D-NNN.md`) records non-obvious choices with status / scope / expiry. Protected paths require a decision reference at commit time.
- Fractal memory: the federation table routes paths to domains; each domain may have CONTEXT.md (summary) + PITFALLS.md (budget + retrieval recipe). L2 assembly stays within the <=400 line session budget (N1).
- Three-layer gate: Stop hook (WRITE-SET / routing / FORBIDDEN -> block; missing write-back -> block; missing capsule -> warn) + git pre-commit (decision reference, done fallback) + Doctor.
- Contract compile: `contract/src/*.md` is the single source of truth; `contract/compile.sh` compiles to dist; `contract/budget.json` enforces subtraction (line count <= baseline, new Rules must net-zero). Contract debt counter (N4) is tracked by Doctor.
- Cockpit: `engine verify T-NNN` runs behavior verification (AC verify commands -> PASS/FAIL + sha256 fingerprint in `engine/evidence/`). A task card may be marked `done` only when verify is all-green or the architect grants an `exempt` marker (N3).
- After meaningful code, doc, dependency, engine-tooling, test, or behavior changes, update `CONTEXT.md` + `HANDOFF.md` and create `engine/changes/CHANGE-*.md` (Goal / Actual Changes / Impact Scope / Risk & Watchpoints / Verification / Rollback / Next Step / Responsibility Boundary).
- Plans may be marked `done` only when every AC has evidence in the spec twin Evidence column, `engine/evidence/*`, or a relevant change capsule.
- Shared engine-file writes are single-writer: parallel agents may gather drafts/evidence, but one writer lands `ENGINE_MAP.md`, `SYSTEM.md`, `PITFALLS.md`, `CONTEXT.md`, `HANDOFF.md`, anchors, and plan/spec edits.
- Claude Code hooks and git pre-commit are enforcement layers; Web/other agents follow this contract manually.
- Update check: `engine check-update` compares local `engine/VERSION` against the remote; session-start prints a non-blocking hint when a newer version exists.
<!-- ENGINE_SYSTEM_CONTRACT_MIGRATIONS_END -->
