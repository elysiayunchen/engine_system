# Changelog

## v6.26.0 (2026-08-01) — TDAI P1 集成: 漂移检测 + 胶囊 heat(T-085)

- Guard 漂移检测: 4 信号评分(非 active T-NNN +3 / GOAL 零关键词重叠 +2 / session 亲和性 +1 / card stale >4h +1), score>=3 DRIFT ADVISORY, 1-2 drift-hint, 0 静默
- 变更胶囊 META header: heat/created/updated/related-decisions/related-tasks/domain
- Doctor check_capsule_heat: heat>=5 WARN 高频变更 / heat>=3 无决策 WARN
- PS1 行为镜像 + plugin byte-identical
- 测试: drift 9 + capsule_heat 6 = 15 断言 ALL PASS

## v6.25.0 (2026-08-01) — TDAI P0 集成: 任务画布 + 失败模式提取(T-082)

- 新增 engine-canvas.{sh,ps1}: 从 evidence 实时派生 Mermaid 任务状态画布(零 LLM, 零持久化, view not state)
- SessionStart 注入: Active Task Card 之后自动输出画布块(%%{taskGoal, progress, cardStatus, gateStatus}%%)
- Guard 模式一行摘要: CANVAS: T-NNN M/N AC PASS
- 状态映射: pass→done/绿, fail→blocked/红, 首个 todo→doing/黄, 其余 todo→紫; >8 AC 自动 graph TD
- 新增失败模式自动提取: Stop hook 检测 S5(memory-writeback)/S12(verify-fail)/S13(doctor-fail)/S18(capsule-missing)
- pre-commit EXIT trap: 任何 block 写 .cache/last-commit-block(signal_id + trigger_file)
- PITFALLS Auto-detected 候选区: 自动追加 CAND 条目, cksum 去重(seen-keys + 全文), fail-open
- PS1 行为镜像 + plugin 镜像 byte-identical + manifest 71 项 + protected_paths 42 项
- 测试: canvas 18 + failure_extract 12 = 30 断言 ALL PASS

## v6.24.0 (2026-08-01) — Gatekeeper 子系统(T-077)

- 新增 `engine gate T-NNN` 命令:聚合 verify/review/review-agent/prove 门禁证据 → 写 GATE.json
- 新增 pre-commit 硬拦截:done 过渡时强制 GATE.json status=pass + provenance 校验(writer=engine-gate, commit=HEAD)
- 新增 --no-verify 封死机制:bypass-detected 标志 → 后续所有 commit 被 block 直到解决;config seal.override_authored 按项目解锁
- 新增 Doctor check_gate_registry:cv>=6.24.0 done 卡无 GATE.json → FAIL
- 新增 engine/gate/config.json(gates 列表 / block_on / docs_only_skip / seal 配置)
- 契约条款:Quality Gate Enforcement Rule 作为 S4 扩展(D-039 决策,budget 基线 2940→2980)
- engine-gate.{sh,ps1} 行为镜像 + plugin manifest + install.sh + federation 路由
- 测试:gate_cli 11 + gate_precommit 9 + gate_seal 5 = 25 断言 ALL PASS

## v6.23.0 (2026-07-31) — Prove 子系统(T-075/T-076)

- 新增 `engine prove T-NNN --infer/--execute`:从 code diff 自动推断断言 → 执行验证 → PROVE.json
- Doctor prove 检查 + 并发锁 + fingerprint 覆盖 WRITE-SET + syntax-only WARN + verify timeout
- AC 交叉锚定:parse verify: 命令提取 basename 交集(0%→FAIL, <50%→WARN)
- 多视角审查:correctness/security/edge-case 三 lens prompt + model_id + cross_model 标记
- 审计 bug 修复 6 项(gate total=0 / test bypass / tautology 扩展 / ps1 WRITE_SET / blocklist / verify sed)
- install.sh manifest 补齐 prove/review 13 项 + plugin config 镜像

## v6.22.0 (2026-07-31) — Agent-Reviewer 对抗性升级(T-073)

- Package 动态挑战生成:静态 3 挑战 → python diff 语义信号分析(6 信号:无 else 分支/函数签名变更/大 hunk>20 行/大量删除>15 行/TODO-FIXME/错误处理,优先级排序取 top 3,无信号 fallback 静态)
- Package 新增 `packaged_by` header(CLAUDE_SESSION_ID 或 hostname:pid)+ schema 新增 `reviewer_session` 字段
- Validate 新增 E_GROUNDED:校验 finding file:line 引用真实存在(>50% 虚假 → FAIL,≤50% → WARN)
- Validate 新增 E_INDEPENDENCE:reviewer_session 与 packaged_by 比对(相同或缺失 → WARN,grace period)
- config.json `agent_review.enabled` 默认 true(新项目开箱即用;代码 fallback 亦为 true)
- 修复 Windows CRLF/GBK 字节导致 python UnicodeDecodeError(所有 open() 加 errors='replace')
- plugin 镜像 byte-identical(4 脚本)
- 测试:dynamic 9/9 + grounded 10/10 + 回归 gate 10/10 + doctor 13/13 = 42 断言 PASS

## v6.21.0 (2026-07-31) — Review 子系统 P2(agent-reviewer 语义审查)

- 新增 `engine review-agent T-NNN --package/--validate` 两原子命令(外部 agent 做语义级代码审查)
- 新增 6 个脚本:engine-review-agent{,-package,-validate}.{sh,ps1}(plugin 行为镜像)
- 新增 `engine/review/protocol.md`(L0 默认审查协议,5 维度固定)
- config.json 新增 `agent_review` 配置段(enabled 默认 false,opt-in;min_entries/min_narrative/adversarial_challenges 等参数)
- Package 阶段:WRITE-SET diff + 周边上下文(git hunk header + grep) + 域知识(federation 路由) + 3 个参数化静态挑战 + v1 linter 摘要注入 + sha256 自证(COMPUTE 归一化算法)
- Validate 阶段:E_SCHEMA(7 必填字段 + 5 维度结构) → E_SHALLOW(反橡皮图章:最小条目/叙事量/对抗响应长度) → E_PROVENANCE(回显模型:package_sha256 + head_commit  echoes) → E_STALE(WARN)
- 通过后更新 REVIEW.json(追加 agent_review 维度) + 重算 evidence_manifest_sha256
- CLI dispatcher 更新:engine/bin/engine{,.ps1} + plugin 镜像
- 60 个测试断言全绿(CLI 12 + package 19 + validate 16 + config 4 + mirror 9)

