#!/usr/bin/env bash
# Engine System - migrate existing engine files to the current contract
#
# Idempotently upserts managed migration blocks into old projects without
# overwriting project-specific engine memory. Also ensures the v6 data-layer
# structure (tasks/decisions/domains/changes/evidence/workstreams directories, federation
# table, decision rules baseline, local VERSION stamp) exists so an old project
# can fully operate the current v6 mechanisms.

set -euo pipefail
on_error() { echo "[engine-migrate-contract] error on line $1 (${BASH_SOURCE[0]})" >&2; exit 1; }

# histexpand 防御(D-015):交互式/被 source 的 bash 会对双引号里的 `!-` 做历史展开,
# 击穿 MARK 赋值 -> set -u unbound。set +H 关掉展开,MARK 用单引号双保险。
set +H

ROOT="${1:-${CLAUDE_PROJECT_DIR:-$PWD}}"
ENGINE_DIR="$ROOT/engine"
MAP="$ENGINE_DIR/ENGINE_MAP.md"
MARK_START='<!-- ENGINE_SYSTEM_CONTRACT_MIGRATIONS_START -->'
MARK_END='<!-- ENGINE_SYSTEM_CONTRACT_MIGRATIONS_END -->'
# Contract version: read from VERSION file (repo root, then engine/), fall back to 6.0.0.
# Written into the managed block header so Doctor / future incremental migrations can
# identify which contract version a project has installed.
if [ -f "$ROOT/VERSION" ]; then
  CONTRACT_VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
elif [ -f "$ENGINE_DIR/VERSION" ]; then
  CONTRACT_VERSION="$(tr -d '[:space:]' < "$ENGINE_DIR/VERSION")"
else
  CONTRACT_VERSION="6.0.0"
fi
TODAY="$(date +%F)"
TOUCHED=()

[ -f "$MAP" ] || {
  echo "engine/ENGINE_MAP.md not found. Run /engine-init first."
  exit 1
}

mkdir -p "$ENGINE_DIR/changes"

relpath() {
  local path="$1"
  printf '%s\n' "${path#"$ROOT"/}"
}

