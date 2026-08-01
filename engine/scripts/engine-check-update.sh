#!/usr/bin/env bash
# Engine System - check for remote updates
#
# Compares local engine/VERSION against the remote repository VERSION.
# Exit codes: 0 = up to date (or remote is older) | 7 = update available | 8 = network error
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
# 非纯数字版本(unknown 等)原样返回；只有可排序数字版本才判断方向，未知形状保守退出 7。
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

is_numeric_version() {
  [[ "${1:-}" =~ ^[0-9]+(\.[0-9]+)*$ ]]
}

# Compare normalized numeric versions without relying on sort-version support.
# Prints -1 when left < right, 0 when equal, and 1 when left > right.
compare_versions() {
  local left="$1" right="$2"
  local IFS=.
  local -a left_parts right_parts
  read -r -a left_parts <<< "$left"
  read -r -a right_parts <<< "$right"
  local max_parts="${#left_parts[@]}"
  if [ "${#right_parts[@]}" -gt "$max_parts" ]; then
    max_parts="${#right_parts[@]}"
  fi
  local i left_part right_part
  for ((i = 0; i < max_parts; i++)); do
    left_part=$((10#${left_parts[$i]:-0}))
    right_part=$((10#${right_parts[$i]:-0}))
    if [ "$left_part" -lt "$right_part" ]; then
      printf '%s' '-1'
      return
    fi
    if [ "$left_part" -gt "$right_part" ]; then
      printf '%s' '1'
      return
    fi
  done
  printf '%s' '0'
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

local_normalized="$(normalize_version "$local_version")"
remote_normalized="$(normalize_version "$remote_version")"

if [ "$local_normalized" = "$remote_normalized" ]; then
  echo "Up to date."
  exit 0
fi

if is_numeric_version "$local_normalized" && is_numeric_version "$remote_normalized"; then
  case "$(compare_versions "$local_normalized" "$remote_normalized")" in
    -1)
      echo "Update available: $local_version -> $remote_version"
      echo "Run: engine update"
      exit 7
      ;;
    1)
      echo "Remote version $remote_version is older than local $local_version; no downgrade recommended."
      exit 0
      ;;
  esac
fi

echo "Version comparison unavailable for local '$local_version' and remote '$remote_version'." >&2
exit 7
