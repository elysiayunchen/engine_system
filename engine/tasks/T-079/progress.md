# T-079 progress

## Status

- active — lifecycle closure repair in progress.

## Findings

- `engine/scripts/engine-gate.{sh,ps1}` existed, but both CLI shims routed `gate` to unknown-command handling.
- `run_doctor` / `Run-Doctor` printed failures while returning success to the caller.
- Verify and gate evidence hard-coded `argv`, so direct script execution could be mistaken for the standard CLI path.
- Gate remediation named `engine prove`, but neither public CLI exposed that command; PROVE evidence also used a hard-coded CLI argv.
- Stop-hook shared-memory rules were Claude-native; non-Claude agents had no canonical command to produce a closure audit and worker handoff.
- `engine workstream` emitted `sessions/<sid>` shards while pre-commit only accepted a legacy two-level shard path, so a valid worker handoff could not be committed.
- `engine close` now owns verify → gate → doctor sequencing, fail-closed memory/capsule checks, and worker-shard handoff evidence without writing coordinator-owned singleton memory.

## Verification

- `bash tests/workstream/test_engine_lifecycle.sh`: 29 passed, 0 failed; PowerShell runtime smoke skipped because the Bash environment could not resolve `pwsh`.
- PowerShell parser pass for all changed `.ps1` files and the lifecycle test.
- `bash -n` pass for all changed Bash scripts; `git diff --check` pass.
- Existing regressions previously passed: gate CLI 11/11, acceptance preflight 22/22, behavior verification 12/12, pre-commit gate 9/9, seal gate 5/5, evidence provenance 6/6.
- `bash engine/bin/engine verify T-079 --preflight`: 6/6 AC pass; full verify also passed 6/6.
- `bash engine/bin/engine gate T-079`: reachable and fail-closed, currently blocked by missing review, agent-review, and prove evidence (expected until the task card is committed and review/prove stages are run).
- `bash engine/bin/engine doctor`: correctly returns non-zero and exposes 27 failures / 211 warnings in the repository baseline; shared-memory and pre-existing task debt remain coordinator-owned.
