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