# Ensure v6 data-layer structure exists. Idempotent: only creates what is missing.
ensure_structure() {
  local changed=0
  # v6 data-layer directories
  local d
  for d in tasks decisions domains changes evidence plans workstreams .cache; do
    if [ ! -d "$ENGINE_DIR/$d" ]; then
      mkdir -p "$ENGINE_DIR/$d"
      echo "created $(relpath "$ENGINE_DIR/$d")/"
      changed=1
    fi
  done
  # Task card template: helps agents and developers understand the T-NNN format.
  # Only created if missing — existing task card setups are never overwritten.
  if [ ! -f "$ENGINE_DIR/tasks/README.md" ]; then
    cat > "$ENGINE_DIR/tasks/README.md" <<'TDOC'
# Task Cards (T-NNN.md)

Each task card tracks one unit of work. Create with: `T-001.md`, `T-002.md`, etc.

## Required Format (machine-readable)

```
# T-NNN: title
> status: active | lane: main | decision: D-NNN | plan: none | domain: root
GOAL: One-line outcome
WRITE-SET: src/**, engine/workstreams/T-NNN/**
FORBIDDEN: secrets/**
CONSTRAINTS: project rules and source
```

`WRITE-SET` and `FORBIDDEN` govern every project path, including `engine/*`.
The equivalent `## WRITE-SET` / `## FORBIDDEN` bullet-list form is also accepted.
Parallel workers run `engine workstream T-NNN <agent-id>` and write only their shard.
Use one card per independently verifiable, normally commit/PR-sized goal. Reuse it across prompts and workers; read-only investigation needs no card. Done cards are cold history and are not injected into session context.

## Acceptance Criteria Section

After the header, list ACs with verify commands:

```
## AC

| # | Criterion | Verify |
|---|-----------|--------|
| 1 | Description of expected behavior | `command to verify` |
| 2 | Another criterion | `another command` |
```

## Lifecycle

- **proposed**: task is planned, not yet started
- **active**: work in progress; Stop hook enforces WRITE-SET
- **done**: all ACs verified green (via `engine verify T-NNN`) or architect grants `exempt`
TDOC
    echo "created $(relpath "$ENGINE_DIR/tasks/README.md")"
    changed=1
  fi
  # Glossary: plain-language bridge between engine terminology and developer understanding.
  # Injected into agent context so agents explain things in accessible language.
  if [ ! -f "$ENGINE_DIR/GLOSSARY.md" ]; then
    cat > "$ENGINE_DIR/GLOSSARY.md" <<'GDOC'
# Engine System Glossary

> Agent: when explaining engine concepts to the developer, use the "Plain meaning" column.
> Match the developer's language — do not hardcode any specific language.

## Core Terms (engine-managed)

<!-- The terms below are maintained by the engine system. Do not edit manually. -->

| Engine term | Plain meaning | Example |
|-------------|--------------|---------|
| Engine file | A project memory file that the AI reads/writes to stay oriented | ENGINE_MAP.md, CONTEXT.md |
| ENGINE_MAP | The table of contents for all engine files — read this first each session | Like a book's index |
| CONTEXT | Current project status dashboard — what's happening right now | Like a morning briefing |
| HANDOFF | Session handoff notes — where we left off and what to do next | Like a relay baton |
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
| Irreducible | Knowledge that can't be regenerated from code — must be preserved | Decisions, rationale, lessons learned |
| Derivable | Knowledge that can be regenerated from code on demand | File listings, module maps |

## Project Terms (developer-managed)

<!-- Add project-specific terms below. This section is preserved across engine upgrades. -->

| Term | Plain meaning | Added by |
|------|--------------|----------|
GDOC
    echo "created $(relpath "$ENGINE_DIR/GLOSSARY.md")"
    changed=1
  fi
  # Federation table: standard engine-runtime + project-meta + default. Routes engine
  # files (not user business code), so it applies to any project using Engine System.
  if [ ! -f "$ENGINE_DIR/domains/federation.json" ]; then
    cat > "$ENGINE_DIR/domains/federation.json" <<'FED'
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
FED
    echo "created $(relpath "$ENGINE_DIR/domains/federation.json")"
    changed=1
  fi
  # Decision rules baseline (empty; populated as decisions are made).
  # protected_paths must exist even when empty - it is the key the pre-commit gate reads.
  if [ ! -f "$ENGINE_DIR/decisions/rules.json" ]; then
    printf '%s\n' '{"rules":[],"protected_paths":["runtime-law.md"]}' > "$ENGINE_DIR/decisions/rules.json"
    echo "created $(relpath "$ENGINE_DIR/decisions/rules.json")"
    changed=1
  fi
  # Local VERSION stamp.
  # In the engine source repo ($ROOT/VERSION is the engine tooling version AND
  # $ROOT/plugin/manifest.json exists): always sync engine/VERSION to $ROOT/
  # VERSION. Prior "create-if-missing" left engine/VERSION stuck at an older
  # version after run_migrate wrote it, causing Doctor to warn in a loop that
  # could not self-heal. Always-sync is idempotent (same value => no-op).
  # In user projects ($ROOT/VERSION is the product version, not the engine
  # tooling version — see P014; and plugin/manifest.json does NOT exist):
  # keep create-if-missing semantics; engine/VERSION is managed by install.sh.
  if [ -f "$ROOT/VERSION" ] && [ -f "$ROOT/plugin/manifest.json" ]; then
    local root_v engine_v
    root_v="$(tr -d '[:space:]' < "$ROOT/VERSION")"
    engine_v="$(tr -d '[:space:]' < "$ENGINE_DIR/VERSION" 2>/dev/null || echo "")"
    if [ "$engine_v" != "$root_v" ]; then
      printf '%s\n' "$root_v" > "$ENGINE_DIR/VERSION"
      echo "synced $(relpath "$ENGINE_DIR/VERSION")"
      changed=1
    fi
  elif [ ! -f "$ENGINE_DIR/VERSION" ]; then
    printf '%s\n' "$CONTRACT_VERSION" > "$ENGINE_DIR/VERSION"
    echo "created $(relpath "$ENGINE_DIR/VERSION")"
    changed=1
  fi
  return $changed
}

