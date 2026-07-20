# INVENTORY — [Domain Name]
> Last updated: [date] | 域级功能索引 | 5 列 ≤120 行,见 contract/src/20-file-templates.md FILE 14

| Feature | Entry file | Public API | Status | Last verified |
|---------|-----------|------------|--------|---------------|
| [功能名] | [path/to/entry] | [api_contract_name] | [stable/experimental/deprecated/wip] | [YYYY-MM-DD] |

<!--
  维护规则:
  - 任务卡 done 时 MUST 更新涉及行（task-run.md 行为规则）
  - Entry file 路径必须存在（Doctor INVENTORY→code FAIL 检查）
  - Public API 全仓唯一（Doctor API 唯一性 FAIL 检查）
  - 总览 ≤120 行,超出拆到 INVENTORY/<feature>.md 子文件
  - 不写 API 完整签名 / 调用链 / 符号定位（交给 ast-grep 现生）
-->
