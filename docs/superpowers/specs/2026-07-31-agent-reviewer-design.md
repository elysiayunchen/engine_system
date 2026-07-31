# Agent-Reviewer 子系统设计(v6.20.0→v6.21.0)

> **状态**:proposed(待批准)
> **日期**:2026-07-31
> **审核轮次**:1 轮子代理批判性审核(5 类 20+ 项问题识别与修订)
> **前置**:T-069/T-070 Review 子系统 v1(semgrep + eslint)已全功能上线
> **目标**:让 agent 能对代码做语义级审查(逻辑/设计/跨文件影响/可读性),填补 v1 linter 无法覆盖的"agent 没法自主 review"核心痛点

---

## 0. 背景与痛点

### 0.1 v1 已解决

- 安全扫描(semgrep):已知漏洞模式检测
- 代码质量(eslint):风格/语法/已知反模式
- 门禁闭环:evidence + provenance + Doctor + pre-commit

### 0.2 v1 未解决(本设计填补)

vibecoding 开发者的核心痛点第 4 条——"agent 几乎没法自主 review":

1. **逻辑错误**:linter 看不出"算法在边界条件下会死循环"
2. **设计问题**:linter 不判断"这个抽象层是否必要"
3. **跨文件影响**:semgrep 单文件扫描,看不到"改了接口但调用方没更新"
4. **可读性/可维护性**:eslint 管格式,不管"这段代码三个月后还能看懂吗"
5. **遗漏边界**:linter 不知道"这个函数没处理 null 输入"

这些需要**语义理解能力**——即 LLM agent 做 code review。

### 0.3 设计约束(继承 D-019 哲学)

| 维度 | 决策 | 理由 |
|------|------|------|
| 引擎定位 | 文件层(打包上下文 + 校验产物) | D-019d "不直驱进程" |
| 执行者 | 外部 agent(Claude Code Agent tool / 用户 harness) | 引擎不绑 harness |
| 与 v1 关系 | 独立维度,不替换 semgrep/eslint | 互补:linter 快+确定,agent 深+语义 |
| 触发模式 | 独立命令 `engine review-agent T-NNN --package/--validate` | 两个原子命令,不做交互编排 |
| 反橡皮图章 | 结构化校验(最小 findings + 最小内容量 + 静态挑战) | v1 只做可机器验证的层;动态对抗留 v2 |
| 命令风格 | fire-and-forget(跑完退出,无交互等待) | 与 engine review/verify 一致 |

---

## 1. 架构总览

### 1.1 两阶段原子命令

```
engine review-agent T-NNN --package     ← Phase 1: 引擎打包
engine review-agent T-NNN --validate    ← Phase 3: 引擎校验

Phase 2(外部 agent 做)不由引擎驱动:
  用户/harness 消费 review-package.md → agent 写 AGENT-REVIEW.json
```

**关键修订**(审核 R1):去掉交互模式。引擎只提供两个原子操作,编排由 harness 负责(Claude Code hook / Makefile / CI script)。这与 `engine review`(fire-and-forget)和 `engine verify`(fire-and-forget)风格一致。

### 1.2 流程

```
engine review-agent T-NNN --package
  │
  ├─ 0. flock/FileStream 锁(防并发,复用 v1 模式)
  ├─ 1. 校验前置(任务卡存在 + WRITE-SET 非空 + git history)
  ├─ 2. 算 diff(复用 v1 task_first_commit 算法)
  ├─ 3. 筛代码文件(code_extensions 白名单)
  │    └─ 无代码文件 → exit 0 + "no code changes, agent review skipped"
  ├─ 4. 收集周边上下文(grep 函数引用,≤500 行)
  ├─ 5. 收集域知识(federation 路由 → INVENTORY/PITFALLS)
  ├─ 6. 注入 review protocol(5 维度 + 输出格式 + 3 个静态挑战)
  ├─ 7. 注入 v1 linter findings 摘要(若存在)
  ├─ 8. 大小控制(≤2000 行,先砍周边上下文)
  └─ 9. 写 engine/review/evidence/T-NNN/review-package.md
       exit 0

engine review-agent T-NNN --validate
  │
  ├─ 0. flock 锁
  ├─ 1. 读 AGENT-REVIEW.json(不存在 → exit 1 E_MISSING)
  ├─ 2. Schema 完整性校验(缺字段 → exit 1 E_SCHEMA)
  ├─ 3. 反橡皮图章校验(太浅 → exit 1 E_SHALLOW)
  ├─ 4. Provenance 校验(package_sha256 → exit 1 E_PROVENANCE)
  ├─ 5. 更新 REVIEW.json(追加 agent_review 维度)
  ├─ 6. 重算 evidence_manifest_sha256
  └─ 7. exit 0 + 摘要
```