upsert_block() {
  local file="$1" title="$2" body_file="$3"
  local dir tmp block_tmp
  dir="$(dirname "$file")"
  mkdir -p "$dir"
  tmp="$(mktemp)"
  block_tmp="$(mktemp)"

  {
    printf '%s\n' "$MARK_START"
    printf '<!-- contract-version: %s -->\n' "$CONTRACT_VERSION"
    printf '## %s\n' "$title"
    printf '> Managed by Engine System contract migration. Preserve project-specific rules outside this block.\n\n'
    cat "$body_file"
    printf '%s\n' "$MARK_END"
  } > "$block_tmp"

  if [ ! -f "$file" ]; then
    cp "$block_tmp" "$file"
    echo "created $(relpath "$file")"
    rm -f "$tmp" "$block_tmp"
    return 0
  fi

  if grep -F "$MARK_START" "$file" >/dev/null 2>&1 && grep -F "$MARK_END" "$file" >/dev/null 2>&1; then
    current_block="$(mktemp)"
    awk -v start="$MARK_START" -v end="$MARK_END" '
      $0 == start { capture=1 }
      capture { print }
      $0 == end { capture=0; exit }
    ' "$file" > "$current_block"
    if cmp -s "$current_block" "$block_tmp"; then
      echo "current $(relpath "$file")"
      rm -f "$tmp" "$block_tmp" "$current_block"
      return 1
    fi
    rm -f "$current_block"
    awk -v start="$MARK_START" -v end="$MARK_END" -v block="$block_tmp" '
      $0 == start {
        while ((getline line < block) > 0) print line
        close(block)
        skip=1
        next
      }
      $0 == end { skip=0; next }
      !skip { print }
    ' "$file" > "$tmp"
    mv "$tmp" "$file"
    echo "updated $(relpath "$file")"
    rm -f "$block_tmp"
    return 0
  fi

  {
    sed -e '${/^$/d;}' "$file"
    printf '\n\n'
    cat "$block_tmp"
  } > "$tmp"
  mv "$tmp" "$file"
  echo "appended $(relpath "$file")"
  rm -f "$block_tmp"
  return 0
}

