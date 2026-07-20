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
8b. **核对 HANDOFF 历史归档**：HANDOFF.md「会话历史」表条目数 > 8 时,标记为 `handoff history overflow`,提示把最旧的整行迁移到 `engine/handoff-archive-YYYY-MM.md`。归档文件不进 §1 注册;裁剪只迁移整行,不删除内容。
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


## DEAD CODE DETECTION (v6.10.0+, D-028/T-035)

设计宗旨:把「agent 跑出从来没用上的死代码」做成机制——verify 调用原生 linter(shellcheck + PSScriptAnalyzer 优先,自研 grep 仅 fallback),反向调用点扫描(查 WRITE-SET 删改标识符在全仓的残留引用),未被引用输出 `evidence/T-NNN/DEAD-CODE.json`;WARN 升级为 done 门项(warn_count > 0 时 done 须架构师显式豁免)。不自研 AST 解析器(委托 shellcheck/PSScriptAnalyzer);不硬失败所有 WARN(只让 warn_count > 0 时 done 须豁免);不覆盖软死代码(冗余复刻,靠 INVENTORY 兜底);不引入跨语言别名表(镜像对死代码靠 linter 自身识别)。

### Linter 委托优先级(委托原生 linter,自研 grep 仅 fallback)

| 文件类型 | 首选 linter | 自检命令 | fallback |
|---------|------------|---------|---------|
| .sh | shellcheck | `command -v shellcheck`(sh)/ `Get-Module -ListAvailable PSScriptAnalyzer`(ps1 兜底 `Install-Module -Scope CurrentUser -Force -AllowClobber`) | 自研 grep `^function\s+\w+` + 全仓 grep 调用 |
| .ps1 | PSScriptAnalyzer (Invoke-ScriptAnalyzer) | 同上 | 自研 grep `function\s+\w+` + 全仓 grep 调用 |
| .md / .json | 跳过(无函数概念) | — | — |
| 其他 typed 语言(.ts/.py/.go 等) | tsc --noUnusedLocals / vulture / go vet 等 | `command -v` 自检 | 自研 grep |

verify MUST 在入口自检 linter 可用性。linter 不可用时降级 grep fallback,DEAD-CODE.json 顶层 `"linter": "grep-fallback"` 字段标记降级。ps1 端 MUST 含 `Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force -AllowClobber` 兜底,自检失败时尝试安装后重试。

### 反向调用点扫描(reverse call site scan)

verify MUST 实现反向调用点扫描:对 WRITE-SET 删改的标识符(函数名/类名/变量名),全仓 grep 是否有调用点(排除定义本身、注释、字符串字面量)。无调用点的标识符加入 DEAD-CODE.json `entries[]`,type=`reverse-call-site`,字段含 `identifier` / `referenced_in`(数组)。

实现步骤:
1. 解析任务卡 `WRITE-SET:` 行,枚举删改的 .sh / .ps1 / 其他 typed 文件。
2. 对每个文件,grep 出函数/类定义行(`^function\s+\w+` for sh; `function\s+\w+` for ps1)。
3. 对每个标识符,全仓 grep 是否有调用点(排除定义本身)。
4. 无调用点 → 加入 DEAD-CODE.json entries[]。

### DEAD-CODE.json 格式

```json
{
  "task": "T-NNN",
  "timestamp": "2026-07-20T12:00:00Z",
  "exempt_all": false,
  "exempt_reason": null,
  "linter": "shellcheck",
  "entries": [
    {
      "type": "linter",
      "file": "engine/scripts/engine-foo.sh",
      "line": 42,
      "severity": "warning",
      "message": "SC2086: Double quote...",
      "exempt": false,
      "exempt_reason": null
    },
    {
      "type": "reverse-call-site",
      "identifier": "old_function_name",
      "referenced_in": ["engine/scripts/engine-bar.sh:100"],
      "exempt": true,
      "exempt_reason": "library export, used by external callers"
    }
  ],
  "summary": {
    "warn_count": 2,
    "exempt_count": 1
  }
}
```

顶层 `exempt_all: true` + `exempt_reason: "<理由>"` = 批量豁免全部 entry(D-028 §9),`check_warn_done_gate` 优先读顶层,不需逐条标。per-entry `exempt: true` 是细粒度选项,可与顶层独立使用。

### COPY-PASTE.json 格式(jscpd 委托,D-028 §10 机制 B)

```json
{
  "task": "T-NNN",
  "timestamp": "2026-07-20T12:00:00Z",
  "tool": "jscpd",
  "jscpd_available": true,
  "duplications": [
    {
      "format": "sh",
      "lines": 50,
      "tokens": 300,
      "firstFile": { "name": "engine/scripts/foo.sh", "start": 10, "end": 60 },
      "secondFile": { "name": "engine/scripts/bar.sh", "start": 5, "end": 55 },
      "fragment": "...",
      "exempt": false,
      "exempt_reason": null
    }
  ],
  "warn_count": 0
}
```

`jscpd_available: false` 表示 jscpd 不可用,verify 降级到 skip + WARN(不计具体重复条目)。token 阈值与最小块长用 jscpd 默认。命中即计 `warn_count`,走现有 warn_count→done 门,不新增门级。

