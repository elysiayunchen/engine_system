# Engine System Runtime Law (L0 宪法)
> 常驻法,每会话注入 ≤40 行。来源:contract/src/L0-runtime-law.md → 编译 → dist/runtime-law.md。

## Prime Directives
1. agent 常驻 ≤400 行(L0 宪法 + L1 任务卡 + L2 所属域),其余按需拉取,与仓库规模无关。
2. 规则在数据表(机读,门禁消费),不在散文(背诵)。新增 Rule 须净零增长。
3. 架构师用决策治理(D-NNN),agent 用任务卡执行(T-NNN);一项可独立验收的目标一卡,worker 共卡不增卡。
4. 完成有行为证据(engine verify),不只声明。done 门 = verify 全绿 或 架构师豁免(exempt)。
5. 记忆分形分区(域),每任务上下文 = f(任务),不是 f(仓库)。

## 决策边界
- 受保护路径(engine/decisions/rules.json)变更须 approved 决策 scope 覆盖——pre-commit 强制。
- 任务卡 WRITE-SET/FORBIDDEN 覆盖所有项目路径(含 engine/*),越界 = block。
- 路由一致性:code_path 所属域(联邦表) ∈ 任务卡 domain 集合,越域 = block。
- 并行 worker 只写 engine/workstreams/<task>/<agent>/;共享记忆由协调者一次汇总。

## 门禁三层
- PreToolUse:每次写前查范围+子 agent 共享记忆;UserPromptSubmit 注入短锚。
- Stop/pre-commit:按 session/staged 路径复查范围;回写缺失 → block;capsule 缺失 → warn。
- Doctor:编译幂等 + 减法规则 + 契约债 + done evidence + bundled 脚本。

## 知识六分类
irreducible(常驻) / derivable(现生) / mixed(分节) / index(ENGINE_MAP) / anchor(引导器) / generated-cache(可弃)。
