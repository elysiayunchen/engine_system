# /engine-sync — Update Engine System Tooling and Sync Engine Files

Use this when the Engine System repository/plugin has been updated and this project should
receive the new maintenance commands, scripts, and engine-file contract without losing its
project-specific memory.

This is not `/engine-update`. `/engine-update` records session state. `/engine-sync`
updates the Engine System layer itself, then reconciles the local engine files.

## Routine
1. Read `engine/ENGINE_MAP.md` first. If it is missing, run `/engine-init` instead.
2. Read `engine/SYSTEM.md`, `engine/REPO_GUIDE.md` if present, and
   `engine/ENGINE_DOCTOR.md` if present.
3. Update bundled Engine System tooling:
   - If this project has `install.sh`, run `bash install.sh --update`.
   - If this project has `install.ps1`, run `.\install.ps1 -Update`.
   - If neither exists, fetch the latest installer from
     `https://raw.githubusercontent.com/elysiayunchen/engine_system/main/` and run its
     update mode for this project.
4. Ensure these installed files exist:
   - `.claude/commands/engine-doctor.md`
   - `.claude/commands/engine-sync.md`
   - `engine/ENGINE_DOCTOR.md`
   - `engine/scripts/engine-doctor.sh`
   - `engine/scripts/engine-doctor.ps1`
5. Register or migrate maintenance authority without overwriting project memory:
   - If `ENGINE_DOCTOR.md` is missing from ENGINE_MAP §1, add it as `irreducible` with
     read priority after SYSTEM/REPO_GUIDE.
   - Add or update SYSTEM / REPO_GUIDE pointers so Engine Doctor is part of the required
     maintenance flow after engine edits.
   - Do not copy the whole Doctor body into ENGINE_MAP; register path/class/priority only.
6. Run `/engine-doctor`.
7. Run `/engine-reconcile` logic to compare project content against engine files and the
   latest Doctor contract. Confirm before landing repairs.
8. End with a concise summary:
   - plugin/tooling files updated
   - maintenance authority registered/migrated
   - Doctor failures/warnings
  - engine files changed
  - next recommended command

During multi-agent work, `/engine-sync` is the merge point, not a parallel write path.
Treat shared engine files as single-writer state: gather evidence in parallel if useful,
then let one agent re-anchor, merge, write, and run Doctor after the write-back.

## Safety
- Never overwrite existing `engine/*.md` project memory just because the plugin template
  changed.
- Treat template changes as migrations: read current files, preserve irreducible content,
  add new required sections/pointers, and bump ENGINE_MAP revision.
- Scripts under `engine/scripts/` are replaceable tooling; `engine/ENGINE_DOCTOR.md` is the
  authority that keeps those scripts from becoming stale.
