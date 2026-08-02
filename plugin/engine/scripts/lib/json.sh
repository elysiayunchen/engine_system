#!/usr/bin/env bash
# Engine System — minimal pure-bash JSON helpers (inspired by jq, MIT).
# Covers engine-produced JSON only (known structure, no nested escapes).
# Source: source "$(dirname "$0")/lib/json.sh"
#
# Functions:
#   json_get FILE KEY        — extract top-level string/number value by key
#   json_get_nested FILE A.B — dot-path traversal (max 3 levels)
#   json_set FILE KEY VALUE  — replace top-level value in-place
#   json_has FILE KEY        — test if key exists (exit 0/1)
#   json_keys FILE           — list top-level keys

# json_get: extract value for a top-level key from a JSON file.
# Handles: "key": "value" | "key": 123 | "key": true | "key": null
# Does NOT handle nested objects/arrays as values (use Python for those).
json_get() {
  local file="$1" key="$2"
  [ -f "$file" ] || return 1
  # Match "key" : "value" or "key" : number/bool/null
  local val
  val="$(sed -n 's/.*"'"$key"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$file" | head -1)"
  if [ -n "$val" ]; then
    printf '%s' "$val"
    return 0
  fi
  # Try non-string value (number, bool, null)
  val="$(sed -n 's/.*"'"$key"'"[[:space:]]*:[[:space:]]*\([0-9a-z._-]*\).*/\1/p' "$file" | head -1)"
  if [ -n "$val" ]; then
    printf '%s' "$val"
    return 0
  fi
  return 1
}

# json_get_nested: dot-path traversal for known-structure JSON.
# Example: json_get_nested config.json "prove.timeout"
# Uses grep + sed chain; max 3 levels deep.
json_get_nested() {
  local file="$1" path="$2"
  [ -f "$file" ] || return 1
  local IFS='.'
  local -a parts=($path)
  local depth=${#parts[@]}

  if [ "$depth" -eq 1 ]; then
    json_get "$file" "${parts[0]}"
    return $?
  fi

  # For nested: extract the block for each level, then get final key
  # Level 2: find "parent" block, then key within
  if [ "$depth" -eq 2 ]; then
    local parent="${parts[0]}" child="${parts[1]}"
    # Extract lines between "parent": { and closing }
    sed -n '/"'"$parent"'"/,/^[[:space:]]*}/p' "$file" | \
      sed -n 's/.*"'"$child"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1
    return $?
  fi

  # Level 3+: fall back to Python if available
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "
import json, sys
with open(sys.argv[1], encoding='utf-8') as f:
    obj = json.load(f)
for k in sys.argv[2].split('.'):
    obj = obj[k]
print(obj if not isinstance(obj, (dict, list)) else json.dumps(obj))
" "$file" "$path" 2>/dev/null
    return $?
  fi
  return 1
}

# json_set: replace a top-level string value in-place.
# Only handles "key": "old" → "key": "new" (string values).
json_set() {
  local file="$1" key="$2" value="$3"
  [ -f "$file" ] || return 1
  # Escape sed special chars in value
  local escaped
  escaped="$(printf '%s' "$value" | sed 's/[&/\]/\\&/g')"
  sed -i 's/"'"$key"'"[[:space:]]*:[[:space:]]*"[^"]*"/"'"$key"'": "'"$escaped"'"/' "$file"
}

# json_has: test if a top-level key exists.
json_has() {
  local file="$1" key="$2"
  [ -f "$file" ] || return 1
  grep -q "\"$key\"" "$file"
}

# json_keys: list top-level keys (one per line).
json_keys() {
  local file="$1"
  [ -f "$file" ] || return 1
  grep -oE '^\s*"[^"]+"\s*:' "$file" | sed 's/[[:space:]]*"//g; s/"[[:space:]]*://' | head -50
}
