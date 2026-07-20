---
name: engine-verify-writeback
description: Verify Engine System work and write back project memory. Use after meaningful code, tooling, documentation, behavior, dependency, installer, or engine-file changes when acceptance evidence, change capsules, CONTEXT.md, and HANDOFF.md must be updated.
---

# Engine Verify Write-Back

Use this before calling work done.

1. Re-read the active task card and collect every `AC: ... verify:` command.
2. Run `engine verify T-NNN` when available; otherwise run each verify command directly and record exact pass/fail status.
3. For release-facing changes, also verify package distribution: `plugin/manifest.json`, `install.sh`, `install.ps1`, and any generated `plugin/` mirrors.
4. Create or update `engine/changes/CHANGE-*.md` with Goal, Actual Changes, Impact Scope, Risk & Watchpoints, Verification, Rollback, Next Step, and Responsibility Boundary.
5. Coordinator updates shared CONTEXT/HANDOFF after re-reading pending workstream shards. A worker updates only its own shard and marks `merge: ready`; it never edits shared memory.
6. If the task is complete, mark the task card `done` only after every declared AC has PASS evidence or an approved exemption is referenced; v6.5+ pre-commit enforces this transition.
7. INVENTORY sync check (v6.8.0 / D-028/T-033): when the task card `domain:` field is non-empty, run `bash engine/scripts/engine-doctor.sh` (or `.ps1`) and inspect the `check_inventory_bidirectional` and `check_inventory_api_uniqueness` outputs. Any FAIL must be resolved before `done`:
   - INVENTORY→code FAIL: an Entry file path in some `engine/domains/<domain>/INVENTORY.md` row does not exist → fix the path or remove the row.
   - code→INVENTORY FAIL: a file you touched in a `done` task is not represented in its domain's INVENTORY → add a row (Feature / Entry file / Public API / Status / Last verified).
   - API uniqueness FAIL: the same Public API contract name appears in multiple INVENTORY rows → rename or mark one as `deprecated` with a clear successor note.
   Migration grace period (D-028 §9): on contract-version < 6.8.0 projects, these FAILs downgrade to WARN and do not block `done`.

Completion check: a future agent can resume from `engine context` without reconstructing your reasoning from chat history.
