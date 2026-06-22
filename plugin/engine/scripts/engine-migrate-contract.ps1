# Engine System - migrate existing engine files to the current contract (PowerShell)
#
# Idempotently upserts managed migration blocks into old projects without overwriting
# project-specific engine memory.

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

function Upsert-Block([string]$Path, [string]$Title, [string]$Body) {
  $dir = Split-Path -Parent $Path
  if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }

  $block = @"
$Start
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

$sessionProtocol = @"
- Read ``engine/ENGINE_MAP.md`` first, then run the path-driven read-gate for touched paths.
- Preserve multi-lane workstreams: ``CONTEXT.md``, ``SPRINT.md``, ``ROADMAP.md``, and ``HANDOFF.md`` may track lane ID, owner, dependency, merge point, and next checkpoint.
- After meaningful code, documentation, dependency, engine-tooling, test, or behavior changes, update ``CONTEXT.md`` + ``HANDOFF.md`` and create/update ``engine/changes/CHANGE-*.md``.
- A change capsule must state Goal, Actual Changes, Impact Scope, Risk & Watchpoints, Verification, Rollback, Next Step, and Responsibility Boundary.
- Plans may be marked ``done`` only when every AC has evidence in the spec twin Evidence column, ``engine/evidence/*``, or a relevant change capsule.
- Shared engine-file writes are single-writer: parallel agents may gather drafts/evidence, but one writer lands ``ENGINE_MAP.md``, ``SYSTEM.md``, ``PITFALLS.md``, ``CONTEXT.md``, ``HANDOFF.md``, anchors, and plan/spec edits.
- Claude Code hooks and git pre-commit are enforcement layers; Web/other agents must follow this contract manually.
"@

$doctorContract = @"
Doctor MUST validate the current Engine System contract in addition to registry health:

1. Registered hot-path files are useful, not just present: ``CONTEXT.md`` has a status panel, ``HANDOFF.md`` has a next-step pointer and dated history, ``PITFALLS.md`` entries have trigger/scope/avoid/verify fields, and ``SPRINT.md`` points to completion criteria and verification.
2. Meaningful recent changes have an architect-readable ``engine/changes/CHANGE-*.md`` capsule.
3. Latest change capsules include Goal, Actual Changes, Impact Scope, Risk & Watchpoints, Verification, Rollback, Next Step, and Responsibility Boundary.
4. Plans marked ``done`` point to acceptance evidence in the spec twin Evidence column, ``engine/evidence/*``, or a related change capsule.
5. Generated self-view snapshots, when used, live under ``engine/.cache/project-view.generated.md`` and are never registered as authority.
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
# $changeId - Engine contract migration

> Created: $Today · Status: needs-verification · Related plan: none

## Goal
Migrate an existing project with old engine files to the current Engine System contract without rerunning /engine-init or overwriting project-specific memory.

## Actual Changes
Updated managed contract blocks so the project receives the current Engine System governance contract, including self-maintenance, change capsule, Project Self-View, acceptance evidence, Doctor parity, and workstream rules.

## Impact Scope
Engine memory layer only. Project source code and project-specific engine prose outside managed migration blocks are preserved.

## Risk & Watchpoints
If the project already had custom rules in the same files, they remain outside the managed block. Review for duplicate wording, but do not delete project-specific decisions.

## Verification
| Check | Result | Evidence |
|-------|--------|----------|
| Contract blocks written | pass | $($Touched -join ", ") |
| Doctor | not run | Run /engine-doctor after migration |

## Rollback
Remove the managed blocks between ENGINE_SYSTEM_CONTRACT_MIGRATIONS_START and ENGINE_SYSTEM_CONTRACT_MIGRATIONS_END, then remove this capsule if the migration is rejected.

## Next Step
Run /engine-doctor, then /engine-reconcile if Doctor reports drift.

## Responsibility Boundary
- AI checked: existing ENGINE_MAP presence and managed migration block insertion.
- Architect should decide: whether to keep the migration wording as-is or tighten missing change capsules into hard failures.
"@ | Set-Content -Path $capsule -Encoding UTF8
Write-Host "created $(Get-Relative $capsule)"

Write-Host "Engine contract migration complete. Next: run /engine-doctor."
exit 0
