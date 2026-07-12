---
name: engine-decision-draft
description: Draft or update an Engine System decision ledger entry. Use when the user is choosing architecture, scope, protected path access, release strategy, agent behavior policy, migration policy, or any non-obvious option that should govern future task cards.
---

# Engine Decision Draft

Decisions are the architect's control surface. Draft them plainly enough for future agents and humans.

1. Load current context and inspect related decisions under `engine/decisions/D-*.md`.
2. Choose the next `D-NNN` id when creating a new decision.
3. Include status, scope, expiry, supersedes, and related decisions in the header.
4. State background, decision, alternatives rejected, consequences, verification hooks, and open questions.
5. If protected paths are involved, ensure the scope covers the exact paths future task cards need.
6. Leave status as `proposed` unless the user explicitly approved the decision.

Release portability check: decisions about engine behavior must say whether they affect only this repository or every installed project.
