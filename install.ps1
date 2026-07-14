# Engine System installer for Windows
# Usage:
#   Invoke-WebRequest https://raw.githubusercontent.com/elysiayunchen/engine_system/main/install.ps1 -OutFile install.ps1
#   powershell -NoProfile -File .\install.ps1 [-Update] [-Version TAG]
#
# Keep this installer file-download-first. Avoid pipe-to-execute examples:
# security products often flag remote-content direct execution as malware-like.

param(
  [switch]$Update,
  [string]$Version = "",
  [string]$Local = ""
)

$ErrorActionPreference = "Stop"

$REPO = "elysiayunchen/engine_system"
$BRANCH = "main"

# Normalize version: strip leading 'v' if present
if ($Version -and $Version.StartsWith("v")) { $Version = $Version.Substring(1) }

# Handle -Local parameter (offline install, no network needed)
$LocalDir = ""
if ($Local) {
  if (Test-Path $Local -PathType Leaf) {
    $LocalDir = Join-Path $env:TEMP "engine-offline-$(Get-Random)"
    New-Item -ItemType Directory -Force -Path $LocalDir | Out-Null
    tar xzf $Local -C $LocalDir
    Write-Host "  Extracted offline package: $Local"
  } elseif (Test-Path $Local -PathType Container) {
    $LocalDir = $Local
  } else {
    Write-Host "Error: -Local path not found: $Local" -ForegroundColor Red
    exit 1
  }
}

# Build BASE_URL — use version tag or default branch
if ($Version) {
  $BASE_URL = "https://raw.githubusercontent.com/$REPO/v$Version/plugin"
} else {
  $BASE_URL = "https://raw.githubusercontent.com/$REPO/$BRANCH/plugin"
}

# Download with release-first fallback (when -Version is specified)
function Download-File {
  param([string]$Src, [string]$Dest)
  $url = "$BASE_URL/$Src"

  if ($Version) {
    $releaseUrl = "https://github.com/$REPO/releases/download/v$Version/plugin/$Src"
    try {
      Invoke-WebRequest -Uri $releaseUrl -OutFile $Dest -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop
      return
    } catch {
      # Release artifact not found — fallback to raw content
    }
  }

  Invoke-WebRequest -Uri $url -OutFile $Dest -UseBasicParsing -TimeoutSec 30
}

