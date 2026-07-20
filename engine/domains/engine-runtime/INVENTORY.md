# INVENTORY — engine-runtime
> Last updated: 2026-07-19 | 域级功能索引 | 5 列 ≤120 行,见 contract/src/20-file-templates.md FILE 14

| Feature | Entry file | Public API | Status | Last verified |
|---------|-----------|------------|--------|---------------|
| 仓库发布门禁 | scripts/check.sh | run_all_checks() | stable | 2026-07-19 |
| Doctor 双实现 | engine/scripts/engine-doctor.sh | check_progress_md() | stable | 2026-07-19 |
| Doctor ps1 实现 | engine/scripts/engine-doctor.ps1 | Test-ProgressMd() | stable | 2026-07-19 |
| progress.md 注入 | engine/scripts/engine-hook-session-start.sh | inject_progress_md() | stable | 2026-07-19 |
| progress.md 注入 ps1 | engine/scripts/engine-hook-session-start.ps1 | Inject-ProgressMd() | stable | 2026-07-19 |
| 契约编译器 | contract/compile.sh | compile_src_to_dist() | stable | 2026-07-19 |
| 契约编译器 ps1 | contract/compile.ps1 | Compile-SrcToDist() | stable | 2026-07-19 |
| Stop hook 门禁 | engine/scripts/engine-hook-stop.sh | enforce_writeback_gate() | stable | 2026-07-19 |
| Stop hook 门禁 ps1 | engine/scripts/engine-hook-stop.ps1 | Enforce-WritebackGate() | stable | 2026-07-19 |
| Pre-commit 受保护路径 | engine/scripts/githooks/pre-commit | check_protected_paths() | stable | 2026-07-19 |
| 旧项目契约迁移器 | engine/scripts/engine-migrate-contract.sh | upsert_block() | stable | 2026-07-19 |
| 旧项目契约迁移器 ps1 | engine/scripts/engine-migrate-contract.ps1 | Upsert-Block() | stable | 2026-07-19 |
| 跨 agent 锚点同步 | engine/scripts/engine-sync-agent-anchors.sh | sync_anchors() | stable | 2026-07-19 |
| 跨 agent 锚点同步 ps1 | engine/scripts/engine-sync-agent-anchors.ps1 | Sync-Anchors() | stable | 2026-07-19 |
| 任务卡 AC 验证器 | engine/scripts/engine-verify.sh | verify_task_ac() | stable | 2026-07-19 |
| 任务卡 AC 验证器 ps1 | engine/scripts/engine-verify.ps1 | Verify-TaskAc() | stable | 2026-07-19 |
| 项目 CLI shim | engine/bin/engine | engine_update() | stable | 2026-07-19 |
| 项目 CLI shim ps1 | engine/bin/engine.ps1 | Engine-Update() | stable | 2026-07-19 |
| 版本检查更新器 | engine/scripts/engine-check-update.sh | check_version_update() | stable | 2026-07-19 |
| 版本检查更新器 ps1 | engine/scripts/engine-check-update.ps1 | Check-VersionUpdate() | stable | 2026-07-19 |
| SessionEnd Doctor 缓存 | engine/scripts/engine-hook-session-end.sh | cache_pending() | stable | 2026-07-19 |
| SessionEnd Doctor 缓存 ps1 | engine/scripts/engine-hook-session-end.ps1 | Cache-Pending() | stable | 2026-07-19 |
| Windows C 层 hook 垫片 | engine/scripts/engine-hook.cmd | dispatch_hook() | stable | 2026-07-19 |
| 引擎上下文加载器 | engine/scripts/engine-context.sh | load_context() | stable | 2026-07-19 |
| 引擎上下文加载器 ps1 | engine/scripts/engine-context.ps1 | Load-Context() | stable | 2026-07-19 |
| 仓库发版脚本 | scripts/release.sh | release_version() | stable | 2026-07-19 |
| GitHub Release workflow | .github/workflows/release.yml | package_release() | stable | 2026-07-19 |
| CI 检查 workflow | .github/workflows/ci.yml | run_ci_checks() | stable | 2026-07-19 |
| 引擎文件系统契约文档 | ENGINE_FILE_SYSTEM_v5.md | fs_contract_doc() | stable | 2026-07-19 |
| 安装脚本 | install.sh | install_engine() | stable | 2026-07-19 |
| 安装脚本 ps1 | install.ps1 | Install-Engine() | stable | 2026-07-19 |
| Git 属性配置 | .gitattributes | git_attr_config() | stable | 2026-07-19 |
| 仓库发布门禁 ps1 | scripts/check.ps1 | Run-AllChecks() | stable | 2026-07-19 |
| 引擎健康检查契约 | engine/ENGINE_DOCTOR.md | doctor_contract() | stable | 2026-07-19 |
| 引擎文件地图 | engine/ENGINE_MAP.md | engine_map_index() | stable | 2026-07-19 |
| 项目状态面板 | engine/CONTEXT.md | status_panel() | stable | 2026-07-19 |
| 会话交接 | engine/HANDOFF.md | handoff_resume() | stable | 2026-07-19 |
| 引擎初始化命令 | plugin/.claude/commands/engine-init.md | engine_init_cmd() | stable | 2026-07-19 |
| 插件清单 | plugin/manifest.json | plugin_manifest() | stable | 2026-07-19 |
| 契约减法预算 | contract/budget.json | contract_budget() | stable | 2026-07-19 |
| 运行时法则 | runtime-law.md | runtime_law() | stable | 2026-07-19 |
| Agent 前言 | contract/src/agent-preamble.md | agent_preamble() | stable | 2026-07-19 |
| Git 忽略配置 | .gitignore | git_ignore_config() | stable | 2026-07-19 |
| Claude hook 配置 | .claude/settings.json | claude_hook_settings() | stable | 2026-07-19 |
| engine-sync 命令 | .claude/commands/engine-sync.md | engine_sync_cmd() | stable | 2026-07-19 |
| 文件模板契约源 | contract/src/20-file-templates.md | file_templates_src() | stable | 2026-07-19 |
| 运营契约源 | contract/src/30-operational.md | operational_src() | stable | 2026-07-19 |
| Handoff 行为契约 | contract/src/behaviors/handoff.md | handoff_behavior() | stable | 2026-07-19 |
