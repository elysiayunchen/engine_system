# engine-runtime — 陷阱与检索配方

> 引擎运行时域的非显然行为。新增陷阱时登记 rg recipe,归档不等于遗忘。

## 陷阱

- **P001 porcelain 必须用 `-z -uall`**:`-unormal`(默认)会把未跟踪目录折叠成 `?? dir/`,遮蔽首个 capsule,门禁看不见。来源:S0 parity 测试抓出。
- **P002 `.cmd` 必须 CRLF**:`.gitattributes` 钉 `*.cmd text eol=crlf`;LF-only 的 .cmd 在 goto/label 跳转时静默失败。来源:S0 engine-hook.cmd。
- **P003 `CLAUDE_PROJECT_DIR` 会泄漏到测试**:测试子进程继承环境变量,指向真实仓库而非临时仓库;测试须显式覆盖。来源:S1 task-card 测试。
- **P004 `git add -A` 会意外暂存受保护文件**:rules.json 本身受保护,`git add -A` 后提交被 pre-commit 拦;测试用指定文件 `git add`。来源:S1 task-card 测试。
- **P005 中文路径击穿 porcelain**:`core.quotepath` 给非 ASCII 文件名加引号,`${line:3}` 子串逻辑破功;`-z` 终止符根治。来源:D1 诊断。

## 检索配方

```bash
rg "porcelain" engine/scripts/ plugin/engine/scripts/         # 门禁路径解析
rg "decision:block|decision:warn" plugin/engine/scripts/      # 门禁裁决
rg "contract-version" plugin/engine/scripts/                  # 契约版本标记
rg "Write-Output|echo " plugin/engine/scripts/engine-hook-stop.ps1 engine/scripts/engine-hook-stop.sh  # 双实现对照
```
