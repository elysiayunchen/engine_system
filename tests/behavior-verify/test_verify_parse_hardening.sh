#!/usr/bin/env bash
# T-049 (issue #11 A-2/A-3): verify command extraction anchored to the first
# pipe separator (a command containing the literal 'verify:' is not truncated),
# and AC ids may carry letter groups (AC-A1) or dotted numerics (AC-1.2).

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

echo "=== verify parse hardening (bash) ==="

# H1: verify command containing the literal 'verify:' runs in full.
# The command greps this very card for AC declaration lines; with the old
# greedy match the extracted command became a fragment and exited 2.
r="$(new_fixture)"
cat > "$r/engine/tasks/T-910.md" <<'EOF'
# T-910
> status: active | lane: t | decision: none | domain: root
GOAL: meta AC
WRITE-SET: src/**
AC: AC-1 declarations exist | verify: grep -qE 'AC: AC-[0-9]+ .*[|] verify:' engine/tasks/T-910.md
EOF
rc=0
CLAUDE_PROJECT_DIR="$r" bash "$VERIFY_SH" T-910 >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 0 ]; then ok "H1a meta-AC with literal 'verify:' passes"; else bad "H1a exit=$rc"; fi
if grep -q '"exit":0' "$r/engine/evidence/T-910/AC-1.json" 2>/dev/null; then ok "H1b evidence exit=0"; else bad "H1b evidence: $(cat "$r/engine/evidence/T-910/AC-1.json" 2>/dev/null | head -c 160)"; fi

# H2: letter-grouped AC id (AC-A1) is recognized and produces AC-A1.json
r="$(new_fixture)"
cat > "$r/engine/tasks/T-911.md" <<'EOF'
# T-911
> status: active | lane: t | decision: none | domain: root
GOAL: letter groups
WRITE-SET: src/**
AC: AC-A1 first group | verify: true
AC: AC-B12 second group | verify: true
EOF
rc=0
CLAUDE_PROJECT_DIR="$r" bash "$VERIFY_SH" T-911 >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 0 ] && [ -f "$r/engine/evidence/T-911/AC-A1.json" ] && [ -f "$r/engine/evidence/T-911/AC-B12.json" ]; then
  ok "H2 letter-grouped ids recognized (AC-A1, AC-B12)"
else
  bad "H2 exit=$rc files=$(ls "$r/engine/evidence/T-911/" 2>/dev/null | tr '\n' ' ')"
fi

# H2b: legacy arrow separator still parses
r="$(new_fixture)"
cat > "$r/engine/tasks/T-913.md" <<'EOF'
# T-913
> status: active | lane: t | decision: none | domain: root
GOAL: arrow separator
WRITE-SET: src/**
AC: AC-1 arrow form → verify: true
EOF
rc=0
CLAUDE_PROJECT_DIR="$r" bash "$VERIFY_SH" T-913 >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 0 ] && [ -f "$r/engine/evidence/T-913/AC-1.json" ]; then ok "H2b arrow separator parses"; else bad "H2b exit=$rc"; fi

# H3: dotted id (AC-1.2) still recognized
r="$(new_fixture)"
cat > "$r/engine/tasks/T-912.md" <<'EOF'
# T-912
> status: active | lane: t | decision: none | domain: root
GOAL: dotted ids
WRITE-SET: src/**
AC: AC-1.2 dotted | verify: true
EOF
rc=0
CLAUDE_PROJECT_DIR="$r" bash "$VERIFY_SH" T-912 >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 0 ] && [ -f "$r/engine/evidence/T-912/AC-1.2.json" ]; then ok "H3 dotted id recognized"; else bad "H3 exit=$rc"; fi

echo ""
echo "verify_parse_hardening result: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
