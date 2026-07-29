# progress — [Task ID: T-052] v6.13.0 .engineignore — 项目级任务卡门禁旁路通道
> Last updated: 2026-07-29 | 任务级压缩恢复锚点 | 7 栏事件驱动更新,见 contract/src/20-file-templates.md FILE 13

## §1 已读文件（理解项目）
- engine/scripts/githooks/pre-commit — 任务卡门禁主逻辑;179-192 无卡 block,194-213 union_allows(WRITE-SET ∧ ∉FORBIDDEN),289-343 protected-path,353-387 dist-stale(T-051)
- engine/decisions/rules.json — protected_paths 数组(10 项),glob 语法同 .gitignore
- engine/decisions/D-035.md — union gating + 逐卡豁免架构(D-029 修订),T-052 复用其 card_meta 结构
- engine/tasks/T-051.md — dist-stale gate 参考卡,格式与 WRITE-SET 模式对齐
- engine/tasks/README.md — 任务卡格式规范、粒度软门禁、verify 反套套三问
- issue #17 — .engineignore feature 提案(D1-D4 设计决议已锁定)

## §2 已确认接口（不重复读）
- union_allows(path) -> 0 iff ∃卡: path∈WRITE-SET ∧ path∉该卡FORBIDDEN (pre-commit L147-159)
- match_any_glob(path, csv) -> 0 iff 任一 glob 命中(case "$path" in $p|$p/*),* 跨 / 故 ** 实际工作 (L83-100)
- is_task_bootstrap_path(path) -> 0 iff engine/tasks/T-*.md | engine/decisions/D-*.md (L31-33,固定语义,不与 .engineignore 合并)
- covering_decision(path) -> 首个覆盖卡的 decision: 字段 (L162-171,protected-path 用)
- git check-ignore --no-index --exclude-from=F --stdin -> 0 输出 ignored 路径,不读 .gitignore

## §3 已排除路径（原 TRAIL 的家）
- 2026-07-29 / 自写简化匹配器(尾/前缀、*单段) / 与 gitignore 语义预期有出入,未来补 **/!会越改越脏 / 采用 git check-ignore(D1 决议)
- 2026-07-29 / issue 原案在 194-213 也 continue / 绕过 FORBIDDEN 违反 issue 自己声明的不绕过保护路径原则 / 采用 union_not_all_forbidden 跳 WRITE-SET 不跳 FORBIDDEN(D3 决议)

## §4 当前进行到（压缩恢复点）
正在做:全部 9 AC 通过 engine verify(9 pass, 0 fail, 0 skip),scripts/check.sh CHECK PASSED
下一步:标记 T-052 status: done,提交

## §5 待确认问题
- (已解决)D-036 随实现一起起草,scope 覆盖 .engineignore + T-052 WRITE-SET

## §6 已知风险/未解 bug
- (已验证)首次提交创建 D-036+.engineignore+rules.json:决策卡 bootstrap 豁免生效(L303 engine/decisions/D-*.md continue),AC-4 测试覆盖通过

## §7 回滚尝试
- (空)
