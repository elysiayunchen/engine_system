# /add-pitfall — Record a Pitfall Immediately

Use this command right when you discover a bug, footgun, or unexpected behavior.
Don't wait until end of session — record it now before context is lost.

## Step 1: Ask (one message, all at once)
"快速记录一下这个坑：
1. 简短描述（一句话，问题是什么）？
2. 怎么触发的？
3. 根本原因（如果知道）？
4. 解决方案或绕过方法？
5. 这属于哪类：bug / 配置问题 / 危险命令 / 不可靠的库 / 永不做的事？"

If the user already described the pitfall in their message before this command, extract the info directly without asking again.

## Step 2: Read engine/PITFALLS.md
Find the current maximum P-ID number across all tables.

## Step 3: Write to engine/PITFALLS.md
Append a new row to the appropriate table section using next P-ID.

Format:
| P00X | [one-line description] | [trigger] | [root cause or TBD] | [solution/workaround] | Open |

## Step 4: Confirm
Output:
```
✓ engine/PITFALLS.md updated — [P00X] added: [one-line description]
```
