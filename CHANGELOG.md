# Changelog

## v6.11.6 (2026-07-23)

- 修复 GitHub issue #10 P037 — pre-commit legacy fallback 移除(T-044 patch,D-032 approved):无 active/closing 卡 + strict_task_mode=0(< 6.5)时拿 lex-largest done 卡当 governing 卡,导致历史 done 卡误管新 commit。done 卡是冷历史,不应 govern。
- AC-1 移除 pre-commit L111-116 legacy fallback 块(`if [ -z "$task_file" ] && [ "$strict_task_mode" -eq 0 ]` + 内部 `ls -1 T-*.md | sort -r` 扫 done 卡)。strict_task_mode=0 项目无 active 卡时改为 fail-open(跳过 task-card governance)。
- AC-2 strict_task_mode=0 无 active/closing 卡 → fail-open(pre-commit 不再拿 done 卡,task_file 空 → 跳过 WRITE-SET/FORBIDDEN 检查;protected_paths 检查仍执行,需 decision 覆盖)。
- AC-3 plugin 镜像 `git diff --no-index` 一致。
- AC-4 测试 `tests/workstream/test_precommit_no_legacy_fallback.sh` 覆盖 4 场景:无 active+旧项目放行 / 无 active+新项目 block / 有 active 正常 governing / 源码 fallback 模式清除,8/8 PASS。
- AC-5 完整发布门禁 `bash scripts/check.sh` 全绿;task-card gate 更新 C6/C7 测试反映新行为(done 卡不 govern → protected 文件无 task_decision → block)。
- 行为变化:旧项目(< 6.5)无 active 卡时 protected 文件 commit 会 block(原 fallback 用 done 卡的 decision 覆盖,现在 task_decision 空)。缓解:旧项目升级到 6.5+ 用 strict 模式,或建 active 卡。
- D-032 scope 扩展加 T-044 完整 WRITE-SET(含 plugin/manifest.json,pre-commit 改动触发 SHA256)。
- 详见 `engine/changes/CHANGE-2026-07-23-03.md` 与 D-032。

## v6.11.5 (2026-07-23)

- 修复 GitHub issue #10 P038 — pre-commit `parse_task_patterns` 不支持 YAML frontmatter 多行 `write-set:` 格式(T-043 patch):用该格式的任务卡被误报「no readable WRITE-SET」拦截非相关 commit。两个解析分支(inline grep L37-41 + awk markdown L42-55)都不识别 YAML frontmatter `field:` 缩进列表。
- AC-1 awk 分支扩展:新增 `in_frontmatter_block` 边界状态(`^---$` 开闭切换)+ `in_frontmatter_field` 字段头匹配(`^field:$` 缩进 `- ` 列表项收集),与现有 markdown `## field` section 分支并存。
- AC-2 case 敏感性修复:awk 内 `tolower` 比较,大写 `WRITE-SET` 调用能匹配小写 `write-set:` frontmatter 字段(原 inline grep `^${_field}:` case-sensitive 漏匹配)。
- AC-3 frontmatter 边界检测:awk 限定 YAML frontmatter 字段匹配在 `^---$` 之间,避免 markdown body 误匹配 `field:` 行。
- AC-4 plugin 镜像 `git diff --no-index` 一致。
- AC-5 测试 `tests/workstream/test_precommit_yaml_frontmatter.sh` 覆盖 7 场景(YAML 多行 / markdown section / inline 单行 / 大小写混合 ×2 / frontmatter 边界 body decoy / 无 frontmatter body decoy),7/7 PASS。
- AC-6 完整发布门禁 `bash scripts/check.sh` 全绿。
- 不改 P037 legacy fallback(L89-94,留 T-044/D-032);不改 protected_paths / worker mode / memory-written / done evidence 检查。
- 详见 `engine/changes/CHANGE-2026-07-23-02.md`。

## v6.11.4 (2026-07-23)

