# Engine System — Agent Entry

> Powered by [Engine System](https://github.com/elysiayunchen/engine_system) (v6.5)
> Bootloader only. Truth lives in `engine/`, indexed by `engine/ENGINE_MAP.md`.

## FIRST ACTION (MUST)
Read `engine/ENGINE_MAP.md` before anything else. Follow §0, then restate the
current project state in one line of 简体中文 before acting.
Before any edit, output: `read-gate: ENGINE_MAP ✓, SYSTEM ✓, state: [一句话]`.
If `engine/ENGINE_MAP.md` does not exist, say:
> "引擎文件尚未初始化。运行 `/engine-init` 开始项目采访并生成全套引擎文件。"

## TOP RULES (source: engine/SYSTEM.md — complete rules reside there)
1. ALWAYS check what exists before implementing. (source: engine/SYSTEM.md)
2. NEVER make silent assumptions when a decision is unclear. (source: engine/SYSTEM.md)
3. MUST run the path-driven read-gate before edits. (source: engine/SYSTEM.md)
4. MUST stop and confirm before destructive actions. (source: engine/SYSTEM.md)
5. NEVER copy engine file bodies into anchors or ENGINE_MAP. (source: engine/SYSTEM.md)

## ANCHOR IMMUTABILITY
This file is a managed bootloader. Do NOT add original rules here.
All new rules → engine/SYSTEM.md; this file only excerpts with `source:` tags.

## SESSION PROTOCOL
- Start: read ENGINE_MAP → load by profile → read rules/anchors/plans → restate state.
- Before edits: one independently verifiable goal shares one task across prompts/workers; read-only work needs none. Otherwise create/activate `engine/tasks/T-NNN.md`; v6.5+ ordinary writes fail closed without one.
- During: coordinator updates shared memory; parallel workers run `engine workstream T-NNN <agent-id>` and update only that shard.
- End: run `/engine-update`; Claude Code hooks may block Stop if write-back missing.
- Multi-lane, self-maintenance loop, architect view: see `engine/agents/plugin-adapter.md`.

## COMMANDS
- `/engine-init` init · `/engine-update` handoff · `/engine-status` snapshot
- `/add-pitfall` · `/engine-ingest` plan · `/engine-extend` file · `/engine-doctor` health
- `/engine-sync` migrate · `/engine-reconcile` reconcile
- CLI: `engine context` · `engine workstream T-NNN <agent-id>` · `engine check-update` · `engine update` · `engine migrate`

## MAP
- Index: `engine/ENGINE_MAP.md` · Rules: `engine/SYSTEM.md` · State: `engine/CONTEXT.md`
- Repo dev rules: `engine/REPO_GUIDE.md` · Handoff: `engine/HANDOFF.md`
- Plans: `engine/plans/` · Adapters: `engine/agents/[ENV].md`
- Package anchors: nearest registered package `README.md`
