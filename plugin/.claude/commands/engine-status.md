# /engine-status — Current Project Snapshot

Read the following files (use Read tool):
- `engine/CONTEXT.md`
- `engine/SPRINT.md` (if exists)
- `engine/PITFALLS.md` (open items only)

Then output this snapshot — keep it short, scannable, no fluff:

---

```
## 项目状态快照 — [project name] | [today's date]

### 当前状态
构建：[✅ 正常 / ⚠️ 不稳定 / ❌ 损坏]
上次完成：[item]
进行中：[item]
阻塞：[list or 无]

### 活跃任务 (SPRINT)
[top 3 tasks with status, or "无 SPRINT 文件"]

### 未解决的坑 (PITFALLS — Open)
[list P-IDs and one-line descriptions, or "无"]

### 引擎文件健康
[list which engine/*.md files exist, flag any missing ones]
```

---

If any engine file is missing, append:
> "⚠️ 缺少文件：[filename]。运行 `/engine-init` 重新生成，或手动创建。"