- 修复 GitHub issue #9 — LF-only engine.ps1 PowerShell 5.1 解析失败(T-042 patch):installer 产出 LF-only `engine.ps1`,PS 5.1 解析 here-string 时行号错位导致 `Unexpected token '}'` 报错,`engine.cmd` shim 在仅有 PS 5.1 的 Windows 系统上完全不可用。方案 A+B 双保险(D-030 批准)。
- AC-1 `install.ps1` 加 `Convert-ToCrlf` 辅助函数(L100-120):`Download-File` 下载 `.ps1` 后将 LF 转 CRLF 写盘(PS 5.1 需要 CRLF 正确解析 here-string)。仓库源保持 LF(`.gitattributes` 钉 `*.ps1 text eol=lf`,D-015 跨平台策略);用户机器侧转 CRLF。checksum 兼容:`Get-NormalizedTextSha256`(L83-98)strip CRLF→LF 再算 hash,与 manifest(LF)一致。
- AC-2 `install.ps1` `Copy-Local`(-Local 离线包)复制 `.ps1` 后同样转 CRLF(L73)。
- AC-3 三个 `engine.cmd`(engine/bin + plugin/bin + plugin/engine/bin)改 pwsh 优先检测:`where pwsh` 找到则用 PS 7,否则回退 PS 5.1。PS 7 解析 LF-only here-string 正确,兜底 git clone 场景(方案 A 仅覆盖 install.ps1 路径)。
- AC-4 plugin 镜像对称:三个 engine.cmd `Get-FileHash` 一致。
- AC-5 版本三处一致 = 6.11.4 + CHANGELOG + manifest SHA256 更新(`bin/engine.cmd`: c2c9ce... → b618a2...)。
- AC-6 完整发布门禁 `bash scripts/check.sh` 全绿。
- 字节级根因分析:install.ps1 自身也是 LF-only(LF=464)且有 1 个 here-string(L264)却能跑完整个安装,证明 PS 5.1 对 LF-only here-string 解析 bug 是累积性行号错位(here-string 数量+首现位置决定何时炸),非 here-string 本身禁用。engine.ps1 有 3 个 here-string 首个在 L20,累积错位导致 183/268 报错。方案 A 转 CRLF 根治,方案 B pwsh 优先兜底。
- 详见 `engine/changes/CHANGE-2026-07-23-01.md` 与 D-030。

## v6.11.3 (2026-07-22)

- 小任务 progress.md 7 栏豁免条款(T-040 patch):T-039 归档 progress.md 实际写成 4 栏自创格式(§1 Goal / §2 Current Step / §3 Done / §4 Next AC),暴露契约对小任务过度强制——强制产出空栏噪声淹没信号,反而违反 D-028 §6「机制错配」原则。本 patch 把"小任务确实不需要 7 栏事件驱动"正式化为契约条款,避免契约与实际再次漂移。
- AC-1 契约源 `contract/src/20-file-templates.md` FILE 13 加「小任务豁免（v6.11.3 / T-040）」子段(放在「禁止」段后、「生命周期规则」段前):条件 `estimated_steps ≤ 10` 且 `checkpoint_plan = inline`(`tryout` 不算豁免,因为 tryout 卡可能复杂)时,7 栏骨架不变但事件驱动更新触发点降级为仅 §1(已读文件)+ §4(当前进行到 / 压缩恢复点)必填;§2/§3/§5/§6/§7 可留空或写单行 `n/a (small task exempt)` 占位;豁免理由 + 边界(不适用于非 inline 任务)+ Doctor 不增减检查逻辑(由 agent 自觉 + 契约文本约束)。
- AC-2 `contract/src/behaviors/task-run.md` 在「Task progress.md event-driven update」段末加「## Small task exemption (v6.11.3 / T-040)」子段:英文(与上下文段对齐),交叉引用 FILE 13,说明 §1+§4 only 的触发降级 + 豁免理由(避免契约与实际漂移,引用 T-039 实证)。
- AC-3 `contract/budget.json` max_lines 2930→2940(新增 ~10 行豁免条款,预算注释追加 v6.11.3/T-040 项);`compile.sh` 重生 5 dist(ENGINE_FILE_SYSTEM_v5.md / runtime-law.md / rules.json / plugin/.claude/commands/engine-init.md / engine/prompts/init.md)+ behavior skills/prompts synced;3 处 dist 均含「小任务豁免」段。
- AC-4 plugin 镜像对称:init.md + behaviors/task-run.md + SKILL.md 3 处 `diff -q` 全部对称(compile.sh 自动同步,本 AC 校验对称性)。
- AC-5 版本三处一致 = 6.11.3 + CHANGELOG 含 v6.11.3 段 + manifest SHA256 更新。
- AC-6 完整发布门禁 `bash scripts/check.sh` 全绿。
- 本任务自身狗粮豁免(estimated_steps=6 ≤ 10, checkpoint_plan=inline),progress.md 仅填 §1+§4,§2/§3/§5/§6/§7 写 n/a 占位。
- 详见 `engine/changes/CHANGE-2026-07-22-02.md`。

