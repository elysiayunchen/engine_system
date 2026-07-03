# Engine System user-level CLI shim for Windows PowerShell.

param(
  [Parameter(Position=0)][string]$Command = "help",
  [Parameter(Position=1)][string]$Task = "",
  [switch]$CheckOnly,
  [switch]$NoMigrate
)

$Repo = if ($env:ENGINE_SYSTEM_REPO) { $env:ENGINE_SYSTEM_REPO } else { "elysiayunchen/engine_system" }
$Branch = if ($env:ENGINE_SYSTEM_BRANCH) { $env:ENGINE_SYSTEM_BRANCH } else { "main" }

function Show-Help {
@"
Engine System CLI

Usage:
  engine check-update   Check if a newer Engine System version is available
  engine update         Update tooling, then migrate + doctor (one-shot)
  engine update -CheckOnly       Only check for updates, change nothing
  engine update -NoMigrate       Update tooling but skip migration/doctor
  engine migrate        Run contract migration on existing engine files
  engine verify T-NNN   Run behavior verification for a task card
  engine help           Show this help

`engine check-update` compares local engine/VERSION against the remote VERSION.
Exit codes: 0 = up to date | 7 = update available | 8 = network error.

`engine update` downloads the latest installer, runs update mode (does not
overwrite project-specific engine/*.md memory), then runs the contract migrator
so old engine files receive the v6 data-layer structure and managed contract
block, then runs Doctor to verify. Use -CheckOnly to preview, -NoMigrate to
skip the migration step.

`engine migrate` runs the contract migrator alone (idempotent).
"@ | Write-Host
}

function Run-Migrate {
  param([string]$Root)
  $migrator = Join-Path $Root "engine\scripts\engine-migrate-contract.ps1"
  if (Test-Path $migrator) {
    Write-Host "[engine] running contract migration..."
    & $migrator -Root $Root
    if ($LASTEXITCODE -ne 0) { Write-Host "[engine] migration reported issues (see above)" }
  } else {
    Write-Host "[engine] migrator not found at $migrator - skipping migrate"
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

switch ($Command) {
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
  { $_ -in @("help", "-h", "--help") } {
    Show-Help
  }
  default {
    Write-Error "Unknown command: $Command"
    Show-Help
    exit 1
  }
}
