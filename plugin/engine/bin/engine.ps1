# Engine System user-level CLI shim for Windows PowerShell.

param(
  [Parameter(Position=0)][string]$Command = "help",
  [Parameter(Position=1)][string]$Task = "",
  [Parameter(Position=2)][string]$Agent = "",
  [switch]$CheckOnly,
  [switch]$NoMigrate,
  [switch]$Print,
  [string]$Kind = "subagent"
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
  engine workstream T-NNN AGENT [--kind=subagent|session]   Create an isolated worker memory shard (default subagent)
  engine check-update   Check if a newer Engine System version is available
  engine update         Update tooling, then migrate + doctor (one-shot)
  engine update -CheckOnly       Only check for updates, change nothing
  engine update -NoMigrate       Update tooling but skip migration/doctor
  engine migrate        Run contract migration on existing engine files
  engine verify T-NNN   Run behavior verification for a task card
  engine doctor         Run engine health check
  engine load           Install the engine CLI shim into user PATH (%USERPROFILE%\.engine\bin)
  engine unload         Remove the engine CLI shim from user PATH
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

`engine load` re-installs engine external side-effects from the current
project: the user-level CLI shim (%USERPROFILE%\.engine\bin) and the git
pre-commit hook (when engine-managed or missing). Use after switching branches,
clobbered shims, or re-linking to a local checkout. Does not run migrate/doctor
and does not touch .claude\settings.json (use the installer or /engine-sync).

`engine unload` removes all engine tooling from the current project plus
external side-effects: engine\bin, engine\scripts, engine\prompts,
engine\migrations, .claude\commands, .claude\skills, runtime-law.md,
engine\VERSION, engine\domains\routing.json, the user PATH shim, the
engine-managed git pre-commit hook, and the engine-managed .claude\settings.json.
User project memory is preserved: engine\{CONTEXT,HANDOFF,ENGINE_MAP,SYSTEM,
AGENT_ADAPTERS,ENGINE_DOCTOR}.md, engine\{tasks,decisions,changes,evidence,
workstreams,domains,checks}\, and root anchors (CLAUDE.md, AGENTS.md).
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

# Load-Engine: 重新铺设引擎工具的外部副作用(PATH shim + git hook)。
# 不拉远程、不跑 migrate/doctor。.claude/settings.json 由 installer/engine-sync 维护。
function Load-Engine {
  param([string]$Root)
  $srcDir = Join-Path $Root "engine\bin"
  $destDir = Join-Path $env:USERPROFILE ".engine\bin"
  if (-not (Test-Path (Join-Path $srcDir "engine.ps1"))) {
    Write-Error "Error: $srcDir\engine.ps1 not found. Engine tooling is missing - run the installer first."
    exit 2
  }
  New-Item -ItemType Directory -Force -Path $destDir | Out-Null
  $installed = 0
  foreach ($f in @("engine.ps1", "engine.cmd")) {
    $src = Join-Path $srcDir $f
    if (Test-Path $src) {
      Copy-Item $src (Join-Path $destDir $f) -Force
      Write-Host "  installed  $destDir\$f"
      $installed++
    }
  }
  $pathParts = ($env:PATH -split ";") | Where-Object { $_ }
  if ($pathParts -notcontains $destDir) {
    Write-Host "Note: $destDir is not in PATH. Add it to run 'engine' globally."
  }

  # git pre-commit hook(仅当目标不存在或是 engine-managed 时重装)
  $hookSrc = Join-Path $Root "engine\scripts\githooks\pre-commit"
  if (Test-Path $hookSrc) {
    $gitDir = git -C $Root rev-parse --git-dir 2>$null
    if ($gitDir) {
      $hookPath = Join-Path $gitDir "hooks\pre-commit"
      $hookParent = Split-Path -Parent $hookPath
      if (-not (Test-Path $hookParent)) { New-Item -ItemType Directory -Force -Path $hookParent | Out-Null }
      if (-not (Test-Path $hookPath) -or ((Get-Content $hookPath -Raw -ErrorAction SilentlyContinue) -match 'Engine System.*pre-commit hook')) {
        Copy-Item $hookSrc $hookPath -Force
        Write-Host "  installed  $hookPath"
        $installed++
      } else {
        Write-Host "  keep       $hookPath (user-defined)"
      }
    }
  }

  Write-Host ""
  Write-Host "Engine external side-effects reloaded. ($installed items)"
  Write-Host "Project tooling under engine\ is unchanged. Run 'engine update' to refresh from remote."
}

# Unload-Engine: 拆掉所有引擎工具 + 外部副作用。保留用户项目记忆和根锚点。
# 白名单删除策略:只删 install.ps1 铺设的引擎工具路径,其余全保留。
function Unload-Engine {
  param([string]$Root)
  $removed = 0; $skipped = 0

  # 1. PATH shim
  $destDir = Join-Path $env:USERPROFILE ".engine\bin"
  if (Test-Path $destDir) {
    foreach ($f in @("engine.ps1", "engine.cmd")) {
      $p = Join-Path $destDir $f
      if (Test-Path $p) {
        Remove-Item $p -Force
        Write-Host "  removed    $p"
        $removed++
      }
    }
  }

  # 2. git pre-commit hook(仅当 engine-managed)
  $gitDir = git -C $Root rev-parse --git-dir 2>$null
  if ($gitDir) {
    $hookPath = Join-Path $gitDir "hooks\pre-commit"
    if (Test-Path $hookPath) {
      $content = Get-Content $hookPath -Raw -ErrorAction SilentlyContinue
      if ($content -match 'Engine System.*pre-commit hook') {
        Remove-Item $hookPath -Force
        Write-Host "  removed    $hookPath (was engine-managed)"
        $removed++
      } else {
        Write-Host "  keep       $hookPath (user-defined)"
        $skipped++
      }
    }
  }

  # 3. .claude\settings.json(仅当含 _engine_system 标记)
  $settings = Join-Path $Root ".claude\settings.json"
  if (Test-Path $settings) {
    $content = Get-Content $settings -Raw -ErrorAction SilentlyContinue
    if ($content -match '"_engine_system"') {
      Remove-Item $settings -Force
      Write-Host "  removed    $settings (engine-managed)"
      $removed++
    }
  }

  # 4. 引擎工具目录(白名单)
  $toolDirs = @(
    (Join-Path $Root "engine\bin"),
    (Join-Path $Root "engine\scripts"),
    (Join-Path $Root "engine\prompts"),
    (Join-Path $Root "engine\migrations"),
    (Join-Path $Root ".claude\commands"),
    (Join-Path $Root ".claude\skills")
  )
  foreach ($d in $toolDirs) {
    if (Test-Path $d) {
      Remove-Item $d -Recurse -Force
      Write-Host "  removed    $d"
      $removed++
    }
  }

  # 5. 引擎工具单文件(白名单)
  $toolFiles = @(
    (Join-Path $Root "runtime-law.md"),
    (Join-Path $Root "engine\VERSION"),
    (Join-Path $Root "engine\domains\routing.json")
  )
  foreach ($tf in $toolFiles) {
    if (Test-Path $tf) {
      Remove-Item $tf -Force
      Write-Host "  removed    $tf"
      $removed++
    }
  }

  Write-Host ""
  Write-Host "Engine tooling unloaded. ($removed items removed, $skipped user-owned kept)"
  Write-Host "Preserved: engine\{CONTEXT,HANDOFF,ENGINE_MAP,SYSTEM,AGENT_ADAPTERS,ENGINE_DOCTOR}.md,"
  Write-Host "          engine\{tasks,decisions,changes,evidence,workstreams,domains,checks}\,"
  Write-Host "          CLAUDE.md, AGENTS.md, and your project source."
  Write-Host ""
  Write-Host "To reinstall: .\install.ps1   (or   .\install.ps1 -Update   to keep memory)"
}

function New-Workstream {
  param([string]$Root, [string]$TaskId, [string]$AgentId, [string]$Kind = "subagent", [switch]$Emit)
  # v6.11.0 (D-029/T-036) AC-8: -Kind subagent|session parameter (default subagent, backward compatible)
  # subagent: worker_id = AGENT (hook detects via agent_id signal 1)
  # session: worker_id = AGENT (top-level session degraded, hook detects via .role=worker marker signal 2)
  $TaskId = $TaskId.ToUpperInvariant()
  if ($TaskId -notmatch '^T-[0-9]{3}$' -or -not $AgentId) {
    Write-Error "Usage: engine workstream T-NNN AGENT [--kind=subagent|session | -Kind subagent|session]"
    exit 2
  }
  if ($AgentId -notmatch '^[A-Za-z0-9._-]+$') {
    Write-Error "Error: AGENT may contain only A-Z, a-z, 0-9, dot, underscore, or dash."
    exit 2
  }
  if ($Kind -notin @("subagent", "session")) {
    Write-Error "Error: -Kind must be 'subagent' or 'session' (got: $Kind)"
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

> status: active | task: $TaskId | owner: $AgentId | merge: pending | kind: $Kind

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

> updated: pending | merge: pending | kind: $Kind

## Latest

- Completed: none
- Next: start assigned unit
- Blockers: none
- Verification: not run
"@
    [System.IO.File]::WriteAllText($handoff, $body + "`n", (New-Object System.Text.UTF8Encoding $false))
  }
  # v6.11.0 (D-029/T-036) AC-8: -Kind session creates .role=worker marker for top-level session degradation
  if ($Kind -eq "session") {
    $sessionsDir = Join-Path $Root "engine\.cache\sessions"
    New-Item -ItemType Directory -Force -Path $sessionsDir | Out-Null
    $roleMarker = Join-Path $sessionsDir ($AgentId + ".role=worker")
    [System.IO.File]::WriteAllText($roleMarker, "", (New-Object System.Text.UTF8Encoding $false))
    Write-Host "Session-degraded worker marker created: engine/.cache/sessions/$AgentId.role=worker"
    Write-Host "Top-level session will be treated as worker by PreToolUse hook (signal 2)."
  }
  Write-Host "Workstream ready: engine/workstreams/$TaskId/$AgentId/"
  Write-Host "Worker writes only this shard; coordinator owns shared CONTEXT/HANDOFF."
  Write-Host "Kind: $Kind"
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
    # v6.11.0 (D-029/T-036) AC-8: support both -Kind (PS native) and --kind/--print (bash compat) via $args scan
    $effectiveKind = $Kind
    $effectivePrint = $Print
    for ($i = 0; $i -lt $args.Count; $i++) {
      $a = "$($args[$i])"
      if ($a -match '^--kind=(.+)$') { $effectiveKind = $Matches[1] }
      elseif ($a -eq '--kind') { $i++; if ($i -lt $args.Count) { $effectiveKind = "$($args[$i])" } }
      elseif ($a -eq '--print') { $effectivePrint = $true }
    }
    New-Workstream -Root $PWD.Path -TaskId $Task -AgentId $Agent -Kind $effectiveKind -Emit:$effectivePrint
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
  "load" {
    if (-not (Test-Path "engine")) {
      Write-Error "Error: engine/ not found in $PWD. Run 'engine init' or the installer first."
      exit 2
    }
    Load-Engine -Root $PWD.Path
  }
  "unload" {
    Unload-Engine -Root $PWD.Path
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