## v6.11.2 (2026-07-22)

- 修复 `engine-verify.{sh,ps1}` 的 checkpoint.md append-without-dedup bug(T-039 patch):T-036 v6.11.0 done 18/18 AC PASS 但 checkpoint.md 达 111 行(18 ACs × 6 轮 verify),远超契约 ≤4KB ~100 行预算,SessionStart 注入时逼近 N1=400 行上限。根因是契约源 FILE 15 写"追加写,不覆盖历史行"——这是设计错误,verify 是 checkpoint.md 唯一写入者,同 AC-N 重复 PASS 无信息价值。
- AC-1 契约源 `contract/src/20-file-templates.md` FILE 15 改"追加写"→"dedup 写"共 7 处:line ~1656 写入格式段、line ~1628 表格、line ~1675 skeleton、line ~1683 注释、line ~1692 维护规则;补 dedup 语义说明段(v6.11.2/T-039);`compile.sh` 重生成 `ENGINE_FILE_SYSTEM_v5.md` dist 同步。
- AC-2 `engine-verify.sh` + `engine-verify.ps1`(4 份含 plugin 镜像)实现 dedup:verify PASS 前 grep 同 AC-N 行(`^- \[x\] $ac_id `),存在则 grep -v 移除旧行后 append 新行(sh) / Where-Object -notmatch 过滤后 Set-Content 再 Add-Content(ps1),不存在则直接 append;header 创建逻辑不变。
- AC-3 `engine/skeleton/checkpoint.md` + `plugin/engine/skeleton/checkpoint.md`(2 份)注释更新:"追加写"→"dedup 写"。
- AC-4 现有 5 个 checkpoint.md 文件清理(T-034/T-035/T-036/T-037/T-038):各保留每个 AC-N 最新时间戳一行,header 不变。清理后:T-036 111→22 行(18 ACs),T-034 60→15 行(11 ACs),T-035 51→15 行(11 ACs),T-037 6→5 行(1 AC),T-038 35→14 行(10 ACs)。
- AC-5 端到端测试 `tests/workstream/test_checkpoint_dedup.{sh,ps1}`:黑盒测试 dedup 算法(1) 首次 PASS 创建 1 行(2) 同 AC 再 PASS 仍 1 行且时间戳更新(3) 不同 AC 追加新行(4) AC-1 再 PASS 总数仍 2 行;sh + ps1 双版本均 PASS。
- AC-6 版本三处一致 = 6.11.2 + CHANGELOG 含 v6.11.2 + plugin 镜像 diff -q 4 份 verify 脚本对称。
- AC-7 完整发布门禁 `bash scripts/check.sh` 全绿。
- 详见 `engine/changes/CHANGE-2026-07-22-01.md`。

## v6.11.1 (2026-07-21)

