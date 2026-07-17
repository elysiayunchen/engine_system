---
name: engine-handoff
description: Prepare an Engine System handoff at the end of a work unit or session. Use when pausing, finishing, summarizing progress, creating a change capsule, marking a task done, or leaving precise next steps for a later agent.
---

# Engine Handoff

Make the next session boring in the best way: clear state, clear next step, no archaeology.

1. Re-read shared CONTEXT/HANDOFF, the task card, and every pending `engine/workstreams/<task>/*/` shard before coordinator edits. Workers re-read only their own shard.
2. Summarize what changed in workflow language, not only file lists.
3. Record verification results and any command that was not run.
4. Add the newest `HANDOFF.md` row at the top of the history table.
5. Update `CONTEXT.md` status, current assumptions, pending decisions, and risks.
6. Link the relevant change capsule and evidence folder when they exist.

Release portability check: note whether the change has been proven through package/install surfaces or only through this repository.
