# /engine-doctor — Validate Engine File Health

Run this when you need a machine-readable health check for the engine memory layer. It
does not replace `/engine-reconcile`; it gives RECONCILE a concrete validation signal.

## Routine
1. Read `engine/ENGINE_MAP.md` first.
2. Read `engine/ENGINE_DOCTOR.md` if present. It is the authority for what Doctor checks.
3. Run the bundled script:
   - macOS/Linux: `./engine/scripts/engine-doctor.sh`
   - Windows: `.\engine\scripts\engine-doctor.ps1`
4. If scripts are missing, do not invent a different standard. Use `/engine-sync` to
   restore bundled tooling, then rerun Doctor. If sync is impossible, manually follow
   `ENGINE_DOCTOR.md`.
5. Report the result in 简体中文:
   - failure count
   - warning count
   - highest-impact failures
   - whether `/engine-reconcile` or `/engine-extend` is the right next action

## Important
- Doctor is registry-driven. New engine authority files should be discovered from
  `ENGINE_MAP.md` §1, not from a hard-coded script list.
- If Doctor misses a new extension type, update `engine/ENGINE_DOCTOR.md` first, then the
  scripts, then run `/engine-sync`.
- Do not auto-fix engine files from Doctor output alone; use `/engine-reconcile` for
  confirmed repair, or `/engine-extend` for missing authority registration.
