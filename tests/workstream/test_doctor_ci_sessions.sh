#!/usr/bin/env bash
# Test: doctor multi-session isolation CI environment downgrade (T-045, v6.11.7)
#
# Validates that check_multi_session_isolation degrades sessions-dir-missing
# from FAIL to WARN when CI=true / GITHUB_ACTIONS=true. In CI environments
# (GitHub Actions / GitLab CI / etc.) SessionStart hook never runs, so
# .cache/sessions is never created — FAIL-ing here is a false positive that
# has kept CI red since v6.11.0.
#
# Scenarios (AC-4):
#   S1: CI=true + no sessions dir → WARN (not FAIL)
#   S2: no CI env + no sessions dir + cv>=6.11.0 → FAIL (behavior unchanged)
#   S3: CI=true + sessions dir exists → no FAIL (not over-reported)
#
# Extracts the real check_multi_session_isolation() from engine-doctor.sh and
# invokes it with stubbed fail()/warn()/pass() to avoid running the full doctor.

set -euo pipefail

echo "[test_doctor_ci_sessions.sh] T-045 CI environment downgrade (multi-session isolation)"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DOCTOR="$REPO_ROOT/engine/scripts/engine-doctor.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --- Minimal fake engine structure ---
ENGINE_DIR="$TMP/engine"
mkdir -p "$ENGINE_DIR/.cache"
cat > "$ENGINE_DIR/ENGINE_DOCTOR.md" <<'EOF'
<!-- ENGINE_SYSTEM_CONTRACT_MIGRATIONS_START -->
<!-- contract-version: 6.11.1 -->
# ENGINE_DOCTOR
managed block placeholder for test
<!-- ENGINE_SYSTEM_CONTRACT_MIGRATIONS_END -->
EOF

# --- Stub fail/warn/pass counters (doctor.sh uses these globals) ---
fail_count=0
warn_count=0
fail() { fail_count=$((fail_count + 1)); printf 'FAIL %s\n' "$1"; }
warn() { warn_count=$((warn_count + 1)); printf 'WARN %s\n' "$1"; }
pass() { printf 'PASS %s\n' "$1"; }

# --- Extract real check_multi_session_isolation() from doctor.sh ---
# Function spans from "^check_multi_session_isolation() {" to the closing "^}"
# (function body uses if/fi, no nested top-level braces, so ^} is safe)
if ! eval "$(sed -n '/^check_multi_session_isolation()/,/^}$/p' "$DOCTOR")"; then
  echo "FAIL setup: could not extract check_multi_session_isolation() from doctor.sh"
  exit 1
fi

PASS=0
FAIL=0

# === S1: CI=true + no sessions dir → WARN (not FAIL) ===
fail_count=0; warn_count=0
CI=true GITHUB_ACTIONS= check_multi_session_isolation >/dev/null 2>&1 || true
if [ "$fail_count" -eq 0 ] && [ "$warn_count" -ge 1 ]; then
  echo "PASS  S1: CI=true + no sessions dir → WARN (fail=$fail_count warn=$warn_count)"
  PASS=$((PASS + 1))
else
  echo "FAIL  S1: CI=true expected WARN, got fail=$fail_count warn=$warn_count"
  FAIL=$((FAIL + 1))
fi

# === S2: no CI env + no sessions dir + cv>=6.11.0 → FAIL (behavior unchanged) ===
fail_count=0; warn_count=0
CI= GITHUB_ACTIONS= check_multi_session_isolation >/dev/null 2>&1 || true
if [ "$fail_count" -ge 1 ]; then
  echo "PASS  S2: no CI + no sessions dir → FAIL (fail=$fail_count warn=$warn_count)"
  PASS=$((PASS + 1))
else
  echo "FAIL  S2: no CI expected FAIL, got fail=$fail_count warn=$warn_count"
  FAIL=$((FAIL + 1))
fi

# === S3: CI=true + sessions dir exists → no FAIL (not over-reported) ===
mkdir -p "$ENGINE_DIR/.cache/sessions"
fail_count=0; warn_count=0
CI=true GITHUB_ACTIONS= check_multi_session_isolation >/dev/null 2>&1 || true
if [ "$fail_count" -eq 0 ]; then
  echo "PASS  S3: CI=true + sessions exists → no FAIL (fail=$fail_count warn=$warn_count)"
  PASS=$((PASS + 1))
else
  echo "FAIL  S3: sessions exists expected no FAIL, got fail=$fail_count"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "result: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
echo "All 3 scenarios PASS"
