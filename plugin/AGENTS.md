# Engine System — Agent Entry

> Powered by [Engine System](https://github.com/elysiayunchen/engine_system) (v6.0)
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
- During work: after any meaningful code change, update `CONTEXT.md` + append one
  `HANDOFF.md` row and create/update an architect-readable `engine/changes/CHANGE-*.md`
  capsule before moving on. This is incremental write-back, not optional cleanup.
- End: run `/engine-update` or update HANDOFF + ENGINE_MAP with a change summary and
  latest change capsule pointer. Claude
  Code hooks may block Stop if code changed but the engine memory did not.

## COMMAND MAP
- `/engine-init` — initialize or regenerate the engine layer
- `/engine-update` — write session handoff; preserve lane structure if multiple workstreams exist
- `/engine-status` — print current snapshot with lane-aware status
- `/add-pitfall` — register a new pitfall
- `/engine-ingest` — record a new plan and spec twin
- `/engine-extend` — register a new authority file or adapter
- `/engine-doctor` — validate engine health
- `/engine-sync` — migrate bundled tooling and reconcile engine files
- `engine check-update` / `engine update` / `engine migrate` — terminal CLI: detect remote version, fetch+migrate+doctor (one-shot), or run migration alone
- `/engine-reconcile` — compare docs vs reality and land fixes

## MULTI-LANE WORK
- Multiple workstreams may run in parallel.
- Shared engine-file writes are single-writer only.
- CONTEXT, SPRINT, ROADMAP, and HANDOFF may carry lane IDs, owners, dependencies, merge points, and next checkpoints.
- Use the lane with the matching goal; do not flatten parallel work into one queue.

## SELF-MAINTENANCE LOOP
- A layer: this anchor contract applies to every agent that reads `AGENTS.md`.
- B layer: git pre-commit blocks commits that change code without engine write-back.
- C layer: Claude Code SessionStart/Stop hooks auto-load context, gate missing write-back,
  and cache Doctor findings for the next session.
- Web AI has no hooks, so it MUST perform incremental write-back manually after each
  meaningful unit.

## ARCHITECT SELF-VIEW
- Meaningful changes need a change capsule: goal, actual changes, impact scope, risk,
  verification, rollback, next step, and responsibility boundary.
- `/engine-status` should surface the latest capsule and say what the architect can judge
  now, what evidence is missing, and what decision remains theirs.

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