## v6.20.0 (2026-07-30) — Review 子系统 P1(pipeline 核心)

- 新增 `engine review T-069` 命令(二维审查:semgrep + eslint)
- 新增 4 个脚本:engine-review.{sh,ps1} + engine-review-pipeline.{sh,ps1}(plugin 镜像 byte-identical)
- 新增 `engine/review/config.json`(L0 defaults + L1 overrides,Class=mixed)
- evidence schema:REVIEW.json + SECURITY.json + QUALITY.json,含 write_provenance + code_fingerprint + evidence_manifest_sha256 + tool_detection + config_layers
- L2 REVIEW-OVERRIDE 单向提级校验(severity_threshold + add/skip_dimensions)
- diff 算法:git log --reverse + git diff task_first_commit..HEAD(只扫 WRITE-SET 内代码文件)
- tool_unavailable 降级:WARN + skip + 记检测证据(不静默不卡死)
- flock -n(Unix)+ mkdir 原子锁(macOS fallback)+ FileStream(Windows)
- 19 AC 全绿,9 个测试文件

## v6.20.0 (2026-07-30)

T-068 防漂移 P3 — 批量补 code_fingerprint(D-038d 迁移期收尾)。对 T-048~T-060, T-063~T-065 共 16 张 legacy done 卡批量重跑 `engine verify` 补 code_fingerprint,全部升级为 T1 结构性信任级(code_fingerprint 存在 + verified_against_commit 记录)。16 张卡均因版本漂移有 AC FAIL,标 exempt(check.sh 跳过 evidence 检查,drift-check 仍校验)。双写过渡期(v6.19.0~v6.20.0)结束。

