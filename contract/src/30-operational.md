# ════════════════════════════════════════════
# OPERATIONAL HALF （运维：plan 约定 + 三种运维模式）
# 由 MODE DISPATCH 在已有 ENGINE_MAP 时进入。所有运维模式先读 ENGINE_MAP 取 profile。
# ════════════════════════════════════════════


## PLAN & SPEC TWIN CONVENTION （plan 与孪生件约定）


设计宗旨：plan 是架构师与 agent 做发散设计的地方，**约束索引、放开源头**——plan 正文完全自由，结构只存在于索引层（ENGINE_MAP）与那个轻量的、可校验的孪生件里。


### Plan 文件（自由）
- 位置：`engine/plans/PLAN-NN.md`
- **正文 100% 自由**：散文、对话、草图、任意结构。NO template。不要因为格式打断架构师的发散。
- 唯一的结构是一个极小的**身份头**，由 agent 在 INGEST 时**自动盖章**（架构师不用管）：
```
<!-- PLAN-NN | [标题] | status: proposed | source: [对话/上传文档] | created: [date] -->
```


### Spec Twin（与 plan 并列共生）
- 位置：`engine/plans/PLAN-NN.spec.md`（共享词干，twin 关系在文件名可见）
- 与 plan 同生命周期、同 ID，**随 plan 而生；无 plan 则无 twin**（小修小补不开 plan，直接在 SPRINT 任务内联验证）。
- 它是「怎么算做成了」的权威定义，也是 RECONCILE 的审计标尺（oracle）。
- 轻量清单，每条验收标准带 ID + 验证方式。v5.2 起，spec twin 有最低结构门槛；没有可执行验收标准的 plan 只能保持 `draft/proposed`，不得升 `active/done`：
```
# SPEC TWIN — PLAN-NN: [标题]
> 与 engine/plans/PLAN-NN.md 并列共生 | status follows PLAN-NN

## 验收标准 (Acceptance Criteria)
| ID | 标准（用户可见行为或系统不变量） | 验证方式 | 状态 | Evidence |
|----|----------------------------------|----------|------|----------|
| AC-1 | [做完后用户能做/看到什么] | [测试命令 / 可观察行为 / 人工检查] | [ ] 未验证 | [why pending / EVIDENCE:id] |
| AC-2 | ... | ... | [ ] | ... |
[新 AC 追加到表格末尾。AC 通过后改状态为 ✅，并记验证日期或 evidence id。]

## Verification Notes
- Last verified: [date or never]
- Cannot verify yet because: [if applicable]
- Required environment/data: [if applicable]
```


### 验证的单一真相源
- plan 驱动的 SPRINT 任务，其「验证方法」是**指针**：`verify → PLAN-NN.spec:AC-x`，NEVER 重述。
- plan 在 ENGINE_MAP §2 标 `done` 的充要条件：其 twin 全部 AC 状态为 ✅。
- 无 plan 的零散任务，验证方法内联写在 SPRINT 任务里（兜底）。
- 验证证据较长时写入 `EVIDENCE:<id>` 或 `engine/evidence/*.md/jsonl`，spec twin 只引用 evidence id。ENGINE_MAP/HANDOFF/CONTEXT 不复制长证据正文。


---


## OPERATIONAL MODES


### MODE — INGEST （录入一份新 plan）


触发：已有 ENGINE_MAP，架构师丢进/口述一份新的设计意图。


