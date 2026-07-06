# CLAUDE.md — Engine System (engine_system)

> 项目级 bootloader。权威规则在 `AGENTS.md`(正本)与引擎文件;本文件只是 import 引用,不重复规则。

See [AGENTS.md](AGENTS.md) for the full session protocol, v6 mechanism summary, and entry points.

## Quick Start

1. 读 `engine/ENGINE_MAP.md` → `engine/CONTEXT.md` → active 任务卡(`engine/tasks/T-NNN.md`)
2. 改动须在任务卡 WRITE-SET 内 ∉ FORBIDDEN
3. 改契约改 `contract/src/*.md` 后 `bash contract/compile.sh`
4. 完成跑 `engine verify T-NNN`(行为化验收)
5. 提交前 `bash scripts/check.sh`

## v6 一句话

agent 常驻 ≤400 行(L0 宪法 + L1 任务卡 + L2 所属域),其余由机器按数据校验:规则在数据表,记忆分形分区,架构师用决策治理,完成有行为证据。
