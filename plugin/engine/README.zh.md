# engine/ — 你项目的记忆层

这个文件夹是 [Engine System](https://github.com/elysiayunchen/engine_system) 创建的持久
记忆层。这里的文件,在任何 AI 动你代码之前,先把你项目的一切告诉它。

> [English](./README.md) · **中文**

## 这里有什么

刚装好时这个文件夹几乎是空的——只有这份说明。在 Claude Code 里运行 `/engine-init`(或把
`.claude/commands/engine-init.md` 粘进网页版 AI),引擎文件就会写到这里:

| 文件              | 里面装着什么                                       |
| ----------------- | -------------------------------------------------- |
| `ENGINE_MAP.md`   | 索引/总目录。每次会话最先读——它指引 AI 接下来读什么 |
| `CONTEXT.md`      | 现在什么坏了,在做什么,卡在哪                       |
| `SYSTEM.md`       | 你的协作规则——AI 必须做什么、不能做什么            |
| `PITFALLS.md`     | 地雷登记册。每个坑、每个雷、每条「永远别这么做」    |
| `ARCHITECTURE.md` | 技术栈、目录结构、数据模型、关键决策                |
| `SPRINT.md`       | 用人话写的当前任务和优先级                          |
| `ROADMAP.md`      | 里程碑、计划功能、将来要大改的东西                  |
| `HANDOFF.md`      | 会话历史——隔了两周也能精准接回断点                 |
| `SOURCEMAP.md`    | 代码 GPS:哪个文件管哪个功能                         |
| `REPO_GUIDE.md`   | 可选：仓库命令、流程与维护规则                      |
| `ENGINE_DOCTOR.md`| 引擎健康检查的维护契约                              |
| `engine/agents/`  | 可选：不同 AI 工具/环境的适配规则                   |
| `scripts/`        | 随仓库打包的 Doctor 脚本                            |
| `plans/`          | 你聊出来的设计文档,每份都配一张验收清单             |

具体出现哪些文件,取决于初始化时选的 **profile**:WEB-FULL 会把所有内容完整写出;
CLI-LEAN 只存没法从代码重建的部分,其余按需现读。

## 怎么用

- **把这些文件提交进 git。** 它们是纯 markdown——可以 diff、可以审查、自己也能读。
- **别手动维护结构。** AI 会保持同步。你基本只需要说人话:「更新状态,我刚做完登录」
  → 它就去改 `CONTEXT.md`。
- **踩到坑?** 说一句「记住,改 X 时别动 Y」,AI 就把它写进 `PITFALLS.md`。
- **多个 agent 并行?** 可以并行做草稿或证据,但共享引擎文件要单写者收口,最后统一合并。
- **会话结束?** 运行 `/engine-update` 同步状态、写好交接笔记。
- **需要新的记忆类型?** 运行 `/engine-extend` 完整注册新的权威引擎文件。
- **更新 Engine System?** 运行 `/engine-sync`，然后跑 `/engine-doctor`。

完整文档:<https://github.com/elysiayunchen/engine_system>
