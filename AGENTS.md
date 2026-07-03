# AGENTS.md — Engine System (engine_system)

> Bootloader / anchor (class: anchor). 唯一职责:把 agent 引到 ENGINE_MAP;进入代码包时先读包根 README 锚点。权威规则在引擎文件,不在这里。

## Session Protocol（强制）

1. **会话开始**:读 `engine/ENGINE_MAP.md`(索引 + 联邦表)→ `engine/CONTEXT.md`(当前状态)→ active 任务卡(`engine/tasks/T-NNN.md`)。SessionStart hook 自动注入。
2. **动工前**:确认本会话改动 ⊆ active 任务卡的 WRITE-SET ∉ FORBIDDEN。无 active 任务卡时回退 v5.6 行为(向后兼容)。
3. **改契约前**:改 `contract/src/*.md`(源模块),不改 `ENGINE_FILE_SYSTEM_v5.md`(dist)。改完 `bash contract/compile.sh` 重新编译。减法规则:新增 Rule 须净零增长。
4. **受保护路径**:改 `engine/decisions/rules.json` 声明的路径,须有 approved 决策(D-NNN)覆盖——pre-commit 强制(done fallback:无 active 时用最新 done 任务卡的 decision)。
5. **回写**:每完成一个有意义单元,增量更新 `engine/CONTEXT.md` + `engine/HANDOFF.md` 追加一行。代码改动不回写 → Stop hook 拦截。
6. **完成验证**:任务卡 AC 的 verify 命令,跑 `engine verify T-NNN` 机器执行,PASS/FAIL+指纹入 `engine/evidence/`。done 门 = verify 全绿 或 架构师豁免(豁免是决策)。

## v6 机制要点

- **S0 诚实门禁**:Stop hook porcelain -z + capsule WARN + engine-hook.cmd 垫片 + parity 等价测试。
- **S1 意图内核**:任务卡(WRITE-SET/FORBIDDEN 机器校验)+ 决策台账(受保护路径须引用 approved 决策)+ 三层门禁。
- **S2 分形记忆**:联邦表 `engine/domains/federation.json`(path-glob→domain)+ 域引擎 + 路由 read-gate + L2 装配 + 域仪表盘。
- **S3 契约编译**:`contract/src/*.md` → compile → dist 幂等 + 减法规则基线(`contract/budget.json`)。
- **S4 驾驶舱**:`engine verify T-NNN` 行为化验收 + `/engine-status` v2(决策队列 + 验收证据)。

## 入口

- 契约(唯一真相源):`ENGINE_FILE_SYSTEM_v5.md`(由 `contract/src/*.md` 编译产出,勿手改 dist)
- 索引:`engine/ENGINE_MAP.md`
- 当前状态:`engine/CONTEXT.md`
- 健康检查:`bash scripts/check.sh`(parity + task-card + fractal-memory + contract-compile + behavior-verify + 镜像)
- 驾驶舱:`/engine-status`
