# T-058 progress — v6.15.0 PS 5.1 乱码根因修复 — .ps1 UTF-8 BOM

> Task: T-058 | Status: done | Lane: engine-runtime

## Timeline

- 2026-07-29: T-057 复查发现 1 个真实 bug(manifest 重复 sha256 字段)+ 5 个证据/文档问题 + 3 个根因风险。用户选"全部 + BOM 评估"。
- 2026-07-29: 子代理 12 维度评估 BOM 方案,结论 Strong GO。23 文件加 BOM,成本约 20 分钟单次提交,对比逐字符清理(859 行,10+ 任务卡)成本优势 2-3 个数量级。
- 2026-07-29: 用户选"BOM + 全部修复"。建 T-058 任务卡。
- 2026-07-29: 给 24 个 .ps1 文件加 BOM(18 个加 BOM,6 个已有)。.sh 全无 BOM(shebang 不破坏)。
- 2026-07-29: 跑 compile.sh 重算 manifest SHA256(62 条目)。发现 P6 根因:不是重复条目,而是同一条目里有两个 sha256 字段(compile.sh backfill 留下旧值)。手动修复。
- 2026-07-29: 修 P4:engine-migrate-contract.ps1 顶部加功能性 § 警告注释(10 行,说明 L304 正则/L355-360 契约块/L375-394 模板中的 § 勿全局替换)。
- 2026-07-29: 修 P5 + 文档错误:.sh § 计数 100(非 113);L375-394 模板写入 skeleton/progress.md(非 CONTEXT.md)。
- 2026-07-29: 版本升到 6.15.0(minor,因为是根因修复/架构级改动)。

## Key Decisions

- **BOM 方案(根因修复)vs 逐字符清理(治标)**:BOM 是 PS 5.1 识别 .ps1 编码的权威信号,一次性消除所有非 ASCII 乱码风险。逐字符清理需 10+ 任务卡,且每加一句中文都要重治。
- **仅 .ps1 加 BOM**:.sh 不能加(破坏 shebang),.md 无需加(无执行风险)。这天然支持"仅 .ps1"边界。
- **不回退 T-056/T-057 的 ASCII 化**:—→- 和 §→S 仍有效,加 BOM 后不再乱码但 ASCII 化有跨 locale 兼容性。回退会增加无谓工作量。
- **T-056/T-057 证据不重跑**:已推送,历史不动。T-058 生成自己的证据。
- **版本 6.15.0(minor)**:BOM 是架构级改动(23 文件 + manifest 重算),值得 minor 版本号而非 patch。
- **P6 根因**:manifest.json 中 engine-migrate-contract.ps1 条目有两个 sha256 字段(compile.sh backfill 留下旧值),JSON 解析器取最后一个导致 mismatch。修复方式:删除重复字段,保留正确值。

## Open Items

- PS 5.1 乱码问题已根因闭环。无已知遗留。
- engine/checks/check-version-consistency.ps1 是纯 ASCII,无 BOM(不影响功能,保持现状)。
- .sh 文件中的 §(100 处)和注释中的 § 仍存在,但 bash 处理 UTF-8 无乱码问题,无需清理。
