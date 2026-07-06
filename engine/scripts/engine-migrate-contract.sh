#!/usr/bin/env bash
# Engine System - migrate existing engine files to the current contract
#
# Idempotently upserts managed migration blocks into old projects without
# overwriting project-specific engine memory. Also ensures the v6 data-layer
# structure (tasks/decisions/domains/changes/evidence directories, federation
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
  for d in tasks decisions domains changes evidence .cache; do
    if [ ! -d "$ENGINE_DIR/$d" ]; then
      mkdir -p "$ENGINE_DIR/$d"
      echo "created $(relpath "$ENGINE_DIR/$d")/"
      changed=1
    fi
  done
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
    printf '%s\n' '{"rules":[],"protected_paths":[]}' > "$ENGINE_DIR/decisions/rules.json"
    echo "created $(relpath "$ENGINE_DIR/decisions/rules.json")"
    changed=1
  fi
  # Local VERSION stamp: copy from repo root if available, else use contract version.
  if [ ! -f "$ENGINE_DIR/VERSION" ]; then
    if [ -f "$ROOT/VERSION" ]; then
      cp "$ROOT/VERSION" "$ENGINE_DIR/VERSION"
    else
      printf '%s\n' "$CONTRACT_VERSION" > "$ENGINE_DIR/VERSION"
    fi
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
ensure_structure || true

session_tmp="$(mktemp)"
doctor_tmp="$(mktemp)"
cleanup() { rm -f "${session_tmp:-}" "${doctor_tmp:-}" 2>/dev/null || true; }
trap 'on_error ${LINENO}; cleanup' ERR
trap 'cleanup' EXIT

# v6 session contract block (replaces v5.7 content).
cat > "$session_tmp" <<'EOF'
- Read `engine/ENGINE_MAP.md` first, then run the path-driven read-gate via `engine/domains/federation.json` (path-glob -> domain routing).
- Task cards (`engine/tasks/T-NNN.md`) carry a machine-readable header: GOAL / WRITE-SET / FORBIDDEN / AC+verify / CONSTRAINTS + status / lane / decision / domain. Work MUST stay within WRITE-SET and outside FORBIDDEN.
- Decision ledger (`engine/decisions/D-NNN.md`) records non-obvious choices with status / scope / expiry. Protected paths require a decision reference at commit time.
- Fractal memory: the federation table routes paths to domains; each domain may have CONTEXT.md (summary) + PITFALLS.md (budget + retrieval recipe). L2 assembly stays within the <=400 line session budget (N1).
- Three-layer gate: Stop hook (WRITE-SET / routing / FORBIDDEN -> block; missing write-back -> block; missing capsule -> warn) + git pre-commit (decision reference, done fallback) + Doctor.
- Contract compile: `contract/src/*.md` is the single source of truth; `contract/compile.sh` compiles to dist; `contract/budget.json` enforces subtraction (line count <= baseline, new Rules must net-zero). Contract debt counter (N4) is tracked by Doctor.
- Cockpit: `engine verify T-NNN` runs behavior verification (AC verify commands -> PASS/FAIL + sha256 fingerprint in `engine/evidence/`). A task card may be marked `done` only when verify is all-green or the architect grants an `exempt` marker (N3).
- After meaningful code, doc, dependency, engine-tooling, test, or behavior changes, update `CONTEXT.md` + `HANDOFF.md` and create `engine/changes/CHANGE-*.md` (Goal / Actual Changes / Impact Scope / Risk & Watchpoints / Verification / Rollback / Next Step / Responsibility Boundary).
- Plans may be marked `done` only when every AC has evidence in the spec twin Evidence column, `engine/evidence/*`, or a relevant change capsule.
- Shared engine-file writes are single-writer: parallel agents may gather drafts/evidence, but one writer lands `ENGINE_MAP.md`, `SYSTEM.md`, `PITFALLS.md`, `CONTEXT.md`, `HANDOFF.md`, anchors, and plan/spec edits.
- Claude Code hooks and git pre-commit are enforcement layers; Web/other agents follow this contract manually.
- Update check: `engine check-update` compares local `engine/VERSION` against the remote; session-start prints a non-blocking hint when a newer version exists.
EOF

# v6 Doctor contract block (replaces v5.7 content).
cat > "$doctor_tmp" <<'EOF'
Doctor MUST validate the current Engine System v6 contract in addition to registry health:

1. Task cards (`engine/tasks/T-*.md`) carry v6 machine-readable headers (GOAL / WRITE-SET / FORBIDDEN / AC+verify / CONSTRAINTS + status / lane / decision / domain).
2. Done task cards have acceptance evidence (`engine/evidence/T-NNN/AC-*.json`) or an `exempt` marker (N3 done-gate).
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
- Ensured v6 data-layer directories exist: tasks, decisions, domains, changes, evidence, .cache.
- Created federation table (engine/domains/federation.json) if missing, with standard engine-runtime + project-meta domains.
- Created decision rules baseline (engine/decisions/rules.json) if missing.
- Created local VERSION stamp (engine/VERSION) if missing.
- Updated managed contract blocks (contract-version $CONTRACT_VERSION) in: ${TOUCHED[*]}.
- The v6 block covers: task card headers, decision ledger, fractal memory, three-layer gate, contract compile, cockpit verify, change capsules, single-writer merges, update check.

## Impact Scope
Engine memory layer only. Project source code and project-specific engine prose outside managed migration blocks are preserved.

## Risk & Watchpoints
If the project already had custom rules in the same files, they remain outside the managed block. Review for duplicate wording, but do not delete project-specific decisions. Existing task cards are NOT reformatted - only new cards must use the v6 header.

## Verification
| Check | Result | Evidence |
|-------|--------|----------|
| v6 structure created | pass | tasks/decisions/domains/changes/evidence/.cache + federation.json + rules.json + VERSION |
| Contract blocks written | pass | ${TOUCHED[*]} |
| Doctor | not run | Run /engine-doctor after migration |

## Rollback
Remove the managed blocks between ENGINE_SYSTEM_CONTRACT_MIGRATIONS_START and ENGINE_SYSTEM_CONTRACT_MIGRATIONS_END, then remove this capsule if the migration is rejected. The created directories and federation.json can be kept (they are harmless empty scaffolding) or removed manually.

## Next Step
Run /engine-doctor, then /engine-reconcile if Doctor reports drift.

## Responsibility Boundary
- AI checked: existing ENGINE_MAP presence, v6 structure creation, managed migration block insertion.
- Architect should decide: whether to keep the migration wording as-is or tighten missing change capsules into hard failures.
EOF
echo "created $(relpath "$capsule")"

echo "Engine contract migration to v6 complete. Next: run /engine-doctor."
exit 0
