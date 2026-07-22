---
name: engine-task-run
description: Run an Engine System task card end to end. Use when working in a project that has engine/ files and the user asks to implement, fix, modify, ship, continue, or complete work governed by an Engine task card, WRITE-SET, FORBIDDEN paths, decisions, verification, and write-back.
---

# Engine Task Run

Follow the project engine, not this skill, when they conflict. This skill is a compact route through the normal task-card workflow.

1. Load context: run `engine context` if available; otherwise read `engine/ENGINE_MAP.md`, `engine/CONTEXT.md`, and `engine/HANDOFF.md`.
2. Find the active task card under `engine/tasks/T-*.md`. If none is active, use the newest relevant approved decision or create a task card before editing.
3. Read the task card header. Treat `WRITE-SET` as the allowed edit boundary and `FORBIDDEN` as a hard stop unless an approved decision explicitly covers it.
4. Run the path-driven read gate from `engine/domains/federation.json` for the files you expect to touch.
5. Implement only the requested unit. Keep changes releasable for other projects, not only for the current repository dogfood case.
6. Run the task card `AC` verify commands, preferably through `engine verify T-NNN` when present.
7. Coordinator: write shared `engine/CONTEXT.md`, `engine/HANDOFF.md`, and a change capsule. Parallel worker: run `engine workstream T-NNN <agent-id>`, update only that shard plus evidence, and return its path to the coordinator.

Completion check: the task card AC commands pass or the remaining failure is explicitly recorded with the blocking cause and next owner.

## Task progress.md event-driven update (v6.7.0 / D-028/T-032)

Short-context agents lose mid-task details when compacted. The task-level `engine/tasks/T-NNN/progress.md` (7 sections, see `contract/src/20-file-templates.md` FILE 13) is the machine-injected recovery anchor: SessionStart hook reads it whenever an active/paused card exists, so the next agent picks up exactly where the previous one stopped without relying on agent self-discipline.

Event-driven update triggers (事件驱动, NOT every step, NOT only on compact — both extremes are anti-patterns):

- After confirming an interface signature → write §2 (已确认接口)
- After排除 a design/implementation path → write §3 (已排除路径)
- After an AC passes verify → write §4 (当前进行到:AC-N pass)
- When a question waits for the architect → write §5 (待确认问题)
- When a risk or unresolved bug is identified → write §6 (已知风险/未解 bug)
- After rolling back written code → write §7 (回滚尝试)
- On status switch (active ↔ paused ↔ done) → write §4

Boundary between §3 and §7: §3 records design-level rejections (decided before coding); §7 records implementation-level rollbacks (wrote then reverted). Never merge them.

Lifecycle:
- active/paused → `engine/tasks/T-NNN/progress.md` is the live recovery file, SessionStart injects §1~§7.
- done → move the file to `engine/archive/tasks/T-NNN-progress.md` and delete the live copy; SessionStart no longer injects it (mirrors D-027 HANDOFF archive).

When the active task card has no `progress.md` yet, instantiate it from `engine/skeleton/progress.md` before the first mid-task checkpoint. Doctor flags active/paused cards missing `progress.md` with WARN (with migration grace period, see `ENGINE_DOCTOR.md`).

## Small task exemption / 小任务豁免 (v6.11.3 / T-040)

When the task card header declares both `estimated_steps ≤ 10` AND `checkpoint_plan = inline` (or an architect-declared equivalent bypass value; `tryout` does NOT qualify because tryout cards may still be complex, e.g. T-036 estimated_steps=18), the 7-section progress.md skeleton is still used (single source of truth, `engine/skeleton/progress.md` unchanged), but event-driven update triggers relax to **§1 (已读文件) + §4 (当前进行到 / 压缩恢复点) only**:

- §1 — still triggered on "after reading a file" (small tasks at least read the task card + contract source)
- §4 — still triggered on "after an AC passes / status switch"
- §2/§3/§5/§6/§7 — may be left empty or filled with a single `n/a (small task exempt)` line (avoids being misjudged as missing file)

Rationale: small patch tasks (≤10 steps, single commit, ≤7 ACs) typically have no "interface confirmed" / "design path rejected" / "question waiting for architect" / "known bug" worth recording — everything fits in the task card GOAL/CONSTRAINTS. Forcing all 7 sections produces empty noise, violating the D-028 §6 anti-pattern rule. T-039 progress.md actually drifted to a 4-section self-invented format (§1 Goal / §2 Current Step / §3 Done / §4 Next AC), which is the symptom this exemption formalizes. See `contract/src/20-file-templates.md` FILE 13 for the full clause.

Boundary: exemption does NOT apply when `estimated_steps > 10` or `checkpoint_plan` is not inline; the latter still follows full 7-section event-driven updates. Doctor does not add/remove checks (exemption enforced by agent self-discipline + contract text; Doctor still only checks progress.md existence + migration grace period).

## Domain INVENTORY.md update on done (v6.8.0 / D-028/T-033)

Short-context agents re-derive project structure by re-reading code, which is expensive and misses existing functionality → duplicate work / dead code. The domain-level `engine/domains/<domain>/INVENTORY.md` (5-column table, ≤120 rows, see `contract/src/20-file-templates.md` FILE 14) is the machine-checkable reverse index: **semantic layer human-written (agent maintains on done), symbol layer machine-generated (ast-grep / ctags)**.

Maintenance triggers:

- Task card `status: done` → **MUST** update the INVENTORY of every domain in the task card `domain:` field. Add or refresh rows for new/changed Features. Entry file paths must exist (`test -f`); Public API contract names must be unique across the whole repo. Doctor `check_inventory_bidirectional` and `check_inventory_api_uniqueness` enforce both directions as FAIL (with migration grace period, see `ENGINE_DOCTOR.md`).
- AC pass → do NOT force-update (avoid noise).
- Casual code reading → do NOT update (INVENTORY is a contract, not a notebook).

Boundary with federation.json: federation.json maps "path belongs to which domain"; INVENTORY maps "which Features live in the domain + where their entry files are". They are complementary, not redundant.

Boundary with ast-grep / ctags: INVENTORY total view only writes semantic layer (Feature name / Entry file path / Public API contract name). API full signatures, call chains, symbol locations, data flow are all live-generated by ast-grep / grep — never hard-coded in INVENTORY (would rot on next refactor).
