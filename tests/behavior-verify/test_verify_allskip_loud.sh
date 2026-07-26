#!/usr/bin/env bash
# T-049 (issue #11 A-1): all-SKIP is a parse failure, not a clean result.
# When a card declares ACs but none yields a parseable verify command,
# engine-verify must exit 3 with an explicit parse-failure message instead of
# printing "0 pass, 0 fail, N skip" and exiting 0.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
VERIFY_SH="$REPO_ROOT/engine/scripts/engine-verify.sh"

pass=0
fail=0
ok() { echo "PASS  $1"; pass=$((pass + 1)); }
bad() { echo "FAIL  $1"; fail=$((fail + 1)); }

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

new_fixture() {
  d="$(mktemp -d "$TMP_ROOT/repo.XXXXXX")"
  mkdir -p "$d/engine/tasks"
  printf '%s\n' "$d"
}

echo "=== verify all-SKIP loud failure (bash) ==="

# L1: card with 2 ACs, none has an inline verify command (split/block form) -> exit 3 + message
r="$(new_fixture)"
cat > "$r/engine/tasks/T-900.md" <<'EOF'
# T-900
> status: active | lane: t | decision: none | domain: root
GOAL: split form card
WRITE-SET: src/**
AC: AC-1
AC: AC-2

### AC-1 Some criterion
**verify**: (block form, not parseable by single-line reader)
EOF
rc=0
out="$(CLAUDE_PROJECT_DIR="$r" bash "$VERIFY_SH" T-900 2>&1)" || rc=$?
if [ "$rc" -eq 3 ]; then ok "L1a all-SKIP exits 3"; else bad "L1a exit=$rc (expected 3)"; fi
if printf '%s' "$out" | grep -q "parse failure"; then ok "L1b message names parse failure"; else bad "L1b message missing: ${out:0:120}"; fi

# L2: normal single-line card -> pass, exit 0
r="$(new_fixture)"
cat > "$r/engine/tasks/T-901.md" <<'EOF'
# T-901
> status: active | lane: t | decision: none | domain: root
GOAL: normal card
WRITE-SET: src/**
AC: AC-1 works | verify: true
EOF
rc=0
CLAUDE_PROJECT_DIR="$r" bash "$VERIFY_SH" T-901 >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 0 ]; then ok "L2 normal card exits 0"; else bad "L2 exit=$rc"; fi
if grep -q '"status":"pass"' "$r/engine/evidence/T-901/AC-1.json" 2>/dev/null; then ok "L2b evidence written"; else bad "L2b evidence missing"; fi

# L3: mixed card (one parseable, one not) -> NOT a loud failure (exit 0, 1 pass 1 skip)
r="$(new_fixture)"
cat > "$r/engine/tasks/T-902.md" <<'EOF'
# T-902
> status: active | lane: t | decision: none | domain: root
GOAL: mixed card
WRITE-SET: src/**
AC: AC-1 works | verify: true
AC: AC-2
EOF
rc=0
out="$(CLAUDE_PROJECT_DIR="$r" bash "$VERIFY_SH" T-902 2>&1)" || rc=$?
if [ "$rc" -eq 0 ]; then ok "L3a mixed card exits 0"; else bad "L3a exit=$rc"; fi
if printf '%s' "$out" | grep -q "1 pass, 0 fail, 1 skip"; then ok "L3b counts intact"; else bad "L3b counts: $(printf '%s' "$out" | tail -1)"; fi

echo ""
echo "verify_allskip_loud result: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