Routine:
1. **Read ENGINE_MAP** → 取 profile、现有 plan 最大 ID、关系图。
2. **落盘 plan**：在 `engine/plans/PLAN-NN.md` 存下架构师的自由正文，自动盖身份头（status: proposed）。NEVER 改写或结构化其正文。
3. **共生 spec twin**：与架构师讨论「怎么算做成了」，抽取验收标准写入 `engine/plans/PLAN-NN.spec.md`。
4. **抽取 deltas（带确认闸）**：从 plan + 讨论中抽取应进入执行层的增量——
   - ROADMAP：新里程碑 / 功能积压条目
   - SPRINT：新任务（「完成标准」+「验证方法」=指针指向对应 AC）
   - SYSTEM：新暂停点 / 危险命令 / 约束
   - PITFALLS：plan 中已知的风险预警
   - 锚点层：plan 触及的代码包，其 README 锚点「指针区」追加 `PLAN-NN` 引用
   每条增量打 `← PLAN-NN` 出处标记。
   **MUST 先把抽取出的 deltas 用人话列给架构师确认，再落盘。** 输入自由 + 输出确认，两头不牺牲。
5. **登记 ENGINE_MAP**：§2 加行（plan + twin + status）；§3.1 加行（派生条目 / 关联 AC / 触及模块）。
6. 若 plan 已开始实施，状态改 `active`。
7. 输出引擎文件变更摘要，bump 全局 revision。

**INGEST status gate (v5.2):**
- `draft` → only raw idea captured; no execution deltas.
- `proposed` → plan+twin exist, but architect has not accepted execution.
- `accepted` → architect accepts direction; can derive SPRINT tasks.
- `active` → at least one execution item exists and work has started.
- `done` → every AC in twin is ✅ with evidence.
Do not skip directly from `proposed` to `done`.


### MODE — EXTEND （新增或注册一种权威引擎文件类型）


触发：已有 ENGINE_MAP，需要一种现有类型之外的新权威引擎文件（如 DESIGN_SYSTEM.md、API_CONTRACT.md），或需要把环境适配文件纳入引擎系统。注：包级 README 锚点不走 EXTEND —— 它由触发条件自动生成并登记 §1.2；generated-cache、archive、外带/bootstrap 文件默认不走 EXTEND。Rename/move/split/merge/archive/delete 是 lifecycle transaction，按 SYSTEM「完整注册协议」处理，不伪装成新增文件。


Routine:
1. **Read ENGINE_MAP + read-gate**：读取 §0/§1/§1.1/§1.2/§4、ENGINE_DOCTOR.md、SYSTEM「引擎文件维护协议」、REPO_GUIDE「Engine File Maintenance」。
2. **Doctor-first maintenance check**：如果新增类型会改变注册路由、预算、stub purity、脚本检查范围或维护语义，先更新 `ENGINE_DOCTOR.md`，再更新 `engine/scripts/*`，最后继续 EXTEND。
3. **Classify before writing**：与架构师确认新增对象的用途、权威性、class、read priority、预算、更新者；先判断它是否真的属于 EXTEND：
   - authority engine file → 继续 EXTEND。
   - environment adapter → 继续 EXTEND，并计划更新 bootloader 指针。
   - package/root/agent anchor → 走锚点维护并登记 §1.2，不进 §1。
   - plan/spec → 走 INGEST，不进 EXTEND。
   - generated-cache → 写 `engine/.cache/*.generated.md`，不登记。
   - archive/bootstrap/external scratch → 默认不登记；除非架构师明确纳入本仓引擎。
   - rename/move/split/merge/archive/delete → lifecycle transaction，不创建重复“新版文件”。
4. **Generate skeleton**：生成新文件骨架，遵循语言策略、插入规范、文件预算；CLI-LEAN 下 derivable 内容必须 pure stub + recipe。
5. **Register route**：在 ENGINE_MAP 唯一正确位置登记：
   - §1 加 File/Class/Read priority/Revision/Last verified。
   - mixed 文件同步 §1.1 section 级类别。
   - 环境适配文件同步 bootloader/MAP 指针，根引导器不复制细则。
