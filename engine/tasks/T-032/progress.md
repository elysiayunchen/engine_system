# progress — [Task ID: T-032] [Task-level progress.md + SessionStart 注入 + Doctor 检查]
> Last updated: 2026-07-19 | 任务级压缩恢复锚点 | 7 栏事件驱动更新,见 contract/src/20-file-templates.md FILE 13

## §1 已读文件（理解项目）
- contract/src/20-file-templates.md — FILE 13 已新增 progress.md 7 栏模板与生命周期规则
- contract/src/behaviors/task-run.md — 已加事件驱动触发点章节
- contract/src/behaviors/handoff.md — 已加薄指针规则
- engine/ENGINE_DOCTOR.md — dogfood 实例,contract-version 6.7.0 + #12 规则
- plugin/engine/ENGINE_DOCTOR.md — 模板,#24 规则
- engine/scripts/engine-doctor.sh + .ps1 — 已加 check_progress_md / Test-ProgressMd
- engine/scripts/engine-hook-session-start.sh + .ps1 — 已加 progress.md 注入段
- engine/scripts/engine-migrate-contract.sh + .ps1 — 已加 #12 + skeleton/progress.md 创建
- engine/skeleton/progress.md + plugin/engine/skeleton/progress.md — 7 栏模板已建
- plugin/manifest.json — compile.sh backfill 57 entries
- install.sh + install.ps1 — skeleton/* 通配规则不变,progress.md 由 migrator 分发

## §2 已确认接口（不重复读）
- compile.sh — behaviors/src → engine/prompts/behaviors/ + plugin 镜像 + skills; scripts → plugin 镜像; manifest SHA256 backfill
- install.sh FILES 数组 — `"src:dest:protect"` 格式; skeleton/* 通配会剥前缀,故 progress.md 不入 FILES,由 migrator create-if-missing
- check_progress_md(cv) — cv_int = major*10000 + minor*100 + patch;< 60700 WARN, >= 60700 FAIL
- ENGINE_DOCTOR.md managed block — 首行 `<!-- contract-version: X -->` 由 migrator 写入

## §3 已排除路径（原 TRAIL 的家）
- 2026-07-19 / 把 skeleton/progress.md 加入 install.sh FILES 数组 / 与 skeleton/* 通配规则冲突需特例,且 migrator 已分发 / 不入 FILES,migrator create-if-missing
- 2026-07-19 / PreCompact hook 注入 progress.md 写盘 / Claude Code 沙箱不允许 hook 触发 agent 磁盘写入,机制错配 / SessionStart 注入 + 事件驱动由 agent 写
- 2026-07-19 / 把 progress.md 加入 SessionStart 全文注入(无论有无 active 卡) / 增加常态 token 占用,违背"任务级"语义 / 仅 active/paused 卡存在时注入

## §4 当前进行到（压缩恢复点）
正在做:AC-6 收尾 — engine-doctor.sh/.ps1 添加 check_progress_md/Test-ProgressMd 函数定义(原仅调用未定义);已写完两份函数,待 compile.sh 同步 + scripts/check.sh 全绿
下一步:跑 compile.sh 同步 doctor 到 plugin 镜像;跑 scripts/check.sh 验证 AC-8;然后 AC-9(VERSION 6.7.0 + CHANGELOG) + AC-10(check.sh + release)

## §5 待确认问题
- 无 / 阻塞:无 / 提出:—

## §6 已知风险/未解 bug
- T-032 自身是 active 卡,dogfood contract-version=6.7.0 → doctor 会检查 T-032/progress.md 是否存在;本文件即是该检查的满足项 / 影响:dogfood 自检 / 缓解:已创建本文件

## §7 回滚尝试
- 无
