# T-060 checkpoint — v6.16.0 doctor 一致性对齐

> Task: T-060 | 7/7 AC PASS | 2026-07-29

## AC Status

- [x] AC-1: migrator item 17 split (long line eliminated) — PASS
- [x] AC-2: doctor HEAD check downgrade WARN — PASS
- [x] AC-3: engine migrate regenerates ENGINE_DOCTOR.md — PASS
- [x] AC-4: engine doctor 0 WARN (long line) — PASS
- [x] AC-5: doctor 'legacy card' WARN for HEAD done cards — PASS
- [x] AC-6: check.sh CHECK PASSED — PASS
- [x] AC-7: VERSION bump 6.16.0 — PASS

## Key Changes

1. engine-migrate-contract.{sh,ps1}: item 17 template split from 2473-char single line to 7 lines (1 main + 6 markdown bullets), each <=800 chars. Fixes #20.
2. engine-doctor.{sh,ps1}: add HEAD check in check_task_card_done_evidence — if done card exists in HEAD (committed), downgrade FAIL to WARN for AC evidence drift. Fixes #19.
3. 4 plugin mirrors synced byte-identical.
4. manifest.json SHA256 recalculated (62 entries).
5. AGENTS.md / engine/SYSTEM.md / engine/ENGINE_DOCTOR.md managed blocks updated by migrator (contract-version 6.16.0).
