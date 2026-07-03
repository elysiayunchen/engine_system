# /engine-status — Engine Dashboard

Read the following files (use Read tool):
- `engine/ENGINE_MAP.md` (first)
- `engine/CONTEXT.md`
- `engine/ENGINE_DOCTOR.md` (if exists; only status/contract summary)
- `engine/SPRINT.md` (if exists)
- `engine/PITFALLS.md` (open items only)
- `engine/HANDOFF.md`
- latest `engine/changes/CHANGE-*.md` capsule if present

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

### Project Self-View
现在能判断：[项目当前最重要的事实，用非技术语言]
还不能判断：[缺少验收证据 / 风险未解释 / 没有 change capsule / 无]
架构师需要看：[latest capsule path / specific AC / pitfall / 无]

### 当前状态
构建：[✅ 正常 / ⚠️ 不稳定 / ❌ 损坏]
上次完成：[item]
进行中：[主 lane + 并行 lanes]
阻塞：[list or 无]
立即恢复点：[HANDOFF 下一步]

### 等你拍板（决策队列）
[列出 engine/decisions/D-*.md 中 status: proposed 的决策,每条:决策 ID + 标题 + 选项 + 推荐选项 + 一句话后果;无 proposed 时写"无"]

### 活跃任务 (SPRINT)
[top 3 tasks with status, or "无 SPRINT 文件"]

### 并行泳道
[lane 列表：Lane / 目标 / 状态 / 交汇点；无并行时写“无”]

### 未解决的坑 (PITFALLS — Open)
[list P-IDs, affected path/scope, and one-line avoid rule, or "无"]

### 最近改动胶囊
[latest CHANGE capsule title + status + risk + verification + rollback, or "无 change capsule"]

### 验收证据
[列出最近任务卡的 engine/evidence/T-NNN/AC-N.json:AC ID + status(pass/fail)+ 指纹前 12 位;无 evidence 时写"无——运行 engine verify T-NNN 生成"]

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
- If code changed but no latest `engine/changes/CHANGE-*.md` exists, or the latest capsule
  lacks risk / verification / rollback, recommend `/engine-update`.
- If Doctor reports failures or warnings, recommend `/engine-doctor` first, then `/engine-reconcile` if the issue is drift.
- If active ACs exist without evidence, surface them under Project Self-View before task details.
- If `PITFALLS.md` has open entries matching currently changed paths, surface the top 3 before task details.
- If a new pitfall is mentioned in CONTEXT/HANDOFF but not present in PITFALLS, recommend `/add-pitfall`.
- If everything is clean and there is a clear next task, recommend continuing that task rather than running another maintenance command.

If the architect asks for a persistent self-view file, write the same dashboard as
`engine/.cache/project-view.generated.md`. It is generated-cache: do not register it in
ENGINE_MAP and regenerate it before trusting it.
