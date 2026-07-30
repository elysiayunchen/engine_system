#!/usr/bin/env bash
# Test: migrator contract-version bump prompt (T-063, v6.17.2, issue #15)
#
# Validates the bump-detection prompt added to engine-migrate-contract.sh.
# When the migrator detects a contract-version change (OLD stamp in the existing
# managed block != NEW stamp from engine/VERSION), it prints a prompt listing
# active/paused task cards. Idempotent repair (no version change) stays silent.
#
# Scenarios:
#   S1 (AC-1, AC-2): bump (OLD=6.16.0, NEW=6.17.2) + active card -> prompt fires + card listed
#   S2 (AC-3): idempotent repair (OLD=6.17.2 == NEW=6.17.2) -> prompt silent + "already current"
#   S3 (AC-2): bump with no active cards -> prompt fires + "No active/paused task cards found."
#   S4 (regression): fresh install (no prior managed block) -> migrator succeeds, no prompt, stamp written
#
# Black-box test: invokes the real migrator against a throwaway project tree.

set -euo pipefail

echo "[test_migrator_bump_prompt.sh] T-063 migrator contract-version bump prompt"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MIGRATOR="$REPO_ROOT/engine/scripts/engine-migrate-contract.sh"

PASS=0
FAIL=0
TMPDIR_S1=""
TMPDIR_S2=""
TMPDIR_S3=""
TMPDIR_S4=""
trap 'rm -rf ${TMPDIR_S1:-} ${TMPDIR_S2:-} ${TMPDIR_S3:-} ${TMPDIR_S4:-} 2>/dev/null || true' EXIT

assert_contains() {
  local label="$1" haystack="$2" needle="$3"
  if printf '%s' "$haystack" | grep -qF -- "$needle"; then
    echo "  PASS: $label"
    PASS=$((PASS+1))
  else
    echo "  FAIL: $label"
    echo "    expected to contain: $needle"
    echo "    actual output (last 25 lines):"
    printf '%s\n' "$haystack" | tail -25 | sed 's/^/      /'
    FAIL=$((FAIL+1))
  fi
}

assert_not_contains() {
  local label="$1" haystack="$2" needle="$3"
  if printf '%s' "$haystack" | grep -qF -- "$needle"; then
    echo "  FAIL: $label"
    echo "    expected NOT to contain: $needle"
    echo "    actual output (last 25 lines):"
    printf '%s\n' "$haystack" | tail -25 | sed 's/^/      /'
    FAIL=$((FAIL+1))
  else
    echo "  PASS: $label"
    PASS=$((PASS+1))
  fi
}

# Build a minimal project tree with an OLD contract-version stamp.
# Args: $1 = root, $2 = stamp version, $3 = engine/VERSION value
make_min_project() {
  local root="$1" stamp="$2" ver="$3"
  mkdir -p "$root/engine/tasks"
  printf '%s\n' "$ver" > "$root/engine/VERSION"
  cat > "$root/engine/ENGINE_MAP.md" <<'EOF'
# Engine Map
| File | Purpose |
|------|---------|
| ENGINE_MAP.md | TOC |
EOF
  cat > "$root/AGENTS.md" <<EOF
<!-- ENGINE_SYSTEM_CONTRACT_MIGRATIONS_START -->
<!-- contract-version: $stamp -->
## Engine System Current Contract
> Managed by Engine System contract migration.

old content
<!-- ENGINE_SYSTEM_CONTRACT_MIGRATIONS_END -->
EOF
}

# --- S1: bump scenario (OLD=6.16.0 -> NEW=6.17.2) with an active card ---
echo "=== S1: bump scenario (OLD=6.16.0 -> NEW=6.17.2) + active card T-999 ==="
TMPDIR_S1="$(mktemp -d)"
make_min_project "$TMPDIR_S1" "6.16.0" "6.17.2"
cat > "$TMPDIR_S1/engine/tasks/T-999.md" <<'EOF'
# T-999: test active card
> status: active | lane: test | decision: none | plan: none | domain: test
GOAL: test bump prompt listing
EOF

