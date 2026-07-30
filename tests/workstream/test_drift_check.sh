#!/usr/bin/env bash
# Test: engine-drift-check three-step verification (T-066, v6.18.0, D-038b)
#
# Validates engine/scripts/engine-drift-check.sh end-to-end against a mock
# git repository. Scenarios cover all three steps + the "step1 FAIL still
# emits subsequent summary" guarantee from D-038b.
#
# Scenarios:
#   S1: clean evidence (no drift) -> exit 0, all OK
#   S2: MANIFEST hash mismatch (evidence tampered) -> exit 1, step1 FAIL
#   S3: code file changed after verify (git ls-files -s differs) -> exit 1, step3 DRIFT
#   S4: MANIFEST missing (legacy evidence) -> exit 1, step1 FAIL + step2/3 SKIP
#   S5: provenance.commit != HEAD -> exit 1, step1 FAIL
#
# Pattern follows test_precommit_dist_stale.sh (T-051): mock ROOT + git init.

set -uo pipefail

echo "[test_drift_check.sh] T-066 drift-check three-step (D-038b)"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

# Real engine-drift-check.sh path (script under test).
REAL_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT_UNDER_TEST="$REAL_ROOT/engine/scripts/engine-drift-check.sh"
[ -f "$SCRIPT_UNDER_TEST" ] || { echo "FATAL: $SCRIPT_UNDER_TEST not found"; exit 2; }

PASS=0
FAIL=0
ok()   { echo "  PASS $1"; PASS=$((PASS+1)); }
bad() { echo "  FAIL $1"; FAIL=$((FAIL+1)); }

# Build a mock done card + evidence dir + code file, then git-init & commit.
# Args: <scenario_setup_fn>
setup_repo() {
  local setup_fn="$1"
  ROOT="$TMPDIR/repo"
  rm -rf "$ROOT"
  mkdir -p "$ROOT/engine/tasks" "$ROOT/engine/evidence/T-999" "$ROOT/src"
  cp "$SCRIPT_UNDER_TEST" "$ROOT/engine/scripts/engine-drift-check.sh" 2>/dev/null
  mkdir -p "$ROOT/engine/scripts"
  cp "$SCRIPT_UNDER_TEST" "$ROOT/engine/scripts/engine-drift-check.sh"
  # code file under test
  echo "print('hello')" > "$ROOT/src/foo.py"
  # done card
  cat > "$ROOT/engine/tasks/T-999.md" <<'EOF'
# T-999: test fixture
> status: done | lane: engine-runtime

## WRITE-SET
- src/foo.py

AC: AC-1 | verify: true
EOF
  # delegate scenario-specific evidence setup
  "$setup_fn"
  # git init + add + commit so HEAD is well-defined
  ( cd "$ROOT" && git init -q && git add -A && git -c user.email=t@t -c user.name=t commit -qm "fixture" )
}

# Helper: write AC-1.json evidence file with given code_fingerprint + commit.
# Args: <code_fp_json> <commit_sha> <writer> [extra_json_fragment]
write_evidence() {
  local code_fp="$1" commit="$2" writer="$3" extra="${4:-}"
  local ev="$ROOT/engine/evidence/T-999/AC-1.json"
  cat > "$ev" <<JSON
{"ac":"AC-1","verify":"true","status":"pass","exit":0,"output_fingerprint":"sha256:abc","code_fingerprint":${code_fp},"write_set_snapshot":["src/foo.py"],"verified_against_commit":"${commit}","write_provenance":{"writer":"${writer}","commit":"${commit}","timestamp":"2026-07-30T00:00:00Z","argv":"engine verify T-999"}${extra},"timestamp":"2026-07-30T00:00:00Z"}
JSON
}

