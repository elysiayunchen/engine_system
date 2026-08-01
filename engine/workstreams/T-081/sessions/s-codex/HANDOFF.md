# Workstream Handoff - T-081 / codex

> updated: 2026-08-01 | merge: pending | kind: session

## Latest

- T-081 task card is bootstrapped; first health implementation is ready for commit.
- Doctor hard failures are reduced from 27 to 2; the remaining two are T-078 missing review and agent-review evidence.
- Manifest PowerShell hashes use the repository's normalized line-ending convention; root/plugin mirrors are byte-identical.
- T-078 close passed verify/gate/Doctor as worker handoff; its regenerated evidence is ready for the final done-transition commit and its live progress anchor is archived.
- The first close attempt correctly blocked on PowerShell drift-check tamper=19; the root/plugin drift twins now classify valid historical snapshots as warnings and preserve hard-fail tamper checks.
- The WSL resolver now rewrites extensionless `pwsh` tokens to the discovered `pwsh.exe` path; the real T-080 Bash verifier reports 8/8 after this fix.
- Coordinator lease was recovered because the previous `alpha/T-050` lease was stale.
- Preserve unrelated dirty files and update shared CONTEXT/HANDOFF only after AC evidence is complete.
