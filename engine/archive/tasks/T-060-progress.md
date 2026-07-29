# progress — [Task ID: T-060] v6.16.0 doctor 一致性对齐(#20 + #19)
> Last updated: 2026-07-29 | 任务级压缩恢复锚点 | 7 栏事件驱动更新,见 contract/src/20-file-templates.md FILE 13

## §1 已读文件（理解项目）
- engine/scripts/engine-migrate-contract.sh — managed block 模板 item 17 在 L408(单行 2473 字符)
- engine/scripts/engine-migrate-contract.ps1 — 对应 L368(.ps1 双反引号转义)
- engine/scripts/engine-doctor.sh — check_task_card_done_evidence L1242-1276,FAIL 在 L1271
- engine/scripts/engine-doctor.ps1 — Test-TaskCardDoneEvidence L1235-1271,FAIL 在 L1264
- engine/ENGINE_DOCTOR.md — managed block item 17 是 2473 字符单行,触发 doctor check_long_line WARN

## §2 已确认接口（不重复读）
- migrator managed block 替换:MARK_START/MARK_END 之间整块替换,内部多行安全
- doctor check_long_line:max 2000 字符,扫所有 .md 文件
- doctor check_task_card_done_evidence:不区分 HEAD vs 工作树 done 卡

## §3 已排除路径（原 TRAIL 的家）
- [2026-07-29] / Option B(doctor 豁免 managed block)/ 削弱 doctor 检查力 / Option A(源头拆分)
- [2026-07-29] / Option A1(doctor 无条件降 WARN)/ 削弱新 done 卡约束 / Option A2(HEAD 检查降 WARN)

## §4 当前进行到（压缩恢复点）
正在做:AC-1 + AC-2 代码修改完成,需创建 progress.md + compile.sh + check.sh + 版本 bump
下一步:跑 contract/compile.sh 重算 manifest → check.sh → 版本 bump 6.16.0 → 证据 → commit

## §5 待确认问题
- AGENTS.md / engine/SYSTEM.md 被 migrate 更新(managed block),需确认 diff 是否只是 item 17 拆分传导

## §6 已知风险/未解 bug
- .sh 文件 Set-Content 写入 CRLF + BOM 导致 bash 执行失败,已修复(LF + 无 BOM)

## §7 回滚尝试
- 无
