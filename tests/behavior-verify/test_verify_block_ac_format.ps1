# Regression test for issue #13 / D-037: all four supported AC declaration
# shapes must reach the PowerShell behavior verifier.
$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$fixture = Join-Path ([IO.Path]::GetTempPath()) ("engine-ac-formats-" + [guid]::NewGuid().ToString("N"))

try {
  New-Item -ItemType Directory -Path (Join-Path $fixture "engine\tasks"), (Join-Path $fixture "engine\evidence"), (Join-Path $fixture "src") -Force | Out-Null
  & git -C $fixture init -q
  & git -C $fixture config user.email test@example.invalid
  & git -C $fixture config user.name "Engine Test"
  Set-Content -Path (Join-Path $fixture "src\fixture.txt") -Value "fixture" -Encoding UTF8
  @'
status: active

## WRITE-SET
- src/fixture.txt

## FORBIDDEN
- never

## AC
AC: AC-1 one-line declaration | verify: true

### AC-2: section declaration
verify: true

- AC-3: list declaration | verify: true

| AC-4 | table declaration | verify: true |
'@ | Set-Content -Path (Join-Path $fixture "engine\tasks\T-902.md") -Encoding UTF8
  & git -C $fixture add .
  & git -C $fixture commit -q -m fixture

  $oldRoot = $env:CLAUDE_PROJECT_DIR
  $env:CLAUDE_PROJECT_DIR = $fixture
  try {
    & pwsh -NoProfile -File (Join-Path $repoRoot "engine\scripts\engine-verify.ps1") -Task T-902 -Preflight *> (Join-Path $fixture "verify.log")
    if ($LASTEXITCODE -ne 0) { throw "PowerShell verifier exited with $LASTEXITCODE" }
  } finally {
    if ($null -eq $oldRoot) { Remove-Item Env:CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue }
    else { $env:CLAUDE_PROJECT_DIR = $oldRoot }
  }

  foreach ($ac in @("AC-1", "AC-2", "AC-3", "AC-4")) {
    $evidence = Join-Path $fixture ("engine\evidence\T-902\$ac.json")
    if (-not (Test-Path $evidence)) { throw "Missing evidence for $ac" }
    if ((Get-Content -Raw $evidence) -notmatch '(?i)"status"\s*:\s*"pass"') { throw "Evidence for $ac did not pass" }
  }
  $count = @(Get-ChildItem (Join-Path $fixture "engine\evidence\T-902") -Filter "AC-*.json").Count
  if ($count -ne 4) { throw "Expected 4 AC evidence files, got $count" }
  Write-Output "PASS test_verify_block_ac_format.ps1"
} finally {
  if (Test-Path $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
}
