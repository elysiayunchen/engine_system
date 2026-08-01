# Engine System — Review from workstream receipt (v6.24.0, D-041/issue #29)
# PowerShell mirror of engine-review-from-receipt.sh
#
# Converts a D-009 workstream reviewer receipt into canonical REVIEW.json.
# Usage: engine review T-NNN --from-receipt <agent-id>
# Exit codes: 0=converted | 1=receipt invalid/missing | 2=usage error

param(
  [string]$Task = "",
  [string]$AgentId = ""
)

$ErrorActionPreference = "Stop"
$Root = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { $PWD.Path }
$EngineDir = Join-Path $Root "engine"

if (-not $Task -or -not $AgentId) {
  Write-Error "Usage: engine review T-NNN --from-receipt <agent-id>"
  exit 2
}

$taskFile = Join-Path $EngineDir "tasks\$Task.md"
if (-not (Test-Path $taskFile)) {
  Write-Error "[engine-review-receipt] Error: task card not found: $taskFile"
  exit 2
}

$receiptFile = Join-Path $EngineDir "workstreams\$Task\agents\$AgentId\REVIEW-RECEIPT.json"
if (-not (Test-Path $receiptFile)) {
  Write-Error "[engine-review-receipt] Error: receipt not found: $receiptFile"
  exit 1
}

$receipt = Get-Content $receiptFile -Raw -Encoding UTF8 | ConvertFrom-Json

if (-not $receipt.status) {
  Write-Error "[engine-review-receipt] Error: receipt missing 'status' field"
  exit 1
}
if ($receipt.status -ne "pass") {
  Write-Error "[engine-review-receipt] Error: receipt status='$($receipt.status)' (only 'pass' can be converted)"
  exit 1
}
if ($receipt.task -and $receipt.task -ne $Task) {
  Write-Error "[engine-review-receipt] Error: receipt task='$($receipt.task)' does not match requested '$Task'"
  exit 1
}

$headCommit = git rev-parse HEAD 2>$null
if (-not $headCommit) {
  Write-Error "[engine-review-receipt] Error: cannot determine HEAD commit"
  exit 1
}

$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$reviewer = if ($receipt.reviewer) { $receipt.reviewer } else { $AgentId }
$summary = if ($receipt.summary) { $receipt.summary } else { "" }
$receiptPath = "engine/workstreams/$Task/agents/$AgentId/REVIEW-RECEIPT.json"

$evidenceDir = Join-Path $EngineDir "review\evidence\$Task"
if (-not (Test-Path $evidenceDir)) { New-Item -ItemType Directory -Path $evidenceDir -Force | Out-Null }

$data = @{
  task = $Task
  timestamp = $timestamp
  status = "pass"
  source = "workstream-receipt"
  receipt = @{
    agent_id = $AgentId
    reviewer = $reviewer
    summary = $summary
    path = $receiptPath
  }
  diff = @{ strategy = "receipt"; base_commit = ""; head_commit = $headCommit; files_reviewed = @(); files_skipped = @(); diff_empty = $true }
  dimensions = @{
    security = @{ status = "not_applicable"; findings_count = @{}; tool_version = "" }
    quality = @{ status = "not_applicable"; findings_count = @{}; tool_version = "" }
  }
  severity_threshold = "N/A"
  tool_unavailable = $false
  write_provenance = @{
    writer = "engine-review-from-receipt"
    commit = $headCommit
    timestamp = $timestamp
    argv = "engine review $Task --from-receipt $AgentId"
    pipeline_version = "v6.24.0"
  }
}

$json = $data | ConvertTo-Json -Depth 5 -Compress
Set-Content -Path (Join-Path $evidenceDir "REVIEW.json") -Value $json -Encoding UTF8 -NoNewline

Write-Host "[engine-review-receipt] ${Task}: converted receipt from $AgentId -> $evidenceDir\REVIEW.json"
Write-Host "[engine-review-receipt] writer=engine-review-from-receipt commit=$headCommit"
