param(
  [string]$Root = (Get-Location).Path
)

$ErrorActionPreference = "Stop"
trap { Write-Error "[check.ps1] error: $_"; exit 1 }
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
  if ($env:GITHUB_ACTIONS -eq "true") {
    Write-Host ("::error::" + ($Message -replace '%', '%25' -replace "`r", '%0D' -replace "`n", '%0A'))
  }
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
  # Windows PowerShell 5 defaults to the system code page when ParseFile reads
  # UTF-8 scripts without a BOM. Read the source explicitly as UTF-8 first so
  # compatibility checks validate PowerShell syntax rather than mojibake.
  $source = Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8
  $tokens = $null
  $errors = $null
  [System.Management.Automation.Language.Parser]::ParseInput($source, [ref]$tokens, [ref]$errors) | Out-Null
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

  Step "Engine VERSION stamp (v6 auto-update)"
  $verFiles = @("VERSION", "plugin\VERSION", "engine\VERSION")
  $allPresent = $true
  foreach ($vf in $verFiles) { if (-not (Test-Path $vf)) { $allPresent = $false } }
  if ($allPresent) {
    $rv = (Get-Content "VERSION" -Raw -Encoding UTF8).Trim()
    $pv = (Get-Content "plugin\VERSION" -Raw -Encoding UTF8).Trim()
    $ev = (Get-Content "engine\VERSION" -Raw -Encoding UTF8).Trim()
    if ($rv -eq $pv -and $rv -eq $ev) {
      Pass "VERSION consistent ($rv) across root/plugin/engine"
    } else {
      Fail "VERSION mismatch: root=$rv plugin=$pv engine=$ev"
    }
  } else {
    Fail "VERSION file missing (root/plugin/engine must all exist)"
  }

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

  Step "Behavior skills distribution"
  foreach ($b in @("decision-draft", "handoff", "scout", "task-run", "verify-writeback")) {
    $src = "contract\src\behaviors\$b.md"
    $prompt = "engine\prompts\behaviors\$b.md"
    $pluginPrompt = "plugin\engine\prompts\behaviors\$b.md"
    $skill = "plugin\.claude\skills\engine-$b\SKILL.md"
    if ((Test-Path $src) -and (Test-Path $prompt) -and (Test-Path $pluginPrompt) -and (Test-Path $skill)) {
      $h1 = (Get-FileHash $src -Algorithm SHA256).Hash
      $h2 = (Get-FileHash $prompt -Algorithm SHA256).Hash
      $h3 = (Get-FileHash $pluginPrompt -Algorithm SHA256).Hash
      $h4 = (Get-FileHash $skill -Algorithm SHA256).Hash
      if ($h1 -eq $h2 -and $h1 -eq $h3 -and $h1 -eq $h4) {
        Pass "behavior mirrors match: $b"
      } else {
        Fail "behavior mirror drift: $b"
      }
    } else {
      Fail "behavior files missing: $b"
    }
  }
  if ((Test-Path "engine\domains\routing.json") -and (Test-Path "plugin\engine\domains\routing.json")) {
    $rh1 = (Get-FileHash "engine\domains\routing.json" -Algorithm SHA256).Hash
    $rh2 = (Get-FileHash "plugin\engine\domains\routing.json" -Algorithm SHA256).Hash
    if ($rh1 -eq $rh2) { Pass "routing table mirrored" } else { Fail "routing table drift" }
  } else {
    Fail "routing table missing"
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
    @("engine/scripts/engine-context.ps1", "plugin/engine/scripts/engine-context.ps1"),
    @("engine/scripts/engine-context.sh", "plugin/engine/scripts/engine-context.sh"),
    @("engine/scripts/engine-hook-session-start.ps1", "plugin/engine/scripts/engine-hook-session-start.ps1"),
    @("engine/scripts/engine-hook-session-start.sh", "plugin/engine/scripts/engine-hook-session-start.sh"),
    @("engine/scripts/engine-hook-stop.ps1", "plugin/engine/scripts/engine-hook-stop.ps1"),
    @("engine/scripts/engine-hook-stop.sh", "plugin/engine/scripts/engine-hook-stop.sh"),
    @("engine/scripts/engine-hook-session-end.ps1", "plugin/engine/scripts/engine-hook-session-end.ps1"),
    @("engine/scripts/engine-hook-session-end.sh", "plugin/engine/scripts/engine-hook-session-end.sh"),
    @("engine/scripts/engine-hook.cmd", "plugin/engine/scripts/engine-hook.cmd"),
    @("engine/scripts/engine-sync-agent-anchors.ps1", "plugin/engine/scripts/engine-sync-agent-anchors.ps1"),
    @("engine/scripts/engine-sync-agent-anchors.sh", "plugin/engine/scripts/engine-sync-agent-anchors.sh"),
    @("engine/scripts/engine-migrate-contract.ps1", "plugin/engine/scripts/engine-migrate-contract.ps1"),
    @("engine/scripts/engine-migrate-contract.sh", "plugin/engine/scripts/engine-migrate-contract.sh"),
    @("engine/scripts/engine-verify.ps1", "plugin/engine/scripts/engine-verify.ps1"),
    @("engine/scripts/engine-verify.sh", "plugin/engine/scripts/engine-verify.sh"),
    @("engine/scripts/engine-check-update.ps1", "plugin/engine/scripts/engine-check-update.ps1"),
    @("engine/scripts/engine-check-update.sh", "plugin/engine/scripts/engine-check-update.sh"),
    @("engine/domains/routing.json", "plugin/engine/domains/routing.json"),
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
