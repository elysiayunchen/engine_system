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
   - Preferred terminal path for existing projects: run `engine update` from the project root.
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
   - `engine/scripts/engine-hook-session-start.sh`
   - `engine/scripts/engine-hook-session-start.ps1`
   - `engine/scripts/engine-hook-stop.sh`
   - `engine/scripts/engine-hook-stop.ps1`
   - `engine/scripts/engine-hook-session-end.sh`
   - `engine/scripts/engine-hook-session-end.ps1`
   - `engine/scripts/engine-sync-agent-anchors.sh`
   - `engine/scripts/engine-sync-agent-anchors.ps1`
   - `engine/bin/engine`
   - `engine/bin/engine.ps1`
   - `engine/bin/engine.cmd`
5. Register or migrate maintenance authority without overwriting project memory:
   - If `ENGINE_DOCTOR.md` is missing from ENGINE_MAP §1, add it as `irreducible` with
     read priority after SYSTEM/REPO_GUIDE.
   - Add or update SYSTEM / REPO_GUIDE pointers so Engine Doctor is part of the required
     maintenance flow after engine edits.
   - Do not copy the whole Doctor body into ENGINE_MAP; register path/class/priority only.
6. Apply the current Engine System contract migrations to existing engine files. This is
   the step that upgrades old projects; do not skip it just because tooling files updated:
   - Run the bundled contract migrator first:
     - macOS/Linux: `./engine/scripts/engine-migrate-contract.sh`
     - Windows: `.\engine\scripts\engine-migrate-contract.ps1`
   - The migrator writes managed, idempotent blocks into `AGENTS.md`, `engine/SYSTEM.md`,
     and `engine/ENGINE_DOCTOR.md`, and creates a migration capsule under
     `engine/changes/`.
   - Then inspect the result and fold any project-specific wording into the right authority
     file if needed.
   - **v5.5 registration closure**: ensure ENGINE_MAP records authority files, anchors,
     plans/spec twins, generated-cache, archive, and scripts in the correct places.
   - **v5.5.2 multi-lane workstreams**: ensure SYSTEM or AGENTS session rules say
     `CONTEXT.md`, `SPRINT.md`, `ROADMAP.md`, and `HANDOFF.md` may carry lane IDs, owners,
     dependencies, merge points, and next checkpoints. Preserve any existing single-lane
     content; add lane support as an additive rule.
   - **v5.6 self-maintenance loop**: ensure SYSTEM/AGENTS mention incremental write-back,
     SessionStart/Stop/SessionEnd hooks, git pre-commit fallback, and single-writer shared
     engine-file merges.
   - **v5.7 architect self-view**: ensure SYSTEM/AGENTS and command guidance require
     `engine/changes/CHANGE-*.md` capsules for meaningful changes, and `/engine-status`
     surfaces Project Self-View.
   - **v5.7 acceptance evidence**: ensure plan/spec rules say `done` requires evidence in
     the spec twin Evidence column, `engine/evidence/*`, or a relevant change capsule.
   - **Doctor contract parity**: ensure `engine/ENGINE_DOCTOR.md` includes checks for
     semantic hot-path files, change capsule completeness, and done-plan evidence.
   - **ENGINE_MAP freshness**: bump global revision, update Last verified for touched files,
     and record the migration summary in §4. Keep long migration notes in HANDOFF or a
     change capsule, not in ENGINE_MAP.
   Treat missing files as optional by scale/profile: if a project never had ROADMAP or
   SPRINT, add the rule to SYSTEM/AGENTS rather than inventing empty authority files.
7. When migrating an old project, create one change capsule for the migration itself:
   `engine/changes/CHANGE-[today]-[nn].md`. It should explain what contract mechanisms were
   added, which files were touched, which old project memory was preserved, Doctor result,
   rollback path, and any architect decision left open.
8. Sync cross-agent bootloaders when the project uses those tools, preserving user content
   outside the managed Engine System block:
   - macOS/Linux: `./engine/scripts/engine-sync-agent-anchors.sh`
   - Windows: `.\engine\scripts\engine-sync-agent-anchors.ps1`
   - Generated targets include `.github/copilot-instructions.md`, `.cursor/rules/engine.md`,
     `GEMINI.md`, `.clinerules`, `.roorules`, and an Aider starter config when absent.
9. Ensure Claude Code hooks include SessionStart plus both Stop commands:
   - `engine-hook-stop.*` is the write-back gatekeeper.
   - `engine-hook-session-end.*` runs Doctor and caches warnings in `engine/.cache/pending.txt`.
   - If `.claude/settings.json` already existed and install preserved it, merge these hook
     entries instead of overwriting the user's settings.
10. Run `/engine-doctor`.
11. Run `/engine-reconcile` logic to compare project content against engine files and the
   latest Doctor contract. Confirm before landing repairs.
12. End with a concise summary:
   - plugin/tooling files updated
   - cross-agent anchors synced or intentionally skipped
   - maintenance authority registered/migrated
   - old-project contract migrations applied: registration closure / multi-lane /
     self-maintenance / change capsules / acceptance evidence / Doctor parity
   - Doctor failures/warnings
   - migration change capsule path
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
- For existing projects, prefer additive sections titled `Engine System contract migrations`
  or `Upgrade notes` over rewriting the user's project-specific SYSTEM/PITFALLS/ARCHITECTURE
  prose.
- Scripts under `engine/scripts/` are replaceable tooling; `engine/ENGINE_DOCTOR.md` is the
  authority that keeps those scripts from becoming stale.
