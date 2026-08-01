# TencentDB-Agent-Memory × Engine System 统合分析

## 一句话定位差异

TDAI 解决的是 **agent 知道什么**（知识积累与压缩）；Engine 解决的是 **agent 可以做什么**（治理与验证）。两者在"分层记忆 + 钩子生命周期 + 可追溯性"上大面积同构，但作用面正交——TDAI 是运行时认知层，Engine 是运行时治理层。

---

## 架构同构对照

| 维度 | TDAI | Engine System | 同构程度 |
|------|------|---------------|----------|
| 分层记忆 | L0(对话)→L1(原子事实)→L2(场景)→L3(人格) | L0(代码)→domain CONTEXT→ENGINE_MAP→L0-runtime-law | 结构同构，语义正交 |
| 上下文预算 | token ratio 触发压缩(mild 50%/aggressive 85%/emergency 95%) | 契约行数预算(2896/2940) + L2 assembly <=400行 | 目标相同，粒度不同 |
| 钩子生命周期 | after-tool-call / before-prompt-build / before-agent-start | SessionStart / PreToolUse / Stop / pre-commit | 完全同构 |
| 可追溯链 | persona→scene→atom→conversation (node_id) | GATE.json→AC evidence→verify output→code fingerprint | 完全同构 |
| 多会话隔离 | per-agent 目录 + session registry | coordinator lease + workstream shards | 目标相同，机制不同 |
| 白盒可调试 | Markdown scene blocks + Mermaid canvas | ENGINE_MAP registry + evidence JSON + CONTEXT trust levels | 理念一致 |
| 去重/冲突 | L1 vector dedup + LLM 4-action judgment | 无直接对应（决策覆盖语义） | TDAI 独有 |
| 写治理 | 无 | WRITE-SET/FORBIDDEN + union gating + seal | Engine 独有 |
| 验证闭环 | 无（记忆质量靠 LLM 判断） | engine verify → PASS/FAIL → GATE.json → done | Engine 独有 |

---

## TDAI 中可集成进 Engine 的设计

### 1. 符号化短期记忆（Mermaid Canvas）→ 任务进度自动生成

**TDAI 做法**: 每次 tool call 后自动提取摘要，L2 pipeline 将摘要编织成 Mermaid flowchart（node_id 标注 done/doing/todo），注入 agent 上下文作为任务感知层。

**Engine 现状**: `progress.md` 由 agent 手动维护，7 个 section，容易在 context compaction 后丢失或过时。

**集成方案**: 在 PreToolUse/Stop hook 中观察 tool 执行轨迹，自动生成 task card 对应的 Mermaid canvas。不替代 progress.md（那是恢复锚点），而是作为 SessionStart 注入的**视觉状态摘要**——agent 一眼看到任务全貌，不需要读完整 progress.md。

**成本**: 低。Mermaid 生成是纯文本拼接，不需要 LLM 调用。node_id 映射可以从 AC 编号 + verify 状态直接派生。

**杠杆**: 解决 context compaction 后 agent 丢失任务全局视图的核心痛点。

---

### 2. 上下文卸载（Context Offload）→ 长会话治理

**TDAI 做法**: 三级压缩（mild: 用摘要替换原文 → aggressive: 删除最旧消息 → emergency: 硬删到 60%），配合 Mermaid canvas 保持任务感知。

**Engine 现状**: SessionStart 注入上下文，但**不管理会话中途的上下文溢出**。长会话（100+ tool calls）中 agent 的上下文窗口被 tool output 填满，engine 注入的规则被挤出窗口。

**集成方案**: 在 `--guard` 模式（UserPromptSubmit 短刷新）中增加上下文压力检测。当检测到 engine 规则被挤出有效窗口时，触发**规则重注入**（不是压缩 tool output——那是 host 的事，而是确保 L0-runtime-law + 当前任务边界始终在 agent 可见范围内）。

**成本**: 中。需要 host 配合（Claude Code 的 context compaction 是黑盒），但 guard 模式已有重锚定机制，扩展即可。

**杠杆**: 解决长会话中 agent "忘记规则" 的根本问题——目前只靠 compaction summary 里的残留记忆。

---

### 3. 自动 L1 提取 → PITFALLS/CONTEXT 自动策展

**TDAI 做法**: 每 N 轮对话自动提取原子事实，LLM 判断 store/skip/update/merge，写入 VectorStore + JSONL 双写。

**Engine 现状**: PITFALLS.md 和 domain CONTEXT.md 完全手动维护。agent 踩坑后是否记录取决于 agent 自觉性和 Stop hook 的 write-back 检查。

**集成方案**: 在 Stop hook 中增加**失败模式检测**——如果会话中出现 verify FAIL、pre-commit 拦截、或 agent 重试同一操作 3+ 次，自动提取一条 pitfall 候选，追加到对应 domain 的 PITFALLS.md 候选区（`## Auto-detected (pending review)`）。架构师定期 review 后提升为正式条目或删除。

**成本**: 低。不需要 LLM——模式匹配即可（FAIL + 路径 + 错误信息 → 结构化条目）。

**杠杆**: 解决"陷阱重复踩"问题。目前 PITFALLS 的增长完全依赖人工，覆盖率低。

---

### 4. 混合检索（BM25 + Vector + RRF）→ Read-Gate 增强

