# Engine System - sync cross-agent bootloader anchors (PowerShell)
#
# Creates or updates thin Engine System pointers for agent tools that do not read
# AGENTS.md directly. Existing user content is preserved outside the managed block.

$ErrorActionPreference = "Stop"

param(
  [string]$Root = $(if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (Get-Location).Path })
)

$Map = Join-Path $Root "engine\ENGINE_MAP.md"
if (-not (Test-Path $Map)) {
  Write-Host "engine/ENGINE_MAP.md not found. Run /engine-init first."
  exit 1
}

$Start = "<!-- ENGINE_SYSTEM_SYNC_START -->"
$End = "<!-- ENGINE_SYSTEM_SYNC_END -->"

function Get-ManagedBlock {
@"
$Start
# Engine System

Read ``engine/ENGINE_MAP.md`` before editing. Follow the session protocol in ``AGENTS.md``:
run the path-driven read-gate before edits, write incremental updates to ``engine/CONTEXT.md``
and ``engine/HANDOFF.md`` after meaningful changes, create/update an architect-readable
``engine/changes/CHANGE-*.md`` capsule with impact/risk/verification/rollback, preserve
multi-lane workstream structure, and keep shared engine-file writes single-writer.
$End
"@
}

function Upsert-MarkdownBlock([string]$Path, [string]$Header = "") {
  $dir = Split-Path -Parent $Path
  if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $block = Get-ManagedBlock

  if (-not (Test-Path $Path)) {
    $content = if ($Header) { "$Header`n`n$block" } else { $block }
    Set-Content -Path $Path -Value $content -Encoding UTF8
    Write-Host "created $($Path.Substring($Root.Length + 1))"
    return
  }

  $raw = Get-Content -Raw -Path $Path
  if ($raw.Contains($Start) -and $raw.Contains($End)) {
    $pattern = [regex]::Escape($Start) + "[\s\S]*?" + [regex]::Escape($End)
    $updated = [regex]::Replace($raw, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $block }, 1)
    Set-Content -Path $Path -Value $updated -Encoding UTF8
    Write-Host "updated $($Path.Substring($Root.Length + 1))"
    return
  }

  Set-Content -Path $Path -Value ($raw.TrimEnd() + "`n`n" + $block) -Encoding UTF8
  Write-Host "appended $($Path.Substring($Root.Length + 1))"
}

Upsert-MarkdownBlock (Join-Path $Root ".github\copilot-instructions.md")
Upsert-MarkdownBlock (Join-Path $Root ".cursor\rules\engine.md") "---`ndescription: Engine System bootloader`nalwaysApply: true`n---"
Upsert-MarkdownBlock (Join-Path $Root "GEMINI.md")
Upsert-MarkdownBlock (Join-Path $Root ".clinerules")
Upsert-MarkdownBlock (Join-Path $Root ".roorules")

$Aider = Join-Path $Root ".aider.conf.yml"
if (-not (Test-Path $Aider)) {
@"
# Engine System managed starter config.
read:
  - AGENTS.md
  - engine/ENGINE_MAP.md
  - engine/CONTEXT.md
  - engine/HANDOFF.md
"@ | Set-Content -Path $Aider -Encoding UTF8
  Write-Host "created .aider.conf.yml"
} else {
  Write-Host "keep .aider.conf.yml (already exists; add AGENTS.md and engine/ENGINE_MAP.md to read: if desired)"
}

exit 0
