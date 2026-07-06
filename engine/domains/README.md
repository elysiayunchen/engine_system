# Domains — 分形域引擎

> Engine System v6 S2 引入。空间分区 + 路由 + 汇总,回答百万行——每任务上下文 = f(任务),不是 f(仓库)。

## 目录结构

```
engine/domains/
  federation.json              # 联邦表:path-glob → domain
  <domain>/
    CONTEXT.md                 # 域级状态(首行 = 预算内摘要,提升到根仪表盘)
    PITFALLS.md                # 域级陷阱(每域自己的预算 + 归档 + 检索配方)
    decisions/                 # 域级决策(可选)
    tasks/                     # 域级任务(可选)
```

## 联邦表 federation.json

```json
{
  "domains": {
    "<domain>": {
      "paths": ["<glob>", "<glob>"],
      "summary": "<一句话域摘要>"
    }
  },
  "default_domain": "root"
}
```

路径不匹配任何域 glob → `default_domain`。glob 语法同 .gitignore(hook 用 `case` 模式匹配)。

## 路由 read-gate

任务卡 `domain:` 字段(逗号分隔) → 联邦表解析 → SessionStart 装配这些域的 L2(各 ≤300 行)。
Stop hook 校验:WRITE-SET 每条代码路径 → 联邦表 → 所属域必须 ∈ 任务卡 domain 集合。越域 = `decision:block`。

## 汇总协议

每个域 CONTEXT.md 首行(标题后第一段非空文本)是预算内摘要(≤120 字符)。SessionStart 提取所有域摘要拼成「域仪表盘」注入——根文件规模 = O(域数),不是 O(仓库)。

## 检索配方

PITFALLS 归档区在域内登记 rg recipe(如 `rg "panic" engine/domains/<d>/PITFALLS.md`),归档不再等于遗忘。每域 PITFALLS 自己的预算(无全局 500 行天花板),超限归档 + 指针。

## 域的划分

来自产品而非代码。INIT 采访加一问「你的项目分几大块?」——架构师答产品分区(登录/商城/后台……),agent 映射成 path-glob 并用人话回确认。
