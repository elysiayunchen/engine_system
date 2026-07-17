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
