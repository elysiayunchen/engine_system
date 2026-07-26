# Engine System Glossary

> Agent: when explaining engine concepts to the developer, use the "Plain meaning" column.
> Match the developer's language — do not hardcode any specific language.

## Core Terms (engine-managed)

<!-- The terms below are maintained by the engine system. Do not edit manually. -->

| Engine term | Plain meaning | Example |
|-------------|--------------|---------|
| Engine file | A project memory file that the AI reads/writes to stay oriented | ENGINE_MAP.md, CONTEXT.md |
| ENGINE_MAP | The table of contents for all engine files — read this first each session | Like a book's index |
| CONTEXT | Current project status dashboard — what's happening right now | Like a morning briefing |
| HANDOFF | Session handoff notes — where we left off and what to do next | Like a relay baton |
| Task card (T-NNN) | A structured work item with clear scope, acceptance criteria, and constraints | Like a Jira ticket |
| Decision (D-NNN) | A recorded non-obvious choice with rationale and scope | Like an ADR (architecture decision record) |
| Change capsule | A human-readable summary of what was changed and why | Like a detailed commit message |
| Federation table | A routing map that groups project files into domains for context management | Like folders with smart labels |
| Doctor | Health check that validates engine file consistency | Like a linter for project memory |
| Write-back | Updating engine files after making code changes | Like updating meeting notes after a meeting |
| Gate / Hook | Automatic checks that run before/after actions to prevent mistakes | Like a spell-checker that runs before you send |
| Contract | The set of rules governing how engine files work together | Like a team's working agreement |
| Pitfall | A documented mistake to avoid repeating | Like a "lessons learned" entry |
| Plan / Spec | A design document (plan) paired with its technical specification (spec) | Like a blueprint + engineering drawing |
| reconcile | Comparing engine memory against actual code and fixing any drift | Like proofreading a document against the source |
| Irreducible | Knowledge that can't be regenerated from code — must be preserved | Decisions, rationale, lessons learned |
| Derivable | Knowledge that can be regenerated from code on demand | File listings, module maps |
| Union gating (v6.12.0) | A file write is allowed when ANY active task card covers it (in that card's WRITE-SET, outside that card's FORBIDDEN) | Like several room keys — any one that fits opens the door |
| Coordinator lease (v6.12.0) | The right to write shared memory, held via `engine/.cache/session.lock` and kept alive by heartbeat; expires after ENGINE_SESSION_TTL_MIN (default 120min) of silence | Like a library study-room booking that lapses if you leave |
| Heartbeat (.hb) | A timestamp file each session refreshes on every tool call, proving it is still alive | Like tapping your badge so the lights stay on |

## Project Terms (developer-managed)

<!-- Add project-specific terms below. This section is preserved across engine upgrades. -->

| Term | Plain meaning | Added by |
|------|--------------|----------|
| Scaling ceremony | Project-chosen extra structure (freeze lists, multi-role review, FU tracking) beyond the engine's minimum task card format; useful at scale but not engine-mandated | Trial feedback 2026-07-22 |
