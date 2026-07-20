# AGENT ADAPTERS — 跨 Agent 自维护适配

> Engine System (engine_system) · Last updated: 2026-06-21
> 说明：自维护循环的核心机制按 agent 能力分三档落地，各自独立兜底。

---

## 三档总览

| 档位 | 机制 | agent 门槛 | 覆盖 |
|------|------|-----------|------|
| **A 档 · 锚点契约** | 读 AGENTS.md / CLAUDE.md → 遵循会话开始/结束协议 | 只要能读引导文件 | 最广 — 包括 Web 端 |
| **B 档 · git pre-commit** | `git commit` 时自动检查「改代码→回写引擎」 | 任何走 git commit 的工具 | 全覆盖 — agent 无关 |
| **C 档 · 原生 hook** | agent 的 SessionStart/Stop 生命周期自动触发 | 支持 hook 的 CLI | 体验最优 — Claude Code / Copilot CLI / Codex CLI / Cursor / Q CLI |

---

## 各 agent 适配

### Claude Code
- **引导文件**: `CLAUDE.md`（自动加载），`@AGENTS.md` 语法引用
- **A 档**: ✅ AGENTS.md 写入 SESSION PROTOCOL + read-gate
- **B 档**: ✅ git pre-commit hook 随 install 分发
- **C 档**: ✅ **原生支持** SessionStart / Stop hook；`.claude/settings.json` 随 install 铺设
- **状态**: 全三档覆盖，体验最佳

### GitHub Copilot CLI (GA 2026-02-25)
- **引导文件**: `.github/copilot-instructions.md`（自动加载）；AGENTS.md 支持待核实
- **A 档**: ✅ 可将 AGENTS.md 内容也写进 copilot-instructions.md（由 `/engine-sync` 同步）
- **B 档**: ✅ git pre-commit 覆盖
- **C 档**: ✅ **支持 lifecycle hooks**（sessionStart / sessionEnd / userPromptSubmitted / preToolUse / postToolUse / errorOccurred）
- **适配**: 需为 Copilot CLI 写独立 hooks 配置（`.github/copilot-hooks.json`），脚本复用同一套 engine-hook-*.sh

### OpenAI Codex CLI
- **引导文件**: 读 `AGENTS.md`（官方文档确认）
- **A 档**: ✅ AGENTS.md 直接生效
- **B 档**: ✅ git pre-commit 覆盖
- **C 档**: ⚠️ 有 `notify` hook（agent-turn-complete 事件），能力边界待核实。若支持 Stop 等价事件可复用 hook 脚本。
- **适配**: 若 notify hook 可返回 block 决策，加一个 `engine-hook-codex.sh` 适配器

### Cursor
- **引导文件**: `.cursor/rules/`（新版 rules 系统），旧版 `.cursorrules` 已弃用
- **A 档**: ✅ 需将 AGENTS.md 核心指令同步到 `.cursor/rules/engine.md`（`/engine-sync` 处理）
- **B 档**: ✅ git pre-commit 覆盖
- **C 档**: ⚠️ Plugin 系统有 stop/sessionEnd 事件，但非标准 CLI hook 格式。投入产出比较低，暂不优先适配。
- **适配**: 当前靠 A+B 档兜底

### Google Gemini CLI
- **引导文件**: `GEMINI.md` 或可配置 `contextFileName`
- **A 档**: ✅ 需将 AGENTS.md 核心指令同步到 `GEMINI.md`（`/engine-sync` 处理）
- **B 档**: ✅ git pre-commit 覆盖
- **C 档**: ❌ 无生命周期 hook
- **适配**: A+B 档兜底

### Aider
- **引导文件**: `.aider.conf.yml`（配置文件，非 markdown）；不自动读 AGENTS.md
- **A 档**: ⚠️ 需在 `.aider.conf.yml` 的 `read` 字段列出引擎文件路径
- **B 档**: ✅ git pre-commit 覆盖
- **C 档**: ❌ 无生命周期 hook；但 Aider 自动 git commit 是天然优势——每次改动后自动提交，pre-commit hook 自然触发。
- **适配**: Aider 的自动 commit + B 档 pre-commit 恰好形成闭环

