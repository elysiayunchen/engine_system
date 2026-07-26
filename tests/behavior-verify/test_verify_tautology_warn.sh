#!/usr/bin/env bash
# T-049 (issue #11 E-1): tautology heuristics.
# - A verify command referencing the card's OWN evidence directory gets a
#   per-AC WARN (it proves a file was written, not that behavior happened).
# - When every PASS fingerprint is the empty-string sha256, a summary WARN
#   flags likely tautologies. WARNs never change the exit code.

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

echo "=== verify tautology warnings (bash) ==="

# W1: self-referential evidence path -> per-AC WARN, exit still 0
r="$(new_fixture)"
mkdir -p "$r/engine/evidence/T-920"
echo x > "$r/engine/evidence/T-920/AC-1.md"
cat > "$r/engine/tasks/T-920.md" <<'EOF'
# T-920
> status: active | lane: t | decision: none | domain: root
GOAL: self referential
WRITE-SET: src/**
AC: AC-1 implementer wrote a file | verify: test -f engine/evidence/T-920/AC-1.md
EOF
rc=0
out="$(CLAUDE_PROJECT_DIR="$r" bash "$VERIFY_SH" T-920 2>&1)" || rc=$?
if printf '%s' "$out" | grep -q "suspicious verify (self-referential evidence path): AC-1"; then ok "W1a self-referential WARN emitted"; else bad "W1a WARN missing: ${out:0:160}"; fi
if [ "$rc" -eq 0 ]; then ok "W1b exit still 0 (WARN only)"; else bad "W1b exit=$rc"; fi

# W2: all PASS fingerprints empty-string hash -> summary WARN
r="$(new_fixture)"
cat > "$r/engine/tasks/T-921.md" <<'EOF'
# T-921
> status: active | lane: t | decision: none | domain: root
GOAL: silent commands
WRITE-SET: src/**
AC: AC-1 silent | verify: true
AC: AC-2 silent too | verify: test 1 -eq 1
EOF
rc=0
out="$(CLAUDE_PROJECT_DIR="$r" bash "$VERIFY_SH" T-921 2>&1)" || rc=$?
if printf '%s' "$out" | grep -q "empty-string hash"; then ok "W2a all-empty-fp summary WARN"; else bad "W2a WARN missing"; fi
if [ "$rc" -eq 0 ]; then ok "W2b exit still 0"; else bad "W2b exit=$rc"; fi

# W3: card with real output -> no WARNs
r="$(new_fixture)"
cat > "$r/engine/tasks/T-922.md" <<'EOF'
# T-922
> status: active | lane: t | decision: none | domain: root
GOAL: honest card
WRITE-SET: src/**
AC: AC-1 produces output | verify: echo checked
EOF
rc=0
out="$(CLAUDE_PROJECT_DIR="$r" bash "$VERIFY_SH" T-922 2>&1)" || rc=$?
if ! printf '%s' "$out" | grep -q "WARN"; then ok "W3 honest card has no WARN"; else bad "W3 unexpected WARN: $(printf '%s' "$out" | grep WARN | head -1)"; fi

echo ""
echo "verify_tautology_warn result: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
