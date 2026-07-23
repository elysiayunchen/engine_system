# Checkpoint — T-042
> Last updated: 2026-07-23T04:53:28Z by engine-verify | AC 级压缩恢复锚点,见 contract/src/20-file-templates.md FILE 15

## 已完成 AC
- [x] AC-1 grep -q 'Convert-ToCrlf' install.ps1 && grep -q 'Download-File' install.ps1 — evidence/AC-1.json PASS @ 2026-07-23T04:53:28Z
- [x] AC-2 grep -q 'Copy-Local' install.ps1 && grep -q 'Convert-ToCrlf' install.ps1 — evidence/AC-2.json PASS @ 2026-07-23T04:53:28Z
- [x] AC-3 grep -q 'pwsh' engine/bin/engine.cmd && grep -q 'pwsh' plugin/bin/engine.cmd &&  — evidence/AC-3.json PASS @ 2026-07-23T04:53:28Z
- [x] AC-4 diff -q engine/bin/engine.cmd plugin/bin/engine.cmd && diff -q engine/bin/engine — evidence/AC-4.json PASS @ 2026-07-23T04:53:29Z
- [x] AC-5 test "$(tr -d '[:space:]' < VERSION)" = "6.11.4" && test "$(tr -d '[:space:]' <  — evidence/AC-5.json PASS @ 2026-07-23T04:53:29Z
- [x] AC-6 bash scripts/check.sh — evidence/AC-6.json PASS @ 2026-07-23T04:54:17Z