### 1.3 目录结构(增量)

```
engine/scripts/
├── engine-review-agent.sh / .ps1          # CLI 入口(路由 --package/--validate)
├── engine-review-agent-package.sh / .ps1  # Phase 1: 打包
├── engine-review-agent-validate.sh / .ps1 # Phase 3: 校验
└── (既有 engine-review*.sh 不动)

engine/review/
├── config.json                            # 扩展: agent_review 配置段
├── protocol.md                            # L0 默认审查协议(可选 L1 覆盖)
└── evidence/T-NNN/
    ├── REVIEW.json                        # 扩展: dimensions.agent_review
    ├── AGENT-REVIEW.json                  # 新增: agent 审查结果
    ├── review-package.md                  # 新增: Phase 1 输出(可审计)
    ├── SECURITY.json                      # 不动
    └── QUALITY.json                       # 不动

plugin/engine/scripts/                      # 行为镜像(非 byte-identical,见 §10)
    ├── engine-review-agent.sh / .ps1
    ├── engine-review-agent-package.sh / .ps1
    └── engine-review-agent-validate.sh / .ps1
```

### 1.4 CLI 接口(严格定义)

```bash
engine review-agent T-NNN --package    # 打包 review context
engine review-agent T-NNN --validate   # 校验 agent 输出

# 无模式标志 → exit 2 + usage(与 engine review 行为一致)
# 两个标志互斥,同时给 → exit 2
# 任务卡不存在 → exit 2
```

Dispatcher(`engine/bin/engine`)新增分支:
```bash
review-agent)
  shift
  exec bash "$ENGINE_DIR/scripts/engine-review-agent.sh" "$@"
  ;;
```

---

## 2. Review Package(Phase 1 输出)

### 2.1 review-package.md 结构

```markdown
# Code Review Package: T-NNN

> generated: <timestamp>
> package_sha256: <本文件的 sha256,validate 时校验>
> head_commit: <HEAD sha,agent 回显用>
> task: <GOAL 一行摘要>
> scope: <diff_base>..<head_commit>, <N> code files

## 1. Task Context

### GOAL
<任务卡 GOAL 原文>

### WRITE-SET
<列表>

### CONSTRAINTS
<列表>

### AC
<AC 列表>

## 2. Code Changes (diff)

### <file_path_1>
```diff
<unified diff with context>
```

### <file_path_2>
...

## 3. Surrounding Context

### <related_file> (references <symbol>)
```<lang>
<≤50 行上下文>
```

## 4. Domain Knowledge

### Domain: <domain_name>
<INVENTORY 相关行 + PITFALLS 相关条目>

## 5. Review Protocol

<protocol.md 内容,逐字包含>

### Adversarial Challenges (必须逐一回答)

1. 文件 <改动行数最多的文件> 的第 <最大 hunk 起始行> 行附近是最复杂的改动。如果它收到空输入或超长输入,会发生什么?
2. 本次改动是否改变了 <WRITE-SET 中另一个文件> 对 <改动文件> 的调用假设?
3. 如果 6 个月后需要修改这段代码,最大的理解障碍是什么?

### Linter Findings Summary (若存在)

v1 review 已报告: <N> security findings, <M> quality findings。
请在 overall_assessment 中说明你对这些发现的看法(同意/补充/不同意)。

## 6. Output Format (严格遵循)

将审查结果写入 `engine/review/evidence/T-NNN/AGENT-REVIEW.json`。
Schema 如下(所有字段必须存在):

```json
<完整 AGENT-REVIEW.json schema 示例,见 §4>
```

**重要**:
- `write_provenance.commit` 填写本 package 头部的 `head_commit` 值
- `write_provenance.package_sha256` 填写本 package 头部的 `package_sha256` 值
- 每条 finding.message ≥ 20 字
- 每个维度至少 1 条 entry(可以是 type=strength 表示"确认无问题")
```

### 2.2 上下文收集算法(bash 可实现版)