6. **Link without copying**：需要关联 SYSTEM/PITFALLS/ARCHITECTURE/plan 时，只写 ID、章节或路径指针；NEVER 复制正文到 MAP。
7. **Validate**：运行 `/engine-doctor` 或 `engine/scripts/engine-doctor.*`；若脚本缺失，先 `/engine-sync` 恢复。至少核对文件存在、class 合法、priority 无冲突、stub purity、预算、锚点/plan 不误登记、引用不悬空。
8. **Close**：更新 ENGINE_MAP §4 freshness/global revision、受影响文件 revision/date，输出引擎文件变更摘要和 `read-gate:` 已读证据。
> EXTEND 永不重跑采访；但也绝不只是“创建文件 + §1 加行”。未完成 classify/register/link/validate/close 的新增文件视为 partial registration。


### MODE — SYNC （旧项目升级：工具层 + 引擎契约迁移）


触发：已有 ENGINE_MAP，架构师请求更新 Engine System 工具/命令/脚本/Doctor 契约，或执行了 `engine update` 后需要把新机制迁移进已有引擎文件。SYNC 不是重新初始化；它必须保留项目已有 `SYSTEM.md`、`PITFALLS.md`、`CONTEXT.md`、`HANDOFF.md`、plans、架构决策和历史记录。


Routine:
1. **Read ENGINE_MAP first**：取得 profile、注册表、已有锚点/plan 状态；读取 `ENGINE_DOCTOR.md`、`SYSTEM.md`、`REPO_GUIDE.md`（若存在）和当前 `AGENTS.md`/`CLAUDE.md`。
2. **Update tooling layer**：优先运行 `engine update`；若不可用，则运行 `bash install.sh --update` 或 `powershell -NoProfile -File .\install.ps1 -Update`。这一步只更新命令、脚本、hook、CLI shim 和模板文件，不代表项目记忆已经迁移完成。
3. **Verify bundled tooling exists**：确认 `.claude/commands/engine-sync.md`、`engine/ENGINE_DOCTOR.md`、`engine/scripts/engine-doctor.*`、hook 脚本、`engine-sync-agent-anchors.*`、`engine/bin/engine*` 存在；缺失则记录 tooling drift 并补齐。
4. **Run contract migrator**：先运行随工具层分发的版本化迁移脚本，给旧项目写入 managed、可重复运行的当前契约区块，并生成 migration capsule：
   - macOS/Linux：`./engine/scripts/engine-migrate-contract.sh`
   - Windows：`.\engine\scripts\engine-migrate-contract.ps1`
   迁移脚本负责写入/更新 `AGENTS.md`、`engine/SYSTEM.md`、`engine/ENGINE_DOCTOR.md` 中的 `ENGINE_SYSTEM_CONTRACT_MIGRATIONS` 托管区块；项目专属规则保留在区块外。
5. **Apply contract migrations additively**：检查迁移脚本结果，并把当前 Engine System 机制迁移进已有引擎文件，NEVER 用模板全文覆盖项目记忆：
   - **v5.5 registration closure**：补 ENGINE_MAP 注册路由、§1/§1.1/§1.2/§2/§3/§4 事务闭环规则；脚本仍不登记为 authority。
   - **v6.5 workstream shards**：创建 `engine/workstreams/`;并行 worker 用 `engine workstream T-NNN <agent-id>` 写独立 CONTEXT/HANDOFF,协调者汇总根记忆；已有单线内容保持原样。
   - **v6.5 self-maintenance loop**：补全路径 WRITE-SET、UserPromptSubmit 短锚、PreToolUse 写前检查、session 归属 Stop、全路径 pre-commit 与 worker shared-memory block。
   - **v5.7 architect self-view**：补 `engine/changes/CHANGE-*.md` change capsule 规则，要求有意义改动说明 Goal、Actual Changes、Impact Scope、Risk、Verification、Rollback、Next Step、Responsibility Boundary；`/engine-status` 输出 Project Self-View。
   - **v5.7 acceptance evidence**：补 plan/spec `done` gate：每个 AC 必须有 spec Evidence、`engine/evidence/*` 或相关 change capsule 证据。
   - **Doctor parity**：确保 `ENGINE_DOCTOR.md` 记录语义热路径检查、change capsule 完整性、done plan 验收证据；脚本实现跟随契约。
