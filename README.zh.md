<div align="center">

**你的 AI 在你关掉标签页的瞬间忘掉了一切。**  
**Engine System 不让这件事发生。**

[English](./README.md) · [中文](./README.zh.md)

</div>

---

## 顺带一提

由于项目根植于无限降低开发门槛，因此考虑到部分用户尚且不明白应该如何下载安装**claude code**，这个可以稍后补习，如果想见识本项目的效用，可以在**web端**的任意AI平台直接以**`ENGINE_FILE_SYSTEM_v5.md`**作为prompt使用；项目根目录刻意只保留这一个稳定 web 初始机入口，旧版本统一放在 `archive/engine-file-system/` 里作为参考，不再作为活跃入口。然后在你的项目根文件夹下面添加**engine**文件夹，以放置AI生成的所有engine文件，之后每次需要在web端开发的时候，只需要把所有engine文件一股脑扔给web端的AI，然后每次项目结束后主动**让AI总结并更新engine文件**即可。————这也是这份engine文件的最初的使用方法，也是最不具门槛的使用方法。您只需要下载项目根目录里的**`ENGINE_FILE_SYSTEM_v5.md`**即可

## 作为一个非专业开发者的vibe coding，严格来说只能算作架构师而不是开发者

为了尽可能拉近非科班计算机开发者，那些具有想象力但无从下手，只能借助AI不断地反复验证做重复的事情的低效vb者，最后对vb大加失望而退出coding圈，都可以运用**管理prompt**————在本项目中被定义为一系列**engine文件**来做到同AI编程师的高效沟通。这个项目就是致力于继续降低人们的编程门槛，让完全不懂任何编程知识的人都可以感受到编程的独属于计算机的创造者的魅力。
如果你从一开始就关注vb并且实践过早期的vb流程，那么你一定在以往的开发过程中有过这种感觉。打开一个新的 Claude Code 会话，然后花十五分钟做这件事：

> _"我的项目是 Next.js，后端用 Postgres——等等，不要用 Prisma，我上个月换成 Drizzle 了。Auth 在 `src/features/auth/` 里面，不是 `src/lib/`。还有不管怎样不要直接动迁移文件，我吃过亏……"_

两小时后，在新标签页里，你又解释了一遍。（当然能够解释清楚并且记住的情况适用于那些已经具备基础知识并且或许也有过项目经验的初级开发者，大多数转码并且不具备成熟的开发能力以及扎实的基础知识的人，可能在进行这一步之前还需要在工作流里再一次询问AI自己的项目架构）

**AI 不是问题所在。缺失的记忆层才是。**

每次会话，你都在付同一笔"重新入职税"。整个项目的全貌只在你脑子里——那些架构决策、那些地雷、那个做了一半的重构、那个看起来很好用但在生产环境炸掉的库。这些知识住在你的头里，不在你的项目里。每次重新开始，它都在悄悄流失。现在的claude code已经足够强大，完善了记忆层的开发，让claude code具备一定的项目记忆，但还不够好，假如不具备记忆：

最终的结果：

- AI 信心十足地重构了你三周前已经试过并放弃的方案
- AI 用了你明令禁止的库，因为你这次忘记说了
- AI 动了不该动的地方，因为它不知道那里有雷
- 你每次会话有 20% 的时间在重新讲背景，而不是在建东西
- 项目越大，反而越难推进——这不对

---

## Engine System 做的事

Engine System 给你的项目加一个结构化记忆层：一组放在 `engine/` 目录里的 **markdown 文件**，在任何 AI 动你代码之前，让它先知道它需要知道的一切。其中有一个 `ENGINE_MAP.md` 是总目录——AI 每次会话最先读它，再据此决定该加载哪些文件。

第一次，在 Claude Code 里运行 `/engine-init`。Claude 会用大约十分钟采访你，然后把文件直接写进你的项目。之后每次会话，文件自动加载。不用重新介绍，不用反复解释，不会上下文漂移。

```
没有 Engine System                  有了 Engine System
──────────────────────              ─────────────────────────────
打开 Claude Code                    打开 Claude Code
↓                                   ↓
重新介绍项目背景，15 分钟            Claude 读取引擎文件，5 秒
↓                                   ↓
开始写代码                          开始写代码
↓                                   ↓
AI 动了不该动的东西                  AI 早就知道那里不能碰
你忘记这次说了                       ↓
↓                                   交付
撤销，重新解释，再来一次
↓
最终交付
```

---