- 修复 D-029 落地 5 处实现层遗漏(T-038 patch):T-036 v6.11.0 done 18/18 AC PASS 但 AC 多为 grep 文本验证,实现层有 4 处未覆盖 + 1 处部分覆盖。本 patch 把 D-029 §8 审视结论真正落地到实现层。
- AC-1 is_shared_memory 扩展含 D-028 三文件:`engine-hook-stop.{sh,ps1}` ×4(plugin 镜像)的 `is_shared_memory` / `Is-SharedMemory` 函数加 `engine/tasks/T-*/progress.md`、`engine/evidence/T-*/checkpoint.md`、`engine/domains/*/INVENTORY.md` pattern。worker 模式下 PreToolUse 拦截这三类文件写共享版本,强制 worker 写 `engine/workstreams/<task>/<sid>/` 分片。这是 D-029 要解决的"progress.md 抢写"痛点的根治。
- AC-2 prompts 加 worker 模式条件化指引:`task-run.md` ×4(plugin 镜像)加「Worker 模式条件化写入指引」段(progress.md/checkpoint.md/INVENTORY.md worker 写分片不写共享)+ progress.md 段 + INVENTORY.md 段加 worker 条件化注释;`handoff.md` ×4 加「HANDOFF 归档角色门控」段(Coordinator add row + archive,Worker don't add row don't archive)。
- AC-3 UUID fallback 替换 anon-PID:`engine-hook-session-start.{sh,ps1}` ×4 与 `engine/bin/engine` + `engine/bin/engine.ps1` 的 assume_coordinator 函数均改为 UUID v4 fallback(sh 用 `uuidgen || /proc/sys/kernel/random/uuid || anon-PID` 兜底;ps1 用 `[guid]::NewGuid().ToString()`)。解决 PID 复用导致 session_key 碰撞风险。
- AC-4 pre-commit worker 检测:`githooks/pre-commit` ×2(plugin 镜像)加 `ENGINE_WORKER=1` 环境变量检测,B 档适配器(Codex/Cursor/Aider)用户显式设此变量后 pre-commit 拒绝共享三件套 staged,与 C 档 PreToolUse 双信号机器强制互补。
- AC-5 s-/a- 前缀约定 + sessions/agents 目录隔离:`engine/bin/engine` + `engine/bin/engine.ps1` + `engine/bin/engine.cmd` ×2(plugin 镜像)改为根据 kind 切换目录:`subagent` → `<task>/agents/a-<agent>/`,`session` → `<task>/sessions/s-<agent>/`。前缀只是人类可读视觉提示,机器识别通过 `.role=worker` 标志 + workstream 目录路径(不依赖前缀)。
- AC-6 文档更新:`ENGINE_DOCTOR.md` ×2 加 #19/#31 worker 模式实现层检查(检测 `is_shared_memory` 是否含三类文件 pattern,缺失任一 = FAIL);`AGENT_ADAPTERS.md` ×2 加 s-/a- 前缀约定 + ENGINE_WORKER 环境变量使用说明 + Worker 模式条件化写入实现段;contract-version 6.11.0→6.11.1。
- AC-7 plugin 镜像同步:4 份 .sh + 4 份 .ps1 + 2 份 pre-commit + 2 份 bin 完整对称验证,manifest SHA256 已更新。
- AC-10 端到端测试:`tests/workstream/test_worker_writes_shard.{sh,ps1}` 验证 worker 模式下写 progress.md/checkpoint.md/INVENTORY.md 被拦截,写自己分片不被拦。
- 详见 `engine/changes/CHANGE-2026-07-21-02.md`。

## v6.11.0 (2026-07-20)

