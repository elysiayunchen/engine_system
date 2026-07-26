#!/usr/bin/env bash
# T-049 AC-6 (issue #11 D-1): the contract migrator reads engine/VERSION first.
# Downstream product repos ship their own root VERSION (the PRODUCT version);
# preferring it stamped e.g. contract-version 3.0.0 into managed blocks and
# silently degraded every versioned Doctor gate to the migration grace period.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
MIGRATE_SH="$REPO_ROOT/plugin/engine/scripts/engine-migrate-contract.sh"

pass=0
fail=0
ok() { echo "PASS  $1"; pass=$((pass + 1)); }
bad() { echo "FAIL  $1"; fail=$((fail + 1)); }

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

new_fixture() {
  d="$(mktemp -d "$TMP_ROOT/repo.XXXXXX")"
  git -C "$d" init -q
  git -C "$d" config user.email mv@test
  git -C "$d" config user.name mv
  git -C "$d" config commit.gpgsign false
  mkdir -p "$d/engine"
  printf '# map\n\n| Active profile | CLI-LEAN |\n' > "$d/engine/ENGINE_MAP.md"
  printf '%s\n' "$d"
}

echo "=== migrator contract-version source (bash) ==="

# V1: product repo shape - root VERSION is the PRODUCT version, engine/VERSION
# is the toolchain version. The stamp must use engine/VERSION.
r="$(new_fixture)"
printf '3.0.0' > "$r/VERSION"
printf '6.12.1' > "$r/engine/VERSION"
( cd "$r" && bash "$MIGRATE_SH" ) >/dev/null 2>&1 || true
if grep -q 'contract-version: 6.12.1' "$r/AGENTS.md" 2>/dev/null; then
  ok "V1 engine/VERSION wins over product root VERSION"
else
  bad "V1 stamped: $(grep -o 'contract-version: [0-9.]*' "$r/AGENTS.md" 2>/dev/null | head -1)"
fi

# V2: no engine/VERSION - falls back to root VERSION
r2="$(new_fixture)"
printf '6.11.8' > "$r2/VERSION"
( cd "$r2" && bash "$MIGRATE_SH" ) >/dev/null 2>&1 || true
if grep -q 'contract-version: 6.11.8' "$r2/AGENTS.md" 2>/dev/null; then
  ok "V2 root VERSION fallback"
else
  bad "V2 stamped: $(grep -o 'contract-version: [0-9.]*' "$r2/AGENTS.md" 2>/dev/null | head -1)"
fi

# V3: neither file - falls back to 6.0.0
r3="$(new_fixture)"
( cd "$r3" && bash "$MIGRATE_SH" ) >/dev/null 2>&1 || true
if grep -q 'contract-version: 6.0.0' "$r3/AGENTS.md" 2>/dev/null; then
  ok "V3 6.0.0 default fallback"
else
  bad "V3 stamped: $(grep -o 'contract-version: [0-9.]*' "$r3/AGENTS.md" 2>/dev/null | head -1)"
fi

echo ""
echo "migrator_version_source result: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