## 引擎文件

这些文件都住在 `engine/` 目录里。第一个是索引——AI 在干别的之前，先读它。

| 文件              | 里面装着什么                                                   |
| ----------------- | -------------------------------------------------------------- |
| `ENGINE_MAP.md`   | 总目录/索引。每次会话最先读它——它告诉 AI 接下来该加载哪些文件 |
| `CONTEXT.md`      | 现在什么坏了，在做什么，卡在哪                                 |
| `SYSTEM.md`       | 你的协作规则——AI 必须做什么、不能做什么                        |
| `PITFALLS.md`     | 地雷登记册。踩过的坑、已知的危险操作、永远不做的事             |
| `ARCHITECTURE.md` | 技术栈、目录结构、数据模型、关键决策及其理由                   |
| `SPRINT.md`       | 用人话写的当前任务和优先级                                     |
| `ROADMAP.md`      | 里程碑、计划功能、预料中将来要大改的东西                       |
| `HANDOFF.md`      | 会话历史——哪怕隔了两周，也能精准接回上次的断点（v6.6+ 限 8 条）|
| `SOURCEMAP.md`    | 代码 GPS：哪个文件管哪个功能，加新东西去哪里改                 |
| `REPO_GUIDE.md`   | 可选：当 SYSTEM 太大时承载仓库命令、流程与维护规则             |
| `ENGINE_DOCTOR.md`| 引擎健康检查与未来扩展的维护契约                               |
| `engine/tasks/`         | 任务卡（`T-NNN.md`）：一项可独立验收的目标一卡——GOAL / WRITE-SET / FORBIDDEN / AC+verify |
| `engine/decisions/`     | 决策台账（`D-NNN.md`）：非显然选择，带 status / scope / expiry。受保护路径在提交时必须引用一个 approved 决策 |
| `engine/changes/`       | 改动胶囊：把 diff 翻译成目标、影响、风险、验证和回滚             |
| `engine/workstreams/`   | 并行 worker 分片：每个 agent 只写自己的 `/<task>/<agent>/`，协调者在 merge point 一次合并 |
| `engine/evidence/`      | 逐 AC 的验收证据：PASS/FAIL + sha256 指纹                       |
| `engine/domains/`       | 联邦路由表（`federation.json`）+ 每域 CONTEXT/PITFALLS，分形记忆 |
| `engine/plans/`         | 你聊出来的设计文档，每份都配一张验收清单                       |
| `engine/handoff-archive-*.md` | HANDOFF 历史归档（v6.6+，search-only，不进 SessionStart 注入、不进 ENGINE_MAP §1）|
| `engine/migrations/`    | 版本化迁移脚本（`v6.0.sh`/`.ps1` …），`engine migrate` 按版本顺序应用 |
| `engine/prompts/behaviors/` | agent-neutral 行为 prompt：scout、task-run、handoff、decision-draft、verify-writeback |
| `engine/agents/`        | 可选：Codex、Claude Code、IDE agent、CI bot 的环境适配细则      |
| `engine/scripts/`       | 随仓库打包的维护脚本：Doctor、hooks、契约迁移器、verify、跨 agent 同步 |
| `.claude/skills/`       | Claude Code 技能（与 `engine/prompts/behaviors/` 同源镜像）     |

纯 markdown 文件。提交进 git，用 diff 追踪变化，自己也能读。  
顺带一提，这也许是你这辈子无意间写出的最好的项目文档。

**还有一层——锚点。** 像 `CLAUDE.md`、`AGENTS.md` 这样的文件不住在 `engine/` 里，而是放在各种 AI 工具一开机就会去看的位置。把它们想成一张「开机引导卡」：AI 工具一打开你的项目，先读这张卡，卡再把它指向 `ENGINE_MAP.md`。在更大的项目里，每个主要文件夹还可以放一个小小的 `README.md` 当「路标」。这些你都不用手写——Engine System 帮你保持同步。

---

## 它会根据你在哪儿干活自动适配

Engine System 会留意你是在用**网页版 AI**（ChatGPT、网页里的 Claude），还是在用 **Claude Code**，并相应调整它存什么：

- **网页版 AI 看不到你的代码**，所以引擎文件就成了代码的完整替身——连目录结构、技术栈都会完整写出来。
- **Claude Code 能直接读你的代码**，所以它只存那些**没法从代码里重建**的东西：你的决策、你踩的坑、你定的规则。像目录结构这类信息就不重复存了——AI 需要时直接现读，这样它永远不会过期。

