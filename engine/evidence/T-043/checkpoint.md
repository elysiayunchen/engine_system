# Checkpoint — T-043
> Last updated: 2026-07-23T10:18:44Z by engine-verify | AC 级压缩恢复锚点,见 contract/src/20-file-templates.md FILE 15

## 已完成 AC
- [x] AC-1 grep -q 'in_frontmatter' engine/scripts/githooks/pre-commit — evidence/AC-1.json PASS @ 2026-07-23T10:18:44Z
- [x] AC-2 grep -q 'tolower' engine/scripts/githooks/pre-commit — evidence/AC-2.json PASS @ 2026-07-23T10:18:44Z
- [x] AC-3 grep -q 'in_frontmatter_block\|frontmatter_block' engine/scripts/githooks/pre-co — evidence/AC-3.json PASS @ 2026-07-23T10:18:44Z
- [x] AC-4 diff -q engine/scripts/githooks/pre-commit plugin/engine/scripts/githooks/pre-co — evidence/AC-4.json PASS @ 2026-07-23T10:18:44Z
- [x] AC-5 test -f tests/workstream/test_precommit_yaml_frontmatter.sh && bash tests/workst — evidence/AC-5.json PASS @ 2026-07-23T10:18:45Z
- [x] AC-6 bash scripts/check.sh — evidence/AC-6.json PASS @ 2026-07-23T10:19:31Z
