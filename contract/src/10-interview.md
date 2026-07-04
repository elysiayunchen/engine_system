# ════════════════════════════════════════════
# INIT PATH （首次初始化；运维模式请跳至文末 OPERATIONAL MODES）
# ════════════════════════════════════════════


## PRE‑INTERVIEW — SCALE & PROFILE SELECTION


**Step 0 — 锚点探测与吸收 (Anchor Probe)：** 提问前先探测项目中已有的 agent 指令文件：`CLAUDE.md`、`AGENTS.md`、`.cursorrules`、`.github/copilot-instructions.md` 等（CLI 下直接读；WEB‑FULL 下请开发者粘贴）。若存在，MUST 作为 Developer Context 读取：其中的协作规则、约束、陷阱将在 PHASE 2 吸收进引擎文件，原文件改写为薄引导器（见 ANCHOR LAYER「吸收再指向」）。改写前 MUST 向架构师列出吸收清单并确认。


Before starting Block 0, ask TWO questions in one turn:


> “开始之前快速确认两件事：
>
> **(1) 项目规模：**
> ① 个人/小型项目（1‑3人，<100文件）
> ② 团队项目（4人以上或架构较复杂）
> ③ 企业级/多服务（微服务、多仓库）
>
> **(2) 我主要在哪里帮你干活？**
> ⓐ 网页对话框（你把引擎文件发给我，我看不到你的代码）→ WEB‑FULL
> ⓑ Claude Code / 能直接读你代码的 agent → CLI‑LEAN
>
> 不确定 (2) 就选 ⓑ 如果你用命令行工具，否则选 ⓐ。”


Based on the answers:


| Scale | Blocks | Files | Notes |
|-------|--------|-------|-------|
| Solo/Small (①) | 0, A, B, C, D, E, G, H | 跳过 ROADMAP.md, SOURCEMAP.md（ENGINE_MAP 与锚点引导器始终生成）；包级 README 锚点仅在触发条件满足时生成 | 轻量采访；Block 0 必需 |
| Team (②) | All blocks | 全部文件 | 标准模式 |
| Enterprise (③) | All blocks + Block I | 全部文件 + SECURITY.md | 完整模式 |


| Profile | 生成影响 |
|---------|---------|
| WEB‑FULL (ⓐ) | 全部文件完整生成。采访用 Developer‑Assisted Investigation（命令‑粘贴）。 |
| CLI‑LEAN (ⓑ) | irreducible 文件完整生成；ARCHITECTURE 只生成 irreducible 章节 + 现生说明；SOURCEMAP 生成为 stub + 现生说明。采访时直接读代码，跳过命令‑粘贴。 |


记录两个选择。Profile 将写入 ENGINE_MAP §0。然后进入 Block 0。


---


## PHASE 1 — INTERVIEW


Conduct a structured interview. Follow these rules strictly:


**Interview Rules:**
- Ask ONE block at a time. Never dump all questions at once.
- After each block, summarize what you understood and ask the developer to confirm or correct before moving on.
- If an answer is vague, ask one follow‑up to make it concrete. Maximum 1 follow‑up per block, 6 follow‑ups total.
- If the developer says “skip” or “not applicable”, mark that field as N/A and move on.
- If the developer says “not sure yet”, mark that field as TBD and move on.
- Match the developer's language for the interview (usually Chinese).
- **探查优先原则 (Probe‑First Principle)**: For all technical factual questions (language, framework, build commands, directory structure, database, logging etc.), before quizzing the developer, the AI MUST first attempt to read the information directly. In CLI‑LEAN this means reading project files directly. In WEB‑FULL this means reading uploaded files, or offering safe read‑only investigation commands. Only ask the developer directly when the information is truly subjective (business logic, architectural decisions, personal experience of pitfalls).
- **类比与示例引导 (Analogy & Example Guidance)**: When the developer shows uncertainty about a technical concept, actively provide 2‑3 simple analogies or common options. E.g.:
  - “你的项目结构更像：① 一个单独的网页应用 ② 一个带后端的全栈网站 ③ 一个处理数据的命令行工具？”
  - “你想的用户登录方式：① 简单的邮箱+密码 ② 直接用微信/Google 账号登录 ③ 暂时不需要登录”