这些你都不用配置。运行 `/engine-init` 时一次性选好，剩下的它替你处理。

---

## v6 新机制——引擎背后的引擎

Engine System v6 把最初的记忆层升级成了数据驱动运行时。文件仍是纯 markdown，你能读、能 diff——但底层由机器执行契约，不再依赖 prompt 纪律。

### v6 核心机制

| 机制 | 它做什么 |
|------|----------|
| **三层门禁（S0）** | UserPromptSubmit 短重锚 + PreToolUse 写前检查 + session 归属的 Stop + pre-commit 复核。陈旧上下文再也无法漂移成错误写入。 |
| **任务卡（S1）** | 一项可独立验收的目标一张卡（`engine/tasks/T-NNN.md`）。每条项目路径——包括 `engine/*`——必须落在 WRITE-SET 内、FORBIDDEN 外。 |
| **决策台账（S1）** | 非显然选择变成可引用工件（`engine/decisions/D-NNN.md`），带 status / scope / expiry。受保护路径提交时必须引用一个 approved 决策。 |
| **分形记忆（S2）** | 联邦表（`engine/domains/federation.json`）按 path-glob 路由到域；每个域有自己的 CONTEXT + PITFALLS。L2 装配不超过 400 行会话预算。 |
| **契约编译（S3）** | `contract/src/*.md` 是唯一正本；`contract/compile.sh` 编译到 dist；减法预算强制"新规则必须净零增长"，契约不会膨胀。 |
| **驾驶舱验收（S4）** | `engine verify T-NNN` 跑行为验收——AC verify 命令产出 PASS/FAIL + sha256 指纹到 `engine/evidence/`。任务卡只有在 verify 全绿或架构师批准豁免时才能标 `done`。 |

### v6.5——长会话硬边界与并行记忆分片

两类可复现问题——长上下文模型遗忘任务范围、并行 agent 抢写 `CONTEXT.md` 互相覆盖——现在由机器解决：

- **全路径任务范围**：WRITE-SET / FORBIDDEN 覆盖代码、文档**和**引擎文件。在 contract-version 6.5+ 项目里，普通写入必须有 active/closing 任务卡；只有任务/决策卡 bootstrap 允许无卡。只读调查免卡。
- **逐 AC 证据门禁**：staging `done` 必须每个 AC 都有 PASS evidence，或架构师批准的豁免。Doctor 把成功历史聚合成一行，只逐项输出失败项。
- **Workstream 分片**：worker 运行 `engine workstream T-NNN <agent-id>`，只写 `engine/workstreams/<task>/<agent>/`。协调者在 merge point 重读所有分片，一次性更新共享记忆。
- **低 token 重锚**：UserPromptSubmit 注入 4 行任务指针（ID、GOAL、卡路径、并行归属），不重复 L0 或完整 WRITE-SET。SessionStart 装配完整上下文；Stop / pre-commit 做收尾门禁。
- **session_id + agent_id 归属**：Claude PreToolUse 拦截已识别的子 agent 直接写共享引擎文件；Stop 用 session/agent 路径账本，避免兄弟 agent 的改动"代打卡"。其他宿主回退到 workstream 分片 + pre-commit。

### v6.6——HANDOFF 历史归档

`HANDOFF.md` 的会话历史表上限 8 条。超出时把最旧的整行迁移到 `engine/handoff-archive-YYYY-MM.md`（search-only——不进 SessionStart 注入、不进 ENGINE_MAP §1 注册、Doctor 不校验预算）。Doctor 在历史表 > 8 条时输出 WARN（不硬失败），提示 agent 在下次写 HANDOFF 时触发首次归档。同一条规则会删除 CONTEXT.md「待验证」段中已 `~~划线~~` 的条目。

### 行为技能

五个 Claude Code 技能把契约行为封装好：`engine-scout`、`engine-task-run`、`engine-handoff`、`engine-decision-draft`、`engine-verify-writeback`。同样的 prompt 也以 agent-neutral 形式发布在 `engine/prompts/behaviors/`，让非 Claude agent（Codex、Copilot、Cursor、Gemini、Aider、网页 chat）也能用。

---

## 想做个大功能？跟它聊一聊就行

当你想做点大东西，你不需要写什么规格文档。就像平时那样，跟 AI 把设计思路聊一遍就好。Engine System 帮你把方案归档——存进 `engine/plans/`，还配上一份大白话的验收清单：「怎么算真的做完了」。格式你一点都不用碰。方案和它的验收清单是绑在一起走的，所以将来任何一次会话都同时知道你当初想做什么、以及做到什么程度才算完成。

