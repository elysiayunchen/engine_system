# Engine System user-level CLI shim for Windows PowerShell.

param(
  [string]$Command = "help"
)

$Repo = if ($env:ENGINE_SYSTEM_REPO) { $env:ENGINE_SYSTEM_REPO } else { "elysiayunchen/engine_system" }
$Branch = if ($env:ENGINE_SYSTEM_BRANCH) { $env:ENGINE_SYSTEM_BRANCH } else { "main" }

function Show-Help {
@"
Engine System CLI

Usage:
  engine update        Update Engine System tooling in the current project
  engine help          Show this help

`engine update` downloads the latest installer and runs update mode. It does not overwrite
project-specific engine/*.md memory. After it finishes, open your AI agent and run
/engine-sync to migrate old engine files to the latest contract mechanisms, including
multi-lane workstreams, self-maintenance hooks, change capsules, and acceptance evidence.
"@ | Write-Host
}

switch ($Command) {
  "update" {
    $tmp = Join-Path $env:TEMP ("engine-install-" + [guid]::NewGuid().ToString("N") + ".ps1")
    try {
      Invoke-WebRequest -Uri "https://raw.githubusercontent.com/$Repo/$Branch/install.ps1" -OutFile $tmp -UseBasicParsing
      powershell -NoProfile -ExecutionPolicy Bypass -File $tmp -Update
      Write-Host ""
      Write-Host "Engine tooling updated from remote."
      Write-Host "Next: run /engine-sync in your AI agent."
      Write-Host "That migrates existing engine files to the latest mechanisms: multi-lane work,"
      Write-Host "self-maintenance hooks, change capsules, and acceptance evidence."
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