# Copy from local offline directory (when -Local is specified)
function Copy-Local {
  param([string]$Src, [string]$Dest)
  $srcPath = Join-Path $LocalDir ($Src -replace '/', '\')
  if (Test-Path $srcPath) {
    Copy-Item $srcPath $Dest -Force
  } else {
    Write-Host "  WARN  local file not found: $srcPath" -ForegroundColor Yellow
  }
}

# Verify SHA256 checksums against manifest (hard-fail on mismatch)
function Verify-Checksums {
  param([string]$ManifestFile)
  if (-not (Test-Path $ManifestFile)) { return }
  try {
    $manifest = Get-Content $ManifestFile -Raw | ConvertFrom-Json
    $verified = 0; $failed = 0; $skipped = 0
    $failedFiles = @()
    foreach ($entry in $manifest.files) {
      if (-not $entry.sha256 -or $entry.sha256 -eq "placeholder") {
        $skipped++
        Write-Host "  NOTE  checksum skipped: $($entry.src) (no sha256)" -ForegroundColor Yellow
        continue
      }
      # Map src to dest
      $destFile = $entry.src -replace '/', '\'
      if ($entry.src -like "engine/*") { $destFile = $entry.src -replace '/', '\' }
      elseif ($entry.src -like "bin/*") { $destFile = "engine\bin\" + ($entry.src -replace '^bin/', '') }
      elseif ($entry.src -like "migrations/*") { $destFile = "engine\migrations\" + ($entry.src -replace '^migrations/', '') }
      # .claude/settings.json is generated/modified by the installer post-download;
      # its on-disk bytes will not match the manifest hash.
      if ($destFile -eq ".claude\settings.json") { continue }
      if (-not (Test-Path $destFile)) { continue }
      $actual = (Get-FileHash $destFile -Algorithm SHA256).Hash.ToLower()
      $verified++
      if ($actual -ne $entry.sha256) {
        Write-Host "  FAIL  checksum mismatch: $destFile" -ForegroundColor Red
        $failed++
        $failedFiles += $destFile
      }
    }
    if ($failed -gt 0) {
      Write-Host "  FAIL  $failed file(s) failed checksum verification: $failedFiles" -ForegroundColor Red
      throw "Checksum verification failed"
    } elseif ($verified -gt 0) {
      Write-Host "  ok    $verified file(s) verified (SHA256)" -ForegroundColor Green
    }
  } catch {
    if ($_.Exception.Message -eq "Checksum verification failed") { throw }
    Write-Host "  note  checksum verification skipped (manifest parse error)" -ForegroundColor Yellow
  }
}

$FILES = @(
  @{ src = ".claude/commands/engine-init.md";      dest = ".claude\commands\engine-init.md";      protect = $true }
  @{ src = ".claude/commands/engine-update.md";    dest = ".claude\commands\engine-update.md";    protect = $true }
  @{ src = ".claude/commands/engine-status.md";    dest = ".claude\commands\engine-status.md";    protect = $true }
  @{ src = ".claude/commands/add-pitfall.md";      dest = ".claude\commands\add-pitfall.md";      protect = $true }
  @{ src = ".claude/commands/engine-ingest.md";    dest = ".claude\commands\engine-ingest.md";    protect = $true }
  @{ src = ".claude/commands/engine-extend.md";    dest = ".claude\commands\engine-extend.md";    protect = $true }
  @{ src = ".claude/commands/engine-doctor.md";    dest = ".claude\commands\engine-doctor.md";    protect = $true }
  @{ src = ".claude/commands/engine-sync.md";      dest = ".claude\commands\engine-sync.md";      protect = $true }
  @{ src = ".claude/commands/engine-reconcile.md"; dest = ".claude\commands\engine-reconcile.md"; protect = $true }
  @{ src = "CLAUDE.md";                            dest = "CLAUDE.md";                            protect = $true }
  @{ src = "AGENTS.md";                            dest = "AGENTS.md";                            protect = $true }
  @{ src = "engine/README.md";                     dest = "engine\README.md";                     protect = $false }
  @{ src = "engine/README.zh.md";                  dest = "engine\README.zh.md";                  protect = $false }
  @{ src = "engine/ENGINE_DOCTOR.md";              dest = "engine\ENGINE_DOCTOR.md";              protect = $false }
  @{ src = "engine/prompts/init.md";               dest = "engine\prompts\init.md";               protect = $true }
  @{ src = "engine/prompts/behaviors/decision-draft.md";    dest = "engine\prompts\behaviors\decision-draft.md";    protect = $true }
  @{ src = "engine/prompts/behaviors/handoff.md";           dest = "engine\prompts\behaviors\handoff.md";           protect = $true }
  @{ src = "engine/prompts/behaviors/scout.md";             dest = "engine\prompts\behaviors\scout.md";             protect = $true }
  @{ src = "engine/prompts/behaviors/task-run.md";          dest = "engine\prompts\behaviors\task-run.md";          protect = $true }
  @{ src = "engine/prompts/behaviors/verify-writeback.md";  dest = "engine\prompts\behaviors\verify-writeback.md";  protect = $true }
  @{ src = "engine/domains/routing.json";          dest = "engine\domains\routing.json";          protect = $true }
  @{ src = ".claude/skills/engine-decision-draft/SKILL.md";   dest = ".claude\skills\engine-decision-draft\SKILL.md";   protect = $true }
  @{ src = ".claude/skills/engine-handoff/SKILL.md";          dest = ".claude\skills\engine-handoff\SKILL.md";          protect = $true }
  @{ src = ".claude/skills/engine-scout/SKILL.md";            dest = ".claude\skills\engine-scout\SKILL.md";            protect = $true }
  @{ src = ".claude/skills/engine-task-run/SKILL.md";         dest = ".claude\skills\engine-task-run\SKILL.md";         protect = $true }
  @{ src = ".claude/skills/engine-verify-writeback/SKILL.md"; dest = ".claude\skills\engine-verify-writeback\SKILL.md"; protect = $true }
  @{ src = "engine/scripts/engine-doctor.sh";      dest = "engine\scripts\engine-doctor.sh";      protect = $true }
  @{ src = "engine/scripts/engine-doctor.ps1";     dest = "engine\scripts\engine-doctor.ps1";     protect = $true }
  @{ src = "engine/scripts/engine-hook-session-start.sh";   dest = "engine\scripts\engine-hook-session-start.sh";   protect = $true }
  @{ src = "engine/scripts/engine-hook-session-start.ps1";  dest = "engine\scripts\engine-hook-session-start.ps1";  protect = $true }
  @{ src = "engine/scripts/engine-hook-stop.sh";   dest = "engine\scripts\engine-hook-stop.sh";   protect = $true }
  @{ src = "engine/scripts/engine-hook-stop.ps1";  dest = "engine\scripts\engine-hook-stop.ps1";  protect = $true }
  @{ src = "engine/scripts/engine-hook-session-end.sh";   dest = "engine\scripts\engine-hook-session-end.sh";   protect = $true }
  @{ src = "engine/scripts/engine-hook-session-end.ps1";  dest = "engine\scripts\engine-hook-session-end.ps1";  protect = $true }
  @{ src = "engine/scripts/engine-hook.cmd";       dest = "engine\scripts\engine-hook.cmd";       protect = $true }
  @{ src = "engine/scripts/engine-sync-agent-anchors.sh";   dest = "engine\scripts\engine-sync-agent-anchors.sh";   protect = $true }
  @{ src = "engine/scripts/engine-sync-agent-anchors.ps1";  dest = "engine\scripts\engine-sync-agent-anchors.ps1";  protect = $true }
  @{ src = "engine/scripts/engine-migrate-contract.sh";     dest = "engine\scripts\engine-migrate-contract.sh";     protect = $true }
  @{ src = "engine/scripts/engine-migrate-contract.ps1";    dest = "engine\scripts\engine-migrate-contract.ps1";    protect = $true }
  @{ src = "engine/scripts/engine-verify.sh";      dest = "engine\scripts\engine-verify.sh";      protect = $true }
  @{ src = "engine/scripts/engine-verify.ps1";     dest = "engine\scripts\engine-verify.ps1";     protect = $true }
  @{ src = "engine/scripts/githooks/pre-commit";   dest = "engine\scripts\githooks\pre-commit";   protect = $true }
  @{ src = "bin/engine";                            dest = "engine\bin\engine";                            protect = $true }
  @{ src = "bin/engine.ps1";                        dest = "engine\bin\engine.ps1";                        protect = $true }
  @{ src = "bin/engine.cmd";                        dest = "engine\bin\engine.cmd";                        protect = $true }
  @{ src = "VERSION";                               dest = "engine\VERSION";                               protect = $true }
  @{ src = "engine/scripts/engine-check-update.sh"; dest = "engine\scripts\engine-check-update.sh"; protect = $true }
  @{ src = "engine/scripts/engine-check-update.ps1"; dest = "engine\scripts\engine-check-update.ps1"; protect = $true }
  @{ src = "migrations/v6.0.sh";                    dest = "engine\migrations\v6.0.sh";                    protect = $true }
  @{ src = "migrations/v6.0.ps1";                   dest = "engine\migrations\v6.0.ps1";                   protect = $true }
  @{ src = "engine/skeleton/ENGINE_MAP.md";         dest = "engine\ENGINE_MAP.md";         protect = $false }
  @{ src = "engine/skeleton/CONTEXT.md";            dest = "engine\CONTEXT.md";            protect = $false }
  @{ src = "engine/skeleton/HANDOFF.md";            dest = "engine\HANDOFF.md";            protect = $false }
  @{ src = "engine/checks/README.md";                 dest = "engine\checks\README.md";                 protect = $false }
  @{ src = ".claude/settings.json";                dest = ".claude\settings.json";                protect = $false }
)

Write-Host ""
Write-Host "Engine System installer" -ForegroundColor Cyan
Write-Host "-------------------------------------"

New-Item -ItemType Directory -Force -Path ".claude\commands", ".claude\skills", "engine", "engine\scripts", "engine\scripts\githooks", "engine\bin", "engine\migrations", "engine\prompts", "engine\prompts\behaviors", "engine\domains", "engine\checks", "engine\.cache" | Out-Null

$installed = 0; $skipped = 0

foreach ($f in $FILES) {
  $url = "$BASE_URL/$($f.src)"
  $dest = $f.dest
  $destDir = Split-Path -Parent $dest
  if ($destDir -and -not (Test-Path $destDir)) {
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null
  }

  # Root anchor files (CLAUDE.md / AGENTS.md) and .claude/settings.json:
  # never clobber an existing one, in any mode.
  # A brand-new project gets the starter bootloader; an existing file is preserved so that
  # /engine-init can absorb its rules first, and /engine-reconcile keeps it in sync after.
  if (($dest -eq "CLAUDE.md" -or $dest -eq "AGENTS.md" -or $dest -eq ".claude\settings.json") -and (Test-Path $dest)) {
    Write-Host "  keep  $dest (already exists; run /engine-sync to merge hooks)" -ForegroundColor Yellow
    $skipped++; continue
  }

  if ($Update -and -not $f.protect -and (Test-Path $dest)) {
    Write-Host "  skip  $dest (user data)" -ForegroundColor Yellow
    $skipped++; continue
  }

  if ($Update -and $f.protect) {
    if ($LocalDir) { Copy-Local -Src $f.src -Dest $dest }
    else { Download-File -Src $f.src -Dest $dest }
    Write-Host "  updated $dest" -ForegroundColor Green
    $installed++; continue
  }

  if (-not $Update -and (Test-Path $dest) -and $dest -like "engine\*" -and $dest -ne "engine\README.md") {
    Write-Host "  skip  $dest (already exists)" -ForegroundColor Yellow
    $skipped++; continue
  }

  if ($LocalDir) {
    Copy-Local -Src $f.src -Dest $dest
  } elseif ($dest -eq ".claude\settings.json") {
@'
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "_engine_system": "Windows hook config generated by install.ps1. Hooks dispatch via engine-hook.cmd (bash first for Unix-identical behavior, PowerShell twin as fallback). If this file already existed, the installer preserves it; run /engine-sync to merge hooks.",
  "hooks": {
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "engine\\scripts\\engine-hook.cmd session-start",
            "timeout": 15
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "engine\\scripts\\engine-hook.cmd stop",
            "timeout": 30
          },
          {
            "type": "command",
            "command": "engine\\scripts\\engine-hook.cmd session-end",
            "timeout": 45
          }
        ]
      }
    ]
  }
}
'@ | Set-Content -Path $dest -Encoding UTF8
  } else {
    Download-File -Src $f.src -Dest $dest
  }
  Write-Host "  ok    $dest" -ForegroundColor Green
  $installed++
}

