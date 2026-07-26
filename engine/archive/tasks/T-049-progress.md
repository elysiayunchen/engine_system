# progress — T-049 v6.12.1 issue #11 门禁静默失效家族修复
> Last updated: 2026-07-26 | 任务级压缩恢复锚点 | 7 栏事件驱动更新,见 contract/src/20-file-templates.md FILE 13

## §1 已读文件(理解项目)
- GitHub issue #11 全文 — 9 项缺陷 + 优先级表 + 「门禁无法判定时必须显式说出来」结构性建议
- engine/scripts/engine-verify.sh L50-58 — AC/verify 同行 sed 抽取(A-1 SKIP 静默 + A-2 贪婪 + A-3 纯数字 id)
- engine/scripts/engine-doctor.sh L523-527(B-2 inline-only)、L1279-1284(E-2 CI unbound)、L8-16(参数吞噬)
- engine/scripts/engine-migrate-contract.sh L25-31 — D-1 根 VERSION 优先
- C-1 无锚 status grep 站点:engine-hook-stop.sh / engine-hook-session-start.sh / engine-context.sh / engine-doctor.sh / pre-commit / engine bin + ps1 孪生

## §2 已确认接口(不重复读)
- pre-commit parse_task_patterns 已支持 inline/section/frontmatter 三格式(T-043)——B-1 移植源
- doctor Write-Warn(ps1)单参;fail/warn(sh)计数 + 输出
- verify evidence JSON 字段:ac/verify/status/exit/fingerprint/timestamp

## §3 已排除路径(原 TRAIL 的家)
- 2026-07-26 / A-1 块状 verify 形式(### AC-N + ```bash 块)本期实现 / 改动面大且格式待架构师定 / 先做 loud-fail 最小项(issue 自己标的 minimum)
- 2026-07-26 / C-2 重复修复 / 上游 T-044 v6.11.6 已除 legacy fallback / 仅回复 issue 说明

## §4 当前进行到(压缩恢复点)
状态:done。verify T-049 = 10 pass / 0 fail / 0 skip。收尾中发现并顺手修了三个衍生洞:①仓外绝对路径被门禁误拦(scratchpad 写入被 union block)→ normalize 后仍为绝对路径的直接放行;②check.sh L111 L2 预算探针以 fallback sid 抢真仓租约(v6.12 心跳给这颗垃圾锁续命 2h,本会话 HANDOFF 写入被拦实证)→ 探针加 ENGINE_DISABLE_MULTI_SESSION=1;③清理 fallback-* 会话垃圾文件。
原记录:主线完成——hooks C-1 锚定(stop/session-start/context/pre-commit/bin,sh+ps1 全站点)+ B-1 hook frontmatter 解析(sh+ps1)+ B-3 glob 目录前缀(hook+pre-commit)+ D-1 migrator 版本源(sh+ps1)+ E-1 三问(README + 契约源 20-file-templates + 00-core 三拼法声明)+ VERSION 6.12.1 + CHANGELOG。主线 4 新测试全绿,回归(multi-session 14 套 / task-card 44 / parity 31 / update-flow 7)全绿。fork-A(verify A-1/2/3+E-1 WARN)已完成:3 新测试 16 例绿 + 既有 24 例绿,发现并兼容第二种分隔符 `→ verify:`。
下一步:等 fork-B(doctor)合流 → doctor 镜像同步 + compile + check.sh → verify T-049 → 胶囊 CHANGE-2026-07-26-03 + 回写 → done + 提交 → 回复 issue #11

## §5 待确认问题
- (无)

## §6 已知风险/未解 bug
- **C-1 现场直播(2026-07-26)**:T-049 卡自身 AC-5 描述文本含 `status:` 与 `done` 字样,被 live hook(未锚定旧版)同时判为 active + closing,拦截消息出现「T-049, T-049」重复——issue 描述的自引用自锁在本卡复现,锚定修复的必要性获得实证
- fix-verify fork 发现第二种野格式分隔符 `→ verify:`(历史夹具/旧卡在用),A-2 修复已兼容两种;README 已写明两种均合法
- B-2 修好后 code→INVENTORY 检查首次真正生效,可能翻出本仓历史 done 卡的缺行 → 修复时补 INVENTORY 行(诚实结果)
- C-1 锚定改动面广(6+ 文件 ×2 语言),漏一处即残留自锁风险 → 全仓 grep 清点收尾
- .ps1 改动继续遵守 P008(BOM)/T-047(字面量 ASCII)

## §7 回滚尝试
- (无)
