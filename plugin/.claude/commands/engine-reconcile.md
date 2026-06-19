# /engine-reconcile — Audit Docs vs Reality (RECONCILE mode)

Run this when the architect says「更新引擎」/「对账」, when you suspect the engine
files have drifted from the real code, or as a routine check after a long multi-step
session. This is the answer to "is the documentation still true?".

## CLI execution context (read first)
- You are Claude Code with disk access. Operate the engine files directly with the
  **Read / Write / Edit** tools.
- Talk to the architect in 简体中文. Confirm before writing any correction.
- NEVER dump engine file bodies into the conversation. Read them silently, report only
  the human-readable reconciliation result.
- Engine files live under `engine/`; plans live under `engine/plans/`; anchor files
  (`CLAUDE.md`, `AGENTS.md`, package `README.md`) live at their conventional code
  locations, NOT under `engine/`.
- This is an operational mode: it MUST begin by reading ENGINE_MAP and end by updating
  ENGINE_MAP §4 + a change summary. Re-anchor (re-read from disk) before any write-back.
- v5.5 rules apply: audit read-gate evidence, complete registration routing, lifecycle
  transaction closure, derivable stub purity, file budgets, and evidence placement.
- Engine Doctor is the machine-check contract. Read `engine/ENGINE_DOCTOR.md` if present
  and run the bundled Doctor script before finalizing the report.

In multi-agent sessions, reconcile as a single writer only. Other agents may prepare
parallel evidence, but only one agent may land shared engine-file edits after re-anchoring
the target files and merging sibling diffs.

## Step 1: Read ENGINE_MAP first (re-anchor, before anything)
Use the Read tool on `engine/ENGINE_MAP.md`. Note the **active profile** — it decides
whether you trust derivable files on disk (WEB-FULL) or regenerate them from code
(CLI-LEAN). Everything below is checked against this map.
Also read §0 / §1 / §1.1 / §1.2 / §2 / §3 / §4 and the SYSTEM sections for Engine Doctor
Contract + engine file maintenance. Record:
`read-gate: ENGINE_MAP §0/§1/§1.1/§1.2/§2/§3/§4, SYSTEM <sections>`
If `engine/ENGINE_DOCTOR.md` exists, read it and include it in the read-gate evidence.

## Step 2: Check the file registry (§1)
- Does every engine file listed in §1 actually exist on disk?
- Any engine file on disk that is NOT registered? Flag it.
- Do the revisions line up with reality?
- Validate complete registration routing:
  - authority `engine/*.md` and `engine/agents/[ENV].md` belong in §1;
  - mixed files also need §1.1 coverage;
  - root/agent/package anchors belong in §1.2 only;
  - plans/spec twins belong in §2 only;
  - `engine/.cache/*.generated.md`, `engine/archive/*`, and external/bootstrap files are
    not misregistered as authority.
- Validate lifecycle transactions: no stale rows, old paths, dangling pointers, or
  half-finished rename/move/split/merge/archive/delete/scope-externalize operations.
- Check bidirectionally: Registry → disk and disk → registry.

## Step 3: Check the linkage graph (§3)
- For every `plan → entry` reference in §3.1, confirm the target still exists
  (e.g. the SPRINT task, the PITFALLS ID). A reference to something deleted is a
  **dangling ref** — list it.
- **Regenerate §3.2** (the reverse index, entry → source plan) from §3.1.
  NEVER hand-maintain §3.2; it is always generated here.

## Step 4: Check acceptance (spec twins)
For each `active` plan, take its spec twin's acceptance criteria (AC) and judge each
against reality:
- **CLI-LEAN** — read the code directly / run the AC's verification command. While you
  are there, regenerate the derivable content (SOURCEMAP, ARCHITECTURE's derivable
  sections) and compare against the on-disk stub.
- **WEB-FULL** — give the architect a safe read-only command to run, or judge from
  known information.

