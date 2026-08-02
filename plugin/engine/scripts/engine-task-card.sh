#!/usr/bin/env bash
# Shared task-card parsing helpers.
#
# This file is intentionally side-effect free: callers source it and invoke
# the functions below.  Keeping the grammar here prevents verify, gate,
# review, close, and Doctor from silently accepting different card shapes.

task_card_parse_patterns() {
  local field="${1:-}" file="${2:-}"
  [ -n "$field" ] && [ -f "$file" ] || return 0

  awk -v wanted="$field" '
    function trim(s) {
      sub(/^[[:space:]]+/, "", s)
      sub(/[[:space:]]+$/, "", s)
      return s
    }
    function emit(value,    n, parts, i, item) {
      value = trim(value)
      if (value == "") return
      # Remove complete inline annotations before splitting.  An annotation
      # may contain commas (for example `file.sh (chmod, no content change)`);
      # splitting first would leak its trailing fragment as a fake path.
      gsub(/[[:space:]]*\([^)]*\)/, "", value)
      gsub(/[[:space:]]*\[[^]]*\]/, "", value)
      n = split(value, parts, /,[[:space:]]*/)
      for (i = 1; i <= n; i++) {
        item = trim(parts[i])
        sub(/[[:space:]]+\(.*/, "", item)
        sub(/[[:space:]]+\[.*/, "", item)
        sub(/[[:space:]]+#.*/, "", item)
        sub(/^\[[[:space:]]*/, "", item)
        sub(/[[:space:]]*\]$/, "", item)
        item = trim(item)
        if (item != "") print item
      }
    }
    BEGIN {
      wanted_lc = tolower(wanted)
      in_frontmatter = 0
      in_front_field = 0
      mode = ""
    }
    {
      raw = $0
      line = raw
      sub(/\r$/, "", line)
      sub(/^[[:space:]]*>[[:space:]]*/, "", line)
      sub(/^[[:space:]]+/, "", line)
      lower = tolower(line)

      if (NR == 1 && line ~ /^[[:space:]]*---[[:space:]]*$/) {
        in_frontmatter = 1
        next
      }
      if (in_frontmatter && line ~ /^[[:space:]]*---[[:space:]]*$/) {
        in_frontmatter = 0
        in_front_field = 0
        next
      }

      if (in_frontmatter) {
        if (mode == "" && lower ~ ("^" wanted_lc "[[:space:]]*:")) {
          value = line
          sub(/^[^:]*:[[:space:]]*/, "", value)
          mode = "front"
          value = trim(value)
          if (value == "") in_front_field = 1
          else emit(value)
          next
        }
        if (mode == "front" && in_front_field && line ~ /^[[:space:]]*-[[:space:]]+/) {
          sub(/^[[:space:]]*-[[:space:]]+/, "", line)
          emit(line)
          next
        }
        if (mode == "front" && in_front_field && line ~ /^[[:space:]]*[A-Za-z0-9_-]+[[:space:]]*:/) {
          in_front_field = 0
        }
        next
      }

      if (mode == "front") next

      if (mode != "front" && lower ~ ("^##[[:space:]]+" wanted_lc "[[:space:]]*$")) {
        mode = "section"
        next
      }

      if (mode == "") {
        if (line ~ /^##[[:space:]]+/) {
          mode = "body"
          next
        }
        # A blank legacy `WRITE-SET:` line is not a declaration; permit the
        # following explicit section form to supply the paths.
        if (lower ~ ("^" wanted_lc "[[:space:]]*:[[:space:]]*.+$")) {
          value = line
          sub(/^[^:]*:[[:space:]]*/, "", value)
          mode = "inline"
          emit(value)
          next
        }
      }

      if (mode == "section") {
        if (line ~ /^##[[:space:]]+/) {
          mode = "done"
          next
        }
        if (line ~ /^[[:space:]]*-[[:space:]]+/) {
          sub(/^[[:space:]]*-[[:space:]]+/, "", line)
          emit(line)
        }
        next
      }
    }
  ' "$file"
}

task_card_parse_ac_declarations() {
  local file="${1:-}"
  [ -f "$file" ] || return 0
  local line ac_id verify_cmd verify_rest
  local section_ac="" pending_ac=""
  while IFS= read -r line || [ -n "$line" ]; do
    if [[ "$line" =~ ^###[[:space:]]+(AC-[A-Za-z]*[0-9]+(\.[0-9]+)*) ]]; then
      section_ac="${BASH_REMATCH[1]}"
      pending_ac=""
      continue
    fi
    if [[ "$line" =~ ^### ]]; then section_ac=""; fi
    if [ -n "$section_ac" ]; then
      if [[ "$line" =~ ^[[:space:]]*verify:[[:space:]]*(.+) ]]; then
        verify_cmd="${BASH_REMATCH[1]}"
        verify_cmd="${verify_cmd%"${verify_cmd##*[![:space:]]}"}"
        printf '%s\t%s\n' "$section_ac" "$verify_cmd"
        section_ac=""
        continue
      fi
      continue
    fi
    if [[ "$line" =~ ^AC:[[:space:]]*(AC-[A-Za-z]*[0-9]+(\.[0-9]+)*) ]]; then
      ac_id="${BASH_REMATCH[1]}"
      verify_cmd=""
      case "$line" in
        *"| verify:"*)  verify_rest="${line#*"| verify:"}" ;;
        *"|verify:"*)   verify_rest="${line#*"|verify:"}" ;;
        *"→ verify:"*)  verify_rest="${line#*"→ verify:"}" ;;
        *"→verify:"*)   verify_rest="${line#*"→verify:"}" ;;
        *)               verify_rest="" ;;
      esac
      verify_cmd="${verify_rest#"${verify_rest%%[![:space:]]*}"}"
      verify_cmd="${verify_cmd%"${verify_cmd##*[![:space:]]}"}"
      printf '%s\t%s\n' "$ac_id" "$verify_cmd"
      pending_ac=""
      continue
    fi
    if [[ "$line" =~ ^-[[:space:]]+(AC-[A-Za-z]*[0-9]+(\.[0-9]+)*) ]]; then
      ac_id="${BASH_REMATCH[1]}"
      verify_cmd=""
      case "$line" in
        *"| verify:"*) verify_rest="${line#*"| verify:"}" ;;
        *"|verify:"*)  verify_rest="${line#*"|verify:"}" ;;
        *)              verify_rest="" ;;
      esac
      verify_cmd="${verify_rest#"${verify_rest%%[![:space:]]*}"}"
      verify_cmd="${verify_cmd%"${verify_cmd##*[![:space:]]}"}"
      if [ -n "$verify_cmd" ]; then
        printf '%s\t%s\n' "$ac_id" "$verify_cmd"
      else
        pending_ac="$ac_id"
      fi
      continue
    fi
    if [ -n "$pending_ac" ]; then
      if [[ "$line" =~ ^[[:space:]]*verify:[[:space:]]*(.+) ]]; then
        verify_cmd="${BASH_REMATCH[1]}"
        verify_cmd="${verify_cmd%"${verify_cmd##*[![:space:]]}"}"
        printf '%s\t%s\n' "$pending_ac" "$verify_cmd"
        pending_ac=""
        continue
      fi
      printf '%s\t\n' "$pending_ac"
      pending_ac=""
    fi
    if [[ "$line" =~ ^\|[[:space:]]*(AC-[A-Za-z]*[0-9]+(\.[0-9]+)*) ]]; then
      ac_id="${BASH_REMATCH[1]}"
      verify_cmd=""
      if [[ "$line" =~ verify:[[:space:]]*([^|]+) ]]; then
        verify_cmd="${BASH_REMATCH[1]}"
        verify_cmd="${verify_cmd#"${verify_cmd%%[![:space:]]*}"}"
        verify_cmd="${verify_cmd%"${verify_cmd##*[![:space:]]}"}"
      fi
      printf '%s\t%s\n' "$ac_id" "$verify_cmd"
    fi
  done < "$file"
  [ -n "$pending_ac" ] && printf '%s\t\n' "$pending_ac"
  [ -n "$section_ac" ] && printf '%s\t\n' "$section_ac"
}

task_card_has_code() {
  local root="${1:-}" file="${2:-}" extensions="${3:-.sh .ps1 .py .js .ts .go .rs .java .c .cpp .rb .php}"
  local path clean ext ce full candidate
  while IFS= read -r path; do
    clean="${path%%(*}"
    clean="${clean%%\[*}"
    clean="${clean//\\//}"
    clean="${clean%"${clean##*[![:space:]]}"}"
    clean="${clean#"${clean%%[![:space:]]*}"}"
    [ -n "$clean" ] || continue
    ext=".${clean##*.}"
    for ce in $extensions; do
      if [ "$ext" = "$ce" ]; then return 0; fi
    done
    full="$root/$clean"
    if [ -f "$full" ]; then
      ext=".${full##*.}"
      for ce in $extensions; do
        if [ "$ext" = "$ce" ]; then return 0; fi
      done
    elif [ -d "$full" ]; then
      while IFS= read -r -d '' candidate; do
        ext=".${candidate##*.}"
        for ce in $extensions; do
          if [ "$ext" = "$ce" ]; then return 0; fi
        done
      done < <(find "$full" -type f -print0 2>/dev/null)
    fi
    # A bare directory glob such as `src/**` does not pass the -d check above.
    # Let find apply the task-card glob so docs-only detection remains correct
    # for the same WRITE-SET shapes accepted by the gate.
    if [[ "$clean" == *\** || "$clean" == *\?* || "$clean" == *\[* ]]; then
      while IFS= read -r -d '' candidate; do
        ext=".${candidate##*.}"
        for ce in $extensions; do
          if [ "$ext" = "$ce" ]; then return 0; fi
        done
      done < <(find "$root" -type f -path "$root/$clean" -print0 2>/dev/null)
    fi
  done < <(task_card_parse_patterns WRITE-SET "$file")
  return 1
}
