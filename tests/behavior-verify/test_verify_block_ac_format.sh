#!/usr/bin/env bash
# Regression test for issue #13 / D-037: all four supported AC declaration
# shapes must reach the behavior verifier, not just the legacy one-line form.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/engine-ac-formats.XXXXXX")"
cleanup() { rm -rf "$fixture"; }
trap cleanup EXIT

mkdir -p "$fixture/engine/tasks" "$fixture/engine/evidence" "$fixture/src"
git -C "$fixture" init -q
git -C "$fixture" config user.email test@example.invalid
git -C "$fixture" config user.name "Engine Test"
printf '%s\n' 'fixture' > "$fixture/src/fixture.txt"
cat > "$fixture/engine/tasks/T-901.md" <<'CARD'
status: active

## WRITE-SET
- src/fixture.txt

## FORBIDDEN
- never

## AC
AC: AC-1 one-line declaration | verify: true

### AC-2: section declaration
verify: true

- AC-3: list declaration | verify: true

| AC-4 | table declaration | verify: true |
CARD
git -C "$fixture" add .
git -C "$fixture" commit -q -m fixture

CLAUDE_PROJECT_DIR="$fixture" bash "$REPO_ROOT/engine/scripts/engine-verify.sh" T-901 --preflight > "$fixture/verify.log" 2>&1

for ac in AC-1 AC-2 AC-3 AC-4; do
  evidence="$fixture/engine/evidence/T-901/$ac.json"
  test -f "$evidence"
  grep -Eiq '"status"[[:space:]]*:[[:space:]]*"pass"' "$evidence"
done

count="$(find "$fixture/engine/evidence/T-901" -maxdepth 1 -type f -name 'AC-*.json' | wc -l | tr -d ' ')"
test "$count" = 4
echo "PASS test_verify_block_ac_format.sh"