**Developer‑Assisted Investigation (WEB‑FULL only):**
The AI cannot access the codebase directly in web‑based sessions. For questions requiring technical details the developer may not know offhand, the AI provides exact commands to run.


Workflow:
1. AI recognizes a question is technical/factual and the developer may not know the answer
2. AI provides the exact command(s) to run and what to look for
3. Developer runs the command and pastes the output
4. AI interprets, summarizes in plain language (including a short “这是什么” explanation)
5. Developer confirms or corrects


Rules:
- Commands MUST be read‑only (no execution of project code, no writes), MUST be safe (no side effects).
- AI MUST explain what it's looking for before asking the developer to run anything.
- If the developer says “没权限” or “不方便查”, mark TBD and move on.
- If output is very long, AI asks for only the relevant parts.


**Investigation Offer Template:**
“这个信息可能需要查一下代码。你可以跑这个命令：
```bash
[exact command]
```
把输出发给我，我来帮你解读并告诉你这是什么意思。或者你已经知道答案了？”


**CLI‑LEAN Exception:** When operating with direct file access, skip the command‑and‑paste workflow — read files directly. Always summarize findings in plain language and ask for confirmation.


**File Upload Exception:** If the developer uploads code files directly (package.json, config files, etc.), read them directly and summarize. Same confirmation rules apply.


**Internal Process:** Maintain a running internal JSON as you interview. Use it to (1) track what you've gathered, (2) generate the Phase 1.5 confirmation, (3) populate files in Phase 2.


JSON schema:
{
  "profile": "WEB-FULL | CLI-LEAN",
  "scale": "solo | team | enterprise",
  "vision": { "problem": "", "threeKeyActions": [], "inspiration": "" },
  "identity": { "name": "", "alias": "", "type": "", "description": "", "stage": "", "repo": "" },
  "stack": { "language": "", "runtime": "", "frameworks": [], "deployment": "", "externalServices": [], "buildCommands": { "install": "", "dev": "", "build": "", "test": "" } },
  "architecture": { "folderStructure": "", "packages": [], "coreDataFlow": "", "keyDecisions": [], "dataLayer": { "database": "", "orm": "", "migrationStrategy": "", "schemaLocation": "" } },
  "state": { "lastCompleted": "", "inProgress": "", "broken": [], "blockers": [] },
  "sprint": { "tasks": [], "topPriority": "" },
  "roadmap": { "milestones": [], "plannedFeatures": [], "v1Definition": "", "futureBreakingChanges": [] },
  "pitfalls": { "commonMistakes": [], "hardBugs": [], "unreliableLibs": [], "configIssues": [], "neverDo": [] },
  "rules": { "conventions": [], "dangerousCommands": [], "depPolicy": "", "testStrategy": "", "editingPolicy": "", "aiDoAlways": [], "aiNeverDo": [] },
  "collaboration": { "roleDivision": "", "preChangeRequirements": [], "pausePoints": [], "blockerProtocol": "", "reportFormat": "", "languageRules": { "explanations": "", "code": "", "docs": "" } },
  "security": { "authModel": "", "secretsManagement": "", "sensitiveData": [], "aiForbiddenAreas": [] }
}


Do not show this JSON to the developer.


---


### BLOCK 0 — 项目愿景（必问，所有模式）
Ask:
1. 用一句最简单的话说，你的项目要帮谁解决什么问题？比如：“帮独立咖啡店老板记录每日销售和库存”或“展示我摄影作品集的个人网站”。
2. 当项目完成时，用户能做哪三件最重要的操作？（可以描述行为，比如“登录后能看到自己的数据仪表板”“上传照片并自动加水印”）
3. 有没有你欣赏的类似产品、网站或工具？它们哪一部分做得好，哪一部分你觉得可以改进？（可选）

[Purpose: Let AI understand the product direction and user experience goals. All subsequent technical decisions serve this vision.]


---


### BLOCK A — 项目身份
Ask:
1. 你的项目叫什么名字？（可以是暂定名或代号）
2. 用一句话描述：它做什么，谁来用？
3. 当前处于什么阶段：刚开始想 / 已经有了雏形 / 已经可以用了 / 已经有很多用户了？
4. 代码放在哪里？（GitHub 仓库地址、本地文件夹路径，或者还没建仓库？）


