# Engine System — Stop hook · "收尾守门员" (PowerShell)
#
# PowerShell 双版本，与 engine-hook-stop.sh 契约一致。
# 硬门禁:改了代码没回写引擎记忆 → 拦截。幂等:同一轮最多拦一次。
#
# 安全契约:只读引擎文件;仅读取 git status。不写文件、不碰代码、不联网。

param()

$Root = $env:CLAUDE_PROJECT_DIR
if (-not $Root) { $Root = $PWD.Path }
$EngineDir = Join-Path $Root "engine"

# 防死循环:若本次 Stop 是上一次 block 触发的继续,直接放行。
$payload = $input | Out-String
if ($payload -match '"stop_hook_active"\s*:\s*true') {
  exit 0
}

# 没有引擎层 → 无可守门。
if (-not (Test-Path $EngineDir)) { exit 0 }

# 必须是 git 仓库。
$gitFound = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitFound) { exit 0 }
Push-Location $Root
$inside = git rev-parse --is-inside-work-tree 2>$null
Pop-Location
if ($inside -ne "true") { exit 0 }

Push-Location $Root
$status = git status --porcelain 2>$null
Pop-Location
if (-not $status) { exit 0 }   # 工作区干净(纯问答)→ 放行。

$codeChanged = $false
$engineWritten = $false

foreach ($line in $status) {
  if (-not $line) { continue }
  $path = $line.Substring(3)
  # 处理 rename:取箭头后的目标路径
  $idx = $path.IndexOf(" -> ")
  if ($idx -gt 0) { $path = $path.Substring($idx + 4) }
  $path = $path.Trim()

  switch -Wildcard ($path) {
    "engine/CONTEXT.md"   { $engineWritten = $true }
    "engine/HANDOFF.md"   { $engineWritten = $true }
    "engine/ENGINE_MAP.md" { $engineWritten = $true }
    "engine/.cache/*"     { }  # 缓存不计
    ".engine/*"           { }  # 缓存不计
    "engine/*"            { }  # 其它引擎文档不算"代码"
    default               { $codeChanged = $true }
  }
}

# 硬门禁:改了代码但没回写引擎记忆 → 拦截。
if ($codeChanged -and -not $engineWritten) {
  $reason = "【Engine System · 收尾守门员】本次会话改动了代码,但项目记忆(engine/CONTEXT.md / HANDOFF.md)还没同步。结束前请先增量回写:1) 更新 CONTEXT 状态面板的『上次完成』『进行中』;2) 在 HANDOFF 顶部追加一行交接(日期 | 做了什么 | 下一步 | 改动文件)。完成后即可结束。"
  Write-Output "{`"decision`":`"block`",`"reason`":`"$reason`"}"
  exit 0
}

exit 0
