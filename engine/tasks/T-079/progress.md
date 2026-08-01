# T-079 progress

## Status

- active — lifecycle closure implementation complete; repository Doctor debt still blocks final close.

## Findings

- `engine/scripts/engine-gate.{sh,ps1}` existed, but both CLI shims routed `gate` to unknown-command handling.
- `run_doctor` / `Run-Doctor` printed failures while returning success to the caller.
- Verify and gate evidence hard-coded `argv`, so direct script execution could be mistaken for the standard CLI path.
- Gate remediation named `engine prove`, but neither public CLI exposed that command; PROVE evidence also used a hard-coded CLI argv.
- Stop-hook shared-memory rules were Claude-native; non-Claude agents had no canonical command to produce a closure audit and worker handoff.
- `engine workstream` emitted `sessions/<sid>` shards while pre-commit only accepted a legacy two-level shard path, so a valid worker handoff could not be committed.
- PowerShell's public CLI and gate runner dropped `--handoff`/`--kind`-style remaining arguments and attempted to pass Windows paths to WSL `bash`; the mirror now preserves remaining flags and launches PowerShell children for PS gate execution.
- Prove initially leaked the outer `ENGINE_CLI_ENTRYPOINT` into nested assertions, causing a direct gate invocation to be mislabeled; prove now captures and clears the outer label before executing user assertions.
- `engine close` now owns verify → gate → doctor sequencing, fail-closed memory/capsule checks, and worker-shard handoff evidence without writing coordinator-owned singleton memory.

## Verification

- `bash tests/workstream/test_engine_lifecycle.sh`: 32 passed, 0 failed; PowerShell runtime smoke skipped inside Bash because that shell could not resolve `pwsh`.
- PowerShell parser/lifecycle static test: 17 passed, 0 failed.
- `bash -n` passes for all changed Bash scripts.
- Existing regressions previously passed: gate CLI 11/11, acceptance preflight 22/22, behavior verification 12/12, pre-commit gate 9/9, seal gate 5/5, evidence provenance 6/6.
- `bash engine/bin/engine verify T-079 --preflight`: 6/6 AC pass; full verify also passed 6/6.
- `bash engine/bin/engine gate T-079`: PASS after review, agent review, prove, and verify evidence were generated against the final commit.
- PowerShell `engine workstream T-079 codex --kind session --print`: pass; PowerShell `engine gate T-079 --run`: reaches prove without WSL path corruption and remains blocked only by missing proof/reviewer evidence in the isolated smoke fixture.
- Lifecycle regression after the provenance-leak and review-package hash fixes: 32/32 pass; `engine prove T-079 --execute`: 1/1 pass.
- Review package provenance regression fixed: pre-commit now normalizes only the package header (`count=1`), matching the package generator even when the protocol body contains hash examples.
- `engine close T-079 --handoff codex`: verify exit 0, gate exit 0, Doctor exit 1, worker memory pass, capsule deferred_to_coordinator; final status BLOCK as designed.
- PowerShell full close reached verify=0, gate=0, Doctor=1; a stale `$LASTEXITCODE` then exposed a worker-shard rc contamination, fixed by launching workstream as a child PowerShell process. The final PowerShell close exits 1 only because Doctor exits 1, with worker memory pass and capsule deferred to the coordinator.
- Final Bash close Doctor result: 27 failures / 215 warnings, all repository baseline/shared-memory or pre-existing task evidence debt outside this worker's safe write-set.
- `bash engine/bin/engine doctor` correctly returns non-zero; shared-memory and pre-existing task debt remain coordinator-owned.
