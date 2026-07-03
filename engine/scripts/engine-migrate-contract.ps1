# Engine System - migrate existing engine files to the current contract (PowerShell)
#
# Idempotently upserts managed migration blocks into old projects without overwriting
# project-specific engine memory. Also ensures the v6 data-layer structure (tasks/
# decisions/domains/changes/evidence directories, federation table, decision rules
# baseline, local VERSION stamp) exists so an old project can fully operate the
# current v6 mechanisms.

param(
  [string]$Root = $(if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (Get-Location).Path })
)

$ErrorActionPreference = "Stop"

$EngineDir = Join-Path $Root "engine"
$Map = Join-Path $EngineDir "ENGINE_MAP.md"
if (-not (Test-Path $Map)) {
  Write-Host "engine/ENGINE_MAP.md not found. Run /engine-init first."
  exit 1
}

New-Item -ItemType Directory -Force -Path $EngineDir, (Join-Path $EngineDir "changes") | Out-Null

$Start = "<!-- ENGINE_SYSTEM_CONTRACT_MIGRATIONS_START -->"
$End = "<!-- ENGINE_SYSTEM_CONTRACT_MIGRATIONS_END -->"
# Contract version: read from VERSION file (repo root, then engine/), fall back to 6.0.
$repoVersionFile = Join-Path $Root "VERSION"
$engineVersionFile = Join-Path $EngineDir "VERSION"
if (Test-Path $repoVersionFile) {
  $ContractVersion = (Get-Content $repoVersionFile -Raw -Encoding UTF8).Trim()
} elseif (Test-Path $engineVersionFile) {
  $ContractVersion = (Get-Content $engineVersionFile -Raw -Encoding UTF8).Trim()
} else {
  $ContractVersion = "6.0"
}
$Today = Get-Date -Format "yyyy-MM-dd"
$Touched = New-Object System.Collections.Generic.List[string]

function Get-Relative([string]$Path) {
  if ($Path.StartsWith($Root)) {
    return $Path.Substring($Root.Length).TrimStart("\", "/")
  }
  return $Path
}

function Normalize-Text([string]$Value) {
  return (($Value -replace "`r`n", "`n").TrimEnd())
}

# Ensure v6 data-layer structure exists. Idempotent: only creates what is missing.
function Ensure-Structure {
  $changed = $false
  foreach ($d in @("tasks", "decisions", "domains", "changes", "evidence", ".cache")) {
    $p = Join-Path $EngineDir $d
    if (-not (Test-Path $p)) {
      New-Item -ItemType Directory -Force -Path $p | Out-Null
      Write-Host "created $(Get-Relative $p)/"
      $changed = $true
    }
  }
  $fed = Join-Path $EngineDir "domains\federation.json"
  if (-not (Test-Path $fed)) {
    $fedContent = @"
{
  "_comment": "Federation table: path-glob -> domain. Hooks parse this for routing assembly and gate checks. glob syntax matches .gitignore (case-fold); paths matching no domain fall through to default_domain.",
  "domains": {
    "engine-runtime": {
      "paths": [
        "plugin/engine/scripts/**",
        "engine/scripts/**",
        "plugin/.claude/commands/**",
        "engine/ENGINE_DOCTOR.md",
        "ENGINE_FILE_SYSTEM_v5.md",
        "scripts/check.sh",
        "scripts/check.ps1"
      ],
      "summary": "Engine runtime: hooks / Doctor / migrator / contract - the product itself"
    },
    "project-meta": {
      "paths": [
        "engine/tasks/**",
        "engine/decisions/**",
        "engine/changes/**",
        "engine/domains/**",
        "engine/CONTEXT.md",
        "engine/HANDOFF.md",
        "engine/ENGINE_MAP.md",
        "docs/**",
        "tests/**"
      ],
      "summary": "Project memory: tasks / decisions / changes / plans / tests"
    }
  },
  "default_domain": "root"
}
"@
    Set-Content -Path $fed -Value $fedContent -Encoding UTF8
    Write-Host "created $(Get-Relative $fed)"
    $changed = $true
  }
  $rules = Join-Path $EngineDir "decisions\rules.json"
  if (-not (Test-Path $rules)) {
    Set-Content -Path $rules -Value '{"rules":[]}' -Encoding UTF8
    Write-Host "created $(Get-Relative $rules)"
    $changed = $true
  }
  $ver = Join-Path $EngineDir "VERSION"
  if (-not (Test-Path $ver)) {
    if (Test-Path $repoVersionFile) {
      Copy-Item $repoVersionFile $ver
    } else {
      Set-Content -Path $ver -Value $ContractVersion -Encoding UTF8
    }
    Write-Host "created $(Get-Relative $ver)"
    $changed = $true
  }
  return $changed
}

function Upsert-Block([string]$Path, [string]$Title, [string]$Body) {
  $dir = Split-Path -Parent $Path
  if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }

  $block = @"
$Start
<!-- contract-version: $ContractVersion -->
## $Title
> Managed by Engine System contract migration. Preserve project-specific rules outside this block.

$Body
$End
"@

  if (-not (Test-Path $Path)) {
    Set-Content -Path $Path -Value $block -Encoding UTF8
    Write-Host "created $(Get-Relative $Path)"
    return $true
  }

  $raw = Get-Content -Raw -Path $Path -Encoding UTF8
  if ($raw.Contains($Start) -and $raw.Contains($End)) {
    $pattern = [regex]::Escape($Start) + "[\s\S]*?" + [regex]::Escape($End)
    $current = [regex]::Match($raw, $pattern)
    if ($current.Success -and (Normalize-Text $current.Value) -eq (Normalize-Text $block)) {
      Write-Host "current $(Get-Relative $Path)"
      return $false
    }
    $updated = [regex]::Replace($raw, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $block }, 1)
    Set-Content -Path $Path -Value $updated -Encoding UTF8
    Write-Host "updated $(Get-Relative $Path)"
    return $true
  }

  Set-Content -Path $Path -Value ($raw.TrimEnd() + "`n`n" + $block) -Encoding UTF8
  Write-Host "appended $(Get-Relative $Path)"
  return $true
}