---


### BLOCK B — 技术栈
Ask:
5. 你的项目用什么编程语言写的？（不清楚的话我可以直接查看你的项目文件来告诉你）
   [可辅助查询]
6. 有没有用到现成的工具包或模版？比如和后端通信的框架、做界面组件的、处理用户登录的？（我可以从 package.json 或其他配置文件中找出来）
   [可辅助查询]
7. 项目最终会在哪里跑起来？网站、本地软件、手机应用、还是微信小程序？
   [需直接回答，涉及部署目标]
8. 项目需要连接哪些外部服务吗？比如发送邮件、支付、地图、第三方登录？
   [可辅助查询 + 你确认核心依赖]
9. 你平时怎么打开这个项目开始工作？需要先输入什么命令吗？（比如 `npm run dev`）
   [可辅助查询]


---


### BLOCK C — 架构
Ask:
10. 你的项目文件和文件夹是怎么组织的？不了解的话我可以列出主要目录并推测用途，你来确认。
    [可辅助查询]
11. 这个项目是一个整体，还是分了好几个独立的部分（前端 + 后台服务）？多个部分之间怎么互相对话？
    [可辅助查询 + 通信方式你说明]
12. 你最希望用户用的一个核心功能，从点一下按钮到看到结果，中间大概发生了哪些步骤？
    [需直接回答，涉及业务逻辑]
13. 开发过程中，有没有某个设计选择让你特别纠结，最后好不容易才定下来的？为什么？
    [需直接回答，经验性知识]
14. 你的用户数据存在哪里？本地文件、在线表格、还是数据库？（没想好我来按项目类型推荐）
    [可辅助查询]
15. 数据模型大概长什么样？有哪些“东西”你必须保存？有没有不能违反的规则？（比如“一个用户不能同时有两个相同的订单”）
    [可辅助查询 + 业务约束你说明]
16. 项目有没有记录日志或报错的方式？出 bug 时你怎么发现的？
    [可辅助查询]
16a. 从**产品**角度,你的项目分几大块？（比如:登录/账户、商城、后台管理、支付……不按代码分,按你心里的功能区说就行;只有一块也没关系。）
     [需直接回答——这是 v6 分形记忆的域划分来源:agent 把每个功能区映射成 path-glob 写进 `engine/domains/federation.json`,并用人话回确认。无编程经验者也答得出产品分区。]


---


### BLOCK D — 当前状态
Ask:
17. 上一个完成的重要功能或修复是什么？
18. 当前正在做的最重要的一件事是什么？
19. 有没有什么是现在坏掉的、不稳定的、或者你不敢碰的部分？
20. 有没有在等待别人或某个外部服务才能继续的事情？


---


### BLOCK E — 当前冲刺
Ask:
21. 列出你现在脑子里最想做的几件事（最多10个）。
22. 每件事做完后，你能看到什么具体变化？（比如“点‘发布’真的能把内容发出去”）
23. 哪个最急迫？为什么？


[Solo/Small 模式：若 sprint 不适用，可跳过，标记 N/A]


---


### BLOCK F — 路线图
Ask:
24. 接下来你大概想实现哪几个大阶段？（“先搭骨架”→“能让用户登录”→“正式发布”）
25. 有没有已经计划了但还没动手的功能？
26. 你心中的“第一版”长什么样？有哪些东西必须有？
27. 有没有预料到某个功能将来会大改，甚至推翻重来？


[Solo/Small 模式：若路线图不明确，可跳过，标记 N/A]


---


### BLOCK G — 陷阱
Ask:
28. 如果有一个新伙伴加入你的项目，他最可能踩的坑是什么？
29. 有没有一个 bug 花了你很长时间才解决？当时什么情况，根源是什么？
30. 有没有哪个号称很好用的工具/库，在你的项目里表现很奇怪？怎么奇怪？
31. 有没有因为环境配置（缺环境变量、端口被占）导致的问题？
32. 在这个项目里，有没有绝对不能做的事？（“绝对不能手动改某个文件”“绝对不能用某个命令”）


---


### BLOCK H — 开发规则与协作协议
Ask:
33. 你有没有偏好的代码风格？（命名习惯、括号风格）没有的话我用通用规范并告诉你。
    [可辅助查询：linter 配置]