```bash
# 审核修订 R1: 去掉 AST 解析,只用 grep/awk 启发式

# 1. diff 范围: 复用 v1 task_first_commit 算法(不重新发明)
# 2. diff 文件: WRITE-SET ∩ code_extensions ∩ git diff --name-only
# 3. 周边上下文(启发式,接受噪声):
#    a. 从 diff hunk headers 提取函数名:
#       git diff -U0 | grep '^@@' | sed 's/.*@@[[:space:]]*//' | head -20
#       (git diff hunk header 自带最近的函数定义行,语言无关)
#    b. 在 WRITE-SET 其他文件中 grep 这些函数名 → 调用方
#    c. 每个周边文件取匹配行 ± 10 行上下文(≤50 行/文件)
#    d. 总周边上下文 ≤500 行,按匹配次数排序截断
# 4. 域知识: federation.json 路由 → 读 INVENTORY(≤100 行) + PITFALLS(≤50 行)
# 5. 二进制文件: 列名 + [binary, not shown] 标记,不计入行数预算
```

**关键**(审核修订):用 `git diff` hunk header 的函数上下文(git 自带,语言无关)代替"awk 解析函数定义"。这避免了多语言 parser 问题,且 bash/ps1 都能调 git。

### 2.3 大小控制

| 段 | 预算 | 超出策略 |
|----|------|---------|
| §1 任务上下文 | 不限(通常 <100 行) | — |
| §2 diff | 不限(核心,必须完整) | — |
| §3 周边上下文 | ≤500 行 | 按匹配频率排序截断 |
| §4 域知识 | ≤150 行 | 只取相关域 |
| §5 protocol + challenges | 固定(~120 行) | — |
| §6 输出格式 | 固定(~60 行) | — |
| **总计** | **≤2000 行** | 先砍 §3,再砍 §4 |

### 2.4 无代码变更处理(审核补充)

若 WRITE-SET 内无 code_extensions 匹配文件,或 diff 为空:
```
exit 0
stdout: "[engine-review-agent] T-NNN: no code changes in WRITE-SET, agent review skipped"
```
不产 review-package.md。validate 时若无 review-package.md → exit 0 "nothing to validate"。

---

## 3. Review Protocol(审查协议)

### 3.1 审查维度(5 维,固定)

| 维度 | key | 审查什么 | 示例 finding |
|------|-----|---------|-------------|
| 正确性 | correctness | 逻辑错误/边界条件/竞态/死锁 | "L42: 当 input=[] 时返回值未初始化" |
| 设计 | design | 抽象层级/职责划分/耦合度 | "config 解析与业务逻辑混在同一函数" |
| 跨文件一致性 | consistency | 接口同步/命名一致/镜像对齐 | ".sh 加了参数但 .ps1 未同步" |
| 可读性 | readability | 命名/注释/复杂度/组织 | "嵌套 4 层 if,建议 early return" |
| 遗漏 | completeness | 缺失的错误处理/测试/边界 | "无 WRITE-SET 时没有 exit 1" |

**v1 固定 5 维**(审核修订):不支持自定义维度。protocol.md 可补充审查要点,但维度数固定。自定义维度留 v2。

### 3.2 反橡皮图章机制(v1 精简版)

审核修订:砍到 2 层可机器验证的结构化检查 + 1 层静态挑战。动态对抗和逐条交叉校验留 v2。

**层 1: 结构约束(validate 硬校验)**
```
- 每维度 entries ≥ 1(finding 或 strength 均算)
- 每条 finding.message ≥ 20 字符
- overall_assessment + 5 × summary 总字符 ≥ 200
- adversarial_responses 恰好 3 条,每条 response ≥ 30 字符
```

**层 2: 静态对抗挑战(嵌入 package)**
```
3 个固定模板问题(参数化:文件名 + 行号):
1. "文件 {most_changed_file} 第 {largest_hunk_line} 行附近是最复杂的改动。
    如果它收到空输入或超长输入,会发生什么?"
2. "本次改动是否改变了 {another_writeset_file} 对 {changed_file} 的调用假设?"
3. "如果 6 个月后需要修改这段代码,最大的理解障碍是什么?"
```

参数填充算法(bash 可实现):
- `most_changed_file`: `git diff --stat $base..HEAD | sort -t'|' -k2 -rn | head -1`
- `largest_hunk_line`: `git diff -U0 $base..HEAD -- $file | grep '^@@' | awk -F'[+ ,]' '{print $3}' | sort -rn | head -1`
- `another_writeset_file`: WRITE-SET 中除 most_changed_file 外的第一个代码文件

**层 3: Linter 摘要(软约束,v1 不做硬校验)**
```
若 v1 SECURITY/QUALITY.json 存在且有 findings:
  package §5 末尾注入摘要 "v1 已报告 N security + M quality findings"
  要求 reviewer 在 overall_assessment 中提及
  validate 不硬校验(v1.1 再加)
```

### 3.3 protocol.md(L0 默认,逐字包含)

`engine/review/protocol.md` 是纯 markdown,Phase 1 逐字包含到 package §5。无模板语法,无占位符(审核修订:去掉模板渲染复杂度)。

