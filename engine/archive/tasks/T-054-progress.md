# T-054 Progress

## 2026-07-29 T-054 v6.14.0 done

- AC-1: pre-commit L273-279 加 `head_task_snapshot` + HEAD status done 检查,grep 确认存在
- AC-2: S1 active→done 转换 → 检查 AC PASS(should_check_ac_pass 返回 1)PASS
- AC-3: S2 新卡首次 done(HEAD 缺失)→ 检查 AC PASS PASS
- AC-4: S3 已 done 修改(HEAD=done, staging=done)→ 跳过 PASS
- AC-5: S4 exempt marker → 跳过 PASS
- AC-6: diff engine/scripts/githooks/pre-commit plugin/engine/scripts/githooks/pre-commit BYTE-IDENTICAL
- AC-7: scripts/check.sh CHECK PASSED
- AC-8: VERSION 6.14.0 + CHANGELOG v6.14.0 段存在

Test: tests/workstream/test_precommit_done_card_drift.sh 5 pass 0 fail