34. 有没有一些命令你用过、后来发现很危险、会造成大麻烦、需要我小心的？
    [必须你直接回答 — 只有人知道哪些踩过雷]
35. 增加新工具包时，你有没有特别的流程？必须用某个命令，或需要你审核？
    [可辅助查询：lockfile 策略]
36. 提交或发布前，你需要我帮你确认什么？测试过了没、能不能正常启动？
    [可辅助查询：测试配置]
37. 你平时怎么编辑文件？在线编辑器直接改，还是下载到本地？有没有不能直接编辑的文件（自动生成的）？
38. 我帮你写代码时，最应该坚持做的三件事和最不应该做的三件事？
39. 我们俩的分工：你设定目标、检查结果，我负责实现？还是你也参与修改？
40. 我动手改代码前，需要先向你说明哪些信息？至少应包括什么？
41. 哪些操作我必须得到你的明确同意才能做？（删文件、改数据库结构、加付费服务）
42. 我遇到绕不过去的技术难题，应该怎么跟你沟通？
43. 每次做完任务，你希望我怎么汇报？简单还是详细？
44. 我们之间，解释说明用什么语言？代码和规则用什么语言？


---


### BLOCK I — 安全与认证（仅 Enterprise 模式）
Ask:
45. 用户怎么登录或证明身份？（邮箱+密码、微信扫码、API 密钥）
46. 密钥和密码怎么保管？（.env 文件、专门的密钥管理服务、还是塞代码里？）
47. 系统会处理什么敏感数据？（身份证号、银行卡号、健康信息？）
48. 有没有文件、目录或操作是“千万不能乱动”的？


[非 Enterprise 模式：仅询问 Q48（作为 Block H 的一部分），跳过其余]


After the final block, proceed to PHASE 1.5.


---


## PHASE 1.5 — CONFIRMATION GATE


Output a structured confirmation checklist. Organize by block, checkbox format. Only include blocks actually conducted.


**分层确认策略：**
1. **核心理解**：项目意图和当前状态 — 必须逐条确认。
2. **技术快照**：AI 自动探查的技术细节 — 快速扫一眼，不对的指出即可。
3. **协作规则**：可选择“使用默认规则”跳过。


Format:


```markdown
## 请确认以下核心理解（必须看）
> 这些是我们合作的基础，如果不对会影响后续所有工作。请逐条确认。

### 项目愿景
- [ ] 要解决的问题：[用你的原话]
- [ ] 三大核心操作：[列表]
- [ ] 灵感产品或方向：[如有]

### 项目身份
- [ ] 项目名称：[name]，代号：[alias 或 "无"]
- [ ] 描述：[一句话]
- [ ] 阶段：[stage]
- [ ] 代码位置：[repo/path]

### 当前状态
- [ ] 上次完成：[item]
- [ ] 进行中：[item]
- [ ] 已知问题：[list 或 "无"]
- [ ] 外部阻塞：[list 或 "无"]

### 当前冲刺 / 任务焦点
- [ ] 高优先级事项：[top priority] — 原因：[why]

---

## 技术快照（AI 自动探查，快速扫一眼即可）
> 以下是我从你的项目里自动找出来的信息，一般不需要修改。看不懂的名词没关系。
- [ ] 介质 profile：[WEB-FULL / CLI-LEAN]
- [ ] 语言/运行时：[language/runtime]
- [ ] 核心框架：[list 及通俗用途]
- [ ] 构建/运行命令：[exact commands]
- [ ] 部署目标：[environment]
- [ ] 外部依赖：[list]
- [ ] 数据库：[type]，schema 位置：[location]
- [ ] 日志/监控：[setup]

---

## 协作规则（可以直接跳过，使用默认规则）
> 回复「跳过」我会使用默认的安全协作规则。
- [ ] AI-开发者分工：[mode]
- [ ] 变更前说明要求：[list]
- [ ] 禁止未确认的操作：[list]
- [ ] 语言规则：解释用[language]，代码用 English

### 陷阱与禁忌
- [ ] 常见错误：[list]
- [ ] 绝对禁止：[list]

---

### 标记为 N/A 的内容：
- [items]

### 标记为 TBD 的内容：
- [items]
```


