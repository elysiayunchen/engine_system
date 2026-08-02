# Shared task-card parsing helpers.
# Dot-source this file from task-card consumers; it has no entry-point side effects.

function Get-TaskCardPatterns {
  param(
    [string]$Path,
    [string]$Content,
    [Parameter(Mandatory=$true)][string]$Field
  )
  if ($PSBoundParameters.ContainsKey('Content')) {
    $lines = @($Content -split "`n")
  } else {
    if (-not $Path -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) { return @() }
    $lines = @(Get-Content -LiteralPath $Path -Encoding UTF8)
  }
  $escaped = [regex]::Escape($Field)
  $inFrontmatter = $false
  $inFrontField = $false
  $mode = ''
  $values = New-Object System.Collections.Generic.List[string]

  $emit = {
    param([string]$Value)
    $value = $Value.Trim()
    if ([string]::IsNullOrWhiteSpace($value)) { return }
    # Remove complete inline annotations before splitting. An annotation may
    # contain commas; splitting first would leak its trailing fragment as a
    # fake path (for example `file.sh (chmod, no content change)`).
    $value = $value -replace '\s*\([^)]*\)', ''
    $value = $value -replace '\s*\[[^]]*\]', ''
    foreach ($part in ($value -split ',\s*')) {
      $item = $part.Trim()
      $item = $item -replace '\s+\(.*$', ''
      $item = $item -replace '\s+\[.*$', ''
      $item = $item -replace '\s+#.*$', ''
      $item = $item -replace '^\[\s*', ''
      $item = $item -replace '\s*\]$', ''
      $item = $item.Trim()
      if ($item) { [void]$values.Add($item) }
    }
  }

  for ($index = 0; $index -lt $lines.Count; $index++) {
    $line = ([string]$lines[$index]).TrimEnd("`r")
    $line = $line -replace '^\s*>\s*', ''
    if ($index -eq 0 -and $line -match '^\s*---\s*$') {
      $inFrontmatter = $true
      continue
    }
    if ($inFrontmatter -and $line -match '^\s*---\s*$') {
      $inFrontmatter = $false
      $inFrontField = $false
      continue
    }
    if ($inFrontmatter) {
      if (-not $mode -and $line -match "^\s*$escaped\s*:\s*(.*?)\s*$") {
        $mode = 'front'
        $inFrontField = [string]::IsNullOrWhiteSpace($Matches[1])
        if (-not $inFrontField) { & $emit $Matches[1] }
        continue
      }
      if ($mode -eq 'front' -and $inFrontField -and $line -match '^\s*-\s+(.+?)\s*$') {
        & $emit $Matches[1]
        continue
      }
      if ($mode -eq 'front' -and $inFrontField -and $line -match '^\s*[A-Za-z0-9_-]+\s*:') { $inFrontField = $false }
      continue
    }

    if ($mode -eq 'front') { continue }
    if ($line -match "^\s*##\s+$escaped\s*$") {
      $mode = 'section'
      continue
    }
    if (-not $mode) {
      if ($line -match "^\s*$escaped\s*:\s*(.+?)\s*$") {
        $mode = 'inline'
        & $emit $Matches[1]
        continue
      }
      if ($line -match '^\s*##\s+') {
        $mode = 'body'
        continue
      }
    }
    if ($mode -eq 'section') {
      if ($line -match '^\s*##\s+') {
        $mode = 'done'
        continue
      }
      if ($line -match '^\s*-\s+(.+?)\s*$') {
        & $emit $Matches[1]
      }
    }
  }
  return @($values.ToArray())
}

