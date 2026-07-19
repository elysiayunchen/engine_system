---
name: engine-handoff
description: Prepare an Engine System handoff at the end of a work unit or session. Use when pausing, finishing, summarizing progress, creating a change capsule, marking a task done, or leaving precise next steps for a later agent.
---

# Engine Handoff

Make the next session boring in the best way: clear state, clear next step, no archaeology.

1. Re-read shared CONTEXT/HANDOFF, the task card, and every pending `engine/workstreams/<task>/*/` shard before coordinator edits. Workers re-read only their own shard.
2. Summarize what changed in workflow language, not only file lists.
3. Record verification results and any command that was not run.
4. Add the newest `HANDOFF.md` row at the top of the history table. If the history table then exceeds 8 rows, move the oldest row(s) to `engine/handoff-archive-YYYY-MM.md` (named by the month of the moved row's date). The archive file is search-only — never loaded by SessionStart, never registered in ENGINE_MAP §1.
5. Update `CONTEXT.md` status, current assumptions, pending decisions, and risks. Remove any `~~struck-through~~` items from "to-verify" sections — verified items no longer belong there.
6. Link the relevant change capsule and evidence folder when they exist.

Release portability check: note whether the change has been proven through package/install surfaces or only through this repository.

## HANDOFF immediate-resume pointer thin-pointer rule (v6.7.0 / D-028/T-032)

When an active or paused task card exists, HANDOFF「立即恢复点」degrades to a thin pointer (≤5 lines) pointing at `engine/tasks/T-NNN/progress.md` §4 (当前进行到), because progress.md is now the machine-injected fine-grained recovery anchor (SessionStart hook injects §1~§7). Duplicating the same recovery content in HANDOFF would create two competing sources of truth.

- Active/paused card exists → HANDOFF「立即恢复点」first line MUST be `见 engine/tasks/T-NNN/progress.md §4: [one-sentence current step]`. Up to 2 additional lines of session-level coarse hints allowed.
- No active/paused card → HANDOFF「立即恢复点」keeps the legacy session-level form (no enforced line cap).
- Read order at SessionStart: inject HANDOFF first (coarse), then progress.md (fine-grained, §4 overrides HANDOFF's resume segment).

This is a symmetric extension of the existing re-anchor (read-before-write) principle: re-anchor prevents drift before a write; progress.md prevents drift after a compact.
