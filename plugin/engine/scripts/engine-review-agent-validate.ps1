# Engine System — Agent-Reviewer Validate (v6.22.0) [PowerShell behavioral mirror]
#
# Phase 3: Validate AGENT-REVIEW.json produced by external agent
# Behavioral mirror of engine-review-agent-validate.sh

param([string]$Task)

$ErrorActionPreference = 'Stop'
$ROOT = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { Get-Location }
$ENGINE_DIR = Join-Path $ROOT 'engine'

if (-not $Task) {
    [Console]::Error.WriteLine("[engine-review-agent-validate] Usage: engine-review-agent-validate T-NNN")
    exit 2
}

$evidenceDir = Join-Path $ENGINE_DIR "review/evidence/$Task"
$reviewFile = Join-Path $evidenceDir 'AGENT-REVIEW.json'
$packageFile = Join-Path $evidenceDir 'review-package.md'

# === 0. FileStream lock ===
$reviewDir = Join-Path $ENGINE_DIR 'review'
if (-not (Test-Path $reviewDir)) { New-Item -ItemType Directory -Path $reviewDir -Force | Out-Null }
$lockPath = Join-Path $reviewDir ".review-agent-lock.$Task"
try {
    $lockStream = [System.IO.File]::Open($lockPath, 'Create', 'ReadWrite', 'None')
} catch {
    [Console]::Error.WriteLine("[engine-review-agent-validate] another review-agent running for $Task")
    exit 1
}

