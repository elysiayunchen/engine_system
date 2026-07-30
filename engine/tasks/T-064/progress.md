# progress — [Task ID: T-064] CI/Doctor 三项修复
> Last updated: 2026-07-30 | 任务级压缩恢复锚点 | 7 栏事件驱动更新

## §1 已读文件（理解项目）
- engine/scripts/engine-doctor.sh — check_long_line 在 line 411 用 awk 计数,Windows Git Bash C locale 下按字节计数
- engine/scripts/engine-doctor.ps1 — PowerShell 版用 Get-Content -Encoding UTF8 | Measure-Object,正确按字符计数
- plugin/engine/skeleton/ENGINE_MAP.md — 空模板,§0/§1 均无内容,install 后 doctor 6 FAIL
- engine/checks/check-version-consistency.sh — git 模式 100644,Linux CI 报 not executable WARN
- install.sh — FILES 数组列出 skeleton/ENGINE_MAP.md → engine/ENGINE_MAP.md 映射
- engine/scripts/engine-migrate-contract.sh — migrator 创建 SYSTEM.md + GLOSSARY.md,upsert managed block

## §2 已确认接口（不重复读）
- doctor check_long_line: awk '{ if (length > max) max = length }' → 改为 perl -CSD -ne
- doctor run_custom_checks: [ ! -x "$script" ] → 需要 100755 模式
- doctor check_disk_to_registry: find engine/ -maxdepth 1 -name '*.md' → 检查 §1 注册

## §3 已排除路径（原 TRAIL 的家）
- 2026-07-30 / 不改 PowerShell doctor / 已正确计数,无需改 / 仅改 bash doctor
- 2026-07-30 / 不改 contract/src / 契约无 long line 检查规范变更 / 仅改实现

## §4 当前进行到（压缩恢复点）
正在做:T-064 3 项修复完成,验证 doctor
下一步:跑 migrator 更新 contract-version stamp → 验证 0 failure → 提交 + push + tag v6.17.3

## §5 待确认问题
- T-061 与 T-064 WRITE-SET 重叠(engine-doctor.sh/VERSION/manifest) / 阻塞:无 / 提出:2026-07-30
  - T-061 是前一会话未提交的进行中工作,T-064 在其基础上继续修改 engine-doctor.sh
  - 提交 T-064 时需一并提交 T-061 的未提交改动,或先提交 T-061

## §6 已知风险/未解 bug
- 无

## §7 回滚尝试
- 无
