# engine-runtime — 域状态

> 引擎运行时:hook 门禁 / Doctor / 迁移器 / 契约脚本 —— 引擎产品本身,跨平台双实现(sh+ps1)。

## 当前状态

| 维度 | 状态 |
|------|------|
| 门禁 | S0 诚实门禁 + S1 三层(WRITE-SET/FORBIDDEN → 硬门禁回写 → capsule WARN)已落地;S2 加路由一致性 |
| 双实现等价 | tests/hook-parity(19/19) + tests/task-card(19/19) 守门 |
| 契约 | ENGINE_FILE_SYSTEM_v5.md(尾横幅去版本号);migrator contract-version: 5.7 |
| 分发 | install.sh/install.ps1 分发 hook+githook+settings.json;engine-hook.cmd 垫片修 Windows C 层 |

## 关键文件

- `plugin/engine/scripts/engine-hook-session-start.{sh,ps1}` — 自动接手 + S1 任务卡重注入 + S2 L2 装配
- `plugin/engine/scripts/engine-hook-stop.{sh,ps1}` — 三层门禁 + S2 路由一致性
- `plugin/engine/scripts/githooks/pre-commit` — B 层受保护路径决策引用门禁
- `plugin/engine/scripts/engine-doctor.{sh,ps1}` — 健康检查
- `plugin/engine/scripts/engine-migrate-contract.{sh,ps1}` — 旧项目契约迁移
- `ENGINE_FILE_SYSTEM_v5.md` — 唯一契约真相源
- `engine/scripts/` — 上述脚本的镜像树(check.ps1 用 SHA256 校验一致性)

## 域约束

- 双树镜像:engine/scripts/ 与 plugin/engine/scripts/ 必须逐字节一致
- sh/ps1 判定等价:同一 fixture 两实现裁决必须相同
- 任何门禁规则变更须同步:契约 + Doctor + 双实现 + 等价测试
