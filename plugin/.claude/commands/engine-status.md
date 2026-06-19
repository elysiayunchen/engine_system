# /engine-status — Current Project Snapshot

Read the following files (use Read tool):
- `engine/ENGINE_MAP.md` (first)
- `engine/CONTEXT.md`
- `engine/ENGINE_DOCTOR.md` (if exists; only status/contract summary)
- `engine/SPRINT.md` (if exists)
- `engine/PITFALLS.md` (open items only)

Then output this snapshot — keep it short, scannable, no fluff:

---

```
## 项目状态快照 — [project name] | [today's date]

### 当前状态
构建：[✅ 正常 / ⚠️ 不稳定 / ❌ 损坏]
上次完成：[item]
进行中：[主 lane + 并行 lanes]
阻塞：[list or 无]

### 活跃任务 (SPRINT)
[top 3 tasks with status, or "无 SPRINT 文件"]

### 并行泳道
[lane 列表：Lane / 目标 / 状态 / 交汇点；无并行时写“无”]

### 未解决的坑 (PITFALLS — Open)
[list P-IDs and one-line descriptions, or "无"]

### 引擎文件健康
[registry → disk and disk → registry summary; flag missing/unregistered authority-looking files]
Doctor：[registered + scripts present / missing / not registered / last result if known]
Read-gate：ENGINE_MAP + CONTEXT + SPRINT/PITFALLS as applicable
```

---

If any engine file is missing, append:
> "⚠️ 缺少文件：[filename]。运行 `/engine-init` 重新生成，或手动创建。"

If authority-looking files under `engine/*.md` or `engine/agents/*.md` are unregistered,
append:
> "⚠️ 发现未登记的引擎文件：[path]。运行 `/engine-reconcile` 对账，或 `/engine-extend` 完整注册。"
