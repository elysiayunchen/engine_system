# /engine-update — Session Handoff

You are updating the project's engine files at the end of a work session.

## Step 1: Read Current State (re-anchor before any write-back)
Use the Read tool to load — re-reading guards against stale context from a long session:
- `engine/ENGINE_MAP.md`  ← the index; read FIRST
- `engine/CONTEXT.md`
- `engine/HANDOFF.md`
- `engine/PITFALLS.md`
Also read the relevant SYSTEM sections for session end, Engine Doctor Contract, and engine
file maintenance. Record read-gate evidence in the final summary.
If `engine/ENGINE_DOCTOR.md` exists, read it so session updates preserve the current
maintenance contract.

When multiple agents are active, treat engine files as single-writer state: collect
inputs in parallel if needed, but only one agent may perform the final write-back to
`ENGINE_MAP.md`, `CONTEXT.md`, `HANDOFF.md`, `PITFALLS.md`, `SYSTEM.md`, `REPO_GUIDE.md`,
anchors, or plan/spec twins for this change set. Re-anchor target files before writing,
merge sibling-agent diffs first, then run `/engine-doctor` after the write-back if
maintenance files changed.

## Step 2: Ask Three Questions (one at a time, wait for answer each time)

1. "这次完成了什么？（一句话描述）"
2. "现在正在做 / 下一步准备做什么？"
3. "有没有新发现的坑、奇怪的行为、或者要提醒下一个 AI 的事？（没有就说『无』）"

## Step 3: Write Updates

### Update engine/CONTEXT.md
Edit the 状态面板 table in place:
- `上次完成` → answer from Q1
- `进行中` → answer from Q2, but preserve lane structure if multiple workstreams exist
- Update `构建` status if relevant info was mentioned

For long sessions, do not wait until the final turn: after each meaningful feature, fix,
or decision, perform this same minimal CONTEXT update and HANDOFF append immediately.
That incremental write-back is the A-layer contract for Web AI and the data that B/C-layer
hooks verify.

### Append to engine/HANDOFF.md
Add a new session entry at the TOP of the session history table (time-ordered):

```
| [today's date] | [Q1 answer] | [Q2 answer] | [files touched this session if known] |
```

If the project runs multiple workstreams, also capture the lane handoff summary:
- lane ID
- current owner
- merge point
- next checkpoint

### Append to engine/PITFALLS.md (only if Q3 has real content)
Record it as a FULL entry — match the structure `/engine-init` generates, not a bare row:

1. Append a structured entry to the **条目** section, using the next P-ID (current max
   across the 索引 table and 条目 section, + 1, zero-padded to three digits):
   ```
   ### P00X — [标题]
   - **严重程度：** [🔴 CRITICAL / 🟠 HIGH / 🟡 MEDIUM / 🔵 INFO — infer from impact; ask if unclear]
   - **类别：** [tooling / deps / arch / api / config / data / testing / security]
   - **状态：** Active
   - **你能观察到的现象：** [from Q3]
   - **根因：** [if known, else TBD]
   - **错误做法：** [if known, else TBD]
   - **正确做法：** [the fix / workaround, if known, else TBD]
   - **触发条件：** [command, file path, environment, user action, or TBD]
   - **影响范围：** [path / module / platform / agent type, or global/TBD]
   - **验证方式：** [smallest repeatable check that proves the pitfall is avoided]
   - **发现时间：** [today's date]
   ```
2. Append the matching row to the **索引** table:
   `| P00X | [严重程度] | [标题] | [类别] | Active |`
3. Bump the header 条目计数 and set its `Last updated` to today.

### Update engine/ENGINE_MAP.md (the index — MUST NOT be skipped)
The session ended, so the map's freshness metadata is now stale. You already re-anchored it
in Step 1; now write back (metadata only — NEVER copy any file's body into the map):
- **§1 文件注册表** — set `Last verified` = today's date for every file you touched this
  session (CONTEXT, HANDOFF, and PITFALLS if a pitfall was added). If a pitfall was added,
  also bump PITFALLS' per-file `Revision`.
- **§4 完整性与新鲜度** — bump `全局 revision` by 1.
- **§4 完整性与新鲜度** — keep it to short freshness metadata, warning pointers, and
  revision only; long session prose belongs in HANDOFF.
- **Header** — set `Last updated` = today's date and mirror the new revision into `Revision:`.

### Sync header dates
Every engine file you wrote above MUST have its header `Last updated` date set to today.

### Run Doctor if maintenance files changed
If this session touched `ENGINE_MAP.md`, `SYSTEM.md`, `REPO_GUIDE.md`, `ENGINE_DOCTOR.md`,
`engine/agents/*`, anchors, plans, or any engine registration row, run `/engine-doctor`
before final confirmation. If Doctor scripts are missing, note that `/engine-sync` is
required.

If `engine/.cache/pending.txt` exists, read it before confirming. It contains the latest
SessionEnd Doctor result cached by the hook; resolve it with `/engine-doctor` or
`/engine-reconcile`, then delete the pending note only after the issue is no longer true.

## Step 4: Confirm
Output the change summary (for the architect's review), then the resume pointer:
```
## 引擎文件变更摘要
| 文件 | 变更类型 | 变更内容 |
|------|---------|---------|
| CONTEXT.md    | 修改 | 状态面板：上次完成 / 进行中 |
| HANDOFF.md    | 追加 | 新会话交接行 |
| PITFALLS.md   | 追加 | [P00X：一句话]  ← 仅当记录了坑 |
| ENGINE_MAP.md | 修改 | §1 Last verified + §4 全局 revision → [新值] |

read-gate: ENGINE_MAP, SYSTEM 会话结束/维护/Doctor, CONTEXT, HANDOFF, PITFALLS
doctor: [not needed / passed / failed / missing scripts]
引擎同步完成。下次会话直接继续：[Q2 answer]
```
