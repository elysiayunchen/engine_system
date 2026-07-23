# progress — [Task ID: T-042] 修复 issue #9 LF-only engine.ps1 PS 5.1 解析失败
> Last updated: 2026-07-23 | 任务级压缩恢复锚点 | 7 栏事件驱动更新,见 contract/src/20-file-templates.md FILE 13
> 小任务豁免(v6.11.3/T-040):estimated_steps=6 ≤ 10, checkpoint_plan=inline → 仅 §1+§4 必填,§2/§3/§5/§6/§7 写 n/a (small task exempt) 占位

## §1 已读文件（理解项目）
- install.ps1 — 安装器,Download-File L47-62 用 Invoke-WebRequest -OutFile 直写字节(LF 保持);Get-NormalizedTextSha256 L83-98 strip CRLF→LF 算 hash(checksum 兼容);settings.json 生成走 Set-Content -Encoding UTF8 L324(PS 5.1 默认 CRLF);PATH shim L336 Copy-Item 字节级复制
- engine/bin/engine.cmd — CLI shim,L4 写死 `powershell -NoProfile -ExecutionPolicy Bypass -File`,无 pwsh 检测;三处镜像(engine/bin + plugin/bin + plugin/engine/bin)内容一致
- engine/bin/engine.ps1 — 30255 字节,CRLF=0 LF=727 CR=0 无 BOM;3 个 here-string(L20/323/351);issue 报错 183/268 是 PS 5.1 误数后的错位行号
- .gitattributes — L27-28 钉 `engine/bin/engine.ps1 text eol=lf` + `plugin/bin/engine.ps1 text eol=lf`(D-015 跨平台一致策略);L3 `*.cmd text eol=crlf`(cmd.exe 需要 CRLF)
- engine/decisions/rules.json — protected_paths 含 install.ps1(L9)、.gitattributes(L11)、plugin/manifest.json(L10);engine/bin/engine.cmd 不在 protected
- engine/scripts/githooks/pre-commit — L209-255 protected 检查:T-041 任务卡自身豁免,其他 protected 路径需 decision scope 覆盖;D-030 scope 覆盖 install.ps1 + plugin/manifest.json
- install.ps1 字节级分析:install.ps1 自身 CRLF=0 LF=464(LF-only),但有 1 个 here-string(L264 settings.json 生成)却能跑完整个安装——证明 PS 5.1 对 LF-only here-string 解析 bug 是累积性行号错位(here-string 数量+首现位置决定何时炸),非 here-string 本身禁用

## §2 已确认接口（不重复读）
n/a (small task exempt)

## §3 已排除路径（原 TRAIL 的家）
n/a (small task exempt)

## §4 当前进行到（压缩恢复点）
T-042 全部完成,准备 commit:
- 6 ACs 全部 PASS:`engine verify T-042` 6/6 AC PASS,evidence/AC-1~6.json + checkpoint.md + DEAD-CODE.json + COPY-PASTE.json 已产出。
- check.sh CHECK PASSED(0 failures,4 非阻塞 WARN:HANDOFF 历史表已归档至 8 行合规 / T-042 WRITE-SET budget 91KB bypass checkpoint_plan / contract debt 54>47)。
- CONTEXT.md「上次完成」已推入 T-042;ENGINE_MAP.md revision 32→33 + 加 v6.11.4 行;HANDOFF.md 加 T-042 行 + 归档 3 行旧记录(2026-07-19 v6.7.0/T-032/v6.6.3)到 handoff-archive-2026-07.md 符合 D-027 8 行上限。
- T-041 post-done cleanup 一并完成(progress.md 归档 + INVENTORY 加 1 行 + DEAD-CODE exempt_all:true)。
- 任务卡 T-042.md status: active → done。

下一步:`git add <T-042 + T-041 cleanup 改动文件>` → `git commit`(可选 `git tag v6.11.4 && git push && git push --tags` 触发 GitHub Release workflow)→ 回复 GitHub issue #9。

## §5 待确认问题
n/a (small task exempt)

## §6 已知风险/未解 bug
n/a (small task exempt)

## §7 回滚尝试
n/a (small task exempt)
