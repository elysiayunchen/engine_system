# Engine System — Gate: 质量门禁聚合器 (v6.24.0)
#
# 聚合 verify/review/review-agent/prove 各门禁证据 → 写 GATE.json
# 二元退出码: 0=全部通过(可标 done) / 1=存在失败或待跑门禁
#
# 用法:
#   engine-gate.ps1 T-NNN          聚合当前证据状态 → 写 GATE.json
#   engine-gate.ps1 T-NNN --run    对 pending 门禁依次执行后聚合
#
# 证据: engine/evidence/T-NNN/GATE.json
# 安全: FileStream 防并发; provenance 写入; 工具缺失 → skipped(不 block)

$ErrorActionPreference = "Stop"

$ROOT = $env:CLAUDE_PROJECT_DIR
if (-not $ROOT) { $ROOT = (Get-Location).Path }
$ENGINE_DIR = Join-Path $ROOT "engine"
$taskCardLibrary = Join-Path $PSScriptRoot "engine-task-card.ps1"
if (Test-Path -LiteralPath $taskCardLibrary -PathType Leaf) { . $taskCardLibrary }

$task = ""
$runMode = $false
foreach ($a in $args) {
  if ($a -eq "--run") { $runMode = $true }
  elseif ($a -match '^T-\d+') { $task = $a }
  else { Write-Error "[engine-gate] Unknown argument: $a"; exit 2 }
}

if (-not $task) {
  Write-Error "[engine-gate] Usage: engine gate T-NNN [--run]"
  exit 2
}

$taskFile = Join-Path $ENGINE_DIR "tasks\$task.md"
if (-not (Test-Path $taskFile)) {
  Write-Error "[engine-gate] Error: task card not found: $taskFile"
  exit 2
}

# 0. FileStream mandatory lock
$evidenceDir = Join-Path $ENGINE_DIR "evidence\$task"
if (-not (Test-Path $evidenceDir)) { New-Item -ItemType Directory -Path $evidenceDir -Force | Out-Null }
$lockPath = Join-Path $ENGINE_DIR "evidence\.gate-lock.$task"
$stream = $null
try {
  $stream = [System.IO.File]::Open($lockPath, 'Create', 'ReadWrite', 'None')
} catch {
  Write-Error "[engine-gate] another gate check running for $task"
  exit 1
}

