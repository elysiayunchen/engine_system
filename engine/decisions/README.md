# Decision Ledger — 决策台账

> Engine System v6 S1 引入。架构师控制面数据化——决策从叙事变成可引用、可过期、可门禁的工件。

## 文件命名

`engine/decisions/D-NNN.md`（NNN 三位递增，从 D-001 起）。

## 格式

```markdown
# D-NNN — <决策标题>
> status: proposed | approved | rejected | expired | superseded
> date: <YYYY-MM-DD> | expiry: <YYYY-MM-DD 或 none> | scope: <glob>
选项: A <选项A>(选定/未选) / B <选项B> / C <选项C>
理由: <为什么>
后果: <带来了什么>
```

## 字段语义

| 字段 | 必填 | 说明 |
|------|------|------|
| status | 是 | `proposed`（待架构师拍板）/ `approved` / `rejected` / `expired` / `superseded` |
| date | 是 | 决策日期 |
| expiry | 否 | 过期日期；`none` = 长期有效 |
| scope | 是 | 本决策管辖的路径 glob（受保护路径变更须引用覆盖它的 approved 决策） |
| 选项 | 是 | 候选选项，标注选定项 |
| 理由 | 是 | 为什么选这个 |
| 后果 | 是 | 带来了什么代价/前提 |

## 门禁消费

- **受保护路径门禁**：`engine/decisions/rules.json` 声明哪些路径 glob 受保护；pre-commit 检查暂存区是否含受保护路径，若是，要求提交信息或关联任务卡引用一个 `status: approved` 且 `scope` 覆盖该路径的决策 ID，否则拒绝提交。
- **「等你拍板」队列**：`/engine-status` 顶部列出所有 `status: proposed` 的决策，每条附选项 + 推荐 + 人话后果——架构师的日常操作从「读汇报」变成「批工单」。
- **过期核对**：RECONCILE 模式核对 `expiry` 已过的决策，标记为 `expired`——决策也是会漂移的记忆。
