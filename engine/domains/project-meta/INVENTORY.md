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
| Agent review CLI regression | tests/workstream/test_review_agent_cli.sh | test_review_agent_cli_sh() | stable | 2026-08-01 |
| Agent review package regression | tests/workstream/test_review_agent_package.sh | test_review_agent_package_sh() | stable | 2026-08-01 |
| Agent review validator regression | tests/workstream/test_review_agent_validate.sh | test_review_agent_validate_sh() | stable | 2026-08-01 |
| Agent review config regression | tests/workstream/test_review_agent_config.sh | test_review_agent_config_sh() | stable | 2026-08-01 |
| Agent review mirror regression | tests/workstream/test_review_agent_mirror.sh | test_review_agent_mirror_sh() | stable | 2026-08-01 |
| Agent reviewer design specification | docs/superpowers/specs/2026-07-31-agent-reviewer-design.md | agent_reviewer_design_spec() | stable | 2026-08-01 |
| Agent review gate regression | tests/workstream/test_review_agent_gate.sh | test_review_agent_gate_sh() | stable | 2026-08-01 |
| Doctor agent review regression | tests/workstream/test_doctor_agent_review.sh | test_doctor_agent_review_sh() | stable | 2026-08-01 |
| Grounded review regression | tests/workstream/test_review_agent_grounded.sh | test_review_agent_grounded_sh() | stable | 2026-08-01 |
| Dynamic review regression | tests/workstream/test_review_agent_dynamic.sh | test_review_agent_dynamic_sh() | stable | 2026-08-01 |
| Prove inference regression | tests/workstream/test_prove_infer.sh | test_prove_infer_sh() | stable | 2026-08-01 |
| Prove execution regression | tests/workstream/test_prove_execute.sh | test_prove_execute_sh() | stable | 2026-08-01 |
| Acceptance preflight regression(sh) | tests/workstream/test_acceptance_preflight.sh | test_acceptance_preflight_sh() | stable | 2026-08-01 |
| Acceptance preflight regression(ps1) | tests/workstream/test_acceptance_preflight.ps1 | test_acceptance_preflight_ps1() | stable | 2026-08-01 |
| T-086 capsule generation regression | tests/workstream/test_close_capsule_gen.sh | test_close_capsule_gen_sh() | stable | 2026-08-02 |
| T-086 Doctor lint regression | tests/workstream/test_doctor_script_lint.sh | test_doctor_script_lint_sh() | stable | 2026-08-02 |
| OSS pattern internalization plan | docs/oss-internalization-plan.md | read_oss_internalization_plan() | stable | 2026-08-02 |
| 编译产物 rules.json | rules.json | generated_rules_json() | stable | 2026-08-01 |