### WARN 升级为 done 门项(D-028 §9)

- verify 完成:`summary.warn_count == 0` → 自动通过(配合现有 fail_count=0 门)
- `warn_count > 0` → 须架构师在 DEAD-CODE.json 中标 `"exempt": true, "exempt_reason": "<理由>"`,或顶层 `"exempt_all": true, "exempt_reason": "<理由>"`(批量豁免)
- Doctor `check_warn_done_gate`(FAIL 级)读 evidence/T-NNN/DEAD-CODE.json:
  - `warn_count > 0` 且未全部豁免 → FAIL
  - `exempt_all=true` 或 per-entry exempt 全覆盖 → 不计 warn_count(通过)
  - 迁移宽限期(D-028 §9):读 `ENGINE_DOCTOR.md` 首行 `<!-- contract-version: X -->` 标记,`< 6.10.0` 时 FAIL 降级为 WARN(不阻塞 done);`>= 6.10.0` 时 FAIL(强制)

### 豁免场景(合理 WARN)

- 库项目导出未使用 API(public API 等外部调用,linter 抓不到)
- 测试 fixture 辅助函数(被测试反射调用,linter 抓不到)
- 动态调用(eval / `& $cmd` / 反射)— linter 抓不到,自研 grep 也抓不到,只能人工标注

### 显式不做

- 不自研 AST 解析器(委托 shellcheck/PSScriptAnalyzer)
- 不覆盖软死代码(换名重写、换实现重做)——靠 INVENTORY 人审兜底
- 不引入跨语言别名表(镜像对死代码靠 linter 自身识别)
- 不硬失败所有 WARN(只让 warn_count > 0 时 done 须豁免)


## MULTI-SESSION ISOLATION (v6.11.0+, D-029/T-036)

设计宗旨:把「多 Claude Code 实例并行抢写引擎记忆三件套(CONTEXT.md / HANDOFF.md / ENGINE_MAP.md)」做成机制——SessionStart hook 复用 Claude Code payload 已传入的 `session_id`,用 atomic 独占 lock file(`engine/.cache/session.lock`)分配协调者/worker 角色,第一个会话获协调者(写共享三件套),后续会话降级 worker(写 `engine/workstreams/<task>/<session-id>/` 隔离分片);PreToolUse 拦截扩展为双信号(`agent_id` 非空 **或** `.cache/sessions/<key>.role=worker`)。不撤销 v6.5 workstream 机制(同会话 subagent 隔离仍有效);不强制每会话用 git worktree(作为可选工作流);不引入跨进程分布式锁服务(违反 CLI-LEAN);不让协调者批量代理所有 worker 提交(避免单点阻塞);不引入自动 merge worker 分片(merge 仍是显式步骤,由 `engine merge-workstream <session-id>` 触发)。

### Atomic 独占 lock(无 TOCTOU)

| 平台 | atomic 操作 | 实现 |
|------|------------|------|
| POSIX (Linux/macOS) | `noclobber` 重定向(`set -C` 选项) | `( set -C; > "$LOCK" ) 2>/dev/null` |
| Windows PowerShell | `FileStream` with `FileShare.None` | `New-Object System.IO.FileStream($lock, 'Create', 'None')` |

lock file 路径 `engine/.cache/session.lock`,已被 .gitignore 第 2 行 `engine/.cache/` 覆盖,天然不进 git。格式单行 pipe-separated:`<pid>|<session_id>|<role>|<started_at_iso>|<task_id>`(与 .cache/sessions/ 风格一致)。`role` 字段值为 `coordinator` 或 `worker`。第一个会话用 atomic 操作独占创建 lock 获得「协调者」角色(写权限),可写共享三件套。

### 协调者/worker 角色分配

- **协调者(coordinator)**:第一个获得 lock 的会话,可写共享三件套(CONTEXT.md / HANDOFF.md / ENGINE_MAP.md)
- **worker**:后续会话 SessionStart 检测到 lock 已存在且 pid 存活,自动降级为 worker 模式,跑 `engine workstream T-NNN <session-id> --kind=session` 写 `engine/workstreams/<task>/<session-id>/` 隔离分片

SessionStart hook MUST 复用 Claude Code payload 中的 `session_id`(Stop hook 已在用,见 `engine-hook-stop.sh:191-197`),NEVER 重新生成。非 Claude Code 适配器 fallback 到 UUID v4(PS 5.1 `[guid]::NewGuid().ToString()`,Bash `uuidgen` 或 `/proc/sys/kernel/random/uuid`)。命名空间隔离:目录隔离(`engine/workstreams/<task>/sessions/<id>/` vs `engine/workstreams/<task>/agents/<id>/`)+ `s-`/`a-` 前缀约定(双轨制机器识别 + 视觉识别)。

### pid + StartTime 双信号比对(防 pid 复用)

