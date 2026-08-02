# T-084 Progress

> status: active | owner: coordinator-codex | updated: 2026-08-01

## Goal

实现 `engine review T-NNN --from-receipt <agent-id>`，并保持 root/plugin、Doctor 与 pre-commit 的行为一致。

## Checkpoint

- [x] AC-1 receipt conversion produces valid REVIEW.json
- [x] AC-2 Doctor accepts the from-receipt writer
- [x] AC-3 pre-commit accepts the canonical receipt review at HEAD
- [x] AC-4 invalid receipts are rejected
- [x] AC-5 plugin mirrors and manifest hashes are aligned

## Next

补齐 review、agent-review、prove、gate、close 证据后，再将任务卡标记 done 并归档本恢复锚点。
