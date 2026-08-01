# Workstream Context - T-080 / codex

> status: active | task: T-080 | owner: codex | merge: pending | kind: session

## Goal

修复当前 GitHub open issues 中仍影响发布可用性的缺陷：Windows review 参数/解析、update 重复迁移胶囊、Implementer candidate 提交门禁、版本检查降级提示、旧 evidence schema 兼容；补齐 #13 的四种 AC 格式回归验证，并同步更新根 README（中英文）以反映 v6.24.0 当前 CLI、质量门禁、证明/审查和生命周期流程。

## Progress

- Implemented the T-080 runtime, installer, version-check, legacy-evidence, candidate-role, README, and regression-test changes in the card write-set.
- Bash and PowerShell issue regression tests pass; four AC declaration format tests pass in both shells.
- Existing T-078/T-079 artifacts and unrelated dirty files remain untouched.

## Changed Paths

- engine/bin/**, plugin/bin/**
- engine/scripts/engine-{review,check-update,doctor}.* and plugin mirrors
- engine/scripts/githooks/pre-commit and plugin mirror
- install.sh, install.ps1, plugin/manifest.json
- README.md, README.zh.md
- tests/workstream/test_issue_regressions.*
- tests/behavior-verify/test_verify_block_ac_format.*
- engine/tasks/T-080.md, engine/tasks/T-080/progress.md

## Evidence

- Bash issue regression: PASS.
- PowerShell issue regression: PASS.
- Bash AC-format regression: PASS.
- PowerShell AC-format regression: PASS.
- Existing generated T-080 evidence must be regenerated after staging because its code fingerprint was empty.

## Merge Notes

- Coordinator re-reads this shard before updating shared engine/CONTEXT.md and engine/HANDOFF.md.