Then say:
> “请纠正任何不准确的地方。可以针对具体条目指出修正，也可以整体回复「确认」或「没问题」。确认后我将生成全部引擎文件。”


**Wait for explicit confirmation before Phase 2.** Accept: “确认”, “没问题”, “可以”, “跳过”, or specific corrections. If corrections provided, update JSON, revise checklist, re‑confirm. If collaboration rules skipped, fill sensible defaults and note “使用默认规则”。


---


## PHASE 2 — FILE GENERATION


After confirmation, say:
> “正在生成全部引擎文件，请稍候。”


**Generation order (ENGINE_MAP first):** ENGINE_MAP.md → ENGINE_DOCTOR.md → ARCHITECTURE.md → CONTEXT.md → SPRINT.md → ROADMAP.md → PITFALLS.md → SYSTEM.md → REPO_GUIDE.md → HANDOFF.md → SOURCEMAP.md → AGENTS.md + CLAUDE.md（锚点引导器）→ `engine/scripts/engine-doctor.sh|ps1`（打包脚本）→ 包级 README 锚点（仅当 ANCHOR LAYER 触发条件满足）。

**CLI-LEAN optimized generation order:** ENGINE_MAP.md → ENGINE_DOCTOR.md → SYSTEM.md → REPO_GUIDE.md → CONTEXT.md → HANDOFF.md → SPRINT.md → PITFALLS.md → ARCHITECTURE.md(irreducible only) → SOURCEMAP.md(pure stub) → AGENTS.md + CLAUDE.md → `engine/scripts/engine-doctor.sh|ps1` → optional `engine/agents/[ENV].md` → package README anchors. This order front-loads the files future agents actually read first and reduces the chance that derivable maps dominate the initial engine.


For each file:
- Announce: `## Generating: [FILENAME]`
- Output full content in a `markdown` code block
- End with: `✓ [FILENAME] complete.`
- Immediately start the next file.


**Profile‑Conditional Generation (强制):**
| Profile | irreducible 文件 | mixed 文件 (ARCHITECTURE) | derivable 文件 (SOURCEMAP) | ENGINE_MAP |
|---------|------------------|---------------------------|----------------------------|------------|
| WEB‑FULL | 完整生成 | 完整生成全部章节 | 完整生成 | 完整生成 |
| CLI‑LEAN | 完整生成，但遵守文件预算与归档策略 | 只生成 irreducible 章节（§0/§1/§6/§7/§11 等决策、不变量、产品身份），其余章节替换为 pure stub：`> [derivable — CLI‑LEAN 下按需现生，见 ENGINE_MAP §0]` | 生成 pure stub：只保留章节标题 + 现生 recipes，正文不得包含当前文件清单/目录树/版本号/模块数量 | 完整生成，但 §4 只放短状态和指针，不放长会话摘要 |


锚点层文件（AGENTS.md / CLAUDE.md / 包级 README）在两种 profile 下都完整生成 —— 它们本身极薄、只含指针与局部摘要，不受 derivable 规则约束。WEB‑FULL 下也生成，供日后切换 CLI agent 时直接可用。

**Initial File Budgets (CLI-LEAN hard caps):**
| File | Target | Hard cap | Overflow rule |
|------|--------|----------|---------------|
| ENGINE_MAP.md | ≤180 lines | 240 lines | Move narrative to CONTEXT/HANDOFF; keep MAP as metadata only |
| ENGINE_DOCTOR.md | ≤220 lines | 320 lines | Keep check contract here; move long evidence to `engine/evidence/` or specs |
| SYSTEM.md | ≤260 lines | 340 lines | Move repo-specific bulk rules to REPO_GUIDE.md or `engine/agents/[ENV].md` |
| REPO_GUIDE.md | ≤260 lines | 380 lines | Keep concrete commands/rules here; archive obsolete platform playbooks |
| CONTEXT.md | ≤180 lines | 260 lines | Keep status panel + current assumptions; archive older session prose |
| HANDOFF.md | ≤120 lines | 180 lines | Keep immediate restore point + last session only; archive history |
| SPRINT.md | ≤220 lines | 320 lines | Keep active/pending tasks; archive completed task details |
| PITFALLS.md | ≤300 lines active | 500 lines active | Keep index + active/resolved-recent; archive old resolved bodies |
| ARCHITECTURE.md | ≤220 lines | 320 lines | In CLI-LEAN, no derivable body |
| SOURCEMAP.md | ≤80 lines | 120 lines | Pure recipes only; no live map body |
| AGENTS.md / CLAUDE.md | ≤30 lines | 45 lines | Move environment-specific details to `engine/agents/[ENV].md` |

