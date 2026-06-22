param(
  [string]$Root = (Get-Location).Path
)

$ErrorActionPreference = "Stop"
$failures = 0

function Step([string]$Name) {
  Write-Host ""
  Write-Host "== $Name ==" -ForegroundColor Cyan
}

function Pass([string]$Message) {
  Write-Host "PASS $Message" -ForegroundColor Green
}

function Fail([string]$Message) {
  $script:failures++
  Write-Host "FAIL $Message" -ForegroundColor Red
}

function Normalize-PathText([string]$Value) {
  return $Value.Replace("\", "/")
}

function Invoke-PwshFile([string]$Path, [string[]]$Arguments, [string]$Name) {
  $exe = (Get-Process -Id $PID).Path
  & $exe -NoProfile -File $Path @Arguments
  if ($LASTEXITCODE -eq 0) {
    Pass $Name
  } else {
    Fail "$Name exited $LASTEXITCODE"
  }
}

function Test-WindowsPowerShellCompatibility([string]$ProjectRoot) {
  $winPs = Get-Command powershell -ErrorAction SilentlyContinue
  if (-not $winPs) {
    Pass "Windows PowerShell unavailable, skipped"
    return
  }

  $currentExe = (Get-Process -Id $PID).Path
  if ((Resolve-Path $winPs.Source).Path -eq (Resolve-Path $currentExe).Path) {
    Pass "current host is Windows PowerShell"
    return
  }

  $compatScript = @'
param([string]$Root)
$failureCount = 0

Get-ChildItem -Path $Root -Recurse -File -Include *.ps1 | ForEach-Object {
  $tokens = $null
  $errors = $null
  [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errors) | Out-Null
  if ($errors.Count -gt 0) {
    $failureCount++
    Write-Host "FAIL $($_.FullName)"
    $errors | ForEach-Object {
      Write-Host "  $($_.Message) at $($_.Extent.StartLineNumber):$($_.Extent.StartColumnNumber)"
    }
  }
}

exit $failureCount
'@

  $tmp = Join-Path ([IO.Path]::GetTempPath()) ("engine-winps-parse-" + [guid]::NewGuid().ToString("N") + ".ps1")
  try {
    Set-Content -Path $tmp -Value $compatScript -Encoding UTF8
    & $winPs.Source -NoProfile -ExecutionPolicy Bypass -File $tmp -Root $ProjectRoot
    if ($LASTEXITCODE -eq 0) {
      Pass "all PowerShell scripts parse in Windows PowerShell"
    } else {
      Fail "Windows PowerShell parser exited $LASTEXITCODE"
    }
  } finally {
    Remove-Item -Path $tmp -ErrorAction SilentlyContinue
  }
}

Push-Location $Root
try {
  Step "Engine Doctor"
  Invoke-PwshFile ".\engine\scripts\engine-doctor.ps1" @("-Root", ".") "project doctor"
  Invoke-PwshFile ".\plugin\engine\scripts\engine-doctor.ps1" @("-Root", ".\plugin", "-PackageMode") "plugin package doctor"

  Step "PowerShell syntax"
  Get-ChildItem -Recurse -File -Include *.ps1 | ForEach-Object {
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors.Count -gt 0) {
      Fail $_.FullName
      $errors | ForEach-Object {
        Write-Host "  $($_.Message) at $($_.Extent.StartLineNumber):$($_.Extent.StartColumnNumber)" -ForegroundColor Red
      }
    } else {
      Pass (Resolve-Path -Relative $_.FullName)
    }
  }

  Step "Windows PowerShell compatibility"
  Test-WindowsPowerShellCompatibility (Get-Location).Path

  Step "Shell syntax"
  $bash = "C:\Program Files\Git\bin\bash.exe"
  if (-not (Test-Path $bash)) {
    $cmd = Get-Command bash -ErrorAction SilentlyContinue
    if ($cmd) { $bash = $cmd.Source }
  }
  if (-not (Test-Path $bash)) {
    Fail "bash not found"
  } else {
    & $bash -lc 'find . -name "*.sh" -o -path "*/githooks/pre-commit" | sort | while read f; do bash -n "$f" || exit 1; done'
    if ($LASTEXITCODE -eq 0) { Pass "all shell scripts" } else { Fail "shell syntax" }
  }

  Step "Installer manifest"
  $manifest = Get-Content -Raw .\plugin\manifest.json | ConvertFrom-Json
  $manifestSrc = @($manifest.files | ForEach-Object { $_.src } | Sort-Object)
  $manifestDest = @($manifest.files | ForEach-Object { Normalize-PathText $_.dest } | Sort-Object)
  $installShSrc = @(Select-String -Path .\install.sh -Pattern '^\s+"([^:"]+):([^:"]+):' | ForEach-Object { $_.Matches[0].Groups[1].Value } | Sort-Object)
  $installPs1Src = @(Select-String -Path .\install.ps1 -Pattern '@\{ src = "([^"]+)";\s+dest = "([^"]+)"' | ForEach-Object { $_.Matches[0].Groups[1].Value } | Sort-Object)
  $diffSh = @(Compare-Object $manifestSrc $installShSrc)
  $diffPs1 = @(Compare-Object $manifestSrc $installPs1Src)
  if ($diffSh.Count -eq 0) { Pass "manifest matches install.sh" } else { Fail "manifest differs from install.sh"; $diffSh | Format-Table | Out-String | Write-Host }
  if ($diffPs1.Count -eq 0) { Pass "manifest matches install.ps1" } else { Fail "manifest differs from install.ps1"; $diffPs1 | Format-Table | Out-String | Write-Host }
  foreach ($src in $manifestSrc) {
    if (-not (Test-Path (Join-Path "plugin" ($src -replace "/", [IO.Path]::DirectorySeparatorChar)))) {
      Fail "manifest source missing: $src"
    }
  }

  Step "Web prompt entrypoint"
  $rootPrompts = @(Get-ChildItem -Path . -File -Filter "ENGINE_FILE_SYSTEM*" | ForEach-Object { $_.Name })
  $unexpectedRootPrompts = @($rootPrompts | Where-Object { $_ -ne "ENGINE_FILE_SYSTEM_v5.md" })
  if ((Test-Path ".\ENGINE_FILE_SYSTEM_v5.md") -and $unexpectedRootPrompts.Count -eq 0) {
    Pass "single active root web prompt"
  } else {
    Fail "root must contain only ENGINE_FILE_SYSTEM_v5.md as active web prompt"
    $rootPrompts | ForEach-Object { Write-Host "  root prompt: $_" -ForegroundColor Red }
  }
  foreach ($archivedPrompt in @("ENGINE_FILE_SYSTEM_v4_legacy.txt", "ENGINE_FILE_SYSTEM_v5.2.md", "ENGINE_FILE_SYSTEM_v5.5.md")) {
    if (Test-Path (Join-Path ".\archive\engine-file-system" $archivedPrompt)) {
      Pass "archived prompt exists: $archivedPrompt"
    } else {
      Fail "archived prompt missing: $archivedPrompt"
    }
  }

  Step "Bundled duplicate drift"
  $pairs = @(
    @("engine/bin/engine", "plugin/bin/engine"),
    @("engine/bin/engine.ps1", "plugin/bin/engine.ps1"),
    @("engine/bin/engine.cmd", "plugin/bin/engine.cmd"),
    @("engine/scripts/engine-doctor.ps1", "plugin/engine/scripts/engine-doctor.ps1"),
    @("engine/scripts/engine-doctor.sh", "plugin/engine/scripts/engine-doctor.sh"),
    @("engine/scripts/engine-hook-session-start.ps1", "plugin/engine/scripts/engine-hook-session-start.ps1"),
    @("engine/scripts/engine-hook-session-start.sh", "plugin/engine/scripts/engine-hook-session-start.sh"),
    @("engine/scripts/engine-hook-stop.ps1", "plugin/engine/scripts/engine-hook-stop.ps1"),
    @("engine/scripts/engine-hook-stop.sh", "plugin/engine/scripts/engine-hook-stop.sh"),
    @("engine/scripts/engine-hook-session-end.ps1", "plugin/engine/scripts/engine-hook-session-end.ps1"),
    @("engine/scripts/engine-hook-session-end.sh", "plugin/engine/scripts/engine-hook-session-end.sh"),
    @("engine/scripts/engine-sync-agent-anchors.ps1", "plugin/engine/scripts/engine-sync-agent-anchors.ps1"),
    @("engine/scripts/engine-sync-agent-anchors.sh", "plugin/engine/scripts/engine-sync-agent-anchors.sh"),
    @("engine/scripts/engine-migrate-contract.ps1", "plugin/engine/scripts/engine-migrate-contract.ps1"),
    @("engine/scripts/engine-migrate-contract.sh", "plugin/engine/scripts/engine-migrate-contract.sh"),
    @("engine/scripts/githooks/pre-commit", "plugin/engine/scripts/githooks/pre-commit")
  )
  foreach ($pair in $pairs) {
    if (-not (Test-Path $pair[0]) -or -not (Test-Path $pair[1])) {
      Fail "missing pair: $($pair[0]) <=> $($pair[1])"
      continue
    }
    $left = (Get-FileHash $pair[0] -Algorithm SHA256).Hash
    $right = (Get-FileHash $pair[1] -Algorithm SHA256).Hash
    if ($left -eq $right) { Pass "$($pair[0]) <=> $($pair[1])" } else { Fail "drift: $($pair[0]) <=> $($pair[1])" }
  }
} finally {
  Pop-Location
}

Write-Host ""
if ($failures -gt 0) {
  Write-Host "CHECK FAILED: $failures issue(s)" -ForegroundColor Red
  exit 1
}

Write-Host "CHECK PASSED" -ForegroundColor Green
exit 0
