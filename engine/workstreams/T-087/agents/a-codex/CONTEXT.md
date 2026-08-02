# Workstream Context - T-087 / codex

> status: active | task: T-087 | owner: codex | merge: pending | kind: subagent

## Goal

修复 issue #30 的任务卡解析一致性与生命周期分发，并发布 6.26.1。

## Progress

- Issue #30 专项测试 33/33 通过。
- T-087 AC-1~AC-5 已生成 PASS evidence。
- 版本已同步至 6.26.1。

## Changed Paths

- T-087 WRITE-SET 内的运行时脚本、安装分发、plugin 镜像与测试。

## Evidence

- `engine/evidence/T-087/AC-1.json` through `AC-5.json`
- `engine/evidence/T-087/MANIFEST.json`

## Merge Notes

- Coordinator re-reads this shard before updating shared engine/CONTEXT.md and engine/HANDOFF.md.
