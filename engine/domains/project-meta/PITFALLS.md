# project-meta — 陷阱与检索配方

> 项目运营记忆域的非显然行为。新增陷阱时登记 rg recipe,归档不等于遗忘。

## 陷阱

- **P001 任务卡 status 必须用 `status:.*active` 匹配**:grep 行内匹配,字段格式 `> status: active | lane:...`。来源:S1。
- **P002 FORBIDDEN 优先于 WRITE-SET**:路径同时命中两者时,按 FORBIDDEN 拦截(架构师否决权优先)。来源:S1 task-card 测试。
- **P003 无 active 任务卡时回退 v5.6 行为**:门禁不要求任务卡存在;兼容存量项目。来源:S1 向后兼容设计。
- **P004 决策 scope 用 glob,逗号分隔**:pre-commit 用 `case` 模式匹配校验 scope 覆盖。来源:S1 pre-commit。

## 检索配方

```bash
rg "status:.*active" engine/tasks/                            # 找活跃任务卡
rg "status:.*proposed" engine/decisions/                      # 找待拍板决策
ls engine/changes/CHANGE-*.md | sort -r | head -3             # 最近胶囊
rg "verify:" engine/tasks/                                    # AC 验证命令
rg "protected_paths" engine/decisions/rules.json              # 受保护路径
```
