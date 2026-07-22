# Checkpoint — T-039
> Last updated: 2026-07-22T09:17:01Z by engine-verify | AC 级压缩恢复锚点,见 contract/src/20-file-templates.md FILE 15

## 已完成 AC
- [x] AC-1 grep -q 'dedup' contract/src/20-file-templates.md && ! grep -q 'verify 脚本追 — evidence/AC-1.json PASS @ 2026-07-22T09:17:01Z
- [x] AC-2 grep -q 'grep.*-v.*AC\|dedup\|replace.*checkpoint\|filter.*checkpoint' engine/sc — evidence/AC-2.json PASS @ 2026-07-22T09:17:01Z
- [x] AC-3 grep -q 'dedup\|去重\|替换' engine/skeleton/checkpoint.md && grep -q 'dedup\ — evidence/AC-3.json PASS @ 2026-07-22T09:17:01Z
- [x] AC-4 test $(grep -c '^- \[x\] AC-' engine/evidence/T-036/checkpoint.md) -le 18 && tes — evidence/AC-4.json PASS @ 2026-07-22T09:17:02Z
- [x] AC-5 test -f tests/workstream/test_checkpoint_dedup.sh && test -f tests/workstream/te — evidence/AC-5.json PASS @ 2026-07-22T09:17:03Z
- [x] AC-6 test "$(tr -d '[:space:]' < VERSION)" = "6.11.2" && test "$(tr -d '[:space:]' <  — evidence/AC-6.json PASS @ 2026-07-22T09:17:03Z
- [x] AC-7 bash scripts/check.sh — evidence/AC-7.json PASS @ 2026-07-22T09:17:52Z
