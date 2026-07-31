# progress — [Task ID: T-068] v6.20.0 防漂移 P3 — 批量补 code_fingerprint
> Last updated: 2026-07-31 | 任务级压缩恢复锚点 | 7 栏事件驱动更新

## §1 已读文件（理解项目）
- D-038(决策点#8:仅 T-048~T-065,深度历史保留 T2) / T-068.md(8 AC) / T-066.md(多锚 schema) / T-067.md(信任分级) / engine-verify.sh(collect_code_fingerprint+is_engine_metadata)

## §2 已确认接口（不重复读）
- engine-verify.sh:collect_code_fingerprint() 解析 WRITE-SET 排除元数据,git ls-files -s 取 blob sha;engine-doctor.sh:check_progress_md() active 卡须 live progress.md,done 卡须归档

## §3 已排除路径（原 TRAIL 的家）
- 2026-07-30 / 深度历史卡 T-004~T-047 回填 / D-038 决策点#8 明确仅 T-048~T-065,保留 T2

## §4 当前进行到（压缩恢复点）
正在做:T-068 收尾 — AC-1~AC-6 完成(16 卡全回填 code_fingerprint+exempt,T1=16/16=100%);AC-7 check.sh doctor 0 failure,session injection 409>400 已 pause T-069 降到<400;AC-8 VERSION 6.20.0+CHANGELOG 完成
下一步:verify T-068(active,AC-7 PASS) → 改 done+归档 progress.md+commit → resume T-069 → push tag v6.20.0

## §5 待确认问题
- 无

## §6 已知风险/未解 bug
- 老 done 卡 AC verify 命令引用已重构路径 → FAIL → 标 exempt 保留 T2

## §7 回滚尝试
- 无
