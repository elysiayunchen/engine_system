# INVENTORY — project-meta
> Last updated: 2026-07-29 | 域级功能索引 | 5 列 ≤120 行,见 contract/src/20-file-templates.md FILE 14

| Feature | Entry file | Public API | Status | Last verified |
|---------|-----------|------------|--------|---------------|
| 任务卡格式契约 | engine/tasks/README.md | parse_task_card(id) | stable | 2026-07-19 |
| 决策台账 | engine/decisions/README.md | parse_decision(id) | stable | 2026-07-19 |
| 受保护路径声明 | engine/decisions/rules.json | protected_paths() | stable | 2026-07-19 |
| 变更胶囊格式 | engine/changes/CHANGE-2026-07-19-04.md | parse_capsule(file) | stable | 2026-07-19 |
| 域路由联邦表 | engine/domains/federation.json | resolve_domain(path) | stable | 2026-07-19 |
| 行为技能路由表 | engine/domains/routing.json | route_behavior(intent) | stable | 2026-07-19 |
| 项目地图 | engine/ENGINE_MAP.md | load_engine_map() | stable | 2026-07-19 |
| 当前状态面板 | engine/CONTEXT.md | read_status_panel() | stable | 2026-07-19 |
| 会话交接 | engine/HANDOFF.md | read_resume_point() | stable | 2026-07-19 |
| Agent 适配器 | engine/AGENT_ADAPTERS.md | list_adapters() | stable | 2026-07-19 |
| 任务级 progress.md 模板 | engine/skeleton/progress.md | instantiate_progress(tid) | stable | 2026-07-19 |
| 域级 INVENTORY 模板 | engine/skeleton/domains/INVENTORY.md | instantiate_inventory(domain) | stable | 2026-07-19 |
| HANDOFF 历史归档 | engine/handoff-archive-2026-07.md | search_archive(date) | stable | 2026-07-19 |
| 引擎根引导器 | AGENTS.md | read_session_protocol() | stable | 2026-07-19 |
| Claude 引导器 | CLAUDE.md | read_quick_start() | stable | 2026-07-19 |
| migrator bump 提示测试(sh) | tests/update-flow/test_migrator_bump_prompt.sh | test_migrator_bump_prompt_sh() | stable | 2026-07-29 |
| migrator bump 提示测试(ps1) | tests/update-flow/test_migrator_bump_prompt.ps1 | test_migrator_bump_prompt_ps1() | stable | 2026-07-29 |
