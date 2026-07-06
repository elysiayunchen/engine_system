#!/usr/bin/env bash
# Engine System — SessionEnd health hook
#
# Runs a lightweight Engine Doctor check at the end of an agent turn/session and stores
# a short pending note for the next SessionStart hook. This hook never blocks the agent:
# Stop gatekeeping is handled by engine-hook-stop.sh.

set -u
log_error() { echo "[engine-hook-session-end] ERROR: $*" >&2; }

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
ENGINE_DIR="$ROOT/engine"
CACHE_DIR="$ENGINE_DIR/.cache"
PENDING_FILE="$CACHE_DIR/pending.txt"
LOG_FILE="$CACHE_DIR/session-end-doctor.log"
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"

[ -d "$ENGINE_DIR" ] || exit 0
mkdir -p "$CACHE_DIR" 2>/dev/null || { log_error "failed to create cache directory: $CACHE_DIR"; exit 0; }

doctor="$ENGINE_DIR/scripts/engine-doctor.sh"
if [ ! -f "$doctor" ] && [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/engine-doctor.sh" ]; then
  doctor="$SCRIPT_DIR/engine-doctor.sh"
fi

timestamp="$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date)"

if [ ! -f "$doctor" ]; then
  {
    echo "Engine Doctor pending ($timestamp)"
    echo "- Doctor script not found. Run /engine-sync to restore bundled tooling."
  } > "$PENDING_FILE" 2>/dev/null || true
  exit 0
fi

output="$("$doctor" "$ROOT" 2>&1)"
status=$?
[ "$status" -eq 0 ] || log_error "doctor execution failed with status $status"
printf '%s\n' "$output" > "$LOG_FILE" 2>/dev/null || true

summary="$(printf '%s\n' "$output" | grep 'Engine Doctor:' | tail -n 1)"
[ -n "$summary" ] || summary="Engine Doctor exited with status $status"

if [ "$status" -eq 0 ] && printf '%s\n' "$summary" | grep -F '0 failure(s), 0 warning(s)' >/dev/null 2>&1; then
  rm -f "$PENDING_FILE" 2>/dev/null || true
  exit 0
fi

{
  echo "Engine Doctor pending ($timestamp)"
  echo "- $summary"
  echo "- Review with /engine-doctor, then run /engine-reconcile if the registry or anchors drifted."
  echo "- Log: engine/.cache/session-end-doctor.log"
} > "$PENDING_FILE" 2>/dev/null || true

exit 0
