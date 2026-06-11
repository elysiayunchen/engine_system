# Engine System — Project Memory Bridge

> Powered by [Engine System](https://github.com/elysiayunchen/engine_system) (v5.1)
> Drop-in persistent memory for AI-assisted development.
> This file is a **bootloader**, not a knowledge store. The truth lives in `engine/`.

If your AI tool supports import syntax, this file can be a single line: `@AGENTS.md`.
Otherwise it mirrors `AGENTS.md` (the canonical bootloader); `/engine-reconcile` keeps
the two consistent.

---

## FIRST ACTION (MUST)

**Read `engine/ENGINE_MAP.md` BEFORE anything else.** It is the index layer — it
declares the active profile (WEB-FULL / CLI-LEAN), the file registry, and the plan
relationship graph. Follow its §0 读取流程 to load the right engine files, then restate
the current project state in one line of 简体中文 and wait for confirmation before acting.

**If `engine/ENGINE_MAP.md` does not exist**, say:

> "引擎文件尚未初始化。运行 `/engine-init` 开始项目采访并生成全套引擎文件(约需 5-10 分钟)。"

---

## TOP RULES (source: engine/SYSTEM.md — 完整规则以彼为准)

> Excerpts for fast orientation. The authoritative rules live in `engine/SYSTEM.md`;
> on any conflict, the engine file wins. NEVER add a rule here that isn't in SYSTEM.md.

1. ALWAYS check what exists before implementing. Source-first.
2. NEVER make silent assumptions. Ask before proceeding on unclear points.
3. MUST explain trade-offs when multiple approaches exist; recommend one, don't silently pick.
4. MUST stop and confirm before destructive actions (delete/rename files, change schema,
   add a paid dependency). See SYSTEM.md 强制暂停点.

---

## SESSION PROTOCOL

- **Start** — see `engine/SYSTEM.md`「会话加载流程」: read ENGINE_MAP → load by profile →
  restate state in 简体中文 → await confirmation.
- **End** — run `/engine-update`: it syncs `CONTEXT.md`, appends a `HANDOFF.md` entry,
  and updates `ENGINE_MAP.md`. Output an engine-file change summary.

---

## Available Commands

| Command          | Purpose                                                                  |
| ---------------- | ------------------------------------------------------------------------ |
| `/engine-init`     | First-time setup: interview → write ENGINE_MAP + all engine files to disk |
| `/engine-update`   | End-of-session: update CONTEXT.md + append HANDOFF.md + bump ENGINE_MAP   |
| `/engine-status`   | Print current project status snapshot                                    |
| `/add-pitfall`     | Immediately record a new pitfall to PITFALLS.md                          |
| `/engine-ingest`   | File a new design/plan into engine/plans/ with a spec twin              |
| `/engine-reconcile`| Audit engine files vs real code, absorb drift, fix dangling refs        |

---

## Insertion Rules (applies to all engine file edits)

ALWAYS follow these when writing to any `engine/*.md` file:

- **Append**: New rows go to end of tables; new list items go to end of lists
- **IDs**: Numbered entries (P001, TASK-01, PLAN-01) use current max + 1
- **Time-ordered sections**: Most recent entry at top
- **Never delete**: Use status markers (e.g., `Status: Resolved`, `superseded`) instead of removing
- **Modify existing**: Edit the row/paragraph in place — no duplicates, no new versions
- **Re-anchor**: Re-read a file from disk before writing back to it (guards against stale context)
- **ENGINE_MAP is the index**: never copy other files' body content into it — relationships and metadata only
