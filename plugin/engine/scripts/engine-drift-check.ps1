# Engine System - Drift checker (v6.18.0 D-038b)
#
# Does NOT re-run verify. Performs cheap fingerprint comparison only. Three steps:
#   1. Integrity self-attestation (MANIFEST + write_provenance)
#   2. WRITE-SET second-order detection (snapshot vs current task card)
#   3. Code fingerprint comparison (git ls-files -s vs code_fingerprint)
# If any step FAILs, subsequent steps still emit a summary (marked unverified),
# so a manifest failure cannot mask a deeper drift.
#
# Usage: pwsh -File engine/scripts/engine-drift-check.ps1 [-Task T-NNN]
#   No -Task: all done cards
#   -Task T-NNN: single card

param([Parameter(Mandatory=$false)][string]$Task)

$ErrorActionPreference = "Stop"
trap { [Console]::Error.WriteLine("[drift-check] error: $_"); exit 1 }

$Root = $env:CLAUDE_PROJECT_DIR
if (-not $Root) { $Root = $PWD.Path }
$EngineDir = Join-Path $Root "engine"

# v6.18.0 (D-038/T-066): metadata filter - same as engine-verify's Test-EngineMetadata.
# Used to extract only code files from WRITE-SET (skip engine metadata).
function Test-EngineMetadata {
  param([string]$Path)
  $metaPatterns = @(
    'engine/tasks/', 'engine/decisions/', 'engine/changes/', 'engine/evidence/',
    'engine/domains/', 'engine/archive/', 'engine/CONTEXT.md', 'engine/HANDOFF.md',
    'engine/ENGINE_MAP.md', 'engine/handoff-archive-', 'VERSION', 'engine/VERSION',
    'plugin/VERSION', 'plugin/manifest.json', 'CHANGELOG.md'
  )
  foreach ($p in $metaPatterns) {
    if ($Path -like "$p*" -or $Path -eq $p) { return $true }
  }
  return $false
}

# Collect done cards (status:done in the > header line, line-start anchored)
$taskDir = Join-Path $EngineDir "tasks"
$doneCards = @()
if (Test-Path $taskDir) {
  Get-ChildItem -Path $taskDir -Filter "T-*.md" -File | Sort-Object Name | ForEach-Object {
    $tid = $_.BaseName
    if ($Task -and ($tid -ne $Task)) { return }
    $firstLines = Get-Content -Path $_.FullName -Encoding UTF8 -TotalCount 5
    foreach ($ln in $firstLines) {
      if ($ln -match '^>.*status:\s*done') { $doneCards += $tid; break }
    }
  }
}

if ($doneCards.Count -eq 0) {
  Write-Output "[drift-check] no done cards, skip"
  exit 0
}

$driftCount = 0
$tamperCount = 0
$warnCount = 0