### Cline / Roo Code (VSCode)
- **引导文件**: 可配置 `.clinerules`（Cline）；Roo Code 用 `.roorules`
- **A 档**: ⚠️ 需同步规则文件
- **B 档**: ✅ git pre-commit 覆盖
- **C 档**: ⚠️ Cline v3.36+ 有 Hooks（PreToolUse / PostToolUse / UserPromptSubmit / TaskStart），但无 session-end 类事件。Roo Code 无 hook。
- **适配**: B 档为主

### Amazon Q Developer CLI
- **引导文件**: 待核实
- **A 档**: 待核实
- **B 档**: ✅ git pre-commit 覆盖
- **C 档**: ⚠️ 有 `stop` hook（每轮 agent 完成时触发），能力待核实

---

## Universal Context Loader: `engine context`

> **This is the most critical feature for multi-agent support.**

`engine context` is an agent-agnostic CLI command that outputs the full session memory snapshot — the same content Claude Code gets automatically via the SessionStart hook. Any AI agent can run it to bootstrap context.

| Command | Bash | PowerShell |
|---------|------|-----------|
| Via CLI shim | `engine context` | `engine context` |
| Direct script | `bash engine/scripts/engine-context.sh` | `powershell -File engine/scripts/engine-context.ps1` |

**Output sections** (same as Claude Code SessionStart hook):
1. L0 Constitution (runtime-law.md)
2. Glossary header (GLOSSARY.md — plain-language bridge)
3. Current state (CONTEXT.md, first 50 lines)
4. Last handoff (HANDOFF.md, newest 4 rows)
5. Domain dashboard (federation.json summaries)
6. Active task card (full content)
7. L2 domain assembly (domain CONTEXT + PITFALLS)
8. Pending decisions (proposed queue)
9. Previous session pending notes

**Agent integration**: Agents that read AGENTS.md will see the Session Protocol requiring `engine context` at session start. Agents with rule files (Cursor `.cursor/rules/engine.md`, Copilot `copilot-instructions.md`, Gemini `GEMINI.md`) should include the same instruction, synced by `engine-sync-agent-anchors.sh`.

---

## 设计原则

1. **B 档(git pre-commit)是真正的最大公约数** — 任何 agent、任何平台，只要走 git，门禁就生效。这是唯一不需要 agent 配合的机制。
2. **A 档(锚点契约)覆盖 Web 端** — 网页版 AI 读不到 hook 脚本，但能读到 AGENTS.md 里的 SESSION PROTOCOL。配合"增量回写"契约(边干边记)，是 Web 端最现实的兜底。
3. **C 档(原生 hook)追求体验最优** — 在支持的 CLI 上做到"架构师零操作"。不需要覆盖所有 agent，有几个算几个。
4. **三档独立兜底** — 任何一档失效(比如 C 档的 agent 不支持 hook)，B 档 pre-commit 照样拦截。
5. **`engine context` 是 A/B 档 agent 的核心桥梁** — 非 C 档 agent 没有自动上下文注入，`engine context` 提供了等效的 agent-agnostic 命令，任何能执行 shell 的 agent 都能获取完整会话上下文。

---

## 实施状态

| Agent | A 档 | B 档 | C 档 | 优先级 |
|-------|------|------|------|--------|
| Claude Code | ✅ | ✅ | ✅ 已实现 | P0 |
| Copilot CLI | 待适配 | ✅ | 待适配 | P1 |
| Codex CLI | ✅ AGENTS.md | ✅ | 待核实 | P1 |
| Cursor | 待适配 | ✅ | 暂不优先 | P2 |
| Gemini CLI | 待适配 | ✅ | N/A | P2 |
| Aider | 待适配 | ✅ | N/A | P2 |
| Cline / Roo | 待适配 | ✅ | 暂不优先 | P2 |
| Amazon Q CLI | 待核实 | ✅ | 待核实 | P2 |
| Web 端 AI | ✅ 契约 | N/A | N/A | P0 |

