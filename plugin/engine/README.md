# engine/ — your project's memory

This folder is the persistent memory layer created by
[Engine System](https://github.com/elysiayunchen/engine_system). The files here tell any
AI everything it needs to know about your project before it touches a line of code.

> **English** · [中文](./README.zh.md)

## What's in here

Right after install this folder is almost empty — just this README. Run `/engine-init`
in Claude Code (or paste `.claude/commands/engine-init.md` into a web AI) and the engine
files get written here:

| File              | What it holds                                                       |
| ----------------- | ------------------------------------------------------------------- |
| `ENGINE_MAP.md`   | The index. Read first every session — points the AI to what's next  |
| `CONTEXT.md`      | What's broken now, what's in progress, what's blocking you           |
| `SYSTEM.md`       | Your rules — what the AI must, should, and must never do             |
| `PITFALLS.md`     | The landmine registry. Every bug, footgun, and "never do this"       |
| `ARCHITECTURE.md` | Tech stack, directory map, data model, key decisions                 |
| `SPRINT.md`       | Active tasks and priorities in plain language                        |
| `ROADMAP.md`      | Milestones, planned features, future rewrites                        |
| `HANDOFF.md`      | Session history — pick up where you left off, weeks later            |
| `SOURCEMAP.md`    | Code GPS: which file owns which feature                              |
| `REPO_GUIDE.md`   | Optional repo commands and workflow rules                            |
| `ENGINE_DOCTOR.md`| Maintenance contract for engine health checks                        |
| `engine/agents/`  | Optional agent/tool-specific adapters                                |
| `scripts/`        | Bundled Doctor scripts                                               |
| `plans/`          | Design docs you talk through, each with an acceptance checklist      |

Exactly which files appear depends on the **profile** chosen at init: WEB-FULL writes
everything out; CLI-LEAN stores only what can't be rebuilt from your code and regenerates
the rest on demand.

## How to use it

- **Commit these files.** They're plain markdown — diff them, review them, read them yourself.
- **Don't hand-maintain the structure.** The AI keeps them in sync. You mostly just talk:
  "update status, I just finished login" → it edits `CONTEXT.md`.
- **Running several workstreams?** `CONTEXT.md`, `SPRINT.md`, `ROADMAP.md`, and `HANDOFF.md`
  can track multiple lanes at once instead of flattening them into one queue.
- **Hit a bug?** Say "记住，改 X 时别动 Y" and the AI files it into `PITFALLS.md`.
- **Running multiple agents?** Let them work in parallel on drafts or evidence, but
  keep shared engine-file writes single-writer and merge them once at the end.
- **End of a session?** Run `/engine-update` to sync state and write the handoff note.
- **Need a new memory type?** Run `/engine-extend` to register it completely.
- **Updating Engine System?** Run `/engine-sync`, then `/engine-doctor`.

Full docs: <https://github.com/elysiayunchen/engine_system>