项目可通过 L1 覆盖(修改此文件)来增加审查要点,但 5 维度 + 3 挑战是固定的。

---

## 4. AGENT-REVIEW.json Schema(Phase 2 输出)

```json
{
  "task": "T-NNN",
  "timestamp": "2026-07-31T12:00:00Z",
  "reviewer": {
    "type": "agent",
    "model": "(可选,agent 自报)",
    "session_id": "(可选)"
  },
  "status": "pass|concerns|block",
  "dimensions": {
    "correctness": {
      "entries": [
        {
          "id": "agent-correctness-engine/scripts/engine-review.sh:42",
          "severity": "high",
          "type": "finding",
          "file": "engine/scripts/engine-review.sh",
          "line": 42,
          "message": "当 WRITE-SET 包含空格路径时,for 循环的 word splitting 会错误拆分路径",
          "suggestion": "使用 while IFS= read -r 替代 for 循环"
        }
      ],
      "summary": "发现 1 个路径处理问题,整体逻辑正确"
    },
    "design": { "entries": [...], "summary": "..." },
    "consistency": { "entries": [...], "summary": "..." },
    "readability": { "entries": [...], "summary": "..." },
    "completeness": { "entries": [...], "summary": "..." }
  },
  "adversarial_responses": [
    {"challenge": "(原始问题 1)", "response": "(≥30 字符回答)"},
    {"challenge": "(原始问题 2)", "response": "(≥30 字符回答)"},
    {"challenge": "(原始问题 3)", "response": "(≥30 字符回答)"}
  ],
  "overall_assessment": "整体评价(2-3 句)",
  "write_provenance": {
    "writer": "agent-reviewer",
    "commit": "(= package 头部 head_commit)",
    "timestamp": "(写入时间)",
    "package_sha256": "(= package 头部 package_sha256)"
  }
}
```

### 4.1 关键修订(审核 R1)

**Provenance 模型重设计**:

原有 v1 provenance(writer/commit/argv)是为"引擎脚本自己写 evidence"设计的。agent-reviewer 的 evidence 由外部 agent 写入,provenance 语义不同:

| 字段 | v1 (engine-review) | v2 (agent-reviewer) | 理由 |
|------|-------|--------|------|
| writer | engine-review | agent-reviewer | 标识谁写的 |
| commit | HEAD(脚本运行时) | package.head_commit(回显) | agent 无 git 访问时也能填 |
| argv | "engine review T-NNN" | **删除** | agent 没跑任何 engine 命令 |
| package_sha256 | 无 | review-package.md 的 sha256 | 证明基于正确输入 |
| validated_by | 无 | "engine review-agent T-NNN --validate"(Phase 3 写入) | 引擎背书 |

**核心改变**:agent 只需回显 package 中预填的 `head_commit` 和 `package_sha256`(证明它读了 package),不需要有 git 访问权限。引擎在 Phase 3 validate 时追加 `validated_by` 字段作为引擎背书。

**pre-commit provenance 校验相应调整**:
```bash
# agent-reviewer evidence 的校验逻辑:
# writer == "agent-reviewer" → OK
# package_sha256 == sha256(review-package.md) → OK(引擎可独立验证)
# 不校验 commit(回显值,非实时 git 状态)
# 不校验 argv(无此字段)
```

### 4.2 Entry 格式

```json
{
  "id": "agent-<dimension>-<file>:<line>",
  "severity": "critical|high|medium|low|info",
  "type": "finding|strength",
  "file": "<repo-relative path, 用 />",
  "line": "<int, 文件行号(非 diff 行号)>",
  "message": "<≥20 字符>",
  "suggestion": "<可选修复建议>"
}
```

**审核修订**:去掉 `severity: "strength"`(语义重载)。用 `type: "strength"` + `severity: "info"` 表达"这个维度确认无问题"。severity 保持纯严重度语义。

### 4.3 Status 语义

| status | 含义 | 对 done 的影响 |
|--------|------|---------------|
| pass | 无 critical/high findings | 不阻塞 |
| concerns | 有 high findings 但 reviewer 认为可继续 | Doctor WARN |
| block | 有 critical findings | 阻塞 done(需 D-xxx waive) |

---

## 5. Validate(Phase 3)校验逻辑

### 5.1 错误码分类(审核补充)

```
E_MISSING   — AGENT-REVIEW.json 不存在
E_SCHEMA    — 缺必须字段 / 类型错误
E_SHALLOW   — 反橡皮图章不达标(内容太少)
E_PROVENANCE — package_sha256 不匹配 / writer 错误
E_STALE     — package 过旧(WARN,不 FAIL)
```

