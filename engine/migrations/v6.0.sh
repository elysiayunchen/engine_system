#!/usr/bin/env bash
# v6.0 migration step - delegates to engine-migrate-contract.sh
#
# v6.0 introduced:
#   - v6 data-layer dirs (tasks/decisions/domains/changes/evidence/.cache)
#   - federation table (engine/domains/federation.json)
#   - decision rules baseline (engine/decisions/rules.json)
#   - local VERSION stamp (engine/VERSION)
#   - v6 contract block (task card headers / decision ledger / fractal memory /
#     three-layer gate / contract compile / cockpit / N1-N5)
#
# This step is idempotent. It is the first versioned step. Future versions
# (v6.1+) will add sibling scripts; `engine migrate` applies all steps newer
# than the local engine/VERSION in order.
#
# Path note: this script may live under plugin/migrations/ (dev tree) or
# engine/migrations/ (installed project). It probes candidate locations so the
# same script works in both trees.

set -euo pipefail
ROOT="${1:-${CLAUDE_PROJECT_DIR:-$PWD}}"
DIR="$(cd "$(dirname "$0")" && pwd)"

MIGRATOR=""
for candidate in \
  "$DIR/../scripts/engine-migrate-contract.sh" \
  "$DIR/../engine/scripts/engine-migrate-contract.sh" \
  "$DIR/engine-migrate-contract.sh"; do
  if [ -f "$candidate" ]; then
    MIGRATOR="$candidate"
    break
  fi
done

if [ -z "$MIGRATOR" ]; then
  echo "Error: engine-migrate-contract.sh not found near $DIR." >&2
  exit 1
fi

exec bash "$MIGRATOR" "$ROOT"
