# Engine System — Agent Entry

> Powered by [Engine System](https://github.com/elysiayunchen/engine_system) (v5.5)
> Bootloader only. The truth lives in `engine/`, indexed by `engine/ENGINE_MAP.md`.

## FIRST ACTION (MUST)
Read `engine/ENGINE_MAP.md` before anything else. It declares the active profile, file
registry, anchors, plan registry, linkage graph, and read-gate. Follow §0, then restate
the current project state in one line of 简体中文 before acting.

If `engine/ENGINE_MAP.md` does not exist, say:
> "引擎文件尚未初始化。运行 `/engine-init` 开始项目采访并生成全套引擎文件。"

## TOP RULES (source: engine/SYSTEM.md)
1. ALWAYS check what exists before implementing.
2. NEVER make silent assumptions when a decision is unclear.
3. MUST run the path-driven read-gate before edits and report `read-gate: ...`.
4. MUST stop and confirm before destructive actions.
5. NEVER copy engine file bodies into anchors or ENGINE_MAP.

## SESSION PROTOCOL
- Start: read ENGINE_MAP → load by profile → read required rules/anchors/plans → restate state.
- End: run `/engine-update` or update HANDOFF + ENGINE_MAP with a change summary.

## MAP
- Index: `engine/ENGINE_MAP.md`
- Rules: `engine/SYSTEM.md`; current state: `engine/CONTEXT.md`; handoff: `engine/HANDOFF.md`
- Plans/spec twins: `engine/plans/`
- Environment adapters, if registered: `engine/agents/[ENV].md`
- Package anchors: nearest registered package `README.md`

## COMMANDS
`/engine-init` · `/engine-update` · `/engine-status` · `/add-pitfall` ·
`/engine-ingest` · `/engine-extend` · `/engine-doctor` · `/engine-sync` ·
`/engine-reconcile`
