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
# Contract version: read from VERSION file (repo root, then engine/), fall back to 6.0.0.
$repoVersionFile = Join-Path $Root "VERSION"
$engineVersionFile = Join-Path $EngineDir "VERSION"
if (Test-Path $repoVersionFile) {
  $ContractVersion = (Get-Content $repoVersionFile -Raw -Encoding UTF8).Trim()
} elseif (Test-Path $engineVersionFile) {
  $ContractVersion = (Get-Content $engineVersionFile -Raw -Encoding UTF8).Trim()
} else {
  $ContractVersion = "6.0.0"
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
  foreach ($d in @("tasks", "decisions", "domains", "changes", "evidence", "plans", "workstreams", ".cache")) {
    $p = Join-Path $EngineDir $d
    if (-not (Test-Path $p)) {
      New-Item -ItemType Directory -Force -Path $p | Out-Null
      Write-Host "created $(Get-Relative $p)/"
      $changed = $true
    }
  }
  # Task card template: helps agents and developers understand the T-NNN format.
  $taskReadme = Join-Path $EngineDir "tasks\README.md"
  if (-not (Test-Path $taskReadme)) {
    $taskContent = @"
# Task Cards (T-NNN.md)

Each task card tracks one unit of work. Create with: ``T-001.md``, ``T-002.md``, etc.

## Required Format (machine-readable)

``````
# T-NNN: title
> status: active | lane: main | decision: D-NNN | plan: none | domain: root
GOAL: One-line outcome
WRITE-SET: src/**, engine/workstreams/T-NNN/**
FORBIDDEN: secrets/**
CONSTRAINTS: project rules and source
``````

``WRITE-SET`` and ``FORBIDDEN`` govern every project path, including ``engine/*``.
The equivalent ``## WRITE-SET`` / ``## FORBIDDEN`` bullet-list form is also accepted.
Parallel workers run ``engine workstream T-NNN <agent-id>`` and write only their shard.
Use one card per independently verifiable, normally commit/PR-sized goal. Reuse it across prompts and workers; read-only investigation needs no card. Done cards are cold history and are not injected into session context.

## Acceptance Criteria Section

After the header, list ACs with verify commands:

``````
## AC

| # | Criterion | Verify |
|---|-----------|--------|
| 1 | Description of expected behavior | ``command to verify`` |
| 2 | Another criterion | ``another command`` |
``````

## Lifecycle

- **proposed**: task is planned, not yet started
- **active**: work in progress; Stop hook enforces WRITE-SET
- **done**: all ACs verified green (via ``engine verify T-NNN``) or architect grants ``exempt``
"@
    Set-Content -Path $taskReadme -Value $taskContent -Encoding UTF8
    Write-Host "created $(Get-Relative $taskReadme)"
    $changed = $true
  }
  # Glossary: plain-language bridge between engine terminology and developer understanding.
  $glossary = Join-Path $EngineDir "GLOSSARY.md"
  if (-not (Test-Path $glossary)) {
    $glossaryContent = @"
# Engine System Glossary

> Agent: when explaining engine concepts to the developer, use the "Plain meaning" column.
> Match the developer's language - do not hardcode any specific language.

## Core Terms (engine-managed)

<!-- The terms below are maintained by the engine system. Do not edit manually. -->

| Engine term | Plain meaning | Example |
|-------------|--------------|---------|
| Engine file | A project memory file that the AI reads/writes to stay oriented | ENGINE_MAP.md, CONTEXT.md |
| ENGINE_MAP | The table of contents for all engine files - read this first each session | Like a book's index |
| CONTEXT | Current project status dashboard - what's happening right now | Like a morning briefing |
| HANDOFF | Session handoff notes - where we left off and what to do next | Like a relay baton |
| Task card (T-NNN) | A structured work item with clear scope, acceptance criteria, and constraints | Like a Jira ticket |
| Decision (D-NNN) | A recorded non-obvious choice with rationale and scope | Like an ADR (architecture decision record) |
| Change capsule | A human-readable summary of what was changed and why | Like a detailed commit message |
| Federation table | A routing map that groups project files into domains for context management | Like folders with smart labels |
| Doctor | Health check that validates engine file consistency | Like a linter for project memory |
| Write-back | Updating engine files after making code changes | Like updating meeting notes after a meeting |
| Gate / Hook | Automatic checks that run before/after actions to prevent mistakes | Like a spell-checker that runs before you send |
| Contract | The set of rules governing how engine files work together | Like a team's working agreement |
| Pitfall | A documented mistake to avoid repeating | Like a "lessons learned" entry |
| Plan / Spec | A design document (plan) paired with its technical specification (spec) | Like a blueprint + engineering drawing |
| reconcile | Comparing engine memory against actual code and fixing any drift | Like proofreading a document against the source |
| Irreducible | Knowledge that can't be regenerated from code - must be preserved | Decisions, rationale, lessons learned |
| Derivable | Knowledge that can be regenerated from code on demand | File listings, module maps |

## Project Terms (developer-managed)

<!-- Add project-specific terms below. This section is preserved across engine upgrades. -->

| Term | Plain meaning | Added by |
|------|--------------|----------|
"@
    Set-Content -Path $glossary -Value $glossaryContent -Encoding UTF8
    Write-Host "created $(Get-Relative $glossary)"
    $changed = $true
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
        "engine/workstreams/**",
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
    Set-Content -Path $rules -Value '{"rules":[],"protected_paths":["runtime-law.md"]}' -Encoding UTF8
    Write-Host "created $(Get-Relative $rules)"
    $changed = $true
  }
  $ver = Join-Path $EngineDir "VERSION"
  # In the engine source repo ($ROOT/VERSION is the engine tooling version AND
  # $ROOT/plugin/manifest.json exists): always sync engine/VERSION to $ROOT/VERSION.
  # Prior "create-if-missing" left engine/VERSION stuck at an older version
  # after run_migrate wrote it, causing Doctor to warn in a loop that could
  # not self-heal. Always-sync is idempotent (same value => no-op).
  # In user projects ($ROOT/VERSION is the product version - see P014; and
  # plugin/manifest.json does NOT exist): keep create-if-missing; engine/VERSION
  # is managed by install.sh.
  $isSourceRepo = (Test-Path $repoVersionFile) -and (Test-Path (Join-Path $Root "plugin/manifest.json"))
  if ($isSourceRepo) {
    $rootV = (Get-Content $repoVersionFile -Raw -Encoding UTF8).Trim()
    $engineV = ""
    if (Test-Path $ver) { $engineV = (Get-Content $ver -Raw -Encoding UTF8).Trim() }
    if ($engineV -ne $rootV) {
      Copy-Item $repoVersionFile $ver
      Write-Host "synced $(Get-Relative $ver)"
      $changed = $true
    }
  } elseif (-not (Test-Path $ver)) {
    Set-Content -Path $ver -Value $ContractVersion -Encoding UTF8
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

# Reconcile known schema drifts in engine files. Fixes safe vocabulary mappings;
# warns about structural issues that require human judgment. Addresses P014.
function Reconcile-Schema {
  $changed = $false
  if (Test-Path $Map) {
    $content = Get-Content $Map -Raw -Encoding UTF8
    $original = $content
    # Status vocabulary mapping (old -> v6 canonical)
    $mappings = @{
      'planning'                 = 'proposed'
      'design-pending-approval'  = 'proposed'
      'in-progress'              = 'proposed'
      'wip'                      = 'proposed'
      'implemented'              = 'done'
      'completed'                = 'done'
      'done-verified'            = 'done'
      'finished'                 = 'done'
      'deprecated'               = 'archived'
      'superseded'               = 'archived'
    }
    foreach ($pair in $mappings.GetEnumerator()) {
      # Match bold status in table cells: | **old** |
      $content = $content -replace "\*\*$($pair.Key)\*\*", "**$($pair.Value)**"
      # Match plain status surrounded by spaces in table cells: | old |
      $content = $content -replace "\s$($pair.Key)\s", " $($pair.Value) "
    }
    if ($content -ne $original) {
      Set-Content -Path $Map -Value $content -Encoding UTF8
      Write-Host "reconciled $(Get-Relative $Map) (status vocabulary normalized)"
      $changed = $true
    }
    # Warn about table column count mismatches (P014: structural issues need human judgment)
    $lines = Get-Content $Map -Encoding UTF8
    $inPlanSection = $false
    foreach ($line in $lines) {
      if ($line -match '## .*Plan.*Registr|## .*§2') { $inPlanSection = $true; continue }
      if ($inPlanSection -and $line -match '^\| [A-Z]') {
        $cols = ($line -split '\|').Count - 2
        if ($cols -lt 6) {
          Write-Host "WARN: ENGINE_MAP §2 plan registry has $cols columns (v6 expects 6-7). Manual reconcile recommended."
        }
        break
      }
    }
  }
  return $changed
}

# Step 1: ensure v6 data-layer structure.
Ensure-Structure | Out-Null
Reconcile-Schema | Out-Null

# v6 session contract block (replaces v5.7 content).
$sessionProtocol = @"
- Read ``engine/ENGINE_MAP.md`` first, then run the path-driven read-gate via ``engine/domains/federation.json`` (path-glob -> domain routing).
- Task cards (``engine/tasks/T-NNN.md``) carry GOAL / WRITE-SET / FORBIDDEN / AC+verify / CONSTRAINTS + status / lane / decision / domain. Every project path, including ``engine/*``, MUST stay within WRITE-SET and outside FORBIDDEN.
- One independently verifiable goal uses one task card across prompts and workers; read-only investigation needs no card. Done cards stay cold and Doctor aggregates successful history.
- In contract-version 6.5+ projects, ordinary writes require an active/closing task; only task/decision card bootstrap is allowed without one. Staging ``done`` requires PASS evidence for every AC or an approved exemption.
- Decision ledger (``engine/decisions/D-NNN.md``) records non-obvious choices with status / scope / expiry. Protected paths require a decision reference at commit time.
- Fractal memory: the federation table routes paths to domains; each domain may have CONTEXT.md (summary) + PITFALLS.md (budget + retrieval recipe). L2 assembly stays within the <=400 line session budget (N1).
- Three-layer gate: UserPromptSubmit short refresh + PreToolUse write check + session-attributed Stop; pre-commit rechecks all staged paths (including engine files) + decision reference; Doctor checks structure/evidence.
- Contract compile: ``contract/src/*.md`` is the single source of truth; ``contract/compile.sh`` compiles to dist; ``contract/budget.json`` enforces subtraction (line count <= baseline, new Rules must net-zero). Contract debt counter (N4) is tracked by Doctor.
- Cockpit: ``engine verify T-NNN`` runs behavior verification (AC verify commands -> PASS/FAIL + sha256 fingerprint in ``engine/evidence/``). A task card may be marked ``done`` only when verify is all-green or the architect grants an ``exempt`` marker (N3).
- After meaningful changes, the coordinator updates shared ``CONTEXT.md`` + ``HANDOFF.md`` + change capsule. Parallel workers run ``engine workstream T-NNN <agent-id>`` and update only ``engine/workstreams/<task>/<agent>/`` plus evidence.
- Plans may be marked ``done`` only when every AC has evidence in the spec twin Evidence column, ``engine/evidence/*``, or a relevant change capsule.
- Shared engine memory is coordinator-only. Claude PreToolUse blocks identified subagents from shared files; Stop uses session/agent path ledgers so sibling edits cannot satisfy write-back. Other harnesses use workstream shards + pre-commit and SHOULD isolate code in git worktrees.
- ``engine context`` shows unmerged workstream shards; the coordinator re-reads them at the merge point before one shared-memory update.
- Update check: ``engine check-update`` compares local ``engine/VERSION`` against the remote; session-start prints a non-blocking hint when a newer version exists.
"@

# v6 Doctor contract block (replaces v5.7 content).
$doctorContract = @"
Doctor MUST validate the current Engine System v6 contract in addition to registry health:

1. Task cards carry readable inline or section-list WRITE-SET/FORBIDDEN; those sets govern all project paths, including engine files.
2. Done task cards have PASS acceptance evidence for every declared AC (``engine/evidence/T-NNN/AC-*.json``) or an ``exempt`` marker (N3 done-gate).
3. Federation table ``engine/domains/federation.json`` is valid JSON with at least a ``default_domain``.
4. Session injection budget (N1): session-start hook output <= 400 lines.
5. Contract debt (N4): MUST count + gate Rule count + debt vs baseline tracked.
6. ``engine/VERSION`` exists and matches the installed tooling version.
7. Recent meaningful changes have an architect-readable ``engine/changes/CHANGE-*.md`` capsule with required sections.
8. Plans marked ``done`` point to acceptance evidence in the spec twin Evidence column, ``engine/evidence/*``, or a related capsule.
9. Bootloaders (AGENTS.md / CLAUDE.md) stay thin: target 30 lines, hard cap 45 lines.
10. Generated self-view snapshots, when used, live under ``engine/.cache/`` and are never registered as authority.
11. HANDOFF.md session history table keeps <= 8 rows; older rows move to ``engine/handoff-archive-YYYY-MM.md`` (search-only, not registered in ENGINE_MAP section 1, not loaded by SessionStart). Verified items in CONTEXT.md "to-verify" sections are removed.
12. Task-level progress.md (v6.7.0+): active/paused task cards MUST have a corresponding ``engine/tasks/T-NNN/progress.md`` (7-section recovery anchor, see ``contract/src/20-file-templates.md`` FILE 13); done task cards MUST have their progress.md archived to ``engine/archive/tasks/T-NNN-progress.md`` and the live copy removed (mirrors D-027 HANDOFF archive). Projects stamped ``contract-version < 6.7.0`` get WARN (migration grace period, see D-028 section 9); ``>= 6.7.0`` get FAIL.
13. Domain INVENTORY.md (v6.8.0+, D-028/T-033): bidirectional FAIL check enforced by ``check_inventory_bidirectional`` — (a) INVENTORY→code: every Entry file path in any ``engine/domains/<domain>/INVENTORY.md`` row must exist (``test -f``); (b) code→INVENTORY: every file path touched by a ``done`` task card (per its WRITE-SET and change capsule file list) must be represented in its domain's INVENTORY (the Entry file column must mention the path, or the domain must have at least one row for the feature area). Projects stamped ``contract-version < 6.8.0`` get WARN (migration grace period, see D-028 §9); ``>= 6.8.0`` get FAIL. INVENTORY total view ≤120 lines; sub-files ``engine/domains/<domain>/INVENTORY/<feature>.md`` ≤200 lines each. INVENTORY does not enter SessionStart full injection — only the first-line summary enters the domain dashboard.
14. INVENTORY API uniqueness (v6.8.0+, D-028 §10 mechanism C): ``check_inventory_api_uniqueness`` scans the Public API column across all ``engine/domains/*/INVENTORY.md`` and ``engine/domains/*/INVENTORY/*.md`` files; the same API contract name must not appear more than once across the whole repo, duplicates = FAIL. Optional normalization (trim + lowercase) on the Feature column catches "same function different name" cases. Migration grace period same as #13: ``contract-version < 6.8.0`` WARN, ``>= 6.8.0`` FAIL.
"@

# v6.7.0 (D-028/T-032): ensure engine/skeleton/progress.md template exists in the
# target project so active/paused task cards can be instantiated from it. Idempotent:
# only creates if missing, never overwrites.
$skeletonProgress = Join-Path $EngineDir "skeleton\progress.md"
if (-not (Test-Path $skeletonProgress)) {
  $skeletonDir = Split-Path -Parent $skeletonProgress
  if (-not (Test-Path $skeletonDir)) { New-Item -ItemType Directory -Force -Path $skeletonDir | Out-Null }
  $progressTemplate = @"
# progress — [Task ID: T-NNN] [Task Title]
> Last updated: [date] | 任务级压缩恢复锚点 | 7 栏事件驱动更新,见 contract/src/20-file-templates.md FILE 13

## §1 已读文件（理解项目）
- [path] — [一句摘要]

## §2 已确认接口（不重复读）
- [fn(arg: T) -> R] — [返回语义]

## §3 已排除路径（原 TRAIL 的家）
- [time] / [被拒绝方案] / [原因] / [采用方案]

## §4 当前进行到（压缩恢复点）
正在做:[一句话]
下一步:[一句话]

## §5 待确认问题
- [问题] / 阻塞:[谁] / 提出:[time]

## §6 已知风险/未解 bug
- [描述] / 影响:[范围] / 缓解:[状态]

## §7 回滚尝试
- [代码段] / 回滚原因:[一句话] / 替代方案:[一句话]
"@
  Set-Content -Path $skeletonProgress -Value $progressTemplate -Encoding UTF8
  Write-Host "created $(Get-Relative $skeletonProgress) (v6.7.0 progress.md template)"
}

# v6.8.0 (D-028/T-033): ensure engine/skeleton/domains/INVENTORY.md template
# exists in the target project so each domain can be instantiated from it.
# Idempotent: only creates if missing, never overwrites.
$skeletonInventory = Join-Path $EngineDir "skeleton\domains\INVENTORY.md"
if (-not (Test-Path $skeletonInventory)) {
  $skeletonInvDir = Split-Path -Parent $skeletonInventory
  if (-not (Test-Path $skeletonInvDir)) { New-Item -ItemType Directory -Force -Path $skeletonInvDir | Out-Null }
  $inventoryTemplate = @"
# INVENTORY — [Domain Name]
> Last updated: [date] | 域级功能索引 | 5 列 ≤120 行,见 contract/src/20-file-templates.md FILE 14

| Feature | Entry file | Public API | Status | Last verified |
|---------|-----------|------------|--------|---------------|
| [功能名] | [path/to/entry] | [api_contract_name] | [stable/experimental/deprecated/wip] | [YYYY-MM-DD] |

<!--
  维护规则:
  - 任务卡 done 时 MUST 更新涉及行（task-run.md 行为规则）
  - Entry file 路径必须存在（Doctor INVENTORY→code FAIL 检查）
  - Public API 全仓唯一（Doctor API 唯一性 FAIL 检查）
  - 总览 ≤120 行,超出拆到 INVENTORY/<feature>.md 子文件
  - 不写 API 完整签名 / 调用链 / 符号定位（交给 ast-grep 现生）
-->
"@
  Set-Content -Path $skeletonInventory -Value $inventoryTemplate -Encoding UTF8
  Write-Host "created $(Get-Relative $skeletonInventory) (v6.8.0 INVENTORY.md template)"
}

# v6.8.0 (D-028 §9/T-033): for each existing domain directory under
# engine/domains/, create an empty-header INVENTORY.md stub if missing.
# Idempotent: never overwrites an existing INVENTORY.md. The stub carries
# the 5-column header + one example row + a "migrated from v6.7.x, features
# pending" comment so Doctor's bidirectional check has a structure to read.
$domainsRoot = Join-Path $EngineDir "domains"
if (Test-Path $domainsRoot) {
  Get-ChildItem -Path $domainsRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $domainName = $_.Name
    $invFile = Join-Path $_.FullName "INVENTORY.md"
    if (Test-Path $invFile) { return }
    $stub = @"
# INVENTORY — $domainName
> Last updated: $Today | 域级功能索引 | 5 列 ≤120 行,见 contract/src/20-file-templates.md FILE 14

| Feature | Entry file | Public API | Status | Last verified |
|---------|-----------|------------|--------|---------------|
| [功能名] | [path/to/entry] | [api_contract_name] | [stable/experimental/deprecated/wip] | [YYYY-MM-DD] |

<!--
  迁移自 v6.7.x:本 stub 由 engine-migrate-contract 创建,功能索引待补。
  任务卡 done 时 MUST 更新涉及行（task-run.md 行为规则）。
  Entry file 路径必须存在（Doctor INVENTORY→code FAIL 检查）。
  Public API 全仓唯一（Doctor API 唯一性 FAIL 检查）。
  总览 ≤120 行,超出拆到 INVENTORY/<feature>.md 子文件。
  不写 API 完整签名 / 调用链 / 符号定位（交给 ast-grep 现生）。
-->
"@
    Set-Content -Path $invFile -Value $stub -Encoding UTF8
    Write-Host "created $(Get-Relative $invFile) (v6.8.0 INVENTORY stub for domain $domainName)"
  }
}

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
- Ensured v6 data-layer directories exist: tasks, decisions, domains, changes, evidence, plans, workstreams, .cache.
- Created task card template (engine/tasks/README.md) and glossary (engine/GLOSSARY.md) if missing.
- Created federation table (engine/domains/federation.json) if missing, with standard engine-runtime + project-meta domains.
- Created decision rules baseline (engine/decisions/rules.json) if missing.
- Created local VERSION stamp (engine/VERSION) if missing.
- Reconciled known schema drifts in ENGINE_MAP.md (status vocabulary normalization).
- Updated managed contract blocks (contract-version $ContractVersion) in: $($Touched -join ", ").
- The v6.5 block covers: all-path task gates, decision ledger, fractal memory, prompt/write/stop gates, workstream shards, contract compile, cockpit verify, and update check.
- Ran Doctor post-migration to validate migration output.

## Impact Scope
Engine memory layer only. Project source code and project-specific engine prose outside managed migration blocks are preserved.

## Risk & Watchpoints
If the project already had custom rules in the same files, they remain outside the managed block. Existing task cards are not reformatted; inline and section-list WRITE-SET forms are both supported.

## Verification
| Check | Result | Evidence |
|-------|--------|----------|
| v6 structure created | pass | tasks/decisions/domains/changes/evidence/plans/workstreams/.cache + federation.json + rules.json + VERSION |
| Templates created | pass | tasks/README.md + GLOSSARY.md |
| Schema reconcile | pass | ENGINE_MAP.md status vocabulary normalized |
| Contract blocks written | pass | $($Touched -join ", ") |
| Doctor | chained | See Doctor output below |

## Rollback
Remove the managed blocks between ENGINE_SYSTEM_CONTRACT_MIGRATIONS_START and ENGINE_SYSTEM_CONTRACT_MIGRATIONS_END, then remove this capsule if the migration is rejected. The created directories, templates, and federation.json can be kept (harmless scaffolding) or removed manually.

## Next Step
Review Doctor output above. If Doctor reports warnings, run /engine-reconcile for structural issues.

## Responsibility Boundary
- AI checked: existing ENGINE_MAP presence, v6 structure creation, template generation, schema reconcile, managed migration block insertion, Doctor chain.
- Architect should decide: whether to keep the migration wording as-is or tighten missing change capsules into hard failures.
"@ | Set-Content -Path $capsule -Encoding UTF8
Write-Host "created $(Get-Relative $capsule)"

# Chain Doctor post-migration to validate output.
$doctorScript = Join-Path $EngineDir "scripts\engine-doctor.ps1"
if (Test-Path $doctorScript) {
  Write-Host ""
  Write-Host "=== Post-migration Doctor check ==="
  try {
    & pwsh -NoProfile -File $doctorScript $Root 2>&1
  } catch {
    & powershell -NoProfile -File $doctorScript $Root 2>&1
  }
  Write-Host "==================================="
}

Write-Host ""
Write-Host "Engine contract migration to v6 complete."

# Detect legacy data residue for conditional messaging.
$legacyChanges = 0
$legacyTasks = 0
$changesDirPath = Join-Path $EngineDir "changes"
$tasksDirPath = Join-Path $EngineDir "tasks"
if (Test-Path $changesDirPath) {
  $legacyChanges = (Get-ChildItem -Path $changesDirPath -Filter "CHANGE-*.md" -File -ErrorAction SilentlyContinue | Measure-Object).Count
}
if (Test-Path $tasksDirPath) {
  $legacyTasks = (Get-ChildItem -Path $tasksDirPath -Filter "T-*.md" -File -ErrorAction SilentlyContinue | Measure-Object).Count
}

Write-Host ""
Write-Host "======================================="
Write-Host " Developer Summary"
Write-Host "======================================="
Write-Host ""
Write-Host "What was done: Engine contract upgraded to v6"
Write-Host ""
Write-Host "What this means for your project:"
Write-Host "  - Task cards: structured work items with clear scope and constraints"
Write-Host "  - Decisions: your recorded choices that the AI must respect"
Write-Host "  - Change capsules: human-readable summaries of what was changed and why"
Write-Host "  - Glossary: helps the AI explain engine concepts in plain language"
Write-Host ""
if ($legacyChanges -gt 0 -and $legacyTasks -eq 0) {
  Write-Host "What you need to do:"
  Write-Host "  - Detected $legacyChanges legacy change capsule(s) but 0 v6 task cards"
  Write-Host "  - New work should use v6 task cards (engine/tasks/T-NNN.md)"
  Write-Host "  - Run 'engine doctor' for a full health check"
} else {
  Write-Host "What you need to do:"
  Write-Host "  - No further action needed - the migration is complete"
  Write-Host "  - Run 'engine doctor' if you want to check project health"
}
Write-Host ""
Write-Host "If something goes wrong:"
Write-Host "  - All migration changes are in engine/changes/ - review or revert"
Write-Host "  - Run 'engine doctor' for a health check"
Write-Host "======================================="

exit 0
