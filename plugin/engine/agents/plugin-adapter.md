# Plugin Agent Adapter — Engine System

> Environment-specific details for plugin-distributed projects. General authority
> remains `engine/SYSTEM.md` and `engine/REPO_GUIDE.md`.

## Multi-Lane Work
- Multiple workstreams may run in parallel.
- Shared engine-file writes are single-writer only.
- CONTEXT, SPRINT, ROADMAP, and HANDOFF may carry lane IDs, owners, dependencies,
  merge points, and next checkpoints.
- Use the lane with the matching goal; do not flatten parallel work into one queue.

## Self-Maintenance Loop
- A layer: the anchor contract in AGENTS.md applies to every agent that reads it.
- B layer: git pre-commit blocks commits that change code without engine write-back.
- C layer: Claude Code SessionStart/Stop hooks auto-load context, gate missing
  write-back, and cache Doctor findings for the next session.
- Web AI has no hooks, so it MUST perform incremental write-back manually after each
  meaningful unit.

## Architect Self-View
- Meaningful changes need a change capsule: goal, actual changes, impact scope, risk,
  verification, rollback, next step, and responsibility boundary.
- `/engine-status` should surface the latest capsule and say what the architect can judge
  now, what evidence is missing, and what decision remains theirs.

## Full Command Reference
`/engine-init` · `/engine-update` · `/engine-status` · `/add-pitfall` ·
`/engine-ingest` · `/engine-extend` · `/engine-doctor` · `/engine-sync` ·
`/engine-reconcile`

Terminal CLI: `engine check-update` / `engine update` / `engine migrate`
