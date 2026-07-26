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
5. The lease-holding coordinator updates shared CONTEXT/HANDOFF after re-reading pending workstream shards. A same-task worker updates only its own shard and marks `merge: ready`; it never edits shared memory. A parallel session on its OWN card (v6.12.0) updates that card's progress/checkpoint directly and takes the lease (or leaves a shard) for shared memory.
6. If the task is complete, mark the task card `done` only after every declared AC has PASS evidence or an approved exemption is referenced; v6.5+ pre-commit enforces this transition.
7. INVENTORY sync check (v6.8.0 / D-028/T-033): when the task card `domain:` field is non-empty, run `bash engine/scripts/engine-doctor.sh` (or `.ps1`) and inspect the `check_inventory_bidirectional` and `check_inventory_api_uniqueness` outputs. Any FAIL must be resolved before `done`:
   - INVENTORY→code FAIL: an Entry file path in some `engine/domains/<domain>/INVENTORY.md` row does not exist → fix the path or remove the row.
   - code→INVENTORY FAIL: a file you touched in a `done` task is not represented in its domain's INVENTORY → add a row (Feature / Entry file / Public API / Status / Last verified).
   - API uniqueness FAIL: the same Public API contract name appears in multiple INVENTORY rows → rename or mark one as `deprecated` with a clear successor note.
   Migration grace period (D-028 §9): on contract-version < 6.8.0 projects, these FAILs downgrade to WARN and do not block `done`.
8. Dead code detection (v6.10.0 / D-028/T-035): `engine verify T-NNN` MUST self-check linter availability (`shellcheck` for sh / `PSScriptAnalyzer` for ps1; ps1 end includes `Install-Module -Scope CurrentUser -Force -AllowClobber` bootstrap), fall back to grep-based scan when unavailable (DEAD-CODE.json `linter` field = `grep-fallback`), call `jscpd` to scan WRITE-SET-touched `.sh` / `.ps1` / `.md` for copy-paste duplications (skip + WARN when jscpd unavailable), and run reverse call-site scan (grep WRITE-SET-deleted identifiers across the repo). Output `evidence/T-NNN/DEAD-CODE.json` (linter warnings + reverse-call-site entries + `exempt_all` / per-entry `exempt` flags + `summary.warn_count`) and `evidence/T-NNN/COPY-PASTE.json` (jscpd duplications + `jscpd_available` flag). WARN 升级为 done 门项:`warn_count > 0` requires architect exemption before `done`.
   - Per-entry exemption: mark `"exempt": true, "exempt_reason": "<reason>"` on each entry (library export, test fixture, dynamic call).
   - Batch exemption: set top-level `"exempt_all": true, "exempt_reason": "<reason>"` to exempt every entry without per-entry marking (D-028 §9).
   - Doctor `check_warn_done_gate` (FAIL level): `warn_count > 0` and not fully exempt = FAIL; `exempt_all=true` or full per-entry exempt = pass.
   - Migration grace period (D-028 §9): on contract-version < 6.10.0 projects, FAIL downgrades to WARN and does not block `done`.

Completion check: a future agent can resume from `engine context` without reconstructing your reasoning from chat history.
