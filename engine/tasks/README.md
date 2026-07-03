# Task Cards — 任务卡

> Engine System v6 S1 引入。机读头 + 人话体，对抗会话中途漂移的核心新原语。

## 文件命名

`engine/tasks/T-NNN.md`（NNN 三位递增，从 T-001 起）。

## 格式

```markdown
# TASK CARD — T-NNN
> status: active | lane: <lane-id> | decision: D-NNN | plan: PLAN-NN | domain: <domain>
GOAL: <一句话目标，中文>
WRITE-SET: <glob>, <glob>          ← agent 只许碰这些路径
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
| GOAL | 是 | 一句话目标 |
| WRITE-SET | 是 | 允许触碰的路径 glob 列表（逗号分隔） |
| FORBIDDEN | 否 | 禁止触碰的路径 glob 列表 |
| AC | 是 | 验收条件，每条可附 `verify:` 命令 |
| CONSTRAINTS | 否 | 约束，须标出处 |

## 门禁消费

- **Stop hook**：本会话 `git status` 触碰的代码路径必须 ⊆ 当前 active 任务卡的 WRITE-SET ∪ engine 文件；越界 = `decision:block`。
- **HANDOFF 绑定**：回写 HANDOFF 时，交接行须含当前任务卡 ID（如 `T-001`），可 grep。
- **压缩重注入**：SessionStart(matcher: compact|resume) 读取 active 任务卡并注入上下文——漂移最危险的时刻（压缩后）恰好被打锚。
- **行为化验收**：`engine verify T-NNN` 逐条执行 AC 的 `verify:` 命令，结果写入 `engine/evidence/T-NNN/`。