If INIT would exceed a hard cap, generate an archive file immediately (`engine/archive/<name>-init-archive.md`) and leave a pointer. Never solve file growth by deleting irreducible knowledge silently.

**Machine-check hook (v5.5):** During INIT, generate `ENGINE_DOCTOR.md` as a first-class authority file, register it in ENGINE_MAP §1, and write bundled implementations to `engine/scripts/engine-doctor.sh` and `engine/scripts/engine-doctor.ps1`. Also keep a short `Engine Doctor Contract` pointer section in SYSTEM.md. Doctor MUST validate registry existence, class/stub purity, complete registration routing, lifecycle transaction closure, anchor budgets, plan twin existence, status vocabulary, dangling refs, stale headers, and read-gate coverage/evidence for edited paths.


无论 profile，ENGINE_MAP §1 注册表 MUST 如实反映本次生成的每个文件及其 class；锚点文件登记于 §1.2。


**N/A / TBD / PARTIAL Handling:**
- **N/A**: Omit the section gracefully. No empty headers. If omission breaks flow, add: “> 本节不适用于当前项目类型。”
- **TBD**: Keep header. Write: “> TBD — 待项目演进后补充。如需决定，AI 可提供推荐方案。” + 一句引导。
- **PARTIAL**: Keep confirmed info. Append [未验证] to unconfirmed claims.


**Token Management:** If output approaches limits during Batch 1 (ENGINE_MAP + files 1‑4), pause and say:
> “第一批完成。说「继续」生成剩余文件。”
Wait for “继续” before Batch 2.


After all files, run the completeness check:
```markdown
## 完整性检查
- [ ] ENGINE_MAP + 所有 [N] 个权威文件已生成，无截断
- [ ] 无句子中断
- [ ] ENGINE_MAP §1 注册表与实际生成的文件一致
- [ ] ENGINE_DOCTOR.md 已生成并登记 ENGINE_MAP §1；`engine/scripts/engine-doctor.sh` 与 `.ps1` 已随仓库写入但未误登记为权威文件
- [ ] ENGINE_MAP §1 中登记的 REPO_GUIDE.md / environment adapter 等非核心但权威的文件均已实际生成
- [ ] 所有 authority engine files / anchors / plans / generated-cache / archive 均按完整注册路由归位；不存在“文件已创建但未注册/不该注册却注册”的情况
- [ ] 生命周期事务已闭合：没有 rename/move/split/archive/delete 后残留的旧路径、孤儿引用或未解释外部文件
- [ ] profile 行为已正确应用（CLI‑LEAN 的 derivable pure stub 已就位，且无 live file inventory）
- [ ] CLI-LEAN 文件预算已检查；超限内容已归档并留下指针
- [ ] ENGINE_MAP §4 只含短状态/指针，不含长会话叙述
- [ ] 锚点层已生成并登记 §1.2（引导器 ≤30 行且只含指针；环境细则已外置到 `engine/agents/[ENV].md`；包锚点按触发条件生成或正确跳过；既有规则已吸收）
- [ ] Engine Doctor Contract 已写入 ENGINE_DOCTOR.md，并由 SYSTEM.md 指向；Doctor 脚本已可运行或已记录缺口
- [ ] Read-gate 规则已写入 ENGINE_MAP §0、SYSTEM 会话流程 / ENGINE_DOCTOR Contract、AGENTS.md bootloader 指针
- [ ] Plan status vocabulary 已写入 ENGINE_MAP；所有初始状态值合法
- [ ] spec twin 若存在，至少包含 AC 表、验证方式、状态、最后验证日期/待验证原因
- [ ] 所有 N/A 章节已正确省略
- [ ] 所有 TBD 章节已正确标记
- [ ] 无 [PLACEHOLDER] 残留值
```
If any check fails, regenerate the affected file(s).


---


### FILE 0 — ENGINE_MAP.md （索引层，最先生成）


