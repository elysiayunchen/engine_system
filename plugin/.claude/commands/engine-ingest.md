# /engine-ingest — Record a New Plan (INGEST mode)

Use this when the architect drops in or dictates a fresh design intent and you need
to file it as a plan, give it a verifiable spec twin, and fan its deltas out into
the execution-layer engine files.

## CLI execution context (read first)
- You are Claude Code with disk access. Operate the engine files directly with the
  **Read / Write / Edit** tools — there is no human copy-pasting between you and disk.
- Talk to the architect in 简体中文. Confirm before you write anything irreversible.
- NEVER dump engine file bodies into the conversation. Read them silently, report only
  the human-readable deltas you intend to write.
- Engine files live under `engine/`; plans live under `engine/plans/`.
- This is an operational mode: it MUST begin by reading ENGINE_MAP and end by updating
  ENGINE_MAP + a change summary. Re-anchor (re-read from disk) before any write-back.

## Step 1: Read ENGINE_MAP (re-anchor, before anything)
Use the Read tool on `engine/ENGINE_MAP.md`. Extract:
- **profile** (WEB-FULL / CLI-LEAN)
- the **highest existing plan ID** → the new plan is `PLAN-NN` (max + 1, zero-padded)
- the **relationship graph** (§3) so you know what already derives from which plan

## Step 2: Write the plan body (free-form, DO NOT restructure)
Save the architect's raw design intent verbatim to `engine/plans/PLAN-NN.md`.
- The body is **100% free**: prose, dialogue, sketches, any structure. NO template.
- **NEVER rewrite, summarize, or structure the body.** Preserve it as given.
- Auto-stamp this identity header at the very top (the architect never maintains it):
```
<!-- PLAN-NN | [标题] | status: proposed | source: [对话/上传文档] | created: [today's date] -->
```

## Step 3: Create the spec twin
Discuss with the architect「怎么算做成了」, then write the acceptance criteria to
`engine/plans/PLAN-NN.spec.md` (shared stem — the twin relationship is visible in the
filename; it shares PLAN-NN's lifecycle and ID):
```
# SPEC TWIN — PLAN-NN: [标题]
> 与 engine/plans/PLAN-NN.md 并列共生 | status follows PLAN-NN

## 验收标准 (Acceptance Criteria)
| ID | 标准（用户可见行为） | 验证方式 | 状态 |
|----|----------------------|----------|------|
| AC-1 | [做完后用户能做/看到什么] | [测试命令 / 可观察行为 / 人工检查] | [ ] 未验证 |
| AC-2 | ... | ... | [ ] 未验证 |
```

## Step 4: Extract deltas (confirmation gate — MUST confirm before writing)
From the plan + discussion, extract the increments that belong in the execution layer.
Each delta MUST carry a `← PLAN-NN` provenance tag:
- **ROADMAP** — new milestone / backlog item
- **SPRINT** — new task. 「完成标准」inline; 「验证方法」is a **pointer**, written as
  `verify → PLAN-NN.spec:AC-x` — NEVER restate the criterion.
- **SYSTEM** — new pause point / dangerous command / constraint
- **PITFALLS** — risks the plan already flags (next available P-ID)
- **Anchor layer** — for each code package the plan touches, append a `PLAN-NN`
  reference into that package README anchor's pointer区.

**MUST list the extracted deltas to the architect in plain 简体中文 and get confirmation
BEFORE writing them to disk.** Free input + confirmed output — neither end sacrificed.
After confirmation, re-anchor each target file (re-read) and write the deltas.

## Step 5: Register in ENGINE_MAP
- **§2** — add a row: plan + twin + status (`proposed`, or `active` if Step 6 applies).
- **§3.1** — add a row: derived entries / linked AC IDs / touched modules.

## Step 6: Set status if already in flight
If the plan has already begun implementation, set its §2 status to `active`.

## Step 7: Bump revision + summarize
Bump the global revision in ENGINE_MAP §4, then output:
```
✓ engine/plans/PLAN-NN.md created (status: proposed)
✓ engine/plans/PLAN-NN.spec.md created — [N] AC defined
✓ ROADMAP / SPRINT / SYSTEM / PITFALLS updated  ← list only the files actually touched
✓ engine/ENGINE_MAP.md updated — §2 + §3.1 registered, revision → [new rev]

PLAN-NN 已录入。下一步：[active 则写当前任务，否则写「等待排期实施」]
```
