#!/usr/bin/env bash
# Project-custom Doctor check: all VERSION files must agree.
# Called by engine-doctor.sh after built-in checks.
# Exit 0 = PASS, non-zero = FAIL (stdout becomes the message).

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
V1="$ROOT/VERSION"
V2="$ROOT/engine/VERSION"
V3="$ROOT/plugin/VERSION"

declare -A versions
for f in "$V1" "$V2" "$V3"; do
  if [ -f "$f" ]; then
    versions["$f"]="$(tr -d '[:space:]' < "$f")"
  else
    echo "MISSING: $f does not exist"
    exit 1
  fi
done

if [ "${versions["$V1"]}" != "${versions["$V2"]}" ]; then
  echo "VERSION mismatch: root=${versions["$V1"]} engine=${versions["$V2"]}"
  exit 1
fi

if [ "${versions["$V1"]}" != "${versions["$V3"]}" ]; then
  echo "VERSION mismatch: root=${versions["$V1"]} plugin=${versions["$V3"]}"
  exit 1
fi

echo "VERSION consistent: ${versions["$V1"]}"
exit 0
