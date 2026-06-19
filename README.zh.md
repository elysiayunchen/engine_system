<div align="center">

**你的 AI 在你关掉标签页的瞬间忘掉了一切。**  
**Engine System 不让这件事发生。**

[English](./README.md) · [中文](./README.zh.md)

</div>

---

## 顺带一提

由于项目根植于无限降低开发门槛，因此考虑到部分用户尚且不明白应该如何下载安装**claude code**，这个可以稍后补习，如果想见识本项目的效用，可以在**web端**的任意AI平台直接以**`ENGINE_FILE_SYSTEM_v5.md`**作为prompt使用；这个稳定文件名当前装的是最新版 v5.5。然后在你的项目根文件夹下面添加**engine**文件夹，以放置AI生成的所有engine文件，之后每次需要在web端开发的时候，只需要把所有engine文件一股脑扔给web端的AI，然后每次项目结束后主动**让AI总结并更新engine文件**即可。————这也是这份engine文件的最初的使用方法，也是最不具门槛的使用方法。您只需要下载项目根目录里的**`ENGINE_FILE_SYSTEM_v5.md`**即可

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
| `HANDOFF.md`      | 会话历史——哪怕隔了两周，也能精准接回上次的断点                 |
| `SOURCEMAP.md`    | 代码 GPS：哪个文件管哪个功能，加新东西去哪里改                 |
| `REPO_GUIDE.md`   | 可选：当 SYSTEM 太大时承载仓库命令、流程与维护规则             |
| `ENGINE_DOCTOR.md`| 引擎健康检查与未来扩展的维护契约                               |
| `engine/agents/`  | 可选：Codex、Claude Code、IDE agent、CI bot 的环境适配细则      |
| `engine/scripts/` | 随仓库打包的维护脚本，包括 registry-driven Engine Doctor        |

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
irm https://raw.githubusercontent.com/elysiayunchen/engine_system/main/install.ps1 | iex
```

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

---

## 之后每次会话

**开始：** Claude Code 自动读取 `CLAUDE.md`，上下文加载完毕，什么都不用做。

**会话结束：**

```
/engine-update
```

三个问题，状态同步，交接笔记写好，三十秒结束。

**踩到奇怪的东西：**

```
/add-pitfall
```

马上记录，在你关掉窗口之前。它永久存进 `PITFALLS.md`——之后所有 AI 会话都会知道这件事。

**快速查看：**

```
/engine-status
```

当前状态、活跃任务、未解决的坑，一张快照。

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

**更新 Engine System 工具并迁移本地引擎文件：**

```
/engine-sync
```

拉取/安装新版 Engine System 后运行它。它会更新命令和脚本，确保 Doctor 契约已注册，
运行 Doctor，然后通过对账流程迁移本项目已有的引擎文件，不会粗暴覆盖你的项目记忆。

**怀疑文档跟真实代码对不上了：**

```
/engine-reconcile
```

对账一遍。它会检查引擎文件跟你代码库里实际的东西是否还一致，并修掉漂移。大改一轮之后跑一下。

---

## 九个命令

| 命令                 | 它做的事                                                |
| -------------------- | ------------------------------------------------------- |
| `/engine-init`       | 首次初始化。采访你，然后把引擎文件写出来                |
| `/engine-update`     | 会话结束。同步当前状态，写好交接笔记                    |
| `/engine-status`     | 打印一张快照：当前状态、活跃任务、未解决的坑            |
| `/add-pitfall`       | 立刻记下一个坑，趁你还没忘                              |
| `/engine-ingest`     | 把一份新设计/方案归档进 `engine/plans/`，并配验收清单   |
| `/engine-extend`     | 新增并完整注册一种权威引擎文件类型                      |
| `/engine-doctor`     | 检查注册表、锚点、plan、预算与生命周期闭环              |
| `/engine-sync`       | 更新 Engine System 工具，并迁移/对账本地引擎文件        |
| `/engine-reconcile`  | 对账文档与真实代码，修掉任何漂移                        |

---

## 更新插件本身

```bash
bash <(curl -sSL .../install.sh) --update
```

把命令和脚本工具更新到最新版本。你的项目专属 `engine/*.md` 记忆不会被粗暴覆盖。更新插件文件后，
运行 `/engine-sync`，让最新维护契约、Doctor 注册和引擎文件迁移通过 read-gate + reconcile 流程落地。

---

## 设计理念

Engine System 不跟上下文窗口死磕——它绕过这个问题。

核心洞察很简单：**不需要 AI 记住，需要项目记住。** 引擎文件是项目的记忆，不是 AI 的记忆。关掉标签页、切换模型、休息一周、换一个 AI 智能体——记忆不会丢。

这些文件被设计成冷启动可读：信息密度高，废话极少，结构清晰，让 AI 能在几秒内完成定位。但它们对人类同样可读。如果你有过隔了两个月回到项目完全找不到北的体验，你会认出这些文件在做什么。

---

## 开源协议

MIT
