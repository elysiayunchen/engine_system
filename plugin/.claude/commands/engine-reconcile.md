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

## Step 1: Read ENGINE_MAP first (re-anchor, before anything)
Use the Read tool on `engine/ENGINE_MAP.md`. Note the **active profile** — it decides
whether you trust derivable files on disk (WEB-FULL) or regenerate them from code
(CLI-LEAN). Everything below is checked against this map.

## Step 2: Check the file registry (§1)
- Does every engine file listed in §1 actually exist on disk?
- Any engine file on disk that is NOT registered? Flag it.
- Do the revisions line up with reality?

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

## Step 5: Check drift (derivable claims vs real code)
Where a derivable file asserts a fact about the code (e.g. "SOURCEMAP says
`src/foo.ts` exists"), verify it. Mismatches (file moved, renamed, deleted; stack
changed) become **drift warnings** recorded in §4.

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

## Step 7: Update ENGINE_MAP §4 (Integrity & Freshness)
Write back: global revision, last-RECONCILE date, dangling refs, drift warnings.

## Step 8: Report (简体中文), then confirm before landing fixes
Output a reconciliation report:
```
## 对账报告 — [today's date]
- ✅ 一致项：[简述]
- ⚠️ 漂移项：[derivable 声明 vs 真实代码的不一致]
- 🔗 悬空引用：[§3 中指向已删除目标的引用，或「无」]
- ⚓ 锚点层：[引导器一致性 / 已吸收的用户手写规则 / 包锚点覆盖率]
- ✔️ 升为 done 的 plan：[PLAN-NN，或「无」]
- ❓ 需架构师决定：[需要你拍板的修正项]

确认后我落盘修正并更新 ENGINE_MAP。
```
Apply corrections only after the architect confirms.

---

> **Need a new *type* of engine file** (e.g. `DESIGN_SYSTEM.md`, `API_CONTRACT.md`)?
> That is EXTEND mode, not RECONCILE: confirm the new file's purpose + knowledge class
> (irreducible / derivable / mixed) + read priority with the architect, generate its
> skeleton, add one row to ENGINE_MAP §1 (and §1.1 if mixed), bump the revision.
> EXTEND never re-runs the interview — adding a file is just a registry row.
