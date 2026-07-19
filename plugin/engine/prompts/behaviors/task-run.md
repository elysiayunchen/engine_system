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
