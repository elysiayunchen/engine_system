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
5. Update `engine/CONTEXT.md` with current state and unresolved risks. Update `engine/HANDOFF.md` with the newest row first.
6. If the task is complete, mark the task card `done` only after evidence exists or an approved exemption is referenced.

Completion check: a future agent can resume from `engine context` without reconstructing your reasoning from chat history.
