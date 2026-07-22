# Checkpoint — T-040
> Last updated: 2026-07-22T11:07:36Z by engine-verify | AC 级压缩恢复锚点,见 contract/src/20-file-templates.md FILE 15

## 已完成 AC
- [x] AC-6 bash scripts/check.sh — evidence/AC-6.json PASS @ 2026-07-22T11:10:58Z
- [x] AC-1 grep -q '小任务.*豁免\|small task.*exempt' contract/src/20-file-templates.m — evidence/AC-1.json PASS @ 2026-07-22T12:21:11Z
- [x] AC-2 grep -q 'small task exemption\|小任务.*豁免' contract/src/behaviors/task-ru — evidence/AC-2.json PASS @ 2026-07-22T12:21:11Z
- [x] AC-3 grep -q '"max_lines": 2940' contract/budget.json && bash contract/compile.sh &&  — evidence/AC-3.json PASS @ 2026-07-22T12:21:14Z
- [x] AC-4 diff -q engine/prompts/behaviors/task-run.md plugin/engine/prompts/behaviors/tas — evidence/AC-4.json PASS @ 2026-07-22T12:21:14Z
- [x] AC-5 test "$(tr -d '[:space:]' < VERSION)" = "6.11.3" && test "$(tr -d '[:space:]' <  — evidence/AC-5.json PASS @ 2026-07-22T12:21:14Z
