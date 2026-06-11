# /add-pitfall — Record a Pitfall Immediately

Use this command right when you discover a bug, footgun, or unexpected behavior.
Don't wait until end of session — record it now before context is lost.

## Step 1: Ask (one message, all at once)
"快速记录一下这个坑：
1. 简短标题（一句话，问题是什么）？
2. 你能观察到的现象（怎么触发、看到什么）？
3. 根本原因（如果知道）？
4. 正确做法 / 绕过方法？
5. 严重程度：🔴 崩溃或数据损坏 / 🟠 难查的运行时错误 / 🟡 行为不对但能跑 / 🔵 仅造成困惑？
6. 类别：tooling / deps / arch / api / config / data / testing / security？"

If the user already described the pitfall before invoking this command, extract what they
gave and infer 严重程度 / 类别 from the impact — only ask back for fields you genuinely
cannot determine.

## Step 2: Read engine/PITFALLS.md (re-anchor)
Find the current maximum P-ID across the 索引 table and the 条目 section. Next ID = max + 1,
zero-padded to three digits (P001, P002, …).

## Step 3: Write to engine/PITFALLS.md — a FULL entry, not just a row
Match the structure `/engine-init` generates. Two writes plus a header bump:

1. Append a structured entry to the **条目** section:
   ```
   ### P00X — [标题]
   - **严重程度：** [🔴 CRITICAL / 🟠 HIGH / 🟡 MEDIUM / 🔵 INFO]
   - **类别：** [tooling / deps / arch / api / config / data / testing / security]
   - **状态：** Active
   - **你能观察到的现象：** [Q2]
   - **根因：** [Q3, or TBD]
   - **错误做法：** [what triggers it, if known, else TBD]
   - **正确做法：** [Q4]
   - **发现时间：** [today's date]
   ```
2. Append the matching row to the **索引** table:
   `| P00X | [严重程度] | [标题] | [类别] | Active |`
3. Bump the header 条目计数 and set its `Last updated` to today.

**Insertion rules:** append only — never reorder existing entries. Status starts as
`Active` (not "Open"); a fixed pitfall later becomes `Resolved`, never deleted.

## Step 4: Confirm
Output:
```
✓ engine/PITFALLS.md updated — [P00X] [严重程度] added: [标题]
```