# Step 1: ensure v6 data-layer structure.
# || true is safe here: ensure_structure returns 1 when it creates directories
# (change detected = success, not error). With set -e, return 1 would abort the
# script. The true guard allows the script to continue whether or not directories
# already existed — both outcomes are acceptable for an idempotent migration step.
# Reconcile known schema drifts in engine files. Fixes safe vocabulary mappings;
# warns about structural issues that require human judgment. Addresses P014.
reconcile_schema() {
  local changed=0
  # Normalize plan/task status vocabulary in ENGINE_MAP.md.
  # Old engine versions used free-text statuses; v6 requires restricted vocabulary.
  if [ -f "$MAP" ]; then
    local map_tmp; map_tmp="$(mktemp)"
    cp "$MAP" "$map_tmp"
    # Status vocabulary mapping (old -> v6 canonical):
    #   planning / design-pending-approval / in-progress / wip -> proposed
    #   implemented / completed / done-verified / finished -> done
    #   archived / deprecated / superseded -> archived
    local sed_script
    sed_script="$(mktemp)"
    # Write sed commands to file (avoids glob expansion)
    cat > "$sed_script" <<'SEDCMD'
s/| \*planning\* */| **proposed**/g
s/ planning / proposed /g
s/| \*design-pending-approval\* */| **proposed**/g
s/ design-pending-approval / proposed /g
s/| \*in-progress\* */| **proposed**/g
s/ in-progress / proposed /g
s/| \*wip\* */| **proposed**/g
s/ wip / proposed /g
s/| \*implemented\* */| **done**/g
s/ implemented / done /g
s/| \*completed\* */| **done**/g
s/ completed / done /g
s/| \*done-verified\* */| **done**/g
s/ done-verified / done /g
s/| \*finished\* */| **done**/g
s/ finished / done /g
s/| \*archived\* */| **archived**/g
s/ archived / archived /g
s/| \*deprecated\* */| **archived**/g
s/ deprecated / archived /g
s/| \*superseded\* */| **archived**/g
s/ superseded / archived /g
SEDCMD
    sed -f "$sed_script" "$map_tmp" > "$map_tmp.2" || true
    rm -f "$sed_script"
    if ! cmp -s "$map_tmp" "$map_tmp.2"; then
      cp "$map_tmp.2" "$MAP"
      echo "reconciled $(relpath "$MAP") (status vocabulary normalized)"
      changed=1
    fi
    rm -f "$map_tmp.2"
    rm -f "$map_tmp"
    # Warn about table column count mismatches (5-col vs 7-col plan registry).
    # This is too risky to auto-fix — the semantic mapping requires human judgment.
    local plan_section; plan_section="$(grep -n '## .*Plan.*Registr\|## .*§2' "$MAP" 2>/dev/null | head -1 || true)"
    if [ -n "$plan_section" ]; then
      local start_line; start_line="$(echo "$plan_section" | cut -d: -f1)"
      local sample_row; sample_row="$(tail -n +"$start_line" "$MAP" | grep -E '^\| [A-Z]' | head -1 || true)"
      if [ -n "$sample_row" ]; then
        local col_count; col_count="$(echo "$sample_row" | awk -F'|' '{print NF-2}')"
        if [ "$col_count" -lt 6 ]; then
          echo "WARN: ENGINE_MAP §2 plan registry has $col_count columns (v6 expects 6-7). Manual reconcile recommended."
        fi
      fi
    fi
  fi
  return $changed
}

ensure_structure || true
reconcile_schema || true

session_tmp="$(mktemp)"
doctor_tmp="$(mktemp)"
cleanup() { rm -f "${session_tmp:-}" "${doctor_tmp:-}" 2>/dev/null || true; }
trap 'on_error ${LINENO}; cleanup' ERR
trap 'cleanup' EXIT

# v6 session contract block (replaces v5.7 content).
cat > "$session_tmp" <<'EOF'
- Read `engine/ENGINE_MAP.md` first, then run the path-driven read-gate via `engine/domains/federation.json` (path-glob -> domain routing).
- Task cards (`engine/tasks/T-NNN.md`) carry GOAL / WRITE-SET / FORBIDDEN / AC+verify / CONSTRAINTS + status / lane / decision / domain. Every project path, including `engine/*`, MUST stay within WRITE-SET and outside FORBIDDEN.
- One independently verifiable goal uses one task card across prompts and workers; read-only investigation needs no card. Done cards stay cold and Doctor aggregates successful history.
- In contract-version 6.5+ projects, ordinary writes require an active/closing task; only task/decision card bootstrap is allowed without one. Staging `done` requires PASS evidence for every AC or an approved exemption.
- Decision ledger (`engine/decisions/D-NNN.md`) records non-obvious choices with status / scope / expiry. Protected paths require a decision reference at commit time.
- Fractal memory: the federation table routes paths to domains; each domain may have CONTEXT.md (summary) + PITFALLS.md (budget + retrieval recipe). L2 assembly stays within the <=400 line session budget (N1).
- Three-layer gate: UserPromptSubmit short refresh + PreToolUse write check + session-attributed Stop; pre-commit rechecks all staged paths (including engine files) + decision reference; Doctor checks structure/evidence.
- Contract compile: `contract/src/*.md` is the single source of truth; `contract/compile.sh` compiles to dist; `contract/budget.json` enforces subtraction (line count <= baseline, new Rules must net-zero). Contract debt counter (N4) is tracked by Doctor.
- Cockpit: `engine verify T-NNN` runs behavior verification (AC verify commands -> PASS/FAIL + sha256 fingerprint in `engine/evidence/`). A task card may be marked `done` only when verify is all-green or the architect grants an `exempt` marker (N3).
- After meaningful changes, the coordinator updates shared `CONTEXT.md` + `HANDOFF.md` + change capsule. Parallel workers run `engine workstream T-NNN <agent-id>` and update only `engine/workstreams/<task>/<agent>/` plus evidence.
- Plans may be marked `done` only when every AC has evidence in the spec twin Evidence column, `engine/evidence/*`, or a relevant change capsule.
- Shared engine memory is coordinator-only. Claude PreToolUse blocks identified subagents from shared files; Stop uses session/agent path ledgers so sibling edits cannot satisfy write-back. Other harnesses use workstream shards + pre-commit and SHOULD isolate code in git worktrees.
- `engine context` shows unmerged workstream shards; the coordinator re-reads them at the merge point before one shared-memory update.
- Update check: `engine check-update` compares local `engine/VERSION` against the remote; session-start prints a non-blocking hint when a newer version exists.
EOF