6. **Migrate anchors**：运行 `engine-sync-agent-anchors.{sh,ps1}`，并确保 managed block 提到 read-gate、全路径写集、workstream 分片、协调者汇总和 change capsule。用户手写规则先吸收进 engine authority，再恢复薄指针。
7. **Verify migration capsule**：确认迁移脚本创建了 `engine/changes/CHANGE-[date]-[nn].md`，其中说明迁移了哪些机制、保留了哪些项目记忆、触碰了哪些文件、Doctor 结果、回滚方式和架构师待决策项。
8. **Update ENGINE_MAP freshness**：bump 全局 revision；更新 touched files 的 Last verified；§4 写短摘要和 migration capsule 指针，不写长证据。
9. **Run Doctor + Reconcile**：运行 `/engine-doctor`；再执行 RECONCILE 核对文档 vs 现实。Doctor warning/failure 必须进入报告；需要架构师拍板的修正先确认再落盘。
10. **Report**：输出中文摘要：工具层是否更新、旧项目迁移项是否应用（registration / multi-lane / self-maintenance / change capsule / acceptance evidence / Doctor parity）、保留的项目记忆、改动文件、migration capsule 路径、Doctor 结果和下一步。

SYNC 的成功标准：老项目不重跑 `/engine-init`，但新机制已经进入其现有 engine authority / anchors / Doctor 契约；下一次 agent 读旧项目引擎文件时，会按最新多 lane、自维护、change capsule 和验收证据规则工作。


### MODE — RECONCILE （对账：文档 vs 现实）


触发：架构师说「更新引擎」/「对账」，或怀疑文档过时，或多步 agent 跑完后例行核对。这是问题 2（设计↔实现审核）与问题 3b（漂移）的解。


Routine:
1. **Read ENGINE_MAP**（先于一切，re‑anchor）。
2. **Read-gate audit**：核对最近写操作或本轮候选写集是否读取了相关锚点、plan/spec、SYSTEM/REPO_GUIDE 章节；缺失时在报告中标记 `read-gate evidence missing`。
3. **核对完整注册**：
   - §1 登记的 authority engine files / `engine/agents/[ENV].md` 是否存在、class 合法、read priority 无冲突、revision/date 合理。
   - §1.1 是否覆盖所有 mixed 文件，且 section 分类与 CLI-LEAN 行为一致。
   - §1.2 锚点是否未误登记到 §1；含 `local-authoritative` 的锚点是否真的承载局部规则。
   - §2 plan/spec 是否未误登记到 §1；每个 registered plan 是否有 spec twin 或明确缺失原因。
   - `engine/.cache/*.generated.md`、`engine/archive/*`、外带/bootstrap 文件是否未误登记为 authority。
   - 若 `ENGINE_DOCTOR.md` 缺失或未登记，标记为 `partial registration`，建议通过 `/engine-sync` 恢复并登记。
   - 若 `engine/scripts/engine-doctor.sh` 或 `.ps1` 缺失，标记为 tooling drift；脚本不进入 §1，但必须随仓库打包恢复。
   - 若发现未登记的 `/engine/*.md` 正本文件，分类为：应登记 / 应归档 / 应标 cache / 应保持外部，并在报告中列出建议。
   - 双向一致性：registry → disk 无缺失；disk → registry 无未解释 authority-looking 文件。
   - 生命周期事务：rename/move/split/merge/archive/delete 后没有旧路径孤儿行、悬空正文指针或半迁移 archive。
4. **核对关系图 (§3)**：
   - 每条 plan→条目引用，目标是否仍存在（标记悬空引用 dangling refs）。
   - 重新生成 §3.2 反向索引（NEVER 手写）。
5. **核对验收 (spec twins)**：拿每个 accepted/active plan 的 twin AC，对照现实判断是否达成——
   - CLI‑LEAN：直接读代码 / 跑验证命令核对；若需要源码地图，生成 disposable `engine/.cache/*.generated.md` 或仅在本轮上下文中使用，不写回 SOURCEMAP 正文。
   - WEB‑FULL：给出只读验证命令请架构师执行，或依据已知信息判断。
   全部 AC ✅ 的 plan，§2 状态可升为 `done`。