foreach ($tid in $doneCards) {
  $evDir = Join-Path $EngineDir ("evidence\" + $tid)
  if (-not (Test-Path $evDir -PathType Container)) {
    Write-Output "WARN: $tid done but evidence directory missing"
    $warnCount++; continue
  }
  $taskFile = Join-Path $EngineDir ("tasks\" + $tid + ".md")

  Write-Output "-- $tid --"

  # ========== Step 1: Integrity self-attestation ==========
  $manifestFile = Join-Path $evDir "MANIFEST.json"
  $step1Fail = $false
  $legacyEvidence = $false
  $historicalSnapshot = $false

  if (-not (Test-Path $manifestFile)) {
    # v6.18.0 (D-038d migration): legacy evidence has no MANIFEST.json. Two cases:
    #   (a) AC-*.json also lacks write_provenance field -> true legacy, WARN, skip
    #   (b) AC-*.json has write_provenance but MANIFEST missing -> deleted, FAIL tamper
    $acFilesForLegacy = Get-ChildItem -Path $evDir -Filter "AC-*.json" -File -ErrorAction SilentlyContinue | Sort-Object Name
    $firstAcForLegacy = if ($acFilesForLegacy.Count -gt 0) { $acFilesForLegacy[0].FullName } else { "" }
    $isLegacy = $false
    if ($firstAcForLegacy -and (Test-Path $firstAcForLegacy)) {
      $firstEvRawLegacy = Get-Content -Path $firstAcForLegacy -Raw -Encoding UTF8
      if ($firstEvRawLegacy -notmatch '"write_provenance"') { $isLegacy = $true }
    }
    if ($isLegacy) {
      Write-Output "  WARN step1: legacy evidence (no MANIFEST, no write_provenance) - migration skip, trust T2"
      $warnCount++; $legacyEvidence = $true
    } else {
      Write-Output "  FAIL step1: MANIFEST.json missing (has write_provenance but no MANIFEST - suspected tamper)"
      $tamperCount++; $step1Fail = $true
    }
  } else {
    # Recompute manifest aggregate hash and compare
    $files = Get-ChildItem -Path $evDir -File |
      Where-Object { $_.Name -ne 'MANIFEST.json' -and ($_.Name -like '*.json' -or $_.Name -eq 'checkpoint.md') } |
      Sort-Object Name
    $manifestContent = ""
    foreach ($f in $files) {
      $h = (Get-FileHash -Path $f.FullName -Algorithm SHA256).Hash.ToLower()
      $manifestContent += "$($f.Name):$h`n"
    }
    $manifestBytes = [System.Text.Encoding]::UTF8.GetBytes($manifestContent)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $recomputedHash = ([System.BitConverter]::ToString($sha.ComputeHash($manifestBytes)) -replace '-', '').ToLower()
    $sha.Dispose()

    $manifestRaw = Get-Content -Path $manifestFile -Raw -Encoding UTF8
    $storedHash = ""
    if ($manifestRaw -match '"evidence_manifest_sha256":"sha256:([^"]*)"') {
      $storedHash = $Matches[1]
    }
    if ($recomputedHash -ne $storedHash) {
      $storedShort = if ($storedHash) { $storedHash.Substring(0,12) } else { "(none)" }
      Write-Output "  FAIL step1: evidence tampered (manifest mismatch: stored=$storedShort.. recomputed=$($recomputedHash.Substring(0,12))..)"
      $tamperCount++; $step1Fail = $true
    }

    # Verify write_provenance
    $headCommit = & git -C $Root rev-parse HEAD 2>$null
    if (-not $headCommit) { $headCommit = "unknown" }
    $provWriter = ""
    if ($manifestRaw -match '"writer":"([^"]*)"') { $provWriter = $Matches[1] }
    $provCommit = ""
    if ($manifestRaw -match '"commit":"([^"]*)"') { $provCommit = $Matches[1] }
    if ($provWriter -ne "engine-verify") {
      Write-Output "  FAIL step1: invalid provenance.writer (expected engine-verify, got $provWriter)"
      $tamperCount++; $step1Fail = $true
    }
    if (-not $provCommit) {
      Write-Output "  FAIL step1: provenance.commit missing"
      $tamperCount++; $step1Fail = $true
    } else {
      $null = & git -C $Root cat-file -e "$provCommit^{commit}" 2>$null
      $commitExists = ($LASTEXITCODE -eq 0)
      if (-not $commitExists) {
        Write-Output "  FAIL step1: provenance.commit is not a reachable commit (got $provCommit)"
        $tamperCount++; $step1Fail = $true
      } elseif ($provCommit -ne $headCommit) {
        # A done card can legitimately retain evidence generated at the commit
        # immediately before its status transition, or at an older historical
        # commit. The manifest has already self-verified, so report this as an
        # explicit legacy snapshot warning while keeping code-fingerprint drift
        # visible below. A current active/newly-done card remains a hard failure.
        $headCard = (& git -C $Root show "HEAD:engine/tasks/$tid.md" 2>$null | Out-String)
        if ($headCard.Contains("> status: done")) {
          Write-Output "  WARN step1: legacy evidence provenance.commit mismatch (HEAD=$headCommit, snapshot=$provCommit)"
          $warnCount++; $historicalSnapshot = $true
        } else {
          Write-Output "  FAIL step1: provenance.commit mismatch (expected HEAD=$headCommit, got $provCommit)"
          $tamperCount++; $step1Fail = $true
        }
      }
    }
  }

  if ($step1Fail) {
    Write-Output "  (step1 FAIL, subsequent steps marked unverified)"
  } elseif ($legacyEvidence) {
    Write-Output "  (legacy evidence, subsequent steps SKIP)"
  } else {
    Write-Output "  OK   step1: manifest + provenance verified"
  }

  # Locate first AC-*.json evidence file (sorted)
  $firstAcEv = ""
  if (Test-Path $evDir) {
    $acFiles = Get-ChildItem -Path $evDir -Filter "AC-*.json" -File | Sort-Object Name
    if ($acFiles.Count -gt 0) { $firstAcEv = $acFiles[0].FullName }
  }

  # ========== Step 2: WRITE-SET second-order detection ==========
  if ($step1Fail) {
    Write-Output "  SKIP step2: (unverified - manifest failed)"
  } elseif ($legacyEvidence) {
    Write-Output "  SKIP step2: (legacy evidence - migration skip)"
  } elseif (-not $firstAcEv) {
    Write-Output "  WARN step2: no AC-*.json, skip WRITE-SET detection"
    $warnCount++
  } else {
    $firstEvRaw = Get-Content -Path $firstAcEv -Raw -Encoding UTF8
    $snapshotJson = ""
    if ($firstEvRaw -match '"write_set_snapshot":(\[[^\]]*\])') {
      $snapshotJson = $Matches[1]
    }
    # Parse snapshot JSON array (path list)
    $snapshotPaths = @()
    if ($snapshotJson) {
      $snapshotJson -replace '^\[', '' -replace '\]$', '' -split ',' | ForEach-Object {
        $p = $_.Trim().Trim('"')
        if ($p) { $snapshotPaths += $p }
      }
    }

    # Parse current task card WRITE-SET (same metadata filter as verify)
    $currentWs = @()
    if (Test-Path $taskFile) {
      $content = Get-Content -Path $taskFile -Encoding UTF8
      $inWs = $false
      foreach ($line in $content) {
        if ($line -match '^## WRITE-SET') { $inWs = $true; continue }
        if ($line -match '^## ') { if ($inWs) { break } else { continue } }
        if (-not $inWs) { continue }
        if ($line -match '^-\s+(.+)') {
          $path = $Matches[1].Trim()
          if (Test-EngineMetadata -Path $path) { continue }
          $fullPath = Join-Path $Root $path
          if (-not (Test-Path $fullPath -PathType Leaf)) { continue }
          $currentWs += $path
        }
      }
    }

    # Use array membership rather than HashSet constructors: PowerShell 5 and
    # PowerShell 7 bind one-element arrays differently to generic constructors.
    $added = @($currentWs | Where-Object { $snapshotPaths -notcontains $_ })
    $removed = @($snapshotPaths | Where-Object { $currentWs -notcontains $_ })
    if ($added.Count -gt 0 -or $removed.Count -gt 0) {
      Write-Output "  WARN step2: WRITE-SET changed since evidence"
      if ($added.Count -gt 0)   { Write-Output "    added: $($added -join ' ')" }
      if ($removed.Count -gt 0) { Write-Output "    removed: $($removed -join ' ')" }
      $warnCount++
    } else {
      Write-Output "  OK   step2: WRITE-SET unchanged"
    }
  }

  # ========== Step 3: Code fingerprint comparison ==========
  if ($step1Fail) {
    Write-Output "  SKIP step3: (unverified - manifest failed)"
  } elseif ($legacyEvidence) {
    Write-Output "  SKIP step3: (legacy evidence - migration skip)"
  } elseif (-not $firstAcEv) {
    Write-Output "  WARN step3: no AC-*.json, skip code fingerprint comparison"
  } else {
    $firstEvRaw = Get-Content -Path $firstAcEv -Raw -Encoding UTF8
    $cfJson = ""
    if ($firstEvRaw -match '"code_fingerprint":(\{[^}]*\})') {
      $cfJson = $Matches[1]
    }
    $hadDrift = $false
    if ($cfJson) {
      # Parse pairs: "path":"sha","path":"sha"
      $pairs = $cfJson -replace '^\{', '' -replace '\}$', '' -split ','
      foreach ($pair in $pairs) {
        if ($pair -match '"([^"]*)":"([^"]*)"') {
          $path = $Matches[1]
          $storedSha = $Matches[2]
          $gitOut = & git -C $Root ls-files -s $path 2>$null
          $currentSha = ""
          if ($gitOut -match '\s([0-9a-f]{40})\s') { $currentSha = $Matches[1] }
          if (-not $currentSha) {
            if ($historicalSnapshot) {
              Write-Output "  WARN legacy step3: $tid file deleted after evidence snapshot (path: $path)"
              $warnCount++
            } else {
              Write-Output "  DRIFT step3: $tid file deleted (path: $path)"
              $driftCount++
            }
            $hadDrift = $true
          } elseif ($currentSha -ne $storedSha) {
            if ($historicalSnapshot) {
              Write-Output "  WARN legacy step3: $tid code changed after evidence snapshot (${path}: stored=$($storedSha.Substring(0,12)).. current=$($currentSha.Substring(0,12))..)"
              $warnCount++
            } else {
              Write-Output "  DRIFT step3: $tid code changed (${path}: stored=$($storedSha.Substring(0,12)).. current=$($currentSha.Substring(0,12))..)"
              $driftCount++
            }
            $hadDrift = $true
          }
        }
      }
    }
    if (-not $hadDrift) {
      Write-Output "  OK   step3: code fingerprint consistent"
    }
  }
}

Write-Output ""
Write-Output "[drift-check summary] tamper=$tamperCount drift=$driftCount warn=$warnCount"
if ($tamperCount -gt 0) { exit 1 }
if ($driftCount -gt 0) { exit 1 }
exit 0
