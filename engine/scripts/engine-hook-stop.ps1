# Engine System - Stop hook (PowerShell)
#
# PowerShell twin of engine-hook-stop.sh. Decisions MUST stay identical to the
# .sh implementation - tests/hook-parity/run-parity.sh enforces this.
#
# Gate definition (v6 S0):
#   hard gate = engine/CONTEXT.md / HANDOFF.md / ENGINE_MAP.md touched;
#   change capsule (engine/changes/CHANGE-*.md) is observed; missing => WARN only.
#
# Parsing contract: git status --porcelain -z (NUL separated), never line-based:
#   non-ASCII paths get quote+octal-escaped under default core.quotepath=true,
#   which breaks column parsing; -z never quotes, and rename/copy records come as
#   "XY newpath\0oldpath\0" - take the new path, skip the old one.
#
# Safety: read-only; only inspects git status. Idempotent via stop_hook_active.
# Fail-open on any error (better to miss one gate than to wedge the session).

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

# NUL-separated status. Force UTF-8 decoding so non-ASCII paths survive PS 5.1.
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
Push-Location $Root
# -uall: list untracked files individually. Default -unormal collapses a fresh
# untracked directory into "?? dir/", which hides the FIRST capsule (engine/changes/
# appearing for the first time) from the gate - a real defect the parity tests caught.
$raw = git status --porcelain -z -uall 2>$null
Pop-Location
if ($raw -is [array]) { $raw = $raw -join "`n" }   # -z emits no newlines; defensive
if (-not $raw) { exit 0 }   # Clean worktree or pure Q&A session.

$codeChanged = $false
$engineWritten = $false
$capsuleWritten = $false
$skipNext = $false

foreach ($rec in ($raw -split "`0")) {
  if (-not $rec) { continue }
  if ($skipNext) { $skipNext = $false; continue }   # old path of a rename/copy record
  if ($rec.Length -lt 4) { continue }
  $st = $rec.Substring(0, 2)
  $path = $rec.Substring(3)
  if ($st -match '[RC]') { $skipNext = $true }   # with -z the NEXT NUL field is the old path

  switch -Wildcard ($path) {
    "engine/CONTEXT.md"          { $engineWritten = $true; break }
    "engine/HANDOFF.md"          { $engineWritten = $true; break }
    "engine/ENGINE_MAP.md"       { $engineWritten = $true; break }
    "engine/changes/CHANGE-*.md" { $capsuleWritten = $true; break }   # capsule: WARN-level observation
    "engine/.cache/*"            { break }
    ".engine/*"                  { break }
    "engine/*"                   { break }
    default                      { $codeChanged = $true }
  }
}

# Hard gate: code changed but engine memory was not updated.
if ($codeChanged -and -not $engineWritten) {
  $reason = "[Engine System gatekeeper] Code changed, but engine memory was not updated. Before stopping: 1) update the engine/CONTEXT.md status panel; 2) append a HANDOFF.md row (date | what | next | touched files); 3) for a meaningful change, add a change capsule under engine/changes/CHANGE-YYYY-MM-DD-nn.md."
  Write-Output "{`"decision`":`"block`",`"reason`":`"$reason`"}"
  exit 0
}

# Soft gate (WARN, never blocks): memory written, but no change capsule for a code change.
if ($codeChanged -and $engineWritten -and -not $capsuleWritten) {
  $msg = "[Engine System] Code change was written back to CONTEXT/HANDOFF, but no change capsule (engine/changes/CHANGE-*.md) was touched. For a meaningful change, ask the agent to add an architect-readable capsule. (WARN, non-blocking)"
  Write-Output "{`"systemMessage`":`"$msg`"}"
  exit 0
}

exit 0
