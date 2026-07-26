#!/usr/bin/env bash
# T-048 (D-035) multi-session isolation suite runner.
# Runs the v6.12.0 union-gating / lease tests plus the previously standalone
# v6.11.x multi-session tests under tests/workstream (they had no runner and
# were invisible to scripts/check.sh).

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
TESTS_DIR="$(cd "$HERE/.." && pwd)"

total_pass=0
total_fail=0

run_one() {
  name="$(basename "$1")"
  if bash "$1"; then
    total_pass=$((total_pass + 1))
  else
    echo "SUITE-FAIL $name"
    total_fail=$((total_fail + 1))
  fi
  echo ""
}

for t in "$HERE"/test_*.sh; do
  [ -f "$t" ] || continue
  run_one "$t"
done

for t in \
  "$TESTS_DIR/workstream/test_double_signal.sh" \
  "$TESTS_DIR/workstream/test_lock_recovery.sh" \
  "$TESTS_DIR/workstream/test_worker_mode.sh" \
  "$TESTS_DIR/workstream/test_kill_switch.sh" \
  "$TESTS_DIR/workstream/test_worker_writes_shard.sh"; do
  [ -f "$t" ] || continue
  run_one "$t"
done

echo "multi-session suites: $total_pass passed, $total_fail failed"
[ "$total_fail" -eq 0 ]