# Step 1: ensure v6 data-layer structure.
Ensure-Structure | Out-Null

# v6 session contract block (replaces v5.7 content).
$sessionProtocol = @"
- Read ``engine/ENGINE_MAP.md`` first, then run the path-driven read-gate via ``engine/domains/federation.json`` (path-glob -> domain routing).
- Task cards (``engine/tasks/T-NNN.md``) carry a machine-readable header: GOAL / WRITE-SET / FORBIDDEN / AC+verify / CONSTRAINTS + status / lane / decision / domain. Work MUST stay within WRITE-SET and outside FORBIDDEN.
- Decision ledger (``engine/decisions/D-NNN.md``) records non-obvious choices with status / scope / expiry. Protected paths require a decision reference at commit time.
- Fractal memory: the federation table routes paths to domains; each domain may have CONTEXT.md (summary) + PITFALLS.md (budget + retrieval recipe). L2 assembly stays within the <=400 line session budget (N1).
- Three-layer gate: Stop hook (WRITE-SET / routing / FORBIDDEN -> block; missing write-back -> block; missing capsule -> warn) + git pre-commit (decision reference, done fallback) + Doctor.
- Contract compile: ``contract/src/*.md`` is the single source of truth; ``contract/compile.sh`` compiles to dist; ``contract/budget.json`` enforces subtraction (line count <= baseline, new Rules must net-zero). Contract debt counter (N4) is tracked by Doctor.
- Cockpit: ``engine verify T-NNN`` runs behavior verification (AC verify commands -> PASS/FAIL + sha256 fingerprint in ``engine/evidence/``). A task card may be marked ``done`` only when verify is all-green or the architect grants an ``exempt`` marker (N3).
- After meaningful code, doc, dependency, engine-tooling, test, or behavior changes, update ``CONTEXT.md`` + ``HANDOFF.md`` and create ``engine/changes/CHANGE-*.md`` (Goal / Actual Changes / Impact Scope / Risk & Watchpoints / Verification / Rollback / Next Step / Responsibility Boundary).
- Plans may be marked ``done`` only when every AC has evidence in the spec twin Evidence column, ``engine/evidence/*``, or a relevant change capsule.
- Shared engine-file writes are single-writer: parallel agents may gather drafts/evidence, but one writer lands ``ENGINE_MAP.md``, ``SYSTEM.md``, ``PITFALLS.md``, ``CONTEXT.md``, ``HANDOFF.md``, anchors, and plan/spec edits.
- Claude Code hooks and git pre-commit are enforcement layers; Web/other agents follow this contract manually.
- Update check: ``engine check-update`` compares local ``engine/VERSION`` against the remote; session-start prints a non-blocking hint when a newer version exists.
"@

# v6 Doctor contract block (replaces v5.7 content).
$doctorContract = @"
Doctor MUST validate the current Engine System v6 contract in addition to registry health:

1. Task cards (``engine/tasks/T-*.md``) carry v6 machine-readable headers (GOAL / WRITE-SET / FORBIDDEN / AC+verify / CONSTRAINTS + status / lane / decision / domain).
2. Done task cards have acceptance evidence (``engine/evidence/T-NNN/AC-*.json``) or an ``exempt`` marker (N3 done-gate).
3. Federation table ``engine/domains/federation.json`` is valid JSON with at least a ``default_domain``.
4. Session injection budget (N1): session-start hook output <= 400 lines.
5. Contract debt (N4): MUST count + gate Rule count + debt vs baseline tracked.
6. ``engine/VERSION`` exists and matches the installed tooling version.
7. Recent meaningful changes have an architect-readable ``engine/changes/CHANGE-*.md`` capsule with required sections.
8. Plans marked ``done`` point to acceptance evidence in the spec twin Evidence column, ``engine/evidence/*``, or a related capsule.
9. Bootloaders (AGENTS.md / CLAUDE.md) stay thin: target 30 lines, hard cap 45 lines.
10. Generated self-view snapshots, when used, live under ``engine/.cache/`` and are never registered as authority.
"@

$agentPath = Join-Path $Root "AGENTS.md"
$systemPath = Join-Path $EngineDir "SYSTEM.md"
$doctorPath = Join-Path $EngineDir "ENGINE_DOCTOR.md"
if (Upsert-Block $agentPath "Engine System Current Contract" $sessionProtocol) { $Touched.Add((Get-Relative $agentPath)) }
if (Upsert-Block $systemPath "Engine System Current Contract" $sessionProtocol) { $Touched.Add((Get-Relative $systemPath)) }
if (Upsert-Block $doctorPath "Current Contract Checks" $doctorContract) { $Touched.Add((Get-Relative $doctorPath)) }

if ($Touched.Count -eq 0) {
  Write-Host "Engine contract migration already current. Next: run /engine-doctor if you need verification."
  exit 0
}

$changesDir = Join-Path $EngineDir "changes"
$existing = @(Get-ChildItem -Path $changesDir -File -Filter "CHANGE-$Today-*.md" -ErrorAction SilentlyContinue)
$next = 1
foreach ($file in $existing) {
  if ($file.BaseName -match "CHANGE-\d{4}-\d{2}-\d{2}-(\d{2})") {
    $n = [int]$Matches[1]
    if ($n -ge $next) { $next = $n + 1 }
  }
}
$changeId = "CHANGE-$Today-$($next.ToString('00'))"
$capsule = Join-Path $changesDir "$changeId.md"

@"
# $changeId - Engine contract migration to v6

> Created: $Today · Status: needs-verification · Related plan: none

## Goal
Migrate an existing project with old engine files to the current Engine System v6 contract without rerunning /engine-init or overwriting project-specific memory.

## Actual Changes
- Ensured v6 data-layer directories exist: tasks, decisions, domains, changes, evidence, .cache.
- Created federation table (engine/domains/federation.json) if missing, with standard engine-runtime + project-meta domains.
- Created decision rules baseline (engine/decisions/rules.json) if missing.
- Created local VERSION stamp (engine/VERSION) if missing.
- Updated managed contract blocks (contract-version $ContractVersion) in: $($Touched -join ", ").
- The v6 block covers: task card headers, decision ledger, fractal memory, three-layer gate, contract compile, cockpit verify, change capsules, single-writer merges, update check.

## Impact Scope
Engine memory layer only. Project source code and project-specific engine prose outside managed migration blocks are preserved.

## Risk & Watchpoints
If the project already had custom rules in the same files, they remain outside the managed block. Review for duplicate wording, but do not delete project-specific decisions. Existing task cards are NOT reformatted - only new cards must use the v6 header.

## Verification
| Check | Result | Evidence |
|-------|--------|----------|
| v6 structure created | pass | tasks/decisions/domains/changes/evidence/.cache + federation.json + rules.json + VERSION |
| Contract blocks written | pass | $($Touched -join ", ") |
| Doctor | not run | Run /engine-doctor after migration |

## Rollback
Remove the managed blocks between ENGINE_SYSTEM_CONTRACT_MIGRATIONS_START and ENGINE_SYSTEM_CONTRACT_MIGRATIONS_END, then remove this capsule if the migration is rejected. The created directories and federation.json can be kept (harmless empty scaffolding) or removed manually.

## Next Step
Run /engine-doctor, then /engine-reconcile if Doctor reports drift.

## Responsibility Boundary
- AI checked: existing ENGINE_MAP presence, v6 structure creation, managed migration block insertion.
- Architect should decide: whether to keep the migration wording as-is or tighten missing change capsules into hard failures.
"@ | Set-Content -Path $capsule -Encoding UTF8
Write-Host "created $(Get-Relative $capsule)"

Write-Host "Engine contract migration to v6 complete. Next: run /engine-doctor."
exit 0
