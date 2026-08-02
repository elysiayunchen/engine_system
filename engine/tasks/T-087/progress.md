# progress — T-087 生命周期分发与任务卡解析一致性

> Last updated: 2026-08-02 | 任务级压缩恢复锚点

## §1 已读文件（理解项目）
- `engine/tasks/T-087.md` — 任务目标、WRITE-SET、AC 与约束。
- `engine/ENGINE_MAP.md` — 引擎入口与路径路由索引。

## §2 已确认接口（不重复读）
- `engine context` — 读取当前共享上下文与 active task。
- `engine verify/gate/close T-087` — T-087 生命周期验收入口。

## §3 已排除路径（原 TRAIL 的家）
- 2026-08-02 / 未修改契约源、review-agent 脚本或共享 CONTEXT/HANDOFF；相关并行会话已有 coordinator lease。

## §4 当前进行到（压缩恢复点）
已完成: 新增 `engine-task-card.{sh,ps1}`，并让 verify/gate/review/close/Doctor/hook/pre-commit 复用统一解析；install、plugin manifest、root/plugin 镜像与 issue 回归测试已同步。
已完成: `engine close` 纳入 install 分发；section AC 由 gate 正确计数；docs-only 任务在 gate/Doctor 跳过代码 review；inline/frontmatter/section WRITE-SET 均可用。
验证: issue #30 专项 33/33；生命周期 Bash 32/32；生命周期 PowerShell 17/17；Doctor review evidence 9/9；issue regressions Bash/PowerShell 通过；相关 sh/ps1 语法通过。
正式验证: `engine-verify.ps1 -Task T-087 -NoCov` 已生成 AC-1~AC-5 全部 PASS 证据（5/5，code_fingerprint/write_set_snapshot 各 34 项）；外层命令在收尾死代码扫描阶段达到 180s 超时，但 AC 证据均为 PASS。
下一步: coordinator 在 merge point 重读本分片并收口共享记忆。

## §5 待确认问题
- 全仓 `scripts/check.sh` 仍受工作区既有 Doctor inventory/evidence、CRLF/WSL 与多 session fixture 状态影响；不属于 issue #30 逻辑回归。

## §6 已知风险/未解 bug
- 正式验证已完成 AC 级 PASS；全仓 `scripts/check.sh` 仍受工作区既有 Doctor inventory/evidence、CRLF/WSL 与多 session fixture 状态影响。

## §7 回滚尝试
- 无；修改均限制在 T-087 WRITE-SET，root/plugin 运行时脚本保持逐字节镜像。
