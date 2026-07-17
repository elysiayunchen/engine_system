---
name: engine-scout
description: Scout an Engine System codebase or change area before implementation. Use when the task needs investigation, parallel reading, comparison across scripts, release/package impact checks, or a concise findings summary without dumping raw file contents into the main context.
---

# Engine Scout

Use this when the work is still blurry. Keep the result small enough to guide implementation.

1. Load engine context, identify the governing task, and create `engine workstream T-NNN <agent-id>` before any parallel worker writes notes.
2. Read only the files needed for the candidate paths. Prefer fast search, manifests, tests, and existing task evidence over broad copying.
3. Compare source and distribution surfaces together: root source, `plugin/` package copy, installers, manifest, tests, and migration/update path.
4. Return findings as facts, risks, and recommended next action. Include file paths and verification commands.
5. Do not make edits unless the user or active task card asks for implementation.

Release portability check: every proposed runtime change must name how it reaches a fresh external project.
