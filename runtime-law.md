# Engine System Runtime Law (L0 宪法)
> 常驻法,每会话注入 ≤40 行。来源:contract/src/L0-runtime-law.md → 编译 → dist/runtime-law.md。

## Prime Directives
1. agent 常驻 ≤400 行(L0 宪法 + L1 任务卡 + L2 所属域),其余按需拉取,与仓库规模无关。
2. 规则在数据表(机读,门禁消费),不在散文(背诵)。新增 Rule 须净零增长。
3. 架构师用决策治理(D-NNN),agent 用任务卡执行(T-NNN)。受保护路径变更须 approved 决策。
4. 完成有行为证据(engine verify),不只声明。done 门 = verify 全绿 或 架构师豁免(exempt)。
5. 记忆分形分区(域),每任务上下文 = f(任务),不是 f(仓库)。

## 决策边界
- 受保护路径(engine/decisions/rules.json)变更须 approved 决策 scope 覆盖——pre-commit 强制。
- 任务卡 WRITE-SET/FORBIDDEN 机器校验,越界 = block。FORBIDDEN 是架构师否决权。
- 路由一致性:code_path 所属域(联邦表) ∈ 任务卡 domain 集合,越域 = block。

## 门禁三层
- Stop hook:WRITE-SET/路由/FORBIDDEN → block;回写缺失 → block;capsule 缺失 → warn。
- pre-commit:受保护路径须决策引用(active 或最新 done 任务卡的 decision)。
- Doctor:编译幂等 + 减法规则 + 契约债 + done evidence + bundled 脚本。

## 知识六分类
irreducible(常驻) / derivable(现生) / mixed(分节) / index(ENGINE_MAP) / anchor(引导器) / generated-cache(可弃)。