# v6 Doctor contract block (replaces v5.7 content).
cat > "$doctor_tmp" <<'EOF'
Doctor MUST validate the current Engine System v6 contract in addition to registry health:

1. Task cards carry readable inline or section-list WRITE-SET/FORBIDDEN; those sets govern all project paths, including engine files.
2. Done task cards have PASS acceptance evidence for every declared AC (`engine/evidence/T-NNN/AC-*.json`) or an `exempt` marker (N3 done-gate).
3. Federation table `engine/domains/federation.json` is valid JSON with at least a `default_domain`.
4. Session injection budget (N1): session-start hook output <= 400 lines.
5. Contract debt (N4): MUST count + gate Rule count + debt vs baseline tracked.
6. `engine/VERSION` exists and matches the installed tooling version.
7. Recent meaningful changes have an architect-readable `engine/changes/CHANGE-*.md` capsule with required sections.
8. Plans marked `done` point to acceptance evidence in the spec twin Evidence column, `engine/evidence/*`, or a related capsule.
9. Bootloaders (AGENTS.md / CLAUDE.md) stay thin: target 30 lines, hard cap 45 lines.
10. Generated self-view snapshots, when used, live under `engine/.cache/` and are never registered as authority.
EOF

if upsert_block "$ROOT/AGENTS.md" "Engine System Current Contract" "$session_tmp"; then TOUCHED+=("AGENTS.md"); fi
if upsert_block "$ENGINE_DIR/SYSTEM.md" "Engine System Current Contract" "$session_tmp"; then TOUCHED+=("engine/SYSTEM.md"); fi
if upsert_block "$ENGINE_DIR/ENGINE_DOCTOR.md" "Current Contract Checks" "$doctor_tmp"; then TOUCHED+=("engine/ENGINE_DOCTOR.md"); fi

if [ "${#TOUCHED[@]}" -eq 0 ]; then
  echo "Engine contract migration already current. Next: run /engine-doctor if you need verification."
  exit 0
fi

