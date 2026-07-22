# Checkpoint — T-035
> Last updated: 2026-07-20T11:23:11Z by engine-verify | AC 级压缩恢复锚点,见 contract/src/20-file-templates.md FILE 15

## 已完成 AC
- [x] AC-1 grep -q 'shellcheck\|PSScriptAnalyzer' contract/src/30-operational.md && grep -q — evidence/AC-1.json PASS @ 2026-07-20T12:03:08Z
- [x] AC-2 grep -q 'shellcheck' engine/scripts/engine-verify.sh && grep -q 'PSScriptAnalyze — evidence/AC-2.json PASS @ 2026-07-20T12:03:08Z
- [x] AC-3 grep -q 'reverse_call_site\|reverse-call-site\|反向调用点' engine/scripts/e — evidence/AC-3.json PASS @ 2026-07-20T12:03:09Z
- [x] AC-4 grep -q 'DEAD-CODE.json' engine/scripts/engine-verify.sh && grep -q 'DEAD-CODE.j — evidence/AC-4.json PASS @ 2026-07-20T12:03:09Z
- [x] AC-5 grep -q 'warn_count\|WARN.*done\|WARN.*豁免\|WARN.*exempt' engine/ENGINE_DOCTO — evidence/AC-5.json PASS @ 2026-07-20T12:03:09Z
- [x] AC-6 grep -q 'check_warn_done_gate\|warn_done_gate\|WarnDoneGate' engine/scripts/engi — evidence/AC-6.json PASS @ 2026-07-20T12:03:09Z
- [x] AC-7 grep -q 'DEAD-CODE\|死代码' engine/prompts/behaviors/verify-writeback.md && g — evidence/AC-7.json PASS @ 2026-07-20T12:03:09Z
- [x] AC-8 bash scripts/check.sh && diff -q engine/scripts/engine-verify.sh plugin/engine/s — evidence/AC-8.json PASS @ 2026-07-20T12:03:55Z
- [x] AC-9 test "$(tr -d '[:space:]' < VERSION)" = "6.10.0" && test "$(tr -d '[:space:]' <  — evidence/AC-9.json PASS @ 2026-07-20T12:03:55Z
- [x] AC-10 bash scripts/check.sh — evidence/AC-10.json PASS @ 2026-07-20T12:04:40Z
- [x] AC-2.1 grep -q 'jscpd' engine/scripts/engine-verify.sh && grep -q 'jscpd' engine/script — evidence/AC-2.1.json PASS @ 2026-07-20T12:03:08Z
