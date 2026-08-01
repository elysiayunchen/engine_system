# T-080 Progress

> status: active | owner: codex | updated: 2026-08-01

## Goal

修复 GitHub open issues #13/#14/#22/#23/#24/#26/#27，并更新中英文根 README。

## Checkpoint

- [x] AC-1 Windows review 参数/解析
- [x] AC-2 update 单次 migrator
- [x] AC-3 Implementer candidate pre-commit 角色门禁
- [x] AC-4 check-update 版本方向
- [x] AC-5 legacy evidence 兼容
- [x] AC-6 四种 AC 格式回归
- [x] AC-7 README
- [x] AC-8 mirror + manifest

## Verification

- `bash tests/workstream/test_issue_regressions.sh`: PASS.
- `pwsh -NoProfile -File tests/workstream/test_issue_regressions.ps1`: PASS.
- `bash tests/behavior-verify/test_verify_block_ac_format.sh`: PASS.
- `pwsh -NoProfile -File tests/behavior-verify/test_verify_block_ac_format.ps1`: PASS.
- Root/plugin mirrors and changed Bash scripts parse successfully.
- Union-gating protected-path fix is included in implementation commit `4ca2372`; plugin manifest hash refresh is staged for the next verify.
- Existing T-078/T-079 artifacts and unrelated dirty files remain untouched.

## Next

- Run `engine verify T-080 --preflight` after the manifest refresh, then review, prove, gate, and close.
- Coordinator must merge the worker shard; repository-wide Doctor debt remains a separate blocker.
