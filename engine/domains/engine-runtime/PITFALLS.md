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

- **P009 Python sed `\1` backreference 变 0x01 控制字符**:Python 普通字符串 `'\\1'` 在替换模板中被解释为八转义→输出 \x01;必须用 `chr(92)+'1'` 拼接或改用 index-based 行插入(不含 backref 的 anchor)。来源:T-082/T-085 canvas/stop/session-start 四处踩中。
- **P010 Stop hook ~L510 早退截断末尾逻辑**:`code_changed=1 && engine_written=0` 在约 L510 触发 block+`exit 0`,早于文件末尾。任何"会话结束时必须执行"的逻辑(如失败模式提取)须内联到该 exit 之前,不能放文件尾。来源:T-082 S5 信号丢失。
- **P011 gate has_code 仅检查 WRITE-SET 字符串扩展名**:路径带注解 `(new)`/`[added]`、是目录、或 glob 模式时,`.${p##*.}` 解析失败→has_code=0→review/prove 全 SKIP。修复:v6.26.1 增加 Python filesystem fallback(磁盘展开+注解剥离)。来源:T-085 后续审查。
- **P012 PS1 补丁 brace-counting 被单行块干扰**:`if (...) { $x = 1; break }` 一行内含 `{`+`}`,朴素计数器净零→把后续 `}` 误判为外层闭合。解法:用结构锚点(如 `# 3.` section marker)定位,不依赖纯计数。来源:gate.ps1 fallback 插入错位。

## 检索配方

```bash
rg "porcelain" engine/scripts/ plugin/engine/scripts/         # 门禁路径解析
rg "decision:block|decision:warn" plugin/engine/scripts/      # 门禁裁决
rg "contract-version" plugin/engine/scripts/                  # 契约版本标记
rg "Write-Output|echo " plugin/engine/scripts/engine-hook-stop.ps1 engine/scripts/engine-hook-stop.sh  # 双实现对照
rg "set \+H|normalize_version" engine/scripts/ engine/bin/    # histexpand 防御 / 版本归一化
rg "has_code|write_set_paths" engine/scripts/engine-gate.sh   # 代码检测逻辑
rg "_fe_append_candidate" engine/scripts/engine-hook-stop.sh  # 失败模式提取
```

## Auto-detected (pending review)

<!-- Stop hook 自动追加的失败模式候选。人工 review 后提升为正式条目或删除。-->


### P013 — doctor 有3处 summary printf, 补丁 rfind 定位最后一处

- **严重程度：** 中
- **类别：** 补丁定位
- **状态：** 已修复
- **你能观察到的现象：** 补丁插入 check_script_lint 调用到 package_mode 块内(函数未定义), 静默无效无报错
- **错误做法：** 用 str.replace() 匹配第一个 summary printf 出现位置
- **正确做法：** 用 rfind() 定位最后一处 summary printf 再插入
- **触发条件：** engine-doctor.sh 有 package_mode 分支, 内含2处相同 printf + 末尾1处
- **验证方式：** `grep -n "check_script_lint" engine-doctor.sh` 确认调用在函数定义之后

### P014 — Python f-string 与 PS1 ${var} 冲突

- **严重程度：** 中
- **类别：** 代码生成
- **状态：** 已修复
- **你能观察到的现象：** NameError: name 'fname' is not defined — Python 解析 ${fname} 为变量
- **错误做法：** 用 f-string 生成含 PowerShell ${var} 语法的代码
- **正确做法：** 用普通三引号字符串(非 f-string)生成 PS1 代码
- **触发条件：** Python 补丁脚本生成 PS1 内容时
- **验证方式：** 补丁脚本执行无 NameError

### P015 — bash printf '---\n...' 被解析为选项

- **严重程度：** 低
- **类别：** bash 语法
- **状态：** 已修复
- **你能观察到的现象：** printf: --: invalid option
- **错误做法：** printf '---\nProvenance: ...' (格式串以 - 开头)
- **正确做法：** printf '%s\n' "---" 或 printf -- '---\n...'
- **触发条件：** 格式串以 --- 开头时 bash printf 误判为选项
- **验证方式：** 胶囊文件包含 --- 分隔行

### P016 — PS1 param 块补丁混合行尾(CRLF/LF)导致解析失败

- **严重程度：** 中
- **类别：** 补丁定位
- **状态：** 已修复
- **你能观察到的现象：** Missing argument in parameter list at line 2
- **错误做法：** 在 CRLF 文件中用 LF 行插入新 param, 产生混合行尾; 或用通用 regex 匹配 param 块时切断 (Get-Location).Path 表达式
- **正确做法：** 匹配时考虑混合行尾(\r\n 和 \n 共存); 插入时统一用文件主行尾
- **触发条件：** engine/scripts/*.ps1 是 CRLF, Python 补丁用 \n 拼接
- **验证方式：** PowerShell Parser::ParseFile 零错误

### P017 — case 模式中含 << 触发 heredoc 解析

- **严重程度：** 低
- **类别：** bash 语法
- **状态：** 已修复
- **你能观察到的现象：** syntax error near unexpected token `<<'
- **错误做法：** case "$line" in *cat\ <<*) — bash 将 << 解析为 heredoc 操作符
- **正确做法：** 用 if [[ "$line" == *"<<"* ]] 替代 case 模式匹配含 << 的字符串
- **触发条件：** case 模式中包含重定向操作符字符
- **验证方式：** bash -n 通过
