# T-089 worker handoff

- CI run 30744979141 failed only in Doctor drift-check.
- Linux exposed eight unreachable historical provenance commits; Windows additionally exposed evidence manifest line-ending mismatches.
- T-082/T-085 local evidence refreshes are in the worktree and are in scope for this card.
- Fix is implemented: evidence LF attribute, historical unreachable provenance WARN, and S6 missing-provenance regression.