- 多 Claude Code 实例并行抢写引擎记忆三件套的隔离机制(D-029/T-036):SessionStart hook 复用 Claude Code payload 已传入的 `session_id`,用 atomic 独占 lock file(`engine/.cache/session.lock` 5 字段 `pid|session_id|role|started_at|task_id`)分配协调者/worker 角色,第一个会话获协调者(写共享三件套),后续会话降级 worker(写 `engine/workstreams/<task>/<session-id>/` 隔离分片)。
- atomic 独占 lock:bash 用 `set -C` / `noclobber` (POSIX,无外部依赖);PowerShell 用 `FileStream(FileMode.CreateNew, FileShare.None)` (OS 保证无 TOCTOU)。接管协调者时写 `engine/.cache/session.tombstone` 通知其他会话。
- PreToolUse 拦截扩展为双信号(OR 关系非 AND):`agent_id` 非空 **或** `.cache/sessions/<key>.role=worker` 标记文件存在,任一即拦截 worker 写共享记忆。Stop hook 写 `.meta` 文件(role|stopped_at|task_id)+ 协调者退出释放 lock + tombstone 通知。
- 两个逃生通道命令:`engine assume-coordinator [--force]`(强制接管 lock + 写 tombstone,三种场景:no lock/fresh、lock 无 --force 拒绝、lock 有 --force 写 forced-replaced tombstone)+ `engine merge-workstream <session-id>`(显示 worker 分片 + 提示协调者 5 步合并流程,不自动写共享记忆)。
- `engine workstream T-NNN AGENT` 加 `--kind=subagent|session` 参数(默认 subagent 向后兼容);`--kind=session` 创建 `.cache/sessions/<agent>.role=worker` 标记文件供 PreToolUse 信号 2 检测。
- kill switch:`ENGINE_DISABLE_MULTI_SESSION=1` 环境变量或 `engine/.cache/multi-session.disabled` 标志文件存在时,SessionStart hook 跳过 lock 检测,所有会话降级为单会话模式(等同 v6.10.0 fail-open)。
- engine-context 加 Active Sessions 面板(读 lock file 协调者 + .cache/sessions/*.meta workers)。
- engine-doctor 加 `check_multi_session_isolation`(FAIL 级 cv>=6.11.0,检查 lock file 5 字段格式 + tombstone 24h 过期)+ `check_workstream_orphan`(WARN 级,workstream 分片无对应 .meta 文件)。
- ENGINE_DOCTOR.md managed block 加 #17/#18 检查条款;contract-version 6.10.0→6.11.0;plugin/engine/ENGINE_DOCTOR.md 加 #29/#30 镜像条款。
- AGENT_ADAPTERS.md 加 C 档扩展子段:多会话锁基础 + assume-coordinator --force 使用频率警示(≤ 每周 1 次合法场景)+ 同一任务卡不同 AC 并行约束(WRITE-SET 重叠 / evidence 顺序 / checkpoint.md 串行性)+ kill switch 说明。
- migrator `engine-migrate-contract.{sh,ps1}` ×4 managed block 加 #17 #18 条目,幂等写入旧项目的 ENGINE_DOCTOR.md。
- 详见 `engine/changes/CHANGE-2026-07-20-03.md` 与 `engine/changes/CHANGE-2026-07-20-04.md`。

## v6.10.0 (2026-07-20)

- verify 死代码检测(D-028/T-035):verify 脚本入口自检 shellcheck/PSScriptAnalyzer 可用性,不可用时降级 grep fallback(.ps1 端含 `Install-Module -Scope CurrentUser -Force -AllowClobber` 兜底);对 WRITE-SET 触及的 .sh/.ps1 文件执行 linter + 反向调用点扫描(查函数定义在全仓的残留引用,无调用点 = 死代码候选)。
- evidence 输出:`engine/evidence/T-NNN/DEAD-CODE.json`(顶层 `exempt_all` 批量豁免 + per-entry `exempt` 细粒度 + `summary.warn_count` + `linter` 字段)+ `engine/evidence/T-NNN/COPY-PASTE.json`(jscpd 委托输出,D-028 §10 机制 B;不可用降级 skip + `jscpd_available: false`)。
- WARN→done 门项(D-028 §9):warn_count > 0 且未豁免时 done 须架构师显式豁免;`engine-doctor.{sh,ps1}` ×4 实现 `check_warn_done_gate`/`Test-WarnDoneGate`(FAIL 级;contract-version < 6.10.0 时降级 WARN 与 D-028 §9 一致;DEAD-CODE.json 顶层 `exempt_all: true` 视为全部 entry 已豁免)。
- 递归保护(`ENGINE_VERIFY_RECURSE_GUARD=$task`,task-specific guard):防止 AC verify 命令递归调用同任务 engine-verify 导致死循环;跨任务调用(如 behavior verify 测试 fixtures)正常执行。
- 迁移宽限期:contract-version < 6.10.0 时所有 WARN→done 检查 FAIL 降级为 WARN;≥ 6.10.0 时 FAIL(与 D-028 §9 一致)。
- 详见 `engine/changes/CHANGE-2026-07-20-02.md`。

## v6.9.0 (2026-07-20)

- AC 级 checkpoint.md 压缩恢复锚点：verify 脚本在每个 AC PASS 后追加写 `engine/evidence/T-NNN/checkpoint.md`（已完成 AC 列表 + 关键中间状态 + 下一 AC 指针），SessionStart 优先注入 checkpoint.md（覆盖 progress.md §4 与 HANDOFF 立即恢复点）。
- 任务粒度软门禁（D-028 §9）：AC 数量 > 12 / WRITE-SET 独立路径 > 15 / estimated_steps > 20 / WRITE-SET 字节数 > 30KB 任一触发且未声明 `checkpoint_plan` = FAIL；`checkpoint_plan: tryout` 是合法 bypass 值。
- depends-on 显式依赖字段（D-028 §9）：任务卡间逗号分隔的上游依赖列表，任一上游 status != done 时本卡置 active = FAIL（跨域拆卡协调）。
- WRITE-SET 静态预算软门禁（D-028 §10 机制 A）：`check_writeset_budget` 对 active 卡的 WRITE-SET 列出文件求 `wc -c` 之和，> 30KB 触发软门禁。
- 迁移宽限期：contract-version < 6.9.0 时所有软门禁 FAIL 降级为 WARN；≥ 6.9.0 时 FAIL（与 D-028 §9 一致）。
- 详见 `engine/changes/CHANGE-2026-07-20-01.md`。

## v6.8.0 (2026-07-20)

- (no capsules in this release)

## v6.7.0 (2026-07-19)

- v6.7.0 任务级 progress.md 压缩恢复锚点 (2026-07-19)

## v6.6.3 (2026-07-19)

- v6.6.3 hotfix (2026-07-19)

## v6.6.2 (2026-07-19)

- Doctor spec twin 误判 hotfix (2026-07-19)

## v6.6.1 (2026-07-19)

- (no capsules in this release)

## v6.6.0 (2026-07-19)

- HANDOFF 历史归档机制：会话历史表 8 条上限，超出迁移到 `engine/handoff-archive-YYYY-MM.md`（search-only，不进 SessionStart/§1，Doctor 不校验预算）。
- Doctor：sh/ps1 加 `check_handoff_history_cap`/`Test-HandoffHistoryCap` WARN 检查；`ENGINE_DOCTOR.md` 实例+模板加 #23 检查。
- Migrator：sh/ps1 加 v6.6 managed block item 11，旧项目升级时获得归档规则（不自动裁剪，由 agent 在下次写 HANDOFF 时触发）。
- Behaviors：`handoff.md` step 4 加归档触发；step 5 加 CONTEXT ✅ 划线行删除。
- 当前仓样本：HANDOFF 53→8 条 + 35 条 7 月归档 + 11 条 6 月归档；CONTEXT 删 8 条 ✅ 划线行。
- 详见 `engine/changes/CHANGE-2026-07-19-01.md`。

## v6.5.0 (2026-07-17)

- 长会话与全路径任务边界：v6.5+ 无 active/closing 任务卡时普通写入 fail-closed，done 逐 AC 要 PASS evidence。
- 并行 agent 记忆分片：worker 使用 `engine/workstreams/<task>/<agent>/`，共享 CONTEXT/HANDOFF 由协调者单写汇总。
- 低 token 重锚：UserPromptSubmit 周期提示实测 4 行；Doctor 聚合 done 历史，避免任务数量线性消耗上下文。
- 发布完整性：installer `--local` SHA256 校验、runtime-law 失败硬报错、双实现 parity 与完整隔离安装验证通过。
- 详见 `engine/changes/CHANGE-2026-07-17-01.md`、`CHANGE-2026-07-17-02.md`。

## v6.3.1 (2026-07-14)

- Doctor 补字节上限 + 单行宽度上限检查 (2026-07-14)

## v6.3.0 (2026-07-14)

- Architect self-view and change capsules (2026-06-22)
- CHANGE-2026-07-03-01 (2026-07-03)
- CHANGE-2026-07-03-02 (2026-07-03)
- v6 S2 Fractal Memory (2026-07-03)
- v6 S3 Contract Compile (2026-07-03)
- v6 S4 Cockpit (2026-07-03)
- v6 体系完善批次1：分发完整性 + Doctor 编译检查 (2026-07-03)
- v6 体系完善批次2a：pre-commit 认 done + 安装 (2026-07-03)
- v6 体系完善批次3：S3-b 源模块细分 (2026-07-03)
- v6 体系完善批次2b：D6 根锚点 (2026-07-03)
- v6 体系完善批次4：契约债计数器（N4） (2026-07-03)
- v6 review 缺口修复：dist 行尾 + N3 done-gate + dist 多产物 (2026-07-03)
- v6 中优先缺口：N1 注入计数器 + L0 注入 + flaky (2026-07-03)
- v6 低优先缺口：Q3 门禁严格度 + Q4 v6 命名 (2026-07-03)
- Engine v6 auto-update + migration mechanism (2026-07-03)
- v6 验收缺口修复 + 外部 4 bug(D-015/T-014) (2026-07-04)
- # CHANGE — 2026-07-05-01 (2026-07-05)
- # CHANGE — 2026-07-05-02 (2026-07-05)
- # CHANGE — 2026-07-05-03 (2026-07-05)
- T-018 离线安装包 (2026-07-05)
- T-019 Phase 1 核心设计(D-018)+ init prompt 通用化分发 + engine init (2026-07-05)
- CHANGE-2026-07-05-06 (2026-07-05)
- D-019 行为引擎化提案(proposed) (2026-07-06)
- T-022 P0 防护卡 + 分发盲区修复 (2026-07-06)
- T-023 行为技能层 + 发布可用性准则 (2026-07-12)
- T-024 SYSTEM/Doctor 职责边界修正 (2026-07-12)
- VERSION 6.0.1 → 6.2.0 补回遗漏更新 (2026-07-12)
- engine/checks/ 自定义检查扩展点 (2026-07-12)
- VERSION 卡死 bug 修复 + Doctor 格式特征检测 (2026-07-14)