$cliDir = Join-Path $env:USERPROFILE ".engine\bin"
if (Test-Path "engine\bin\engine.ps1") {
  New-Item -ItemType Directory -Force -Path $cliDir | Out-Null
  Copy-Item "engine\bin\engine.ps1" (Join-Path $cliDir "engine.ps1") -Force
  Copy-Item "engine\bin\engine.cmd" (Join-Path $cliDir "engine.cmd") -Force
  Write-Host "  ok    $($cliDir)\engine.cmd (CLI: engine update)" -ForegroundColor Green
  $installed++
  $pathParts = ($env:PATH -split ";") | Where-Object { $_ }
  if ($pathParts -notcontains $cliDir) {
    Write-Host "  note  add $($cliDir) to PATH to run: engine update" -ForegroundColor Yellow
    Write-Host "        This session can run: $($cliDir)\engine.cmd update" -ForegroundColor Yellow
  }
}

$insideGit = git rev-parse --is-inside-work-tree 2>$null
if ($insideGit -eq "true") {
  $gitDir = git rev-parse --git-dir 2>$null
  if ($gitDir) {
    $hookDir = Join-Path $gitDir "hooks"
    $hookPath = Join-Path $hookDir "pre-commit"
    New-Item -ItemType Directory -Force -Path $hookDir | Out-Null
    if (Test-Path $hookPath) {
      $existing = Get-Content $hookPath -Raw -ErrorAction SilentlyContinue
      if ($existing -match 'Engine System.*pre-commit hook' -and (Test-Path "engine\scripts\githooks\pre-commit")) {
        if ((Get-FileHash "engine\scripts\githooks\pre-commit" -Algorithm SHA256).Hash -eq (Get-FileHash $hookPath -Algorithm SHA256).Hash) {
          Write-Host "  ok    $hookPath (up to date)" -ForegroundColor Green
        } else {
          Copy-Item "engine\scripts\githooks\pre-commit" $hookPath -Force
          Write-Host "  update $hookPath (engine-managed, updated to latest)" -ForegroundColor Green
          $installed++
        }
      } else {
        Write-Host "  keep  $hookPath (user-defined; merge engine\scripts\githooks\pre-commit manually if needed)" -ForegroundColor Yellow
        $skipped++
      }
    } elseif (Test-Path "engine\scripts\githooks\pre-commit") {
      Copy-Item "engine\scripts\githooks\pre-commit" $hookPath -Force
      Write-Host "  ok    $hookPath" -ForegroundColor Green
      $installed++
    }
  }
}

