# Task Cards — 任务卡

> Engine System v6 S1 引入。机读头 + 人话体，对抗会话中途漂移的核心新原语。

## 文件命名

`engine/tasks/T-NNN.md`（NNN 三位递增，从 T-001 起）。

**编号可不连续**：撤回、合并或废弃的卡保留缺口（例如 T-015 缺位），不重用、不补号。新增卡始终取当前最大号 +1，不填旧缺口。

## 格式

```markdown
# TASK CARD — T-NNN
> status: active | lane: <lane-id> | decision: D-NNN | plan: PLAN-NN | domain: <domain>
> estimated_steps: <整数> | checkpoint_plan: <文本或 tryout> | depends-on: T-NNN, T-NNN
GOAL: <一句话目标，中文>
WRITE-SET: <glob>, <glob>          ← 覆盖所有项目路径（包含 engine/*）
FORBIDDEN: <glob>, <glob>          ← 架构师否决权数据化，碰了即拦截
AC: AC-1 <验收条件> → verify: <命令>
AC: AC-2 <验收条件> → verify: <命令>
CONSTRAINTS: <约束文本> (source: <权威出处>)
```

## 字段语义

| 字段 | 必填 | 说明 |
|------|------|------|
| status | 是 | `active` / `paused` / `done` / `blocked` |
| lane | 否 | 多 lane 工作流时的 lane ID |
| decision | 否 | 本任务所依据的已批准决策 ID |
| plan | 否 | 关联的 PLAN-NN |
| domain | 否 | 落点域（S2 分形记忆消费，当前留空或写 `root`） |
| estimated_steps | 否（v6.9.0+ 强烈推荐） | 预估执行步骤数;软门禁阈值 > 20 触发 WARN,见 §任务粒度软门禁。新卡建议填写,存量卡不告警 |
| checkpoint_plan | 否（v6.9.0+） | 软门禁 bypass 声明:任意非空文本（如 `每 N 步强制 checkpoint`）即降级 FAIL→WARN;`tryout` 是合法 bypass 值（D-028 §9）,表示架构师明确开试错卡 |
| depends-on | 否（v6.9.0+） | 逗号分隔的上游任务卡 ID 列表（如 `T-032, T-033`）;任一上游 status != done 时本卡置 active = FAIL（跨域拆卡协调,见 §跨域拆卡协调） |
| GOAL | 是 | 一句话目标 |
| WRITE-SET | 是 | 允许触碰的全部项目路径 glob（逗号分隔；也接受 `## WRITE-SET` bullet list） |
| FORBIDDEN | 否 | 禁止触碰的路径 glob 列表 |
| AC | 是 | 验收条件，每条可附 `verify:` 命令 |
| CONSTRAINTS | 否 | 约束，须标出处 |

## 任务粒度软门禁（v6.9.0+ / D-028 §9 / T-034）

任务卡置 `active` 时,Doctor `check_task_granularity` 检查 4 个阈值,任一触发且未声明 `checkpoint_plan` 字段 = FAIL:

| 阈值 | 触发值 | 处置 |
|------|--------|------|
| AC 数量 | > 12 | 须拆卡或声明 `checkpoint_plan` 才能置 active |
| WRITE-SET 独立路径（去重镜像对） | > 15 | 同上 |
| estimated_steps | > 20 | 同上 |
| WRITE-SET 字节数（所有列出文件 `wc -c` 之和,机制 A） | > 30KB（≈ 8000 tokens） | 同上（`check_writeset_budget` 实现） |

**bypass 机制**:
- 声明 `checkpoint_plan` 字段非空（含 `tryout` 合法值）→ FAIL 降级为 WARN（D-028 §9）
- `check_task_granularity` 只检查 `checkpoint_plan` 字段非空,不检查内容
- `tryout` 是合法 bypass 值,表示架构师明确开试错卡

**迁移宽限期**:contract-version < 6.9.0 时所有软门禁 FAIL 降级为 WARN;≥ 6.9.0 时 FAIL。

## 跨域拆卡协调（v6.9.0+ / D-028 / T-034）

跨域拆卡（一张卡涉及多个 domain）时,必须用 `depends-on` 字段显式声明上游依赖:

- **depends-on 字段**:逗号分隔的上游任务卡 ID 列表,如 `depends-on: T-032, T-033`
- **阻塞门禁**:Doctor `check_depends_on` 检查 `depends-on` 列表中任一卡 status != done → 本卡置 active = FAIL
- **跨域拆卡范式**:
  - 拆出的下游卡在 `domain` 字段列多个域(如 `domain: engine-runtime,project-meta`)
  - 下游卡 `depends-on: <上游卡 ID>`
  - 上游卡 status: done 后,下游卡才能置 active
- **迁移宽限期**:contract-version < 6.9.0 时 depends-on FAIL 降级为 WARN;≥ 6.9.0 时 FAIL
- **跨域拆卡 vs workstream**:跨域拆卡是任务级串行(上游 done 后下游开干),workstream 是同卡并行(多 worker 写独立分片)

## 门禁消费

- **全路径门禁**：PreToolUse / Stop / pre-commit 均检查 WRITE-SET/FORBIDDEN，engine 文件没有 blanket exemption；active 卡无可读 WRITE-SET 时 fail-closed。
- **v6.5 任务采用门**：无 active/closing 卡时只允许创建任务卡或决策卡，普通改动 fail-closed；任务置 `done` 时每个 AC 都须有 PASS evidence（或批准的 exempt）。旧 contract-version 项目迁移前保留兼容模式。
- **v6.9.0 软门禁 + depends-on 门禁**:任务卡置 `active` 前须过 `check_task_granularity` + `check_depends_on` + `check_writeset_budget`(FAIL 级,迁移宽限期同 D-028 §9)。
- **并行分片**：worker 先运行 `engine workstream T-NNN <agent-id>`，只写自己的 CONTEXT/HANDOFF；协调者才写共享记忆。
- **短重锚**：SessionStart 注入完整任务上下文；UserPromptSubmit 只重注入 ≤5 行任务指针，不重复 L0 或完整 WRITE-SET，写前由 PreToolUse 机器校验。
- **行为化验收**：`engine verify T-NNN` 逐条执行 AC 的 `verify:` 命令，结果写入 `engine/evidence/T-NNN/`；每个 AC PASS 后追加写 `engine/evidence/T-NNN/checkpoint.md`（v6.9.0+,AC 级压缩恢复锚点,见 contract/src/20-file-templates.md FILE 15）。

## 粒度与生命周期

- 一张卡对应一个可独立验收、通常是 commit/PR 大小的目标，不对应一次对话、一次工具调用或一个 AC。
- 同一目标跨多轮消息复用 active 卡；并行 worker 共用任务 ID，通过 workstream 分片隔离，不为每个 worker 新建卡。
- 只读调查、状态检查和解释不建卡；开始写普通项目路径前才需要 active 卡。
- done 卡是冷历史，不进入 session context；Doctor 聚合输出总数，仅逐项报告失败，因此卡数不线性消耗模型 token。
- done 卡的 `engine/evidence/T-NNN/checkpoint.md` 归档到 `engine/archive/tasks/T-NNN-checkpoint.md`（v6.9.0+,与 progress.md 归档机制对称）。
