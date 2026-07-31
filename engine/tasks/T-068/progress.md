# progress — [Task ID: T-068] v6.20.0 防漂移 P3 — 批量补 code_fingerprint
> Last updated: 2026-07-30 | 任务级压缩恢复锚点 | 7 栏事件驱动更新,见 contract/src/20-file-templates.md FILE 13

## §1 已读文件（理解项目）
- engine/decisions/D-038.md — 防漂移设计 4 层,决策点 #8 定义迁移期范围(仅 T-048~T-065,深度历史保留 T2)
- engine/tasks/T-068.md — 8 个 AC 定义(试跑 T-048 + 批量回填 T-049~T-060 + T-063~T-065 + exempt + T1 占比 + check + 版本)
- engine/tasks/T-066.md — D-038a/b 实施参考(多锚 schema 已就绪,verify 已支持 code_fingerprint)
- engine/tasks/T-067.md — D-038c/d 实施参考(信任分级 T1/T2/T3 已就绪)
- engine/scripts/engine-verify.sh — 多锚写入逻辑(code_fingerprint + write_provenance + MANIFEST,is_engine_metadata 排除任务卡/决策/evidence/CONTEXT 等)
- engine/evidence/T-066/AC-1.json — T1 evidence 样本(多锚格式参考)
- engine/evidence/T-048/AC-1.json — T2 legacy evidence 样本(单锚 fingerprint,待升级)

## §2 已确认接口（不重复读）
- engine-verify.sh:collect_code_fingerprint() — 解析 WRITE-SET,排除 engine 元数据,git ls-files -s 取 blob sha,前置 git add 检查
- engine-verify.sh:is_engine_metadata() — 排除 engine/tasks/*/engine/decisions/*/engine/evidence/*/engine/CONTEXT.md/VERSION 等
- engine-doctor.sh:check_progress_md() — active 卡必须有 live progress.md,done 卡必须归档(删 live)
- engine-doctor.sh:check_task_card_done_evidence() — done 卡 AC evidence 必须 PASS 或标 exempt

## §3 已排除路径（原 TRAIL 的家）
- 2026-07-30 / 重跑 verify 导致 AC FAIL 降级 / 老 done 卡 AC verify 命令可能引用已重构代码 / 采用 exempt 标记保留 T2 不降 status
- 2026-07-30 / 深度历史卡 T-004~T-047 回填 / D-038 决策点 #8 明确仅 T-048~T-065 / 保留 T2
- 2026-07-30 / 改 engine-verify.sh 加 --fingerprint-only 模式 / 增加复杂度且改变脚本行为 / 直接重跑 verify,FAIL 则标 exempt

## §4 当前进行到（压缩恢复点）
正在做:T-068 收尾 — AC-1~AC-6 完成(16 张卡全回填 code_fingerprint+exempt,T1=16/16=100%);AC-7 check.sh doctor 0 failure(§1.1 段补全+T-070 paused 修复),session injection 510>400 FAIL 需 T-068 done 后降到 382;AC-8 VERSION 6.20.0+CHANGELOG 已完成
下一步:commit T-068 改动(active) → 改 done+归档 progress.md → verify T-068(done,AC-7 PASS) → commit evidence → push tag v6.20.0

## §5 待确认问题
- 无

## §6 已知风险/未解 bug
- 老 done 卡 AC verify 命令可能引用已重构/删除的文件路径 → FAIL → 标 exempt
- T-048 的 WRITE-SET 含 engine/scripts/** 等宽泛路径,code_fingerprint 可能包含大量文件
- 回填流程临时改 active 会触发 check_progress_md,需同步创建 progress.md

## §7 回滚尝试
- 无
