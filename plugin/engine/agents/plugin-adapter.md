# Plugin Agent Adapter — Engine System

> Environment-specific details for plugin-distributed projects. General authority
> remains `engine/SYSTEM.md` and `engine/REPO_GUIDE.md`.

## Multi-Lane Work
- Multiple workstreams may run in parallel.
- Workers run `engine workstream T-NNN <agent-id>` and write only their own
  `engine/workstreams/<task>/<agent>/` CONTEXT/HANDOFF shard plus evidence.
- Shared CONTEXT/HANDOFF/SYSTEM/PITFALLS/anchors/plans are coordinator-only; the
  coordinator re-reads pending shards and updates shared memory once at the merge point.

## Self-Maintenance Loop
- A layer: the anchor contract in AGENTS.md applies to every agent that reads it.
- B layer: git pre-commit checks WRITE-SET/FORBIDDEN for all staged paths and accepts
  coordinator memory or a worker shard as write-back.
- C layer: Claude Start/Prompt/PreTool/Stop hooks load context, refresh short guards,
  block worker shared-memory writes, and attribute changed paths per session/agent.
- Web/other CLI agents use the same workstream directory protocol without native hooks.

## Architect Self-View
- Meaningful changes need a change capsule: goal, actual changes, impact scope, risk,
  verification, rollback, next step, and responsibility boundary.
- `/engine-status` should surface the latest capsule and say what the architect can judge
  now, what evidence is missing, and what decision remains theirs.

## Full Command Reference
`/engine-init` · `/engine-update` · `/engine-status` · `/add-pitfall` ·
`/engine-ingest` · `/engine-extend` · `/engine-doctor` · `/engine-sync` ·
`/engine-reconcile`

Terminal CLI: `engine context` / `engine workstream T-NNN <agent-id>` /
`engine check-update` / `engine update` / `engine migrate`
