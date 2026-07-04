#!/usr/bin/env bash
# Engine System - check for remote updates
#
# Compares local engine/VERSION against the remote repository VERSION.
# Exit codes: 0 = up to date | 7 = update available | 8 = network error
#
# Idempotent and fail-open: a missing local version falls back to parsing
# ENGINE_FILE_SYSTEM_v5.md; a network failure exits 8 without touching state.

set -euo pipefail

REPO="${ENGINE_SYSTEM_REPO:-elysiayunchen/engine_system}"
BRANCH="${ENGINE_SYSTEM_BRANCH:-main}"
ROOT="${1:-${CLAUDE_PROJECT_DIR:-$PWD}}"
LOCAL_VERSION_FILE="$ROOT/engine/VERSION"
REMOTE_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/VERSION"

# 归一化:补足 major.minor.patch(6.0 -> 6.0.0)再比较,防 6.0 vs 6.0.0 伪更新提示;
# 非纯数字版本(unknown 等)原样返回,退回原始不等判定(D-015)。
normalize_version() {
  v="$(printf '%s' "${1:-}" | tr -d '[:space:]')"
  case "$v" in
    ''|*[!0-9.]*) printf '%s' "$v"; return ;;
  esac
  case "$v" in
    *.*.*) ;;
    *.*) v="$v.0" ;;
    *) v="$v.0.0" ;;
  esac
  printf '%s' "$v"
}

# Read local version: prefer engine/VERSION, fall back to ENGINE_FILE_SYSTEM_v5.md header.
local_version="unknown"
if [ -f "$LOCAL_VERSION_FILE" ]; then
  local_version="$(tr -d '[:space:]' < "$LOCAL_VERSION_FILE")"
elif [ -f "$ROOT/ENGINE_FILE_SYSTEM_v5.md" ]; then
  local_version="$(grep -oE 'Version: [0-9.]+' "$ROOT/ENGINE_FILE_SYSTEM_v5.md" \
    | head -1 | sed 's/Version: //')"
fi

# Fetch remote version (10s timeout, suppress stderr).
remote_version=""
if command -v curl >/dev/null 2>&1; then
  remote_version="$(curl -sSL --max-time 10 "$REMOTE_URL" 2>/dev/null || true)"
elif command -v wget >/dev/null 2>&1; then
  remote_version="$(wget -qO - --timeout=10 "$REMOTE_URL" 2>/dev/null || true)"
else
  echo "Network error: curl or wget required." >&2
  exit 8
fi
remote_version="$(printf '%s' "$remote_version" | tr -d '[:space:]')"

if [ -z "$remote_version" ]; then
  echo "Network error: could not fetch remote VERSION ($REMOTE_URL)." >&2
  exit 8
fi

echo "Local:  $local_version"
echo "Remote: $remote_version"

if [ "$(normalize_version "$local_version")" = "$(normalize_version "$remote_version")" ]; then
  echo "Up to date."
  exit 0
else
  echo "Update available: $local_version -> $remote_version"
  echo "Run: engine update"
  exit 7
fi
