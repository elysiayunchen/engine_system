# project-meta — 域状态

> 项目运营记忆:任务 / 决策 / 变更 / 规划 / 测试 —— 引擎吃自己的狗粮。

## 当前状态

| 维度 | 状态 |
|------|------|
| 任务卡 | T-001(S1,done) / T-002(S2,active) |
| 决策 | D-001(v6 路线 A→B,approved) / D-002(S2 分形记忆,approved) |
| 受保护路径 | engine/decisions/rules.json 声明;pre-commit 校验决策引用 |
| 变更胶囊 | CHANGE-2026-07-03-01(S0) / -02(S1) / -03(S2,待写) |
| 测试 | tests/hook-parity + tests/task-card + tests/fractal-memory(S2 新增) |

## 关键文件

- `engine/tasks/T-NNN.md` — 任务卡(WRITE-SET/FORBIDDEN/AC+verify)
- `engine/decisions/D-NNN.md` — 决策台账(status/scope/expiry)
- `engine/decisions/rules.json` — 受保护路径声明
- `engine/domains/federation.json` — 联邦表(S2)
- `engine/changes/CHANGE-*.md` — 变更胶囊
- `engine/ENGINE_MAP.md` — 引擎索引 + 联邦表段(S2)
- `docs/superpowers/specs/2026-07-03-engine-v6-direction-design.md` — v6 方向设计

## 域约束

- 受保护路径变更须引用 approved 决策(N2)
- 每个 done 的 AC 须有 verify 证据或架构师豁免(N3)
- 任务卡 WRITE-SET 须与联邦表域一致(S2 路由校验)