输出格式:`[engine-review-agent] FAIL <CODE>: <human message>`(stderr)
成功格式:`[engine-review-agent] T-NNN: AGENT REVIEW PASS (N findings, M strengths)`(stdout)

### 5.2 Schema 完整性(E_SCHEMA)

```
必须字段: task, timestamp, status, dimensions(5 维全在),
          adversarial_responses(恰好 3), overall_assessment,
          write_provenance(writer + commit + package_sha256)
每维度: entries ≥ 1, summary 非空
每条 entry: id/severity/type/file/line/message 全在
reviewer/confidence/session_id: 可选,不校验
```

### 5.3 反橡皮图章(E_SHALLOW)

```
1. 每维度 entries ≥ 1 → 否则 FAIL "dimension <X> has no entries"
2. 每条 entry.message 字符数 ≥ 20 → 否则 FAIL "entry <id> message too terse (N < 20)"
3. overall_assessment + 5 × summary 总字符 ≥ 200 → 否则 FAIL "narrative too shallow (N < 200)"
4. adversarial_responses 恰好 3 条,每条 response ≥ 30 字符
   → 否则 FAIL "adversarial challenges not properly answered"
```

### 5.4 Provenance(E_PROVENANCE)

```
1. writer == "agent-reviewer" → 否则 FAIL
2. package_sha256 == sha256(engine/review/evidence/T-NNN/review-package.md)
   → 否则 FAIL "review based on different package (regenerate?)"
3. commit == package 头部 head_commit(字符串比较)
   → 否则 FAIL "commit mismatch (agent did not echo package head_commit)"
```

### 5.5 Staleness(E_STALE, WARN only)

```
review-package.md 内嵌 timestamp 与当前时间差 > max_package_age_hours(默认 72)
→ WARN "package is N hours old, consider regenerating"
不 FAIL(不阻塞,只提醒)
```

### 5.6 Validate 通过后

```
1. 追加 validated_by 到 AGENT-REVIEW.json:
   "validated_by": "engine review-agent T-NNN --validate"
   "validated_at": "<timestamp>"
2. 更新 REVIEW.json dimensions 追加 agent_review 段
3. 重算 evidence_manifest_sha256(含 AGENT-REVIEW.json + review-package.md)
4. exit 0
```

### 5.7 Retry 处理(审核补充)

validate FAIL 时:
- 不删除/不修改 AGENT-REVIEW.json(保留供诊断)
- 错误消息含机器可读 code(harness 可据此决定 retry 策略)
- 无 attempt 计数(v1 不限重试次数)
- 用户/harness 修改 AGENT-REVIEW.json 后重跑 --validate

---

## 6. 配置扩展

### 6.1 config.json 新增段

```json
{
  "defaults": {
    "dimensions": ["security", "quality"],
    "agent_review": {
      "enabled": false,
      "min_entries_per_dimension": 1,
      "min_narrative_chars": 200,
      "min_entry_message_chars": 20,
      "adversarial_challenges": 3,
      "max_package_lines": 2000,
      "max_surrounding_context_lines": 500,
      "max_domain_knowledge_lines": 150,
      "max_package_age_hours": 72
    }
  },
  "overrides": {}
}
```

**审核修订**:
- `agent_review` 是独立配置段,**不加入 `dimensions[]` 数组**(避免 v1 pipeline 误路由)
- 默认 `enabled: false`(opt-in)
- 去掉 `protocol` 路径配置(固定 `engine/review/protocol.md`)
- 去掉 named presets(strict/default),直接用数值配置
- L2 REVIEW-OVERRIDE 可直接覆盖数值(如 `- min_narrative_chars: 400`)

### 6.2 L2 REVIEW-OVERRIDE 扩展

```markdown
## REVIEW-OVERRIDE

- add_dimensions: agent_review
- min_narrative_chars: 400
```

`add_dimensions: agent_review` 使本任务强制要求 agent review(即使 config enabled=false)。
数值覆盖走标准 L2 > L1 > L0 合并(只允许提级/加严,不允许降低)。

### 6.3 路由区分(审核补充)

```
dimensions[] 数组 → 路由到 v1 linter pipeline(engine review)
agent_review 段 → 路由到 agent pipeline(engine review-agent)
两者独立运行,互不干扰
```

---

## 7. Doctor + pre-commit 集成

### 7.1 Doctor 新增检查

