# progress — T-050 v6.12.2 tombstone 生命周期修复
> Last updated: 2026-07-28 | 任务级压缩恢复锚点 | 7 栏事件驱动更新,见 contract/src/20-file-templates.md FILE 13

## §1 已读文件(理解项目)
- 本仓 doctor 实测 FAIL 输出 — `tombstone file is stale (133188s old, >24h)`,内容 `2026-07-26T22:16:57Z|1244|coordinator-exited`(正常退出被误报 abnormal)
- engine/scripts/engine-hook-session-start.sh — coordinator 锁获取三条路径(fresh acquire / same-sid resume / stale-recovery),只有 `engine assume-coordinator` 命令清理 tombstone,hook 路径不清理
- engine/scripts/engine-doctor.sh `check_multi_session_isolation` — tombstone >24h FAIL + 消息含 "exited abnormally",与契约 #17 原文 "triggers WARN" 不一致
- engine/ENGINE_DOCTOR.md #17 Multi-session isolation 段 — 契约源已说 WARN,代码却 FAIL
- engine/scripts/engine-migrate-contract.sh — managed block 模板需同步到 6.12.2 内容
- T-048 v6.12.0 租约液性修复 — lock/hb mtime TTL 120min 是 active 状态源,tombstone 是历史事件日志

## §2 已确认接口(不重复读)
- Stop hook 写 tombstone(`coordinator-exited` / `stale-recovered` / `forced-replaced` 三种 type)
- assume-coordinator 命令清理 tombstone 已有逻辑(参考实现)
- doctor `tombstone_is_fail` cv 阈值切换模式(参考 v6.11.7 CI 降级模式)
- WSLENV 转发 CLAUDE_PROJECT_DIR(WSL→Windows PowerShell 进程不传任意 env var,T-048 先例)

## §3 已排除路径(原 TRAIL 的家)
- 2026-07-28 / stale-recovery 路径 tombstone 写入 / 已正确覆盖旧值,不动 / C-1 明示
- 2026-07-28 / 删除 tombstone 检查本身 / 保留为 WARN 诊断信号,有可观测价值 / CONSTRAINTS 明示

## §4 当前进行到(压缩恢复点)
状态:**done**。verify T-050 = 9 pass / 0 fail / 0 skip。AC-1~AC-5 测试套件 `bash tests/multi-session/test_tombstone_lifecycle.sh` 19 例全 PASS(sh 6 + ps1 3 + Doctor 10);AC-6/AC-7 契约 grep PASS;AC-8 `bash scripts/check.sh` 全绿;AC-9 VERSION 6.12.2 + CHANGELOG grep PASS。
实现要点:A-1/A-2 SessionStart hook 在 fresh coordinator + same-sid resume 两条路径加 `rm -f .cache/session.tombstone`(对称 Stop hook 写入);B-1 doctor `tombstone_is_fail` 变量(cv ∈ [6.11.0, 6.12.2) 保持旧 FAIL,cv ≥ 6.12.2 WARN);B-2 消息删 "exited abnormally" 改 "historical transition record";C-1 契约 #17 重写;C-2 contract-version 升 6.12.2;migrator sh/ps1 镜像同步;AGENT_ADAPTERS + ENGINE_FILE_SYSTEM_v5 文档同步;plugin 全镜像 byte-identical。

## §5 待确认问题
- (无)

## §6 已知风险/未解 bug
- **Doctor 降级 FAIL→WARN 的诊断信号减弱**:cv ≥ 6.12.2 项目 >24h tombstone 不再阻塞 Doctor。但 tombstone 本就不是 active 状态信号——真正的 active 状态问题由 lock file + lease mtime 检查(已有,FAIL 级)覆盖
- **SessionStart 清理 tombstone 掩盖 Stop hook 故障**:如果 Stop hook 异常退出不写 tombstone,SessionStart 清理路径不会发现「上次没写」。但这本就是 tombstone 的设计——它不是必须存在的事件日志,缺失不构成问题
- .ps1 改动遵守 P008(BOM)/T-047(字面量 ASCII)

## §7 回滚尝试
- (无)
