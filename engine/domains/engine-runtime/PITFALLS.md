# engine-runtime — 陷阱与检索配方

> 引擎运行时域的非显然行为。新增陷阱时登记 rg recipe,归档不等于遗忘。

## 陷阱

- **P001 porcelain 必须用 `-z -uall`**:`-unormal`(默认)会把未跟踪目录折叠成 `?? dir/`,遮蔽首个 capsule,门禁看不见。来源:S0 parity 测试抓出。
- **P002 `.cmd` 必须 CRLF**:`.gitattributes` 钉 `*.cmd text eol=crlf`;LF-only 的 .cmd 在 goto/label 跳转时静默失败。来源:S0 engine-hook.cmd。
- **P003 `CLAUDE_PROJECT_DIR` 会泄漏到测试**:测试子进程继承环境变量,指向真实仓库而非临时仓库;测试须显式覆盖。来源:S1 task-card 测试。
- **P004 `git add -A` 会意外暂存受保护文件**:rules.json 本身受保护,`git add -A` 后提交被 pre-commit 拦;测试用指定文件 `git add`。来源:S1 task-card 测试。
- **P005 中文路径击穿 porcelain**:`core.quotepath` 给非 ASCII 文件名加引号,`${line:3}` 子串逻辑破功;`-z` 终止符根治。来源:D1 诊断。
- **P006 双引号里的 `<!--` 会被交互式 bash 历史展开**:`MARK="<!-- … -->"` 中 `!-` 触发 histexpand→赋值丢弃→`set -u` unbound(外部项目实测踩中)。脚本一律 `set +H` + MARK 单引号;回归:tests/update-flow U6。来源:D-015。
- **P007 改 live hook 必须先改非 live 副本再原子换入**:settings.json 指向 plugin/ 副本;直接 Edit 该文件时,第一刀(如函数改名)落盘后 hook 立即以半改状态执行,可能自坏并拦截后续一切 Edit(自锁)。解法:改 root 副本,完工后 `cp` 整体换入;Bash 工具不受 PreToolUse 逐路径拦截,可作恢复通道。来源:T-048 实测自锁。
- **P008 无 BOM .ps1 的中文注释在 GBK 机器上会吞括号**:PS 5.1 按系统码页读无 BOM 文件;GBK 双字节解码可把注释外的 `{`/`}` 吞进乱码对,且是否引爆取决于字节对齐——上游任何 ASCII 编辑都可能改变对齐引爆预存雷(CI Windows-1252 单字节不受影响,本地中文 Windows 才炸)。解法:含非 ASCII 的 .ps1 一律带 UTF-8 BOM(T-038 先例);新增字符串字面量 ASCII-only(T-047)。来源:T-048 engine.ps1 三副本实测。

## 检索配方

```bash
rg "porcelain" engine/scripts/ plugin/engine/scripts/         # 门禁路径解析
rg "decision:block|decision:warn" plugin/engine/scripts/      # 门禁裁决
rg "contract-version" plugin/engine/scripts/                  # 契约版本标记
rg "Write-Output|echo " plugin/engine/scripts/engine-hook-stop.ps1 engine/scripts/engine-hook-stop.sh  # 双实现对照
rg "set \+H|normalize_version" engine/scripts/ engine/bin/    # histexpand 防御 / 版本归一化
```