**check_agent_review_evidence**(sh)/ **Test-AgentReviewEvidence**(ps1):
```
对每张 done 卡:
1. 判定是否要求 agent review:
   - config agent_review.enabled == true,或
   - 任务卡 REVIEW-OVERRIDE 含 add_dimensions: agent_review
2. 若要求:
   - 无 AGENT-REVIEW.json:
     - 新 done 卡(HEAD status≠done)→ FAIL "agent review required but missing"
     - 历史 done 卡(HEAD 已 done)→ WARN "legacy done without agent review"
   - 有 → 校验 status:
     - block → FAIL "unresolved agent review block findings"
     - concerns → WARN "agent review has concerns, architect should confirm"
     - pass → OK
3. 若不要求:
   - 有 AGENT-REVIEW.json → 不检查(INFO 级别)
   - 无 → 不检查
```

### 7.2 pre-commit provenance 扩展

在 T-070 已有的 review evidence provenance 块中扩展:
```bash
# 路径路由:
# engine/review/evidence/T-NNN/REVIEW.json → writer=engine-review(既有)
# engine/review/evidence/T-NNN/AGENT-REVIEW.json → writer=agent-reviewer(新增)
# engine/review/evidence/T-NNN/review-package.md → 不校验 provenance(引擎产物)

case "$_prov_writer" in
  engine-review) : ;;        # 既有
  agent-reviewer) : ;;       # 新增
  *) FAIL ;;
esac

# agent-reviewer 不校验 argv(无此字段)
# agent-reviewer 校验 package_sha256(引擎可独立重算)
```

### 7.3 protected_paths 扩展

rules.json 追加:
```json
"engine/scripts/engine-review-agent*",
"plugin/engine/scripts/engine-review-agent*",
"engine/review/protocol.md"
```

---

## 8. 执行模式(Phase 2 如何跑)

### 8.1 Claude Code 原生模式(推荐)

```
协调者/用户:
  1. engine review-agent T-NNN --package
  2. Agent tool 派子代理:
     "Read engine/review/evidence/T-NNN/review-package.md.
      Follow the Review Protocol in §5 exactly.
      Write your findings as JSON to engine/review/evidence/T-NNN/AGENT-REVIEW.json
      following the schema in §6. Fill write_provenance.commit and
      write_provenance.package_sha256 from the package header values."
  3. engine review-agent T-NNN --validate
```

### 8.2 其他 harness(Cursor/Copilot/web)

```
1. engine review-agent T-NNN --package
2. 用户复制 review-package.md 到目标 agent
3. agent 输出 JSON → 用户保存到 AGENT-REVIEW.json
4. engine review-agent T-NNN --validate
```

**审核修订**:因为 provenance 只需回显 package 头部值(不需 git 访问),任何 harness 都能正确填写。

### 8.3 CI 模式(v2,不实现)

预留接口:`--package` 和 `--validate` 已是原子操作,CI 只需在中间插 LLM API 调用。

---

## 9. 与 v1 pipeline 的关系

### 9.1 独立但互补

```
完整审查流程(推荐顺序,非强制):
  engine verify T-NNN        → 行为验收(AC 命令)
  engine review T-NNN        → linter 审查(semgrep + eslint,秒级)
  engine review-agent T-NNN --package  → 打包(秒级)
  [agent 审查]                         → 语义审查(分钟级)
  engine review-agent T-NNN --validate → 校验(秒级)
```

### 9.2 v1 findings 注入(软依赖)

Phase 1 打包时检查 v1 evidence:
- `engine/review/evidence/T-NNN/SECURITY.json` 存在且有 findings → 注入摘要到 package
- 不存在 → 跳过(不强制先跑 v1)

### 9.3 REVIEW.json 统一视图

validate 通过后,REVIEW.json 最终形态:
```json
{
  "dimensions": {
    "security": {"status": "pass", "findings_count": {...}},
    "quality": {"status": "pass", "findings_count": {...}},
    "agent_review": {
      "status": "pass|concerns|block",
      "findings_count": {"critical": 0, "high": 1, "medium": 3, "low": 2, "info": 5},
      "confidence": "(可选)",
      "protocol_version": "v6.21.0"
    }
  },
  "status": "pass"
}
```

**Overall status 规则**:
- security/quality 的 block → overall block(既有)
- agent_review 的 block(critical findings)→ overall block
- agent_review 的 concerns → overall 不升 block(架构师裁决权)

---

## 10. 镜像策略(审核修订)

### 10.1 行为镜像 vs byte-identical

v1 的 engine-review-pipeline.sh/.ps1 是 byte-identical(相同 bash 语法,因为 ps1 也在 Git Bash 下跑)。

agent-reviewer 的 package 算法涉及更多文本处理(git diff 解析、上下文收集),ps1 需要用 PowerShell 原生 cmdlet(Select-String、Get-Content)实现。

