#!/usr/bin/env bash
# Test: pre-commit dist-stale gate (T-051, v6.12.3)
#
# Validates the dist-stale gate added to engine/scripts/githooks/pre-commit.
# The gate runs compile.sh to a temp dir and diffs 6 dist files against the
# working tree when any contract/src/** or dist file is staged.
#
# Scenarios:
#   S1 (AC-2): source changed, compile.sh not run → FAIL
#   S2 (AC-3): dist edited directly (mismatch) → FAIL
#   S3 (AC-4): source changed + compile.sh run → PASS
#   S4 (AC-1): no contract files staged → PASS (skip)
#   S5 (AC-5): compile.sh fails → PASS (fail-open WARN)
#
# Black-box test of the extracted dist-stale check logic.

set -euo pipefail

echo "[test_precommit_dist_stale.sh] T-051 dist-stale pre-commit gate"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

# --- Setup: minimal contract structure ---
ROOT="$TMPDIR"
mkdir -p "$ROOT/contract/src"
mkdir -p "$ROOT/plugin/.claude/commands"
mkdir -p "$ROOT/engine/prompts"
mkdir -p "$ROOT/plugin/engine/prompts"

# Source file
cat > "$ROOT/contract/src/30-operational.md" <<'EOF'
# Operational
## Multi-session
tombstone lifecycle here
EOF

# Fake compile.sh: concatenates banner + src into dist files
cat > "$ROOT/contract/compile.sh" <<'COMPILE'
#!/bin/sh
set -e
OUT="${ENGINE_COMPILE_OUT:-$(dirname "$0")/..}"
SRC="$(dirname "$0")/src"
mkdir -p "$OUT/plugin/.claude/commands" "$OUT/engine/prompts" "$OUT/plugin/engine/prompts"
{
  printf '<!-- banner -->\n'
  cat "$SRC"/*.md
} > "$OUT/ENGINE_FILE_SYSTEM_v5.md"
cp "$SRC/30-operational.md" "$OUT/engine/prompts/init.md"
cp "$OUT/engine/prompts/init.md" "$OUT/plugin/engine/prompts/init.md"
printf 'cli\n' > "$OUT/plugin/.claude/commands/engine-init.md"
printf '{}\n' > "$OUT/rules.json"
printf 'law\n' > "$OUT/runtime-law.md"
COMPILE
chmod +x "$ROOT/contract/compile.sh"

# Generate initial dist files
ENGINE_COMPILE_OUT="$ROOT" bash "$ROOT/contract/compile.sh" >/dev/null 2>&1

# --- Extracted dist-stale check logic (mirrors pre-commit T-051 block) ---
# Args: <root> <staged_newline_separated>
# Returns: 0 = pass, 1 = fail (stale), 2 = warn (compile failed)
dist_stale_check() {
  local root="$1" staged="$2"
  local contract_touch tmpcompile stale df compiled_file real_file
  contract_touch="$(printf '%s\n' "$staged" | grep -E '^contract/src/|^(ENGINE_FILE_SYSTEM_v5\.md|runtime-law\.md|rules\.json|plugin/\.claude/commands/engine-init\.md|engine/prompts/init\.md|plugin/engine/prompts/init\.md)$' | head -1 || true)"
  [ -n "$contract_touch" ] || return 0
  [ -f "$root/contract/compile.sh" ] || return 0
  tmpcompile="$(mktemp -d 2>/dev/null || mktemp -d -t engcompile)"
  if ENGINE_COMPILE_OUT="$tmpcompile" bash "$root/contract/compile.sh" >/dev/null 2>&1; then
    stale=""
    for df in \
      ENGINE_FILE_SYSTEM_v5.md \
      runtime-law.md \
      rules.json \
      plugin/.claude/commands/engine-init.md \
      engine/prompts/init.md \
      plugin/engine/prompts/init.md
    do
      compiled_file="$tmpcompile/$df"
      real_file="$root/$df"
      if [ -f "$compiled_file" ] && [ -f "$real_file" ]; then
        if ! diff -q "$compiled_file" "$real_file" >/dev/null 2>&1; then
          stale="${stale}${stale:+, }$df"
        fi
      fi
    done
    rm -rf "$tmpcompile"
    [ -n "$stale" ] && return 1
    return 0
  else
    rm -rf "$tmpcompile"
    return 2
  fi
}

PASS=0
FAIL=0
ok() { echo "  PASS $1"; PASS=$((PASS+1)); }
bad() { echo "  FAIL $1"; FAIL=$((FAIL+1)); }

# --- S1 (AC-2): source changed, compile.sh not run → FAIL ---
echo "S1: source changed, compile.sh not run (dist stale)"
echo "tombstone lifecycle CHANGED" >> "$ROOT/contract/src/30-operational.md"
rc=0; dist_stale_check "$ROOT" "contract/src/30-operational.md" || rc=$?
if [ "$rc" -eq 1 ]; then ok "S1 blocks stale dist"; else bad "S1 should block (rc=$rc)"; fi
# Restore: regenerate dist
ENGINE_COMPILE_OUT="$ROOT" bash "$ROOT/contract/compile.sh" >/dev/null 2>&1

# --- S2 (AC-3): dist edited directly (mismatch) → FAIL ---
echo "S2: dist edited directly (mismatch compile(src))"
echo "HAND EDITED" >> "$ROOT/ENGINE_FILE_SYSTEM_v5.md"
rc=0; dist_stale_check "$ROOT" "ENGINE_FILE_SYSTEM_v5.md" || rc=$?
if [ "$rc" -eq 1 ]; then ok "S2 blocks direct dist edit"; else bad "S2 should block (rc=$rc)"; fi
# Restore: regenerate dist
ENGINE_COMPILE_OUT="$ROOT" bash "$ROOT/contract/compile.sh" >/dev/null 2>&1

# --- S3 (AC-4): source changed + compile.sh run → PASS ---
echo "S3: source changed + compile.sh run (dist matches)"
echo "more content" >> "$ROOT/contract/src/30-operational.md"
ENGINE_COMPILE_OUT="$ROOT" bash "$ROOT/contract/compile.sh" >/dev/null 2>&1
rc=0; dist_stale_check "$ROOT" "contract/src/30-operational.md" || rc=$?
if [ "$rc" -eq 0 ]; then ok "S3 passes fresh dist"; else bad "S3 should pass (rc=$rc)"; fi

# --- S4 (AC-1): no contract files staged → PASS (skip) ---
echo "S4: no contract files staged (skip)"
rc=0; dist_stale_check "$ROOT" "engine/CONTEXT.md" || rc=$?
if [ "$rc" -eq 0 ]; then ok "S4 skips non-contract files"; else bad "S4 should skip (rc=$rc)"; fi

# --- S5 (AC-5): compile.sh fails → PASS (fail-open WARN) ---
echo "S5: compile.sh fails (fail-open WARN)"
cat > "$ROOT/contract/compile.sh" <<'COMPILE'
#!/bin/sh
exit 1
COMPILE
chmod +x "$ROOT/contract/compile.sh"
rc=0; dist_stale_check "$ROOT" "contract/src/30-operational.md" || rc=$?
if [ "$rc" -eq 2 ]; then ok "S5 warn on compile failure"; else bad "S5 should warn (rc=$rc)"; fi

echo ""
echo "=========================================="
echo "PASS=$PASS  FAIL=$FAIL"
[ "$FAIL" -eq 0 ] && echo "PASS dist-stale gate tests" || { echo "FAIL dist-stale gate tests"; exit 1; }
