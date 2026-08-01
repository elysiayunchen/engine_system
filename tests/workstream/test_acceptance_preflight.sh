#!/usr/bin/env bash
# T-078 / issue #25: acceptance preflight separates harness failures from behavior.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT_REPO="$(cd "$HERE/../.." && pwd)"
VERIFY_SH="$ROOT_REPO/engine/scripts/engine-verify.sh"
CLI_SH="$ROOT_REPO/engine/bin/engine"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

pass=0
fail=0

assert_rc() {
  local name="$1" expected="$2" actual="$3"
  if [ "$expected" -eq "$actual" ]; then
    echo "PASS  $name (exit=$actual)"
    pass=$((pass+1))
  else
    echo "FAIL  $name (expected exit=$expected got=$actual)"
    fail=$((fail+1))
  fi
}

assert_file_has() {
  local name="$1" file="$2" pattern="$3"
  if grep -Eq "$pattern" "$file"; then
    echo "PASS  $name"
    pass=$((pass+1))
  else
    echo "FAIL  $name (pattern not found: $pattern)"
    fail=$((fail+1))
  fi
}

assert_files_equal() {
  local name="$1" left="$2" right="$3"
  if cmp -s "$left" "$right"; then
    echo "PASS  $name"
    pass=$((pass+1))
  else
    echo "FAIL  $name ($left differs from $right)"
    fail=$((fail+1))
  fi
}

REPO="$TMP_ROOT/repo"
mkdir -p "$REPO/engine/tasks" "$REPO/engine/scripts" "$REPO/engine/bin" "$REPO/engine/evidence" "$REPO/bin"
cp "$VERIFY_SH" "$REPO/engine/scripts/engine-verify.sh"
cp "$CLI_SH" "$REPO/engine/bin/engine"
chmod +x "$REPO/engine/scripts/engine-verify.sh" "$REPO/engine/bin/engine"

cat > "$REPO/engine/tasks/T-TEST.md" <<'CARD'
# T-TEST: acceptance preflight fixture

## WRITE-SET

- src/not-yet-created.sh

## AC

AC: AC-1 coverage harness | verify: pytest -q | coverage: auto
AC: AC-2 missing dependency | verify: bash -c 'echo "ModuleNotFoundError: No module named missing" >&2; exit 1'
AC: AC-3 behavior failure | verify: bash -c 'exit 9' | behavior: bash -c 'exit 7'
AC: AC-4 no coverage policy | verify: pytest -q --no-cov | coverage: no-cov
CARD

# Deterministic pytest stand-in: the frozen command fails only because of the
# repository coverage threshold; the diagnostic command passes with --no-cov.
cat > "$REPO/bin/pytest" <<'PYTEST'
#!/usr/bin/env bash
case " $* " in
  *" --no-cov "*) echo "behavior passed"; exit 0 ;;
  *) echo "FAIL Required test coverage of 80% not reached" >&2; exit 1 ;;
esac
PYTEST
chmod +x "$REPO/bin/pytest"

export PATH="$REPO/bin:$PATH"
export CLAUDE_PROJECT_DIR="$REPO"

echo "=== acceptance preflight behavior classification ==="
OUTPUT="$TMP_ROOT/verify.out"
bash "$VERIFY_SH" T-TEST --preflight >"$OUTPUT" 2>&1
rc=$?
assert_rc "preflight returns non-zero for blocked/fail ACs" 1 "$rc"

EVIDENCE="$REPO/engine/evidence/T-TEST"
assert_file_has "coverage result is blocked" "$EVIDENCE/AC-1.json" '"status":"blocked"'
assert_file_has "coverage keeps command_exit=1" "$EVIDENCE/AC-1.json" '"command_exit":1'
assert_file_has "coverage behavior diagnostic passes" "$EVIDENCE/AC-1.json" '"behavior_exit":0'
assert_file_has "coverage failure is classified" "$EVIDENCE/AC-1.json" '"coverage_status":"failed_threshold"'
assert_file_has "coverage policy defaults to auto" "$EVIDENCE/AC-1.json" '"coverage_policy":"auto"'

assert_file_has "missing dependency is blocked" "$EVIDENCE/AC-2.json" '"status":"blocked"'
assert_file_has "missing dependency is classified" "$EVIDENCE/AC-2.json" '"environment_status":"blocked"'
if grep -q '"status":"pass"' "$EVIDENCE/AC-2.json"; then
  echo "FAIL  missing dependency cannot be PASS"
  fail=$((fail+1))
else
  echo "PASS  missing dependency cannot be PASS"
  pass=$((pass+1))
fi

assert_file_has "ordinary behavior failure remains fail" "$EVIDENCE/AC-3.json" '"status":"fail"'
assert_file_has "ordinary command exit is retained" "$EVIDENCE/AC-3.json" '"command_exit":9'
assert_file_has "ordinary behavior exit is separate" "$EVIDENCE/AC-3.json" '"behavior_exit":7'

assert_file_has "per-AC no-cov policy is recorded" "$EVIDENCE/AC-4.json" '"coverage_policy":"no-cov"'
assert_file_has "per-AC no-cov disables coverage" "$EVIDENCE/AC-4.json" '"coverage_status":"disabled"'

echo "=== CLI aliases ==="
CLI_OUTPUT="$TMP_ROOT/cli.out"
(cd "$REPO" && ./engine/bin/engine acceptance-preflight T-TEST --no-cov >"$CLI_OUTPUT" 2>&1)
cli_rc=$?
assert_rc "acceptance-preflight CLI is wired" 1 "$cli_rc"
assert_file_has "CLI --no-cov is recorded" "$EVIDENCE/AC-1.json" '"coverage_policy":"no-cov"'
assert_file_has "CLI invokes preflight mode" "$EVIDENCE/AC-1.json" '"preflight":true'

(cd "$REPO" && ./engine/bin/engine verify T-TEST --preflight >"$CLI_OUTPUT" 2>&1)
alias_rc=$?
assert_rc "verify --preflight alias is wired" 1 "$alias_rc"

echo "=== mirror parity ==="
assert_files_equal "bash engine/plugin mirror" "$ROOT_REPO/engine/scripts/engine-verify.sh" "$ROOT_REPO/plugin/engine/scripts/engine-verify.sh"
assert_files_equal "powershell engine/plugin mirror" "$ROOT_REPO/engine/scripts/engine-verify.ps1" "$ROOT_REPO/plugin/engine/scripts/engine-verify.ps1"
assert_files_equal "bash CLI engine/plugin mirror" "$ROOT_REPO/engine/bin/engine" "$ROOT_REPO/plugin/bin/engine"
assert_files_equal "powershell CLI engine/plugin mirror" "$ROOT_REPO/engine/bin/engine.ps1" "$ROOT_REPO/plugin/bin/engine.ps1"

if command -v pwsh >/dev/null 2>&1; then
  pwsh -NoProfile -ExecutionPolicy Bypass -File "$HERE/test_acceptance_preflight.ps1" >"$TMP_ROOT/ps.out" 2>&1
  ps_rc=$?
  assert_rc "PowerShell preflight smoke test" 0 "$ps_rc"
else
  echo "SKIP  PowerShell preflight smoke test (pwsh unavailable)"
fi

echo "=== RESULTS: $pass passed, $fail failed ==="
[ "$fail" -eq 0 ]
