# Engine System installer for Windows
# Usage: irm https://raw.githubusercontent.com/elysiayunchen/engine_system/main/install.ps1 | iex
# Or:    .\install.ps1 [-Update]

param([switch]$Update)

$REPO = "elysiayunchen/engine_system"
$BRANCH = "main"
$BASE_URL = "https://raw.githubusercontent.com/$REPO/$BRANCH/plugin"

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
  @{ src = "engine/scripts/engine-doctor.sh";      dest = "engine\scripts\engine-doctor.sh";      protect = $true }
  @{ src = "engine/scripts/engine-doctor.ps1";     dest = "engine\scripts\engine-doctor.ps1";     protect = $true }
)

Write-Host ""
Write-Host "Engine System installer" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

New-Item -ItemType Directory -Force -Path ".claude\commands", "engine", "engine\scripts" | Out-Null

$installed = 0; $skipped = 0

foreach ($f in $FILES) {
  $url = "$BASE_URL/$($f.src)"
  $dest = $f.dest

  # Root anchor files (CLAUDE.md / AGENTS.md): never clobber an existing one, in any mode.
  # A brand-new project gets the starter bootloader; an existing file is preserved so that
  # /engine-init can absorb its rules first, and /engine-reconcile keeps it in sync after.
  if (($dest -eq "CLAUDE.md" -or $dest -eq "AGENTS.md") -and (Test-Path $dest)) {
    Write-Host "  keep  $dest (已存在，保留；运行 /engine-init 吸收其规则后再改写)" -ForegroundColor Yellow
    $skipped++; continue
  }

  if ($Update -and -not $f.protect -and (Test-Path $dest)) {
    Write-Host "  skip  $dest (user data)" -ForegroundColor Yellow
    $skipped++; continue
  }

  if ($Update -and $f.protect) {
    Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
    Write-Host "  updated $dest" -ForegroundColor Green
    $installed++; continue
  }

  if (-not $Update -and (Test-Path $dest) -and $dest -like "engine\*" -and $dest -ne "engine\README.md") {
    Write-Host "  skip  $dest (already exists)" -ForegroundColor Yellow
    $skipped++; continue
  }

  Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
  Write-Host "  ✓ $dest" -ForegroundColor Green
  $installed++
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host "Done. $installed files installed, $skipped skipped." -ForegroundColor Green
Write-Host ""

if ($Update) {
  Write-Host "Plugin updated. Your engine/*.md files were not touched."
} else {
  Write-Host "Next steps:"
  Write-Host ""
  Write-Host "  Option A - Claude Code (recommended):"
  Write-Host "    Open Claude Code, then type: /engine-init"
  Write-Host "    Claude interviews you, picks a profile, writes engine/ENGINE_MAP.md + all files."
  Write-Host ""
  Write-Host "  Option B - Web Claude:"
  Write-Host "    Copy .claude\commands\engine-init.md and paste into claude.ai"
  Write-Host ""
  Write-Host "  After init:  /engine-update  /add-pitfall  /engine-status  /engine-ingest  /engine-extend  /engine-doctor  /engine-sync  /engine-reconcile"
}
Write-Host ""
