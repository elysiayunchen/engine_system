# progress — [Task ID: T-033] [域级 INVENTORY.md 功能索引 + 双向 FAIL 检查 + v6.8.0 发布]
> Last updated: 2026-07-19 | 任务级压缩恢复锚点 | 7 栏事件驱动更新,见 contract/src/20-file-templates.md FILE 13

## §1 已读文件（理解项目）
- contract/src/20-file-templates.md — FILE 14 INVENTORY.md 模板定义处
- engine/scripts/engine-doctor.sh — check_inventory_bidirectional + check_inventory_api_uniqueness 实现
- engine/scripts/engine-migrate-contract.sh — #13/#14 + INVENTORY stub 创建逻辑
- engine/ENGINE_DOCTOR.md — #13/#14 规则 + contract-version 6.8.0
- engine/domains/engine-runtime/INVENTORY.md — dogfood 自检域
- engine/domains/project-meta/INVENTORY.md — dogfood 自检域

## §2 已确认接口（不重复读）
- check_inventory_bidirectional() — INVENTORY→code test -f + code→INVENTORY done WRITE-SET 检查
- check_inventory_api_uniqueness() — 全仓 Public API 列唯一性扫描
- upsert_block() — migrator 幂等写入 managed block

## §3 已排除路径（原 TRAIL 的家）
- 2026-07-19 / 用 AST 解析器做符号定位 / 违反 CLI-LEAN + INVENTORY 只写语义层 / 交 ast-grep 现生
- 2026-07-19 / INVENTORY 进 SessionStart 全文注入 / 域仪表盘膨胀 / 只首行摘要进仪表盘
- 2026-07-19 / code→INVENTORY 检查走 federation.json 全路径映射 / dogfood 简化足够 + 完整映射是 federation.json 职责 / 只看 done 任务 WRITE-SET 具体路径

## §4 当前进行到（压缩恢复点）
正在做:T-033 11 个 AC 全部完成,准备跑 release.sh 6.8.0 发版
下一步:release.sh 6.8.0 → push tag → 开干 T-034/T-035

## §5 待确认问题
- 无 / 阻塞:无 / 提出:无

## §6 已知风险/未解 bug
- bash `[[ =~ ^<!-- ]]` 正则 syntax error / 影响:doctor 崩溃 / 缓解:改为 `== "<!--"*` glob(已修复)
- `set -euo pipefail` + `grep|head|sed` 管道无匹配触发 ERR trap / 影响:doctor 提前 exit / 缓解:加 `|| true`(已修复)

## §7 回滚尝试
- 无
