# /engine-status — Engine Dashboard

Read the following files (use Read tool):
- `engine/ENGINE_MAP.md` (first)
- `engine/CONTEXT.md`
- `engine/ENGINE_DOCTOR.md` (if exists; only status/contract summary)
- `engine/SPRINT.md` (if exists)
- `engine/PITFALLS.md` (open items only)
- `engine/HANDOFF.md`

Run a read-only inspection when possible:
- `git status --short`
- `engine/scripts/engine-doctor.*` if available, or summarize why it was skipped

Then output this dashboard — keep it short, scannable, no fluff:

---

```
## 引擎仪表盘 — [project name] | [today's date]

### 总览
健康：[🟢 稳 / 🟡 需同步 / 🔴 需修复]
推荐下一步：[/engine-update / /engine-doctor / /engine-reconcile / /add-pitfall / 无]
原因：[one sentence tied to evidence below]

### 当前状态
构建：[✅ 正常 / ⚠️ 不稳定 / ❌ 损坏]
上次完成：[item]
进行中：[主 lane + 并行 lanes]
阻塞：[list or 无]
立即恢复点：[HANDOFF 下一步]

### 活跃任务 (SPRINT)
[top 3 tasks with status, or "无 SPRINT 文件"]

### 并行泳道
[lane 列表：Lane / 目标 / 状态 / 交汇点；无并行时写“无”]

### 未解决的坑 (PITFALLS — Open)
[list P-IDs, affected path/scope, and one-line avoid rule, or "无"]

### 引擎文件健康
[registry → disk and disk → registry summary; flag missing/unregistered authority-looking files]
Doctor：[registered + scripts present / missing / not registered / last result if known]
Git 同步：[clean / changed files / changed code without engine write-back]
Read-gate：ENGINE_MAP + CONTEXT + SPRINT/PITFALLS as applicable
```

---

If any engine file is missing, append:
> "⚠️ 缺少文件：[filename]。运行 `/engine-init` 重新生成，或手动创建。"

If authority-looking files under `engine/*.md` or `engine/agents/*.md` are unregistered,
append:
> "⚠️ 发现未登记的引擎文件：[path]。运行 `/engine-reconcile` 对账，或 `/engine-extend` 完整注册。"

Recommendation rules:
- If code changed but `CONTEXT.md` / `HANDOFF.md` did not change, recommend `/engine-update`.
- If Doctor reports failures or warnings, recommend `/engine-doctor` first, then `/engine-reconcile` if the issue is drift.
- If `PITFALLS.md` has open entries matching currently changed paths, surface the top 3 before task details.
- If a new pitfall is mentioned in CONTEXT/HANDOFF but not present in PITFALLS, recommend `/add-pitfall`.
- If everything is clean and there is a clear next task, recommend continuing that task rather than running another maintenance command.
