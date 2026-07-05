# AGENT-NEUTRAL EXECUTION CONTEXT
> This prompt runs with ANY AI coding agent — Claude Code, Codex CLI, Copilot CLI,
> Cursor, Windsurf, or a web chat. The Engine System installer distributes it to the
> project as `engine/prompts/init.md`; run `engine init` in a terminal for usage guidance.

**Filesystem Rules (agent-neutral mode):**
- If you can write files directly (CLI/IDE agent): write engine files straight to disk at `engine/[FILENAME].md`, and do NOT echo file bodies into the conversation.
- If you cannot write files (web chat): output each file as one fenced code block labeled with its target path so the developer can save it verbatim.
- The index file `engine/ENGINE_MAP.md` is written FIRST, before any other engine file.
- Anchor files `CLAUDE.md` and `AGENTS.md` belong at the PROJECT ROOT, not `engine/`.
- Create the `engine/`, `engine/plans/`, `engine/archive/`, `engine/.cache/`, and `engine/scripts/` directories as needed.
- Confirmation after each write: `✓ Written: [path] ([word count] words)`
- Re-anchor: before writing back to any file you already created or edited this session, re-read it from disk.

---
