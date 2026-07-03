# Engine System user-level CLI shim for Windows PowerShell.

param(
  [string]$Command = "help",
  [string]$Task = ""
)

$Repo = if ($env:ENGINE_SYSTEM_REPO) { $env:ENGINE_SYSTEM_REPO } else { "elysiayunchen/engine_system" }
$Branch = if ($env:ENGINE_SYSTEM_BRANCH) { $env:ENGINE_SYSTEM_BRANCH } else { "main" }

function Show-Help {
@"
Engine System CLI

Usage:
  engine update        Update Engine System tooling in the current project
  engine verify T-NNN  Run behavior verification for a task card
  engine help          Show this help

`engine update` downloads the latest installer and runs update mode. It does not overwrite
project-specific engine/*.md memory. After it finishes, open your AI agent and run
/engine-sync. That runs the bundled engine-migrate-contract script so old engine files
receive the latest managed contract block while preserving project memory.
"@ | Write-Host
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
  "update" {
    $tmp = Join-Path $env:TEMP ("engine-install-" + [guid]::NewGuid().ToString("N") + ".ps1")
    try {
      Invoke-WebRequest -Uri "https://raw.githubusercontent.com/$Repo/$Branch/install.ps1" -OutFile $tmp -UseBasicParsing
      powershell -NoProfile -ExecutionPolicy Bypass -File $tmp -Update
      Write-Host ""
      Write-Host "Engine tooling updated from remote."
      Write-Host "Next: run /engine-sync in your AI agent."
      Write-Host "That runs engine/scripts/engine-migrate-contract.* to write the latest"
      Write-Host "managed contract block into existing engine files while preserving project memory."
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
