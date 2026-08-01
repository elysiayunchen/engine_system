# project-meta — 陷阱与检索配方

> 项目运营记忆域的非显然行为。新增陷阱时登记 rg recipe,归档不等于遗忘。

## 陷阱

- **P001 任务卡 status 必须用 `status:.*active` 匹配**:grep 行内匹配,字段格式 `> status: active | lane:...`。来源:S1。
- **P002 FORBIDDEN 优先于 WRITE-SET**:路径同时命中两者时,按 FORBIDDEN 拦截(架构师否决权优先)。来源:S1 task-card 测试。
- **P003 无 active 任务卡时回退 v5.6 行为**:门禁不要求任务卡存在;兼容存量项目。来源:S1 向后兼容设计。
- **P004 决策 scope 用 glob,逗号分隔**:pre-commit 用 `case` 模式匹配校验 scope 覆盖。来源:S1 pre-commit。

- **P005 AC 必须用 Format 1 单行格式**:`AC: AC-N desc | verify: cmd`;多行缩进格式(`AC-N:\n  verify:`)不被 engine-verify 解析→0 pass。来源:T-082 verify 跑出 0/7。
- **P006 Edit 工具改 engine/scripts/*.ps1 产生 CRLF→LF 假 churn**:Edit 工具输出 LF;engine/scripts/*.ps1 是 CRLF→git diff 全文标红。解法:Python 二进制补丁(显式 `\r\n` 拼接)。注意 engine/bin/engine.ps1 是 LF,可直接 Edit。来源:T-084/T-085 多次。
- **P007 engine close 大仓超时(>10min doctor 遍历)**:手动收尾流程=python 写 CLOSE.json(status done + verify/gate 摘要)+sed 标卡 done+git add evidence;verify/gate 须先独立 PASS。来源:T-082/T-085 close。

## 检索配方

```bash
rg "status:.*active" engine/tasks/                            # 找活跃任务卡
rg "status:.*proposed" engine/decisions/                      # 找待拍板决策
ls engine/changes/CHANGE-*.md | sort -r | head -3             # 最近胶囊
rg "verify:" engine/tasks/                                    # AC 验证命令
rg "protected_paths" engine/decisions/rules.json              # 受保护路径
```

## Auto-detected (pending review)

<!-- Stop hook 自动追加的失败模式候选。人工 review 后提升为正式条目或删除。-->

