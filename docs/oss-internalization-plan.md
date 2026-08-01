# Open-Source Internalization Plan

> 原则：借鉴源码设计，改装为引擎自有 bash/markdown 实现。不引入外部二进制依赖。

## O1: ShellCheck 规则子集 → Doctor Lint Check

**来源**: koalaman/shellcheck (GPL-3.0)
**目标**: engine-doctor.sh 新增 check_script_lint()
**内化方式**:
- 不嵌入 shellcheck 二进制，提取其高频规则为 grep/awk 模式
- 核心规则子集（~20条）：
  - SC2086: 未引用变量（$var 应为 "$var"）
  - SC2046: 未引用的命令替换
  - SC2155: declare 和赋值分离
  - SC2164: cd 无 || exit
  - SC2034: 未使用变量
  - SC1091: source 文件不存在
- 实现：bash 函数，对 engine/scripts/*.sh 逐文件跑模式匹配
- 输出：WARN 级（不 FAIL），格式同 doctor 其他 check
- 优先级：P1（低成本高收益）

## O2: BATS 测试骨架 → tests/framework.sh

**来源**: bats-core/bats-core (MIT)
**目标**: tests/workstream/ 统一测试框架
**内化方式**:
- 提取 BATS 核心：TAP 输出格式 + setup/teardown + @test 语法糖
- 实现为 tests/framework.sh（~100行 bash）：
  - `tap_plan N` — 输出 1..N
  - `tap_ok desc` / `tap_fail desc` — TAP 格式断言
  - `setup()` / `teardown()` 钩子
  - 自动 mktemp + trap cleanup
- 现有测试逐步迁移（兼容期保留旧 assert helper）
- 优先级：P2（测试量大时收益明显）

## O3: jq 模式 → engine/scripts/lib/json.sh

**来源**: jqlang/jq (MIT) + 纯 bash JSON 解析模式
**目标**: 减少 Python subprocess 调用
**内化方式**:
- 实现 json_get(json_string, path) — 点分路径取值
- 实现 json_set(json_string, path, value) — 简单赋值
- 限制：只处理引擎自产 JSON（结构已知、无嵌套转义）
- 不追求通用 JSON 解析（那是 jq 的活），只覆盖 gate/verify/doctor 的高频操作
- 回退：复杂操作仍用 Python（json_set 嵌套 >2 层时）
- 优先级：P2（性能优化，非阻塞）

## O4: Conventional Changelog → CHANGE 胶囊自动生成

**来源**: conventional-changelog/conventional-changelog (ISC)
**目标**: engine close 时从 git log 自动生成 CHANGE-*.md
**内化方式**:
- 提取 commit message 规范：`type(scope): description`
- close 脚本新增 `generate_capsule()` 函数：
  - git log --oneline first_commit..HEAD → 按 type 分组
  - feat → "新增", fix → "修复", docs → "文档", test → "测试"
  - 生成 CHANGE-YYYY-MM-DD-NN.md 标准格式
- 不依赖 npm/node，纯 bash + git log
- 优先级：P1（减少 close 手动步骤）

## O5: 跨宿主规则格式 → D-042 适配层参考

**来源**: cursor-rules 社区集合 + .clinerules + AGENTS.md 标准
**目标**: engine install --host=<agent> 的格式映射表
**内化方式**:
- 收集各宿主的规则注入格式：
  - Claude Code: .claude/settings.json hooks + CLAUDE.md
  - Cursor: .cursorrules (markdown)
  - QoderWork: AGENTS.md + awareness 协议
  - Cline: .clinerules (markdown)
  - 通用: pre-commit (git 层)
- 实现 engine/scripts/engine-install.sh --host=X：
  - 读取引擎核心规则（runtime-law.md + ENGINE_MAP.md）
  - 转换为目标宿主格式
  - 写入对应配置文件
- 优先级：P3（trigger=多会话扩展）

## O6: Token 估算 → injection budget 精确化

**来源**: tiktoken 算法 (MIT) + 中文分词经验公式
**目标**: 替换行数估算为 token 估算
**内化方式**:
- 纯 bash 估算公式（不引入 tiktoken 二进制）：
  - ASCII: len / 4
  - CJK: len * 0.6 (每字符约 1.5 token)
  - 混合: 分段计算
- 实现 estimate_tokens(file) 函数
- injection budget 从 500 行改为 40000 token（等价但更精确）
- 优先级：P2（当前行数估算已够用）

## 实施顺序

1. **P1 先行**: O1 (doctor lint) + O4 (capsule auto-gen) — 直接改善日常体验
2. **P1 同步**: B1-B5 边界 bug 修复
3. **P2 跟进**: O2 (test framework) + O3 (json.sh) + O6 (token estimate)
4. **P3 延后**: O5 (D-042 多宿主) — 等多会话需求

## 许可证合规

- shellcheck: GPL-3.0 → 只提取规则思路，不复制代码，实现为独立 bash 模式匹配
- bats-core: MIT → 可参考结构，注明灵感来源
- jq: MIT → 不复制代码，自实现子集
- conventional-changelog: ISC → 提取格式规范，自实现生成器
- tiktoken: MIT → 使用公开算法公式，不复制代码
