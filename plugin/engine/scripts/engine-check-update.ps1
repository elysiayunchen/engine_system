# Engine System - check for remote updates (PowerShell twin)
#
# Compares local engine/VERSION against the remote repository VERSION.
# Exit codes: 0 = up to date | 7 = update available | 8 = network error
#
# Idempotent and fail-open: a missing local version falls back to parsing
# ENGINE_FILE_SYSTEM_v5.md; a network failure exits 8 without touching state.

param([Parameter(Mandatory=$false)][string]$Root)

$Repo = $env:ENGINE_SYSTEM_REPO
if (-not $Repo) { $Repo = "elysiayunchen/engine_system" }
$Branch = $env:ENGINE_SYSTEM_BRANCH
if (-not $Branch) { $Branch = "main" }
if (-not $Root) { $Root = $PWD.Path }

$LocalFile = Join-Path $Root "engine\VERSION"
$RemoteUrl = "https://raw.githubusercontent.com/$Repo/$Branch/VERSION"

# Read local version: prefer engine/VERSION, fall back to ENGINE_FILE_SYSTEM_v5.md header.
$localVersion = "unknown"
if (Test-Path $LocalFile) {
  $localVersion = (Get-Content $LocalFile -Raw -Encoding UTF8).Trim()
} elseif (Test-Path (Join-Path $Root "ENGINE_FILE_SYSTEM_v5.md")) {
  $hit = Select-String -Path (Join-Path $Root "ENGINE_FILE_SYSTEM_v5.md") -Pattern 'Version:\s*([0-9.]+)' | Select-Object -First 1
  if ($hit) { $localVersion = $hit.Matches[0].Groups[1].Value }
}

# Fetch remote version (10s timeout).
$remoteVersion = ""
try {
  $resp = Invoke-WebRequest -Uri $RemoteUrl -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
  $remoteVersion = $resp.Content.Trim()
} catch {
  Write-Error "Network error: could not fetch remote VERSION ($RemoteUrl)."
  exit 8
}

if (-not $remoteVersion) {
  Write-Error "Network error: empty remote VERSION."
  exit 8
}

Write-Output "Local:  $localVersion"
Write-Output "Remote: $remoteVersion"

if ($localVersion -eq $remoteVersion) {
  Write-Output "Up to date."
  exit 0
} else {
  Write-Output "Update available: $localVersion -> $remoteVersion"
  Write-Output "Run: engine update"
  exit 7
}
