#!/usr/bin/env bash
# Engine System - migrate existing engine files to the current contract
#
# Idempotently upserts managed migration blocks into old projects without overwriting
# project-specific engine memory.

set -euo pipefail

ROOT="${1:-${CLAUDE_PROJECT_DIR:-$PWD}}"
ENGINE_DIR="$ROOT/engine"
MAP="$ENGINE_DIR/ENGINE_MAP.md"
MARK_START="<!-- ENGINE_SYSTEM_CONTRACT_MIGRATIONS_START -->"
MARK_END="<!-- ENGINE_SYSTEM_CONTRACT_MIGRATIONS_END -->"
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

upsert_block() {
  local file="$1" title="$2" body_file="$3"
  local dir tmp block_tmp
  dir="$(dirname "$file")"
  mkdir -p "$dir"
  tmp="$(mktemp)"
  block_tmp="$(mktemp)"

  {
    printf '%s\n' "$MARK_START"
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

session_tmp="$(mktemp)"
doctor_tmp="$(mktemp)"
trap 'rm -f "$session_tmp" "$doctor_tmp"' EXIT

cat > "$session_tmp" <<'EOF'
- Read `engine/ENGINE_MAP.md` first, then run the path-driven read-gate for touched paths.
- Preserve multi-lane workstreams: `CONTEXT.md`, `SPRINT.md`, `ROADMAP.md`, and `HANDOFF.md` may track lane ID, owner, dependency, merge point, and next checkpoint.
- After meaningful code, documentation, dependency, engine-tooling, test, or behavior changes, update `CONTEXT.md` + `HANDOFF.md` and create/update `engine/changes/CHANGE-*.md`.
- A change capsule must state Goal, Actual Changes, Impact Scope, Risk & Watchpoints, Verification, Rollback, Next Step, and Responsibility Boundary.
- Plans may be marked `done` only when every AC has evidence in the spec twin Evidence column, `engine/evidence/*`, or a relevant change capsule.
- Shared engine-file writes are single-writer: parallel agents may gather drafts/evidence, but one writer lands `ENGINE_MAP.md`, `SYSTEM.md`, `PITFALLS.md`, `CONTEXT.md`, `HANDOFF.md`, anchors, and plan/spec edits.
- Claude Code hooks and git pre-commit are enforcement layers; Web/other agents must follow this contract manually.
EOF

cat > "$doctor_tmp" <<'EOF'
Doctor MUST validate the current Engine System contract in addition to registry health:

1. Registered hot-path files are useful, not just present: `CONTEXT.md` has a status panel, `HANDOFF.md` has a next-step pointer and dated history, `PITFALLS.md` entries have trigger/scope/avoid/verify fields, and `SPRINT.md` points to completion criteria and verification.
2. Meaningful recent changes have an architect-readable `engine/changes/CHANGE-*.md` capsule.
3. Latest change capsules include Goal, Actual Changes, Impact Scope, Risk & Watchpoints, Verification, Rollback, Next Step, and Responsibility Boundary.
4. Plans marked `done` point to acceptance evidence in the spec twin Evidence column, `engine/evidence/*`, or a related change capsule.
5. Generated self-view snapshots, when used, live under `engine/.cache/project-view.generated.md` and are never registered as authority.
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
# $change_id - Engine contract migration

> Created: $TODAY · Status: needs-verification · Related plan: none

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
| Contract blocks written | pass | ${TOUCHED[*]} |
| Doctor | not run | Run /engine-doctor after migration |

## Rollback
Remove the managed blocks between ENGINE_SYSTEM_CONTRACT_MIGRATIONS_START and ENGINE_SYSTEM_CONTRACT_MIGRATIONS_END, then remove this capsule if the migration is rejected.

## Next Step
Run /engine-doctor, then /engine-reconcile if Doctor reports drift.

## Responsibility Boundary
- AI checked: existing ENGINE_MAP presence and managed migration block insertion.
- Architect should decide: whether to keep the migration wording as-is or tighten missing change capsules into hard failures.
EOF
echo "created $(relpath "$capsule")"

echo "Engine contract migration complete. Next: run /engine-doctor."
exit 0