---

## 实际数字

|                              | 没有 Engine System  | 有 Engine System |
| ---------------------------- | ------------------- | ---------------- |
| 会话启动（重新介绍）         | 10–20 分钟          | 约 30 秒         |
| "撤销，我说了不要这样"的次数 | 每次会话好几次      | 接近零           |
| 隔一周回来继续开发           | 30 分钟以上重新定位 | 不到 5 分钟      |
| 接入第二个 AI 智能体         | 从零开始讲          | 即时             |
| 停下来时项目知识的去向       | 消失在你脑子里      | 保存在项目里     |

---

## 安装

**macOS / Linux**

```bash
bash <(curl -sSL https://raw.githubusercontent.com/elysiayunchen/engine_system/main/install.sh)
```

**Windows（PowerShell）**

```powershell
Invoke-WebRequest https://raw.githubusercontent.com/elysiayunchen/engine_system/main/install.ps1 -OutFile install.ps1
powershell -NoProfile -File .\install.ps1
```

Windows 安装器刻意采用“先下载、可检查、再运行”的方式。不要使用管道直接执行远程内容的安装片段，
安全软件经常会把这种模式识别为木马行为。

**通过 degit**（不带 git 历史）

```bash
npx degit elysiayunchen/engine_system/plugin
```

往你的项目根目录加这些文件——**原有代码一行不动：**

```
你的项目/
├── engine/                 ← 引擎文件住在这里
│                             （/engine-init 之后会有 ENGINE_MAP.md 等文件，以及 plans/）
├── .claude/
│   └── commands/           ← 自动变成 Claude Code 的斜杠命令
│       ├── engine-init.md       →  /engine-init
│       ├── engine-update.md     →  /engine-update
│       ├── engine-status.md     →  /engine-status
│       ├── add-pitfall.md       →  /add-pitfall
│       ├── engine-ingest.md     →  /engine-ingest
│       ├── engine-extend.md     →  /engine-extend
│       ├── engine-doctor.md     →  /engine-doctor
│       ├── engine-sync.md       →  /engine-sync
│       └── engine-reconcile.md  →  /engine-reconcile
│   └── scripts/
│       ├── engine-doctor.sh
│       └── engine-doctor.ps1
├── AGENTS.md               ← 给 AI 工具的开机引导卡（把它指向 ENGINE_MAP.md）
└── CLAUDE.md               ← 每次 Claude Code 启动自动加载
```

没有 npm 包，没有运行时依赖，没有配置文件。就是文件。

---

## 第一次使用

```
/engine-init
```

Claude 会采访你：项目愿景、技术栈、当前状态、已知的坑、你希望怎么合作。大概十分钟。引擎文件——`ENGINE_MAP.md` 和其余几份——直接写进 `engine/`。打开编辑器，文件就在那里。

**没有 Claude Code？** 把 `.claude/commands/engine-init.md` 的内容复制到任意 Claude 会话（网页版、API 均可），把生成结果手动存进 `engine/`。其他一切功能完全一样。

大多数 agent 工具会先读 `AGENTS.md` 或 `CLAUDE.md`；它们会把不同工具都导向同一套 `ENGINE_MAP.md`
和命令入口，所以不必把整套规则复制到每个工具里。

---

## 之后每次会话

**开始：** Claude Code 自动读取 `CLAUDE.md`。在 v5.6+，SessionStart hook 还会把最新的
`CONTEXT.md` + `HANDOFF.md` 快照注入新会话。在 v6+，联邦表按路径路由到域，只装配相关 L2
记忆（≤400 行）。在 v6.5+，每次 UserPromptSubmit 都会重注入 4 行任务指针，长会话不再漂移。

**没装 Claude Code？** 在任意终端运行 `engine context`，它会打印同样的会话上下文包，供任意 AI agent 阅读。

**会话结束：**

```
/engine-update
```

三个问题，状态同步，交接笔记写好，三十秒结束。在 Claude Code 里，如果代码变了但
`CONTEXT.md` / `HANDOFF.md` 没回写，Stop hook 会拦一次；SessionEnd 体检 hook 会把
Doctor warning 缓存给下次启动。其他 agent 仍有 git pre-commit 兜底。

