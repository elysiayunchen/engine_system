# CLAUDE CODE EXECUTION CONTEXT
> This command runs inside Claude Code with full filesystem access.
> Engine files are written directly to disk — do NOT output them to the conversation.

**Filesystem Rules (Claude Code mode):**
- ALWAYS use the Write tool to create files. Engine files go to `engine/[FILENAME].md`.
- The index file `engine/ENGINE_MAP.md` is written FIRST, before any other engine file.
- Anchor files `CLAUDE.md` and `AGENTS.md` are written to the PROJECT ROOT, not `engine/`.
- Create the `engine/`, `engine/plans/`, `engine/archive/`, `engine/.cache/`, and `engine/scripts/` directories as needed.
- Confirmation after each write: `✓ Written: [path] ([word count] words)`
- Do NOT output file contents as code blocks in the conversation. The developer reads from disk, not from chat.
- Re-anchor: before writing back to any file you already created or edited this session, re-read it from disk.

---
