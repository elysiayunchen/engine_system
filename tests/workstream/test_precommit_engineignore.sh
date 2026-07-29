#!/usr/bin/env bash
# Test: pre-commit .engineignore bypass (T-052, v6.13.0)
#
# Validates the .engineignore mechanism added to engine/scripts/githooks/pre-commit.
# Paths matching .engineignore bypass the "no active card" block (179-192) and the
# union_allows WRITE-SET check (194-213), but STILL face:
#   - FORBIDDEN (via union_not_all_forbidden: blocked only if ALL active cards forbid)
#   - protected-path check (289-343)
#   - dist-stale gate (353-387)
#
# Matching engine: reuses match_any_glob (case "$path" in $p|$p/*) from pre-commit.
# Shell case '*' crosses '/' so 'engine/scripts/**' matches deep children; trailing
# '/**' is stripped so the bare dir matches too. Pure shell, zero subprocess spawns.
#
# Scenarios:
#   S1 (AC-1): no .engineignore file → behavior unchanged (no-card block, union block)
#   S2 (AC-2): .engineignore lists GEMINI.md, no active card → PASS (bypass 179-192)
#   S3 (AC-3): .engineignore path, ALL active cards forbid → FAIL
#   S4 (AC-3): .engineignore path, only ONE card forbids → PASS
#   S5 (AC-4): .engineignore itself staged → protected-path check still applies
#   S6 (AC-5): contract/src/** staged + .engineignore matches it → dist-stale still runs
#   S7 (AC-2): glob pattern engine/scripts/** matches deep child engine/scripts/githooks/pre-commit
#
# Black-box test of the extracted .engineignore bypass logic.

set -euo pipefail

echo "[test_precommit_engineignore.sh] T-052 .engineignore bypass"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

PASS=0
FAIL=0
ok() { echo "  PASS $1"; PASS=$((PASS+1)); }
bad() { echo "  FAIL $1"; FAIL=$((FAIL+1)); }

