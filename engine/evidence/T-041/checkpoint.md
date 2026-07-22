# Checkpoint — T-041
> Last updated: 2026-07-22T12:01:57Z by engine-verify | AC 级压缩恢复锚点,见 contract/src/20-file-templates.md FILE 15

## 已完成 AC
- [x] AC-1 grep -q 'exempt_id' engine/scripts/githooks/pre-commit && grep -q 'engine/tasks/ — evidence/AC-1.json PASS @ 2026-07-22T12:03:57Z
- [x] AC-2 test -f tests/workstream/test_precommit_self_exempt.sh && bash tests/workstream/ — evidence/AC-2.json PASS @ 2026-07-22T12:03:57Z
- [x] AC-3 bash contract/compile.sh 2>&1 | grep -q 'manifest sha256 backfilled' && git diff — evidence/AC-3.json PASS @ 2026-07-22T12:04:03Z
- [x] AC-4 test "$(git config core.hooksPath)" = "engine/scripts/githooks" && grep -q 'exem — evidence/AC-4.json PASS @ 2026-07-22T12:04:03Z
- [x] AC-5 bash scripts/check.sh — evidence/AC-5.json PASS @ 2026-07-22T12:04:50Z
