#!/usr/bin/env bash
# T-079: agent-neutral lifecycle closure and CLI status propagation.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT_REPO="$(cd "$HERE/../.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

PASS=0
FAIL=0
PY=python3
command -v "$PY" >/dev/null 2>&1 || PY=python

ok() { PASS=$((PASS+1)); echo "PASS  $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL  $1"; }
assert_rc() {
  local name="$1" expected="$2" actual="$3"
  if [ "$expected" -eq "$actual" ]; then ok "$name (exit=$actual)"; else bad "$name (expected=$expected got=$actual)"; fi
}
assert_contains() {
  local name="$1" file="$2" pattern="$3"
  if grep -Eq "$pattern" "$file" 2>/dev/null; then ok "$name"; else bad "$name (pattern=$pattern)"; fi
}
assert_json() {
  local name="$1" file="$2" expr="$3" expected="$4"
  local actual
  actual="$($PY -c "import json,sys; d=json.load(open(sys.argv[1])); print($expr)" "$file" 2>/dev/null || true)"
  if [ "$actual" = "$expected" ]; then ok "$name"; else bad "$name (expected=$expected got=$actual)"; fi
}

new_fixture() {
  local d="$TMP_ROOT/repo-$RANDOM"
  mkdir -p "$d/engine/tasks" "$d/engine/scripts" "$d/engine/bin" \
    "$d/engine/evidence" "$d/engine/gate" "$d/engine/review/evidence"
  git -C "$d" init -q
  git -C "$d" config user.email test@example.invalid
  git -C "$d" config user.name T079
  git -C "$d" config core.autocrlf false
  cp "$ROOT_REPO/engine/bin/engine" "$d/engine/bin/engine"
  cp "$ROOT_REPO/engine/scripts/engine-gate.sh" "$d/engine/scripts/engine-gate.sh"
  cp "$ROOT_REPO/engine/scripts/engine-verify.sh" "$d/engine/scripts/engine-verify.sh"
  cp "$ROOT_REPO/engine/scripts/engine-prove.sh" "$d/engine/scripts/engine-prove.sh"
  cp "$ROOT_REPO/engine/scripts/engine-close.sh" "$d/engine/scripts/engine-close.sh"
  chmod +x "$d/engine/bin/engine" "$d/engine/scripts/"*.sh
  cat > "$d/engine/gate/config.json" <<'JSON'
{
  "defaults": {
    "gates": ["verify", "review", "review_agent", "prove"],
    "code_extensions": [".sh", ".ps1", ".py", ".js"],
    "docs_only_skip": ["review", "review_agent", "prove"]
  }
}
JSON
  cat > "$d/engine/scripts/engine-doctor.sh" <<'DOCTOR'
#!/usr/bin/env bash
exit "${ENGINE_TEST_DOCTOR_RC:-0}"
DOCTOR
  chmod +x "$d/engine/scripts/engine-doctor.sh"
  printf '%s' "$d"
}

write_card() {
  local d="$1"
  cat > "$d/engine/tasks/T-001.md" <<'CARD'
# T-001 lifecycle fixture
> status: active | lane: test

## WRITE-SET
- docs/guide.md

## FORBIDDEN

AC: AC-1 | verify: true
CARD
}

commit_fixture() {
  local d="$1"
  git -C "$d" add -A
  git -C "$d" commit -qm fixture --no-verify
}

echo "=== T-079 lifecycle tests ==="

# AC-1: public gate CLI + actual provenance, and direct script is distinguishable.
R="$(new_fixture)"; write_card "$R"; commit_fixture "$R"
mkdir -p "$R/engine/evidence/T-001"
printf '%s\n' '{"ac":"AC-1","status":"pass","exit":0}' > "$R/engine/evidence/T-001/AC-1.json"
(
  cd "$R" || exit 2
  ./engine/bin/engine gate T-001 > "$TMP_ROOT/gate.out" 2>&1
); rc=$?
assert_rc "Bash engine gate CLI is reachable" 0 "$rc"
assert_json "CLI gate provenance is real" "$R/engine/evidence/T-001/GATE.json" "d['write_provenance']['argv']" "engine gate T-001"
(
  cd "$R" || exit 2
  bash engine/scripts/engine-gate.sh T-001 > "$TMP_ROOT/direct-gate.out" 2>&1
); rc=$?
assert_rc "direct gate script still works" 0 "$rc"
assert_json "direct gate provenance is not mislabeled" "$R/engine/evidence/T-001/GATE.json" "d['write_provenance']['argv']" "engine-gate.sh T-001"

# Verify also records the public entry point when called through the CLI.
(
  cd "$R" || exit 2
  ./engine/bin/engine verify T-001 > "$TMP_ROOT/verify.out" 2>&1
); rc=$?
assert_rc "Bash engine verify still works" 0 "$rc"
assert_json "CLI verify provenance is real" "$R/engine/evidence/T-001/AC-1.json" "d['write_provenance']['argv']" "engine verify T-001"

# The gate's prove remediation must be reachable through the same public CLI.
(
  cd "$R" || exit 2
  ./engine/bin/engine prove T-001 --infer > "$TMP_ROOT/prove.out" 2>&1
); rc=$?
assert_rc "Bash engine prove CLI is reachable" 0 "$rc"
if [ -f "$R/engine/evidence/T-001/prove-package.md" ]; then
  ok "prove infer writes its package"
