# progress — [Task ID: T-067] v6.19.0 防漂移 P2 — 状态面板视图化 + 信任分级注入
> Last updated: 2026-07-30 | 任务级压缩恢复锚点 | 7 栏事件驱动更新,见 contract/src/20-file-templates.md FILE 13

## §1 已读文件（理解项目）
- engine/decisions/D-038.md — 防漂移设计 4 层(a 多锚 / b drift-check / c 状态视图 / d 信任分级),本任务覆盖 c/d
- engine/tasks/T-067.md — 10 个 AC 定义(engine-context render_derived_status + 信任标签 + doctor check_derived_status + plugin 镜像 + 测试 + 版本)
- engine/scripts/engine-context.sh — 现有 context 加载逻辑(已新增 render_derived_status + 标签注入)
- engine/scripts/engine-context.ps1 — PowerShell 孪生(已新增 Render-DerivedStatus + 标签注入)
- engine/scripts/engine-doctor.sh — 现有 doctor 检查(已新增 check_derived_status)
- engine/scripts/engine-doctor.ps1 — PowerShell 孪生(已新增 Test-DerivedStatus)
- engine/CONTEXT.md — 状态面板(已加 legacy 标注)

## §2 已确认接口（不重复读）
- engine-context.sh:render_derived_status() — 实时计算 git tag + engine/VERSION + 最近 done 卡 evidence 信任级
- engine-context.sh:信任标签注入 — sed/while 循环按段注入 [T1]/[T2 legacy]/[T2 declared-only]/[T3 unverified]
- engine-context.ps1:Render-DerivedStatus — PowerShell 孪生,语义一致
- engine-doctor.sh:check_derived_status() — 校验 legacy 标注 + tag/VERSION 一致性 + stale panel
- engine-doctor.ps1:Test-DerivedStatus — PowerShell 孪生

## §3 已排除路径（原 TRAIL 的家）
- 2026-07-30 / 最近 done 卡选择 / 取 lexicographic highest T-NNN with status:done / 简单实现,跳号场景留 watchpoint
- 2026-07-30 / verified_against_commit 校验范围 / HEAD 直接匹配 OR ancestor of HEAD / vac 通常是 HEAD~1(evidence 在提交前写入)
- 2026-07-30 / T2 信任级通胀 / 14+ 张 legacy done 卡无 code_fingerprint → T2 legacy-evidence / 留 T-068 批量补 code_fingerprint

## §4 已完成（压缩恢复点）
10 个 AC 全部 PASS:engine-context.sh render_derived_status + 信任标签 / engine-context.ps1 孪生 / CONTEXT.md legacy 标注 / engine-doctor.sh check_derived_status / engine-doctor.ps1 孪生 / plugin 镜像 byte-identical(4 脚本) / test_derived_status.sh 6 场景 9/9 PASS / check.sh PASSED / 版本 6.19.0 + CHANGELOG。

## §5 待确认问题
- 无

## §6 已知风险/未解 bug
- 双写过渡期 v6.19.0~v6.20.0:Doctor 对 derived 不一致只 WARN 不 FAIL,v6.20.0 后须切硬 FAIL
- 最近 done 卡选择取 lexicographic highest,跳号场景可能误判(留 D-038 后续 watchpoint)

## §7 回滚尝试
- 无