try {
    # === 1. E_MISSING ===
    if (-not (Test-Path $reviewFile)) {
        [Console]::Error.WriteLine("[engine-review-agent-validate] FAIL E_MISSING: $reviewFile not found")
        [Console]::Error.WriteLine("  The external agent must write AGENT-REVIEW.json before validation.")
        exit 1
    }

    # === 2. Parse JSON ===
    try {
        $data = Get-Content $reviewFile -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        [Console]::Error.WriteLine("[engine-review-agent-validate] FAIL E_SCHEMA: invalid JSON: $_")
        exit 1
    }

    # === 3. E_SCHEMA ===
    $schemaErrors = @()
    foreach ($field in @('task','timestamp','status','dimensions','adversarial_responses','overall_assessment','write_provenance')) {
        if (-not $data.PSObject.Properties[$field]) { $schemaErrors += "missing required field: $field" }
    }
    if ($data.status -and $data.status -notin @('pass','concerns','block')) {
        $schemaErrors += "invalid status: $($data.status)"
    }

    $requiredDims = @('correctness','design','consistency','readability','completeness')
    foreach ($dim in $requiredDims) {
        if (-not $data.dimensions.PSObject.Properties[$dim]) {
            $schemaErrors += "missing dimension: $dim"
        } else {
            $dimData = $data.dimensions.$dim
            if (-not $dimData.PSObject.Properties['entries']) { $schemaErrors += "dimension ${dim}: missing entries" }
            if (-not $dimData.PSObject.Properties['summary'] -or -not $dimData.summary) { $schemaErrors += "dimension ${dim}: missing summary" }
        }
    }

    # Entry field checks
    foreach ($dim in $requiredDims) {
        if (-not $data.dimensions.PSObject.Properties[$dim]) { continue }
        $entries = $data.dimensions.$dim.entries
        if (-not $entries) { continue }
        for ($i = 0; $i -lt @($entries).Count; $i++) {
            $e = @($entries)[$i]
            foreach ($f in @('id','severity','type','file','line','message')) {
                if (-not $e.PSObject.Properties[$f]) { $schemaErrors += "${dim}.entries[${i}]: missing $f" }
            }
            if ($e.severity -and $e.severity -notin @('critical','high','medium','low','info')) {
                $schemaErrors += "${dim}.entries[${i}]: invalid severity $($e.severity)"
            }
        }
    }

    # Adversarial responses
    $ar = @($data.adversarial_responses)
    if ($ar.Count -ne 3) { $schemaErrors += "adversarial_responses must have exactly 3 entries (got $($ar.Count))" }

    # Provenance
    $prov = $data.write_provenance
    if ($prov) {
        foreach ($f in @('writer','commit','package_sha256')) {
            if (-not $prov.PSObject.Properties[$f]) { $schemaErrors += "write_provenance: missing $f" }
        }
    }

    if ($schemaErrors.Count -gt 0) {
        foreach ($err in $schemaErrors) { [Console]::Error.WriteLine("[engine-review-agent-validate] FAIL E_SCHEMA: $err") }
        exit 1
    }

    # === 4. E_SHALLOW ===
    $configFile = Join-Path $reviewDir 'config.json'
    $cfg = if (Test-Path $configFile) { Get-Content $configFile -Raw -Encoding UTF8 | ConvertFrom-Json } else { @{} }
    $minEntries = if ($cfg.defaults.agent_review.min_entries_per_dimension) { [int]$cfg.defaults.agent_review.min_entries_per_dimension } else { 1 }
    $minNarrative = if ($cfg.defaults.agent_review.min_narrative_chars) { [int]$cfg.defaults.agent_review.min_narrative_chars } else { 200 }
    $minMessage = if ($cfg.defaults.agent_review.min_entry_message_chars) { [int]$cfg.defaults.agent_review.min_entry_message_chars } else { 20 }

    $shallowErrors = @()
    $narrativeTotal = $data.overall_assessment.Length
    foreach ($dim in $requiredDims) {
        $entries = @($data.dimensions.$dim.entries)
        if ($entries.Count -lt $minEntries) { $shallowErrors += "dimension $dim has $($entries.Count) entries (minimum $minEntries)" }
        $narrativeTotal += $data.dimensions.$dim.summary.Length
        foreach ($e in $entries) {
            if ($e.message.Length -lt $minMessage) { $shallowErrors += "$dim entry message too terse ($($e.message.Length) < $minMessage)" }
        }
    }
    if ($narrativeTotal -lt $minNarrative) { $shallowErrors += "narrative too shallow ($narrativeTotal chars < $minNarrative)" }
    foreach ($resp in $ar) {
        if ($resp.response.Length -lt 30) { $shallowErrors += "adversarial response too short ($($resp.response.Length) < 30)" }
    }

    if ($shallowErrors.Count -gt 0) {
        foreach ($err in $shallowErrors) { [Console]::Error.WriteLine("[engine-review-agent-validate] FAIL E_SHALLOW: $err") }
        exit 1
    }

    # === 4b. E_GROUNDED (v6.22.0): verify finding file:line references exist ===
    $groundedErrors = @()
    $groundedWarnings = @()
    $totalFindingsForGrounding = 0
    $ungroundedCount = 0
    foreach ($dim in $requiredDims) {
        $entries = @($data.dimensions.$dim.entries)
        for ($i = 0; $i -lt $entries.Count; $i++) {
            $e = $entries[$i]
            if ($e.type -ne 'finding') { continue }
            $totalFindingsForGrounding++
            $fpath = if ($e.PSObject.Properties['file']) { $e.file } else { '' }
            $fline = if ($e.PSObject.Properties['line']) { [int]$e.line } else { 0 }
            if (-not $fpath -or -not $fline) { continue }
            $fullPath = Join-Path $ROOT $fpath
            if (-not (Test-Path $fullPath -PathType Leaf)) {
                $ungroundedCount++
                $groundedErrors += "${dim}.entries[${i}] references non-existent file: $fpath"
                continue
            }
            try {
                $lineCount = (Get-Content $fullPath -Encoding UTF8).Count
                if ($fline -gt $lineCount) {
                    $ungroundedCount++
                    $groundedErrors += "${dim}.entries[${i}] line $fline exceeds file length ($lineCount lines): $fpath"
                }
            } catch {}
        }
    }
    if ($totalFindingsForGrounding -gt 0 -and $ungroundedCount -gt 0) {
        $ratio = $ungroundedCount / $totalFindingsForGrounding
        if ($ratio -gt 0.5) {
            foreach ($msg in $groundedErrors) { [Console]::Error.WriteLine("[engine-review-agent-validate] FAIL E_GROUNDED: $msg") }
            exit 1
        } else {
            $groundedWarnings = $groundedErrors
        }
    }

    # === 5. E_PROVENANCE ===
    $provErrors = @()
    if ($prov.writer -ne 'agent-reviewer') { $provErrors += "invalid writer: $($prov.writer)" }
    if (Test-Path $packageFile) {
        # Normalize: replace package_sha256 line value with COMPUTE before hashing
        $pkgContent = [System.IO.File]::ReadAllText($packageFile, [System.Text.Encoding]::UTF8)
        # Only replace FIRST occurrence (diff content may contain same pattern)
        $regexObj = [System.Text.RegularExpressions.Regex]::new('(> package_sha256: ).*')
        $normalized = $regexObj.Replace($pkgContent, '${1}COMPUTE', 1)
        $sha = [System.Security.Cryptography.SHA256]::Create()
        $normBytes = [System.Text.Encoding]::UTF8.GetBytes($normalized)
        $actualSha = [BitConverter]::ToString($sha.ComputeHash($normBytes)).Replace('-','').ToLower()
        if ($prov.package_sha256 -ne $actualSha) { $provErrors += "package_sha256 mismatch" }
        # head_commit echo check
        $pkgLines = Get-Content $packageFile -Encoding UTF8
        $headLine = $pkgLines | Where-Object { $_ -match '^> head_commit:' } | Select-Object -First 1
        if ($headLine) {
            $pkgHead = ($headLine -replace '^> head_commit:\s*', '').Trim()
            if ($prov.commit -ne $pkgHead) { $provErrors += "commit mismatch: agent=$($prov.commit) package=$pkgHead" }
        }
    } else {
        $provErrors += "review-package.md not found"
    }

    if ($provErrors.Count -gt 0) {
        foreach ($err in $provErrors) { [Console]::Error.WriteLine("[engine-review-agent-validate] FAIL E_PROVENANCE: $err") }
        exit 1
    }

    # === 6. Staleness WARN (uses embedded timestamp from package header) ===
    $maxAge = if ($cfg.defaults.agent_review.max_package_age_hours) { [int]$cfg.defaults.agent_review.max_package_age_hours } else { 72 }
    if (Test-Path $packageFile) {
        $genLine = Get-Content $packageFile -Encoding UTF8 | Where-Object { $_ -match '^> generated:' } | Select-Object -First 1
        if ($genLine) {
            $genStr = ($genLine -replace '^> generated:\s*', '').Trim()
            try {
                $genTime = [DateTime]::ParseExact($genStr, 'yyyy-MM-ddTHH:mm:ssZ', [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AdjustToUniversal)
                $age = ((Get-Date).ToUniversalTime() - $genTime).TotalHours
                if ($age -gt $maxAge) {
                    [Console]::Error.WriteLine("[engine-review-agent-validate] WARN: package is $([int]$age) hours old (>$maxAge`h), consider regenerating")
                }
            } catch {
                [Console]::Error.WriteLine("[engine-review-agent-validate] WARN: cannot parse package generated timestamp")
            }
        }
    }

    # === 6b. E_INDEPENDENCE (v6.22.0, FAIL): reviewer_session must differ from packaged_by ===
    if (Test-Path $packageFile) {
        $pkgPackagedBy = $null
        foreach ($line in (Get-Content $packageFile -Encoding UTF8)) {
            if ($line -match '^> packaged_by:\s*(.+)$') { $pkgPackagedBy = $Matches[1].Trim(); break }
        }
        $reviewerSession = if ($prov.PSObject.Properties['reviewer_session']) { $prov.reviewer_session } else { '' }
        if (-not $reviewerSession) {
            [Console]::Error.WriteLine("[engine-review-agent-validate] FAIL E_INDEPENDENCE: reviewer_session missing in write_provenance (subagent review is mandatory)")
            exit 1
        } elseif ($pkgPackagedBy -and $reviewerSession -eq $pkgPackagedBy) {
            [Console]::Error.WriteLine("[engine-review-agent-validate] FAIL E_INDEPENDENCE: reviewer_session matches packaged_by ($reviewerSession) - reviewer must be a separate agent/session")
            exit 1
        }
    }
    # Output grounded warnings
    foreach ($gw in $groundedWarnings) { [Console]::Error.WriteLine("[engine-review-agent-validate] WARN: E_GROUNDED: $gw") }

    # === 7. Append validated_by ===
    $validatedAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    $data.write_provenance | Add-Member -NotePropertyName 'validated_by' -NotePropertyValue "engine review-agent $Task --validate" -Force
    $data.write_provenance | Add-Member -NotePropertyName 'validated_at' -NotePropertyValue $validatedAt -Force
    $data | ConvertTo-Json -Depth 10 -Compress | Set-Content $reviewFile -Encoding UTF8

    # === 7b. Cross-model detection (v6.23.0, T-076) ===
    $validatorModel = if ($env:ENGINE_MODEL_ID) { $env:ENGINE_MODEL_ID } else { '' }
    $reviewerModel = ''
    if ($data.reviewer -and $data.reviewer.model) { $reviewerModel = $data.reviewer.model }
    if (-not $reviewerModel -and $data.write_provenance.PSObject.Properties['model_id']) { $reviewerModel = $data.write_provenance.model_id }
    $crossModel = ($validatorModel -and $reviewerModel -and $validatorModel -ne $reviewerModel)

    # === 8. Update REVIEW.json ===
    $reviewJson = Join-Path $evidenceDir 'REVIEW.json'
    $totalFindings = 0; $totalStrengths = 0
    foreach ($dim in $requiredDims) {
        foreach ($e in @($data.dimensions.$dim.entries)) {
            if ($e.type -eq 'finding') { $totalFindings++ } else { $totalStrengths++ }
        }
    }
    $agentStatus = $data.status

    if (Test-Path $reviewJson) {
        $review = Get-Content $reviewJson -Raw -Encoding UTF8 | ConvertFrom-Json
        $agentDim = @{ status = $agentStatus; findings_count = @{critical=0;high=0;medium=0;low=0;info=0}; protocol_version = 'v6.22.0' }
        foreach ($dim in $requiredDims) {
            foreach ($e in @($data.dimensions.$dim.entries)) { $agentDim.findings_count[$e.severity]++ }
        }
        $review.dimensions | Add-Member -NotePropertyName 'agent_review' -NotePropertyValue $agentDim -Force
        $review | Add-Member -NotePropertyName 'cross_model' -NotePropertyValue $crossModel -Force
        if ($agentStatus -eq 'block') { $review.status = 'block' }
        $review | ConvertTo-Json -Depth 10 -Compress | Set-Content $reviewJson -Encoding UTF8
    } else {
        $headCommit = git -C $ROOT rev-parse HEAD 2>$null
        $newCounts = @{critical=0;high=0;medium=0;low=0;info=0}
        foreach ($dim in $requiredDims) {
            foreach ($e in @($data.dimensions.$dim.entries)) { $newCounts[$e.severity]++ }
        }
        $newReview = @{
            task = $Task; timestamp = $validatedAt; status = $agentStatus; cross_model = $crossModel
            dimensions = @{ agent_review = @{ status = $agentStatus; findings_count = $newCounts; protocol_version = 'v6.22.0' } }
            write_provenance = @{ writer = 'engine-review-agent-validate'; model_id = $validatorModel; commit = $headCommit; timestamp = $validatedAt; argv = "engine review-agent $Task --validate"; pipeline_version = 'v6.22.0' }
        }
        $newReview | ConvertTo-Json -Depth 10 -Compress | Set-Content $reviewJson -Encoding UTF8
    }

    # === 9. Manifest sha256 ===
    $sha2 = [System.Security.Cryptography.SHA256]::Create()
    $hasher = [System.Security.Cryptography.IncrementalHash]::CreateHash([System.Security.Cryptography.HashAlgorithmName]::SHA256)
    $jsonFiles = Get-ChildItem $evidenceDir -Filter '*.json' | Where-Object { $_.Name -ne 'REVIEW.json' } | Sort-Object Name
    foreach ($jf in $jsonFiles) { $hasher.AppendData([System.IO.File]::ReadAllBytes($jf.FullName)) }
    if (Test-Path $packageFile) { $hasher.AppendData([System.IO.File]::ReadAllBytes($packageFile)) }
    $manifestSha = [BitConverter]::ToString($hasher.GetHashAndReset()).Replace('-','').ToLower()
    $review2 = Get-Content $reviewJson -Raw -Encoding UTF8 | ConvertFrom-Json
    $review2 | Add-Member -NotePropertyName 'evidence_manifest_sha256' -NotePropertyValue $manifestSha -Force
    $review2 | ConvertTo-Json -Depth 10 -Compress | Set-Content $reviewJson -Encoding UTF8

    # === 10. Output ===
    $statusUpper = $agentStatus.ToUpper()
    Write-Output "[engine-review-agent-validate] $Task`: AGENT REVIEW $statusUpper ($totalFindings findings, $totalStrengths strengths)"
    exit 0

} finally {
    if ($lockStream) { $lockStream.Dispose() }
}
