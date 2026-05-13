# Engine System — Project Memory Bridge

> Powered by [engine-system](https://github.com/elysiayunchen/engine-system)
> Drop-in persistent memory for AI-assisted development.

---

## Session Start Protocol

**If `engine/` contains .md files**, read in this order before doing anything:

1. `engine/CONTEXT.md` — current state, what's broken, blockers
2. `engine/SYSTEM.md` — collaboration rules, what you must/never do
3. `engine/PITFALLS.md` — known landmines (read before any edit)
4. `engine/ARCHITECTURE.md` — tech stack, directory structure, data model
5. `engine/SPRINT.md` — active tasks and priorities (if exists)

After reading, output a one-line session summary:

> "已加载引擎文件。当前状态：[CONTEXT.md 状态面板摘要]。最高优先级：[SPRINT.md top task or 'none']。"

**If `engine/` is empty or missing files**, say:

> "引擎文件尚未初始化。运行 `/engine-init` 开始项目采访并生成全套引擎文件（约需 5-10 分钟）。"

---

## Available Commands

| Command          | Purpose                                                                  |
| ---------------- | ------------------------------------------------------------------------ |
| `/engine-init`   | First-time setup: structured interview → writes all engine files to disk |
| `/engine-update` | End-of-session: update CONTEXT.md + append HANDOFF.md entry              |
| `/add-pitfall`   | Immediately record a new pitfall to PITFALLS.md                          |
| `/engine-status` | Print current project status snapshot                                    |

---

## Insertion Rules (applies to all engine file edits)

ALWAYS follow these rules when writing to any `engine/*.md` file:

- **Append**: New rows go to end of tables; new list items go to end of lists
- **IDs**: Numbered entries (P001, TASK-01) use current max + 1
- **Time-ordered sections**: Most recent entry at top
- **Never delete**: Use status markers (e.g., `Status: Resolved`) instead of removing rows
- **Modify existing**: Edit the row/paragraph in place — no duplicates, no new versions
