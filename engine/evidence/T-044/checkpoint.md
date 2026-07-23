# Checkpoint — T-044
> Last updated: 2026-07-23T12:06:37Z by engine-verify | AC 级压缩恢复锚点,见 contract/src/20-file-templates.md FILE 15

## 已完成 AC
- [x] AC-1 ! grep -q 'ls -1.*T-\*.md.*sort -r' engine/scripts/githooks/pre-commit — evidence/AC-1.json PASS @ 2026-07-23T12:10:37Z
- [x] AC-2 ! grep -q 'strict_task_mode.*-eq 0' engine/scripts/githooks/pre-commit — evidence/AC-2.json PASS @ 2026-07-23T12:10:37Z
- [x] AC-3 diff -q engine/scripts/githooks/pre-commit plugin/engine/scripts/githooks/pre-co — evidence/AC-3.json PASS @ 2026-07-23T12:10:37Z
- [x] AC-4 test -f tests/workstream/test_precommit_no_legacy_fallback.sh && bash tests/work — evidence/AC-4.json PASS @ 2026-07-23T12:10:37Z
- [x] AC-5 bash scripts/check.sh — evidence/AC-5.json PASS @ 2026-07-23T12:11:30Z
