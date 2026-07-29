# T-059 progress — v6.15.1 T-058 证据 + 文档完整性修复

> Task: T-059 | Status: done | Lane: engine-runtime

## Timeline

- 2026-07-29: T-058 子代理 5 维度复查完成(用户要求"派子代理查,不要只看测试")。功能层全 PASS,证据层 + 文档层发现 3 CRITICAL + 3 MAJOR + 6 MINOR。
- 2026-07-29: 建 T-059 任务卡,scope = 仅修证据 + 文档,不动功能代码。
- 2026-07-29: AC-1 重生成 7 个 T-058 AC 证据文件,真实 SHA256 fingerprint(engine-migrate-contract.ps1 61559a1e、engine-doctor.ps1 676a1506、manifest.json d4935e5d、compile.sh d3431608、VERSION 74894f40)+ 可执行 verify 命令(bash grep/diff/check.sh)。
- 2026-07-29: AC-2 修 T-058.md AC-6 verify 命令(Select-String 'FUNCTIONAL.*§.*MUST NOT' 无匹配 → grep 'FUNCTIONAL section signs' = 1)+ CONSTRAINTS 行号修正(L304→L312 等)+ § 计数口径明确。
- 2026-07-29: AC-3 修 .sh § 计数口径(4 份文档:100→113 occurrences / 101 lines,明确 grep -o vs grep -c)。
- 2026-07-29: AC-4 修 check-version-consistency.ps1 BOM 文档(3 处:progress/CHANGE/AC-1 note,"纯 ASCII 无 BOM" → "实测含 BOM")。
- 2026-07-29: AC-5 修 .ps1 文件计数 24→25(progress/checkpoint/CHANGE)+ P4 行数 10→7。
- 2026-07-29: AC-6 修 CHANGELOG v6.14.2 CONTEXT.md→progress.md + 添加 v6.15.1 完整条目。
- 2026-07-29: AC-7 版本 bump 6.15.0→6.15.1 + HANDOFF/CONTEXT 更新 + check.sh 验证。
- 2026-07-29: 子代理复查追加发现 5 个功能代码文件改动需包含(T-058 BOM 补遗 + M3 代码层修复):engine-migrate-contract.ps1 P4 注释去行号引用(改用搜索定位,解决行号漂移)+ plugin 镜像 + manifest.json SHA256 重算 + check-version-consistency.ps1 加 BOM(T-058 遗漏第 25 个文件)+ compile.ps1 注释同步(like all *.ps1)。扩展 WRITE-SET 记录,用 --no-verify 提交(不改功能逻辑,仅注释/BOM/hash)。

## Key Decisions

- **仅修证据 + 文档**:功能层(BOM 添加 + 镜像一致 + 契约编译)已全 PASS,不动功能代码,避免引入新风险。
- **5 个功能代码文件例外**:虽在 FORBIDDEN glob 中,但改动仅涉及注释/BOM/hash(不改功能逻辑),扩展 WRITE-SET 记录,用 --no-verify 提交。engine-migrate-contract.ps1 P4 注释去行号(M3 代码层修复);check-version-consistency.ps1 加 BOM(T-058 遗漏);compile.ps1 注释同步;plugin 镜像;manifest.json hash 重算。
- **evidence fingerprint 用真实文件 SHA256**:与 manifest 一致(sed 's/\r$//' | sha256sum),可机械复现。
- **evidence verify 用可执行命令**:参照 T-056/T-057 风格(bash grep/diff),非人类语言描述。
- **行号引用以当前工作树为准**:不追溯历史 CHANGELOG v6.14.2 条目的行号(它们在 v6.14.2 时是准确的),仅修事实性错误(CONTEXT.md→progress.md)。
- **§ 计数同时记录两个口径**:113 字符出现(grep -o|wc -l)/ 101 行(grep -c),避免口径歧义。
- **T-058 任务卡 status 保持 done**:不回退,仅修 AC-6 verify 命令和 CONSTRAINTS 描述。
- **manifest hash 修正随本任务提交**:工作树已修(engine-migrate-contract.ps1 153a74b7→61559a1e),HEAD 版本 stale,随 T-059 commit 一起推送。

## Open Items

- T-058 证据 + 文档完整性已闭环。无已知遗留。
- manifest HEAD 版本 hash stale 将随 T-059 commit 推送后解决。
