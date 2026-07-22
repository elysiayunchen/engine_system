# progress — [Task ID: T-036] 多会话锁 + worker 自动降级 + PreToolUse 双信号 + v6.11.0 发布
> Last updated: 2026-07-20 | 任务级压缩恢复锚点 | 7 栏事件驱动更新,见 contract/src/20-file-templates.md FILE 13

## §1 已读文件（理解项目）
- engine/scripts/engine-hook-session-start.{sh,ps1} — SessionStart hook,已加 lock 检测 + 协调者/worker 分配(P2+P3 修复)
- engine/scripts/engine-hook-stop.{sh,ps1} — Stop hook,AC-3 加 .meta + lock release + tombstone
- engine/scripts/githooks/pre-commit — protected_paths + strict_task_mode + done 门禁
- engine/decisions/rules.json — protected_paths 列表
- engine/decisions/D-029.md — approved 多会话隔离决策
- engine/decisions/D-031.md — approved T-037 元决策卡(protected_paths 背书)

## §2 已确认接口（不重复读）
- safe_id(s) -> str — Stop hook 用 `tr -c 'A-Za-z0-9._-' '_'`,SessionStart worker_key 同算法(P2 统一)
- lock file 格式 — `<pid>|<session_id>|<role>|<started_at_iso>|<task_id>`(单行 pipe-separated)
- atomic 独占 — .sh `( set -C; printf ... > "$LOCK" )` / .ps1 `FileStream(FileMode.CreateNew, FileShare.None)`(P3 修复)
- .meta 格式 — `<role>|<stopped_at>|<task_id>`(AC-3 新增)
- tombstone 格式 — `<stopped_at>|<lock_pid>|coordinator-exited`(AC-3 新增)

## §3 已排除路径（原 TRAIL 的家）
- 2026-07-20 / 双信号用 AND 关系 / agent_id 为空时 worker 不被拦截 / 改用 OR 关系(`agent_id` 非空 OR `.role=worker` 文件存在)
- 2026-07-20 / atomic 用 mkdir 独占目录 / 跨平台不一致 / 改用 noclobber + FileStream
- 2026-07-20 / lock 用 pid 单信号 / pid 可能被复用 / 加 StartTime 双信号(AC-1 契约已加)

## §4 当前进行到（压缩恢复点）
正在做:AC-3 Stop hook .meta + lock release + tombstone(4 份)已实现 + verify grep PASS
下一步:AC-4 PreToolUse 双信号扩展(agent_id OR .role=worker)

## §5 待确认问题
- v6.10.1 done-without-evidence 修改被 stash(git stash push -m "v6.10.1..."),待 T-036 完成后开 T-038 任务卡处理 / 阻塞:无 / 提出:2026-07-20
- Stop hook safe_id 未加 cut -c1-64(P2 修复的延续,session_id > 64 字符时会与 worker_key 不匹配) / 阻塞:无 / 提出:2026-07-20

## §6 已知风险/未解 bug
- check.sh FAIL 因 contract budget 2892 > 2830(超 62 行) / 影响:AC-14/AC-16 verify FAIL / 缓解:后期 AC 完成时压缩契约源或提升基线
- check.sh FAIL 因 T-036 progress.md 缺失(本提交已创建) / 影响:AC-14/AC-16 verify / 缓解:已修复
- HANDOFF.md 有 2020 字符超长行 / 影响:Doctor WARN / 缓解:后期压缩

## §7 回滚尝试
- (无)