# Helper: compute MANIFEST.json aggregate hash and write MANIFEST.
# Args: <commit_sha>
write_manifest() {
  local commit="$1"
  local ev_dir="$ROOT/engine/evidence/T-999"
  local manifest_content="" fname fhash
  for fname in $(cd "$ev_dir" && find . -maxdepth 1 -type f \( -name '*.json' -o -name 'checkpoint.md' \) ! -name 'MANIFEST.json' 2>/dev/null | sed 's|^\./||' | LC_ALL=C sort); do
    fhash="$(sha256sum "$ev_dir/$fname" | cut -d' ' -f1)"
    manifest_content+="${fname}:${fhash}"$'\n'
  done
  local manifest_hash="$(printf '%s' "$manifest_content" | sha256sum | cut -d' ' -f1)"
  local manifest_ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local files_json="{" first=1
  while IFS=: read -r fname fhash; do
    [ -n "$fname" ] || continue
    [ "$first" = "1" ] || files_json+=","
    files_json+="\"$fname\":\"$fhash\""
    first=0
  done <<< "$manifest_content"
  files_json+="}"
  printf '{"evidence_manifest_sha256":"sha256:%s","generated":"%s","writer":"engine-verify","commit":"%s","files":%s}\n' \
    "$manifest_hash" "$manifest_ts" "$commit" "$files_json" \
    > "$ev_dir/MANIFEST.json"
}

# Helper: compute git ls-files -s blob sha for a path under $ROOT.
# Args: <path> -> echoes blob sha
blob_sha_of() {
  local path="$1"
  ( cd "$ROOT" && git ls-files -s "$path" | awk '{print $2}' )
}

# Helper: run drift-check and capture exit code.
run_check() {
  ( cd "$ROOT" && CLAUDE_PROJECT_DIR="$ROOT" bash "$ROOT/engine/scripts/engine-drift-check.sh" )
  return $?
}

# DEBUG: when DEBUG=1, run_check prints full output.
run_check_debug() {
  local out rc
  out="$(cd "$ROOT" && CLAUDE_PROJECT_DIR="$ROOT" bash "$ROOT/engine/scripts/engine-drift-check.sh" 2>&1)" || true
  rc=$?
  echo "----- DEBUG OUTPUT (rc=$rc) -----"
  echo "$out"
  echo "----- END DEBUG -----"
  return $rc
}

# =============================================================================
# S1: clean evidence -> exit 0, all OK
# =============================================================================
setup_s1() {
  # Will be filled after git commit (need HEAD + blob sha)
  :
}
setup_repo setup_s1
HEAD_SHA="$(cd "$ROOT" && git rev-parse HEAD)"
BLOB_SHA="$(blob_sha_of src/foo.py)"
write_evidence "{\"src/foo.py\":\"$BLOB_SHA\"}" "$HEAD_SHA" "engine-verify"
write_manifest "$HEAD_SHA"
echo "S1: clean evidence -> exit 0"
if [ "${DEBUG:-0}" = "1" ]; then
  out="$(run_check_debug 2>&1)"; rc=$?
else
  out="$(run_check 2>&1)"; rc=$?
fi
echo "$out"
if [ "$rc" -eq 0 ]; then
  ok "S1 exit 0"
else
  bad "S1 expected exit 0 got $rc"
fi
echo "$out" | grep -q "OK   step1" || bad "S1 missing step1 OK"
echo "$out" | grep -q "OK   step3" || bad "S1 missing step3 OK"

# =============================================================================
# S2: MANIFEST hash mismatch (evidence tampered) -> exit 1, step1 FAIL
# =============================================================================
setup_s2() { :; }
setup_repo setup_s2
HEAD_SHA="$(cd "$ROOT" && git rev-parse HEAD)"
BLOB_SHA="$(blob_sha_of src/foo.py)"
write_evidence "{\"src/foo.py\":\"$BLOB_SHA\"}" "$HEAD_SHA" "engine-verify"
write_manifest "$HEAD_SHA"
# Tamper: change AC-1.json content without re-writing MANIFEST
echo '{"tampered": true}' > "$ROOT/engine/evidence/T-999/AC-1.json"
echo "S2: MANIFEST mismatch -> exit 1, step1 FAIL"
if out="$(run_check 2>&1)"; rc=$?; [ "$rc" -eq 1 ]; then
  ok "S2 exit 1"
else
  bad "S2 expected exit 1 got $rc"
fi
echo "$out" | grep -q "FAIL step1: evidence tampered" || bad "S2 missing tampered message"

