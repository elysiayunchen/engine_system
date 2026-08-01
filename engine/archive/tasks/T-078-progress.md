# T-078 progress

## Goal

Acceptance preflight for issue #25.

## Current Step

Completed issue #25 acceptance preflight and verified all acceptance criteria.

## Done

- Task card created; issue #25 reproduction and existing verifier paths read.
- Added `acceptance-preflight` and `engine verify --preflight`/`--no-cov` handling to Bash and PowerShell CLIs.
- Evidence now separates `command_exit`, `behavior_exit`, `environment_status`, `coverage_status`, `coverage_policy`, and `preflight`; blocked results are non-zero and never PASS.
- Kept engine/plugin verifier and CLI mirrors byte-identical.
- Added Bash and PowerShell regression fixtures for coverage, missing dependencies, behavior failures, aliases, and mirror parity.
- `engine verify T-078 --preflight`: 7 pass, 0 fail, 0 blocked, 0 skip.
- Acceptance preflight test: 23 pass, 0 fail; existing behavior verifier: 24 pass, 0 fail; env cleanup: 2 pass; Bash detection: 11 pass.

## Next AC

None.

> Archived by T-081 so the done card no longer retains a live progress file.
