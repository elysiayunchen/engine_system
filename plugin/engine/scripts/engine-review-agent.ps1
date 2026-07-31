# Engine System — Agent-Reviewer CLI entry (v6.21.0) [PowerShell behavioral mirror]
#
# Two atomic commands:
#   engine review-agent T-NNN --package   -> package review context
#   engine review-agent T-NNN --validate  -> validate agent output
#
# No mode flag -> exit 2 + usage (consistent with engine review)

param(
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Args
)

$ErrorActionPreference = 'Stop'
$ROOT = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { Get-Location }
$ENGINE_DIR = Join-Path $ROOT 'engine'

function Show-Usage {
    [Console]::Error.WriteLine(@"
Usage: engine review-agent T-NNN --package
       engine review-agent T-NNN --validate

Modes (exactly one required):
  --package   Package review context (diff + task card + protocol + challenges)
              Output: engine/review/evidence/T-NNN/review-package.md
  --validate  Validate agent-produced AGENT-REVIEW.json
              Requires: AGENT-REVIEW.json already written by external agent

Exit codes: 0=success | 1=validation failure | 2=usage error
"@)
}

$task = ''
$mode = ''
$modeCount = 0
foreach ($arg in $Args) {
    switch -Regex ($arg) {
        '^--package$'  { $mode = 'package'; $modeCount++ }
        '^--validate$' { $mode = 'validate'; $modeCount++ }
        '^T-\d+'      { $task = $arg }
        default {
            [Console]::Error.WriteLine("[engine-review-agent] Unknown argument: $arg")
            Show-Usage
            exit 2
        }
    }
}

if ($modeCount -gt 1) {
    [Console]::Error.WriteLine("[engine-review-agent] Error: --package and --validate are mutually exclusive")
    Show-Usage
    exit 2
}

if (-not $task) {
    [Console]::Error.WriteLine("[engine-review-agent] Error: task ID required (e.g. T-071)")
    Show-Usage
    exit 2
}

if (-not $mode) {
    [Console]::Error.WriteLine("[engine-review-agent] Error: mode flag required (--package or --validate)")
    Show-Usage
    exit 2
}

$taskFile = Join-Path $ENGINE_DIR "tasks/$task.md"
if (-not (Test-Path $taskFile)) {
    [Console]::Error.WriteLine("[engine-review-agent] Error: task card not found: $taskFile")
    exit 2
}

switch ($mode) {
    'package' {
        $script = Join-Path $ENGINE_DIR 'scripts/engine-review-agent-package.ps1'
        & $script $task
        exit $LASTEXITCODE
    }
    'validate' {
        $script = Join-Path $ENGINE_DIR 'scripts/engine-review-agent-validate.ps1'
        & $script $task
        exit $LASTEXITCODE
    }
}