6. **核对漂移**：
   - CLI-LEAN：derivable 文件/章节若出现 live file inventory、目录树、版本号、模块数量、配置值，标为 `stub contamination`，迁出为 generated-cache 或删除正文，只保留 recipe。
   - WEB-FULL：derivable 声明 vs 真实代码（如「SOURCEMAP 声称 src/foo.ts 存在，实际已删」），写入 §4 漂移警告。
7. **核对锚点层 (§1.2)**：
   - 引导器（CLAUDE.md / AGENTS.md）：是否仍指向 ENGINE_MAP、CLAUDE.md 与正本 AGENTS.md 是否一致、TOP RULES 摘抄与 SYSTEM.md 是否漂移；超过 45 行必须拆环境适配到 `engine/agents/[ENV].md`。
   - **吸收再指向**：引导器中出现的、引擎里没有的用户手写规则，MUST 提取吸收进对应引擎文件（SYSTEM / PITFALLS），再把引导器恢复为薄指针。NEVER 不经吸收直接删除用户手写内容。TOP RULES 中无 `source:` 标注的条目视为疑似原创规则，必须逐一核对：若在引擎文件中找到对应原文，补标注；若未找到，先吸收进引擎文件，再标注出处。
   - 包级锚点：「关键文件」表 vs 真实包结构；覆盖率（达到触发条件的新包是否缺锚点，已删除的包是否留有孤儿锚点登记）。
8. **核对文件预算**：按 PHASE 2 Initial File Budgets 检查；超限文件必须归档历史或拆分权威位置，不能继续堆叙述。
9. **核对 Engine Doctor Contract**：读取 `ENGINE_DOCTOR.md`，运行 `/engine-doctor` 或脚本；若脚本不存在，先建议 `/engine-sync`，并按 Doctor 契约手工打勾记录缺口；完整注册缺口必须标为 `partial registration`、`misregistered file`、`orphan reference` 或 `lifecycle transaction incomplete`。
10. **更新 ENGINE_MAP §4**：全局 revision、上次 RECONCILE 日期、悬空引用、漂移警告、read-gate evidence missing、file budget warnings、evidence index 指针。§4 不写长会话叙述。
11. 输出对账报告（中文）：一致项 / 漂移项 / read-gate 缺口 / partial registration / misregistered file / orphan reference / lifecycle transaction incomplete / stub contamination / 文件预算警告 / 悬空引用 / 锚点吸收与覆盖率结果 / 升为 done 的 plan / 需架构师决定的事项。架构师确认后落盘修正。


---


## 运维模式通用规则 (MUST)
- 每个运维模式 MUST 以「读 ENGINE_MAP」开始、以「更新 ENGINE_MAP + 变更摘要」结束。
- 会写文件的模式 MUST 在写入前执行 read-gate，并在报告里列出已读证据；只读 RECONCILE 至少核对 read-gate 规则是否存在且可执行。
- 回写任何引擎文件前 MUST re‑anchor（重读磁盘版本）。
- NEVER 在 ENGINE_MAP 中复制其他文件正文；只存关系与元数据。
- CLI-LEAN 下 NEVER 把现生代码地图写回 derivable 正文；只写 recipe 或 generated-cache。
- Long evidence belongs in spec twin evidence refs or evidence files, not ENGINE_MAP/HANDOFF/CONTEXT prose.
- 涉及强制暂停点（删文件、改 schema、加付费依赖等）时，按 SYSTEM.md 暂停并确认。
- 抽取/对账结果 MUST 用人话列给架构师确认后再落盘。


# ════════════════════════════════════════════
# END OF ENGINE FILE SYSTEM
# (版本号只在文件头部声明一处,尾部横幅不再重复——重复即漂移之源)
# ════════════════════════════════════════════