try {
  # 1. 读 gate config
  $configFile = Join-Path $ENGINE_DIR "gate\config.json"
  if (-not (Test-Path $configFile)) {
    Write-Error "[engine-gate] Error: gate config not found: $configFile"
    exit 2
  }
  $config = Get-Content $configFile -Raw -Encoding UTF8 | ConvertFrom-Json
  $gatesList = @("verify", "review", "review_agent", "prove")
  if ($config.defaults -and $config.defaults.gates) {
    $gatesList = @($config.defaults.gates)
  }
  $codeExtensions = @(".sh", ".ps1", ".py", ".js", ".ts", ".go", ".rs", ".java", ".c", ".cpp", ".rb", ".php")
  if ($config.defaults -and $config.defaults.code_extensions) {
    $codeExtensions = @($config.defaults.code_extensions)
  }
  $docsOnlySkip = @("review", "review_agent", "prove")
  if ($config.defaults -and $config.defaults.docs_only_skip) {
    $docsOnlySkip = @($config.defaults.docs_only_skip)
  }

  # 2. 判断 WRITE-SET 是否含代码文件
  $taskContent = Get-Content $taskFile -Raw -Encoding UTF8
  $hasCode = $false
  $writeSetPaths = @()
  if (Get-Command Get-TaskCardPatterns -ErrorAction SilentlyContinue) {
    $writeSetPaths = @(Get-TaskCardPatterns -Path $taskFile -Field 'WRITE-SET')
  } else {
    $wsMatch = [regex]::Match($taskContent, '(?ms)^##\s+WRITE-SET\s*$([\s\S]*?)(?=^##\s+|\z)')
    if ($wsMatch.Success) {
      $writeSetPaths = @($wsMatch.Groups[1].Value -split "`n" | Where-Object { $_.Trim().StartsWith('- ') } | ForEach-Object { $_.Trim().Substring(2).Trim() })
    }
  }
  foreach ($p in $writeSetPaths) {
    $p = ($p -replace '\s*[\(\[].*$', '').Trim()
    $ext = [System.IO.Path]::GetExtension($p)
    if ($codeExtensions -contains $ext) { $hasCode = $true; break }
  }

  # Fallback: expand WRITE-SET paths on disk (covers new files, dirs, globs, annotations)
  if (-not $hasCode) {
    foreach ($p in $writeSetPaths) {
      $p = $p.Trim()
      # Strip annotations: (new), [added], etc.
      $p = $p -replace "\s*[\(\[].*$", ""
      $full = Join-Path $ROOT $p
      # Direct file check
      if (Test-Path $full -PathType Leaf) {
        $ext = [System.IO.Path]::GetExtension($full)
        if ($codeExtensions -contains $ext) { $hasCode = $true; break }
        continue
      }
      # Glob/directory expansion
      $resolved = @(Resolve-Path $full -ErrorAction SilentlyContinue)
      if ($resolved.Count -eq 0) {
        # Try as directory
        if (Test-Path $full -PathType Container) {
          $children = Get-ChildItem $full -File -ErrorAction SilentlyContinue
          foreach ($child in $children) {
            $ext = $child.Extension
            if ($codeExtensions -contains $ext) { $hasCode = $true; break }
          }
          if ($hasCode) { break }
        }
        continue
      }
      foreach ($r in $resolved) {
        if (Test-Path $r.Path -PathType Leaf) {
          $ext = [System.IO.Path]::GetExtension($r.Path)
          if ($codeExtensions -contains $ext) { $hasCode = $true; break }
        } elseif (Test-Path $r.Path -PathType Container) {
          $children = Get-ChildItem $r.Path -File -ErrorAction SilentlyContinue
          foreach ($child in $children) {
            $ext = $child.Extension
            if ($codeExtensions -contains $ext) { $hasCode = $true; break }
          }
          if ($hasCode) { break }
        }
      }
      if ($hasCode) { break }
    }
  }

  # 3. 门禁检查函数
  function Check-Verify {
    if (Get-Command Get-TaskCardAcDeclarations -ErrorAction SilentlyContinue) {
      $acCount = @(Get-TaskCardAcDeclarations -Path $taskFile).Count
    } else {
      $acCount = ([regex]::Matches($taskContent, '(?m)(^AC-|^AC:.*AC-)')).Count
    }
    if ($acCount -eq 0) { return @{status="pass"; detail="0/0 AC (no ACs declared)"; fix=""} }
    $passCount = 0
    $acFiles = Get-ChildItem (Join-Path $ENGINE_DIR "evidence\$task\AC-*.json") -ErrorAction SilentlyContinue
    if ($acFiles) {
      foreach ($f in $acFiles) {
        $content = Get-Content $f.FullName -Raw -Encoding UTF8
        if ($content -match '"status"\s*:\s*"pass"') { $passCount++ }
      }
    }
    if ($passCount -ge $acCount) {
      return @{status="pass"; detail="$passCount/$acCount AC PASS"; fix=""}
    } else {
      return @{status="block"; detail="$passCount/$acCount AC PASS (need $acCount)"; fix="engine verify $task"}
    }
  }

  function Check-Review {
    $reviewFile = Join-Path $ENGINE_DIR "review\evidence\$task\REVIEW.json"
    if (-not (Test-Path $reviewFile)) {
      return @{status="pending"; detail="REVIEW.json not found"; fix="engine review $task"}
    }
    $data = Get-Content $reviewFile -Raw -Encoding UTF8 | ConvertFrom-Json
    $st = if ($data.status) { $data.status } else { "unknown" }
    switch ($st) {
      "pass"     { return @{status="pass"; detail="linter review passed"; fix=""} }
      "block"    { return @{status="block"; detail="linter found blocking issues"; fix="engine review $task"} }
      "degraded" { return @{status="pass"; detail="linter degraded (tool unavailable)"; fix=""} }
      "skipped"  { return @{status="skipped"; detail="tool unavailable"; fix=""} }
      default    { return @{status="pending"; detail="unknown review status: $st"; fix="engine review $task"} }
    }
  }

  function Check-ReviewAgent {
    $reviewConfig = Join-Path $ENGINE_DIR "review\config.json"
    $arEnabled = $true
    if (Test-Path $reviewConfig) {
      $rc = Get-Content $reviewConfig -Raw -Encoding UTF8 | ConvertFrom-Json
      if ($rc.defaults -and $rc.defaults.agent_review -and $rc.defaults.agent_review.enabled -eq $false) {
        $arEnabled = $false
      }
    }
    if (-not $arEnabled) { return @{status="skipped"; detail="disabled in config"; fix=""} }
    $agentFile = Join-Path $ENGINE_DIR "review\evidence\$task\AGENT-REVIEW.json"
    if (-not (Test-Path $agentFile)) {
      return @{status="pending"; detail="AGENT-REVIEW.json not found"; fix="engine review-agent $task --package"}
    }
    $data = Get-Content $agentFile -Raw -Encoding UTF8 | ConvertFrom-Json
    $st = if ($data.status) { $data.status } else { "unknown" }
    switch ($st) {
      "pass"     { return @{status="pass"; detail="agent review passed"; fix=""} }
      "concerns" { return @{status="concerns"; detail="agent review found high-severity issues"; fix="engine review-agent $task --package"} }
      "block"    { return @{status="block"; detail="agent review blocked"; fix="engine review-agent $task --package"} }
      default    { return @{status="pending"; detail="unknown agent review status: $st"; fix="engine review-agent $task --package"} }
    }
  }

  function Check-Prove {
    $proveFile = Join-Path $ENGINE_DIR "evidence\$task\PROVE.json"
    if (-not (Test-Path $proveFile)) {
      return @{status="pending"; detail="PROVE.json not found"; fix="engine prove $task --execute"}
    }
    $data = Get-Content $proveFile -Raw -Encoding UTF8 | ConvertFrom-Json
    $st = if ($data.status) { $data.status.ToString().ToLower() } else { "unknown" }
    switch ($st) {
      "pass"    { return @{status="pass"; detail="prove assertions passed"; fix=""} }
      "fail"    { return @{status="block"; detail="prove assertions failed"; fix="engine prove $task --execute"} }
      "timeout" { return @{status="block"; detail="prove timed out"; fix="engine prove $task --execute"} }
      default   { return @{status="pending"; detail="unknown prove status: $st"; fix="engine prove $task --execute"} }
    }
  }

  # --run 模式
  if ($runMode) {
    Write-Host "[engine-gate] Running pending gates for $task..."
    $psExe = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
    if (-not $psExe) { $psExe = (Get-Command powershell -ErrorAction SilentlyContinue).Source }
    $acFiles = Get-ChildItem (Join-Path $ENGINE_DIR "evidence\$task\AC-*.json") -ErrorAction SilentlyContinue
    if (-not $acFiles) {
      Write-Host "[engine-gate] Running: engine verify $task"
      $verifyCli = Join-Path $ROOT "engine\bin\engine.ps1"
      $verifyScript = Join-Path $ENGINE_DIR "scripts\engine-verify.ps1"
      if ($psExe -and (Test-Path $verifyCli)) { & $psExe -NoProfile -ExecutionPolicy Bypass -File $verifyCli verify $task 2>&1 | Out-Host }
      elseif ($psExe -and (Test-Path $verifyScript)) { & $psExe -NoProfile -ExecutionPolicy Bypass -File $verifyScript -Task $task 2>&1 | Out-Host }
    }
    if ($hasCode -and -not (Test-Path (Join-Path $ENGINE_DIR "review\evidence\$task\REVIEW.json"))) {
      Write-Host "[engine-gate] Running: engine review $task"
      $reviewScript = Join-Path $ENGINE_DIR "scripts\engine-review-pipeline.ps1"
      if ($psExe -and (Test-Path $reviewScript)) { & $psExe -NoProfile -ExecutionPolicy Bypass -File $reviewScript $task 2>&1 | Out-Host }
    }
    if ($hasCode -and -not (Test-Path (Join-Path $ENGINE_DIR "review\evidence\$task\AGENT-REVIEW.json"))) {
      Write-Host "[engine-gate] Manual step required:"
      Write-Host "  1. engine review-agent $task --package"
      Write-Host "  2. Feed review-package.md to an external agent"
      Write-Host "  3. engine review-agent $task --validate"
    }
    if ($hasCode -and -not (Test-Path (Join-Path $ENGINE_DIR "evidence\$task\PROVE.json"))) {
      $proveScript = Join-Path $ENGINE_DIR "scripts\engine-prove.ps1"
      if ($psExe -and (Test-Path $proveScript)) {
        Write-Host "[engine-gate] Running: engine prove $task --execute"
        & $psExe -NoProfile -ExecutionPolicy Bypass -File $proveScript -Task $task -Mode --execute 2>&1 | Out-Host
      }
    }
    Write-Host ""
  }

  # 4. 聚合
  $gateResults = @{}
  $overallStatus = "pass"
  $failCount = 0

  foreach ($g in $gatesList) {
    # 适用性
    if (-not $hasCode -and $docsOnlySkip -contains $g) {
      $gateResults[$g] = @{status="skipped"; detail="no code changes in WRITE-SET"; fix=""}
      continue
    }
    $result = switch ($g) {
      "verify"       { Check-Verify }
      "review"       { Check-Review }
      "review_agent" { Check-ReviewAgent }
      "prove"        { Check-Prove }
      default        { @{status="skipped"; detail="unknown gate: $g"; fix=""} }
    }
    $gateResults[$g] = $result
    if ($result.status -in @("block", "pending", "concerns")) {
      $overallStatus = "block"
      $failCount++
    }
  }

  # 5. 写 GATE.json
  $headCommit = cmd /c "git -C `"$ROOT`" rev-parse HEAD 2>nul"
  if (-not $headCommit) { $headCommit = "unknown" }
  $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
  $gateArgv = if ($env:ENGINE_CLI_ENTRYPOINT) { $env:ENGINE_CLI_ENTRYPOINT } else { "engine-gate.ps1 " + ($args -join " ") }

  $gateObj = [ordered]@{
    task = $task
    timestamp = $timestamp
    status = $overallStatus
    gates = [ordered]@{}
    config = [ordered]@{
      gates_applicable = @()
      gates_skipped = @()
      skip_reasons = [ordered]@{}
    }
    write_provenance = [ordered]@{
      writer = "engine-gate"
      commit = $headCommit
      timestamp = $timestamp
      argv = $gateArgv
    }
  }

  $applicable = @()
  $skipped = @()
  foreach ($g in $gatesList) {
    $r = $gateResults[$g]
    $entry = [ordered]@{ status = $r.status; detail = $r.detail; checked_at = $timestamp }
    if ($r.fix) { $entry["fix_command"] = $r.fix }
    $gateObj.gates[$g] = $entry
    if ($r.status -eq "skipped") {
      $skipped += $g
      $gateObj.config.skip_reasons[$g] = $r.detail
    } else {
      $applicable += $g
    }
  }
  $gateObj.config.gates_applicable = $applicable
  $gateObj.config.gates_skipped = $skipped

  $outPath = Join-Path $ENGINE_DIR "evidence\$task\GATE.json"
  $gateObj | ConvertTo-Json -Depth 10 | Set-Content $outPath -Encoding UTF8 -NoNewline
  Add-Content $outPath "`n" -NoNewline -Encoding UTF8

  # 6. 打印摘要
  Write-Host ""
  Write-Host "[Engine System] Gate status for ${task}: $($overallStatus.ToUpper())"
  Write-Host ""
  foreach ($g in $gatesList) {
    $r = $gateResults[$g]
    switch ($r.status) {
      "pass"    { Write-Host "  PASS ${g}: $($r.detail)" }
      "skipped" { Write-Host "  SKIP ${g}: $($r.detail)" }
      "exempt"  { Write-Host "  EXEMPT ${g}: $($r.detail)" }
      default {
        Write-Host "  FAIL ${g}: $($r.detail)"
        if ($r.fix) { Write-Host "       Fix: $($r.fix)" }
      }
    }
  }
  Write-Host ""
  if ($overallStatus -eq "pass") {
    Write-Host "All gates satisfied. Task $task can be marked done."
  } else {
    Write-Host "Run 'engine gate $task' after fixing, then stage engine/evidence/$task/GATE.json."
  }

  # 7. 退出码
  if ($overallStatus -eq "pass") { exit 0 } else { exit 1 }

} finally {
  if ($stream) { $stream.Dispose() }
}
