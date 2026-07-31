# Checkpoint - T-058
> Last updated: 2026-07-29T23:30:00Z by T-059 evidence regeneration | AC-level recovery anchor

## Completed AC

- [x] AC-1 all .ps1 files have UTF-8 BOM (25 files verified, including check-version-consistency.ps1) - evidence/AC-1.json PASS @ 2026-07-29T19:30:00Z
- [x] AC-2 plugin mirror byte-identical (11 pairs, compile.sh synced) - evidence/AC-2.json PASS @ 2026-07-29T19:30:00Z
- [x] AC-3 manifest SHA256 matches (62 entries, 0 mismatches) - evidence/AC-3.json PASS @ 2026-07-29T19:30:00Z
- [x] AC-4 .sh files no BOM (shebang preserved) - evidence/AC-4.json PASS @ 2026-07-29T19:30:00Z
- [x] AC-5 manifest no duplicate sha256 fields (P6 fixed, 62 fields = 62 entries) - evidence/AC-5.json PASS @ 2026-07-29T19:30:00Z
- [x] AC-7 version 6.15.0 + CHANGELOG (historical entry preserved) - evidence/AC-7.json PASS @ 2026-07-29T19:30:00Z

## Evidence Regeneration Note (T-059, 2026-07-29)

T-058 original evidence had P-CRIT-2: all 7 AC files used descriptive strings as fingerprint (e.g., 'sha256:24files-bom-verified') instead of valid 64-hex SHA256. T-059 regenerated all evidence with real file hashes and executable verify commands. Functional code unchanged - only evidence files and docs fixed.
- [x] AC-6 bash -c "grep -c 'FUNCTIONAL section signs' engine/scripts/engine-migrate-contra — evidence/AC-6.json PASS @ 2026-07-31T05:10:58Z