A plan whose AC are **all ✅** may be promoted to `done` in §2 (record the date).
Plan statuses in §2 must be only: `draft / proposed / accepted / active / blocked / done /
archived / superseded`. Longer notes go in 备注, not as invented statuses.

## Step 5: Check drift (derivable claims vs real code)
Where a derivable file asserts a fact about the code (e.g. "SOURCEMAP says
`src/foo.ts` exists"), verify it. Mismatches (file moved, renamed, deleted; stack
changed) become **drift warnings** recorded in §4.
In CLI-LEAN, a derivable body containing live file inventories, directory trees, version
numbers, module counts, or concrete config values is `stub contamination`; migrate it to a
disposable generated cache or remove it, leaving only recipes.

## Step 6: Check the anchor layer (§1.2)
- **Bootloaders** (`CLAUDE.md` / `AGENTS.md`): do they still point to
  `engine/ENGINE_MAP.md` first? Is `CLAUDE.md` consistent with the canonical
  `AGENTS.md`? Have the TOP RULES excerpts drifted from `engine/SYSTEM.md`?
- **Absorb-then-point**: if the architect hand-wrote new rules directly into
  `CLAUDE.md` / `AGENTS.md` that are NOT yet in the engine files, you MUST absorb them
  into the right engine file (SYSTEM / PITFALLS) first, THEN restore the bootloader to
  a thin pointer. NEVER delete a user's hand-written rule without absorbing it.
- **Package anchors**: does each package README's「关键文件」table still match the real
  package? Coverage — any new package past the anchor trigger threshold missing an
  anchor? Any orphan anchor registered for a deleted package?
- Bootloaders should stay within budget: target ≤30 lines, hard cap 45. If environment
  details exceed ~10 lines, externalize them into `engine/agents/[ENV].md` and register it
  in §1.

## Step 6.5: Check budgets and Doctor Contract
- Check file budgets from v5.5. Over-budget active files need archive pointers or a split;
  never silently delete irreducible history.
- Run `/engine-doctor` or the bundled script:
  - macOS/Linux: `./engine/scripts/engine-doctor.sh`
  - Windows: `.\engine\scripts\engine-doctor.ps1`
- If scripts are missing, run `/engine-sync` to restore them. If sync is impossible,
  manually follow `engine/ENGINE_DOCTOR.md`.
- If Doctor itself is missing or unregistered, treat that as a maintenance drift item:
  register `ENGINE_DOCTOR.md` in §1 and add/restore scripts through `/engine-sync`.

## Step 7: Update ENGINE_MAP §4 (Integrity & Freshness)
Write back: global revision, last-RECONCILE date, dangling refs, drift warnings.
Keep §4 short: status, warnings, and pointers only. Long evidence belongs in spec twins or
`engine/evidence/*`.

## Step 8: Report (简体中文), then confirm before landing fixes
Output a reconciliation report:
```
## 对账报告 — [today's date]
- ✅ 一致项：[简述]
- ⚠️ 漂移项：[derivable 声明 vs 真实代码的不一致]
- 🧭 Read-gate：[已读证据 / missing]
- 🧾 注册闭环：[partial registration / misregistered file / lifecycle incomplete / 无]
- 🧼 Stub purity：[污染项或无]
- 📏 文件预算：[超限项或无]
- 🩺 Doctor：[pass / fail / missing / unregistered]
- 🔗 悬空引用：[§3 中指向已删除目标的引用，或「无」]
- ⚓ 锚点层：[引导器一致性 / 已吸收的用户手写规则 / 包锚点覆盖率]
- ✔️ 升为 done 的 plan：[PLAN-NN，或「无」]
- ❓ 需架构师决定：[需要你拍板的修正项]

确认后我落盘修正并更新 ENGINE_MAP。
```
Apply corrections only after the architect confirms.

---

> **Need a new *type* of engine file** (e.g. `DESIGN_SYSTEM.md`, `API_CONTRACT.md`)?
> Use `/engine-extend`. EXTEND is a full registration transaction, not just "create file
> + add one row".
