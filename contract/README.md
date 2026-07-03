# Contract — 契约编译（v6 S3）

> 契约从「agent 背诵的散文单体」变成「机器编译产物」。src 是唯一真相源,dist 是编译产出,check 校验幂等——拆掉复杂度棘轮。

## 结构

```
contract/
  src/00-core.md              # 核心规则(知识分类/语言/Profile/锚点/MODE DISPATCH)
  src/10-interview.md         # 采访 + PHASE 1-4
  src/20-file-templates.md    # 文件模板(ENGINE_MAP/CONTEXT/PITFALLS/...)
  src/30-operational.md       # 运维模式 + SPEC TWIN
  compile.sh / compile.ps1    # 编译器:src + 横幅 → dist
  budget.json                 # 减法规则基线(行数 + Rule 数)
```

## 编译流程

```bash
bash contract/compile.sh        # 或: pwsh -File contract/compile.ps1
# 产出: ENGINE_FILE_SYSTEM_v5.md = 编译横幅 + contract/src/ENGINE_FILE_SYSTEM.md
```

## 减法规则（反棘轮）

`budget.json` 记录基线行数与 Rule 数。`scripts/check.sh` 校验:
- **编译幂等**:`compile(src) == dist`——dist 必须由 src 编译产出,手改 dist 会被检出。
- **行数预算**:`wc -l src ≤ budget.max_lines`——新增 Hard Rule 必须净零增长(删并等量旧散文)。

## 编辑契约

**改 src,不改 dist**。改完 `bash contract/compile.sh` 重新编译,然后 `bash scripts/check.sh` 验证。新增 Rule 时,若 src 行数超基线,必须删并等量旧散文,或显式提升基线(需决策背书)。

## 不分发

`contract/` 是引擎仓库自身的契约源(契约是引擎产品本身,非用户项目内容)。compile 脚本不入 plugin 分发——用户项目的契约是其自身的 `engine/AGENTS.md` 等,由 migrator 维护,不由本编译器产出。