**决策**:engine-review-agent*.ps1 是**行为镜像**(相同输入 → 相同 review-package.md 输出),不要求 byte-identical。

### 10.2 测试 AC

```
AC: 给定 fixture repo,sh 和 ps1 产出的 review-package.md 内容一致
    (允许行尾 CRLF/LF 差异,用 diff --strip-trailing-cr 比较)
```

---

## 11. 并发控制(审核补充)

复用 v1 flock/mkdir 模式:
```bash
# .sh
exec 200>"$ENGINE_DIR/review/.review-agent-lock.$task"
flock -n 200 || { echo "[engine-review-agent] another review-agent running for $task"; exit 1; }

# .ps1
$stream = [System.IO.File]::Open("$ENGINE_DIR\review\.review-agent-lock.$task", 'Create', 'ReadWrite', 'None')
# try/finally 保证释放
```

锁文件:`.review-agent-lock.T-NNN`(与 v1 `.review-lock.T-NNN` 分开,允许 v1 和 agent 并行)。

---

## 12. 任务卡规划

### 12.1 拆分(2 张卡)

#### T-NNN: agent-reviewer 核心(--package + --validate)

```
GOAL: 实现 engine review-agent T-NNN --package/--validate 两阶段命令
 estimated_steps: ~30 | checkpoint_plan: per-AC

WRITE-SET:
  - engine/bin/engine, engine/bin/engine.ps1
  - plugin/engine/bin/engine, plugin/engine/bin/engine.ps1
  - engine/scripts/engine-review-agent.sh / .ps1
  - engine/scripts/engine-review-agent-package.sh / .ps1
  - engine/scripts/engine-review-agent-validate.sh / .ps1
  - plugin/engine/scripts/(6 镜像)
  - engine/review/config.json
  - engine/review/protocol.md
  - engine/review/evidence/T-NNN/**
  - engine/domains/federation.json
  - engine/ENGINE_MAP.md
  - tests/workstream/test_review_agent_*.sh
  - VERSION, engine/VERSION, plugin/VERSION, plugin/manifest.json
  - CHANGELOG.md, install.sh, install.ps1
  - engine/tasks/T-NNN.md, engine/CONTEXT.md, engine/HANDOFF.md

FORBIDDEN:
  - engine/scripts/githooks/pre-commit(T-NNN+1)
  - engine/scripts/engine-doctor.*(T-NNN+1)
  - engine/decisions/rules.json(T-NNN+1)
  - contract/src/**
  - ENGINE_FILE_SYSTEM_v5.md

AC(预估 16 条):
  AC-1: CLI 入口(无模式标志 exit 2,usage 含 review-agent)
  AC-2: --package 产 review-package.md(含 diff + protocol + challenges)
  AC-3: --package 无代码变更 → exit 0 skip
  AC-4: --package 大小控制(≤2000 行)
  AC-5: --package 周边上下文(调用方识别,≤500 行)
  AC-6: --package 静态挑战生成(3 个参数化问题)
  AC-7: --package 注入 v1 linter 摘要(若存在)
  AC-8: --validate 缺 AGENT-REVIEW.json → exit 1 E_MISSING
  AC-9: --validate schema 不完整 → exit 1 E_SCHEMA
  AC-10: --validate 反橡皮图章不达标 → exit 1 E_SHALLOW
  AC-11: --validate package_sha256 不匹配 → exit 1 E_PROVENANCE
  AC-12: --validate 通过 → 更新 REVIEW.json + manifest hash
  AC-13: config agent_review.enabled=false + 无 L2 override → --package exit 0 skip
  AC-14: L2 add_dimensions: agent_review 覆盖 enabled=false
  AC-15: 并发锁(2 进程,1 持锁 1 exit 1)
  AC-16: sh/ps1 行为镜像(fixture 输出一致)

CONSTRAINTS:
  - 两阶段原子命令,无交互模式
  - 复用 v1 diff 算法(task_first_commit)
  - 周边上下文用 git diff hunk header + grep(无 AST)
  - protocol.md 逐字包含(无模板渲染)
  - JSON 解析用 python3(无 jq)
  - 5 维度固定,不可配置
  - provenance 回显模型(不要求 agent 有 git 访问)
```

#### T-NNN+1: agent-reviewer 门禁集成

