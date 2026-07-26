#!/usr/bin/env bash
# T-049 AC-7 (issue #11 D-2/E-2/C-1 + doctor arg hardening): gates say so
# explicitly when they cannot determine an answer.
#
#   1. fresh worktree / empty env: no unbound-variable crash on CI vars (E-2)
#   2. unknown --flag: loud error exit 2, not silently treated as ROOT
#   3. project without INVENTORY: explicit "not initialized" SKIP line (D-2)
#   4. done card whose PROSE quotes 'status:.*active': not treated as active (C-1)
#   5. card with both anchored active and done lines: conflict FAIL (C-1)

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
DOCTOR_SH="$REPO_ROOT/plugin/engine/scripts/engine-doctor.sh"

pass=0
fail=0
ok() { echo "PASS  $1"; pass=$((pass + 1)); }
bad() { echo "FAIL  $1"; fail=$((fail + 1)); }

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

new_fixture() {
  d="$(mktemp -d "$TMP_ROOT/repo.XXXXXX")"
  mkdir -p "$d/engine/tasks" "$d/engine/decisions" "$d/engine/changes" "$d/engine/domains" "$d/engine/.cache/sessions"
  cat > "$d/engine/ENGINE_MAP.md" <<'EOF'
# ENGINE_MAP - index

| Active profile | `CLI-LEAN` |
|----------------|------------|

## Registry

| File | Class |
|------|-------|
| ENGINE_MAP.md | index |
EOF
  printf 'ctx\n' > "$d/engine/CONTEXT.md"
  printf '%s\n' "$d"
}

echo "=== doctor loud-skip / arg hardening / anchored status (bash) ==="

# S1: empty env (no CI / GITHUB_ACTIONS) must not crash with unbound variable
r="$(new_fixture)"
out="$(cd "$r" && env -u CI -u GITHUB_ACTIONS bash "$DOCTOR_SH" 2>&1 || true)"
if printf '%s' "$out" | grep -q 'unbound variable'; then
  bad "S1 unbound variable crash"
else
  ok "S1 no unbound-variable crash without CI vars"
fi

# S2: unknown flag -> exit 2 + loud error (not treated as ROOT)
rc=0
out="$(cd "$r" && bash "$DOCTOR_SH" --bogus-flag 2>&1)" || rc=$?
if [ "$rc" -eq 2 ] && printf '%s' "$out" | grep -q 'unknown flag'; then
  ok "S2 unknown flag fails loudly (exit=2)"
else
  bad "S2 unknown flag -> rc=$rc out=${out:0:100}"
fi

# S3: no INVENTORY files -> explicit "not initialized" line
out="$(cd "$r" && env -u CI -u GITHUB_ACTIONS bash "$DOCTOR_SH" 2>&1 || true)"
if printf '%s' "$out" | grep -q 'not initialized'; then
  ok "S3 INVENTORY absence reported as not-initialized SKIP"
else
  bad "S3 no not-initialized line"
fi

# S4: done card whose prose QUOTES the unanchored pattern is NOT active (C-1)
r2="$(new_fixture)"
cat > "$r2/engine/tasks/T-010.md" <<'EOF'
# T-010: fix hook misfire
> status: done | lane: main | decision: none | domain: root
GOAL: document the governance fix
WRITE-SET: src/**
AC: AC-1 t | verify: true
CONSTRAINTS: pre-commit hook grep 'status:.*active' misfires - governance fix note
EOF
out="$(cd "$r2" && env -u CI -u GITHUB_ACTIONS bash "$DOCTOR_SH" 2>&1 || true)"
if printf '%s' "$out" | grep -q 'T-010 (active)'; then
  bad "S4 prose-quoted pattern pinned done card active"
else
  ok "S4 anchored detection ignores prose mention"
fi

# S5: one card with BOTH anchored status lines -> conflict FAIL
r3="$(new_fixture)"
cat > "$r3/engine/tasks/T-020.md" <<'EOF'
# T-020: contradictory card
> status: active | lane: main | decision: none | domain: root
GOAL: g
WRITE-SET: src/**
AC: AC-1 t | verify: true

status: done
EOF
out="$(cd "$r3" && env -u CI -u GITHUB_ACTIONS bash "$DOCTOR_SH" 2>&1 || true)"
if printf '%s' "$out" | grep -q 'self-contradictory'; then
  ok "S5 active+done conflict reported"
else
  bad "S5 conflict not reported"
fi

echo ""
echo "doctor_loud_skip result: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
