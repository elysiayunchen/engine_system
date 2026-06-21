# AGENT ADAPTERS — 跨 Agent 自维护适配

> Engine System (engine_system) · Last updated: 2026-06-21
> 说明：本文件记录当前仓库 dogfood 的跨 agent 自维护策略。完整模板见 `plugin/engine/AGENT_ADAPTERS.md`。

## 三层策略

| 层 | 机制 | 当前状态 |
|----|------|----------|
| A · 锚点契约 | AGENTS.md / CLAUDE.md 要求 read-gate + 增量回写 | 已在 plugin 模板强化 |
| B · git pre-commit | 提交前检查「代码改动是否伴随引擎回写」 | 脚本已随 install 分发，并补安装到 `.git/hooks/pre-commit` 的逻辑 |
| C · 原生 hook | SessionStart 自动接手；Stop 拦截漏写回；SessionEnd Doctor 缓存 | Claude Code settings 已挂三段 hook |

## 当前决策

- Web 端没有 hook，靠 A 层契约执行：每完成一个有意义单元，立即更新 `CONTEXT.md` 与 `HANDOFF.md`。
- CLI agent 优先享受 C 层体验，但不能依赖单一工具；B 层 git hook 是最大公约数。
- 跨 agent 引导文件由 `engine-sync-agent-anchors.{sh,ps1}` 生成薄托管块，用户手写规则必须先吸收进引擎权威文件，再清理锚点。

## 下一步

- 合并后跑 `/engine-sync`，把新脚本分发到真实用户项目。
- 后续用 `/engine-reconcile` 补齐 dogfood 实例的完整 v5.5 注册表。