# L0 constitution (runtime-law.md): session-start hook injects first 40 lines to fight drift.
# Fetched from repo root (contract compile output) to project root. Always overwrite (engine artifact).
if ($LocalDir -and (Test-Path (Join-Path $LocalDir "runtime-law.md"))) {
  Copy-Item (Join-Path $LocalDir "runtime-law.md") "runtime-law.md" -Force
  Write-Host "  ok    runtime-law.md (L0 constitution)" -ForegroundColor Green
  $installed++
} else {
  try {
    if ($Version) {
      $runtimeLawUrl = "https://raw.githubusercontent.com/$REPO/v$Version/runtime-law.md"
    } else {
      $runtimeLawUrl = "https://raw.githubusercontent.com/$REPO/$BRANCH/runtime-law.md"
    }
    Invoke-WebRequest -Uri $runtimeLawUrl -OutFile "runtime-law.md" -UseBasicParsing -TimeoutSec 15
    Write-Host "  ok    runtime-law.md (L0 constitution)" -ForegroundColor Green
    $installed++
  } catch {
    Write-Host "  skip  runtime-law.md (network error - L0 constitution not fetched)" -ForegroundColor Yellow
  }
}

# Verify SHA256 checksums (hard-fail on mismatch; only when -Version is specified, skip for -Local)
if ($Version -and -not $LocalDir) {
  try {
    $manifestUrl = "https://raw.githubusercontent.com/$REPO/v$Version/plugin/manifest.json"
    Invoke-WebRequest -Uri $manifestUrl -OutFile ".manifest-check.json" -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
    Verify-Checksums -ManifestFile ".manifest-check.json"
    Remove-Item ".manifest-check.json" -Force -ErrorAction SilentlyContinue
  } catch {
    Remove-Item ".manifest-check.json" -Force -ErrorAction SilentlyContinue
    if ($_.Exception.Message -match "Checksum verification failed") {
      exit 1
    }
    # Fail-open: no checksum verification if manifest unavailable
  }
}