**TDAI 做法**: recall 时并行跑 keyword（FTS5 BM25）和 embedding（cosine），RRF 融合排序，5s 超时降级。

**Engine 现状**: read-gate 是**路径驱动**的——federation.json 把 path-glob 映射到 domain，agent 必须知道要改哪个路径才能找到对应规则。

**集成方案**: 为 `engine context` 增加**语义查询模式**——agent 描述意图（"我要改编译流程"），系统在契约规则 + PITFALLS + 决策历史中做 BM25 检索，返回相关条目。不替代路径路由（那是精确匹配），而是补充**意图路由**（模糊匹配）。

**成本**: 中高。需要索引构建（契约 dist + PITFALLS + decisions 全文索引）。但不需要 embedding——纯 BM25 即可覆盖（引擎术语是确定性的，不是自然语言模糊查询）。

**杠杆**: 解决新 agent/新会话"不知道去哪找规则"的冷启动问题。

---

### 5. 场景块（Scene Blocks）→ 变更胶囊演进

**TDAI 做法**: L2 scene 是有结构的叙事文档（META header + heat + evolution trajectory），支持 UPDATE/MERGE/CREATE 三种操作，heat 追踪活跃度。

**Engine 现状**: `engine/changes/` 变更胶囊是扁平的一次性记录，无演进语义。

**集成方案**: 给变更胶囊增加 META header（created/updated/heat/related-decisions）和**演进轨迹** section。同一功能域的多次变更可以 MERGE 为一个活胶囊（类似 scene block 的 heat 累积），而不是每次都是一独立文件。Doctor 检查胶囊 heat——超过 N 次更新的胶囊提示架构师提取为正式决策或 PITFALLS。

**成本**: 低。格式扩展 + Doctor 检查规则。

**杠杆**: 让变更历史从"日志"变成"知识"——目前胶囊写完就冷，无人回看。

---

### 6. Persona 生成 → 项目画像自动演进

**TDAI 做法**: 每 N 条新记忆触发 persona 重生成，四层深扫模型（绿/蓝/黄/红），增量演进协议（strengthen/supplement/correct/restructure/no-change）。

**Engine 现状**: 项目"画像"散落在 ENGINE_MAP（结构）、CONTEXT（状态）、decisions（选择）中，无统一的项目特征文档。

**集成方案**: 引入 `engine/PROFILE.md`——从决策历史 + 变更胶囊 + PITFALLS 自动合成的**项目认知画像**。内容：架构风格偏好、技术债分布、高风险区域、团队约定。每次 done 一个 task card 时增量更新（类似 TDAI 的 incremental persona）。SessionStart 注入时作为"项目性格"补充 L0-runtime-law。

**成本**: 中。需要 LLM 合成（但频率极低——每个 task done 才触发一次）。

**杠杆**: 让新 agent/新会话快速理解"这个项目是什么样的"，而不只是"这个项目有什么规则"。

---

## 不建议集成的部分

| TDAI 特性 | 不集成原因 |
|-----------|-----------|
| Vector embedding 存储 | Engine 的知识是确定性的（规则/决策/路径），不需要语义相似度检索。BM25 足够。引入 embedding 增加部署复杂度，违背"零依赖 bash 脚本"的产品定位。 |
| LLM 驱动的记忆提取 | Engine 的 agent 本身就是 LLM——让 agent 自己判断什么值得记录（现有 write-back 机制）比外挂一个提取 pipeline 更自然。TDAI 需要外挂是因为它的 host agent 不感知记忆系统。 |
| Gateway HTTP 服务 | Engine 是文件级系统（git-native），不引入常驻进程。所有状态在文件中，所有操作是脚本。 |
| Token 精确计数（tiktoken） | Engine 的预算管理是行数/字节级（契约编译），不需要 token 精度。Host 的 compaction 是黑盒，engine 无法控制。 |

---

## 集成优先级排序

| 优先级 | 方案 | 理由 |
|--------|------|------|
| P0 | #1 Mermaid 任务状态 | 零 LLM 成本，直接解决 compaction 后丢失全局视图的高频痛点 |
| P0 | #3 失败模式自动提取 | 零 LLM 成本，模式匹配即可，解决陷阱重复踩 |
| P1 | #5 变更胶囊演进 | 低成本格式扩展，让冷数据变活 |
| P1 | #2 长会话规则重注入 | 扩展现有 guard 机制，解决长会话规则遗忘 |
| P2 | #4 语义 read-gate | 需要索引基础设施，但 BM25-only 方案可控 |
| P2 | #6 项目画像 | 需要 LLM 调用，频率低但价值高，可以后做 |

---

## 设计哲学对比总结

TDAI 的核心信念：**记忆应该自动形成、分层存储、按需召回**。它是"认知增强"——让 agent 更聪明。

Engine 的核心信念：**规则应该显式声明、机器验证、证据闭环**。它是"制度约束"——让 agent 更可靠。

两者不冲突。一个可靠的 agent 既需要制度约束（Engine），也需要认知增强（TDAI 式记忆）。集成方向是：**用 TDAI 的自动化记忆形成机制，服务于 Engine 的治理目标**——不是让 agent "记住更多"，而是让 agent "更快找到该遵守的规则"和"不重复犯已知的错误"。
