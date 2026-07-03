# ENGINE_MAP — [Project Name]
> Last updated: [date] | Revision: 1 | 引擎系统的索引层。每次会话 MUST 最先读此文件。
> ⚠️ 本文件只记录关系与元数据，NEVER 复制其他文件的正文内容。它是 RECONCILE 的首要核对对象。


## 0. Profile（介质配置）
> 决定 agent 信任谁、加载谁、现生谁。切换介质只改本节，不动其他文件。

| 字段 | 值 | 说明 |
|------|-----|------|
| Active profile | [WEB-FULL / CLI-LEAN] | 来自 PRE‑INTERVIEW 选择 |
| 现生来源 (regen source) | [SOURCEMAP / 直接探测代码库] | CLI‑LEAN 下 derivable 内容从哪里重建；CLI-LEAN 必须为直接探测代码库 |
| Regen 命令前缀 | [e.g. rg / ls / cat —— 只读] | 重建 derivable 内容时允许的只读命令 |
| Derivable cache policy | [none / engine/.cache/*.generated.md] | CLI-LEAN 默认 none；若使用 cache，必须标 generated-cache 且不可作为权威 |

**知识类别 → 行为映射（强制）：**
- `irreducible` / `index` → 所有 profile 下常驻可信（always trust disk）
- `derivable` → WEB‑FULL：读并信任磁盘；CLI‑LEAN：忽略磁盘版本，按需从「现生来源」重建，NEVER trust the stale disk copy
- `mixed` → 按 §1.1 的 section 级类别分别处理
- `generated-cache` → 只作临时现生快照；不得登记为权威引擎文件，不得被后续 agent 当作事实来源

**读取流程（每次会话）：**
1. 读本 MAP → 取得 profile、文件注册表、锚点注册表、plan 注册表与 linkage recipe
2. 按上表映射决定：加载哪些文件、忽略并现生哪些
3. 按注册表 read priority 读取会话必需的 SYSTEM / CONTEXT / HANDOFF / REPO_GUIDE 等文件
4. 用一句中文复述对当前状态的理解；若架构师已明确要求动手，可继续执行

**开发前必读预检（Read-Gate，强制）：**
1. 先列出本轮候选写集或将要检查的路径；路径不确定时先只读探测，再回到本预检。
2. 对每个候选路径，读取 §1.2 中最近的已登记锚点；若锚点标注 `local-authoritative`，其局部规则视为权威。
3. 若任务涉及 plan / spec / AC / 架构决策，读取 §2 对应 plan 全文、spec twin，以及 §3 linkage 指向的执行层条目。
4. 若任务涉及测试、依赖、部署、危险命令、仓库规范或 engine 文件维护，读取 SYSTEM / REPO_GUIDE 中对应章节。
5. 开始编辑前在工作更新或最终报告中写一行 `read-gate:`，列出已读的关键文件/章节/锚点/plan id。
6. 写集变化时重新执行本预检；没有读到相关规则，不得声称规则不存在。


## 1. 文件注册表 (File Registry)
> 每个引擎文件登记一行。新增引擎文件 = 此表加行（EXTEND 模式的落点）。

| File | Class | Read priority | Revision | Last verified |
|------|-------|---------------|----------|---------------|
| ENGINE_MAP.md | index | 0 | 1 | [date] |
| SYSTEM.md | irreducible | 1 | 1 | [date] |
| CONTEXT.md | irreducible | 2 | 1 | [date] |
| HANDOFF.md | irreducible | 3 | 1 | [date] |
| ENGINE_DOCTOR.md | irreducible | 3.25 | 1 | [date] |
| REPO_GUIDE.md | irreducible | 3.5 | 1 | [date] |
| SPRINT.md | irreducible | 4 | 1 | [date] |
| ROADMAP.md | irreducible | 5 | 1 | [date] |
| PITFALLS.md | irreducible | 6 | 1 | [date] |
| ARCHITECTURE.md | mixed | 7 | 1 | [date] |
| SOURCEMAP.md | derivable | 8 | 1 | [date] |

[新引擎文件追加到表格末尾。删除文件时直接删行，并同步清理 §3 中对它的引用。]
[Solo/Small 模式跳过 ROADMAP / SOURCEMAP 时，相应行不登记。]
[环境适配文件仅在实际生成时追加登记，例如 `engine/agents/CODEX.md | irreducible | 9 | 1 | [date]`；未生成时不要保留占位行。]

**Class 定义：** 见主 prompt「KNOWLEDGE CLASS PRINCIPLE」。

**完整注册定义（强制）：** 引擎相关文件只有满足以下条件才算注册完成：
1. 已按类型放入正确注册表：authority engine file → §1；mixed section → §1.1；anchor → §1.2；plan/spec → §2；generated-cache 不登记；archive 只保留指针。
2. `Class` 与 profile 行为一致：CLI-LEAN 下 derivable 只能是 pure stub 或 recipe，不能存 live inventory。
3. `Read priority` 与会话加载顺序一致，且不与同优先级关键文件冲突。
4. `Revision` / `Last verified` 已更新；结构性变更已 bump §4 全局 revision。
5. 所有对该文件的引用只用路径、ID、章节号或 evidence/spec 指针；NEVER 把正文复制进 MAP。
6. 文件预算已检查；超限内容归档到 `engine/archive/` 并留下指针。
7. Engine Doctor Contract 能验证其存在、class、stub purity、引用和预算。

**注册路由表：**
| 新增对象 | 归属位置 | 必做动作 |
|----------|----------|----------|
| `engine/*.md` 权威引擎文件 | §1 | 加 File/Class/Read priority/Revision/Last verified；若为 mixed，同步 §1.1 |
| `engine/agents/[ENV].md` 环境适配 | §1 | class 通常为 `irreducible`；bootloader 只保留指针 |
| `engine/scripts/*` 维护脚本 | 不登记 | 随仓库/插件打包；契约来源是 `ENGINE_DOCTOR.md`；脚本变更必须更新 Doctor 契约或说明实现细节未变 |
| `AGENTS.md` / `CLAUDE.md` / 包级 README 锚点 | §1.2 | 标注类型、权威指向、Last verified；含局部规则时标 `local-authoritative` |
| `engine/plans/PLAN-NN.md` + spec twin | §2 | 加 plan 行；状态只用允许枚举；spec twin 缺失必须写明原因 |
| `engine/.cache/*.generated.md` | 不登记 | 标 `generated-cache` 和 disposable；使用前重建或核对 |
| `engine/archive/*` | 不作为热路径登记 | 活跃文件中保留 archive 指针；不可丢失 irreducible 历史 |
| 外带/bootstrap 文件 | 不登记 | 仅在架构师明确要求纳入本仓引擎时才登记 |

**注册闭环（写入前后都要做）：**
1. 写入前：re-anchor 读取当前 ENGINE_MAP，并执行 read-gate。
2. 写入时：生成/修改目标文件，同时同步对应注册表行。
3. 写入后：跑 Doctor 或手工核对注册路由、引用、预算、stub purity。
4. 收尾：更新 §4 freshness/revision，输出引擎文件变更摘要。

**生命周期事务（强制）：**
| 操作 | 必做动作 |
|------|----------|
| Create | classify → generate → register → link → validate → close |
| Rename / Move | 更新 §1/§1.2/§2 路径、所有指针、Last verified；不得保留旧路径孤儿行 |
| Split | 新文件按 class 注册；旧文件保留摘要/指针或归档；预算重新检查 |
| Merge | 选定 survivor；迁移 irreducible 内容；删除/归档被合并文件行；清理所有引用 |
| Archive | 移到 `engine/archive/`；活跃文件/§4 留指针；若不再是热路径 authority，从 §1/§2 移除或标 archived |
| Delete | 仅限 derivable/obsolete 或架构师批准；同一事务清理 §1/§1.1/§1.2/§2/§3 和正文指针 |
| Scope-externalize | 在会话报告说明“不纳入本仓引擎”；不得留下看似权威但未登记的热路径文件 |

**双向一致性检查：**
- Registry → disk：§1/§1.2/§2 登记路径必须存在，或明确 archived/superseded 且有活跃指针。
- Disk → registry：`engine/*.md` / `engine/agents/*.md` 中看似权威的文件必须已登记、已归档、已标 generated-cache，或已被架构师声明为 external。

### 1.1 Section 级类别（仅 mixed 文件）
> CLI‑LEAN 下，mixed 文件只保留 irreducible 章节，其余按需现生。

| File | Irreducible sections（常驻） | Derivable sections（CLI 现生） |
|------|------------------------------|--------------------------------|
| ARCHITECTURE.md | §0 产品简史, §6 关键架构决策, §7 数据约束与不变量 | §2 技术栈, §3 目录结构, §4 包地图, §5 数据流, §8 日志去向, §9 外部依赖 |

[新增 mixed 文件时追加一行。业务不变量始终算 irreducible，即使所在文件标记为 mixed。]


### 1.2 锚点注册表 (Anchor Registry)
> 锚点层文件（class: anchor），住在代码库约定位置而非 /engine/。RECONCILE 核对其存在性、指针有效性、与正本的一致性及覆盖率。

| Path | 类型 | 权威指向 | Last verified |
|------|------|----------|---------------|
| AGENTS.md | bootloader（正本） | engine/ENGINE_MAP.md, engine/SYSTEM.md | [date] |
| CLAUDE.md | bootloader（[import 引用 / 同步副本]） | AGENTS.md | [date] |
| [src/pkg-a/README.md] | package‑anchor | 指针区引用的 PITFALLS / ARCHITECTURE 条目 | [date] |

[未生成包级锚点时只登记前两行。新包锚点追加到表格末尾。删除包时删行。包锚点中若有「本包局部规则」作为权威知识，在「权威指向」列标注 `local-authoritative`。]


## 2. Plan 注册表 (Plan Registry)
> 每份 plan 作为完整文件存于 `engine/plans/`，与其 spec twin 并列共生。新 plan 录入 = 此表加行（INGEST 第一步）。

| ID | Title | Status | Plan path | Spec twin | 备注 | Last verified |
|----|-------|--------|-----------|-----------|------|---------------|
| [e.g. PLAN-01] | [标题] | [proposed / active / done / superseded] | engine/plans/[PLAN-01].md | engine/plans/[PLAN-01].spec.md | [如 superseded-by: PLAN-XX] | [date] |

[初始化时：若无正式 plan，写「无。Plan 通过 INGEST 模式录入。」]
[新 plan 追加到表格末尾。ID 按 PLAN‑[N+1] 递增。状态变更时直接改对应行。]

**Status 定义：**
- `draft` —— 尚未确认，只能作为草案材料
- `proposed` —— 已录入，尚未批准执行或尚未派生任务
- `accepted` —— 架构师已接受方向，但尚未开始执行
- `active` —— 已派生执行层条目，进行中
- `blocked` —— 当前无法推进；备注列必须写阻塞条件和需要谁决定
- `done` —— 已落实并通过验证：其 spec twin 关联的全部验收标准（AC）均验证通过
- `archived` —— 历史保留，不再执行
- `superseded` —— 被后续 plan 取代；备注列记 `superseded-by: PLAN-XX`，NEVER 删除原 plan 与其 twin

**Status 规则：** ENGINE_MAP §2 只允许以上状态。需要更细表达时写入 `备注` 或 plan 正文的 `substatus`，不要发明新的 registry status。


## 3. 关系图 (Linkage Graph)
> plan ↔ 执行层条目 ↔ 代码模块的连线。追溯「改 X 会牵连什么」的唯一权威来源。

### 3.1 Plan → 派生条目 / 验收标准 / 触及模块
| Plan | 派生的执行层条目 | 关联验收标准 | 触及的模块/目录 |
|------|------------------|--------------|------------------|
| [e.g. PLAN-01] | [e.g. ROADMAP:M5, SPRINT:TASK-12, SYSTEM:pause-7, PITFALLS:P008] | [e.g. PLAN-01.spec:AC-1, AC-2] | [e.g. payment/, checkout/] |

[初始化时为空或「无」。]
[plan 派生新条目时，在其行内追加。执行层条目用 `文件:锚点` 格式引用，NEVER 复制条目正文。]

### 3.2 反向索引（执行层条目 → 来源 plan）
> 由 RECONCILE 从 §3.1 自动生成。NEVER 手工双写 —— 双写即漂移源。

| 执行层条目 | 来源 plan |
|-----------|-----------|
| [auto-generated by RECONCILE] | |


## 4. 完整性与新鲜度 (Integrity & Freshness)
> RECONCILE 每次运行后更新本节。agent 读到陈旧/悬空标记时 MUST 对相关内容降权。

| 字段 | 值 |
|------|-----|
| 全局 revision | 1 |
| 上次 RECONCILE | 从未（初始化） |
| 悬空引用 (dangling refs) | 无 |
| 漂移警告 (drift) | 无 |
| Evidence index | 无；后续验证证据用 `EVIDENCE:<id>` 或 spec twin AC 状态引用 |
| File budget warnings | 无 |


## 5. 更新协议 (Update Protocol)

| 事件 | 在 MAP 中的动作 |
|------|------------------|
| 新增权威引擎文件 (EXTEND) | §1 加行；若为 mixed，§1.1 加行；§4 记录结构变更 |
| 新增环境适配文件 | §1 加行 + bootloader/MAP 指针；环境细则不塞进 AGENTS/CLAUDE |
| 新 plan 录入 (INGEST) | §2 加行（含 spec twin）；§3 写 linkage recipe/短指针，不复制 plan 正文 |
| plan 派生新任务/标准 | §3.1 对应行追加条目 |
| plan 状态变更 | §2 改对应行 |
| 切换介质 | 改 §0 Active profile |
| 新建代码包（达到锚点触发条件） | §1.2 加行 + 生成包级 README 锚点 |
| 生成 disposable cache | 不登记；只在 `engine/.cache/*.generated.md` 写 generated-cache 标记 |
| 归档热路径内容 | archive 文件不进热路径注册表；活跃文件/§4 留指针 |
| 重命名/移动引擎文件 | 同步 §1/§1.1/§1.2/§2 路径与所有指针；旧路径不得残留 |
| 拆分/合并引擎文件 | 新 survivor/新文件按 class 注册；被替代文件归档或删除行；保留 irreducible 历史指针 |
| 删除引擎文件/锚点/plan | 同一事务删除注册行、section 行、关系引用、正文指针；plan 删除优先 archived/superseded |
| 外带/bootstrap 文件 | 默认不登记；仅架构师明确纳入本仓引擎时按 class 路由 |
| 用户手写规则进 CLAUDE.md / AGENTS.md | RECONCILE 吸收进对应引擎文件后恢复薄指针，§1.2 更新 Last verified |
| 每次 RECONCILE | 校验 §1 / §1.2 / §2 / §3 vs 现实，更新 §4，重生成 §3.2 |

[新触发条件追加到表格末尾。]

**强制规则 (MUST / NEVER)：**
- MUST NOT copy any other file's body content into this file —— relationships and metadata only.
- MUST read this file's current on‑disk version BEFORE writing back to any engine file（re‑anchor，对抗多步 agent 的上下文压缩）。
- MUST read this file FIRST at the start of every session.
- The §3.2 reverse index is generated by RECONCILE; NEVER maintain it by hand.
- When deleting an engine file or plan, MUST purge every reference to it in §3.
- MUST bump 全局 revision (§4) on every structural change to the registry or linkage graph.
- ENGINE_MAP itself is `index` class —— ALWAYS persisted and read, under every profile.
- Anchor 文件 MUST 保持薄指针形态；RECONCILE 发现引导器膨胀或与正本漂移时，执行「吸收再指向」（见主 prompt ANCHOR LAYER）。
- Complete registration requires class routing + registry row + references + budget check + doctor validation + §4 freshness update; a created file without this closure is partial and must be fixed or explicitly left external.
- Lifecycle changes are atomic transactions: do not leave rename/split/archive/delete half-applied across disk, registries, and references.


✓ ENGINE_MAP.md complete.


---


### FILE 0.5 — ENGINE_DOCTOR.md
> Class: irreducible。引擎文件健康检查的权威契约；必须登记 ENGINE_MAP §1。脚本只是实现，住在 `engine/scripts/`，不登记为权威文件。


# ENGINE_DOCTOR — [Project Name]
> Last updated: [date] | Class: irreducible | This file is the authoritative maintenance spec for engine health checks.


## Scope
ENGINE_DOCTOR defines how the project validates the engine memory layer itself. It is an
engine authority file, not a disposable helper note. Register it in `ENGINE_MAP.md` §1.

The scripts in `engine/scripts/` are implementations of this spec. If this file and a
script disagree, update the script or this file through a lifecycle transaction; do not
silently treat the script as legacy.


## Maintenance Principle
- The source of truth for what exists is `ENGINE_MAP.md`, not a hard-coded file list.
- New authority files added through EXTEND must become visible to Doctor through the
  registry, class, priority, budget, and references.
- Scripts must be registry-driven where possible, so extension does not make Doctor stale.
- Generated cache and archive files are intentionally outside hot-path authority unless
  `ENGINE_MAP.md` explicitly says otherwise.


## Required Checks
1. `engine/ENGINE_MAP.md` exists and can be read first.
2. §1 registered authority files exist on disk, with legal class values and non-empty read priorities.
3. Disk authority-looking files under `engine/*.md` and `engine/agents/*.md` are registered,
   archived, generated-cache, or explicitly external.
4. Mixed files in §1 have section-level coverage in §1.1.
5. Anchors in §1.2 exist, except paths explicitly marked archived/superseded/external.
6. Plans/spec twins in §2 use only the allowed status vocabulary and have matching files.
7. `ENGINE_MAP.md` §3.2 is treated as generated from §3.1.
8. CLI-LEAN derivable authority files stay pure stubs: no live file inventory, directory tree,
   module count, version dump, or concrete config registry.
9. Bootloaders stay thin: target 30 lines, hard cap 45 lines.
10. File budgets are checked from the v5.5 budget table; over-budget authority files need an
    archive/split pointer.
11. Lifecycle transactions close both directions: registry to disk and disk to registry.
12. Long verification evidence stays in spec twins or `engine/evidence/*`, not in MAP,
    HANDOFF, or CONTEXT prose.
13. Recent write sessions should include `read-gate:` evidence in the final report or handoff.
14. Semantic memory checks warn when registered hot-path files exist but are not useful:
    `CONTEXT.md` needs a concrete status panel, `HANDOFF.md` needs a next-step resume
    pointer plus dated history, `PITFALLS.md` entries need trigger/scope/avoid/verify
    fields, and `SPRINT.md` should point to completion criteria and verification.


## Script Contract
Preferred commands:

```bash
./engine/scripts/engine-doctor.sh
```

```powershell
.\engine\scripts\engine-doctor.ps1
```

Exit codes:
- `0`: no hard failures
- `1`: one or more required checks failed

Warnings are allowed for conditions that need human review but do not prove broken state.


## Update Protocol
- When Engine System itself updates this contract, run `/engine-sync` in installed projects.
- `/engine-sync` updates command/script tooling, ensures this file is registered, runs Doctor,
  then reconciles project-specific engine files against the latest contract.
- If a project extends the engine with new file types, update `ENGINE_MAP.md` first; Doctor
  should discover the new file from the registry rather than from a script edit.
- If Doctor needs a new check, update this file first, then update scripts, then run
  `/engine-doctor` and `/engine-reconcile`.


### Bundled Script Files
During CLI/plugin INIT, write these helper files alongside the engine:
- `engine/scripts/engine-doctor.sh`
- `engine/scripts/engine-doctor.ps1`

These scripts implement the contract above. They are bundled tooling, not authority files,
so they are intentionally not listed in ENGINE_MAP §1.


✓ ENGINE_DOCTOR.md complete.


---


### FILE 1 — ARCHITECTURE.md
> Class: mixed（§0/§6/§7约束 = irreducible；§2‑5/§8/§9 = derivable）。CLI‑LEAN 下只生成 irreducible 章节，derivable 章节替换为现生说明行。


# ARCHITECTURE — [Project Name]
> Stage: [stage] | Last updated: [date]


## 0. 产品简史  [irreducible]
**为什么要做这个项目：** [来自 Block 0]
**用户核心操作：** [来自 Block 0 的三项操作]
**灵感与参考：** [来自 Block 0 第三问，如有]
> 本节帮助后续 AI 回溯产品初心，在技术抉择时不偏离用户体验。


## 1. 项目身份
[名称、代号、一句话描述、仓库位置、项目类型]


## 2. 技术栈  [derivable]
| 层级 | 技术 | 版本 | 说明 | 通俗解释（它是干嘛的） |
|------|------|------|------|------------------------|
[Fill from interview. 通俗解释由 AI 用简单语言概括。]
[新依赖追加到表格末尾。]


## 3. 目录结构  [derivable]
[ASCII tree with one‑line explanation per folder. Only include directories that exist. 对每个目录附带一句中文说明。]
[目录变更时直接修改对应行。新增目录追加到对应层级末尾。]
```
project-root/
├── src/           — [role]
│   ├── core/      — [role]
│   ├── api/       — [role]
│   └── utils/     — [role]
├── engine/        — 引擎文件与 plans/（AI 记忆系统）
├── tests/         — [role]
├── scripts/       — [role]
├── config/        — [role]
└── docs/          — [role]
```


## 4. 包/服务地图  [derivable]
[每个包/服务：名称、职责、通信方式，附带通俗解释]
[单包项目：「单包项目，无跨包通信。」]


## 5. 核心数据流  [derivable]
[用“用户眼光”描述：用户做了什么 → 界面如何变化 → 数据去了哪里 → 最终看到什么。附 ASCII 流程图。]
[交互式项目：用户操作 → 响应；管道式项目：输入 → 转换 → 输出]


## 6. 关键架构决策  [irreducible]
[编号列表。新决策追加到列表末尾。下一个编号：当前最大+1。]
1. **[决策]** → **原因：** [reason] → **后果：** [trade‑off，用通俗语言解释影响]


## 7. 数据模型  [混合：约束/不变量 = irreducible，schema 位置 = derivable]
[核心实体和关系，ASCII ER 图或表格]
[数据库类型、ORM、schema 位置、迁移策略]
[关键数据约束和不变量，使用中文明说 —— 这部分始终 irreducible]
| 实体 | 核心字段 | 关系 | 通俗含义 |
|------|---------|------|----------|
[e.g. User | id, email, role | has many → Posts | 系统的使用者 |


## 8. 日志与可观测性  [derivable]
[日志框架、日志级别、日志去向，附一句如何查看；监控/告警；错误上报]


## 9. 外部依赖  [derivable]
| 服务/API | 用途 | 是否必需 | 环境变量 | 通俗解释 |
|----------|------|---------|---------|----------|
[Fill from interview. If none: “无。”]


## 10. 快速启动
[从零到运行开发环境的完整命令，附每步作用说明]
```bash
git clone [repo]
cd [project]
[install command]   # 安装所有需要的工具包
[env setup if needed]  # 配置必要的环境变量
[migration command if needed]  # 初始化数据库结构
[dev command]   # 启动开发模式
```


---


### FILE 2 — CONTEXT.md
> Class: irreducible（项目当前状态，不可从代码重建）。


# CONTEXT — [Project Name]
> 快照日期：[date] | 每次会话开始时，读完 ENGINE_MAP 后优先阅读此文件。


## 状态面板
| 维度 | 状态 |
|------|------|
| 构建 | [✅ 正常 / ⚠️ 不稳定 / ❌ 损坏] |
| 上次完成 | [item] |
| 进行中 | [item；支持多 lane / 多 workstream] |
| 阻塞 | [list 或 无] |
| 产品目标完成度 | [主观百分比或描述] |

[状态面板每次会话检查并直接修改对应行。]


## 当前状态概述
[2‑4 句话描述项目此刻的状态。写给一个对此项目一无所知的冷启动 AI。简洁中文。]

## 并行工作流
| Lane | 目标 | 负责人 | 依赖 | 交汇点 | 下一检查点 |
|------|------|--------|------|--------|------------|
| L1 | [业务线/子目标] | [owner] | [依赖] | [merge point] | [next checkpoint] |
[多 lane 并行时，每条工作流单独占一行；无并行时可写一行主 lane 或写“无”。]


## 当前假设
[此刻为真但可能变化的事实。AI 基于这些假设做决策。]
- [e.g. “本地开发环境禁用了认证”]
- [e.g. “数据库使用 staging 实例，不是 production”]


## 运行时上下文
[影响代码行为的运行时事实。]
- [e.g. “Feature flag `new_checkout` 在生产环境为 OFF”]


## 常用请求翻译表
> 将日常业务语言映射到技术入口点。AI 每次会话后根据实际请求更新。
| 如果你说想要… | 实际需要动到的文件/地方 | 复杂度 | 备注 |
|---------------|--------------------------|--------|------|
| 改首页的标题文字 | src/pages/Home.jsx 第 12 行附近的 <h1> | 低 | 直接改文字即可 |
[新条目追加到表格末尾。高频条目可由 AI 调整到顶部。]


## 会话交接记录
[进行中的思路、半成品工作、待定决策]
[初始化时：「引擎文件首次生成。无先前会话上下文。」]
[每次会话结束时由 HANDOFF.md 的内容更新本节。]


## 最近完成的事项
[按时间倒序，最新在最上。超过 5 条时删除最旧的。]


## 已知不稳定项
[任何有缺陷或不稳定的部分，附怀疑原因。若无则写「无」。]


## 待解决问题
[编号：Q‑01, Q‑02...]
- [ ] [Q‑01] [问题] — 背景：[为什么重要]


---


### FILE 3 — SPRINT.md
> Class: irreducible（任务意图与验收，不可从代码重建）。


# SPRINT — [Project Name]
> 开始日期：[date] | 状态：进行中


[Solo/Small 模式：若 sprint 标记 N/A，写「无正式冲刺。当前工作参见 CONTEXT.md。」并跳到简化任务列表。]
[多 lane 模式：Sprint 是任务泳道表，不是单一 checklist。每个 lane 维护自己的目标、owner、阻塞与验证点。]


## 冲刺参数
| 参数 | 值 |
|------|-----|
| 冲刺开始 | [date 或 TBD] |
| 冲刺结束 | [date 或 TBD] |
| 重点 | [一句话冲刺目标，用业务语言] |


## 工作流泳道
| Lane | 目标 | Owner | 状态 | 阻塞 | 验证点 |
|------|------|-------|------|------|--------|
| L1 | [lane goal] | [owner] | [pending/active/blocked/done] | [blocker or 无] | [check / AC / file] |
[每个活跃 lane 占一行；不同工作流可并行推进，不必共享同一状态。]


## 优先级栈
[有序列表 — #1 是在完成之前唯一重要的事]
1. [TASK-01] [标题] — [一句话目标（业务语言）]
2. [TASK-02] [标题] — [一句话目标（业务语言）]
[新任务追加到列表末尾。调整优先级时重排整列并通知架构师。]


## 任务详情


### TASK-01: [标题]
- **用户可见的变化：** [做完后用户能做/看到什么不同]
- **完成标准：** [具体、可验证的完成条件，用行为描述]
- **验证方法：** [如何确认完成标准达成 —— 二选一：
  · plan 驱动的任务 → 指针，引用 spec twin 的验收标准，e.g. `verify → PLAN-03.spec:AC-2`（NEVER 重述，单一真相源在 twin）
  · 无 plan 的零散任务 → 内联写：测试命令 / 可观察行为 / 人工检查步骤]
- **约束：** [哪些地方绝对不能动，哪些功能不能受影响]
- **起点：** [从代码库的哪里开始 — 具体文件或目录，附解释]
- **前置依赖：** [开始前必须满足的条件]
- **风险：** [可能出什么问题]


---


### TASK-02: [标题]
- **用户可见的变化：** [同上]
- **完成标准：** [同上]
- **验证方法：** [同上]
- **约束：** [同上]
- **起点：** [同上]
- **前置依赖：** [同上]
- **风险：** [同上]


[新任务追加到本节末尾。下一个 ID：TASK‑[N+1]。任务之间用 --- 分隔。]
[已完成的任务：在标题后添加 ✅，保留详情供参考。完成前 MUST 跑「验证方法」并确认通过。]


## 阻塞中的任务
[新阻塞任务追加到本节末尾。解除阻塞后删除对应条目。]


## 本冲刺不做的事
[明确推迟的事项 — 防止范围蔓延]


---


### FILE 4 — ROADMAP.md
> Class: irreducible（长期意图与里程碑）。


# ROADMAP — [Project Name]
> 当前版本：[stage] | Last updated: [date]


[Solo/Small 模式：若 roadmap 标记 N/A，写「无正式路线图。目标在 SPRINT.md 中追踪。」并跳过其余。]
[多 lane 模式：ROADMAP 按里程碑分组，不要求单线推进；每个里程碑可以关联多个 lane，但只在交汇点同步。]


## 完成定义 (v1.0)
[5‑10 条“功能完整”的具体标准，用业务语言，如“用户可以注册、登录、发布带图片的文章”]
[新标准追加到列表末尾。已达成的保留并标记 ✅。]


## 里程碑地图
| ID | 里程碑 | 状态 | 目标时间 |
|----|--------|------|---------|
| M1 | ... | ✅ 完成 / 🔄 进行中 / 📋 计划中 | [date/quarter] |
[新里程碑追加到表格末尾。ID 按 M[N+1] 递增。]

## 里程碑泳道
| Lane | 关联里程碑 | 当前状态 | 交汇点 | 负责人 |
|------|------------|----------|--------|--------|
| L1 | [M1/M2...] | [active/blocked/done] | [merge point] | [owner] |
[当多个工作流共用同一里程碑时，在这里记录并行推进关系，而不是把它们合并成一个任务。]


## 里程碑详情


### M1: [里程碑名称]
- **目标：** [这个里程碑达成什么，用业务语言]
- **关键交付物：** [bullet list]
- **成功指标：** [怎么知道它完成了，用户能做什么]
- **已知风险：** [可能阻塞它的因素]
[新里程碑详情追加到本节末尾。]


## 功能积压
[按主题分组。编号：FB‑01... 新编号为当前最大+1。]
### [主题名称]
- [FB‑01] [功能描述] — [优先级：高/中/低]
[功能移入冲刺时，从积压中删除并创建 SPRINT.md 任务。涉及较大设计的，改走 INGEST 开 plan。]


## 已知的未来破坏性变更
[需要仔细迁移的重构或 API 变更]


## 明确不做的事
[不会构建的东西 — 防止功能蔓延]


---


### FILE 5 — PITFALLS.md
> Class: irreducible（踩坑根因，永久知识）。


# PITFALLS — [Project Name]
> [N] 条记录 | Last updated: [date]
> ⚠️ 修改代码库前必读。


## 严重程度说明
- 🔴 CRITICAL — 破坏构建或损坏数据。**现象**：应用直接崩溃或数据丢失。
- 🟠 HIGH — 难以调试的运行时错误。**现象**：功能不正常但无明显报错。
- 🟡 MEDIUM — 行为不正确或浪费精力。**现象**：代码能跑但不符合预期。
- 🔵 INFO — 造成困惑但不破坏。**现象**：开发时容易误解。


## 索引
| ID | 严重程度 | 标题 | 类别 | 状态 |
|----|---------|------|------|------|
[Fill from interview. 状态：Active / Resolved / Mitigated]
[新条目追加到索引表末尾。状态变更时直接修改对应行。]


## 条目


### P001 — [标题]
- **严重程度：** [level]
- **类别：** [tooling / deps / arch / api / config / data / testing / security]
- **状态：** [Active / Resolved / Mitigated]
- **你能观察到的现象：** [描述用户或开发者直接看到/遇到的情况]
- **根因：** [为什么发生]
- **错误做法：** [不要做什么]
- **正确做法：** [应该做什么]
- **触发条件：** [什么文件、命令、环境、用户操作会踩中]
- **影响范围：** [路径 / 模块 / 平台 / agent 类型]
- **验证方式：** [以后怎么确认没有再踩中]
- **发现时间：** [date 或「来自采访」]


[新条目追加到本节末尾。下一个 ID：P[当前最大+1]，补零到三位。]
[已修复的条目：将状态改为 Resolved，保留条目供参考。]


### 新条目模板：
```
### P[NNN] — [标题]
- **严重程度：** [🔴 CRITICAL / 🟠 HIGH / 🟡 MEDIUM / 🔵 INFO]
- **类别：** [tooling / deps / arch / api / config / data / testing / security]
- **状态：** [Active]
- **你能观察到的现象：** [描述]
- **根因：** [描述]
- **错误做法：** [描述]
- **正确做法：** [描述]
- **触发条件：** [描述]
- **影响范围：** [描述]
- **验证方式：** [描述]
- **发现时间：** [date]
```


## 反模式（通用）
[不适用于单一事件的更广泛坏模式]


## 绝对禁止
[零例外的硬规则 — 来自 Block G Q32]
- [ ] NEVER ...


## 更新协议
发现新陷阱时：
1. 分配下一个顺序 ID（当前最大 + 1，补零三位）
2. 在「条目」节末尾追加新条目
3. 在「索引」表追加新行，保持相同顺序
4. 更新文件头部的条目计数与日期


**非技术用户自然语言记录方式**：用户可直接说“记住，改头像功能时千万别动密码文件”，AI 自动转化为一个 Pitfall 条目并插入。


---


### FILE 6 — SYSTEM.md
> Class: irreducible（规则与协作协议）。


# SYSTEM — [Project Name]
> Last updated: [date] | 以下规则为强制执行，非建议。


## Prime Directives
[3‑5 条最高优先级规则，覆盖一切。绝对的，零例外。从项目愿景和协作原则推导。]
1. ALWAYS check what exists before implementing. Source‑first.
2. NEVER make silent assumptions. Ask before proceeding on unclear points.
3. MUST explain tradeoffs when multiple approaches exist. Recommend one, don't silently pick.
4. User‑facing behavior is the ultimate truth; technical implementation serves the vision.
5. Protect the integrity of the data and the build; no shortcuts that endanger them.
[新增 Prime Directive 需架构师批准。]


## 人机协作协议


### 角色定义
架构师（[developer name/alias]）：项目方向决策者和最终验收者。不要求编写实现代码。定义目标、功能体验、业务规则。审核影响用户可见行为的变更。
AI 工程师：负责所有技术实现、代码结构、工具选择。是自动化的执行官。


### 决策边界
**架构师决定：**
- [list from interview]
- 产品功能和用户体验方向
- 数据隐私/安全相关策略
- 是否引入新的外部服务或付费依赖


**AI 决定（无需询问）：**
- [list from interview]
- 具体代码实现方式
- 内部技术选型（不影响外部接口和性能的前提下）
- 代码风格、注释风格（除非架构师另有要求）
- 发现并修复 bug 的具体步骤


**不确定时：** 询问架构师。


### 强制暂停点
AI 在执行以下操作前 MUST 停止并确认：
- [ ] 删除或重命名文件
- [ ] 修改数据结构、schema 或存储格式
- [ ] 引入新的外部依赖（无论是否付费）
- [ ] 影响多个模块的大规模重构
- [ ] 任何可能破坏现有功能的操作
- [ ] 修改项目部署或启动方式
- [ ] 需要动到认证、支付或敏感数据相关代码
[新暂停点追加到列表末尾。]


### 变更前协议
每次修改前，AI MUST 说明（用中文）：
1. **改什么？**（哪个文件、哪个部分、什么逻辑）
2. **影响什么？**（触及或有风险的已有功能/模块）
3. **引入什么？**（新依赖、新模式、新文件 — 以及为什么）
4. **目的是什么？**（解决什么问题，用户会看到什么变化）
5. **风险是什么？**（可能破坏什么？有什么副作用？）


### 阻塞处理协议
AI 遇到无法解决的阻塞时：
1. 用中文描述阻塞是什么
2. 给出 2‑3 个处理选项，附各自权衡
3. 做出推荐并解释原因
4. 等待架构师决定后再继续
MUST NOT silently pick one and proceed on blocked or ambiguous decisions.


### 会话结束报告格式
每次工作会话结束后，AI MUST 按以下格式汇报（中文）：
✅ 完成内容 — [完成了什么，用户能看到什么变化]
⚙️ 实现方式 — [简要说明做了什么改动，为什么]
⚠️ 注意事项 — [已知脆弱点、限制、用户需注意处]
🔜 建议下一步 — [接下来应该做什么，为什么]
❓ 待解决问题（如有） — [需要架构师决定的未决事项]


### 语言规则
- 解释和沟通：[language from interview — 中文]
- 代码、注释、规则：English
- 文档叙述：[language — 中文]
- 文件名和标题：始终 English


### 工作流偏好
- Source‑first：实现前检查已有内容
- Incremental：小步骤、可解释的变更
- Communicate tradeoffs：有多个方案时解释并推荐，不默默选择
- No silent assumptions：不清楚时先问再做
- 为维护者解释：所有技术操作附一句通俗解释


## 工作流介质（由 ENGINE_MAP §0 的 profile 决定）


### WEB‑FULL（手动传递）
- 引擎文件存放在项目根目录 `/engine/`，plans 存于 `/engine/plans/`
- 每次会话开始时，将引擎文件内容发送到 Web AI 的上下文
- AI 无法直接访问代码库；derivable 内容信任引擎文件
- AI 完成后，开发者将更新后的引擎文件手动放回项目目录
- 需要查代码时，AI 给出只读命令，开发者执行后返回结果


### CLI‑LEAN（直接读代码）
- AI 可以直接读取项目文件
- 只信任 irreducible 引擎文件；derivable 内容按 ENGINE_MAP §0 现生来源现场重建，NEVER 信任其磁盘 stub
- 跳过命令‑粘贴流程
- 引擎文件格式不变，两种 profile 通用
- CLAUDE.md / AGENTS.md 引导器由 agent 工具自动注入，其唯一职责是把 agent 引到 ENGINE_MAP；进入大型代码包时先读该包根部的 README 锚点取局部地图。权威规则永远在引擎文件


### 会话加载流程
每次新会话时：
1. **先读 ENGINE_MAP.md** —— 取得 profile、文件注册表、锚点注册表、plan 注册表与 read-gate 规则
2. 按 profile 决定加载/现生哪些文件，阅读顺序按注册表 read priority：SYSTEM → CONTEXT → HANDOFF → SPRINT → (ARCHITECTURE/PITFALLS 按需) → ...
3. 若任务涉及某 plan，从 ENGINE_MAP §2/§3 查关联，读该 plan 全文 + spec twin + 关联执行层条目
4. AI 用一句通俗中文总结当前状态理解
5. 开发/编辑前按 ENGINE_MAP §0 执行 read-gate：根据候选写集读取相关包锚点、plan/spec、REPO_GUIDE/SYSTEM 章节，并在工作更新或最终报告中声明 `read-gate:` 证据
6. 开发者已确认或本轮已明确要求动手后开始工作


### 会话结束流程
每次会话结束时：
1. AI 按「会话结束报告格式」输出完成情况
2. **Re‑anchor**：回写任何引擎文件前，MUST 重读其磁盘当前版本（对抗多步运行的上下文压缩）
3. AI 输出所有引擎文件变更摘要
4. 更新 ENGINE_MAP（注册表 revision、关系图、若有结构变更则 bump 全局 revision）
5. 开发者确认后，手动/自动更新项目中的引擎文件，同步头部日期

> **v5.6 自维护循环：** 在 Claude Code 下，Stop hook 自动执行第 1‑4 步——若本次会话改动了代码但未回写引擎记忆，hook 拦截 agent 结束并要求先增量回写，然后再放行。同时 git pre-commit hook（B 层）在任何 agent、任何平台下做同样的检查。详见「自维护循环架构」章。


## 自维护循环架构 (v5.6)

Engine System 的"自动更新"在 v5.5 里是软契约——agent 被要求 `MUST 收尾回写`,但没有物理机制保证它必然执行。v5.6 把软契约变成硬执行,分三层独立兜底,任何一层失效都有另一层接着。

### 三层架构

| 层 | 机制 | 触发点 | 覆盖范围 | 强度 |
|----|------|--------|----------|------|
| **C · 原生 hook** | Claude Code SessionStart / Stop hook | 会话开始 / 每轮结束 | Claude Code | 体验最优 |
| **B · git pre-commit** | `.git/hooks/pre-commit` | `git commit` 时 | 任何 agent · 任何平台 | 硬门禁兜底 |
| **A · 锚点契约** | AGENTS.md SESSION PROTOCOL | agent 读引导文件时 | 所有读锚点的 agent + Web 端 | 覆盖最广 |

### C 层 · Claude Code 原生 hook（体验最优）

三个 hook 脚本随仓库分发(`engine/scripts/engine-hook-{session-start,stop,session-end}.{sh,ps1}`):

- **SessionStart「自动接手」**:开对话瞬间,脚本读取 CONTEXT.md 状态面板 + HANDOFF.md 最新交接行,注入 agent 上下文。架构师什么都不用说,agent 第一句就是准确的状态复述。
- **Stop「收尾守门员」(硬门禁)**:agent 每轮结束时,脚本用 `git status` 检查——若本轮改了代码但 CONTEXT.md / HANDOFF.md 没跟着更新,拦截 agent 结束(`decision: block`),要求先增量回写。仅拦截一次(`stop_hook_active` 防死循环),纯问答/工作区干净时不打扰。
- **SessionEnd「体检缓存」(非阻塞)**:Stop 放行后运行 Engine Doctor,将 warning/failure 写入 `engine/.cache/pending.txt` 与 `session-end-doctor.log`。下一次 SessionStart 会把 pending note 注入上下文,让 agent 先处理引擎漂移。

hook 配置通过 `.claude/settings.json` 随 `install.sh` / `install.ps1` 自动铺设。PowerShell 双版本(.ps1)覆盖 Windows 原生 PowerShell 执行场景。若目标项目已有 settings,安装器保留原文件,`/engine-sync` 负责合并 hook 字段。

### B 层 · git pre-commit（跨 agent 最大公约数）

`engine/scripts/githooks/pre-commit` 在 `git commit` 时检查暂存区:若本次提交有代码改动但没有同步引擎记忆(CONTEXT/HANDOFF/ENGINE_MAP),拒绝提交并提示先回写。逃生口:`git commit --no-verify`。

安装器会在 `.git/hooks/pre-commit` 不存在时自动安装该脚本；若已有 hook,保留用户 hook 并提示手动合并。它是唯一不需要 agent 配合的机制——无论用 Claude Code / Codex / Cursor / Aider / Gemini CLI 还是手敲,只要走 `git commit`,门禁就生效。纯 POSIX sh + git 自带 sh 执行,Linux/macOS/Windows 全覆盖。

### A 层 · 锚点契约（Web 端也吃得到）

AGENTS.md / CLAUDE.md 里的 `SESSION PROTOCOL` 是写给 agent 的强制契约。配合"增量回写"策略——每完成一个有意义的单元(一个功能/一次修复/一个决策)立即增量更新 CONTEXT 状态面板 + HANDOFF 追加一行,不等会话结束——Web 端 AI 即使没有 hook,也能靠契约保持引擎记忆新鲜。

### 跨 agent 适配

详见 `engine/AGENT_ADAPTERS.md`。核心策略:每个 agent 按能力自动享受对应层的兜底。

`engine/scripts/engine-sync-agent-anchors.{sh,ps1}` 负责把同一套薄引导块同步到 `.github/copilot-instructions.md`、`.cursor/rules/engine.md`、`GEMINI.md`、`.clinerules`、`.roorules`,并在缺失时生成 Aider starter config。同步块只放指针和会话契约;用户手写规则必须先吸收进 SYSTEM / PITFALLS / 其他权威引擎文件,再清理锚点。

| Agent | C 层(原生 hook) | B 层(git) | A 层(锚点) |
|-------|----------------|-----------|-----------|
| Claude Code | ✅ SessionStart+Stop | ✅ | ✅ AGENTS.md |
| Copilot CLI | ⚠️ 待适配 | ✅ | ⚠️ 待同步 |
| Codex CLI | ⚠️ 待核实 | ✅ | ✅ AGENTS.md |
| Cursor | ⚠️ 待适配 | ✅ | ⚠️ 待同步 |
| Gemini CLI | ❌ | ✅ | ⚠️ 待同步 |
| Aider | ❌ | ✅(自动 commit 触发) | ⚠️ 待配置 |
| Web 端 AI | N/A | N/A | ✅ 契约 |


## 文件编辑规则
[文件怎么修改？允许/禁止什么工具？有没有必须保护、不能直接编辑的文件（自动生成的）？]


## 依赖管理
| 规则 | 详情 |
|------|------|
| 包管理器 | [name and version] |
| 添加依赖 | `[exact command]` |
| 添加开发依赖 | `[exact command]` |
| 禁止 | [如「不要手动编辑 lockfile」] |


## 构建与运行命令
| 操作 | 命令 | 说明 |
|------|------|------|
| 安装 | [exact command] | 下载所有需要的工具包 |
| 开发 | [exact command] | 启动开发模式，实时预览 |
| 构建 | [exact command] | 打包成可发布版本 |
| 测试 | [exact command] | 运行自动化检查 |
| 部署 | [exact command] | 发布到服务器或托管平台 |
| 迁移 | [exact command if applicable] | 更新数据库结构 |


## 代码规范
[命名规范、import 排序、错误处理、日志、注释语言；如有 linter/formatter：名称和配置文件位置]


## 危险命令
⚠️ `[COMMAND]` — [为什么危险] — [安全替代或前置条件]
[新危险命令追加到本节末尾。]


## 测试策略
[提交前必须测试什么；测试框架和命令；明确排除在测试之外的内容]
> 注：具体功能的验收，由对应 SPRINT 任务的「验证方法」/ plan 的 spec twin 承载。本节是项目级的通用测试约定。

## Engine Doctor Contract
> v5.5 初始化时必须生成 `ENGINE_DOCTOR.md`。本节只保留指针；权威契约在 `engine/ENGINE_DOCTOR.md`，脚本实现随仓库打包在 `engine/scripts/`。

**Authority:** `engine/ENGINE_DOCTOR.md`

**Preferred commands:**
```bash
./engine/scripts/engine-doctor.sh
```
```powershell
.\engine\scripts\engine-doctor.ps1
```

**MUST validate:**
1. ENGINE_MAP §1 登记的每个 engine 文件都存在，class 合法，read priority 无冲突。
2. CLI-LEAN 下所有 `derivable` 文件/章节都是 pure stub，不含 live 文件清单、目录树、版本号、模块数量或配置值。
3. `AGENTS.md` / `CLAUDE.md` bootloader 不超过硬上限；超出环境细则必须外置到 `engine/agents/[ENV].md`。
4. 每个 registered plan 都有 spec twin；每个 spec twin 至少有 AC id、验证方式、状态、最后验证日期或未验证原因。
5. ENGINE_MAP §2 plan status 只使用允许枚举。
6. ENGINE_MAP §3.2 可由 §3.1 重建；禁止手写漂移。
7. ENGINE_MAP §4 只放短状态、警告和 evidence/spec 指针，不放长会话叙述。
8. 文件预算超限时必须有 archive 指针，不能静默膨胀。
9. 锚点注册表里的 README/bootloader 路径存在；已删除包不能保留孤儿锚点登记。
10. 完整注册路由正确：authority engine files 在 §1，mixed sections 在 §1.1，anchors 在 §1.2，plans/spec twins 在 §2，generated-cache/archive/bootstrap 文件未误登记为权威。
11. 生命周期事务闭合：rename/move/split/merge/archive/delete/scope-externalize 后，磁盘、§1/§1.1/§1.2/§2/§3、正文指针和 §4 freshness 一致。
12. 双向一致性成立：registry → disk 无缺失；disk → registry 无未解释的 authority-looking 文件。
13. 最近一次有写操作的会话必须能说明 read-gate 覆盖了已编辑路径：至少列出 ENGINE_MAP、相关锚点、相关 plan/spec、SYSTEM/REPO_GUIDE/ENGINE_DOCTOR 章节；缺失则标记为 `read-gate evidence missing`。
14. 最近一次有意义的代码/文档/工具/依赖/测试/行为改动应有 `engine/changes/CHANGE-*.md` change capsule；缺失则标记为 `missing change capsule`。
15. Change capsule 必须包含 Goal、Actual Changes、Impact Scope、Risk & Watchpoints、Verification、Rollback、Next Step、Responsibility Boundary；缺项或占位符未替换则 warning。
16. 标记为 `done` 的 plan/spec twin 必须能指向验收证据：spec twin Evidence 列、`engine/evidence/*` 或相关 `engine/changes/CHANGE-*.md`。

If the scripts are missing, run `/engine-sync` to restore bundled tooling. If the contract changes, update `ENGINE_DOCTOR.md` first, then update scripts, run `/engine-doctor`, and finish with `/engine-reconcile`.


## Git 与版本控制
[分支命名规范；提交消息格式；绝对不能提交的内容（.env、密钥、大文件）]


## 安全边界
[来自 Block I 或 Block H Q48]
- 认证模型：[summary 或「无」]
- 密钥管理：[方式]
- AI 禁区：[AI 绝对不能碰的文件/目录/操作]
- 敏感数据：[存在什么、如何保护]
[安全边界变更需架构师批准。]


## AI Agent Rules
**ALWAYS:**
1. [rule]
2. [rule]
3. [rule]
[新 ALWAYS 规则编号从 4 开始递增。]


**NEVER:**
1. [rule]
2. [rule]
3. [rule]
[新 NEVER 规则编号从 4 开始递增。]


**When uncertain:** [specific fallback, e.g. “询问架构师，不要猜测，并给出通俗解释为什么不确定”]


## 引擎文件维护协议


### 维护者
- 架构师：[name]：审核变更、批准重大修改、记录非技术性陷阱
- AI 工程师：执行日常更新、从自然语言提取并结构化陷阱、更新交接文件、维护 ENGINE_MAP
- 重大变更需架构师确认


### 维护的极简方式
架构师（即使非技术）仅需关注：
- **CONTEXT.md** 的「状态面板」：用一句话告诉 AI “现在什么进度”
- **SPRINT.md** 的「优先级栈」：用业务语言描述最想做的事
- 想做新的大东西时直接聊设计 → AI 走 INGEST 开 plan + spec twin
- 遇到新坑时说：“记住，[现象和正确做法]” → AI 自动写入 PITFALLS.md
其余由 AI 自动维护。


### 更新触发条件
| 事件 | 需要更新的文件 | 更新者 |
|------|--------------|--------|
| 每次开发会话结束 | HANDOFF.md, ENGINE_MAP（revision） | AI（v5.6：Claude Code 下 Stop hook 自动触发；跨 agent 靠 git pre-commit 兜底） |
| 每次开发会话中完成一个有意义单元（功能/修复/决策） | CONTEXT.md（状态面板增量更新）, HANDOFF.md（追加一行）, `engine/changes/CHANGE-*.md`（目标/影响/风险/验证/回滚/责任边界） | AI（v5.7：增量回写 + 架构师可读 change capsule） |
| 每个冲刺结束 | CONTEXT.md, SPRINT.md | AI，架构师审核 |
| 里程碑达成 | ROADMAP.md, CONTEXT.md | AI，架构师审核 |
| 发现新陷阱（自然语言） | PITFALLS.md（追加） | AI 从描述生成 |
| 架构变更 | ARCHITECTURE.md, SOURCEMAP.md | AI 提议，架构师批准 |
| 依赖/工具链变更 | SYSTEM.md | AI 提议，架构师批准 |
| 录入新 plan | engine/plans/, ENGINE_MAP §2/§3 | INGEST 模式 |
| 新增权威引擎文件 | 新文件 + ENGINE_MAP §1（mixed 还要 §1.1） | EXTEND 模式 |
| Doctor 契约/维护语义变更 | ENGINE_DOCTOR.md + engine/scripts/* + ENGINE_MAP §1/§4 | 先更新契约，再更新脚本，运行 /engine-doctor |
| Engine System 仓库/插件更新 | /engine-sync 更新命令与脚本；Doctor + RECONCILE 校验本项目引擎文件 | AI，架构师审核 |
| 新增环境适配文件 | engine/agents/[ENV].md + ENGINE_MAP §1 + bootloader 指针 | EXTEND 或锚点维护 |
| 新建代码包（达锚点触发条件） | 包级 README 锚点 + ENGINE_MAP §1.2 | AI |
| 用户手写规则进 CLAUDE.md / AGENTS.md | 对应引擎文件（吸收）+ 引导器恢复薄指针 | RECONCILE 模式 |
| 对账 / 「更新引擎」 | ENGINE_MAP §3.2/§4 + 受影响文件 | RECONCILE 模式 |
| 项目方向调整 | ROADMAP.md, SPRINT.md, CONTEXT.md | 架构师主导 |


### 更新规则
- PITFALLS.md：只追加，不删除。已修复标记 Status: Resolved
- ARCHITECTURE.md：每次架构变更后更新（CLI‑LEAN 下仅 irreducible 章节）
- HANDOFF.md：每次会话结束后重写
- ENGINE_MAP.md：任何结构性变更（注册表/关系图）后更新，并 bump 全局 revision
- ENGINE_DOCTOR.md：任何维护语义、注册路由、预算或检查范围变更后先更新本文件；脚本跟随契约，不反向成为权威
- engine/scripts/*：随仓库打包；不登记为权威文件；脚本缺失或落后时运行 `/engine-sync`
  - `engine/scripts/engine-hook-session-start.{sh,ps1}`：SessionStart「自动接手」hook 脚本
  - `engine/scripts/engine-hook-stop.{sh,ps1}`：Stop「收尾守门员」hook 脚本
  - `engine/scripts/githooks/pre-commit`：git pre-commit「B 层」门禁脚本
  - `engine/scripts/engine-doctor.{sh,ps1}`：引擎健康检查脚本
- 锚点文件：MUST 保持薄指针形态；包结构变化时同步对应包 README 锚点；引导器只在 SYSTEM.md Prime Directives 变更时同步摘抄
- 其他文件：增量更新
- **Re‑anchor 强制**：回写前 MUST 重读目标文件的磁盘版本
- 所有文件头部日期 MUST 同步更新


### 完整注册协议
新增、迁移、拆分、归档任何引擎相关文件时，AI MUST 先判断文件身份，再写入对应注册位置：

| 对象 | 是否权威 | 注册位置 | 额外要求 |
|------|----------|----------|----------|
| `engine/*.md` 正本 | 是 | ENGINE_MAP §1 | class/read priority/revision/date 必填；mixed 文件同步 §1.1 |
| `engine/agents/[ENV].md` | 是 | ENGINE_MAP §1 | 根引导器只放指针，不复制环境细则 |
| `engine/ENGINE_DOCTOR.md` | 是 | ENGINE_MAP §1 | 引擎维护契约；脚本必须服从它 |
| `engine/scripts/*` | 否 | 不登记 | 随仓库打包的实现；缺失时 `/engine-sync` 恢复 |
| `engine/changes/CHANGE-*.md` | 证据 | 不登记 §1 | 架构师可读的改动胶囊；由 HANDOFF / ENGINE_MAP §4 / spec Evidence 引用 |
| `AGENTS.md` / `CLAUDE.md` | anchor | ENGINE_MAP §1.2 | 保持薄引导器；规则先吸收进 SYSTEM/PITFALLS 再指向 |
| 包级 README 锚点 | anchor | ENGINE_MAP §1.2 | 标注是否 `local-authoritative`；包结构大改后同步 |
| plan + spec twin | plan authority | ENGINE_MAP §2 | plan 保留原意；spec 至少有 AC、验证方式、状态 |
| `engine/.cache/*.generated.md` | 否 | 不登记 | 标 `generated-cache` / disposable；使用前重建或核对 |
| `engine/archive/*` | 历史证据 | 不进热路径注册表 | 活跃文件留指针；不能删除 irreducible 历史 |
| 外带/bootstrap 文件 | 默认否 | 不登记 | 只有架构师明确纳入本仓引擎时才登记 |

完整注册闭环：
1. Read-gate：读取 ENGINE_MAP、相关维护规则、相关锚点/plan/spec。
2. Classify：判定 `index / irreducible / derivable / mixed / anchor / generated-cache`。
3. Register：同步 §1 / §1.1 / §1.2 / §2 中唯一正确的位置。
4. Link：只写路径、ID、章节、evidence/spec 指针；NEVER 复制正文。
5. Budget：检查文件预算；超限先归档再留指针。
6. Validate：运行 doctor 或按本清单手工核对。
7. Close：更新 ENGINE_MAP §4 freshness/revision、受影响文件 revision/date，并输出引擎文件变更摘要。

生命周期事务：
| 操作 | 收口要求 |
|------|----------|
| Create | 新文件存在，注册表有且仅有正确一行，引用/预算/doctor 均通过 |
| Rename / Move | 新路径已写入所有注册表与正文指针；旧路径无孤儿引用 |
| Split | 新文件分别注册；旧文件只保留索引/指针或归档；irreducible 历史不丢失 |
| Merge | survivor 明确；被合并文件的注册行删除或归档；引用全部指向 survivor |
| Archive | archive 文件不再作为热路径 authority；活跃文件或 §4 留可追溯指针 |
| Delete | 同一事务删除磁盘文件、注册行、section 行、关系引用和正文指针；重大删除先获架构师批准 |
| Scope-externalize | 明确报告“外部/不登记”原因；RECONCILE 不应把它误判为漏登记 |

双向一致性：
- Registry → disk：ENGINE_MAP 登记的路径必须存在，或明确 archived/superseded/external。
- Disk → registry：`engine/*.md` / `engine/agents/*.md` 中看似权威的文件必须能在注册表、archive/cache 规则或外部声明中解释。


### 审核机制
AI 完成引擎文件修改后，MUST 输出变更摘要供架构师审核（中文）：
```
## 引擎文件变更摘要
| 文件 | 变更类型 | 变更内容 | 原因 |
|------|---------|---------|------|
| [file] | [新增/修改/删除] | [简述] | [why] |
```
架构师确认后变更生效。涉及以下内容需格外标注：删除已有内容、修改 Prime Directives、修改 Decision Boundaries、修改安全章节、新增或删除整个章节、修改 ENGINE_MAP §0 profile。


### 何时需要重新初始化（回到 INIT）
- 技术栈整体迁移
- 项目类型变更
- 团队结构变更
- 引擎文件严重过时（超过 3 个月未更新且架构已大变）
重新初始化时：重走 INIT 流程，可跳过不变的部分。常规演进用 INGEST/EXTEND/RECONCILE，NEVER 重跑采访。


---


### FILE 7 — REPO_GUIDE.md
> Class: irreducible。项目级开发规则权威位置；SYSTEM 只保留跨仓库协议，具体命令、测试、依赖、发布、平台和 engine file maintenance 写在这里。


# REPO_GUIDE — [Project Name]
> Last updated: [date] | 仓库开发规则、命令、测试、发布与引擎文件维护细则。


## Scope
- 本文件是仓库级开发规范权威来源。
- SYSTEM.md 只保留跨项目工作协议和 Prime Directives；具体命令、平台 playbook、测试矩阵、依赖策略写在本文件。
- Agent 修改代码/docs 前，按 ENGINE_MAP §0 read-gate 读取本文件相关章节。


## Repository Commands
| 操作 | 命令 | 说明 |
|------|------|------|
| 安装 | [exact command] | 下载依赖 |
| 开发 | [exact command] | 启动开发模式 |
| 构建 | [exact command] | 生成发布产物 |
| 测试 | [exact command] | 运行默认测试 |
| 格式检查 | [exact command] | 代码/文档格式 |
| Lint | [exact command] | 静态检查 |


## Dependency Management
| 规则 | 详情 |
|------|------|
| 包管理器 | [name/version or source] |
| 添加依赖 | `[exact command]` |
| 添加开发依赖 | `[exact command]` |
| Lockfile | [允许/禁止手改规则] |


## Coding Style
[命名、import、错误处理、日志、注释语言、formatter/linter 配置位置。]


## Testing Guidelines
[测试框架、默认命令、覆盖率要求、慢测/集成测/live test 触发条件。]


## Git / PR / Release
[提交、PR、changelog、发版、平台 smoke 的仓库级规则。]


## Security / Configuration
[密钥、真实数据、危险环境变量、发布凭据、AI 禁区。]


## Engine File Maintenance
- Before editing engine files, read ENGINE_MAP §0/§1/§1.1/§1.2/§4, ENGINE_DOCTOR.md, SYSTEM「引擎文件维护协议」, and this section.
- A file exists is not enough. Complete registration requires: class routing, registry row, references, budget check, Doctor validation, and ENGINE_MAP §4 freshness update.
- Register authority engine files in ENGINE_MAP §1; mixed files also in §1.1.
- Register anchors in ENGINE_MAP §1.2 only; never duplicate anchors in §1.
- Register plans/spec twins in ENGINE_MAP §2; keep plan/spec bodies in `engine/plans/`.
- Keep `ENGINE_DOCTOR.md` registered in ENGINE_MAP §1 as the maintenance contract. Keep `engine/scripts/engine-doctor.sh` and `.ps1` bundled but unregistered as tooling.
- Do not register `engine/.cache/*.generated.md`, `engine/archive/*`, or external/bootstrap scratch files unless the architect explicitly changes scope.
- CLI-LEAN derivable content must be pure stub or recipe; live inventories belong in generated-cache, not authority files.
- After engine edits, run `./engine/scripts/engine-doctor.sh` or `.\engine\scripts\engine-doctor.ps1`; if scripts are missing, run `/engine-sync` and then re-run Doctor.
- Use `/engine-sync` after updating the Engine System repo/plugin so installed projects receive current commands, bundled scripts, and engine-file migration guidance. `/engine-update` is session state handoff, not tooling sync.


## Dangerous Commands
⚠️ `[COMMAND]` — [why dangerous] — [safe alternative or required confirmation]
[新危险命令追加到本节末尾。]


---


### FILE 8 — HANDOFF.md
> Class: irreducible（交接状态）。


# HANDOFF — [Project Name]
> 初始化日期：[date] | 会话：0（初始）
> 每次会话结束后重写此文件。


## ⚡ 立即恢复点
> “从这里开始：[用业务语言描述当前最高优先级任务，附具体的文件/目录入口]”


## 本次会话总结
### ✅ 完成内容
* 引擎文件首次生成。ENGINE_MAP + 全部 [N] 个文件已创建。
### ⚙️ 实现方式
* 基于架构师采访，按 [profile] 生成了引擎文件系统。
### ⚠️ 注意事项
* 这是初始化版本，部分内容（TBD 项）需随项目演进补充。
### 🔜 建议下一步
* [根据采访中最高优先级任务填写，业务语言]
### ❓ 待解决问题
* [采访中出现但未解决的问题]


## 本次会话中的决策
| 决策 | 选择 | 放弃 | 原因 |
|------|------|------|------|
[新决策追加到表格末尾。]


## 进行中的工作
### Lane 列表
| Lane | 当前任务 | 状态 | 下一步操作 | 开始前需阅读的文件 |
|------|----------|------|------------|--------------------|
| L1 | [来自 SPRINT.md 的任务或工作流] | [尚未开始/进行中/阻塞/完成] | [具体第一步，附通俗解释] | [来自 SOURCEMAP / ARCHITECTURE / PLAN 的关键文件] |
[多 lane 并行时，每条工作流占一行；若只有单线任务，可保留一行主 lane。]


## 上下文漂移警告
[无（初始化时）。随项目演进逐步填充。]


## 会话历史
| 会话 | 日期 | 关键变更 |
|------|------|---------|
| 0 | [today] | 引擎文件初始化 |
[新会话追加到表格顶部（时间倒序）。]


## 引擎文件变更摘要
| 文件 | 变更类型 | 变更内容 | 原因 |
|------|---------|---------|------|
| [file] | [修改/追加] | [简述] | [why] |
[如无修改则写「本次会话未修改引擎文件。」]


## 交接检查清单
- [ ] 恢复点足够具体，能立即行动
- [ ] 所有修改过的文件已列出
- [ ] 待解决问题已记录
- [ ] 新发现的陷阱已记录到 PITFALLS.md
- [ ] 上下文漂移警告已标注
- [ ] 会话历史表已更新
- [ ] ENGINE_MAP 已更新（revision / 关系图）
- [ ] 引擎文件变更摘要已输出


---


### FILE 9 — SOURCEMAP.md
> Class: derivable。WEB‑FULL 完整生成；CLI‑LEAN 生成为 pure stub —— 章节标题保留，正文只写查询 recipes，不写当前代码事实。agent 需要时现场重建并核对，NEVER 信任 stub 正文。


# SOURCEMAP — [Project Name]
> Last updated: [date] | 把这个当作 GPS，不是文档。
> CLI-LEAN: pure stub only. 本文件只保存现生方法，不保存现生结果。


## 使用方法
- “X 逻辑在哪里？” → Ctrl+F 搜索领域名称
- “在哪里添加新的 Y？” → 查看扩展点章节
- “谁调用了 Z？” → 查看依赖图章节
- “我想做 [功能描述]” → 查看「功能地图」

## CLI-LEAN 现生协议
> [derivable — 由 agent 从代码现生，见 ENGINE_MAP §0]

Rules:
- Store recipes, not results.
- Do not paste `rg --files`, `ls`, dependency list, directory tree, or version output into this file.
- If a temporary map is useful, write/read it as `engine/.cache/sourcemap.generated.md` and mark it disposable.
- Before acting on any recipe output, rerun the read command or inspect the target file directly.

Common recipes:
```bash
rg --files
rg -n "symbolOrFeatureName" .
rg -n "export .*Tool|register|manifest" src
find . -maxdepth 3 -type f -name 'package.json' -o -name 'pnpm-workspace.yaml'
```


## 1. 关键文件
> [derivable — CLI-LEAN 下按需现生。WEB-FULL 下才填表。]


## 2. 模块地图
### 入口点
> [derivable — CLI-LEAN 下按需现生。WEB-FULL 下才填表。]
### 核心逻辑
> [derivable — CLI-LEAN 下按需现生。WEB-FULL 下才填表。]
### 数据层
> [derivable — CLI-LEAN 下按需现生。WEB-FULL 下才填表。]
### 配置与引导
> [derivable — CLI-LEAN 下按需现生。WEB-FULL 下才填表。]


## 3. 入口点
> [derivable — CLI-LEAN 下按需现生。WEB-FULL 下才填表。]


## 4. 数据流
> [derivable — CLI-LEAN 下按需现生。WEB-FULL 下才填 ASCII 流程图。]


## 5. 配置注册表
> [derivable — CLI-LEAN 下按需现生。WEB-FULL 下才填表。]


## 6. 依赖图（非显而易见的）
> [derivable — CLI-LEAN 下按需现生。WEB-FULL 下才填图。]


## 7. 扩展点
> [derivable — CLI-LEAN 下按需现生。WEB-FULL 下才填表。]


## 8. 功能地图
> [derivable — CLI-LEAN 下按需现生。WEB-FULL 下才填表。]


## 9. 废弃区域
> [derivable — CLI-LEAN 下按需现生。WEB-FULL 下才填表。]


## 10. 文件命名规范
> [derivable — CLI-LEAN 下按需现生。WEB-FULL 下才填表。]


---


### FILE 10 — AGENTS.md + CLAUDE.md （anchor 引导器，两种 profile 均生成）
> Class: anchor。生成于项目根目录（不在 /engine/ 内）。若任一文件已存在，先走「吸收再指向」：列出将吸收进引擎文件的既有规则清单，经架构师确认后改写为引导器。NEVER 不经吸收直接覆盖。


**AGENTS.md（正本）内容：**


# [Project Name] — Agent Entry
> 本文件是引导器，不是知识仓库。权威知识在 `engine/`，以 `engine/ENGINE_MAP.md` 为索引。


## FIRST ACTION (MUST)
Read `engine/ENGINE_MAP.md` BEFORE anything else. Active profile: [WEB-FULL / CLI-LEAN].
按其 §0 读取流程加载引擎文件，用一句中文复述当前状态理解，架构师确认后动手。
开发/编辑前还必须按 ENGINE_MAP §0 的 read-gate 读取候选路径相关锚点、plan/spec、SYSTEM/REPO_GUIDE 章节，并声明 `read-gate:` 证据。


## TOP RULES (source: engine/SYSTEM.md — 完整规则以彼为准)
1. [Prime Directive 摘抄 1]
2. [Prime Directive 摘抄 2]
3. [最关键的 NEVER，e.g. NEVER touch [AI 禁区]]
[最多 5 条。只摘抄，NEVER 在此新增引擎里没有的规则 —— 新规则先进 SYSTEM.md。]


## SESSION PROTOCOL
- 开始：见 engine/SYSTEM.md「会话加载流程」
- 结束：更新 HANDOFF.md + ENGINE_MAP；若有实质改动，同时写 `engine/changes/CHANGE-*.md`，输出引擎文件变更摘要（见「会话结束流程」）
- **v5.6 自维护循环**：在 Claude Code 下，SessionStart hook 自动注入当前状态摘要到 agent 上下文（「自动接手」），Stop hook 在会话结束时检查是否改了代码但没回写引擎记忆（「收尾守门员」）。跨 agent 靠 git pre-commit hook 兜底。详见「自维护循环架构」章与 `engine/AGENT_ADAPTERS.md`。


## MAP
- 引擎索引：engine/ENGINE_MAP.md ｜ 规则：engine/SYSTEM.md ｜ 当前状态：engine/CONTEXT.md
- [若有包级锚点] 各代码包的局部上下文见各包根部 README.md
- [若有环境适配] 当前 agent 工具细则见 engine/agents/[ENV].md


**CLAUDE.md 内容：**
- agent 工具支持 import 语法时：单行 `@AGENTS.md`
- 不支持时：与 AGENTS.md 内容完全相同（RECONCILE 负责核对两份一致）

若需要环境适配文件，继续生成 FILE 11；否则跳过并且不要在 ENGINE_MAP §1 保留占位行。


---


### FILE 11 — engine/agents/[ENV].md （可选环境适配文件）
> Class: irreducible。仅当某个 agent 环境需要超过 10 行的工具/权限/子代理/终端细则时生成。生成后 MUST 登记 ENGINE_MAP §1；未生成时 ENGINE_MAP §1 不保留占位行。


# [ENV] Agent Adapter — [Project Name]
> Last updated: [date] | Environment-specific rules. General authority remains `engine/SYSTEM.md` and `engine/REPO_GUIDE.md`.


## Scope
- 本文件只放某个 agent 环境专属规则，例如 Codex、Claude Code、IDE agent、CI bot。
- 不复制 SYSTEM / REPO_GUIDE 正文；只记录该环境如何执行那些规则。
- 根引导器 AGENTS.md / CLAUDE.md 只保留到本文件的一行指针。


## Tooling Rules
[工具发现、并行读取、文件编辑工具、终端 session、权限边界。]


## Subagent / Delegation Rules
[若该环境支持子代理，写何时允许、如何关闭、不得回滚他人改动等。若不支持，写 N/A。]


## Environment-Specific Safety
[该环境独有风险、禁用命令、审批/沙箱/网络规则。]


## Maintenance
- 修改本文件时，同步 ENGINE_MAP §1 revision/date。
- 若本文件被删除，必须删除 ENGINE_MAP §1 对应行，并清理 AGENTS.md / CLAUDE.md 中的指针。
- 若规则已变成通用仓库规则，迁移到 SYSTEM.md 或 REPO_GUIDE.md，本文件只留环境执行差异。


---


### FILE 12 — 包级 README.md （anchor 记忆锚点，仅 ANCHOR LAYER 触发条件满足时生成）
> Class: anchor。生成于每个主要包/服务目录根部，并逐一登记到 ENGINE_MAP §1.2。已有面向人类的 README 时，在其末尾追加 `## For AI Agents` 章节（内容同下，去掉一级标题），NEVER 覆盖或改写人类内容。


# [package-name]
> Agent memory anchor | 全局权威知识见 /engine/ | Last verified: [date]


## 职责
[本包做什么，一句话，业务语言]


## 关键文件
| 文件 | 角色 |
|------|------|
| [entry file] | [一句话] |
[只列 3‑7 个最关键文件，不求全 —— 全量地图由 SOURCEMAP 承载或现生。]


## 本包局部规则
[仅适用于本包的 irreducible 知识 —— 此处即权威位置，引擎文件不重复]
- [e.g. 本包内所有时间一律 UTC，时区转换只在 view 层做]
[新局部规则追加到列表末尾。]


## 指针（NEVER 在此复制正文）
- 相关陷阱：[PITFALLS: P003, P007 或「无」]
- 相关架构决策：[ARCHITECTURE §6: #2 或「无」]
- 关联 plan：[PLAN-NN 或「无」]


[包结构变化时同步「关键文件」表并更新头部日期。]


---


## PHASE 3 — COMPLETION


After all files are generated and the completeness check passes, output the completion table, then proceed to Phase 4.


## ✅ 引擎文件系统初始化完成


| 文件 | 状态 | 核心内容 |
|------|------|---------|
| ENGINE_MAP.md | ✓ | profile=[X]，[N] 个文件已注册，关系图就绪 |
| ARCHITECTURE.md | ✓ | [一句话摘要]（CLI‑LEAN：derivable 章节为现生说明） |
| CONTEXT.md | ✓ | [一句话摘要] |
| SPRINT.md | ✓ | [N 个任务，最高优先级：X] |
| ROADMAP.md | ✓ | [N 个里程碑] |
| PITFALLS.md | ✓ | [N 条记录] |
| SYSTEM.md | ✓ | [N 条 Prime Directives，含协作协议、维护协议] |
| ENGINE_DOCTOR.md | ✓ | 维护契约已注册，Doctor 脚本已打包 |
| HANDOFF.md | ✓ | 恢复点：[task] |
| SOURCEMAP.md | ✓ | [N 个模块已映射 / CLI‑LEAN：stub] |
| AGENTS.md + CLAUDE.md | ✓ | 引导器已就位，首读指向 ENGINE_MAP[；已吸收原有 N 条规则进引擎] |
| 包级 README 锚点 | [✓ / 跳过] | [N 个包已布锚 / 未达触发条件，未生成] |


另已创建空目录 `engine/plans/`，用于存放后续 plan 及其 spec twin；已创建 `engine/scripts/` 并写入 Doctor 脚本。锚点文件（AGENTS.md / CLAUDE.md / 包级 README）位于代码库约定位置，已登记到 ENGINE_MAP §1.2。


---


## PHASE 4 — 人话启动指南（必须输出）


After the completion table, output the following plain‑language guide to the maintainer (who may be non‑technical).


```markdown
---

## 🎉 引擎设置完毕！接下来你需要知道的事（人话版）

你的项目现在有了一套“AI 记忆系统”，存放在 `/engine/` 文件夹里。以后每次找我帮忙开发，我会先读 `ENGINE_MAP.md`（一张总目录），立刻想起你项目的全部上下文——你是谁、项目要做什么、做到哪了、有哪些坑、你喜欢我怎么干活。


### 📌 你最需要关心的，只有这 4 件事

1. **项目进度（当前状态）**
   在 `CONTEXT.md` 的「状态面板」里。你可以直接对我说：“更新状态，我刚做完用户注册，接下来做登录”，我会帮你改。

2. **最想做的任务**
   在 `SPRINT.md`（或直接说）里，用你的话描述：“我想让用户能做 ______”“现在最急的是 ______，因为 ______”。

3. **想做一个新的大东西（plan）**
   直接跟我聊设计就行——“我想加一套支付功能，大概是这样……”。我会帮你把它写成一份 plan 存档、配一份「怎么算做成了」的验收清单（spec twin）、排进任务、登记到总目录。**你不用管格式**，尽管发散地想。

4. **遇到的坑**
   告诉我：“记住，改头像时千万别动密码文件，不然登录会崩。” 我会写进 `PITFALLS.md`，以后所有 AI 都绕开。


### 🔁 如何开始一次新的开发会话

- 用网页：把 `/engine/` 里的文件发给我（至少 `ENGINE_MAP.md`），然后说人话。
- 用 Claude Code：直接说人话，我自己读。
然后比如：“继续上次的功能，做到上传照片后加水印”“帮我修复登录慢”“我想在首页加搜索框”。


### 🤖 我会自动帮你维护的东西

以下文件你基本不用碰，我每次干完活自动更新：`ENGINE_MAP`（总目录）、`ENGINE_DOCTOR`（体检规则）、`ARCHITECTURE`、`SOURCEMAP`、`PITFALLS`、`HANDOFF`、`ROADMAP`，以及 `CLAUDE.md` / `AGENTS.md`（AI 工具的"开机引导卡"）和各代码包里的小 README（AI 进入每个文件夹时看的"路标"）。你只需看一下我的总结，确认没问题。

> 💡 **v5.6 新增：** 在 Claude Code 下我不只"记得"更新——我**必须**更新（不改完不让我停下）。即使你用别的 AI 工具，你的 git 仓库也会在 `git commit` 时自动检查引擎记忆是否跟上代码变化。详见下一章「自维护循环」。

> 💡 **v5.7 新增：** 每次有意义的改动，我会写一份 `engine/changes/CHANGE-*.md` 改动胶囊，把代码变化翻译成目标、影响、风险、验证、回滚和责任边界。你不需要审代码，只需要看这份胶囊和 `/engine-status` 的 Project Self-View。

> 💡 小提示：如果你哪天顺手把新规则直接写进了 `CLAUDE.md`，没关系 —— 下次"更新引擎"时我会把它收编进正式规则库，不会丢。


### 🗣️ 你可以这样和我沟通

- **改需求**：“注册时还要收集生日”
- **查看进度**：“我们做到哪了？还有多久能发布？”
- **暂停&回顾**：“等等，你这步做了什么，解释一下”
- **记录经验**：“记住，那个库停更了，以后别用”
- **健康检查**：“检查引擎” 或 `/engine-doctor` —— 我会跑 Doctor，确认引擎文件注册、脚本、预算和锚点没有漂移
- **更新引擎/对账**：“更新引擎” —— 我会刷新会话上下文、核对文档和代码是否还一致
- **同步工具**：“同步引擎工具” 或 `/engine-sync` —— 当本仓库/插件升级后，我会更新命令、Doctor 脚本和迁移规则，再做健康检查


### ⚠️ 几点说明

- 技术细节我已从你的代码/采访里读好了，看不懂那些名词没关系。
- `/engine-update` 是更新当前项目记忆和交接；`/engine-sync` 才是同步本仓库随版本升级的命令、脚本和 Doctor 契约。
- 不确定某操作是否安全，先问我“如果我想……会不会有问题？”
- 默认我不会删文件、不会引入付费服务，除非你明确同意。

---

**现在，告诉我：“继续” 或者 “开始做 [你的具体任务]”。**
```


After outputting this guide, INIT is complete.


---
---


