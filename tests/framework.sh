#!/usr/bin/env bash
# Engine System — internalized test framework (inspired by bats-core, MIT).
# Provides TAP output, setup/teardown hooks, temp dir lifecycle, and assertions.
# Source this file in test scripts: source "$(dirname "$0")/../framework.sh"
#
# Usage:
#   source tests/framework.sh
#   tap_plan 5
#   setup() { ... }       # optional, runs before each test section
#   teardown() { ... }    # optional, runs after all tests
#   tap_ok "description"
#   tap_fail "description" "diagnostic"
#   tap_eq "desc" "$actual" "$expected"
#   tap_contains "desc" "$haystack" "$needle"
#   tap_file_exists "desc" "/path/to/file"
#   tap_done              # prints summary, exits 0/1

_TAP_COUNT=0
_TAP_PASS=0
_TAP_FAIL=0
_TAP_PLAN=0
_TEST_TMPDIR=""

# --- Lifecycle ---

tap_plan() {
  _TAP_PLAN="$1"
  echo "1..$1"
}

_tap_ensure_tmpdir() {
  if [ -z "$_TEST_TMPDIR" ]; then
    _TEST_TMPDIR="$(mktemp -d)"
    trap '_tap_cleanup' EXIT
  fi
}

_tap_cleanup() {
  if [ -n "$_TEST_TMPDIR" ] && [ -d "$_TEST_TMPDIR" ]; then
    rm -rf "$_TEST_TMPDIR"
  fi
  if declare -f teardown >/dev/null 2>&1; then
    teardown
  fi
}

tap_tmpdir() {
  _tap_ensure_tmpdir
  printf '%s' "$_TEST_TMPDIR"
}

# --- Assertions (TAP format) ---

tap_ok() {
  local desc="${1:-unnamed}"
  _TAP_COUNT=$((_TAP_COUNT + 1))
  _TAP_PASS=$((_TAP_PASS + 1))
  echo "ok $_TAP_COUNT - $desc"
}

tap_fail() {
  local desc="${1:-unnamed}" diag="${2:-}"
  _TAP_COUNT=$((_TAP_COUNT + 1))
  _TAP_FAIL=$((_TAP_FAIL + 1))
  echo "not ok $_TAP_COUNT - $desc"
  [ -n "$diag" ] && echo "  --- $diag"
}

tap_eq() {
  local desc="$1" actual="$2" expected="$3"
  if [ "$actual" = "$expected" ]; then
    tap_ok "$desc"
  else
    tap_fail "$desc" "expected='$expected' actual='$actual'"
  fi
}

tap_neq() {
  local desc="$1" actual="$2" unexpected="$3"
  if [ "$actual" != "$unexpected" ]; then
    tap_ok "$desc"
  else
    tap_fail "$desc" "should not equal '$unexpected'"
  fi
}

tap_contains() {
  local desc="$1" haystack="$2" needle="$3"
  if printf '%s' "$haystack" | grep -qF "$needle"; then
    tap_ok "$desc"
  else
    tap_fail "$desc" "output does not contain '$needle'"
  fi
}

tap_not_contains() {
  local desc="$1" haystack="$2" needle="$3"
  if printf '%s' "$haystack" | grep -qF "$needle"; then
    tap_fail "$desc" "output unexpectedly contains '$needle'"
  else
    tap_ok "$desc"
  fi
}

tap_file_exists() {
  local desc="$1" path="$2"
  if [ -f "$path" ]; then
    tap_ok "$desc"
  else
    tap_fail "$desc" "file not found: $path"
  fi
}

tap_dir_exists() {
  local desc="$1" path="$2"
  if [ -d "$path" ]; then
    tap_ok "$desc"
  else
    tap_fail "$desc" "directory not found: $path"
  fi
}

tap_exit_code() {
  local desc="$1" actual="$2" expected="${3:-0}"
  tap_eq "$desc (exit code)" "$actual" "$expected"
}

tap_match() {
  local desc="$1" haystack="$2" pattern="$3"
  if printf '%s' "$haystack" | grep -qE "$pattern"; then
    tap_ok "$desc"
  else
    tap_fail "$desc" "no match for pattern '$pattern'"
  fi
}

# --- Summary ---

tap_done() {
  echo ""
  echo "# tests: $_TAP_COUNT, pass: $_TAP_PASS, fail: $_TAP_FAIL"
  if [ "$_TAP_PLAN" -gt 0 ] && [ "$_TAP_COUNT" -ne "$_TAP_PLAN" ]; then
    echo "# WARNING: planned $_TAP_PLAN but ran $_TAP_COUNT"
  fi
  [ "$_TAP_FAIL" -eq 0 ] && exit 0 || exit 1
}

# Auto-setup: create tmpdir if setup() is defined
if declare -f setup >/dev/null 2>&1; then
  _tap_ensure_tmpdir
  setup
fi