从 v5.7 开始，有意义的改动还会生成 `engine/changes/CHANGE-*.md` 改动胶囊：
目标、实际变化、影响范围、风险、验证结果、回滚方式和责任边界。你不用看代码 diff，
只看这份胶囊就能判断“这次改动是否能接受”。

**踩到奇怪的东西：**

```
/add-pitfall
```

马上记录，在你关掉窗口之前。它永久存进 `PITFALLS.md`——之后所有 AI 会话都会知道这件事。

**快速查看：**

```
/engine-status
```

当前状态、活跃任务、未解决的坑、最近改动胶囊和 Project Self-View，一张快照。
它会明确告诉你：现在能判断什么、还缺什么证据、架构师需要看哪份胶囊或验收项。

**刚设计完一个新功能：**

```
/engine-ingest
```

把你跟 AI 聊出来的一份设计/方案交给它，它会归档进 `engine/plans/`，并附上一份验收清单。没有格式要学。

**需要新增一种引擎文件类型：**

```
/engine-extend
```

它会按 5.5 的完整注册事务创建/登记新的权威引擎文件：class、注册表、引用、预算、验证一起收口。
普通功能方案仍然走 `/engine-ingest`。

**检查引擎健康：**

```
/engine-doctor
```

运行随仓库打包的 Doctor 脚本。Doctor 读取 `ENGINE_MAP.md`，所以将来扩展新的引擎文件时，
它会通过注册表发现新文件，而不是被写死的旧脚本遗忘。
v5.7 起，Doctor 还会检查最近改动是否有可读胶囊、胶囊是否包含风险/验证/回滚，
以及标记为 done 的计划是否真的有验收证据。
v6.3.1 起，Doctor 加字节上限 + 单行宽度检查，膨胀的 CONTEXT/ENGINE_MAP/HANDOFF（例如表格单元格填充攻击）逃不过行数上限的盲点。
v6.5+ 起，Doctor 把成功任务历史聚合成一行，只逐项输出失败 AC。
v6.6 起，Doctor 在 `HANDOFF.md` 历史表超过 8 条时输出 WARN。

**任务标 done 前先验收（v6+）：**

```
engine verify T-NNN
```

跑 `engine/tasks/T-NNN.md` 里的 AC verify 命令，把 PASS/FAIL + sha256 指纹写到 `engine/evidence/T-NNN/`。任务卡只有每个 AC 全绿或架构师批准豁免时才能标 `done`。

**并行 worker（v6.5+）：**

```
engine workstream T-NNN <agent-id>
```

在 `engine/workstreams/<task>/<agent>/` 创建隔离的 worker 分片。worker 只写自己的 `CONTEXT.md` + `HANDOFF.md`；协调者在 merge point 重读所有分片，一次更新共享记忆。多个 agent 共享工作区时用它——彻底消除 CONTEXT/HANDOFF 写冲突。

**更新 Engine System 工具并迁移本地引擎文件：**

```
/engine-sync
```

拉取/安装新版 Engine System 后运行它。它会更新命令和脚本，确保 Doctor 契约已注册，
同步 Copilot、Cursor、Gemini、Cline/Roo、Aider 等工具的薄引导文件，运行 Doctor，
然后通过对账流程迁移本项目已有的引擎文件，不会粗暴覆盖你的项目记忆。

**怀疑文档跟真实代码对不上了：**

```
/engine-reconcile
```

对账一遍。它会检查引擎文件跟你代码库里实际的东西是否还一致，并修掉漂移。大改一轮之后跑一下。

---

## 命令清单

### 斜杠命令（Claude Code）

| 命令                 | 它做的事                                                |
| -------------------- | ------------------------------------------------------- |
| `/engine-init`       | 首次初始化。采访你，然后把引擎文件写出来                |
| `/engine-update`     | 会话结束。同步当前状态，写好交接笔记和改动胶囊           |
| `/engine-status`     | 打印一张自视图：状态、任务、坑、最近改动、缺失证据       |
| `/add-pitfall`       | 立刻记下一个坑，趁你还没忘                              |
| `/engine-ingest`     | 把一份新设计/方案归档进 `engine/plans/`，并配验收清单   |
| `/engine-extend`     | 新增并完整注册一种权威引擎文件类型                      |
| `/engine-doctor`     | 检查注册表、锚点、plan、预算、生命周期闭环与自审证据     |
| `/engine-sync`       | 更新 Engine System 工具，并迁移/对账本地引擎文件        |
| `/engine-reconcile`  | 对账文档与真实代码，修掉任何漂移                        |

