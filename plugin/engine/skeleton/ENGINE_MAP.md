# ENGINE_MAP — 引擎索引

> ⚠️ 空模板。引擎已安装但尚未初始化。运行 `/engine-init` 或 `engine init` 后本文件将由 agent 填充。

## 0. Profile（介质配置）

> 决定 agent 信任谁、加载谁、现生谁。切换介质只改本节。

| 字段 | 值 | 说明 |
|------|-----|------|
| Active profile | WEB-FULL | 默认 profile;init 后可切换为 CLI-LEAN |
| 现生来源 (regen source) | SOURCEMAP | init 后按项目实际情况调整 |
| Regen 命令前缀 | rg / ls / cat | 重建 derivable 内容时允许的只读命令 |
| Derivable cache policy | none | init 后按需配置 |

## 1. 文件注册表 (File Registry)

> 核心引擎文件预注册(install + migrate 后磁盘即存在)。init 后追加项目专属文件。

| File | Class | Read priority | Revision | Last verified |
|------|-------|---------------|----------|---------------|
| ENGINE_MAP.md | index | 0 | 1 | 未初始化 |
| SYSTEM.md | irreducible | 1 | 1 | 未初始化 |
| CONTEXT.md | irreducible | 2 | 1 | 未初始化 |
| HANDOFF.md | irreducible | 3 | 1 | 未初始化 |
| ENGINE_DOCTOR.md | irreducible | 3.25 | 1 | 未初始化 |
| GLOSSARY.md | irreducible | 6 | 1 | 未初始化 |

## 下一步

- **Claude Code**:运行 `/engine-init`
- **其他 agent / 终端**:运行 `engine init`

初始化后本文件将由 agent 填充为完整项目索引(联邦表 + plan 注册表 + 关系图)。