---

## C 档扩展:多会话锁使用约束(v6.11.0+, D-029/T-036)

> 多会话锁机制让多个 Claude Code 实例并行运行时不再抢写共享引擎记忆。以下规则适用于所有支持 C 档 hook 的 agent。

### 多会话锁基础

- **协调者/worker 角色**: 第一个 SessionStart 获得协调者(写共享 CONTEXT/HANDOFF/ENGINE_MAP),后续会话自动降级为 worker(只写 `engine/workstreams/<task>/<session-id>/` 隔离分片)。
- **lock file**: `engine/.cache/session.lock` 5 字段 `pid|session_id|role|started_at|task_id`。
- **tombstone**: `engine/.cache/session.tombstone` 通知其他会话旧协调者已退出(正常退出写 `coordinator-exited`,强制替换写 `forced-replaced`)。
- **双信号 PreToolUse 拦截**: worker 身份由 OR 关系判定 — `agent_id` 非空 **或** `.cache/sessions/<key>.role=worker` 标记文件存在(任一即拦截共享记忆写入)。

### `engine assume-coordinator [--force]` 使用频率警示

- **--force 是逃生通道,不是常规操作**。滥用 `--force` 会绕过协调者排他性,导致并发写竞争回潮,抵消 v6.11.0 的核心收益。
- **合法使用场景**(频率应 ≤ 每周 1 次):
  1. 旧协调者崩溃后留下 stale lock(已超过 24h tombstone 过期阈值)。
  2. 协调者会话意外关闭但 lock 未释放(进程未正常退出)。
  3. 架构师明确要切换协调者到另一会话(罕见,需先确认旧协调者已停止工作)。
- **非法使用场景**:
  1. 为了"绕过 PreToolUse 拦截"而频繁 --force(应改用 `engine workstream --kind=session` 显式降级)。
  2. 在 worker 想直接改共享记忆时 --force(应改用 `engine merge-workstream <session-id>` 由协调者合并)。
  3. 多个 worker 同时 --force 抢协调者(必然产生 tombstone 风暴,失去锁的意义)。
- Doctor 通过 `check_multi_session_isolation` 检查 tombstone 文件数量与时间分布,异常高频会触发 WARN。

### 同一任务卡不同 AC 的并行约束

- **同一任务卡的不同 AC 不应同时由多个 worker 并行实现**,原因:
  1. **WRITE-SET 重叠**: 同一任务卡的 AC 共享同一 WRITE-SET 路径集合,多 worker 同时改同文件会产生 git 冲突。
  2. **evidence 顺序**: `engine-verify` 按 AC 编号顺序写 evidence,并行写会产生交错覆盖。
  3. **checkpoint.md 串行性**: AC-级 checkpoint 是单链表结构(每个 AC 完成后追加),并行写会破坏链表完整性。
- **合法并行模式**:
  - 同一任务卡的不同 AC 由**单一协调者串行推进**(默认)。
  - 不同任务卡可由不同 worker 并行(各自写自己的 workstreams/<task>/<worker>/ 分片)。
  - 同一任务卡需要并行时,先在决策卡(D-NNN)中拆分为多个子任务卡(T-NNN-a, T-NNN-b),每个 worker 认领一张独立卡。
- **PreToolUse 拦截兜底**: worker 写入非自己分片的路径时,Stop hook 会 block,但不会预先阻止"两个 worker 同时认领同一 AC" — 这是架构师的责任,通过任务卡分配避免。

### kill switch

- 环境变量 `ENGINE_DISABLE_MULTI_SESSION=1` 或 `engine/.cache/multi-session.disabled` 标志文件存在时,SessionStart hook 跳过 lock 检测,所有会话降级为单会话模式(等同 v6.10.0 行为,fail-open)。
- 仅用于 v6.11.0 升级期间发现兼容性问题时的紧急回退。长期开启 kill switch 等于放弃多会话锁保护,应尽快定位问题并重新启用。
