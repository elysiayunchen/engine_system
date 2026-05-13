# /engine-update — Session Handoff

You are updating the project's engine files at the end of a work session.

## Step 1: Read Current State
Use the Read tool to load:
- `engine/CONTEXT.md`
- `engine/HANDOFF.md`
- `engine/PITFALLS.md`

## Step 2: Ask Three Questions (one at a time, wait for answer each time)

1. "这次完成了什么？（一句话描述）"
2. "现在正在做 / 下一步准备做什么？"
3. "有没有新发现的坑、奇怪的行为、或者要提醒下一个 AI 的事？（没有就说"无"）"

## Step 3: Write Updates

### Update engine/CONTEXT.md
Edit the 状态面板 table in place:
- `上次完成` → answer from Q1
- `进行中` → answer from Q2
- Update `构建` status if relevant info was mentioned

### Append to engine/HANDOFF.md
Add a new session entry at the TOP of the session history table (time-ordered):

```
| [today's date] | [Q1 answer] | [Q2 answer] | [files touched this session if known] |
```

### Append to engine/PITFALLS.md (only if Q3 has content)
Add new pitfall row following insertion rules. Use next available P-ID.

## Step 4: Confirm
Output:
```
✓ engine/CONTEXT.md updated
✓ engine/HANDOFF.md updated
[✓ engine/PITFALLS.md updated — P00X added]  ← only if pitfall was recorded

引擎同步完成。下次会话直接继续：[Q2 answer]
```
