#!/usr/bin/env bash
# Test: review sh/ps1 mirror parity(T-069 AC-11, v6.20.0)
set -euo pipefail
echo "[test_review_mirror_parity.sh] T-069 AC-11 mirror parity"
PASS=0; FAIL=0
ok()  { echo "  PASS $1"; PASS=$((PASS+1)); }
bad() { echo "  FAIL $1"; FAIL=$((FAIL+1)); }

REPO="$PWD"

# 4 个脚本 sh↔sh / ps1↔ps1 镜像 byte-identical
for f in engine-review.sh engine-review.ps1 engine-review-pipeline.sh engine-review-pipeline.ps1; do
  if diff -q "$REPO/engine/scripts/$f" "$REPO/plugin/engine/scripts/$f" >/dev/null 2>&1; then
    ok "$f byte-identical mirror"
  else
    bad "$f mirror drift"
  fi
done

echo "Results: $PASS pass, $FAIL fail"
[ "$FAIL" -eq 0 ] || exit 1
