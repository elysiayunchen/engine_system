# T-081 Progress

> status: active | owner: coordinator-codex | updated: 2026-08-01

## Goal

收口 Engine Doctor 全仓失败与 Windows/WSL 跨 shell 生命周期缺口。

## Checkpoint

- [x] AC-1 ENGINE_MAP registry and Doctor root-path resolution
- [x] AC-2 progress anchors and T-078 archive
- [x] AC-3 domain INVENTORY coverage
- [x] AC-4 Bash verify PowerShell resolution
- [x] AC-5 historical evidence integrity (valid historical snapshots now warn; tamper remains hard-fail)
- [ ] AC-6 T-078 lifecycle evidence
- [ ] AC-7 full Doctor zero failures

## Next

注册表/路径、progress 锚点、域 INVENTORY 与 Bash PowerShell 解析已修复并通过静态回归；下一步重验历史 evidence、完成 T-078 生命周期并运行完整 Doctor。
