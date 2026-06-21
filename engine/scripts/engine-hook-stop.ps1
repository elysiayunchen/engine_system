# Engine System - Stop hook (PowerShell)
#
# PowerShell version matching engine-hook-stop.sh.
# Gatekeeper: if code changed without engine write-back, block once.
#
# Safety: read-only. Uses git status only.

param()

$Root = $env:CLAUDE_PROJECT_DIR
if (-not $Root) { $Root = $PWD.Path }
$EngineDir = Join-Path $Root "engine"

# Avoid loops: if this Stop follows a prior block, allow it.
$payload = $input | Out-String
if ($payload -match '"stop_hook_active"\s*:\s*true') {
  exit 0
}

# No engine layer: nothing to gate.
if (-not (Test-Path $EngineDir)) { exit 0 }

# Must be a git repo.
$gitFound = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitFound) { exit 0 }
Push-Location $Root
$inside = git rev-parse --is-inside-work-tree 2>$null
Pop-Location
if ($inside -ne "true") { exit 0 }

Push-Location $Root
$status = git status --porcelain 2>$null
Pop-Location
if (-not $status) { exit 0 }   # Clean worktree or pure Q&A.

$codeChanged = $false
$engineWritten = $false

foreach ($line in $status) {
  if (-not $line) { continue }
  $path = $line.Substring(3)
  # Rename: use the target path.
  $idx = $path.IndexOf(" -> ")
  if ($idx -gt 0) { $path = $path.Substring($idx + 4) }
  $path = $path.Trim()

  switch -Wildcard ($path) {
    "engine/CONTEXT.md"   { $engineWritten = $true }
    "engine/HANDOFF.md"   { $engineWritten = $true }
    "engine/ENGINE_MAP.md" { $engineWritten = $true }
    "engine/.cache/*"     { }
    ".engine/*"           { }
    "engine/*"            { }
    default               { $codeChanged = $true }
  }
}

# Gate: code changed but engine memory was not updated.
if ($codeChanged -and -not $engineWritten) {
  $reason = "[Engine System gatekeeper] Code changed, but engine memory was not updated. Before stopping, update engine/CONTEXT.md and append a HANDOFF.md row with what changed, next step, and touched files."
  Write-Output "{`"decision`":`"block`",`"reason`":`"$reason`"}"
  exit 0
}

exit 0
