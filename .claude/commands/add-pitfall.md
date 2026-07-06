# /add-pitfall — Record a Pitfall Immediately

Use this command right when you discover a bug, footgun, or unexpected behavior.
Don't wait until end of session — record it now before context is lost.

## Step 1: Ask (one message, all at once)
"快速记录一下这个坑：
1. 简短标题（一句话，问题是什么）？
2. 你能观察到的现象（怎么触发、看到什么）？
3. 根本原因（如果知道）？
4. 正确做法 / 绕过方法？
5. 触发条件（什么文件、命令、环境、用户操作会踩中）？
6. 影响范围（路径 / 模块 / 平台 / agent 类型；不知道就写全局或 TBD）？
7. 验证方式（以后怎么确认没有再踩中）？
8. 严重程度：🔴 崩溃或数据损坏 / 🟠 难查的运行时错误 / 🟡 行为不对但能跑 / 🔵 仅造成困惑？
9. 类别：tooling / deps / arch / api / config / data / testing / security？"

If the user already described the pitfall before invoking this command, extract what they
gave and infer 严重程度 / 类别 / 触发条件 / 影响范围 / 验证方式 from the impact. Only ask
back for fields you genuinely cannot determine. If verification is not executable yet,
write the smallest observable check, e.g. "run the failing command again" or "open the
affected screen and confirm [behavior]".

## Step 2: Read ENGINE_MAP + engine/PITFALLS.md (re-anchor)
Read `engine/ENGINE_MAP.md` first, then `engine/PITFALLS.md`. If ENGINE_MAP defines a
read-gate or pitfall maintenance rule in SYSTEM, read the relevant SYSTEM section too.
Final confirmation should include:
`read-gate: ENGINE_MAP, PITFALLS, SYSTEM pitfall/maintenance rules if present`

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
   - **触发条件：** [Q5]
   - **影响范围：** [Q6]
   - **验证方式：** [Q7]
   - **发现时间：** [today's date]
   ```
2. Append the matching row to the **索引** table:
   `| P00X | [严重程度] | [标题] | [类别] | Active |`
3. Bump the header 条目计数 and set its `Last updated` to today.
4. Update `engine/ENGINE_MAP.md`: bump PITFALLS revision/Last verified in §1 and bump §4
   global revision. Keep §4 short; do not paste the pitfall body there.

**Insertion rules:** append only — never reorder existing entries. Status starts as
`Active` (not "Open"); a fixed pitfall later becomes `Resolved`, never deleted.

## Step 4: Confirm
Output:
```
✓ engine/PITFALLS.md updated — [P00X] [严重程度] added: [标题]
✓ engine/ENGINE_MAP.md updated — PITFALLS revision + global revision bumped
read-gate: ENGINE_MAP, PITFALLS, [SYSTEM section if read]
```
