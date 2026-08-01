# Workstream Context - T-081 / codex

> updated: 2026-08-01 | merge: complete | kind: session

- T-081 bootstrap committed as `2ff205c`.
- Health implementation is committed in `dd907c5`: concrete ENGINE_MAP rows, root-level Doctor path resolution, progress/archive anchors, INVENTORY coverage, and Bash-to-Windows-PowerShell resolution.
- Static health tests, the T-080 issue regression test, the real WSL shell-resolution test, and the final close pass; T-081 is done with verify 7/7 and Doctor exit 0.
- Drift-check now distinguishes self-validating historical snapshots from tamper: old provenance/code fingerprints are explicit legacy warnings, while missing/invalid provenance remains a hard failure; PowerShell HashSet compatibility is fixed.
