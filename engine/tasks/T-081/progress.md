# T-081 Progress

> status: active | owner: coordinator-codex | updated: 2026-08-01

## Goal

收口 Engine Doctor 全仓失败与 Windows/WSL 跨 shell 生命周期缺口，并修复 verify/close 写证据时序缺口。

## Checkpoint

- [x] AC-1 ENGINE_MAP registry and Doctor root-path resolution
- [x] AC-2 progress anchors and T-078 archive
- [x] AC-3 domain INVENTORY coverage
- [x] AC-4 Bash verify PowerShell resolution (WSL `.exe` path rewriting verified by real T-080 run)
- [x] AC-5 historical evidence integrity (valid historical snapshots now warn; tamper remains hard-fail)
- [x] AC-6 T-078 lifecycle evidence (verify/review/agent-review/prove/gate/close recorded)
- [x] AC-7 full Doctor zero failures (Bash Doctor exit 0; legacy warnings remain explicit)
- [x] AC-8 verify refreshes MANIFEST before a Doctor AC
- [ ] AC-9 close refreshes MANIFEST after gate and CLOSE writes

## Next

验证 close 的 gate/Doctor/CLOSE 写入边界，完成最终证据刷新后恢复 done，并归档本 progress 文件。
