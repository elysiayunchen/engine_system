# Engine System — Review CLI 入口(v6.20.0)
#
# 跑 post-task 代码 review(semgrep + eslint),产 REVIEW/SECURITY/QUALITY evidence。
# 必须在 engine verify T-NNN PASS 之后调用。
#
# 用法:engine review T-NNN (via engine.ps1)
# 安全:review 命令由任务卡声明;用户主动跑,非 hook 自动。

$ErrorActionPreference = "Stop"

$ROOT = $env:CLAUDE_PROJECT_DIR
if (-not $ROOT) { $ROOT = (Get-Location).Path }
$ENGINE_DIR = Join-Path $ROOT "engine"
$task = $args[0]

if (-not $task) {
  Write-Error "Usage: engine review T-NNN"
  exit 2
}

$taskFile = Join-Path $ENGINE_DIR "tasks\$task.md"
if (-not (Test-Path $taskFile)) {
  Write-Error "[engine-review] Error: task card not found: $taskFile"
  exit 2
}

$pipeline = Join-Path $ENGINE_DIR "scripts\engine-review-pipeline.ps1"
& $pipeline $task
exit $LASTEXITCODE
