# Engine System — SessionStart hook · "自动接手" (PowerShell)
#
# PowerShell 双版本，与 engine-hook-session-start.sh 契约一致。
# 用于 Windows 上 Claude Code 以 PowerShell 执行 hook 的场景。
#
# 安全契约:只读。不写引擎文件、不碰代码、不联网。任何失败都绝不致命。

param()

$Root = $env:CLAUDE_PROJECT_DIR
if (-not $Root) { $Root = $PWD.Path }
$EngineDir = Join-Path $Root "engine"

if (-not (Test-Path $EngineDir)) {
  Write-Output "【Engine System】未检测到 engine/ 目录。建议运行 /engine-init 生成项目记忆层。"
  exit 0
}

Write-Output "【Engine System · 自动接手】下面是项目记忆当前快照。请先用一句简体中文复述当前状态,再开始工作。"
Write-Output ""

$ContextFile = Join-Path $EngineDir "CONTEXT.md"
if (Test-Path $ContextFile) {
  Write-Output "──── 当前状态 (engine/CONTEXT.md) ────"
  Get-Content $ContextFile -TotalCount 50 | ForEach-Object { Write-Output $_ }
  Write-Output ""
}

$HandoffFile = Join-Path $EngineDir "HANDOFF.md"
if (Test-Path $HandoffFile) {
  Write-Output "──── 上次交接 (engine/HANDOFF.md，最新在上) ────"
  Get-Content $HandoffFile | Select-String '^\|' | Select-Object -First 4 | ForEach-Object { Write-Output $_.Line }
  Write-Output ""
}

$PendingFile = Join-Path $EngineDir ".cache/pending.txt"
if (Test-Path $PendingFile) {
  Write-Output "──── ⚠️ 上次会话遗留待办 ────"
  Get-Content $PendingFile | ForEach-Object { Write-Output $_ }
  Write-Output ""
}

exit 0
