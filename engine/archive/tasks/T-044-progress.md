# progress — T-044

## §1 任务目标

修复 GitHub issue #10 的 P037 — pre-commit legacy fallback(L111-116,原 L89-94)在无 active 卡 + strict_task_mode=0(< 6.5)时拿 lex-largest done 卡管当前 commit,导致历史 done 卡误管新 commit。按 D-032(已批)移除 fallback,无 active/closing 卡时 strict_task_mode=0 项目放行(fail-open)。

## §2 (n/a — small task exempt)

n/a (small task exempt per contract/src/behaviors/task-run.md)

## §3 (n/a — small task exempt)

n/a (small task exempt)

## §4 进度日志

T-044 done 5/5 AC PASS。移除 pre-commit L111-116 legacy fallback 块(strict_task_mode=0 时 `ls -1 T-*.md | sort -r` 扫 done 卡);更新 L94-98 注释说明 fail-open 语义 + P037 fix 标记;plugin 镜像同步;写测试 test_precommit_no_legacy_fallback.sh 4 场景(S1 无 active+旧项目 fail-open / S2 无 active+新项目 block / S3 有 active 正常 governing / S4 源码 fallback 模式清除)8/8 PASS;更新 task-card gate C6/C7 测试反映新行为(done 卡不 govern → protected 文件无 task_decision → block);扩展 D-032 scope 加 T-044 完整 WRITE-SET 含 plugin/manifest.json;DEAD-CODE.json 9 警告全豁免(test helper false positive);版本 6.11.5 → 6.11.6。check.sh 全绿(0 failures,3 non-blocking WARN)。issue #10 P037 修复完成(P038 已在 v6.11.5/T-043 修复)。
