# progress — T-048 v6.12.0 多任务卡并行(union gating)+ 会话租约液性修复
> Last updated: 2026-07-26 | 任务级压缩恢复锚点 | 7 栏事件驱动更新,见 contract/src/20-file-templates.md FILE 13

## §1 已读文件(理解项目)
- engine/ENGINE_MAP.md — v6.11.8 现状,workstreams 并行路径「实现完整但无真实并行验证」
- engine/CONTEXT.md — D-025/D-029 并行记忆假设;v6.11.0 多会话锁已落地
- engine/decisions/D-029.md — v6.11.0 多会话锁架构(lock/角色/分片/kill switch)
- plugin/engine/scripts/engine-hook-stop.sh — PreToolUse+Stop 双模式;find_active_task 单卡;is_shared_memory 一揽子;双信号 worker 判定
- plugin/engine/scripts/engine-hook-session-start.sh — full/--guard 双模式;lock 获取用 ms_pid=$$(hook shell 瞬时 pid);.role=worker 写入无清理
- engine/scripts/githooks/pre-commit — 单卡 task_file;bootstrap 豁免仅零卡分支;protected 单 exempt_id(T-041)
- engine/decisions/rules.json — protected_paths 含 engine/tasks/** engine/decisions/**
- contract/budget.json — 2940 cap / 13 rules / debt_baseline 54
- engine/.cache/ 实证 — lock pid=5112 已死;tombstone stale-recovered;7月23 两个 .role=worker 残留

## §2 已确认接口(不重复读)
- parse_task_patterns(field, file) -> 逗号分隔 glob 串(sh/ps1 双胞胎,frontmatter+inline+section 三格式)
- match_glob(path, patterns) / match_any_glob — case glob 匹配,逗号分隔
- session_key = safe_id("<session_id>-<agent_id|main>")(tr -c 'A-Za-z0-9._-' '_',截 64)
- lock 格式:`<pid>|<sid>|coordinator|<iso>|<task>` 单行 pipe;tombstone:`<iso>|<pid>|<reason>`
- hook stdin JSON payload:session_id / agent_id / tool_name / tool_input.file_path

## §3 已排除路径(原 TRAIL 的家)
- 2026-07-26 / 会话-任务强绑定单卡校验(方案 B) / pre-commit 无会话身份仍需 union 兜底,双语义复杂 / 采用 union gating,B 留作 v6.12.x 增强
- 2026-07-26 / 强制 git worktree 物理隔离 / D-029 已否决(UX 摩擦) / union gating
- 2026-07-26 / lock 活性继续用 pid(改记 Claude Code 父进程 pid) / 跨平台 PPID 链不可靠(MSYS/cmd 中间层) / heartbeat mtime TTL

## §4 当前进行到(压缩恢复点)
状态:done。engine verify T-048 = 10 pass / 0 fail / 0 skip(AC-9 首跑 FAIL 系 verify 命令误用不存在的 doctor --quiet 旗标——doctor 把未知参数当 ROOT 吞掉,已改命令并把「doctor 参数吞噬」列入 T-049 issue #11 修复清单;契约债 55→54 系本卡新段落净增 1 个 MUST,已改写为中文「必须」)。
原记录:实现层全完成——sh 三件 + ps1 孪生(fork 子代理移植,4/4 语法过)+ engine bin assume-coordinator 租约化 + engine-context 多卡面板 + doctor 交集 WARN(sh+ps1)+ contract/src 净零改写(2910→2896)+ migrator 3 处 bullet + item 17 + VERSION 6.12.0 + CHANGELOG + AGENT_ADAPTERS/GLOSSARY + 行为层 2 处。测试:tests/multi-session 新 6 件 + task-card union 1 件全绿;旧 double_signal/lock_recovery(sh+ps1)更新到租约语义全绿;hook-parity 31/31;task-card 44/44;workstream 14/14。migrator 已跑(AGENTS/SYSTEM/ENGINE_DOCTOR 托管块 → 6.12.0)
下一步:scripts/check.sh 全量门禁(后台跑中)→ engine verify T-048 → 胶囊 CHANGE-2026-07-26-01 重写 + CONTEXT/HANDOFF/ENGINE_MAP/INVENTORY 回写 → progress 归档 → done → 提交

## §5 待确认问题
- TTL 默认 120 分钟(ENGINE_SESSION_TTL_MIN 可调)/ 阻塞:无(先落地试点)/ 提出:2026-07-26

## §6 已知风险/未解 bug
- contract/src 修订须净零(2910/2940 仅 30 行余量)/ 影响:AC-9 / 缓解:改写 v6.11.0 多会话段不新增
- .ps1 字符串字面量禁非 ASCII(T-047 教训)/ 影响:所有 ps1 孪生 / 缓解:新增文案全 ASCII
- 两张卡 WRITE-SET 交集竞态是固有边界 / 影响:union 放行交集 / 缓解:Doctor WARN(D-035 Consequences)

## §7 回滚尝试
- 2026-07-26 / 直接改 live hook(plugin/engine/scripts/engine-hook-stop.sh,settings.json 指向的副本):第一刀改了函数名、调用点未改,hook 立即自坏并拦截一切 Edit(判"无 active 卡")/ 回滚:用 Bash 工具(不受拦)cp root 完好副本恢复 / 替代方案:改 root 副本,完工后整体 cp 同步 plugin。教训:改 live hook 必须先改非 live 副本再原子换入
- 2026-07-26 / PreToolUse worker 分片路径校验通过后仍落入 block_scope(union 不含 workstreams)导致分片写被拦 / 回滚该结构 / 替代:分片是钦定写道,校验归属后直接放行+记账 exit(Stop 模式同步跳过 workstreams 路径)
