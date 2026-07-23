# progress — [Task ID: T-043] 修复 P038 parse_task_patterns 支持 YAML frontmatter 多行 write-set
> Last updated: 2026-07-23 | 任务级压缩恢复锚点 | 7 栏事件驱动更新,见 contract/src/20-file-templates.md FILE 13
> 小任务豁免(v6.11.3/T-040):estimated_steps=6 ≤ 10, checkpoint_plan=inline → 仅 §1+§4 必填,§2/§3/§5/§6/§7 写 n/a (small task exempt) 占位

## §1 已读文件（理解项目）
- engine/scripts/githooks/pre-commit — parse_task_patterns L35-56 两个分支:inline grep L37-41(case-sensitive,大写 WRITE-SET 调用不匹配小写 write-set: frontmatter)+ awk markdown L42-55(只匹配 ## field section,不匹配 YAML field: 多行列表);两者都不支持 YAML frontmatter 多行 write-set
- GitHub issue #10 — reporter elysiayunchen 报告 P038(parser bug)+ P037(legacy fallback L89-94)叠加导致误拦。reporter 提供概念性 awk 补丁,方向正确但缺 case 敏感性 + frontmatter 边界检测细节
- engine/decisions/D-032.md — P037 fallback 改造决策(proposed),移除 L89-94 + fail-open
- engine/tasks/T-044.md — P037 fix 任务卡(proposed,depends-on D-032 + T-043)
- pre-commit L80-94 P037 fallback 三层选卡逻辑:L76-79 active 卡 / L80-88 closing done 卡 / L89-94 legacy fallback(strict_task_mode=0 拿 lex-largest done 卡)

## §2 已确认接口（不重复读）
n/a (small task exempt)

## §3 已排除路径（原 TRAIL 的家）
n/a (small task exempt)

## §4 当前进行到（压缩恢复点）
T-043 done 6/6 AC PASS。awk 分支重写完成(engine + plugin 镜像):新增 `in_frontmatter_block` 边界状态 + `in_frontmatter_field` 字段头匹配 + `field_lc=tolower(field)` case 不敏感;原 markdown `## field` section 分支保留并改 case-insensitive。变量名用 `in_frontmatter_block`(非 `in_frontmatter`)以匹配 AC-3 verify grep 契约。测试 test_precommit_yaml_frontmatter.sh 7 场景全 PASS(5 required + 2 bonus case-mixed)。check.sh 全绿(2 非阻塞 WARN)。engine verify T-043 6/6 PASS。版本 6.11.5 + CHANGELOG + manifest SHA256(pre-commit f24d1c31→3baf994e)+ change capsule CHANGE-2026-07-23-02.md。CONTEXT/HANDOFF/ENGINE_MAP 已更新,HANDOFF 归档 T-034 行(8 行合规)。
下一步:commit + 可选 push tag v6.11.5 + 回复 issue #10 + 开 T-044(D-032 已批准)。

## §5 待确认问题
n/a (small task exempt)

## §6 已知风险/未解 bug
n/a (small task exempt)

## §7 回滚尝试
n/a (small task exempt)
