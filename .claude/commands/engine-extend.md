# /engine-extend — Register a New Engine Authority File (EXTEND mode)

Use this when the project already has `engine/ENGINE_MAP.md` and the architect wants to
add a new authoritative engine file type, such as `DESIGN_SYSTEM.md`,
`API_CONTRACT.md`, `REPO_GUIDE.md`, or `engine/agents/CODEX.md`.

Do **not** use this for normal feature plans. Plans go through `/engine-ingest`.
Renames, moves, splits, merges, archives, deletes, and scope-externalization are lifecycle
transactions; handle them with the same transaction rules below instead of creating a
duplicate "new version" file.

## CLI execution context
- You are Claude Code with disk access. Operate files directly with Read / Write / Edit.
- Talk to the architect in 简体中文.
- NEVER dump engine file bodies into the conversation.
- Every EXTEND run MUST begin by reading `engine/ENGINE_MAP.md` and end by updating
  `ENGINE_MAP.md` §4 plus a short change summary.
- Re-anchor before write-back: re-read every target file from disk before editing it.
- Engine Doctor is part of the maintenance lifecycle. Read `engine/ENGINE_DOCTOR.md` when
  present and run Doctor after registration changes.

## Step 1: Read ENGINE_MAP + maintenance rules
Read `engine/ENGINE_MAP.md` first. Extract:
- Active profile
- §1 file registry
- §1.1 mixed section registry
- §1.2 anchor registry
- §4 integrity/freshness

Then perform the read-gate for this write set:
- Read `engine/SYSTEM.md` sections for `Engine Doctor Contract`, `引擎文件维护协议`, and
  dangerous/approval rules.
- Read `engine/ENGINE_DOCTOR.md` if present. It is the authority for validation checks.
- Read `engine/REPO_GUIDE.md` engine-maintenance section if it exists.
- Read relevant anchors or plan/spec files if the new authority file links to them.

Report one line before writing:
`read-gate: ENGINE_MAP §0/§1/§1.1/§1.2/§4, SYSTEM <sections>, <anchors/plans if any>`

## Step 2: Classify before writing
Confirm with the architect:
- Purpose of the new object
- Authority class: `irreducible`, `derivable`, `mixed`, `index`, `anchor`, or
  `generated-cache`
- Read priority
- File budget
- Owner/updater
- Whether it is truly EXTEND or belongs elsewhere

Routing rules:
- Authority `engine/*.md` or `engine/agents/[ENV].md` → EXTEND, register in §1.
- Mixed authority file → also register section classes in §1.1.
- Root/agent/package anchor → register in §1.2 only, not §1.
- Plan + spec twin → stop and use `/engine-ingest`.
- Disposable generated snapshot → write under `engine/.cache/*.generated.md`, mark
  `generated-cache`, and do not register as authority.
- Archive/bootstrap/external scratch file → do not register unless the architect explicitly
  scopes it into this project's engine.

## Step 3: Generate the skeleton
Create the new file with only the minimum useful structure:
- Follow the language strategy used by the existing engine files.
- Add insertion rules for any appendable tables/lists.
- In CLI-LEAN, `derivable` content MUST be a pure stub with regeneration recipes only.
  NEVER paste live file inventories, directory trees, version numbers, module counts, or
  concrete config values.
- Keep within the chosen budget. Overflow irreducible history goes to `engine/archive/`
  with a pointer, never silent deletion.

## Step 4: Register and link
Update the correct registry in `ENGINE_MAP.md`:
- §1: add the authority file row with File / Class / Read priority / Revision / Last verified.
- §1.1: add section classes if the file is `mixed`.
- §1.2: update bootloader or anchor pointers if an environment adapter or anchor is involved.
- §4: bump global revision and record the structural change as a short status/pointer.
- If the new object changes maintenance semantics, update `ENGINE_DOCTOR.md` first, then
  the scripts. Do not leave Doctor as an old hard-coded checker.

When linking to SYSTEM/PITFALLS/ARCHITECTURE/plans, use only paths, IDs, sections, or
spec/evidence refs. NEVER copy body text into ENGINE_MAP.

## Step 5: Validate lifecycle closure
Run `/engine-doctor` or the bundled script:
- macOS/Linux: `./engine/scripts/engine-doctor.sh`
- Windows: `.\engine\scripts\engine-doctor.ps1`

If scripts are missing, run `/engine-sync` to restore bundled tooling. If sync is not
available, manually follow `engine/ENGINE_DOCTOR.md`.

Check at minimum:
- Registry → disk: every registered path exists or is explicitly archived/superseded.
- Disk → registry: every authority-looking `engine/*.md` and `engine/agents/*.md` file is
  registered, archived, generated-cache, or explicitly external.
- Class is legal and matches profile behavior.
- Mixed section registry exists when needed.
- Bootloader and package anchors are not misregistered in §1.
- Plans/spec twins are not misregistered in §1.
- CLI-LEAN derivable stubs are uncontaminated.
- Budgets are respected or archived with pointers.
- No stale paths, dangling refs, or half-finished rename/split/archive/delete remain.

## Step 6: Close
Output a concise Chinese summary:
```
## EXTEND 变更摘要
| 文件 | 变更类型 | 变更内容 |
|------|----------|----------|
| [new file] | 新增 | [purpose/class/priority] |
| ENGINE_MAP.md | 修改 | §1/§1.1/§1.2 + §4 revision → [new rev] |

read-gate: [files/sections read]
validation: [doctor command or manual checklist result]
```

If classification shows the object is not EXTEND, say which route applies and stop before
writing.