pid 单信号在 Windows 不可靠(pid 复用风险)。SessionStart MUST 用 pid + StartTime 双信号比对确认 lock holder 存活:
- **POSIX**:`kill -0 <pid>` 检查 pid 存活 + `/proc/<pid>/stat` 第 22 字段 starttime 比对
- **Windows PowerShell**:`Get-Process -Id <pid>` 检查 pid 存活 + `.StartTime` 比对(精度到秒,容差 2 秒)

lock holder 已退出(pid 死)→ 当前会话可接管协调者,覆盖 lock + 写 tombstone `engine/.cache/session.tombstone`(含被接管 session_id + 时间戳)通知其他会话。lock holder 仍存活 → 当前会话降级 worker。

### PreToolUse 双信号拦截(扩展 v6.5 单信号)

v6.5 PreToolUse 拦截依赖 `agent_id` 单信号(`[ -n "$agent_id" ]`),对同会话派生 subagent 有效,对**独立顶层会话失效**(顶层会话的 agent_id 为空)。PreToolUse MUST 扩展为双信号:

```
[ -n "$agent_id" ] || [ -n "$ENGINE_SESSION_ROLE" -a "$ENGINE_SESSION_ROLE" = "worker" ]
```

`agent_id` 非空(subagent,走 v6.5 路径)**或** `.cache/sessions/<session_key>.role=worker` 文件存在(顶层会话降级为 worker)。命中任一信号即拦截 worker 写共享三件套,引导写 `engine/workstreams/<task>/<session-id>/` 分片。这是双信号扩展(扩展触发点 + 新增角色判定),非配置开关,不撤销 v6.5 协议。

### fail-open vs fail-closed 边界

| 项目契约版本 | SessionStart 检测到 lock 时的行为 |
|-------------|----------------------------------|
| `< 6.11.0`(老项目) | WARN 不强制 worker 模式(fail-open,与 D-028 §9 迁移宽限期一致) |
| `≥ 6.11.0`(新项目) | 强制 worker 模式(fail-closed) |

SessionStart hook 异常失败时,fail-open 走单会话路径(等同现状),Doctor 输出 WARN("SessionStart hook 异常,多会话隔离失效")。

### D-028 三文件 worker 写入边界(progress.md / INVENTORY.md / checkpoint.md)

D-025 v6.5 workstream 落地时 D-028 三文件还不存在,worker 写入边界清单未覆盖。本契约明确:

| 文件 | worker 模式写入位置 | 协调者 merge 时 |
|------|---------------------|-----------------|
| `engine/domains/<domain>/progress.md`(T-032) | `engine/workstreams/<task>/<session-id>/progress.md`(分片副本,7 栏结构同共享版本) | 读所有 worker 分片,§3/§5/§6/§7 按时间序追加合并;§1/§2/§4 由协调者重写 |
| `engine/domains/<domain>/INVENTORY.md`(T-033) | **不写**(worker 在分片 HANDOFF.md 的「Merge Notes」段记录「涉及哪些 INVENTORY entry / Feature 名 / Entry file 路径」) | 协调者读 worker 分片 Merge Notes,按 entry 合并到 `engine/domains/<domain>/INVENTORY.md`;merge 后跑一次 Doctor |
| `engine/domains/<domain>/checkpoint.md`(T-034) | `engine/workstreams/<task>/<session-id>/checkpoint.md`(分片副本,AC 状态表) | 读所有 worker 分片,按 AC-id 合并状态;冲突 AC(同 AC 不同状态)由协调者人审 |

### kill switch(逃生通道)

环境变量 `ENGINE_DISABLE_MULTI_SESSION=1` 或 `engine disable-multi-session` 命令切换全局 disable 标志文件 `engine/.cache/multi-session.disabled`。SessionStart hook 检测到 disable 标志时跳过 lock 检测,所有会话降级为单会话模式(等同现状,fail-open)。这是 v6.11.0 上线后若 lock 机制有 bug 阻塞所有并行开发时的逃生通道,与 fail-open 边界一致。

### 范围诚实(固有边界,无法 100% 解决)

- Windows pid 复用 + 任务管理器 kill 后 100% 自动恢复做不到,需 `engine assume-coordinator --force` 兜底
- Web 端 AI 无 hook 无 git,主线方案不适用,只能走 AGENTS.md 纯协议层
- B 档 CLI(Codex/Cursor/Aider)无 SessionStart hook,只能 pre-commit 兜底
- 协调者僵死检测:pid+StartTime 比对覆盖 95%+ 场景,极端情况(同秒 pid 复用 + starttime 精度不足)需 `--force` 强制接管

### 显式不做

- 不撤销 v6.5 workstream 机制(只扩展触发点 + 新增角色判定机制)
- 不强制每会话用 git worktree(作为可选工作流保留)
- 不引入跨进程分布式锁服务(redis / etcd / 文件服务器,违反 CLI-LEAN)
- 不让协调者批量代理所有 worker 提交(避免单点阻塞)
- 不引入自动 merge worker 分片(merge 仍是显式步骤,由 `engine merge-workstream <session-id>` 触发,语义冲突风险过高)


# ════════════════════════════════════════════
# END OF ENGINE FILE SYSTEM
# (版本号只在文件头部声明一处,尾部横幅不再重复——重复即漂移之源)
# ════════════════════════════════════════════