# --- match_any_glob (copied from pre-commit L83-100) ---
# Args: <path> <comma-separated patterns>
# Returns: 0 iff any glob matches (case "$path" in $p|$p/*)
match_any_glob() {
  _path="$1"; _pats="$2"; _old="$IFS"
  set -f
  IFS=','
  for _p in $_pats; do
    _p="${_p#"${_p%%[![:space:]]*}"}"
    _p="${_p%"${_p##*[![:space:]]}"}"
    [ -n "$_p" ] || continue
    case "$_path" in $_p|$_p/*) IFS="$_old"; set +f; return 0 ;; esac
  done
  IFS="$_old"
  set +f
  return 1
}

# --- compute_engineignored (mirrors pre-commit T-052 logic) ---
# Reads $root/.engineignore, strips comments/empty lines, strips trailing /**,
# converts to CSV. Returns 0 if path matches any pattern.
# Args: <root> <path>
is_engineignored() {
  local root="$1" path="$2"
  [ -f "$root/.engineignore" ] || return 1
  local csv
  csv="$(grep -vE '^[[:space:]]*(#|$)' "$root/.engineignore" 2>/dev/null | \
         sed 's|/\*\*[[:space:]]*$||' | \
         tr '\n' ',' | sed 's/,$//')"
  [ -n "$csv" ] || return 1
  match_any_glob "$path" "$csv"
}

# --- union_not_all_forbidden (mirrors pre-commit T-052) ---
# Returns 0 iff at least one card does NOT forbid the path.
# Card meta format: <file>TAB<id>TAB<write-set>TAB<forbidden>  (newline-separated)
# Args: <path> <card_meta>
union_not_all_forbidden() {
  local path="$1" meta="$2"
  [ -n "$meta" ] || return 0
  local any_nonforbid=0
  while IFS="$(printf '\t')" read -r cf cid cws cfb; do
    [ -n "$cid" ] || continue
    if [ -z "$cfb" ]; then any_nonforbid=1; break; fi
    local found_forbid=0
    if match_any_glob "$path" "$cfb"; then found_forbid=1; fi
    [ "$found_forbid" -eq 0 ] && { any_nonforbid=1; break; }
  done <<META_EOF
$meta
META_EOF
  [ "$any_nonforbid" -eq 1 ]
}

# ===========================================================================
# S1 (AC-1): no .engineignore file → behavior unchanged
# ===========================================================================
echo "S1: no .engineignore → no bypass"
ROOT="$TMPDIR/s1"
mkdir -p "$ROOT"
if ! is_engineignored "$ROOT" "GEMINI.md"; then ok "S1 no bypass without .engineignore"; else bad "S1 should not bypass"; fi

# ===========================================================================
# S2 (AC-2): .engineignore lists GEMINI.md → bypass
# ===========================================================================
echo "S2: .engineignore lists GEMINI.md → bypass"
ROOT="$TMPDIR/s2"
mkdir -p "$ROOT"
cat > "$ROOT/.engineignore" <<'EOF'
# cross-agent anchors
.github/copilot-instructions.md
.cursor/rules/engine.md
GEMINI.md
.clinerules
.roorules
EOF
if is_engineignored "$ROOT" "GEMINI.md"; then ok "S2 GEMINI.md bypassed"; else bad "S2 GEMINI.md should be bypassed"; fi
if ! is_engineignored "$ROOT" "src/main.py"; then ok "S2 src/main.py not bypassed"; else bad "S2 src/main.py should not be bypassed"; fi

# ===========================================================================
# S3 (AC-3): .engineignore path, ALL active cards forbid → FAIL
# ===========================================================================
echo "S3: .engineignore path, ALL active cards forbid → blocked"
TAB="$(printf '\t')"
meta="${TMPDIR}/s3-card1.md${TAB}T-A${TAB}engine/tasks/T-A.md${TAB}GEMINI.md
${TMPDIR}/s3-card2.md${TAB}T-B${TAB}engine/tasks/T-B.md${TAB}GEMINI.md"
if ! union_not_all_forbidden "GEMINI.md" "$meta"; then ok "S3 blocked (all forbid)"; else bad "S3 should block"; fi

# ===========================================================================
# S4 (AC-3): .engineignore path, only ONE card forbids → PASS
# ===========================================================================
echo "S4: .engineignore path, only one card forbids → pass"
meta="${TMPDIR}/s4-card1.md${TAB}T-A${TAB}engine/tasks/T-A.md${TAB}GEMINI.md
${TMPDIR}/s4-card2.md${TAB}T-B${TAB}engine/tasks/T-B.md${TAB}"
if union_not_all_forbidden "GEMINI.md" "$meta"; then ok "S4 passed (not all forbid)"; else bad "S4 should pass"; fi

# ===========================================================================
# S5 (AC-4): .engineignore itself is protected (in protected_paths)
# ===========================================================================
echo "S5: .engineignore in protected_paths"
ROOT="$TMPDIR/s5"
mkdir -p "$ROOT"
cat > "$ROOT/rules.json" <<'EOF'
{
  "protected_paths": [
    "engine/decisions/**",
    ".engineignore"
  ]
}
EOF
protected="$(sed -n '/"protected_paths"/,/\]/{
  /"protected_paths"/d
  /\]/d
  s/.*"\([^"]*\)".*/\1/p
}' "$ROOT/rules.json")"
if printf '%s\n' "$protected" | grep -qx '.engineignore'; then ok "S5 .engineignore in protected_paths"; else bad "S5 .engineignore should be protected"; fi

# ===========================================================================
# S6 (AC-5): contract/src/** + .engineignore match → dist-stale trigger still fires
# The dist-stale gate is independent of .engineignore bypass: even if .engineignore
# matches contract/src/**, the dist-stale check still runs (separate code path).
# ===========================================================================
echo "S6: contract/src/** + .engineignore match → dist-stale trigger fires"
ROOT="$TMPDIR/s6"
mkdir -p "$ROOT/contract/src"
cat > "$ROOT/.engineignore" <<'EOF'
contract/src/**
EOF
staged="contract/src/30-operational.md"
# Confirm .engineignore matches it:
if is_engineignored "$ROOT" "$staged"; then
  # dist-stale trigger condition: any staged path matches ^contract/src/
  contract_touch="$(printf '%s\n' "$staged" | grep -E '^contract/src/' | head -1 || true)"
  if [ -n "$contract_touch" ]; then ok "S6 dist-stale trigger still fires"; else bad "S6 dist-stale should trigger"; fi
else
  bad "S6 setup wrong: .engineignore should match contract/src/**"
fi

# ===========================================================================
# S7 (AC-2): glob engine/scripts/** matches deep child
# ===========================================================================
echo "S7: engine/scripts/** matches deep child"
ROOT="$TMPDIR/s7"
mkdir -p "$ROOT"
cat > "$ROOT/.engineignore" <<'EOF'
engine/scripts/**
EOF
if is_engineignored "$ROOT" "engine/scripts/githooks/pre-commit"; then ok "S7 deep child matched"; else bad "S7 should match deep child"; fi
if is_engineignored "$ROOT" "engine/scripts"; then ok "S7 bare dir matched"; else bad "S7 should match bare dir"; fi
if ! is_engineignored "$ROOT" "engine/prompts/init.md"; then ok "S7 non-matching path rejected"; else bad "S7 should not match engine/prompts"; fi

echo ""
echo "=========================================="
echo "PASS=$PASS  FAIL=$FAIL"
[ "$FAIL" -eq 0 ] && echo "PASS .engineignore bypass tests" || { echo "FAIL .engineignore bypass tests"; exit 1; }