**T-068 (D-038d 迁移期收尾):**
- 16 张 done 卡 evidence 从单锚 `fingerprint` 升级为多锚(`output_fingerprint` + `code_fingerprint` + `write_set_snapshot` + `verified_against_commit` + `write_provenance` + `MANIFEST.json`)
- 16 张任务卡 frontmatter 加 `<!-- exempt: AC-N verify failed due to version drift -->` 注释
- T1 占比:16/16 = 100%(目标 ≥75%)
- 深度历史卡(T-004~T-047)保留 T2(D-038 决策点 #8)

**漂移原因分类:** 版本号漂移(全部 16 张)、check.sh/doctor 漂移(多数卡)、PowerShell 环境缺失(T-053)、contract-version 漂移(T-048)。

## v6.19.0 (2026-07-30)

T-067 防漂移 P2 — 状态面板视图化 + 信任分级注入(D-038c/d)。堵声明漂移 + 决策漂移 + agent 误判:CONTEXT.md 状态面板从「权威声明」降级为「派生视图」(双写过渡期 v6.19.0~v6.20.0,旧静态段保留并标 legacy,新 Derived Status 段实时重算 git tag + engine/VERSION + 最近 done 卡 evidence 信任级),`engine context` 输出对每段声明打 T1/T2/T3 信任标签(T1=机器校验通过;T2=legacy-evidence/declared-only;T3=待验证),Doctor 校验 derived/legacy 标注与一致性。批量补 code_fingerprint 独立到 T-068。

**T-067 (D-038c/d):**
- `engine-context.{sh,ps1}` + plugin 镜像:新增 `render_derived_status()`/`Render-DerivedStatus` 函数,实时计算最近 git tag、engine/VERSION 一致性、最近 done 卡 evidence 信任级(code_fingerprint 存在 + verified_against_commit=HEAD/ancestor → T1 structural;无 code_fingerprint → T2 legacy-evidence;vac not ancestor → T2 stale;tag/VERSION mismatch → T3),输出 "Derived Status" 段(machine-verified);CONTEXT.md 输出时按段注入 [T1]/[T2 legacy]/[T2 declared-only]/[T3 unverified] 信任标签
- `engine-doctor.{sh,ps1}` + plugin 镜像:新增 `check_derived_status()`/`Test-DerivedStatus` 函数,校验 (1) CONTEXT.md `<!-- legacy: status-panel -->` 标注存在(缺失→WARN);(2) 派生值(最近 git tag vs engine/VERSION)与静态声明一致(不匹配→WARN);(3) 静态面板是否引用当前版本(stale panel detection)。双写过渡期 WARN 不 FAIL
- `engine/CONTEXT.md`:"状态面板" 段加 `<!-- legacy: status-panel (double-write transition, v6.19.0~v6.20.0) -->` 标注 + 说明注释(engine context 输出时实时重算 "Derived Status" 段,本静态段保留并标 legacy)

**设计要点:**
- 信任标签注入 `engine context` **输出**(不写入 CONTEXT.md 文件),agent 读取时即看到分级
- T1 判定=evidence 有 code_fingerprint + verified_against_commit=HEAD/ancestor + git tag 与 engine/VERSION 一致(T1 structural;full T1 由 Doctor/engine drift-check 确认)
- T2 分档:legacy-evidence(无 code_fingerprint)/ declared-only(人工决策声明)/ stale(vac not ancestor of HEAD)
- T3=待验证项(agent 须先跑校验或显式声明"未验证")
- 双写过渡期 2 版本(v6.19.0~v6.20.0):旧静态状态面板保留并标 legacy,新 Derived Status 段并行;Doctor 对 derived 不一致只 WARN 不 FAIL(容忍迁移期)
- verified_against_commit 校验:HEAD 直接匹配 OR ancestor of HEAD(evidence 在任务提交前写入,vac 通常是 HEAD~1)

**测试:**
- `tests/workstream/test_derived_status.sh`:6 场景端到端(S1 derived 段渲染 + T1 / S2 信任标签 [T2 legacy]/[T2 declared-only]/[T3 unverified] 注入 / S3 doctor PASS on legacy annotation / S4 doctor WARN on missing legacy / S5 doctor WARN on tag/VERSION mismatch / S6 T2 legacy-evidence when no code_fingerprint)

**验证:** derived_status 9/9 PASS(含 S1 双断言);plugin 镜像 4 脚本 byte-identical;check.sh CHECK PASSED。

## v6.18.0 (2026-07-30)

T-066 防漂移 P1 — 证据多锚 + drift-check(D-038a/b)。堵 6 类漂移:时间漂移、锚点漂移、状态漂移、evidence 篡改、WRITE-SET 二阶漂移、EOL 假 DRIFT。

**T-066 (D-038a/b):**
- evidence schema 升级为多锚:`output_fingerprint`(原 `fingerprint` 改名)+ 新增 `code_fingerprint`(`git ls-files -s` 取 index blob sha,已 EOL 归一化)+ `write_set_snapshot` + `verified_against_commit` + `write_provenance`(writer/commit/timestamp/argv)+ `MANIFEST.json` 聚合 hash(目录所有 .json + checkpoint.md,排除自身)
- 新增 `engine/scripts/engine-drift-check.{sh,ps1}` + plugin 镜像:三步顺序校验(完整性自证 → WRITE-SET 二阶检测 → 代码指纹比对),任一 FAIL 仍输出后续摘要标 unverified,避免 manifest 失败掩盖更深漂移
- `engine-verify.{sh,ps1}` + plugin 镜像:收集 code_fingerprint 时前置 `git add` 检查(未 add 则 FAIL);循环结束写 MANIFEST.json
- `githooks/pre-commit` + plugin 镜像:AC PASS 检查后追加 evidence provenance gate。双路径:(a) 机器写入 → writer=engine-verify + commit=HEAD + argv='engine verify <task>';(b) 手工编辑 → evidence JSON 须带 `evidence-manual-edit` 标注。任一不匹配 → exit 1
- `engine-doctor.{sh,ps1}` + plugin 镜像:新增 `check_drift`/`Test-Drift` 函数,调用 drift-check 脚本,根据 exit code 输出 PASS/FAIL
- `rules.json`:`engine/evidence/**` + `engine/scripts/engine-drift-check.*` 纳入 protected_paths
- pre-commit protected-path gate 加 `engine/evidence/T-NNN/**` self_exempt(任务卡自己的 evidence 目录豁免,跨任务篡改由 provenance gate + drift-check 拦截)
- D-038d 迁移期策略:legacy evidence(无 MANIFEST + 无 write_provenance)→ WARN 跳过,信任级 T2;有 write_provenance 但 MANIFEST 缺失 → FAIL tamper

**修复:**
- `engine-drift-check.sh` step3 解析 bug:`cut`+`sed` 在单条目 JSON 上留末尾 `}` 导致 stored_sha vs current_sha 假 DRIFT,改用 `awk -F'"'` 取字段
- `engine-drift-check.ps1` PowerShell `$path:` scope 解析 bug:字符串内 `$path:` 被当成 scope 引用,改用 `${path}:`

**测试:**
- `tests/workstream/test_drift_check.sh`:5 场景端到端(clean PASS / MANIFEST 篡改 FAIL / 代码改 DRIFT / MANIFEST 缺失 tamper FAIL / provenance.commit 不匹配 FAIL)
- `tests/workstream/test_evidence_provenance.sh`:6 场景 black-box(clean PASS / 缺 provenance FAIL / writer=manual FAIL / commit!=HEAD FAIL / manual-edit 标注 PASS / argv 不匹配 FAIL)
- `tests/task-card/run-task-tests.sh` C4 fixture:evidence JSON 加 `evidence-manual-edit` 标注(手工构造)
- `tests/behavior-verify/run-verify-tests.sh` B1:`"fingerprint"` → `"output_fingerprint"`

**验证:** drift-check 5/5 PASS;provenance 6/6 PASS;plugin 镜像 7 文件 byte-identical;check.sh CHECK PASSED。

## v6.17.4 (2026-07-30)

T-065 pre-commit governing 不把已 done 卡误当 closing(issue #21)。

**T-065 (#21):**
- `engine/scripts/githooks/pre-commit` + plugin 镜像 L234-245:closing_paths 收集逻辑增加 HEAD 检查。staged 卡 status:done 后,额外检查 HEAD 是否已 done;HEAD 已 done 则跳过(不是 closing,不加入 governing)。与 issue #18 的 AC PASS 检查修复(L375-381)模式一致
- 新增 `tests/workstream/test_precommit_done_card_governing.sh`:5 场景:active→done closing / 新卡首次 done closing / 已 done 修改跳过 / staging active 跳过 / 新 active 卡跳过
- 修复:修改已 done 卡时该卡被误加入 governing,其 WRITE-SET 不覆盖的文件被 union check 拦截,只能 --no-verify 绕过

**验证:** governing test 5/5 PASS;done-card drift 回归 5/5 PASS;plugin 镜像 byte-identical;check.sh CHECK PASSED。

## v6.17.2 (2026-07-29)

T-063 migrator contract-version bump 提示(issue #15)+ doctor latent set -e bug 修复。

**T-063 (#15 D-13):**
- `engine-migrate-contract.sh`/`.ps1` + plugin 镜像:upsert managed block 前捕获 OLD contract-version 戳,upsert 后若 `新戳 != 旧戳` 打印 "contract-version bumped: $OLD -> $NEW" + 列出 active/paused 任务卡提示审查
- 新增 `tests/update-flow/test_migrator_bump_prompt.{sh,ps1}`:S1 bump+active 卡 / S2 idempotent repair / S3 bump 无 active 卡 / S4 fresh install 无 prior 戳(回归)
- 修复 fresh-install 崩溃:migrator `OLD_CONTRACT_VERSION` 捕获循环的 `grep -oE` 无匹配返回 1,`set -euo pipefail` 触发 `on_error` 退出,导致 install.sh I6 测试 FAIL(AGENTS.md 无 contract-version 戳)。加 `|| true` 对齐既有 `plan_section`/`sample_row` 模式

**Doctor latent bug 修复(T-063 验证发现):**
- `engine-doctor.sh`/`plugin` 镜像 line 1494:`check_multi_card_writeset_overlap` 的 `entries="$(grep '^WRITE-SET:' ... | tr ',' '\n')"` — 当 active 卡用 `## WRITE-SET` bullet 格式(T-061)而非 `WRITE-SET:` 单行格式时,grep 无匹配返回 1,pipefail 触发 `set -e` 静默退出(exit 1,无 FAIL/WARN 输出)。加 `|| true` 对齐 migrator 修复模式

**验证:** bump prompt 9/9 PASS(sh+ps1);install flow 6/6 PASS(I6 contract-version: 6.17.2);doctor exit 0(1 WARN: T-061/T-063 WRITE-SET overlap 预期);manifest 62/62 sha256 verified;check.sh 仅余 pre-existing session injection 436>400(project_memory 明确留待面板溢出时手动裁剪)。

## v6.15.1 (2026-07-29)

T-058 证据 + 文档完整性修复(T-059)。子代理 5 维度复查发现功能层全 PASS,但证据层和文档层有 3 个 CRITICAL + 3 个 MAJOR + 6 个 MINOR 问题。本次仅修证据 + 文档,不动功能代码。

**CRITICAL 修复:**
- **C1 (P-CRIT-2)**: 7/7 AC 证据文件 fingerprint 从描述性字符串(`sha256:24files-bom-verified` 等)重写为真实 64-hex SHA256(engine-migrate-contract.ps1 hash 61559a1e...、engine-doctor.ps1 hash 676a1506...、manifest.json hash d4935e5d...、compile.sh hash d3431608...、VERSION hash 74894f40...)
- **C2 (AC-6 verify 无法匹配)**: `Select-String -Pattern 'FUNCTIONAL.*§.*MUST NOT'` 在文件中无任何匹配(L9 有 FUNCTIONAL+MUST NOT 但无 §,L10/L15 有 § 但无 MUST NOT),改为 `grep -c 'FUNCTIONAL section signs'` = 1
- **C3 (.sh § 计数口径错误)**: T-058 的 P5 "修正"把 113 改成 100,但 113 是字符出现数(grep -o|wc -l),100 是行数(grep -c,且漏算 compile.sh)。改为同时记录两个口径:113 字符出现 / 101 行

**MAJOR 修复:**
- **M1**: check-version-consistency.ps1 实测含 BOM(EF BB BF),修正 progress.md/CHANGE/evidence 中"纯 ASCII 无 BOM"的错误声明
- **M2**: .ps1 文件计数 24 → 25(WRITE-SET 24 + check-version-consistency.ps1)
- **M3**: 行号漂移 +8 修正(P4 在文件顶部加 7 行注释导致):L304→L312, L355-360→L362-368, L375-394→L379-402

**MINOR 修复:**
- P4 注释行数 10 → 7(L9-15)
- L375-394 模板范围 → L379-402
- CHANGELOG v6.14.2 条目"重生成 CONTEXT.md" → "重生成 skeleton/progress.md"
- manifest HEAD 版本 hash stale 修正(153a74b7... → 61559a1e...,工作树已修随本任务提交)
- checkpoint.md 计数 24 → 25
- AC-1 note 关于 check-version-consistency.ps1 的描述修正

**验证:** 7 个 AC 证据 fingerprint 全部为合法 64-hex SHA256;7 个 AC verify 全部为可执行命令;AC-6 verify 实际可匹配;check-version-consistency.ps1 BOM 实测确认;.sh § 计数 113 字符出现 / 101 行;check.sh CHECK PASSED。

## v6.15.0 (2026-07-29)

PS 5.1 乱码根因修复 — .ps1 UTF-8 BOM 方案(T-058)。T-056/T-057 的逐字符 ASCII 化清理(—→-, §→S)治标不治本(全仓仍有 859 处非 ASCII,here-string 中文模板会写入 .md 造成永久乱码)。本次给所有 .ps1 文件加 UTF-8 BOM(EF BB BF),使 PS 5.1 正确按 UTF-8 读取源文件,一次性消除所有非 ASCII 乱码风险。经子代理 12 维度评估确认可行(Strong GO)。

**BOM 方案(根因修复):**
- 18 个 .ps1 文件加 UTF-8 BOM(6 个已有 BOM:engine-hook-stop.ps1 × 2 + engine/bin/engine.ps1 × 3 + contract/compile.ps1)
- 覆盖 11 个逻辑文件 × 2-3 副本(engine/scripts/ + plugin/engine/scripts/ + engine/bin/ + plugin/bin/ + plugin/engine/bin/ + engine/migrations/ + plugin/migrations/)
- .sh 文件不加 BOM(破坏 shebang),.md 文件不加 BOM(无需)
- plugin 镜像 byte-identical 保持(同逻辑文件所有副本同步加 BOM)
- manifest SHA256 重算(62 条目,跑 `bash contract/compile.sh`)

**附带修复(T-057 复查发现):**
- **P4**: engine-migrate-contract.ps1 顶部加功能性 § 警告注释(7 行 L9-15,防止未来全局替换破坏 L312 正则/L362-368 契约块/L379-402 模板)
- **P6**: manifest.json engine-migrate-contract.ps1 条目重复 sha256 字段修复(compile.sh backfill 留下旧值)
- **P5**: 文档中 .sh § 计数口径明确:113 字符出现(grep -o|wc -l)/ 101 行(grep -c),非笼统"100 或 113"
- **文档错误**: L379-402 模板用途修正(写入 skeleton/progress.md,非 CONTEXT.md)

**保留(不回退):**
- T-056/T-057 的 ASCII 化(—→-, §→S)仍有效,加 BOM 后不再乱码但 ASCII 化有跨 locale 兼容性
- T-056/T-057 的证据不重跑(已推送,历史不动)

**验证:**
- 所有 .ps1 文件含 UTF-8 BOM(25 文件验证通过,含 check-version-consistency.ps1)
- .sh 文件无 BOM(shebang 不破坏)
- plugin 镜像 byte-identical
- manifest SHA256 全量一致(62 条目)
- P6 manifest 无重复 sha256 字段

## v6.14.2 (2026-07-29)

§ 编码 hotfix(T-057)。承接 T-056 v6.14.1 em-dash 修复,本次清理 Windows PowerShell 5.1 zh-CN locale 下 §(section sign,U+00A7)在用户可见字符串中的乱码。根因:UTF-8 § 字节 `C2 A7` 被 GBK codepage 解码为 `搂`(C2A7 = 搂)→ 用户看到 `D-028 §9` 渲染为 `D-028 搂9`。实测证据:`tmp_section_test.ps1` 在 PS 5.1 下输出 `搂1 and 搂2`。

- **修复**:3 处用户可见 `§` → ASCII `S`:
  - `engine/scripts/engine-doctor.ps1` L768、L854 `Write-Output` 字符串 `(D-028 §9)` → `(D-028 S9)`(engine + plugin 镜像)。
  - `engine/scripts/engine-migrate-contract.ps1` L308 `Write-Host` 警告 `ENGINE_MAP §2 plan registry` → `ENGINE_MAP S2 plan registry`(engine + plugin 镜像)。
- **保留**(功能性 § 不动):
  - `engine-migrate-contract.ps1` L304 正则 `'## .*§2'`(匹配 ENGINE_MAP.md 章节标题)。
  - `engine-migrate-contract.ps1` L379-402 here-string 模板 `## §1 已读文件` 等(重生成 skeleton/progress.md 用,非 CONTEXT.md,T-058 修正)。
  - 注释里的 §(非用户可见,留独立任务)。
  - `.sh` 文件中的 §(bash 处理 UTF-8 无乱码问题)。
- **验证**:`Select-String` 确认 3 处用户可见字符串无 §;plugin 镜像 SHA256 byte-identical;`check.sh` CHECK PASSED。
- **未覆盖**(留独立任务):注释里的 §、`.sh` 文件中的 §、here-string 中文模板、`engine-sync-agent-anchors.ps1`、`engine-verify.ps1` 中其他非 ASCII 字符。

## v6.14.1 (2026-07-29)

em-dash 编码 hotfix(T-056)。Windows PowerShell 5.1 在 zh-CN locale 下按 GBK codepage 读取无 BOM 的 .ps1 源文件,UTF-8 编码的 em-dash(`—`,字节 `E2 80 94`)被 GBK 解码为 `鈥` + 残字节 `?` → 控制台输出乱码。本次扫描发现 7 个 .ps1 含非 ASCII,但只有 3 处出现在用户可见的 `Write-Warn`/`Write-Output`/`Fail` 字符串字面量(其余在注释或 .md 模板,影响小)。其余 `§` / here-string 中文模板问题留独立任务卡。

- **修复**:3 处 em-dash `—` → ASCII `-`:
  - `engine/scripts/engine-doctor.ps1` L1318 `check_engineignore` 的 Write-Warn 文案(engine + plugin 镜像)。
  - `tests/workstream/test_engine_verify_env_cleanup.ps1` `Fail` 函数输出前缀。
- **验证**:实测 `鈥?` 乱码已消失;`test_engine_verify_env_cleanup.ps1` 2/2 PASS;`check.sh` CHECK PASSED。
- **未覆盖**(留独立任务):`engine-doctor.ps1` L768/L854 `§9`、`engine-migrate-contract.ps1` L308 `§2`、`engine-sync-agent-anchors.ps1` here-string `✓`/`—`/中文、`engine-migrate-contract.ps1` markdown 模板中文。

## v6.14.0 (2026-07-29)

双 issue 修复:T-054 (#18 pre-commit done-card drift)+ T-055 (#12 engine-verify.ps1 Windows bash 检测)。

### T-054: pre-commit AC PASS 只检查 active→done 转换(issue #18)

pre-commit hook L260-287 对所有 staged done 卡检查 AC PASS evidence,不区分「active→done 转换」与「已 done 卡修改」。bookkeeping 任务修改已 done 卡的 verify 命令后 re-verify 产生 content-drift FAIL,锁死提交,被迫 `--no-verify` 绕过(连带丢失 WRITE-SET/FORBIDDEN/protected/dist-stale 门禁)。

- **修复**:AC PASS 检查前加 HEAD status 比较。`git show HEAD:$task_path` 取 HEAD 快照,若 HEAD 已是 `status: done` 则 `continue` 跳过(已 done 卡修改,非转换)。HEAD 缺失(新卡)→ 不匹配 done → 检查 AC PASS(正确)。HEAD=active → 不匹配 done → 检查 AC PASS(正确)。
- **不影响**:exempt marker 仍被尊重;WRITE-SET/FORBIDDEN/protected/dist-stale 门禁是独立代码路径,不受影响。
- **测试**:`tests/workstream/test_precommit_done_card_drift.sh` 5 场景:active→done 检查 / 新卡首次 done 检查 / 已 done 修改跳过 / exempt 跳过 / 非 done 跳过。

### T-055: engine-verify.ps1 Git Bash 检测增强(issue #12)

engine-verify.ps1 L54-64 Git Bash 检测仅查 `C:\Program Files\Git\bin\bash.exe` + Get-Command bash(排除 WSL stub)。漏检 32-bit Program Files 路径、自定义安装路径、bash on PATH 是 WSL stub 但 Git Bash 存在于 git install dir 的场景。检测失败 → fallback `cmd /c` → 无 grep → AC verify 全 FAIL。

- **修复**:检测链从 2 步扩展到 4 步:(1) 标准 64-bit 路径(回归);(2) 32-bit `C:\Program Files (x86)\Git\bin\bash.exe`(`${env:ProgramFiles(x86)}` 优先,硬编码兜底);(3) Get-Command bash 排除 WSL stub(回归);(4) `git --exec-path` 反推 git install root → `bin\bash.exe`(git 几乎总在 PATH,exec-path 如 `...\Git\mingw64\libexec\git-core`,3 层 up 到 Git root)。每步失败静默继续,try/catch 包裹。
- **测试**:`tests/workstream/test_engine_verify_bash_detection.{sh,ps1}` 11 断言:标准路径回归 / (x86) 路径 / git --exec-path 反推 / try-catch 包裹 / Get-Command 回归 / WSL 排除回归 / 检测顺序。

## v6.13.1 (2026-07-29)

engine-verify.ps1 预防性修复(T-053)。T-051 CHANGE 记录的 `Remove-Item Env:` 在 TRAE `safe_rm_alias.ps1` 包装下失效的 bug,当前环境虽不复现,作防御性修复。

- **修复**:`engine-verify.ps1` 行 107 `Remove-Item Env:ENGINE_VERIFY_RECURSE_GUARD -ErrorAction SilentlyContinue` → `[Environment]::SetEnvironmentVariable('ENGINE_VERIFY_RECURSE_GUARD', $null, 'Process')`。.NET 原生方法完全绕过 PowerShell provider 机制,不被任何 alias 包装影响,在 PS 5.1/7+ 行为一致。
- **背景**:TRAE IDE 的 `safe_rm_alias.ps1` 包装 `Remove-Item`,不识别 `Env:` drive prefix,在 `$ErrorActionPreference = "Stop"` 下抛 terminating error 被 trap 捕获 → exit 1 → 任何 task verify 报错。当前 TRAE 环境疑似已修 `safe_rm_alias.ps1`,bug 不复现,但改用 .NET 原生方法作永久防御。
- **测试**:`tests/workstream/test_engine_verify_env_cleanup.ps1` 2 场景:env var 清除 + 递归守卫仍工作。

## v6.13.0 (2026-07-29)

`.engineignore` 项目级任务卡门禁旁路通道(T-052/D-036,issue #17)。非产品路径(跨 agent anchor、`engine update` 工具维护、项目级配置)免于任务卡 union 门禁,无需一次性任务卡或 `--no-verify`。

- **`.engineignore` 旁路**:repo 根新增 gitignore 语法文件,匹配路径旁路 pre-commit hook 的「无卡 block」(L179-192)和「union_allows WRITE-SET 检查」(L194-213)。匹配引擎复用既有 `match_any_glob`(shell `case` 的 `*` 跨 `/`),纯 shell 零子进程(issue 提案的 `git check-ignore --exclude-from` 不可行——该选项不存在)。
- **跳 WRITE-SET 不跳 FORBIDDEN**(修正 issue 提案漏点):新增 `union_not_all_forbidden` 函数。`.engineignore` 路径只跳 WRITE-SET 归属,仍受 FORBIDDEN 约束(全部卡都禁才拦)。issue 原案在 union 循环也 `continue` 会绕过 FORBIDDEN,违反自身声明的不绕过保护路径原则。
- **自身防护**:`.engineignore` 加入 `rules.json` protected_paths(改它需覆盖决策 D-036)+ doctor 内容告警(发现 `src/**`/`runtime/**`/`contract/**` 产品路径即 WARN)。
- **不绕过独立门禁**:protected-path 检查(L289-343)和 dist-stale 契约门禁(L353-387)是独立代码路径,`.engineignore` 不影响它们。
- **engine-init 模板**:`engine/skeleton/.engineignore` 注释模板(跨 agent anchor + engine 工具路径 + 项目配置),用户取消注释即用。
- **测试**:`tests/workstream/test_precommit_engineignore.sh` 7 场景 10 断言:无文件不旁路 / GEMINI.md 旁路 / 全卡禁仍拦 / 单卡禁放行 / protected 不绕过 / dist-stale 不绕过 / `**` 深层匹配。

## v6.12.3 (2026-07-28)

Pre-commit dist-stale 门禁(T-051)。v6.12.2 发版时直接编辑编译产物 `ENGINE_FILE_SYSTEM_v5.md` 未跑 `compile.sh` 导致 CI/Release 双红 + re-tag,本版在 pre-commit hook 加前置防线防止再次发生。

- **dist-stale gate**:pre-commit hook 检测 staged 含 `contract/src/**` 或 6 个 dist 文件之一时,运行 `ENGINE_COMPILE_OUT=/tmp/xxx bash contract/compile.sh` 编译到临时目录,diff 6 个 dist 文件的工作树版本与编译输出。任一不匹配 → FAIL,消息提示 `bash contract/compile.sh`。无契约文件 staged → 跳过(零开销)。compile.sh 自身失败 → WARN(fail-open)。
- **测试**:`tests/workstream/test_precommit_dist_stale.sh` 5 场景:源改未编译 FAIL / 直编 dist FAIL / 源改+编译 PASS / 无契约文件 skip / compile.sh 失败 fail-open WARN。

## v6.12.2 (2026-07-28)

Tombstone 生命周期双重 bug 修复(T-050/D-035)。共同根因:把「历史 transition 记录」当成「active 状态信号」治理。

- **A-1**:SessionStart hook 获取 fresh coordinator 锁时清理已存在的 tombstone(`coordinator-exited` / `stale-recovered` / `forced-replaced` 任一)——对称 Stop hook 写 tombstone 的逻辑。原先只有 `engine assume-coordinator` 命令清理,任何安静 24h+ 的仓库 Doctor 必 FAIL(本仓实证 36h 后触发)。sh+ps1。
- **A-2**:SessionStart hook 同 sid resume 路径也清理 tombstone。stale-recovery 路径保持原行为(覆盖写 `stale-recovered`)。
- **B-1**:Doctor `check_multi_session_isolation` 对 >24h tombstone 输出 WARN 而非 FAIL(cv ≥ 6.12.2)。tombstone 是历史 transition 记录,不是 active 状态信号——lock file + lease mtime 才是状态源。
- **B-2**:Doctor 消息删除 "exited abnormally" 误导措辞;新消息明确 tombstone 是 historical transition record、lock 是状态源、下次 coordinator 启动自动清理。
- **B-3**:迁移宽限:cv ∈ [6.11.0, 6.12.2) 保持旧 FAIL;cv < 6.11.0 保持 advisory WARN(fail-open)。
- **C-1**:契约 #17 同步重写:tombstone 是 historical transition records(NOT active-state signals);24h+ tombstone triggers WARN(auto-cleans on next coordinator start);SessionStart hook MUST 在 fresh coordinator acquisition 路径清理 tombstone。
- **C-2**:contract-version 升 6.12.2(engine/ENGINE_DOCTOR.md + plugin/engine/ENGINE_DOCTOR.md + migrator sh/ps1 ×2 镜像)。
- **D-1**:ENGINE_FILE_SYSTEM_v5.md + AGENT_ADAPTERS.md 文档同步 tombstone 生命周期说明。
- **测试**:`tests/multi-session/test_tombstone_lifecycle.sh` 19 例(AC-1~AC-5 覆盖):sh 6 + ps1 3(WSLENV 转发 CLAUDE_PROJECT_DIR)+ Doctor 10。

## v6.12.1 (2026-07-26)

Issue #11 门禁静默失效家族修复(T-049/D-035)。下游真实项目审计报告 9 项缺陷,共同失效模式:门禁看似在跑、报绿或报熟悉的红,实际检查的不是它声称的东西。修复原则:**门禁无法判定时显式说出来,不折叠进 PASS/SKIP**。

- **A-1**:`engine verify` 声明了 AC 但全部无法解析出 verify 命令时,不再静默输出 `0 pass, 0 fail, N skip`——stderr 显式 parse-failure 说明 + exit 3(区别于 AC fail 的 exit 1)。下游曾因此 18 张 done 卡零机器证据跑了 5 天无人察觉。
- **A-2**:verify 命令抽取锚定首个 `| verify:` / `→ verify:` 分隔符(两种野格式均收敛支持),命令体含字面 `verify:` 不再被贪婪截断。
- **A-3**:AC id 放宽字母分组 `AC-A1`/`AC-B12`/`AC-1.2`(verify + doctor)。
- **B-1**:engine-hook-stop parse_task_patterns 移植 T-043 三格式解析(inline / `## WRITE-SET` section / YAML frontmatter 多行)——只写 frontmatter(规范格式)的卡不再被 hook 误报 "no readable WRITE-SET" 而锁死全仓写入。sh+ps1。
- **B-2**:doctor code→INVENTORY 检查换统一解析器——原先只认 inline 拼法,对全部用 section/frontmatter 的项目**从未评估过任何一张卡**(空转多版本)。
- **B-3**:WRITE-SET 裸目录条目(`engine/evidence/T-049`)现匹配其子文件(hook + pre-commit + doctor)。
- **C-1**:status 检测全部改行首锚定 `^(> )?status:` ——原无锚全文 grep 会把散文中引用该模式的 done 卡钉成 active 并锁死全仓(下游三次踩中;本仓 T-049 卡自身也复现了一次)。sh+ps1 全站点(hook/session-start/context/pre-commit/engine bin/doctor)。doctor 新增同卡 active+done 冲突检查。
- **C-2**:done 卡治理新提交——上游 v6.11.6(T-044)已修,无需重复。
- **D-1**:migrator contract-version 改读 `engine/VERSION` 优先——原先偏好仓根 `VERSION`,产品仓被盖上产品版本号(下游实测 3.0.0),五代门禁静默降级到迁移宽限期。
- **D-2**:doctor INVENTORY 未初始化显式输出 SKIP (not initialized) 而非无声跳过;active 卡缺 DEAD-CODE.json 提示。
- **E-1**:AC 模板加「反套套逻辑三问」(契约源 + engine/tasks/README.md);`engine verify` 对可疑模式 WARN(自引用本卡 evidence 路径 / 全部 PASS 指纹皆空串哈希)。下游曾有 37 条 `test -f evidence/*.md` 型恒真 AC 全绿。
- **E-2**:doctor `${CI:-}`/`${GITHUB_ACTIONS:-}` 防 fresh worktree unbound 崩溃。
- **E-3**:doctor grep -c 多行结果整数比较修复。
- **附加**(本仓 T-048 撞到):doctor 未知 `--*` 参数显式报错退出,不再被静默当作 ROOT(`engine-doctor.sh --quiet` 曾因此报 ENGINE_MAP missing)。
- 测试:tests/multi-session 增 frontmatter/glob 前缀/status 锚定 3 件;tests/update-flow 增版本源 1 件;tests/behavior-verify 增 all-SKIP loud/解析硬化/恒真 WARN/doctor loud-skip 4 件。
- 详见 GitHub issue #11 + `engine/changes/CHANGE-2026-07-26-03.md`。

## v6.12.0 (2026-07-26)

多任务卡并行(union gating)+ 会话租约液性修复(D-035/T-048)。根治「激活一张任务卡后其他 agent 被全面拦截」的多会话撞车:

- **Union gating(RC-1)**:三层门禁(PreToolUse / Stop / pre-commit)从「字典序第一张 active 卡治理一切」改为收集全部 active 卡(+dirty done 收尾卡),路径 ∈ 任一卡 WRITE-SET 且 ∉ 该卡自身 FORBIDDEN 即放行;某卡的 FORBIDDEN 不再否决另一张卡的 WRITE-SET;拦截消息列出全部卡 id。
- **Bootstrap 恒豁免(RC-2)**:`engine/tasks/T-*.md` / `engine/decisions/D-*.md` 写入与提交不再被别人的 active 卡拦截——第二个会话可随时建/改自己的卡。
- **Protected 逐卡豁免(RC-5)**:pre-commit protected 检查从单一 exempt_id 改为「每张卡豁免自己」(active 或 staged-done);决策卡恒豁免;其余 protected 路径用覆盖它的卡的 decision 校验。
- **租约液性修复(RC-3)**:v6.11.0 lock 记录的是 hook shell 瞬时 pid(写完即死),`kill -0` 恒判 stale → 每个新会话都自封 coordinator,共享三件套保护实际空转(实证:本仓 tombstone 全是 stale-recovered)。活性改为租约:lock mtime 或持锁会话 `.hb` 心跳 mtime 在 `ENGINE_SESSION_TTL_MIN`(默认 120 分钟)内;PreToolUse 每次工具调用续租,guard 每轮续租,持锁会话顺手 touch lock。
- **写时验租约**:写共享单例(CONTEXT/HANDOFF/ENGINE_MAP 等)逐次验锁——持锁放行;他人租约 fresh 拦截(提示 `engine assume-coordinator`);free/stale 当场原子抢占(含残留 worker 旗标的自愈升格)。失联 coordinator 回来乱写的窗口关闭。
- **role 旗标生命周期(RC-3b)**:coordinator 上位(初次/同 sid 重入/stale 接管)一律删除自身 `.role=worker` 旗标;SessionStart GC 超 7 天孤儿 session 文件。修复 resume 会话被残留旗标永久钉死为 worker 的死锁。
- **worker 拦截面收窄(RC-4)**:一揽子 `is_shared_memory` 拆为共享单例 + 任务局部;干自己卡的顶层 worker 可直接写自己任务的 progress.md/checkpoint.md;worker 分片可挂在任一 active 卡下且校验后直接放行;同会话 subagent(agent_id)保持 v6.5 一揽子语义。
- **`engine assume-coordinator` 租约化**:stale 租约免 `--force` 直接接管(崩溃恢复主场景),fresh 才需 `--force`;tombstone 区分 stale-recovered / forced-replaced。
- **展示层多卡化**:guard 列全部 active 卡(id + GOAL);SessionStart 注入 ≤3 张全文(超出仅 header)+ 多卡提示。
- **测试**:新增 `tests/multi-session/` 套件(union/液性/旗标/写时验锁/worker 收窄/多卡展示,sh 48 例)+ `tests/task-card/test_multi_active_union.sh`(pre-commit 9 例);收编 v6.11.x 孤儿测试(double_signal/lock_recovery 等 5 份,原先不在 check.sh 链上)进新 runner;旧测试断言更新到租约语义(sh+ps1)。
- **契约**:`contract/src/30-operational.md` 多会话段净零改写(编译后 2910→2896 行,预算 2940 不动,13 规则不变);migrator AGENTS.md managed block 3 处 bullet 更新 + ENGINE_DOCTOR item 17 租约化;contract-version 升 6.12.0(< 6.12.0 老项目 fail-open 不变)。
- 固有边界:两张卡 WRITE-SET 交集路径的并发写不做机器仲裁(union 放行,git 层兜底);TTL 窗口内失联 coordinator 挡共享单例写,`--force` 兜底。
- 详见 `engine/decisions/D-035.md` + `engine/changes/CHANGE-2026-07-26-01.md`。

## v6.11.8 (2026-07-23)

- 修复 GitHub Actions CI Windows job 持续红灯 — `check.ps1` "Windows PowerShell compatibility" 步骤用 PS 5.1 `Parser.ParseFile()` 解析所有 .ps1 文件,PS 5.1 对无 BOM 文件按 Windows-1252 codepage 读取(非 UTF-8)。两个文件的**字符串字面量**含非 ASCII 字符,其 UTF-8 字节序列含 0x94(Windows-1252 左弯引号 `"`),被 PS 5.1 误认为字符串终止符,导致 parse 失败(T-047 patch)。
- AC-1 `engine/bin/engine.ps1` L537:em-dash `—` (U+2014) UTF-8 `E2 80 94`,byte 0x94 = `"` in Windows-1252 → 替换为 ASCII `-`。
- AC-2 `engine/scripts/engine-verify.ps1` L117:Chinese `锚` (U+951A) UTF-8 `E9 94 9A` 含 byte 0x94;L122 em-dash 同 AC-1 → 替换为 ASCII 等价物(`AC-level recovery anchor (compressed), see ...` / `Completed AC` / ASCII `-`)。注释中的 em-dash/Chinese 也一并清理(3 行,使文件 ASCII-only)。
- AC-3 plugin 镜像 `engine/bin/engine.ps1` + `engine/scripts/engine-verify.ps1` byte-identical(`diff -q` PASS,SHA256 MATCH)。
- AC-4 `bash scripts/check.sh` 全绿(0 failures)。
- 根因分析:PS 5.1 `Parser.ParseFile()` 对无 BOM 文件用系统默认 codepage(Windows Server US = Windows-1252)读取,而非 UTF-8。任何 UTF-8 字符含 byte 0x93/0x94(Windows-1252 弯引号)在字符串字面量中都会提前终止 string。`install.ps1` (ASCII-only) 已 PASS,`engine-doctor.ps1` (非 ASCII 仅在注释 + § 安全字符) 已 PASS,证明方案有效。注释中的非 ASCII 字符安全(PS 5.1 跳过注释字节)。
- 不改 .sh 双胞胎(engine-verify.sh 保留 Chinese,bash 不受 PS 5.1 影响);不改 .gitattributes;不改 check.ps1 的 compat 检查逻辑。
- 详见 `engine/changes/CHANGE-2026-07-23-06.md`。

## v6.11.7 (2026-07-23)

- 修复 GitHub Actions CI 自 v6.11.0 起持续红灯(10+ 次 consecutive failures)— engine-doctor.sh `check_multi_session_isolation` + engine-doctor.ps1 `Test-MultiSessionIsolation` 在 cv>=6.11.0 时硬 FAIL "`.cache/sessions` dir missing"(T-045 patch)。但 `.cache/sessions` 是 SessionStart hook 的运行时产物,CI 环境非交互式 agent 会话,SessionStart 永不运行;且 `.gitignore` 钉住 `engine/.cache/`,CI checkout 后目录永不创建 → 每次 CI 红灯。
- AC-1 `engine-doctor.sh` `check_multi_session_isolation`:检测 `$CI=true` 或 `$GITHUB_ACTIONS=true` 时 sessions dir missing 从 FAIL 降为 WARN,human 提示 "CI environment: SessionStart hook not expected to run, sessions dir absence is normal"。交互式环境行为不变(仍硬 FAIL)。
- AC-2 `engine-doctor.ps1` `Test-MultiSessionIsolation`:同样改 `$env:CI -eq 'true' -or $env:GITHUB_ACTIONS -eq 'true'`。
- AC-3 plugin 镜像 doctor sh+ps1 `diff -q` 一致(4 处)。
- AC-4 测试 `tests/workstream/test_doctor_ci_sessions.sh` 3 场景:(1) `CI=true` + 无 sessions dir → WARN 不 FAIL (2) 无 CI 变量 + 无 sessions dir + cv>=6.11.0 → FAIL(行为不变,交互式场景仍硬门禁) (3) `CI=true` + 有 sessions dir → PASS(不误报)。3/3 PASS。
- AC-5 完整发布门禁 `bash scripts/check.sh` 在 `$env:CI=true; $env:GITHUB_ACTIONS=true` 下:0 failures, 4 warnings(含新增 WARN for sessions-dir-missing-in-CI,符合预期)。
- 不改 ENGINE_DOCTOR.md managed block 描述(CI 降级是实现细节);不改 migrator;不改 pre-commit;不改其他 doctor 检查;不改 contract/src。本任务自身狗粮豁免(estimated_steps=5 ≤ 10, checkpoint_plan=inline),progress.md 仅填 §1+§4。
- `plugin/manifest.json` SHA256 更新:engine-doctor.sh `614e0c8e... → a767a8c1...`;engine-doctor.ps1 `afd5e65a... → bdc9a148...`(ps1 hash 手动修正匹配 staged blob)。
- 详见 `engine/changes/CHANGE-2026-07-23-04.md`。
- **T-046 (伴随修复)**: install.sh/install.ps1 的 FILES 数组与 plugin/manifest.json src 列表不一致(CI 红灯第二个根因)——manifest 有 61 条,installer 各只有 57 条,缺 4 条 skeleton 文件(checkpoint.md/progress.md/domains/INVENTORY.md/tasks/README.md,自 v6.7.0/T-032 起预存 bug)。同时修 installer case 语句的 blanket `engine/skeleton/*` 重映射 bug(只应重映射 ENGINE_MAP/CONTEXT/HANDOFF 三个文件)。`check.ps1` "manifest matches install.sh/ps1" 检查从 FAIL → PASS。详见 `engine/changes/CHANGE-2026-07-23-05.md`。

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
