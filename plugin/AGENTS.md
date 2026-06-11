# Engine System — Agent Entry

> Powered by [Engine System](https://github.com/elysiayunchen/engine_system) (v5.1)
> 本文件是**引导器(bootloader)**,不是知识仓库。权威知识在 `engine/`,以
> `engine/ENGINE_MAP.md` 为索引。This file only points; the engine files hold the truth.

---

## FIRST ACTION (MUST)

**Read `engine/ENGINE_MAP.md` BEFORE anything else.** It declares the active profile
(WEB-FULL / CLI-LEAN), the file registry, and the plan relationship graph. Follow its
§0 读取流程 to load the right engine files, then restate the current project state in
one line of 简体中文 and wait for the architect's confirmation before acting.

**If `engine/ENGINE_MAP.md` does not exist**, the engine system is not initialized yet.
Say:
> "引擎文件尚未初始化。运行 `/engine-init` 开始项目采访并生成全套引擎文件(约需 5-10 分钟)。"

---

## TOP RULES (source: engine/SYSTEM.md — 完整规则以彼为准)

> These are excerpts for fast orientation. The authoritative, complete rules live in
> `engine/SYSTEM.md`. On any conflict, the engine file wins. NEVER add a new rule here
> that is not already in SYSTEM.md — new rules go into SYSTEM.md first.

1. ALWAYS check what exists before implementing. Source-first.
2. NEVER make silent assumptions. Ask before proceeding on unclear points.
3. MUST explain trade-offs when multiple approaches exist; recommend one, don't silently pick.
4. MUST stop and confirm before destructive actions (delete/rename files, change schema,
   add a paid dependency). See SYSTEM.md 强制暂停点.

---

## SESSION PROTOCOL

- **Start** — see `engine/SYSTEM.md`「会话加载流程」: read ENGINE_MAP → load by profile →
  restate state in 简体中文 → await confirmation.
- **End** — update `engine/HANDOFF.md` + `engine/ENGINE_MAP.md`, output an engine-file
  change summary. See SYSTEM.md「会话结束流程」. Run `/engine-update` to do this for you.

---

## MAP

- 引擎索引(先读这个):`engine/ENGINE_MAP.md`
- 规则:`engine/SYSTEM.md` ｜ 当前状态:`engine/CONTEXT.md` ｜ 交接:`engine/HANDOFF.md`
- 设计文档(plan)与验收孪生件:`engine/plans/`
- 大项目中,进入某个代码包时,先读该包根部的 `README.md` 取局部上下文。

---

## COMMANDS

| Command | Purpose |
| ---------------- | ---- |
| `/engine-init`      | 首次采访 → 生成 ENGINE_MAP + 全套引擎文件 |
| `/engine-update`    | 会话结束:同步 CONTEXT + 追加 HANDOFF |
| `/engine-status`    | 打印当前项目状态快照 |
| `/add-pitfall`      | 立刻记录一个坑到 PITFALLS.md |
| `/engine-ingest`    | 把一份新设计/plan 归档到 engine/plans/ |
| `/engine-reconcile` | 对账:核对引擎文件与真实代码是否一致,修漂移 |
