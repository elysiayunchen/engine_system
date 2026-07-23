# progress — [Task ID: T-046] 修复 install.sh/install.ps1 与 plugin/manifest.json src 列表不一致
> Last updated: 2026-07-23 | 任务级压缩恢复锚点 | 7 栏事件驱动更新,见 contract/src/20-file-templates.md FILE 13

## §1 已读文件（理解项目）
- install.sh L150-165, L255-268 — case 语句 skeleton 重映射逻辑 + FILES 数组（3 条 skeleton 条目）
- install.ps1 L130-150, L220-235 — 同上的 PowerShell 版本，case 语句 L140 + 数组 L224-228
- scripts/check.ps1 L141-155 — manifest vs install.sh/ps1 src 列表 Compare-Object 检查（正则 `@\{ src = "([^"]+)";\s+dest = "([^"]+)"`）
- plugin/manifest.json — 61 条 src，其中 7 条 engine/skeleton/*（3 重映射 + 4 dest=src）
- engine/tasks/T-045.md — T-045 FORBIDDEN 明确列 install.sh/ps1，须开 T-046

## §4 当前进行到（压缩恢复点）
正在做:T-046 五项 AC 全部完成 — install.sh/ps1 各加 4 条 skeleton 条目 + 修 case 语句 blanket 重映射 bug；manifest src 列表 61=61 MATCH。
下一步:跑 engine verify T-046 生成 evidence + 收尾文档 + 与 T-045 一起 commit/push。