next=1
while IFS= read -r file; do
  base="$(basename "$file" .md)"
  n="${base##*-}"
  case "$n" in
    [0-9][0-9])
      if [ "$((10#$n))" -ge "$next" ]; then next=$((10#$n + 1)); fi
      ;;
  esac
done < <(find "$ENGINE_DIR/changes" -maxdepth 1 -type f -name "CHANGE-$TODAY-*.md" 2>/dev/null | sort)

change_id="CHANGE-$TODAY-$(printf '%02d' "$next")"
capsule="$ENGINE_DIR/changes/$change_id.md"
cat > "$capsule" <<EOF
# $change_id - Engine contract migration to v6

> Created: $TODAY · Status: needs-verification · Related plan: none

## Goal
Migrate an existing project with old engine files to the current Engine System v6 contract without rerunning /engine-init or overwriting project-specific memory.

## Actual Changes
- Ensured v6 data-layer directories exist: tasks, decisions, domains, changes, evidence, plans, workstreams, .cache.
- Created task card template (engine/tasks/README.md) and glossary (engine/GLOSSARY.md) if missing.
- Created federation table (engine/domains/federation.json) if missing, with standard engine-runtime + project-meta domains.
- Created decision rules baseline (engine/decisions/rules.json) if missing.
- Created local VERSION stamp (engine/VERSION) if missing.
- Reconciled known schema drifts in ENGINE_MAP.md (status vocabulary normalization).
- Updated managed contract blocks (contract-version $CONTRACT_VERSION) in: ${TOUCHED[*]}.
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
| Contract blocks written | pass | ${TOUCHED[*]} |
| Doctor | chained | See Doctor output below |

## Rollback
Remove the managed blocks between ENGINE_SYSTEM_CONTRACT_MIGRATIONS_START and ENGINE_SYSTEM_CONTRACT_MIGRATIONS_END, then remove this capsule if the migration is rejected. The created directories, templates, and federation.json can be kept (they are harmless scaffolding) or removed manually.

## Next Step
Review Doctor output above. If Doctor reports warnings, run /engine-reconcile for structural issues.

## Responsibility Boundary
- AI checked: existing ENGINE_MAP presence, v6 structure creation, template generation, schema reconcile, managed migration block insertion, Doctor chain.
- Architect should decide: whether to keep the migration wording as-is or tighten missing change capsules into hard failures.
EOF
echo "created $(relpath "$capsule")"

# Chain Doctor post-migration to validate output (addresses: standalone migrate
# previously did not validate its own results).
doctor_script="$ENGINE_DIR/scripts/engine-doctor.sh"
if [ -f "$doctor_script" ]; then
  echo ""
  echo "=== Post-migration Doctor check ==="
  bash "$doctor_script" "$ROOT" || echo "(Doctor exited with warnings/failures — review above)"
  echo "==================================="
fi

echo ""
echo "Engine contract migration to v6 complete."

# Detect legacy data residue for conditional messaging.
legacy_changes=0
legacy_tasks=0
[ -d "$ENGINE_DIR/changes" ] && legacy_changes="$(find "$ENGINE_DIR/changes" -maxdepth 1 -name 'CHANGE-*.md' -type f 2>/dev/null | wc -l || echo 0)"
[ -d "$ENGINE_DIR/tasks" ] && legacy_tasks="$(find "$ENGINE_DIR/tasks" -maxdepth 1 -name 'T-*.md' -type f 2>/dev/null | wc -l || echo 0)"

echo ""
echo "═══════════════════════════════════════"
echo " Developer Summary"
echo "═══════════════════════════════════════"
echo ""
echo "What was done: Engine contract upgraded to v6"
echo ""
echo "What this means for your project:"
echo "  - Task cards: structured work items with clear scope and constraints"
echo "  - Decisions: your recorded choices that the AI must respect"
echo "  - Change capsules: human-readable summaries of what was changed and why"
echo "  - Glossary: helps the AI explain engine concepts in plain language"
echo ""
if [ "$legacy_changes" -gt 0 ] && [ "$legacy_tasks" -eq 0 ]; then
  echo "What you need to do:"
  echo "  - Detected $legacy_changes legacy change capsule(s) but 0 v6 task cards"
  echo "  - New work should use v6 task cards (engine/tasks/T-NNN.md)"
  echo "  - Run 'engine doctor' for a full health check"
else
  echo "What you need to do:"
  echo "  - No further action needed — the migration is complete"
  echo "  - Run 'engine doctor' if you want to check project health"
fi
echo ""
echo "If something goes wrong:"
echo "  - All migration changes are in engine/changes/ — review or revert"
echo "  - Run 'engine doctor' for a health check"
echo "═══════════════════════════════════════"

exit 0
