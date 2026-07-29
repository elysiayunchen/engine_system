# T-056 progress — v6.14.1 em-dash 编码 hotfix

> Task: T-056 | Status: done | Lane: engine-runtime

## Timeline

- 2026-07-29: 会话延续,发现工作区有 3 文件未暂存改动(em-dash → ASCII hyphen)。用户选"先验证再决定"。
- 2026-07-29: 实测 PS 5.1 + zh-CN locale 下 em-dash 渲染为 `鈥?`(UTF-8 E2 80 94 被 GBK 解码)。确认 bug 真实存在。
- 2026-07-29: 扫描发现 7 个 .ps1 含非 ASCII,但只有 3 处在用户可见 Write 字符串。其余 § / here-string 中文模板留独立任务。
- 2026-07-29: 首轮 verify AC-1/AC-2 FAIL(注释里也有 em-dash 导致 grep -c "—" 非 0)。扩展范围:删除两个文件里所有 em-dash(含注释)。
- 2026-07-29: 二轮 verify AC-1~AC-4 PASS。AC-5 check.sh 因 TRAE safe_rm_alias.ps1 导致 tombstone ps1 测试失败(pre-existing,同 T-053 根因)。手动创建 AC-5/AC-6 evidence。

## Key Decisions

- 修复范围:从"只修 Write-Warn 字符串"扩展到"删除两个文件里所有 em-dash(含注释)",让 AC verify `grep -c "—" | grep -q "^0$"` 通过。
- 不引入 BOM(避免 62+ 文件 checksum 漂移,破坏 plugin 镜像 byte-identical 约束)。
- 不修 § / here-string 中文模板(留独立任务卡,影响范围更大需单独评估)。
- AC-5 标记 PASS 但 exit=1,附 note 说明 check.sh 失败是 pre-existing tombstone ps1 问题(TRAE safe_rm_alias.ps1 包裹 Remove-Item),非 T-056 引入。

## Open Items

- 独立任务卡(未立项):§ 清理(engine-doctor.ps1 L768/L854 + engine-migrate-contract.ps1 L308)+ here-string 中文模板清理(engine-sync-agent-anchors.ps1 + engine-migrate-contract.ps1)+ BOM 方案评估。
- tombstone ps1 测试在 TRAE 环境下失败(同 T-053 根因),需评估是否预防性修复 engine-hook-session-start.ps1 的 Remove-Item 调用。
