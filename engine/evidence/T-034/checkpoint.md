# Checkpoint — T-034
> Last updated: 2026-07-20T09:34:40Z by engine-verify | AC 级压缩恢复锚点,见 contract/src/20-file-templates.md FILE 15

## 已完成 AC
- [x] AC-1 grep -q 'checkpoint.md' contract/src/20-file-templates.md && grep -q '已完成  — evidence/AC-1.json PASS @ 2026-07-20T10:19:40Z
- [x] AC-2 grep -q 'checkpoint.md' engine/scripts/engine-verify.sh && grep -q 'checkpoint.m — evidence/AC-2.json PASS @ 2026-07-20T10:19:40Z
- [x] AC-3 grep -q 'checkpoint.md' engine/scripts/engine-hook-session-start.sh && grep -q ' — evidence/AC-3.json PASS @ 2026-07-20T10:19:40Z
- [x] AC-4 grep -q 'estimated_steps' engine/tasks/README.md && grep -q 'checkpoint_plan' en — evidence/AC-4.json PASS @ 2026-07-20T10:19:41Z
- [x] AC-5 grep -q 'estimated_steps' engine/ENGINE_DOCTOR.md && grep -q 'checkpoint_plan' e — evidence/AC-5.json PASS @ 2026-07-20T10:19:41Z
- [x] AC-6 grep -q 'check_task_granularity\|task_granularity' engine/scripts/engine-doctor. — evidence/AC-6.json PASS @ 2026-07-20T10:19:41Z
- [x] AC-7 grep -q '跨域\|cross-domain\|depends-on.*阻塞\|depends-on.*block' engine/tas — evidence/AC-7.json PASS @ 2026-07-20T10:19:41Z
- [x] AC-8 bash scripts/check.sh && diff -q engine/scripts/engine-verify.sh plugin/engine/s — evidence/AC-8.json PASS @ 2026-07-20T10:20:29Z
- [x] AC-9 test "$(tr -d '[:space:]' < VERSION)" = "6.9.0" && test "$(tr -d '[:space:]' < e — evidence/AC-9.json PASS @ 2026-07-20T10:20:30Z
- [x] AC-10 bash scripts/check.sh — evidence/AC-10.json PASS @ 2026-07-20T10:21:17Z
- [x] AC-5.1 grep -q 'check_writeset_budget' engine/scripts/engine-doctor.sh && grep -q 'chec — evidence/AC-5.1.json PASS @ 2026-07-20T10:19:41Z
