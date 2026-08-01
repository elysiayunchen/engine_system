# T-081 progress

## Goal

收口 Engine Doctor 全仓失败与 Windows/WSL 跨 shell 生命周期缺口，并修复 done task verify 的 MANIFEST 时序缺口。

## Checkpoint

- [x] AC-1 ENGINE_MAP registry and Doctor root-path resolution
- [x] AC-2 progress anchors and T-078 archive
- [x] AC-3 domain INVENTORY coverage
- [x] AC-4 Bash verify PowerShell resolution (WSL `.exe` path rewriting verified by real T-080 run)
- [x] AC-5 historical evidence integrity (valid historical snapshots now warn; tamper remains hard-fail)
- [x] AC-6 T-078 lifecycle evidence (verify/review/agent-review/prove/gate/close recorded)
- [x] AC-7 full Doctor zero failures (Bash Doctor exit 0; legacy warnings remain explicit)
- [x] AC-8 verify refreshes MANIFEST before a Doctor AC

## Next

None. T-081 completed 8/8 verify, review, agent-review, prove, gate, close, and Doctor with zero hard failures.

> Archived by T-081 so the done card no longer retains a live progress file.