### 终端 CLI（任意 AI agent，v6+）

`engine` CLI 是装在 `engine/bin/engine` 的薄壳（安装后还会装一份用户级 `engine` 命令到 PATH）。不在 Claude Code 里时（Codex、Copilot CLI、Cursor、Gemini CLI、Aider 或纯终端）用它。

| 命令                                     | 它做的事                                                                                       |
| ---------------------------------------- | ---------------------------------------------------------------------------------------------- |
| `engine init`                            | 展示如何把 `engine/prompts/init.md` 喂给任意 AI agent。`--print` 直接吐出原始 prompt            |
| `engine context`                         | 打印完整会话上下文包（Claude Code SessionStart 注入的 agent-neutral 等价物）                    |
| `engine workstream T-NNN <agent-id>`     | 为并行 agent 创建隔离 worker 记忆分片（v6.5+）                                                  |
| `engine verify T-NNN`                     | 跑行为验收，把 PASS/FAIL + sha256 证据写到 `engine/evidence/`（v6+）                            |
| `engine check-update`                    | 对比本地 `engine/VERSION` 和远端。Exit 0 最新 / 7 有更新 / 8 网络错误                            |
| `engine update`                          | 一站式：拉 installer → 更新工具 → 跑 migrator → 跑 Doctor                                        |
| `engine update --check-only`             | 只预览，不改任何东西                                                                            |
| `engine update --no-migrate`             | 更新工具但跳过迁移/Doctor                                                                       |
| `engine migrate`                         | 按 `engine/migrations/` 下的版本化迁移步按序应用，再跑幂等契约迁移器                            |
| `engine doctor`                          | 跑引擎健康检查                                                                                 |
| `engine help`                            | 显示用法                                                                                       |

CLI 不会自动改你的项目记忆——`engine migrate` 只应用托管契约区块和结构性迁移；项目专属的 `SYSTEM.md`、`PITFALLS.md`、`CONTEXT.md`、`HANDOFF.md`、plans、decisions 都保留。

---

## 更新插件本身

```bash
bash <(curl -sSL .../install.sh) --update
```

把命令和脚本工具更新到最新版本。你的项目专属 `engine/*.md` 记忆不会被粗暴覆盖。更新插件文件后，
运行 `/engine-sync`，让最新维护契约、Doctor 注册和引擎文件迁移通过 read-gate + reconcile 流程落地。

### 已经执行过旧引擎文件的项目怎么升级

不要为了升级而重跑 `/engine-init`。先更新随项目打包的工具层，再让 `/engine-sync` 迁移已有记忆层：

```bash
engine update
```

如果终端命令还没有进入 PATH，就直接用安装器：

```bash
bash install.sh --update
```

```powershell
powershell -NoProfile -File .\install.ps1 -Update
```

然后运行：

```text
/engine-sync
```

这会保留项目自己的 `SYSTEM.md`、`PITFALLS.md`、`CONTEXT.md`、`HANDOFF.md`、plans 和决策，
同时补上最新 Doctor 契约、hooks、命令文件与跨 agent 引导文件。更重要的是，`/engine-sync`
会先运行 `engine/scripts/engine-migrate-contract.*`，把新机制作为可重复运行的托管迁移区块
写进已有引擎文件，而不是只更新脚本。这个托管契约可以承载当前和未来的 Engine System
规则：自维护循环、change capsule、Project Self-View、done 计划验收证据、Doctor 自审门禁、
多 lane 并行工作流等都会按 additive 方式补入，同时保留项目原有记忆。

安装器也会把 CLI shim 放到 `engine/bin/`，并尝试安装用户级 `engine` 命令
（macOS/Linux 是 `~/.local/bin/engine`，Windows 是 `%USERPROFILE%\.engine\bin\engine.cmd`）。
只要这个目录进了 PATH，以后远端更新就是：

```text
engine update
```

---

## 设计理念

Engine System 不跟上下文窗口死磕——它绕过这个问题。

核心洞察很简单：**不需要 AI 记住，需要项目记住。** 引擎文件是项目的记忆，不是 AI 的记忆。关掉标签页、切换模型、休息一周、换一个 AI 智能体——记忆不会丢。

这些文件被设计成冷启动可读：信息密度高，废话极少，结构清晰，让 AI 能在几秒内完成定位。但它们对人类同样可读。如果你有过隔了两个月回到项目完全找不到北的体验，你会认出这些文件在做什么。

---

## 开源协议

MIT