# 创建 v6 数据层目录结构(tasks/decisions/domains/changes/evidence)
if (Test-Path "engine\scripts\engine-migrate-contract.ps1") {
  try {
    & powershell -NoProfile -ExecutionPolicy Bypass -File "engine\scripts\engine-migrate-contract.ps1" "." 2>$null
  } catch {
    # fail-open: migrator 失败不阻塞安装
  }
}

Write-Host ""
Write-Host "-------------------------------------"
Write-Host "Done. $installed files installed, $skipped skipped." -ForegroundColor Green
Write-Host ""

if ($Update) {
  Write-Host "Plugin updated. Your engine/*.md project memory was not overwritten."
  Write-Host "Next: open your AI agent in this project and run /engine-sync."
  Write-Host "/engine-sync runs engine-migrate-contract.* to write the current managed contract block"
  Write-Host "into old engine files while preserving project-specific memory."
  Write-Host "That contract covers self-maintenance, change capsules, acceptance evidence,"
  Write-Host "Doctor parity, and other current Engine System mechanisms."
  Write-Host "Future remote updates can use: engine update"
} else {
  Write-Host "=== Engine System installed ==="
  Write-Host "Next steps (pick one):"
  Write-Host "  Claude Code  -> /engine-init"
  Write-Host "  Other agent  -> engine init"
  Write-Host "  Terminal     -> engine init"
  Write-Host ""
  Write-Host "engine init guides your agent through an interview to generate"
  Write-Host "ENGINE_MAP / CONTEXT / SYSTEM / ARCHITECTURE."
}
Write-Host ""

