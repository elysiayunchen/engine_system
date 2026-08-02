# T-089 Progress

## Status

- Active; investigating CI evidence drift.

## Completed

- Confirmed Linux drift-check is clean locally after the existing T-082/T-085 evidence refresh.
- Confirmed Windows failures are caused by evidence files lacking an explicit LF attribute.
- Confirmed eight historical provenance commits are reachable locally but absent from remote refs.
- Added LF checkout policy, legacy-unreachable provenance warnings, and a regression fixture for missing MANIFEST provenance.
- Bash drift regression: 6 pass, 0 fail; PowerShell T-082/T-085 checks: tamper=0, drift=0.

## Next

- Commit only T-089 WRITE-SET, push, and verify CI.
