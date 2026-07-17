# Engine System user-level CLI shim for Windows PowerShell.

param(
  [Parameter(Position=0)][string]$Command = "help",
  [Parameter(Position=1)][string]$Task = "",
  [Parameter(Position=2)][string]$Agent = "",
  [switch]$CheckOnly,
  [switch]$NoMigrate,
  [switch]$Print
)

$ErrorActionPreference = "Stop"

$Repo = if ($env:ENGINE_SYSTEM_REPO) { $env:ENGINE_SYSTEM_REPO } else { "elysiayunchen/engine_system" }
$Branch = if ($env:ENGINE_SYSTEM_BRANCH) { $env:ENGINE_SYSTEM_BRANCH } else { "main" }

function Show-Help {
@"
Engine System CLI

Usage:
  engine init           Show how to run the init interview with any AI agent
  engine init --print   Print the raw agent-neutral init prompt (pipe/copy it)
  engine context        Load full session context (agent-agnostic, any AI agent)
  engine workstream T-NNN AGENT   Create an isolated worker memory shard
  engine check-update   Check if a newer Engine System version is available
  engine update         Update tooling, then migrate + doctor (one-shot)
  engine update -CheckOnly       Only check for updates, change nothing
  engine update -NoMigrate       Update tooling but skip migration/doctor
  engine migrate        Run contract migration on existing engine files
  engine verify T-NNN   Run behavior verification for a task card
  engine doctor         Run engine health check
  engine help           Show this help

`engine init` is the agent-agnostic entry to initialize the engine layer: it
locates engine/prompts/init.md (distributed by the installer) and shows how to
feed it to your AI agent; --print emits the raw prompt for piping/copying.

`engine check-update` compares local engine/VERSION against the remote VERSION.
Exit codes: 0 = up to date | 7 = update available | 8 = network error.

`engine update` downloads the latest installer, runs update mode (does not
overwrite project-specific engine/*.md memory), then runs the contract migrator
so old engine files receive the v6 data-layer structure and managed contract
block, then runs Doctor to verify. Use -CheckOnly to preview, -NoMigrate to
skip the migration step.

`engine migrate` applies migration steps under engine/migrations/ newer than
the local engine/VERSION in version order, writing the version back after each
step; when nothing is pending it falls back to the idempotent contract migrator.
"@ | Write-Host
}

# Normalize: pad to major.minor.patch (6.0 -> 6.0.0); non-numeric returned as-is (D-015).
function Normalize-Version([string]$v) {
  $v = ($v -replace '\s', '')
  if ($v -notmatch '^[0-9]+(\.[0-9]+)*$') { return $v }
  $parts = @($v.Split('.'))
  while ($parts.Count -lt 3) { $parts += '0' }
  return ($parts -join '.')
}

# Versioned migration scheduling (D-015): discover engine/migrations/v*.ps1, apply steps
# newer than local engine/VERSION in version order, write VERSION back after each step.
# Falls back to the idempotent contract migrator when nothing is pending.
function Run-Migrate {
  param([string]$Root)
  $migrator = Join-Path $Root "engine\scripts\engine-migrate-contract.ps1"
  $migDir = Join-Path $Root "engine\migrations"
  $vfile = Join-Path $Root "engine\VERSION"
  $current = "0"
  if (Test-Path $vfile) { $current = (Get-Content $vfile -Raw -Encoding UTF8).Trim() }
  $currentN = Normalize-Version $current
  if ($currentN -notmatch '^[0-9]+(\.[0-9]+)*$') { $currentN = "0.0.0" }
  $applied = 0
  if (Test-Path $migDir) {
    $steps = Get-ChildItem -Path $migDir -Filter "v*.ps1" -File -ErrorAction SilentlyContinue |
      Where-Object { $_.BaseName -match '^v[0-9][0-9.]*$' } |
      Sort-Object { [version](Normalize-Version $_.BaseName.Substring(1)) }
    foreach ($s in $steps) {
      $stepV = Normalize-Version $s.BaseName.Substring(1)
      if ([version]$stepV -gt [version]$currentN) {
        Write-Host "[engine] applying migration step $($s.Name) ($currentN -> $stepV)..."
        & $s.FullName -Root $Root
        if ($LASTEXITCODE -ne 0) {
          Write-Host "[engine] migration step $($s.Name) failed - stopping (VERSION stays $currentN)"
          return
        }
        # VERSION write-back after each successful step (BOM-free so sh readers stay intact).
        [System.IO.File]::WriteAllText($vfile, $stepV + "`n", (New-Object System.Text.UTF8Encoding $false))
        $currentN = $stepV
        $applied++
      }
    }
  }
  if ($applied -eq 0) {
    if (Test-Path $migrator) {
      Write-Host "[engine] no pending migration steps (local $currentN) - running contract migrator (idempotent repair)..."
      & $migrator -Root $Root
      if ($LASTEXITCODE -ne 0) { Write-Host "[engine] migration reported issues (see above)" }
    } else {
      Write-Host "[engine] migrator not found at $migrator - skipping migrate"
    }
  }
}

function Run-Doctor {
  param([string]$Root)
  $doctor = Join-Path $Root "engine\scripts\engine-doctor.ps1"
  if (Test-Path $doctor) {
    Write-Host "[engine] running doctor..."
    & $doctor
    if ($LASTEXITCODE -ne 0) { Write-Host "[engine] doctor reported issues (see above)" }
  }
}

function New-Workstream {
  param([string]$Root, [string]$TaskId, [string]$AgentId, [switch]$Emit)
  $TaskId = $TaskId.ToUpperInvariant()
  if ($TaskId -notmatch '^T-[0-9]{3}$' -or -not $AgentId) {
    Write-Error "Usage: engine workstream T-NNN AGENT"
    exit 2
  }
  if ($AgentId -notmatch '^[A-Za-z0-9._-]+$') {
    Write-Error "Error: AGENT may contain only A-Z, a-z, 0-9, dot, underscore, or dash."
    exit 2
  }
  $taskFile = Join-Path $Root ("engine\tasks\" + $TaskId + ".md")
  if (-not (Test-Path $taskFile)) {
    Write-Error "Error: task card not found: engine/tasks/$TaskId.md"
    exit 2
  }
  $taskContent = Get-Content -Raw -Path $taskFile -Encoding UTF8
  $goal = ""
  foreach ($line in ($taskContent -split "`n")) {
    if ($line -match '^GOAL:\s*(.*)$') { $goal = $Matches[1].Trim(); break }
  }
  if (-not $goal) {
    $on = $false
    foreach ($raw in ($taskContent -split "`n")) {
      $line = $raw.TrimEnd("`r")
      if ($line -match '^##\s+GOAL\s*$') { $on = $true; continue }
      if ($on -and $line -match '^##\s+') { break }
      if ($on -and $line.Trim()) { $goal = $line.Trim(); break }
    }
  }
  if (-not $goal) { $goal = "See engine/tasks/$TaskId.md" }
  $dir = Join-Path $Root ("engine\workstreams\" + $TaskId + "\" + $AgentId)
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $ctx = Join-Path $dir "CONTEXT.md"
  $handoff = Join-Path $dir "HANDOFF.md"
  if (-not (Test-Path $ctx)) {
    $body = @"
# Workstream Context - $TaskId / $AgentId

> status: active | task: $TaskId | owner: $AgentId | merge: pending

## Goal

$goal

## Progress

- pending

## Changed Paths

- none

## Evidence

- none

## Merge Notes

- Coordinator re-reads this shard before updating shared engine/CONTEXT.md and engine/HANDOFF.md.
"@
    [System.IO.File]::WriteAllText($ctx, $body + "`n", (New-Object System.Text.UTF8Encoding $false))
  }
  if (-not (Test-Path $handoff)) {
    $body = @"
# Workstream Handoff - $TaskId / $AgentId

> updated: pending | merge: pending

## Latest

- Completed: none
- Next: start assigned unit
- Blockers: none
- Verification: not run
"@
    [System.IO.File]::WriteAllText($handoff, $body + "`n", (New-Object System.Text.UTF8Encoding $false))
  }
  Write-Host "Workstream ready: engine/workstreams/$TaskId/$AgentId/"
  Write-Host "Worker writes only this shard; coordinator owns shared CONTEXT/HANDOFF."
  if ($Emit) {
    Write-Output (Get-Content -Raw -Path $ctx -Encoding UTF8)
    Write-Output (Get-Content -Raw -Path $handoff -Encoding UTF8)
  }
}

switch ($Command) {
  "init" {
    $promptRel = "engine/prompts/init.md"
    $promptFile = Join-Path $PWD.Path "engine\prompts\init.md"
    if (-not (Test-Path $promptFile)) {
      Write-Error "Error: $promptRel not found in $PWD. Run 'engine update' (or re-run the installer) to fetch the init prompt, then retry."
      exit 2
    }
    if ($Print -or $Task -eq "--print") {
      Write-Output (Get-Content -Raw -Path $promptFile -Encoding UTF8)
      exit 0
    }
    Write-Host "Engine System init - agent-neutral entry point"
    Write-Host ""
    if (Test-Path (Join-Path $PWD.Path "engine\ENGINE_MAP.md")) {
      Write-Host "Note: engine/ENGINE_MAP.md already exists - this project looks initialized."
      Write-Host "Prefer /engine-reconcile (in your agent) or 'engine migrate' instead of re-init."
      Write-Host ""
    }
    Write-Host "The init interview prompt lives at: $promptRel"
    Write-Host "Feed it to whichever AI agent you use:"
    Write-Host ""
    Write-Host "  Claude Code   type /engine-init in this project"
    Write-Host "  claude CLI    claude `"`$(cat $promptRel)`""
    Write-Host "  codex CLI     codex `"`$(cat $promptRel)`""
    Write-Host "  copilot CLI   copilot -p `"`$(cat $promptRel)`""
    Write-Host "  Web chat      paste the contents of $promptRel into the chat"
    Write-Host "  Raw prompt    engine init --print"
  }
  "verify" {
    if (-not (Test-Path "engine")) {
      Write-Error "Error: engine/ not found in $PWD. Run engine verify in a project root."
      exit 2
    }
    if (-not $Task) {
      Write-Error "Usage: engine verify T-NNN"
      exit 2
    }
    $verifyScript = Join-Path $PWD.Path "engine\scripts\engine-verify.ps1"
    & $verifyScript -Task $Task
  }
  "context" {
    if (-not (Test-Path "engine")) {
      Write-Error "Error: engine/ not found in $PWD. Run 'engine init' first."
      exit 2
    }
    $ctxScript = Join-Path $PWD.Path "engine\scripts\engine-context.ps1"
    & $ctxScript -Root $PWD.Path
  }
  "workstream" {
    if (-not (Test-Path "engine")) {
      Write-Error "Error: engine/ not found in $PWD."
      exit 2
    }
    New-Workstream -Root $PWD.Path -TaskId $Task -AgentId $Agent -Emit:$Print
  }
  "check-update" {
    $chk = Join-Path $PWD.Path "engine\scripts\engine-check-update.ps1"
    & $chk -Root $PWD.Path
    exit $LASTEXITCODE
  }
  "migrate" {
    if (-not (Test-Path "engine")) {
      Write-Error "Error: engine/ not found in $PWD."
      exit 2
    }
    Run-Migrate -Root $PWD.Path
  }
  "update" {
    if ($CheckOnly) {
      $chk = Join-Path $PWD.Path "engine\scripts\engine-check-update.ps1"
      & $chk -Root $PWD.Path
      exit $LASTEXITCODE
    }
    $tmp = Join-Path $env:TEMP ("engine-install-" + [guid]::NewGuid().ToString("N") + ".ps1")
    try {
      Invoke-WebRequest -Uri "https://raw.githubusercontent.com/$Repo/$Branch/install.ps1" -OutFile $tmp -UseBasicParsing
      powershell -NoProfile -ExecutionPolicy Bypass -File $tmp -Update
      Write-Host ""
      if (-not $NoMigrate) {
        Run-Migrate -Root $PWD.Path
        Run-Doctor -Root $PWD.Path
      }
      Write-Host ""
      Write-Host "Engine tooling updated from remote."
      if (-not $NoMigrate) {
        Write-Host "Migration + doctor complete."
      }
      Write-Host "Next: run /engine-sync in your AI agent if cross-agent anchors need syncing."
    } finally {
      Remove-Item -Path $tmp -ErrorAction SilentlyContinue
    }
  }
  "doctor" {
    if (-not (Test-Path "engine")) {
      Write-Error "Error: engine/ not found in $PWD. Run 'engine init' first."
      exit 2
    }
    Run-Doctor -Root $PWD.Path
  }
  { $_ -in @("help", "-h", "--help") } {
    Show-Help
  }
  default {
    Write-Error "Unknown command: $Command"
    Show-Help
    exit 1
  }
}
