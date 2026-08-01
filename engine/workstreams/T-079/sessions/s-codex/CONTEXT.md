# Workstream Context - T-079 / codex

> status: active | task: T-079 | owner: codex | merge: pending | kind: session

## Goal

让 Codex、CLI/Web agent 与 Claude 使用同一条可执行的任务收口路径：`engine gate` 必须从 Bash/PowerShell CLI 可达并保持真实退出码；`engine doctor` 不得吞掉失败；`engine close` 统一运行 verify → gate → doctor，并把门禁、Doctor、变更胶囊与 coordinator/worker 记忆归属写入机器可读收口证据。这样“验证过”与“可以完成”不再依赖 agent 自己猜测。

## Progress

- Implemented the agent-neutral lifecycle closure path and public CLI dispatch for gate, prove, and close.
- Fixed Bash/PowerShell Doctor exit propagation and CLI-vs-direct evidence provenance for verify, gate, and prove.
- Added fail-closed close checks for verify/gate/doctor, worker handoff, coordinator-owned memory, and task-linked capsules.
- Fixed the canonical `sessions/<sid>` worker-shard pattern in both pre-commit mirrors.
- Fixed PowerShell remaining-argument forwarding (`--handoff`, `--kind`, `--run`, `--execute`) and PowerShell gate child invocation so Windows paths are not handed to WSL bash.

## Changed Paths

- engine/bin/engine and engine/bin/engine.ps1
- engine/scripts/engine-gate.*, engine/scripts/engine-verify.*, engine/scripts/engine-prove.*, engine/scripts/engine-close.*
- plugin/bin/engine*, plugin/engine/scripts/engine-{gate,verify,prove,close}.*
- tests/workstream/test_engine_lifecycle.*
- engine/tasks/T-079.md and engine/tasks/T-079/progress.md

## Evidence

- Lifecycle test: 31 passed, 0 failed.
- PowerShell parser/static test: 16 passed, 0 failed.
- PowerShell `workstream ... --kind session --print`: pass; PowerShell `gate ... --run`: reaches prove without WSL path corruption.
- Task verify: 6/6 AC passed (preflight and full).
- Review: PASS.
- Doctor remains non-zero on repository baseline; coordinator must merge this shard and address shared debt before marking the task done.

## Merge Notes

- Coordinator re-reads this shard before updating shared engine/CONTEXT.md and engine/HANDOFF.md.
