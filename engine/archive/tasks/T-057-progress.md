# T-057 progress — v6.14.2 § 编码 hotfix

> Task: T-057 | Status: done | Lane: engine-runtime

## Timeline

- 2026-07-29: 承接 T-056 v6.14.1,用户选 "§ symbol cleanup" 作为下一项。
- 2026-07-29: 验证 § 渲染:`tmp_section_test.ps1` 实测 PS 5.1 + zh-CN 下输出 `搂1 and 搂2`(UTF-8 字节 `C2 A7` 被 GBK 解码为 `搂`)。确认 bug 真实存在。
- 2026-07-29: 扫描 § 分布:.ps1 4 文件 56 处(engine-doctor.ps1 9 + engine-migrate-contract.ps1 19 + plugin 镜像 ×2);.sh 9 文件 113 处。
- 2026-07-29: 关键发现 — engine-migrate-contract.ps1 中 17 处 § 是功能性的(L304 正则 `'## .*§2'` 匹配 ENGINE_MAP.md + L375-394 here-string 模板 `## §1 已读文件` 重生成 CONTEXT.md)。直接替换会破坏契约迁移。
- 2026-07-29: 用户选 "中:仅可见字符串" 范围。只清理 3 处用户可见 Write-Output/Write-Host 字符串中的 §,功能性 § 保留。
- 2026-07-29: 替换 § → ASCII `S`(engine-doctor.ps1 L768/L854 `(D-028 §9)` → `(D-028 S9)` + engine-migrate-contract.ps1 L308 `ENGINE_MAP §2` → `ENGINE_MAP S2`)。
- 2026-07-29: plugin 镜像 SHA256 byte-identical,manifest 已更新。check.sh CHECK PASSED。

## Key Decisions

- 修复范围:从"全部 §"收窄到"仅用户可见 Write-Output/Write-Host 字符串"(3 处)。功能性 §(正则 + here-string 模板)保留,避免破坏契约迁移。
- 替换字符:`§` → `S`(如 `D-028 §9` → `D-028 S9`),ASCII 单字符,简洁,保留 "section" 语义。
- 不改注释里的 §(非用户可见,留独立任务)。
- 不改 .sh 文件中的 §(bash 处理 UTF-8 无乱码问题)。
- 不引入 BOM(沿用 T-056 决策,避免 62+ 文件 checksum 漂移)。

## Open Items

- 独立任务卡(未立项):注释里的 § 清理(engine-doctor.ps1 7 处 + engine-migrate-contract.ps1 1 处 + .sh 文件 113 处)。
- 独立任务卡(未立项):here-string 中文模板清理(engine-sync-agent-anchors.ps1 + engine-migrate-contract.ps1 L375-394)。
- tombstone ps1 测试在 TRAE 环境下失败(同 T-053/T-056 根因,TRAE safe_rm_alias.ps1 包裹 Remove-Item),需评估是否预防性修复 engine-hook-session-start.ps1。
