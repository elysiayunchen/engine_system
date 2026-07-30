# INVENTORY — engine-runtime
> Last updated: 2026-07-30 | 域级功能索引 | 5 列 ≤120 行,见 contract/src/20-file-templates.md FILE 14

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
| 安装脚本 | install.sh | install_engine() | stable | 2026-07-23 |
| 安装脚本 ps1 | install.ps1 | Install-Engine() | stable | 2026-07-23 |
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
| 核心契约源(Hard Rules) | contract/src/00-core.md | core_rules_src() | stable | 2026-07-26 |
| 运营契约源 | contract/src/30-operational.md | operational_src() | stable | 2026-07-19 |
| Handoff 行为契约 | contract/src/behaviors/handoff.md | handoff_behavior() | stable | 2026-07-19 |
| Task-run 行为契约 | contract/src/behaviors/task-run.md | task_run_behavior() | stable | 2026-07-20 |
| Verify-writeback 行为契约 | contract/src/behaviors/verify-writeback.md | verify_writeback_behavior() | stable | 2026-07-20 |
| checkpoint dedup 测试 | tests/workstream/test_checkpoint_dedup.sh | test_checkpoint_dedup() | stable | 2026-07-22 |
| checkpoint dedup 测试 ps1 | tests/workstream/test_checkpoint_dedup.ps1 | Test-CheckpointDedup() | stable | 2026-07-22 |
| pre-commit 自身豁免测试 | tests/workstream/test_precommit_self_exempt.sh | test_precommit_self_exempt() | stable | 2026-07-22 |
| YAML frontmatter parser 测试 | tests/workstream/test_precommit_yaml_frontmatter.sh | test_precommit_yaml_frontmatter() | stable | 2026-07-23 |
| legacy fallback 移除测试 | tests/workstream/test_precommit_no_legacy_fallback.sh | test_precommit_no_legacy_fallback() | stable | 2026-07-23 |
| CI sessions 降级测试 | tests/workstream/test_doctor_ci_sessions.sh | test_doctor_ci_sessions() | stable | 2026-07-23 |
| task-card 门禁测试套件 | tests/task-card/run-task-tests.sh | run_task_tests() | stable | 2026-07-23 |
| 多会话隔离测试套件 (v6.12.0) | tests/multi-session/run-multi-session-tests.sh | run_multi_session_tests() | stable | 2026-07-26 |
| pre-commit 多卡 union 测试 | tests/task-card/test_multi_active_union.sh | test_multi_active_union() | stable | 2026-07-26 |
| Doctor 多卡 WRITE-SET 交集检查 | engine/scripts/engine-doctor.sh | check_multi_card_writeset_overlap() | stable | 2026-07-26 |
| Doctor 多卡交集检查 ps1 | engine/scripts/engine-doctor.ps1 | Test-MultiCardWritesetOverlap() | stable | 2026-07-26 |
| Doctor 状态冲突检查 (v6.12.1) | engine/scripts/engine-doctor.sh | check_status_conflict() | stable | 2026-07-26 |
| verify 解析硬化测试组 (v6.12.1) | tests/behavior-verify/test_verify_allskip_loud.sh | test_verify_allskip_loud() | stable | 2026-07-26 |
| hook frontmatter 解析测试 (v6.12.1) | tests/multi-session/test_hook_frontmatter_writeset.sh | test_hook_frontmatter_writeset() | stable | 2026-07-26 |
| migrator 版本源测试 (v6.12.1) | tests/update-flow/test_migrator_version_source.sh | test_migrator_version_source() | stable | 2026-07-26 |
| tombstone 生命周期测试 (v6.12.2) | tests/multi-session/test_tombstone_lifecycle.sh | test_tombstone_lifecycle() | stable | 2026-07-28 |
| pre-commit dist-stale 门禁 (v6.12.3) | engine/scripts/githooks/pre-commit | check_dist_stale() | stable | 2026-07-28 |
| dist-stale 门禁测试 (v6.12.3) | tests/workstream/test_precommit_dist_stale.sh | test_precommit_dist_stale() | stable | 2026-07-28 |
| .engineignore 旁路通道 (v6.13.0) | engine/scripts/githooks/pre-commit | is_engineignored() | stable | 2026-07-29 |
| .engineignore 旁路测试 (v6.13.0) | tests/workstream/test_precommit_engineignore.sh | test_precommit_engineignore() | stable | 2026-07-29 |
| Doctor .engineignore 告警 (v6.13.0) | engine/scripts/engine-doctor.sh | check_engineignore() | stable | 2026-07-29 |
| .engineignore 配置 | .engineignore | engineignore_config() | stable | 2026-07-29 |
| engine-verify env cleanup 测试 (v6.13.1) | tests/workstream/test_engine_verify_env_cleanup.ps1 | test_engine_verify_env_cleanup() | stable | 2026-07-29 |
| engine-verify env cleanup 测试 runner (v6.13.1) | tests/workstream/test_engine_verify_env_cleanup.sh | test_engine_verify_env_cleanup_sh() | stable | 2026-07-29 |
| done-card drift AC PASS 测试 (v6.14.0) | tests/workstream/test_precommit_done_card_drift.sh | test_precommit_done_card_drift() | stable | 2026-07-29 |
| engine-verify bash 检测测试 (v6.14.0) | tests/workstream/test_engine_verify_bash_detection.ps1 | test_engine_verify_bash_detection() | stable | 2026-07-29 |
| engine-verify bash 检测测试 runner (v6.14.0) | tests/workstream/test_engine_verify_bash_detection.sh | test_engine_verify_bash_detection_sh() | stable | 2026-07-29 |
| closing_paths HEAD 已 done 跳过 (v6.17.4) | engine/scripts/githooks/pre-commit | closing_paths() | stable | 2026-07-30 |
| done-card governing closing_paths 测试 (v6.17.4) | tests/workstream/test_precommit_done_card_governing.sh | test_precommit_done_card_governing() | stable | 2026-07-30 |
| drift-check 三步校验 (v6.18.0) | engine/scripts/engine-drift-check.sh | run_drift_check() | stable | 2026-07-30 |
| drift-check 三步校验 ps1 (v6.18.0) | engine/scripts/engine-drift-check.ps1 | Run-DriftCheck() | stable | 2026-07-30 |
| drift-check 测试套件 (v6.18.0) | tests/workstream/test_drift_check.sh | test_drift_check() | stable | 2026-07-30 |
| evidence provenance 测试套件 (v6.18.0) | tests/workstream/test_evidence_provenance.sh | test_evidence_provenance() | stable | 2026-07-30 |
| behavior verify 测试 runner (v6.18.0) | tests/behavior-verify/run-verify-tests.sh | run_verify_tests() | stable | 2026-07-30 |
