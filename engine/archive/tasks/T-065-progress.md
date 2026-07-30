# T-065 Progress (archived)

## Step 1: 定位 + 修复 pre-commit closing_paths 逻辑
- [x] 读 issue #21 全文 + issue #18 修复模式(L375-381)作为参考
- [x] 修 `engine/scripts/githooks/pre-commit` L234-238:加 HEAD 检查
- [x] 修 `plugin/engine/scripts/githooks/pre-commit` 镜像(同步)
- [x] diff 验证 byte-identical: IDENTICAL

## Step 2: 测试
- [x] 新增 `tests/workstream/test_precommit_done_card_governing.sh`:5 场景
- [x] 新测试 5 pass 0 fail
- [x] 回归 `test_precommit_done_card_drift.sh`(issue #18):5 pass 0 fail

## Step 3: 版本 + 文档
- [x] VERSION 6.17.3 → 6.17.4(root/engine/plugin)
- [x] manifest.json:pre-commit + VERSION sha256 更新
- [x] change capsule CHANGE-2026-07-30-02.md
- [x] CHANGELOG v6.17.4 段

## Step 4: 验证
- [x] scripts/check.sh CHECK PASSED
- [x] engine verify T-065: 7 pass, 0 fail, 0 skip
