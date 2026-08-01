# Workstream Context - T-081 / codex

> updated: 2026-08-01 | merge: pending | kind: session

- T-081 bootstrap committed as `2ff205c`.
- Health implementation is ready to commit: concrete ENGINE_MAP rows, root-level Doctor path resolution, progress/archive anchors, INVENTORY coverage, and Bash-to-Windows-PowerShell resolution.
- Static health tests and the T-080 issue regression test pass; T-080 remains behaviorally green (8/8 verify, gate PASS), and T-078 lifecycle evidence is complete at HEAD `21b75af`.
- Drift-check now distinguishes self-validating historical snapshots from tamper: old provenance/code fingerprints are explicit legacy warnings, while missing/invalid provenance remains a hard failure; PowerShell HashSet compatibility is fixed.
