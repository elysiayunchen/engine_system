# progress — [Task ID: T-066] v6.18.0 防漂移 P1 — 证据多锚 + drift-check
> Last updated: 2026-07-30 | 任务级压缩恢复锚点 | 7 栏事件驱动更新,见 contract/src/20-file-templates.md FILE 13

## §1 已读文件（理解项目）
- engine/decisions/D-038.md — 防漂移设计 4 层（a 多锚 / b drift-check / c 状态视图 / d 信任分级）
- engine/tasks/T-066.md — 12 个 AC 定义（rules/verify/drift-check/pre-commit/doctor/plugin/测试/版本）
- engine/scripts/engine-verify.sh — 现有 verify 实现 + 多锚写入函数（已升级）
- engine/scripts/engine-drift-check.sh — 新建脚本（三步顺序校验）
- engine/scripts/githooks/pre-commit — 现有 AC PASS 检查（已追加 provenance gate）

## §2 已确认接口（不重复读）
- engine-verify.sh:write_evidence_manifest(ev_dir, commit) — 写 MANIFEST.json 聚合 hash
- engine-drift-check.sh:三步顺序（manifest自证→WRITE-SET二阶→代码指纹）— 任一 FAIL 仍输出后续摘要
- pre-commit L408-444: provenance 双路径（机器写入 + manual-edit 标注）

## §3 已排除路径（原 TRAIL 的家）
- 2026-07-30 / git hash-object / 对未 staged 文件算原始字节含 CRLF / 改用 git ls-files -s
- 2026-07-30 / cut+sed 解析 JSON pair / 单条目 JSON 末尾留 } 导致假 DRIFT / 改用 awk -F'"'
- 2026-07-30 / MANIFEST 缺失直接 FAIL / 49 个 legacy 卡全部误报 / 加 legacy_evidence 分支（无 write_provenance → WARN 跳过）

## §4 已完成（压缩恢复点）
12 个 AC 全部 PASS:rules.json protected_paths / engine-verify.{sh,ps1} 多锚+MANIFEST / engine-drift-check.{sh,ps1} 三步校验 / pre-commit provenance gate / doctor 集成 / plugin 镜像 byte-identical / drift-check 5 场景测试 / provenance 6 场景测试 / check.sh PASSED / 版本 6.18.0 + CHANGELOG。

## §5 待确认问题
- 无

## §6 已知风险/未解 bug
- 无（AC-4 verify 命令 grep 'git ls-files -s' 不匹配 .ps1 的 'git -C $Root ls-files -s'，已改为 grep 'ls-files -s'）

## §7 回滚尝试
- 无