# =============================================================================
# S3: code file changed after verify (git ls-files -s differs) -> step3 DRIFT
# =============================================================================
setup_s3() { :; }
setup_repo setup_s3
HEAD1="$(cd "$ROOT" && git rev-parse HEAD)"
BLOB1="$(blob_sha_of src/foo.py)"
write_evidence "{\"src/foo.py\":\"$BLOB1\"}" "$HEAD1" "engine-verify"
# Modify code file + git add + commit (so ls-files -s returns a NEW blob sha)
echo "print('changed')" > "$ROOT/src/foo.py"
( cd "$ROOT" && git add src/foo.py && git -c user.email=t@t -c user.name=t commit -qm "drift" )
# Re-write MANIFEST with new HEAD so step1 passes (focus step3 on the drift).
# AC-1.json still references the old BLOB1 — step3 must catch the mismatch.
HEAD2="$(cd "$ROOT" && git rev-parse HEAD)"
write_manifest "$HEAD2"
echo "S3: code changed -> step3 DRIFT"
if [ "${DEBUG:-0}" = "1" ]; then
  out="$(run_check_debug 2>&1)"; rc=$?
  echo "$out"
else
  out="$(run_check 2>&1)"; rc=$?
fi
if [ "$rc" -eq 1 ]; then
  ok "S3 exit 1"
else
  bad "S3 expected exit 1 got $rc"
fi
echo "$out" | grep -q "DRIFT step3" || bad "S3 missing DRIFT message"

# =============================================================================
# S4: MANIFEST missing (legacy evidence) -> exit 1, step1 FAIL + step2/3 SKIP
# =============================================================================
setup_s4() { :; }
setup_repo setup_s4
HEAD_SHA="$(cd "$ROOT" && git rev-parse HEAD)"
BLOB_SHA="$(blob_sha_of src/foo.py)"
write_evidence "{\"src/foo.py\":\"$BLOB_SHA\"}" "$HEAD_SHA" "engine-verify"
# No write_manifest call - simulates legacy evidence
echo "S4: MANIFEST missing -> exit 1, step1 FAIL + SKIP step2/3"
if [ "${DEBUG:-0}" = "1" ]; then
  out="$(run_check_debug 2>&1)"; rc=$?
  echo "$out"
else
  out="$(run_check 2>&1)"; rc=$?
fi
if [ "$rc" -eq 1 ]; then
  ok "S4 exit 1"
else
  bad "S4 expected exit 1 got $rc"
fi
# Tolerate both EN ("MANIFEST.json missing") and ZH ("MANIFEST.json 不存在") messages.
echo "$out" | grep -qE "FAIL step1: MANIFEST\.json (missing|不存在)" || bad "S4 missing missing-manifest message"
echo "$out" | grep -q "SKIP step2" || bad "S4 missing step2 SKIP"
echo "$out" | grep -q "SKIP step3" || bad "S4 missing step3 SKIP"

# =============================================================================
# S5: provenance.commit != HEAD -> exit 1, step1 FAIL
# =============================================================================
setup_s5() { :; }
setup_repo setup_s5
HEAD_SHA="$(cd "$ROOT" && git rev-parse HEAD)"
BLOB_SHA="$(blob_sha_of src/foo.py)"
# Use a fake commit sha that is NOT HEAD
FAKE_COMMIT="0000000000000000000000000000000000000001"
write_evidence "{\"src/foo.py\":\"$BLOB_SHA\"}" "$FAKE_COMMIT" "engine-verify"
write_manifest "$FAKE_COMMIT"
echo "S5: provenance.commit != HEAD -> exit 1"
if [ "${DEBUG:-0}" = "1" ]; then
  out="$(run_check_debug 2>&1)"; rc=$?
  echo "$out"
else
  out="$(run_check 2>&1)"; rc=$?
fi
if [ "$rc" -eq 1 ]; then
  ok "S5 exit 1"
else
  bad "S5 expected exit 1 got $rc"
fi
echo "$out" | grep -q "provenance.commit mismatch" || bad "S5 missing commit mismatch message"

echo ""
echo "=========================================="
echo "T-066 drift-check: $PASS pass, $FAIL fail"
[ "$FAIL" -eq 0 ] || exit 1
