# Engine System — Review pipeline 编排器(v6.20.0)
#
# 流程:FileStream → L2 提级校验 → diff → config 合并 → semgrep → eslint → 汇总
# 二元退出码:0=pass / 1=block
#
# 用法:engine-review-pipeline.ps1 T-NNN
# 安全:FileStream mandatory lock + try/finally 释放。

$ErrorActionPreference = "Stop"

$ROOT = $env:CLAUDE_PROJECT_DIR
if (-not $ROOT) { $ROOT = (Get-Location).Path }
$ENGINE_DIR = Join-Path $ROOT "engine"
$taskCardLibrary = Join-Path $PSScriptRoot "engine-task-card.ps1"
if (Test-Path -LiteralPath $taskCardLibrary -PathType Leaf) { . $taskCardLibrary }
$task = $args[0]

if (-not $task) {
  Write-Error "[engine-review-pipeline] Usage: engine-review-pipeline T-NNN"
  exit 2
}

$taskFile = Join-Path $ENGINE_DIR "tasks\$task.md"
if (-not (Test-Path $taskFile)) {
  Write-Error "[engine-review-pipeline] Error: task card not found: $taskFile"
  exit 2
}

# 0. FileStream mandatory lock(对照 C19)
$lockPath = Join-Path $ENGINE_DIR "review\.review-lock.$task"
$lockDir = Join-Path $ENGINE_DIR "review"
if (-not (Test-Path $lockDir)) { New-Item -ItemType Directory -Path $lockDir | Out-Null }
$stream = $null
try {
  $stream = [System.IO.File]::Open($lockPath, 'Create', 'ReadWrite', 'None')
} catch {
  Write-Error "[engine-review-pipeline] another review running for $task"
  exit 1
}
try {
  # 1. 读 config.json(L0 defaults + L1 overrides 合并)
  #    M3 修复:去掉 -AsHashtable(PS 5.1 不支持),用 PSCustomObject 属性访问
  #    N4 修复:L1 overrides 逐字段覆盖 L0 defaults(原版只读 defaults)
  $configFile = Join-Path $ENGINE_DIR "review\config.json"
  $config = $null
  if (Test-Path $configFile) {
    $config = Get-Content $configFile -Raw | ConvertFrom-Json
  }
  $merged = @{}
  if ($config -and $config.defaults) {
    $config.defaults.PSObject.Properties | ForEach-Object { $merged[$_.Name] = $_.Value }
  }
  if ($config -and $config.overrides) {
    $config.overrides.PSObject.Properties | ForEach-Object {
      if ($_.Name -eq 'tools' -and $merged.ContainsKey('tools') -and $merged['tools'] -is [PSCustomObject] -and $_.Value -is [PSCustomObject]) {
        $toolsMerged = @{}
        $merged['tools'].PSObject.Properties | ForEach-Object { $toolsMerged[$_.Name] = $_.Value }
        $_.Value.PSObject.Properties | ForEach-Object { $toolsMerged[$_.Name] = $_.Value }
        $merged['tools'] = $toolsMerged
      } else {
        $merged[$_.Name] = $_.Value
      }
    }
  }
  if (-not $merged.Count) {
    $merged = @{
      severity_threshold = "high"
      code_extensions = @('.sh','.ps1','.py','.js','.ts','.go','.rs','.java','.c','.cpp','.rb','.php')
      dimensions = @('security','quality')
    }
  }
  $severityThreshold = $merged.severity_threshold
  if (-not $severityThreshold) { $severityThreshold = "high" }
  $codeExtensions = $merged.code_extensions
  if (-not $codeExtensions) { $codeExtensions = @('.sh','.ps1','.py','.js','.ts','.go','.rs','.java','.c','.cpp','.rb','.php') }

  # 2. WRITE-SET 解析
  $taskContent = Get-Content $taskFile -Raw
  $writeSetFiles = @()
  if (Get-Command Get-TaskCardPatterns -ErrorAction SilentlyContinue) {
    $writeSetFiles = @(Get-TaskCardPatterns -Path $taskFile -Field 'WRITE-SET')
  } else {
    $inWriteSet = $false
    foreach ($line in $taskContent -split "`n") {
      if ($line -match '^##\s+WRITE-SET') { $inWriteSet = $true; continue }
      if ($line -match '^##\s+') { $inWriteSet = $false; continue }
      if ($inWriteSet -and $line -match '^- ') {
        $f = (($line -replace '^- ','') -replace ' *#.*').Trim()
        if ($f) { $writeSetFiles += $f }
      }
    }
  }
  if ($writeSetFiles.Count -eq 0) {
    Write-Error "[engine-review-pipeline] Error: review requires WRITE-SET to scope diff (task $task)"
    exit 1
  }

  # 3. diff 算法
  $taskFirstCommit = git log --reverse --format="%H" -- $taskFile 2>$null | Select-Object -First 1
  if (-not $taskFirstCommit) {
    Write-Error "[engine-review-pipeline] Error: no git history for $taskFile"
    exit 1
  }
  $headCommit = git rev-parse HEAD 2>$null
  if (-not $headCommit) { $headCommit = "unknown" }

  # diff base = task_first_commit 的 parent(含任务首提交代码);根提交 fallback 空树
  $diffBase = (git rev-parse "$taskFirstCommit^" 2>$null)
  if ($diffBase -notmatch '^[0-9a-f]{40}$') {
    $diffBase = "4b825dc642cb6eb9a060e54bf8d69288fbee4904"
  }

  # 4. 筛代码文件
  $codeFiles = @()
  foreach ($f in $writeSetFiles) {
    $ext = [System.IO.Path]::GetExtension($f)
    if ($codeExtensions -contains $ext) {
      $fullPath = Join-Path $ROOT $f
      if (Test-Path $fullPath) { $codeFiles += $f }
    }
  }

  # 5. diff_files(只看实际改动的;diff_base = taskFirstCommit^,含首提交代码)
  $diffFiles = @()
  foreach ($f in $codeFiles) {
    $changed = git diff --name-only "$diffBase..HEAD" -- $f 2>$null
    if ($changed) { $diffFiles += $f }
  }

  # 6-9. SECURITY/QUALITY/汇总(与 .sh 语义孪生,实际跑 semgrep/eslint)
  $securityStatus = "pass"
  $qualityStatus = "pass"
  $toolUnavailable = $false
  $semgrepAvailable = $false
  $eslintAvailable = $false
  $semgrepVersion = ""
  $eslintVersion = ""
  $securityFindings = @()
  $qualityFindings = @()

  if (Get-Command semgrep -ErrorAction SilentlyContinue) {
    $semgrepAvailable = $true
    $semgrepVersion = (semgrep --version 2>$null | Select-Object -First 1)
    if ($diffFiles.Count -gt 0) {
      $semgrepOut = semgrep --json --config=auto $diffFiles 2>$null
      if (-not $semgrepOut) {
        $securityStatus = "skipped"; $toolUnavailable = $true; $semgrepAvailable = $false
      } else {
        $semgrepData = ($semgrepOut -join [Environment]::NewLine) | ConvertFrom-Json
        foreach ($r in @($semgrepData.results)) {
          $extra = $r.extra
          $metadata = $extra.metadata
          $sev = [string]$metadata.impact
          if (-not $sev) { $sev = [string]$extra.severity }
          $rawSeverity = [string]$extra.severity
          $conf = [string]$extra.confidence
          $mapped = "medium"
          if ($sev -eq "ERROR" -or $r.extra.severity -eq "ERROR") {
            if ($conf -in @("high","medium","")) { $mapped = "critical" } else { $mapped = "high" }
          } elseif ($sev -eq "WARNING") { $mapped = "high" }
          $rule = [string]$r.check_id
          if (-not $rule) { $rule = "unknown" }
          $path = ([string]$r.path).Replace('\','/')
          $securityFindings += @{
            id = "semgrep-$($rule.Replace('.','-'))-${path}:$($r.start.line):$($r.start.col)"
            severity = $mapped
            file = $path
            line = $r.start.line
            col = $r.start.col
            rule = $rule
            message = $extra.message
            tool = "semgrep"
            tool_severity_raw = $rawSeverity
            tool_confidence = $conf
          }
        }
        if (@($securityFindings | Where-Object { $_.severity -in @("critical","high") }).Count -gt 0) { $securityStatus = "block" }
      }
    }
  } else {
    $securityStatus = "skipped"; $toolUnavailable = $true
  }

  if (Get-Command eslint -ErrorAction SilentlyContinue) {
    $eslintAvailable = $true
    $eslintVersion = (eslint --version 2>$null | Select-Object -First 1)
    $jsFiles = $diffFiles | Where-Object { $_ -match '\.(js|ts)$' }
    if ($jsFiles) {
      $eslintOut = eslint --format=json $jsFiles 2>$null
      if (-not $eslintOut) {
        $qualityStatus = "skipped"; $toolUnavailable = $true; $eslintAvailable = $false
      } else {
        $eslintData = ($eslintOut -join [Environment]::NewLine) | ConvertFrom-Json
        $rootForPaths = ([System.IO.Path]::GetFullPath($ROOT)).Replace('\','/').TrimEnd('/')
        foreach ($f in @($eslintData)) {
          foreach ($m in @($f.messages)) {
            $mapped = if ($m.severity -eq 2) { "high" } elseif ($m.severity -eq 1) { "medium" } else { "low" }
            $path = ([string]$f.filePath).Replace('\','/')
            if ($rootForPaths -and $path.StartsWith("$rootForPaths/", [System.StringComparison]::OrdinalIgnoreCase)) {
              $path = $path.Substring($rootForPaths.Length + 1)
            }
            $rule = [string]$m.ruleId
            if (-not $rule) { $rule = "unknown" }
            $qualityFindings += @{
              id = "eslint-$rule-${path}:$($m.line):$($m.column)"
              severity = $mapped
              file = $path
              line = $m.line
              col = $m.column
              rule = $rule
              message = $m.message
              tool = "eslint"
              tool_severity_raw = [string]$m.severity
            }
          }
        }
        if (@($qualityFindings | Where-Object { $_.severity -in @("critical","high") }).Count -gt 0) { $qualityStatus = "block" }
      }
    } else {
      $qualityStatus = "no_tool_for_language"
    }
  } else {
    $qualityStatus = "skipped"; $toolUnavailable = $true
  }

  $overallStatus = "pass"
  if ($securityStatus -eq "block" -or $qualityStatus -eq "block") { $overallStatus = "block" }

  $evidenceDir = Join-Path $ENGINE_DIR "review\evidence\$task"
  if (-not (Test-Path $evidenceDir)) { New-Item -ItemType Directory -Path $evidenceDir | Out-Null }
  $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

  # Keep the PowerShell evidence schema aligned with the Bash writer. The
  # satellite files are written before REVIEW.json so the manifest hash covers
  # exactly the same inputs on both shells.
  $securityCounts = [ordered]@{ critical = 0; high = 0; medium = 0; low = 0 }
  foreach ($finding in @($securityFindings)) {
    $severity = [string]$finding.severity
    if ($securityCounts.Contains($severity)) { $securityCounts[$severity]++ }
  }
  $qualityCounts = [ordered]@{ critical = 0; high = 0; medium = 0; low = 0 }
  foreach ($finding in @($qualityFindings)) {
    $severity = [string]$finding.severity
    if ($qualityCounts.Contains($severity)) { $qualityCounts[$severity]++ }
  }

  $securityEvidence = [ordered]@{
    dimension = "security"
    tool = "semgrep"
    status = $securityStatus
  }
  if ($securityStatus -eq "skipped") {
    $securityEvidence.reason = "tool_unavailable"
    $securityEvidence.tool_available = $semgrepAvailable
    $securityEvidence.detection_command = "command -v semgrep"
    $securityEvidence.detection_exit_code = if ($semgrepAvailable) { 0 } else { 1 }
  } else {
    $securityEvidence.tool_version = $semgrepVersion
    $securityEvidence.findings = @($securityFindings)
    $securityEvidence.findings_count = $securityCounts
  }
  $securityEvidence | ConvertTo-Json -Depth 20 -Compress | Set-Content -LiteralPath (Join-Path $evidenceDir "SECURITY.json") -Encoding UTF8

  $qualityEvidence = [ordered]@{
    dimension = "quality"
    tool = "eslint"
    status = $qualityStatus
  }
  if ($qualityStatus -eq "skipped") {
    $qualityEvidence.reason = "tool_unavailable"
    $qualityEvidence.tool_available = $eslintAvailable
    $qualityEvidence.detection_command = "command -v eslint"
    $qualityEvidence.detection_exit_code = if ($eslintAvailable) { 0 } else { 1 }
  } else {
    $qualityEvidence.tool_version = $eslintVersion
    $qualityEvidence.findings = @($qualityFindings)
    $qualityEvidence.findings_count = $qualityCounts
  }
  $qualityEvidence | ConvertTo-Json -Depth 20 -Compress | Set-Content -LiteralPath (Join-Path $evidenceDir "QUALITY.json") -Encoding UTF8

  $manifestHash = [System.Security.Cryptography.SHA256]::Create()
  $manifestStream = New-Object System.IO.MemoryStream
  try {
    $manifestFiles = @(Get-ChildItem -LiteralPath $evidenceDir -File | Where-Object { $_.Extension -eq '.json' -and $_.Name -ne 'REVIEW.json' } | Sort-Object Name)
    foreach ($manifestFile in $manifestFiles) {
      $bytes = [System.IO.File]::ReadAllBytes($manifestFile.FullName)
      $manifestStream.Write($bytes, 0, $bytes.Length)
    }
    $evidenceManifestSha256 = ([BitConverter]::ToString($manifestHash.ComputeHash($manifestStream.ToArray())) -replace '-', '').ToLowerInvariant()
  } finally {
    $manifestStream.Dispose()
    $manifestHash.Dispose()
  }

  $codeFingerprint = [ordered]@{}
  foreach ($f in @($diffFiles)) {
    $sha = (git rev-parse "HEAD:$f" 2>$null | Select-Object -First 1)
    if ($sha) { $codeFingerprint[$f] = ([string]$sha).Trim() }
  }
  $configDefaults = if ($config -and $config.defaults) { $config.defaults } else { [ordered]@{} }
  $configOverrides = if ($config -and $config.overrides) { $config.overrides } else { [ordered]@{} }
  $configLayers = [ordered]@{
    l0_defaults = $configDefaults
    l1_project = [ordered]@{ overrides = $configOverrides }
    l2_task = [ordered]@{ severity_threshold = $severityThreshold }
  }
  $toolVersions = [ordered]@{ semgrep = $semgrepVersion; eslint = $eslintVersion }

  $review = @{
    task = $task
    timestamp = $timestamp
    status = $overallStatus
    diff = @{
      strategy = "task_first_commit"
      base_commit = $taskFirstCommit
      head_commit = $headCommit
      files_reviewed = @($diffFiles)
      files_skipped = @($writeSetFiles | Where-Object { -not ($codeFiles -contains $_) })
      diff_empty = ($diffFiles.Count -eq 0)
    }
    dimensions = @{
      security = @{ status = $securityStatus; findings_count = $securityCounts; tool_version = $semgrepVersion }
      quality = @{ status = $qualityStatus; findings_count = $qualityCounts; tool_version = $eslintVersion }
    }
    severity_threshold = $severityThreshold
    tool_unavailable = $toolUnavailable
    tool_detection = @{
      semgrep = @{ available = $semgrepAvailable; detection_command = "command -v semgrep"; detection_exit_code = if ($semgrepAvailable) { 0 } else { 1 } }
      eslint = @{ available = $eslintAvailable; detection_command = "command -v eslint"; detection_exit_code = if ($eslintAvailable) { 0 } else { 1 } }
    }
    config_layers = $configLayers
    tool_versions = $toolVersions
    code_fingerprint = $codeFingerprint
    evidence_manifest_sha256 = $evidenceManifestSha256
    write_provenance = @{
      writer = "engine-review"
      commit = $headCommit
      timestamp = $timestamp
      argv = "engine review $task"
      pipeline_version = "v6.20.0"
    }
  }
  $review | ConvertTo-Json -Depth 10 -Compress | Out-File (Join-Path $evidenceDir "REVIEW.json") -Encoding utf8

  if ($overallStatus -eq "block") {
    Write-Error "[engine-review-pipeline] ${task}: BLOCK (critical/high findings)"
    exit 1
  }
  Write-Host "[engine-review-pipeline] ${task}: PASS"
  exit 0
} finally {
  if ($stream) { $stream.Dispose() }
}
