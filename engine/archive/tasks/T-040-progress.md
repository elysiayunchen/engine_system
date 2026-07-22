# progress — T-040 小任务 progress.md 豁免条款 + v6.11.3 patch (archived 2026-07-22 done)
> Last updated: 2026-07-22 | 任务级压缩恢复锚点 | 7 栏事件驱动更新,见 contract/src/20-file-templates.md FILE 13
> **本任务豁免**:estimated_steps=6 ≤ 10 且 checkpoint_plan=inline,按 FILE 13「小任务豁免」条款仅填 §1 + §4;§2/§3/§5/§6/§7 写 n/a 占位。
> 归档自 `engine/tasks/T-040/progress.md`(T-040 status: done 后按 FILE 13 lifecycle 迁移,SessionStart 不再注入)。

## §1 已读文件（理解项目）
- engine/tasks/T-039.md — T-039 任务卡(GOAL/WRITE-SET/AC 范围)
- engine/archive/tasks/T-039-progress.md — T-039 归档 progress.md(4 栏自创格式样本,豁免动机)
- engine/archive/tasks/T-036-progress.md — T-036 归档 progress.md(7 栏完整样本,对照参考)
- engine/skeleton/progress.md — 7 栏骨架(豁免不改骨架)
- contract/src/20-file-templates.md FILE 13 段(line 1413-1492)— 7 栏定义 + 事件驱动 + 生命周期
- contract/src/behaviors/task-run.md — 「Task progress.md event-driven update」段(line 20-40)
- contract/budget.json — max_lines 2930 + 13 rules
- contract/compile.sh — 编译器流程(8 步:web-prompt / runtime-law / rules.json / engine-init / prompts/init / behaviors / scripts sync / bin sync / manifest sha256)
- engine/prompts/behaviors/task-run.md — plugin 镜像源(compile.sh 自动同步)
- engine/prompts/init.md — agent 中立前言 dist(compile.sh 重生)

## §2 已确认接口（不重复读）
- n/a (small task exempt)

## §3 已排除路径（原 TRAIL 的家）
- n/a (small task exempt)

## §4 当前进行到（压缩恢复点）
T-040 **done** 6/6 AC PASS(engine verify T-040 全绿,check.sh 0 failures 4 warnings 非阻塞)。
- AC-1 ✅ FILE 13 加「小任务豁免」子段(line 1446-1459)
- AC-2 ✅ task-run.md 加「Small task exemption / 小任务豁免」子段(line 42-52,双语 heading 满足 grep 大小写敏感)
- AC-3 ✅ budget.json max_lines 2930→2940 + compile.sh 重生 5 dist(3 处 dist 含豁免段已 grep 验证)
- AC-4 ✅ plugin 镜像 3 处 diff -q 对称(init.md / behaviors/task-run.md / SKILL.md)
- AC-5 ✅ VERSION 三处 6.11.3 + CHANGELOG v6.11.3 段 + manifest SHA256 重生
- AC-6 ✅ check.sh 0 failures 4 warnings(非阻塞)PASS project doctor

本任务自身狗粮豁免(estimated_steps=6 ≤ 10 + checkpoint_plan=inline),progress.md 仅填 §1 + §4,§2/§3/§5/§6/§7 写 n/a 占位——豁免条款首次应用即狗粮验证。下一步:本 progress.md 归档到 `engine/archive/tasks/T-040-progress.md` + 删除 live 副本(按 FILE 13 lifecycle);更新 HANDOFF/CONTEXT/ENGINE_MAP;commit + 可选 push tag v6.11.3。

## §5 待确认问题
- n/a (small task exempt)

## §6 已知风险/未解 bug
- n/a (small task exempt)

## §7 回滚尝试
- n/a (small task exempt)