else
  bad "prove infer writes its package"
fi

# AC-2: Doctor failures are no longer swallowed by the public wrapper.
R="$(new_fixture)"; write_card "$R"; commit_fixture "$R"
(
  cd "$R" || exit 2
  ENGINE_TEST_DOCTOR_RC=7 ./engine/bin/engine doctor > "$TMP_ROOT/doctor.out" 2>&1
); rc=$?
assert_rc "Bash engine doctor propagates failure" 7 "$rc"

# AC-3: close runs the public stages and emits a pass audit for a docs-only card.
R="$(new_fixture)"; write_card "$R"; printf '%s\n' 'T-001' > "$R/engine/CONTEXT.md"; printf '%s\n' 'T-001' > "$R/engine/HANDOFF.md"; commit_fixture "$R"
(
  cd "$R" || exit 2
  ./engine/bin/engine close T-001 > "$TMP_ROOT/close.out" 2>&1
); rc=$?
assert_rc "close succeeds when verify/gate/doctor pass" 0 "$rc"
assert_json "close status is pass" "$R/engine/evidence/T-001/CLOSE.json" "d['status']" "pass"
assert_json "close records verify pass" "$R/engine/evidence/T-001/CLOSE.json" "d['stages']['verify']['exit']" "0"
assert_json "close records gate pass" "$R/engine/evidence/T-001/CLOSE.json" "d['stages']['gate']['exit']" "0"
assert_json "close records doctor pass" "$R/engine/evidence/T-001/CLOSE.json" "d['stages']['doctor']['exit']" "0"

# AC-4: a non-coordinator must explicitly produce its own worker handoff.
R="$(new_fixture)"; write_card "$R"; mkdir -p "$R/engine/.cache"; commit_fixture "$R"
printf '%s\n' '1|other-session|coordinator|2026-08-01T00:00:00Z|T-999' > "$R/engine/.cache/session.lock"
(
  cd "$R" || exit 2
  ./engine/bin/engine close T-001 --handoff codex > "$TMP_ROOT/worker-close.out" 2>&1
); rc=$?
assert_rc "worker close creates handoff" 0 "$rc"
assert_json "worker close is marked handoff" "$R/engine/evidence/T-001/CLOSE.json" "d['status']" "handoff"
assert_contains "worker handoff contains closure audit" "$R/engine/workstreams/T-001/sessions/s-codex/HANDOFF.md" 'Closure audit'

R="$(new_fixture)"; write_card "$R"; mkdir -p "$R/engine/.cache"; commit_fixture "$R"
printf '%s\n' '1|other-session|coordinator|2026-08-01T00:00:00Z|T-999' > "$R/engine/.cache/session.lock"
(
  cd "$R" || exit 2
  ./engine/bin/engine close T-001 > "$TMP_ROOT/worker-missing.out" 2>&1
); rc=$?
assert_rc "worker close without handoff blocks" 1 "$rc"
assert_json "incomplete worker close is blocked" "$R/engine/evidence/T-001/CLOSE.json" "d['status']" "block"

# AC-5/AC-6: mirror and regression checks.
check_mirror() {
  local left="$1" right="$2"
  if cmp -s "$ROOT_REPO/$left" "$ROOT_REPO/$right"; then ok "mirror parity: $left"; else bad "mirror parity: $left"; fi
}
check_mirror engine/bin/engine plugin/bin/engine
check_mirror engine/bin/engine.ps1 plugin/bin/engine.ps1
check_mirror engine/scripts/engine-gate.sh plugin/engine/scripts/engine-gate.sh
check_mirror engine/scripts/engine-gate.ps1 plugin/engine/scripts/engine-gate.ps1
check_mirror engine/scripts/engine-verify.sh plugin/engine/scripts/engine-verify.sh
check_mirror engine/scripts/engine-verify.ps1 plugin/engine/scripts/engine-verify.ps1
check_mirror engine/scripts/engine-prove.sh plugin/engine/scripts/engine-prove.sh
check_mirror engine/scripts/engine-prove.ps1 plugin/engine/scripts/engine-prove.ps1
check_mirror engine/scripts/engine-close.sh plugin/engine/scripts/engine-close.sh
check_mirror engine/scripts/engine-close.ps1 plugin/engine/scripts/engine-close.ps1
check_mirror engine/scripts/githooks/pre-commit plugin/engine/scripts/githooks/pre-commit
if grep -Eq 'engine/workstreams/\[\^/\]\+/\(\[\^/\]\+/\)\?\[\^/\]\+/' "$ROOT_REPO/engine/scripts/githooks/pre-commit"; then
  ok "pre-commit accepts canonical worker shard layout"
else
  bad "pre-commit accepts canonical worker shard layout"
fi

if command -v pwsh >/dev/null 2>&1; then
  pwsh -NoProfile -ExecutionPolicy Bypass -File "$HERE/test_engine_lifecycle.ps1" > "$TMP_ROOT/ps.out" 2>&1
  ps_rc=$?
  assert_rc "PowerShell lifecycle smoke test" 0 "$ps_rc"
else
  echo "SKIP  PowerShell lifecycle smoke test (pwsh unavailable)"
fi

echo "=== RESULTS: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
