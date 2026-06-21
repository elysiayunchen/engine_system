# Engine System installer for Windows
# Usage:
#   Invoke-WebRequest https://raw.githubusercontent.com/elysiayunchen/engine_system/main/install.ps1 -OutFile install.ps1
#   powershell -NoProfile -File .\install.ps1 [-Update]
#
# Keep this installer file-download-first. Avoid pipe-to-execute examples:
# security products often flag remote-content direct execution as malware-like.

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
  @{ src = "engine/scripts/engine-hook-session-start.sh";   dest = "engine\scripts\engine-hook-session-start.sh";   protect = $true }
  @{ src = "engine/scripts/engine-hook-session-start.ps1";  dest = "engine\scripts\engine-hook-session-start.ps1";  protect = $true }
  @{ src = "engine/scripts/engine-hook-stop.sh";   dest = "engine\scripts\engine-hook-stop.sh";   protect = $true }
  @{ src = "engine/scripts/engine-hook-stop.ps1";  dest = "engine\scripts\engine-hook-stop.ps1";  protect = $true }
  @{ src = "engine/scripts/engine-hook-session-end.sh";   dest = "engine\scripts\engine-hook-session-end.sh";   protect = $true }
  @{ src = "engine/scripts/engine-hook-session-end.ps1";  dest = "engine\scripts\engine-hook-session-end.ps1";  protect = $true }
  @{ src = "engine/scripts/engine-sync-agent-anchors.sh";   dest = "engine\scripts\engine-sync-agent-anchors.sh";   protect = $true }
  @{ src = "engine/scripts/engine-sync-agent-anchors.ps1";  dest = "engine\scripts\engine-sync-agent-anchors.ps1";  protect = $true }
  @{ src = "engine/scripts/githooks/pre-commit";   dest = "engine\scripts\githooks\pre-commit";   protect = $true }
  @{ src = ".claude/settings.json";                dest = ".claude\settings.json";                protect = $false }
)

Write-Host ""
Write-Host "Engine System installer" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

New-Item -ItemType Directory -Force -Path ".claude\commands", "engine", "engine\scripts", "engine\scripts\githooks", "engine\.cache" | Out-Null

$installed = 0; $skipped = 0

foreach ($f in $FILES) {
  $url = "$BASE_URL/$($f.src)"
  $dest = $f.dest

  # Root anchor files (CLAUDE.md / AGENTS.md) and .claude/settings.json:
  # never clobber an existing one, in any mode.
  # A brand-new project gets the starter bootloader; an existing file is preserved so that
  # /engine-init can absorb its rules first, and /engine-reconcile keeps it in sync after.
  if (($dest -eq "CLAUDE.md" -or $dest -eq "AGENTS.md" -or $dest -eq ".claude\settings.json") -and (Test-Path $dest)) {
    Write-Host "  keep  $dest (已存在，保留；运行 /engine-sync 合并 hooks 字段)" -ForegroundColor Yellow
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

$insideGit = git rev-parse --is-inside-work-tree 2>$null
if ($insideGit -eq "true") {
  $gitDir = git rev-parse --git-dir 2>$null
  if ($gitDir) {
    $hookDir = Join-Path $gitDir "hooks"
    $hookPath = Join-Path $hookDir "pre-commit"
    New-Item -ItemType Directory -Force -Path $hookDir | Out-Null
    if (Test-Path $hookPath) {
      Write-Host "  keep  $hookPath (已存在；如需 B 层门禁，请手动合并 engine\scripts\githooks\pre-commit)" -ForegroundColor Yellow
      $skipped++
    } elseif (Test-Path "engine\scripts\githooks\pre-commit") {
      Copy-Item "engine\scripts\githooks\pre-commit" $hookPath -Force
      Write-Host "  ✓ $hookPath" -ForegroundColor Green
      $installed++
    }
  }
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host "Done. $installed files installed, $skipped skipped." -ForegroundColor Green
Write-Host ""

if ($Update) {
  Write-Host "Plugin updated. Your engine/*.md project memory was not overwritten."
  Write-Host "Next: open your AI agent in this project and run /engine-sync."
  Write-Host "/engine-sync migrates old engine files to the latest contract while preserving project-specific memory."
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
