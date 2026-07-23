# progress — [Task ID: T-047] [Windows PS 5.1 compat: engine.ps1 + engine-verify.ps1 non-ASCII in string literals]
> Last updated: 2026-07-23 | 任务级压缩恢复锚点 | 7 栏事件驱动更新,见 contract/src/20-file-templates.md FILE 13

## §1 已读文件（理解项目）
- scripts/check.ps1 — Test-WindowsPowerShellCompatibility 用 PS 5.1 Parser.ParseFile 解析所有 .ps1,无 BOM 时按 Windows-1252 读取
- engine/bin/engine.ps1 — L537 em-dash (U+2014) UTF-8 E2 80 94,byte 0x94=Win-1252 左弯引号,在字符串字面量中提前终止 string
- engine/scripts/engine-verify.ps1 — L117 Chinese 锚(U+951A) UTF-8 E9 94 9A 含 byte 0x94;L122 em-dash 同理
- install.ps1 — 参照基线:ASCII-only (nonASCII=0) PASS compat check

## §2 已确认接口（不重复读）
- n/a (small task exempt)

## §3 已排除路径（原 TRAIL 的家）
- n/a (small task exempt)

## §4 当前进行到（压缩恢复点）
正在做:4 文件改完(engine.ps1 + engine-verify.ps1 × 2 mirrors) + drive-by fix engine-doctor.sh xargs quote bug (L308 xargs→sed trim,triggered by CONTEXT.md 含双引号)。synced byte-identical,check.sh 全绿,待 commit + push 验证 CI Windows 转绿
下一步:commit → push → 观察 GitHub Actions Windows job

## §5 待确认问题
- n/a (small task exempt)

## §6 已知风险/未解 bug
- n/a (small task exempt)

## §7 回滚尝试
- n/a (small task exempt)
