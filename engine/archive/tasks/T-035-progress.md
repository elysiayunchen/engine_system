# progress — [Task ID: T-035] [verify 死代码检测 + done 门项 + v6.10.0]
> Last updated: 2026-07-20 | 任务级压缩恢复锚点 | 7 栏事件驱动更新,见 contract/src/20-file-templates.md FILE 13

## §1 已读文件（理解项目）
- engine/scripts/engine-verify.{sh,ps1} v6.9.0 checkpoint 实现(基线)
- engine/scripts/engine-doctor.{sh,ps1} v6.9.0 软门禁 + depends-on 实现(基线)
- contract/src/30-operational.md v6.9.0 状态(基线)
- D-028 §9 迁移宽限期 + §10 机制 B jscpd 委托 + Open Question #4 linter CI 可用性评估

## §2 已确认接口（不重复读）
- engine-verify.sh 已有 checkpoint 写入逻辑(line 88-108);死代码检测追加在 AC 循环后(line 119+)
- engine-doctor.sh 已有 contract-version 读取 + cv_int 比较 + WARN/FAIL 范式(可复用)
- compile.sh 已有 plugin 镜像同步机制(自动 backfill SHA256)

## §3 已排除路径（原 TRAIL 的家）
- 不自研 AST 解析器(D-028 §4 修订 4)
- 不引入运行时上下文预算感知(D-028 §4 不做项)
- 不覆盖语义级软死代码(D-028 §6 边界声明,留 T-033 INVENTORY 兜底)

## §4 当前进行到（压缩恢复点）
正在做:**T-035 done** — v6.10.0 发版完成,11/11 AC PASS。
- engine-verify.{sh,ps1} ×4 加 detect_dead_code + recursion guard(task-specific)
- engine-doctor.{sh,ps1} ×4 加 check_warn_done_gate
- engine-migrate-contract ×4 加 #16 heredoc
- ENGINE_DOCTOR.md contract-version 6.9.0→6.10.0 + #16
- budget.json 2730→2830;VERSION ×3 = 6.10.0;CHANGELOG 含 v6.10.0 段
- T-035 自身 DEAD-CODE.json warn_count=76 已 exempt_all 批量豁免
- 递归 guard bug 修复:`=1` → `=$task`(task-specific)
下一步:D-028 LPHP 路线 4 版本(v6.7.0~v6.10.0)全部完成;后续可考虑 patch 版本调整 linter 委托表或 jscpd 配置。

## §5 待确认问题
- 无 / 阻塞:无 / 提出:—

## §6 已知风险/未解 bug
- shellcheck 假阳性:既有 engine-doctor.sh / engine-migrate-contract.sh 的 SC2004/SC2034/SC2317 等 warning 是历史代码风格,非 T-035 引入。已用 exempt_all 批量豁免,后续 patch 可单独修复历史代码。

## §7 回滚尝试
- 无