OUTPUT_S1="$(env -u CLAUDE_PROJECT_DIR bash "$MIGRATOR" "$TMPDIR_S1" 2>&1 || true)"
assert_contains "S1: bump prompt fires" "$OUTPUT_S1" "contract-version bumped: 6.16.0 -> 6.17.2"
assert_contains "S1: lists active card T-999" "$OUTPUT_S1" "T-999.md"
assert_contains "S1: review guidance text" "$OUTPUT_S1" "Please review active/paused task cards"

# --- S2: idempotent repair (OLD=6.17.2 == NEW=6.17.2) ---
# Reuse S1's post-migration tree: all 3 managed blocks now stamped 6.17.2 with
# the current session/doctor protocol body, so upsert reports "current" for all
# 3 files -> TOUCHED empty -> "already current" exit -> prompt silent.
echo "=== S2: idempotent repair (OLD=6.17.2 == NEW=6.17.2) ==="
TMPDIR_S2="$(mktemp -d)"
mkdir -p "$TMPDIR_S2/engine/tasks"
cp "$TMPDIR_S1/engine/VERSION" "$TMPDIR_S2/engine/VERSION"
cp "$TMPDIR_S1/engine/ENGINE_MAP.md" "$TMPDIR_S2/engine/ENGINE_MAP.md"
cp "$TMPDIR_S1/AGENTS.md" "$TMPDIR_S2/AGENTS.md"
cp "$TMPDIR_S1/engine/SYSTEM.md" "$TMPDIR_S2/engine/SYSTEM.md"
cp "$TMPDIR_S1/engine/ENGINE_DOCTOR.md" "$TMPDIR_S2/engine/ENGINE_DOCTOR.md"

OUTPUT_S2="$(env -u CLAUDE_PROJECT_DIR bash "$MIGRATOR" "$TMPDIR_S2" 2>&1 || true)"
assert_not_contains "S2: no bump prompt on idempotent repair" "$OUTPUT_S2" "contract-version bumped"
assert_contains "S2: reports already current" "$OUTPUT_S2" "already current"

# --- S3: bump with no active cards -> prompt fires + "No active/paused task cards found." ---
echo "=== S3: bump (OLD=6.16.0 -> NEW=6.17.2) with no active cards ==="
TMPDIR_S3="$(mktemp -d)"
make_min_project "$TMPDIR_S3" "6.16.0" "6.17.2"
# engine/tasks dir exists but empty (no T-*.md cards)

OUTPUT_S3="$(env -u CLAUDE_PROJECT_DIR bash "$MIGRATOR" "$TMPDIR_S3" 2>&1 || true)"
assert_contains "S3: bump prompt fires" "$OUTPUT_S3" "contract-version bumped: 6.16.0 -> 6.17.2"
assert_contains "S3: reports no active cards" "$OUTPUT_S3" "No active/paused task cards found."

# --- S4 (regression): fresh install (no prior managed block) ---
# Reproduces the I6 install-test bug: a project tree with AGENTS.md present but
# WITHOUT a prior contract-version stamp. The OLD_CONTRACT_VERSION capture loop
# must not crash on grep-no-match (set -euo pipefail). Migrator should succeed,
# write the stamp, and NOT fire the bump prompt (OLD is empty -> no bump).
echo "=== S4: fresh install (no prior managed block) -> no prompt, stamp written ==="
TMPDIR_S4="$(mktemp -d)"
mkdir -p "$TMPDIR_S4/engine/tasks"
printf '6.17.2\n' > "$TMPDIR_S4/engine/VERSION"
cat > "$TMPDIR_S4/engine/ENGINE_MAP.md" <<'EOF'
# Engine Map
| File | Purpose |
|------|---------|
| ENGINE_MAP.md | TOC |
EOF
# AGENTS.md exists but has NO managed block (fresh install state)
printf '# Project Agents\nThin bootloader.\n' > "$TMPDIR_S4/AGENTS.md"

OUTPUT_S4="$(env -u CLAUDE_PROJECT_DIR bash "$MIGRATOR" "$TMPDIR_S4" 2>&1 || true)"
assert_not_contains "S4: no bump prompt on fresh install" "$OUTPUT_S4" "contract-version bumped"
assert_contains "S4: migrator wrote stamp to AGENTS.md" "$(grep -o 'contract-version: 6.17.2' "$TMPDIR_S4/AGENTS.md" 2>/dev/null || echo MISSING)" "contract-version: 6.17.2"

echo ""
echo "=== Summary: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