function Get-TaskCardAcDeclarations {
  param([Parameter(Mandatory=$true)][string]$Path)
  $results = New-Object System.Collections.Generic.List[object]
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return @($results.ToArray()) }
  $sepArrow = [string][char]0x2192
  $acIdPattern = 'AC-[A-Za-z]*\d+(?:\.\d+)*'
  $sectionAc = ''
  $pendingAc = ''
  foreach ($line in (Get-Content -LiteralPath $Path -Encoding UTF8)) {
    if ($line -match "^###\s+($acIdPattern)") {
      $sectionAc = $Matches[1]; $pendingAc = ''; continue
    }
    if ($line -match '^###') { $sectionAc = '' }
    if ($sectionAc) {
      if ($line -match '^\s*verify:\s*(.+?)\s*$') {
        [void]$results.Add([PSCustomObject]@{ AcId=$sectionAc; VerifyCmd=$Matches[1] })
        $sectionAc = ''
        continue
      }
      continue
    }
    if ($line -match "^AC:\s*($acIdPattern)") {
      $acId = $Matches[1]
      $verifyCmd = ''
      if ($line -match "[|$sepArrow]\s*verify:\s*(.+?)\s*$") { $verifyCmd = $Matches[1] }
      [void]$results.Add([PSCustomObject]@{ AcId=$acId; VerifyCmd=$verifyCmd })
      $pendingAc = ''
      continue
    }
    if ($line -match "^-\s+($acIdPattern)") {
      $acId = $Matches[1]
      $verifyCmd = ''
      if ($line -match '\|\s*verify:\s*(.+?)\s*$') { $verifyCmd = $Matches[1] }
      if ($verifyCmd) {
        [void]$results.Add([PSCustomObject]@{ AcId=$acId; VerifyCmd=$verifyCmd })
      } else { $pendingAc = $acId }
      continue
    }
    if ($pendingAc) {
      if ($line -match '^\s*verify:\s*(.+?)\s*$') {
        [void]$results.Add([PSCustomObject]@{ AcId=$pendingAc; VerifyCmd=$Matches[1] })
        $pendingAc = ''
        continue
      }
      [void]$results.Add([PSCustomObject]@{ AcId=$pendingAc; VerifyCmd='' })
      $pendingAc = ''
    }
    if ($line -match "^\|\s*($acIdPattern)") {
      $acId = $Matches[1]
      $verifyCmd = ''
      if ($line -match 'verify:\s*([^|]+)') { $verifyCmd = $Matches[1].Trim() }
      [void]$results.Add([PSCustomObject]@{ AcId=$acId; VerifyCmd=$verifyCmd })
    }
  }
  if ($pendingAc) { [void]$results.Add([PSCustomObject]@{ AcId=$pendingAc; VerifyCmd='' }) }
  if ($sectionAc) { [void]$results.Add([PSCustomObject]@{ AcId=$sectionAc; VerifyCmd='' }) }
  return @($results.ToArray())
}

function Test-TaskCardHasCode {
  param(
    [Parameter(Mandatory=$true)][string]$Root,
    [Parameter(Mandatory=$true)][string]$Path,
    [string[]]$Extensions = @('.sh','.ps1','.py','.js','.ts','.go','.rs','.java','.c','.cpp','.rb','.php')
  )
  foreach ($entry in @(Get-TaskCardPatterns -Path $Path -Field 'WRITE-SET')) {
    $clean = ($entry -replace '\s*[\(\[].*$', '').Trim()
    if (-not $clean) { continue }
    if ($Extensions -contains ([IO.Path]::GetExtension($clean))) { return $true }
    $full = Join-Path $Root $clean
    if (Test-Path -LiteralPath $full -PathType Leaf) {
      if ($Extensions -contains ([IO.Path]::GetExtension($full))) { return $true }
    } elseif (Test-Path -LiteralPath $full -PathType Container) {
      foreach ($child in @(Get-ChildItem -LiteralPath $full -File -Recurse -ErrorAction SilentlyContinue)) {
        if ($Extensions -contains $child.Extension) { return $true }
      }
    }
    # Resolve wildcard WRITE-SET entries such as `src/**` and `src/*.ps1`.
    # This keeps docs-only detection aligned with gate's filesystem fallback.
    foreach ($child in @(Get-ChildItem -Path $full -File -Recurse -ErrorAction SilentlyContinue)) {
      if ($Extensions -contains $child.Extension) { return $true }
    }
  }
  return $false
}
