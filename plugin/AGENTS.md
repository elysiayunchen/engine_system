# Engine System — Agent Entry

> Powered by [Engine System](https://github.com/elysiayunchen/engine_system) (v6.5)
> Thin bootloader. Truth lives in `engine/`, indexed by `engine/ENGINE_MAP.md`.

## START

1. Read `engine/ENGINE_MAP.md`, follow §0, then run the routed read-gate.
2. Before edits, output `read-gate: ENGINE_MAP ✓, SYSTEM ✓, state: [一句话]`.
3. If ENGINE_MAP is absent, run `/engine-init`; non-Claude agents run `engine context`.

## EXECUTION

- One independently verifiable goal shares one task across prompts/workers; read-only work needs no card.
- All writes stay inside the active task WRITE-SET and outside FORBIDDEN; finish with `engine verify T-NNN`.
- Workers use `engine workstream T-NNN <agent-id>`; the coordinator alone merges shared CONTEXT/HANDOFF.

## POINTERS

- Rules: `engine/SYSTEM.md` · State: `engine/CONTEXT.md` · Handoff: `engine/HANDOFF.md`
- Commands: `/engine-update`, `/engine-status`, `/engine-doctor`, `/engine-sync`, `/engine-reconcile`
- CLI: `engine context|workstream|check-update|update|migrate|verify|doctor`