```
GOAL: pre-commit provenance 扩展 + Doctor check + e2e
  depends-on: T-NNN

WRITE-SET:
  - engine/scripts/githooks/pre-commit + plugin 镜像
  - engine/scripts/engine-doctor.sh / .ps1 + plugin 镜像
  - engine/decisions/rules.json
  - engine/review/evidence/T-NNN+1/**
  - tests/workstream/test_doctor_agent_review.sh
  - tests/workstream/test_review_agent_e2e.sh
  - engine/tasks/T-NNN+1.md, engine/CONTEXT.md, engine/HANDOFF.md

AC(预估 9 条):
  AC-1: pre-commit writer=agent-reviewer 通过
  AC-2: pre-commit package_sha256 校验(篡改 → FAIL)
  AC-3: pre-commit 错误 writer → FAIL
  AC-4: Doctor enabled=true + 新 done 无 evidence → FAIL
  AC-5: Doctor enabled=true + status=block → FAIL
  AC-6: Doctor enabled=true + status=concerns → WARN
  AC-7: Doctor enabled=false → 不检查
  AC-8: e2e(package → 模拟 agent 写入 → validate → commit → doctor 全绿)
  AC-9: Doctor sh/ps1 行为一致
```

### 12.2 实施顺序

1. T-NNN Phase A: CLI + dispatcher + config 扩展 + protocol.md + 锁
2. T-NNN Phase B: --package(diff + 上下文 + 挑战 + 大小控制)
3. T-NNN Phase C: --validate(schema + 反橡皮图章 + provenance + REVIEW.json 集成)
4. T-NNN Phase D: 行为镜像 + 全量测试
5. T-NNN+1 Phase A: pre-commit 扩展
6. T-NNN+1 Phase B: Doctor 检查
7. T-NNN+1 Phase C: e2e + 自审

---

## 13. 风险与缓解

| 风险 | 缓解 |
|------|------|
| Agent 自审橡皮图章 | 结构化校验(§3.2);validate 硬 FAIL;架构师可 L2 加严 |
| review-package 太大 | 2000 行硬限 + 分段截断;diff 永远完整 |
| 周边上下文噪声(grep 假阳性) | 接受;reviewer 有能力忽略;用 git hunk header 降低噪声 |
| agent 不写标准 JSON | validate E_SCHEMA 硬 FAIL;package §6 给完整示例 |
| 不同 agent 审查质量差异 | protocol 标准化最低要求;validate 保证结构;质量靠架构师判断 |
| 同一 agent 实现+审查 | v1 接受(静态挑战对抗);v3 可要求不同 session |
| package 时代码变了 | package_sha256 校验;staleness WARN |
| Windows ps1 行为差异 | 行为镜像(非 byte-identical);fixture 测试校验 |
| 并发竞争 | flock/FileStream 锁(与 v1 独立锁文件) |

---

## 14. 未来路线(v2/v3)

| 项 | 触发条件 | 说明 |
|----|---------|------|
| 动态对抗挑战 | v2 | AST 感知的问题生成(最复杂函数/调用链分析) |
| 逐条 linter 交叉校验 | v2 | 对每条 v1 finding 要求 agree/disagree |
| 多 reviewer 共识 | v3 | 2+ agent 独立审查,取交集 |
| 不同 session 强制 | v3 | session_id ≠ implement agent |
| CI 集成 | 有需求 | GitHub Actions 中调 LLM API |
| 增量审查 | 大任务 | 只审最近 N commit 增量 |
| 自定义维度 | v2 | protocol.md 声明第 6+ 维度,validate 动态适配 |
| capsule 融合 | D-019d 落地 | review-package 成为 capsule 的 review 变体 |
| review 质量反馈环 | 数据积累 | waive/accept 记录 → 调整 protocol 严格度 |

---

## 15. 审核历史

| 轮次 | 识别问题 | 关键修订 |
|------|---------|---------|
| 1 | 5 类 20+ 项(3 critical + 4 inconsistency + 6 missing + 4 over-eng + 5 under-specified) | 去交互模式;provenance 回显模型;去 argv;静态挑战替代动态;severity 去 strength;行为镜像;错误码分类;无代码变更处理;并发锁;config 路由区分;retry 保留;staleness WARN |

---

## 16. 未解决问题(留给实施时)

1. **git diff hunk header 质量**:某些文件(纯 JSON/纯 markdown)的 hunk header 无函数名,周边上下文收集会退化。接受,v2 再优化。
2. **review-package.md 是否进 git**:建议进(可审计"基于什么做的审查")。它是 evidence 的一部分。
3. **protocol.md 初始内容**:需要写一份 ~100 行的默认审查协议。实施时起草。
4. **AGENT-REVIEW.json 的 line 字段**:文件行号(非 diff 行号)。agent 可能填错——validate 不校验行号精确性(只校验是正整数)。
