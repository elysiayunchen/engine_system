#!/usr/bin/env bash
# Strict error handling: fail on any error, unbound var, or pipe failure.
# Intentional soft-fail sites (where we checked that failure is safe) use || true.
set -euo pipefail
on_error() { echo "[engine-doctor] error on line $1" >&2; exit 1; }
trap 'on_error ${LINENO}' ERR

ROOT="$(pwd)"
PACKAGE_MODE=false

# v6.12.1 (issue #11 / T-048): unknown flags must fail loudly. The old
# catch-all treated any argument as ROOT, so a typo like --quiet became
# ROOT="--quiet" and doctor reported "ENGINE_MAP.md is missing" instead
# of "no such flag".
for arg in "$@"; do
  case "$arg" in
    --package-mode) PACKAGE_MODE=true ;;
    --*)
      echo "Error: unknown flag '$arg' (known: --package-mode; a path argument sets ROOT)" >&2
      exit 2
      ;;
    *) ROOT="$arg" ;;
  esac
done

ENGINE_DIR="$ROOT/engine"
MAP="$ENGINE_DIR/ENGINE_MAP.md"

fail_count=0
warn_count=0

# parse_ac_declarations: Extract (ac_id, verify_cmd) pairs from a task card.
# Supports 4 AC declaration formats (D-037 / v6.17.0):
#   1. Single-line:  AC: AC-N <desc> | verify: <cmd>
#   2. Section:      ### AC-N: <title> + body's first verify: line
#   3. List item:    - AC-N: <desc> | verify: <cmd>  (or next line verify:)
#   4. Table row:    | AC-N | <desc> | verify: <cmd> |
# Output: <ac_id>\t<verify_cmd> per line (verify_cmd may be empty for SKIP).
# AC id regex: AC-[A-Za-z]*[0-9]+(\.[0-9]+)* (v6.12.1 A-3).
# Separators: | verify: / |verify: / → verify: / →verify: / line-start verify:
parse_ac_declarations() {
  local file="$1"
  local line ac_id verify_cmd verify_rest
  local section_ac="" pending_ac=""
  while IFS= read -r line || [ -n "$line" ]; do
    # Format 2: section heading "### AC-N: <title>"
    if [[ "$line" =~ ^###[[:space:]]+(AC-[A-Za-z]*[0-9]+(\.[0-9]+)*) ]]; then
      section_ac="${BASH_REMATCH[1]}"
      pending_ac=""
      continue
    fi
    # Any other ### heading ends the current section
    if [[ "$line" =~ ^### ]]; then section_ac=""; fi
    # In section: look for first verify: line
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
    # Format 1: "AC: AC-N <desc> | verify: <cmd>"
    if [[ "$line" =~ ^AC:[[:space:]]*(AC-[A-Za-z]*[0-9]+(\.[0-9]+)*) ]]; then
      ac_id="${BASH_REMATCH[1]}"
      verify_cmd=""
      case "$line" in
        *"| verify:"*)  verify_rest="${line#*"| verify:"}" ;;
        *"|verify:"*)   verify_rest="${line#*"|verify:"}" ;;
        *"→ verify:"*)  verify_rest="${line#*"→ verify:"}" ;;
        *"→verify:"*)   verify_rest="${line#*"→verify:"}" ;;
        *)              verify_rest="" ;;
      esac
      verify_cmd="${verify_rest#"${verify_rest%%[![:space:]]*}"}"
      verify_cmd="${verify_cmd%"${verify_cmd##*[![:space:]]}"}"
      printf '%s\t%s\n' "$ac_id" "$verify_cmd"
      pending_ac=""
      continue
    fi
    # Format 3: "- AC-N: <desc>" with same-line or next-line verify:
    if [[ "$line" =~ ^-[[:space:]]+(AC-[A-Za-z]*[0-9]+(\.[0-9]+)*) ]]; then
      ac_id="${BASH_REMATCH[1]}"
      verify_cmd=""
      case "$line" in
        *"| verify:"*)  verify_rest="${line#*"| verify:"}" ;;
        *"|verify:"*)   verify_rest="${line#*"|verify:"}" ;;
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
    # Pending Format 3: next line "  verify: <cmd>"
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
    # Format 4: "| AC-N | <desc> | verify: <cmd> |"
    if [[ "$line" =~ ^\|[[:space:]]*(AC-[A-Za-z]*[0-9]+(\.[0-9]+)*) ]]; then
      ac_id="${BASH_REMATCH[1]}"
      verify_cmd=""
      if [[ "$line" =~ verify:[[:space:]]*([^|]+) ]]; then
        verify_cmd="${BASH_REMATCH[1]}"
        verify_cmd="${verify_cmd#"${verify_cmd%%[![:space:]]*}"}"
        verify_cmd="${verify_cmd%"${verify_cmd##*[![:space:]]}"}"
      fi
      printf '%s\t%s\n' "$ac_id" "$verify_cmd"
      continue
    fi
  done < "$file"
  [ -n "$pending_ac" ] && printf '%s\t\n' "$pending_ac"
  [ -n "$section_ac" ] && printf '%s\t\n' "$section_ac"
  return 0
}

trim() {
  local value="$1"
  value="${value//\`/}"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

fail() {
  fail_count=$((fail_count + 1))
  printf 'FAIL %s\n' "$1"
}

warn() {
  warn_count=$((warn_count + 1))
  printf 'WARN %s\n' "$1"
}

# v6.12.1 (issue #11 C-1): anchored card-status predicates. Unanchored
# 'status:.*active' greps also match prose that merely QUOTES the pattern -
# a card documenting the bug pins itself active (self-referential lock).
card_status_active() {
  grep -Eq '^[[:space:]]*(>[[:space:]]*)?status:[[:space:]]*active' "$1" 2>/dev/null
}
card_status_paused() {
  grep -Eq '^[[:space:]]*(>[[:space:]]*)?status:[[:space:]]*paused' "$1" 2>/dev/null
}
card_status_done() {
  grep -Eq '^[[:space:]]*(>[[:space:]]*)?status:[[:space:]]*done' "$1" 2>/dev/null
}

# v6.12.1 (issue #11 B-2): unified task-card field parser, same three formats
# as the pre-commit hook (T-043): inline `FIELD: a,b`, markdown `## FIELD`
# section list, YAML frontmatter multi-line list. The old inline-only grep
# meant the code->INVENTORY check never evaluated a single section-list card.
doctor_parse_task_patterns() {
  local _field="$1" _file="$2" _inline
  _inline="$(grep "^${_field}:" "$_file" 2>/dev/null | head -1 | sed "s/^${_field}:[[:space:]]*//;s/\r$//")"
  if [ -n "$_inline" ]; then
    printf '%s' "$_inline"
    return 0
  fi
  awk -v field="$_field" '
    BEGIN { in_section=0; in_frontmatter_block=0; in_frontmatter_field=0; out=""; field_lc=tolower(field) }
    {
      sub(/\r$/, "")
      if ($0 ~ /^---[[:space:]]*$/) {
        in_frontmatter_block = !in_frontmatter_block
        in_frontmatter_field = 0
        next
      }
      line_lc = tolower($0)
      if (line_lc ~ "^##[[:space:]]+" field_lc "[[:space:]]*$") { in_section=1; in_frontmatter_field=0; next }
      if (in_section && $0 ~ "^##[[:space:]]+") { exit }
      if (in_frontmatter_block && line_lc ~ "^" field_lc ":$") {
        in_frontmatter_field=1; in_section=0; next
      }
      if (in_frontmatter_field && $0 !~ /^[[:space:]]/ && $0 != "") { in_frontmatter_field=0 }
      if (in_frontmatter_field && $0 ~ /^[[:space:]]+-[[:space:]]+/) {
        sub(/^[[:space:]]+-[[:space:]]+/, "")
        sub(/[[:space:]]+\(.*/, "")
        if ($0 != "") out = (out == "" ? $0 : out "," $0)
        next
      }
      if (in_section && $0 ~ "^-[[:space:]]+") {
        sub(/^-[[:space:]]+/, "")
        sub(/[[:space:]]+\(.*/, "")
        if ($0 != "") out = (out == "" ? $0 : out "," $0)
      }
    }
    END { print out }
  ' "$_file" 2>/dev/null
}

pass() {
  printf 'PASS %s\n' "$1"
}

package_manifest_srcs() {
  local manifest="$1"
  if command -v jq >/dev/null 2>&1; then
    jq -r '.files[].src' "$manifest" | tr -d '\r'
  else
    sed -n 's/.*"src"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$manifest" | tr -d '\r'
  fi
}

package_mode() {
  local manifest="$ROOT/manifest.json"
  if [[ ! -f "$manifest" ]]; then
    fail "plugin/manifest.json is missing"
    echo "  human: The plugin manifest file is missing. Run 'engine init' to generate it, or create manifest.json with the required file list."
    return
  fi

  pass "plugin manifest exists"
  local srcs
  srcs="$(package_manifest_srcs "$manifest")"
  if [[ -z "$srcs" ]]; then
    fail "plugin manifest has no files"
    echo "  human: The plugin manifest lists no files. Add at least one file entry to manifest.json under the 'files' array."
    return
  fi

  local seen_tmp
  seen_tmp="$(mktemp)"
  while IFS= read -r src; do
    [[ -z "$src" ]] && continue
    if grep -Fx "$src" "$seen_tmp" >/dev/null 2>&1; then
      fail "duplicate manifest src: $src"
      echo "  human: The file '$src' appears more than once in the manifest. Remove the duplicate entry from manifest.json."
    fi
    printf '%s\n' "$src" >> "$seen_tmp"
    if [[ -f "$ROOT/$src" ]]; then
      pass "package file exists: $src"
    else
      fail "package file missing: $src"
      echo "  human: The file '$src' is listed in the manifest but does not exist on disk. Create it or remove the entry from manifest.json."
    fi
  done <<< "$srcs"

  for required in \
    AGENTS.md \
    CLAUDE.md \
    .claude/commands/engine-init.md \
    .claude/commands/engine-sync.md \
    engine/ENGINE_DOCTOR.md \
    engine/scripts/engine-doctor.ps1 \
    engine/scripts/engine-doctor.sh \
    engine/scripts/engine-context.ps1 \
    engine/scripts/engine-context.sh \
    engine/scripts/engine-migrate-contract.ps1 \
    engine/scripts/engine-migrate-contract.sh \
    engine/scripts/engine-verify.ps1 \
    engine/scripts/engine-verify.sh \
    engine/scripts/githooks/pre-commit \
    bin/engine \
    bin/engine.ps1 \
    bin/engine.cmd
  do
    if ! grep -Fx "$required" "$seen_tmp" >/dev/null 2>&1; then
      fail "required package file is not in manifest: $required"
      echo "  human: The required file '$required' is not listed in the manifest. Add it to the 'files' array in manifest.json."
    fi
  done
  rm -f "$seen_tmp"

  if [[ -f "$ROOT/.claude/settings.json" ]]; then
    if grep -q '"SessionStart"' "$ROOT/.claude/settings.json" && grep -q '"Stop"' "$ROOT/.claude/settings.json"; then
      pass "Claude hook settings declare SessionStart and Stop"
    else
      fail ".claude/settings.json is missing SessionStart or Stop hooks"
      echo "  human: The Claude settings file is missing required hook definitions. Add both 'SessionStart' and 'Stop' hooks to .claude/settings.json. Run 'engine sync' to regenerate them."
    fi
  else
    fail ".claude/settings.json is missing"
    echo "  human: The .claude/settings.json file is missing entirely. Run 'engine sync' to generate it with the required hook configuration."
  fi
}

if $PACKAGE_MODE; then
  package_mode
  printf '\nEngine Doctor: %s failure(s), %s warning(s)\n' "$fail_count" "$warn_count"
  if [[ "$fail_count" -gt 0 ]]; then
    exit 1
  fi
  exit 0
fi

engine_path() {
  local file="$1"
  file="$(trim "$file")"
  # Registry rows may name root-level files (docs/, tests/, install.sh, ...)
  # as well as engine-relative files. Prefer an existing project-root path;
  # otherwise retain the historical engine/relative resolution.
  if [[ "$file" == engine/* || -e "$ROOT/$file" ]]; then
    printf '%s/%s' "$ROOT" "$file"
  else
    printf '%s/%s' "$ENGINE_DIR" "$file"
  fi
}

budget_cap() {
  case "$1" in
    ENGINE_MAP.md) echo 240 ;;
    SYSTEM.md) echo 340 ;;
    ENGINE_DOCTOR.md) echo 320 ;;
    REPO_GUIDE.md) echo 380 ;;
    CONTEXT.md) echo 260 ;;
    HANDOFF.md) echo 180 ;;
    SPRINT.md) echo 320 ;;
    PITFALLS.md) echo 500 ;;
    ARCHITECTURE.md) echo 320 ;;
    SOURCEMAP.md) echo 120 ;;
    AGENTS.md|CLAUDE.md) echo 45 ;;
    *) echo 0 ;;
  esac
}

if [[ ! -f "$MAP" ]]; then
  fail "engine/ENGINE_MAP.md is missing"
  echo "  human: The project's main index file (ENGINE_MAP.md) is missing. Run 'engine init' to create it."
  printf '\nEngine Doctor: %s failure(s), %s warning(s)\n' "$fail_count" "$warn_count"
  exit 1
fi

pass "ENGINE_MAP exists"

profile="$(grep -E '^\|[[:space:]]*Active profile[[:space:]]*\|' "$MAP" | head -n 1 | awk -F'|' '{print $3}' | tr -d ' `' || true)"
if [[ -z "$profile" ]]; then
  profile="$(grep -E 'Active profile:' "$MAP" | head -n 1 | sed -E 's/.*Active profile:[[:space:]]*\**([^* （(]+).*/\1/' | tr -d ' `' || true)"
fi
[[ -z "$profile" ]] && warn "Active profile not found in ENGINE_MAP §0" && echo "  human: The active profile (e.g. CLI-LEAN, FULL) is not declared in ENGINE_MAP. Add an 'Active profile' row to section 0 of ENGINE_MAP.md."

registered_tmp="$(mktemp)"
section_tmp="$(mktemp)"
anchor_tmp="$(mktemp)"
plan_tmp="$(mktemp)"
cleanup() { rm -f "${registered_tmp:-}" "${section_tmp:-}" "${anchor_tmp:-}" "${plan_tmp:-}" "${tmp:-}" "${tmp2:-}" "${tmp3:-}" "${tmp4:-}"; }
trap 'on_error ${LINENO}; cleanup' ERR
trap 'cleanup' EXIT

awk '
  /^## (1\.|§1[[:space:]])/ { in_reg=1; next }
  /^### (1\.1|§1\.1)/ { in_reg=0 }
  /^## (§4|4\.|2\.|§2|3\.|§3)/ { in_reg=0 }
  in_reg && /^\|/ { print }
' "$MAP" > "$registered_tmp"

awk '
  /^### (1\.1|§1\.1)/ { in_sec=1; next }
  /^### (1\.2|§1\.2)/ { in_sec=0 }
  in_sec && /^\|/ { print }
' "$MAP" > "$section_tmp"

awk '
  /^### (1\.2|§1\.2)/ { in_anchor=1; next }
  /^## (2\.|§2)/ { in_anchor=0 }
  in_anchor && /^\|/ { print }
' "$MAP" > "$anchor_tmp"

awk '
  /^## (2\.|§2)/ { in_plan=1; next }
  /^## (3\.|§3)/ { in_plan=0 }
  in_plan && /^\|/ { print }
' "$MAP" > "$plan_tmp"

registered_names=""
while IFS='|' read -r _ file class priority revision verified _; do
  file="$(trim "$file")"
  class="$(trim "$class")"
  priority="$(trim "$priority")"
  [[ -z "$file" || "$file" == "File" || "$file" == "文件" || "$file" =~ ^-+$ || "$file" == \[* ]] && continue
  registered_names="$registered_names $file"
  case "$class" in
    index|irreducible|derivable|mixed|anchor|generated-cache) ;;
    *) fail "$file has illegal class '$class' in ENGINE_MAP §1"
       echo "  human: The file '$file' has an invalid class type '$class' in ENGINE_MAP. Valid classes are: index, irreducible, derivable, mixed, anchor, generated-cache." ;;
  esac
  [[ -z "$priority" ]] && fail "$file has empty read priority" && echo "  human: The file '$file' has no read priority set in ENGINE_MAP. Add a priority value (e.g. must, should, optional) in the priority column."
  path="$(engine_path "$file")"
  if [[ -f "$path" ]]; then
    pass "registered file exists: $file"
  else
    fail "registered file missing: $file"
    echo "  human: The file '$file' is registered in ENGINE_MAP but does not exist on disk. Create the file or remove its entry from ENGINE_MAP."
  fi
  cap="$(budget_cap "$file")"
  if [[ "$cap" -gt 0 && -f "$path" ]]; then
    lines="$(wc -l < "$path" | tr -d ' ')"
    if [[ "$lines" -gt "$cap" ]]; then
      warn "$file exceeds hard budget ($lines > $cap lines)"
      echo "  human: The file '$file' has $lines lines, exceeding its $cap-line size limit. Trim it down to stay within the budget."
    fi
    # Byte budget: line cap × 200 (normal markdown ~50-100 chars/line; 200 gives headroom).
    # Catches single-line bloat that line-count misses (e.g. table cells padded to 19K chars).
    bytes="$(wc -c < "$path" | tr -d ' ')"
    byte_cap=$((cap * 200))
    if [[ "$bytes" -gt "$byte_cap" ]]; then
      warn "$file exceeds byte budget ($bytes > $byte_cap bytes)"
      echo "  human: The file '$file' is $bytes bytes, exceeding its $byte_cap-byte size limit (likely single-line bloat). Check for table cells padded with excessive whitespace."
    fi
    # Line width: 2000 chars max. Normal markdown tables/paragraphs rarely exceed 1200;
    # 2000 gives headroom. Catches table cells padded to tens of thousands of chars.
    # v6.17.3 (T-064): use perl -CSD for UTF-8 character counting. awk length()
    # returns byte count in C/POSIX locale (Windows Git Bash default), causing
    # false positives on lines with multi-byte chars (e.g. Chinese = 3 bytes/char).
    # perl -CSD decodes UTF-8 correctly. awk is fallback when perl unavailable.
    if command -v perl >/dev/null 2>&1; then
      longest="$(perl -CSD -ne 'chomp; $max = length($_) if length($_) > $max; END { print $max+0 }' "$path")"
    else
      longest="$(awk '{ if (length > max) max = length } END { print max+0 }' "$path")"
    fi
    if [[ "$longest" -gt 2000 ]]; then
      warn "$file has very long line ($longest > 2000 chars)"
      echo "  human: The file '$file' has a line $longest characters long (max 2000). This is likely a padded table row or separator. Remove the excessive padding."
    fi
  fi
  if [[ "$class" == "mixed" ]] && ! grep -F "| $file |" "$section_tmp" >/dev/null 2>&1; then
    fail "$file is mixed but missing §1.1 section-class row"
    echo "  human: The file '$file' is classified as 'mixed' but has no section breakdown in ENGINE_MAP section 1.1. Add a row for it in the section-class table."
  fi
  if [[ "$profile" == "CLI-LEAN" && "$class" == "derivable" && -f "$path" ]]; then
    lines="$(wc -l < "$path" | tr -d ' ')"
    [[ "$lines" -gt 120 ]] && warn "$file is derivable in CLI-LEAN and longer than stub budget" && echo "  human: The file '$file' is auto-derivable and too long for CLI-LEAN mode ($lines lines > 120). Replace its content with a short stub or summary."
    if grep -E '^[[:space:]]*(├|└|│)|file inventory|directory tree|module count|version dump' "$path" >/dev/null 2>&1; then
      warn "$file may contain live derivable inventory in CLI-LEAN"
      echo "  human: The file '$file' appears to contain live file/directory listings that should be auto-generated, not stored. In CLI-LEAN mode, replace this with a pointer to the generation command."
    fi
  fi
done < "$registered_tmp"

is_registered() {
  local candidate="$1"
  for name in $registered_names; do
    [[ "$name" == "$candidate" ]] && return 0
    [[ "engine/$name" == "$candidate" ]] && return 0
  done
  return 1
}

is_registered_name() {
  local candidate="$1"
  for name in $registered_names; do
    [[ "$name" == "$candidate" || "$name" == "engine/$candidate" ]] && return 0
  done
  return 1
}

require_section() {
  local file="$1" path="$2" pattern="$3" label="$4"
  if ! grep -Eq "$pattern" "$path"; then
    warn "$file is missing semantic section: $label"
    echo "  human: The file '$file' is missing a required section titled '$label'. Add this section to keep the engine file complete."
  fi
}

check_context_semantics() {
  is_registered_name "CONTEXT.md" || return 0
  local path="$ENGINE_DIR/CONTEXT.md"
  [[ -f "$path" ]] || return 0

  require_section "CONTEXT.md" "$path" '^##[[:space:]]+状态面板' "状态面板"
  for label in 构建 上次完成 进行中 阻塞; do
    local row value
    row="$(grep -E "^\|[[:space:]]*$label[[:space:]]*\|" "$path" | head -n 1 || true)"
    if [[ -z "$row" ]]; then
      warn "CONTEXT.md status panel missing row: $label"
      echo "  human: CONTEXT.md is missing the '$label' row in its status panel. Add a table row for '$label' with current information."
      continue
    fi
    value="$(printf '%s' "$row" | awk -F'|' '{print $3}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    if [[ -z "$value" || "$value" =~ ^\[.*\]$ || "$value" == "TBD" || "$value" == "TODO" ]]; then
      warn "CONTEXT.md status row '$label' is placeholder or empty"
      echo "  human: The '$label' row in CONTEXT.md has no real value (placeholder or empty). Fill in the actual status."
    fi
  done
}

check_handoff_semantics() {
  is_registered_name "HANDOFF.md" || return 0
  local path="$ENGINE_DIR/HANDOFF.md"
  [[ -f "$path" ]] || return 0

  require_section "HANDOFF.md" "$path" '^##[[:space:]]+立即恢复点' "立即恢复点"
  require_section "HANDOFF.md" "$path" '^##[[:space:]]+会话历史' "会话历史"
  if ! grep -Eq '^下一步[:：][[:space:]]*[^[:space:]\[]' "$path"; then
    warn "HANDOFF.md has no concrete next-step resume pointer"
    echo "  human: HANDOFF.md does not have a clear next-step instruction. Add a concrete '下一步' entry so the next session knows where to resume."
  fi
  if ! grep -Eq '^\|[[:space:]]*[0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]]*\|' "$path"; then
    warn "HANDOFF.md has no dated session history rows"
    echo "  human: HANDOFF.md has no dated session history entries. Add rows with dates (YYYY-MM-DD) to the session history table so future sessions can trace past work."
  fi
}

check_handoff_history_cap() {
  # v6.6 (D-027): HANDOFF history table ≤ 8 rows; older rows move to
  # engine/handoff-archive-YYYY-MM.md. Archive is search-only (not loaded
  # by SessionStart, not registered in ENGINE_MAP §1).
  is_registered_name "HANDOFF.md" || return 0
  local path="$ENGINE_DIR/HANDOFF.md"
  [[ -f "$path" ]] || return 0
  local history_count
  history_count="$(awk '
    /^##[[:space:]]+会话历史/ { in_hist=1; next }
    in_hist && /^##[[:space:]]/ { in_hist=0 }
    in_hist && /^\|[[:space:]]*[0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]]*\|/ { count++ }
    END { print count+0 }
  ' "$path")"
  if [[ "$history_count" -gt 8 ]]; then
    warn "HANDOFF.md history table has $history_count rows (> 8) - archive oldest to engine/handoff-archive-YYYY-MM.md"
    echo "  human: The HANDOFF.md session history table has $history_count rows. Keep only the most recent 8 in HANDOFF.md and move the rest to engine/handoff-archive-YYYY-MM.md (named by the month of the oldest moved row). The archive file is search-only and not loaded by SessionStart."
  fi
}

check_progress_md() {
  # v6.7.0 (D-028/T-032): task-level progress.md 7-section recovery anchor.
  # active/paused cards MUST have engine/tasks/T-NNN/progress.md;
  # done cards MUST have it archived to engine/archive/tasks/T-NNN-progress.md
  # (live copy removed, mirrors D-027 HANDOFF archive).
  # Migration grace period: projects stamped contract-version < 6.7.0 → WARN;
  # >= 6.7.0 → FAIL (see D-028 §9).
  local tasks_dir="$ENGINE_DIR/tasks"
  [ -d "$tasks_dir" ] || return 0

  # Read contract-version from ENGINE_DOCTOR.md managed block.
  local doctor_path="$ENGINE_DIR/ENGINE_DOCTOR.md"
  local contract_version=""
  if [ -f "$doctor_path" ]; then
    contract_version="$(grep -oE 'contract-version:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+' "$doctor_path" 2>/dev/null | head -1 | sed 's/.*contract-version:[[:space:]]*//')"
  fi
  # Parse "X.Y.Z" → cv_int = X*10000 + Y*100 + Z (for numeric compare).
  local cv_int=0
  if [[ "$contract_version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    cv_int=$(( ${BASH_REMATCH[1]} * 10000 + ${BASH_REMATCH[2]} * 100 + ${BASH_REMATCH[3]} ))
  fi
  local violation_is_fail=0
  if [ "$cv_int" -ge 60700 ] 2>/dev/null; then
    violation_is_fail=1
  fi

  local active_count=0 paused_count=0 done_count=0
  local active_missing=0 paused_missing=0 done_live=0
  local f
  for f in "$tasks_dir"/T-*.md; do
    [ -f "$f" ] || continue
    [[ "$f" == *.spec.md ]] && continue
    local tid; tid="$(basename "$f" .md)"
    local prog="$tasks_dir/$tid/progress.md"
    local archive="$ENGINE_DIR/archive/tasks/$tid-progress.md"
    if card_status_active "$f"; then
      active_count=$((active_count + 1))
      if [ ! -f "$prog" ]; then
        active_missing=$((active_missing + 1))
        if [ "$violation_is_fail" -eq 1 ]; then
          fail "task $tid (active) missing progress.md - copy engine/skeleton/progress.md to engine/tasks/$tid/progress.md"
          echo "  human: Active task $tid has no progress.md recovery anchor. SessionStart injects progress.md to survive context compression; without it, in-progress details may be lost. Run: cp engine/skeleton/progress.md engine/tasks/$tid/progress.md and fill in §1-§7."
        else
          warn "task $tid (active) missing progress.md (grace period, contract-version $contract_version < 6.7.0)"
          echo "  human: Active task $tid has no progress.md. Migration grace period is active (contract-version $contract_version < 6.7.0); WARN only. To fix: cp engine/skeleton/progress.md engine/tasks/$tid/progress.md."
        fi
      fi
    elif card_status_paused "$f"; then
      paused_count=$((paused_count + 1))
      if [ ! -f "$prog" ]; then
        paused_missing=$((paused_missing + 1))
        if [ "$violation_is_fail" -eq 1 ]; then
          fail "task $tid (paused) missing progress.md - copy engine/skeleton/progress.md to engine/tasks/$tid/progress.md"
          echo "  human: Paused task $tid has no progress.md recovery anchor. Without it, resuming the task after context loss requires re-reading all files. Run: cp engine/skeleton/progress.md engine/tasks/$tid/progress.md."
        else
          warn "task $tid (paused) missing progress.md (grace period, contract-version $contract_version < 6.7.0)"
        fi
      fi
    elif card_status_done "$f"; then
      done_count=$((done_count + 1))
      # Done cards: live progress.md should be archived (mirror D-027 HANDOFF).
      if [ -f "$prog" ]; then
        done_live=$((done_live + 1))
        if [ "$violation_is_fail" -eq 1 ]; then
          fail "task $tid (done) has live progress.md - archive to engine/archive/tasks/$tid-progress.md and remove live copy"
          echo "  human: Done task $tid still has a live progress.md at engine/tasks/$tid/progress.md. Done cards are cold history; archive the progress.md to engine/archive/tasks/$tid-progress.md (mirrors HANDOFF archive) and remove the live copy."
        else
          warn "task $tid (done) has live progress.md (grace period, contract-version $contract_version < 6.7.0)"
        fi
      fi
    fi
  done

  # Summary line when there are active/paused cards with progress.md present.
  local total_active=$((active_count + paused_count))
  if [ "$total_active" -gt 0 ]; then
    local total_missing=$((active_missing + paused_missing))
    if [ "$total_missing" -eq 0 ]; then
      pass "progress.md summary: $total_active active/paused task(s) all have progress.md (cv=$contract_version)"
    fi
  fi
  if [ "$done_live" -gt 0 ]; then
    : # Already reported per-task above; no extra summary needed.
  fi
}

# v6.8.0 (D-028/T-033): domain-level INVENTORY.md bidirectional FAIL check.
# (a) INVENTORY→code: every Entry file path in any engine/domains/<domain>/INVENTORY.md
#     row must exist (test -f);
# (b) code→INVENTORY: every file path touched by a `done` task card must be represented
#     in its domain's INVENTORY (Entry file column mentions it, or domain has ≥1 row).
# Migration grace period: contract-version < 6.8.0 → WARN; >= 6.8.0 → FAIL (D-028 §9).
check_inventory_bidirectional() {
  local domains_dir="$ENGINE_DIR/domains"
  [ -d "$domains_dir" ] || return 0

  local doctor_path="$ENGINE_DIR/ENGINE_DOCTOR.md"
  local contract_version=""
  if [ -f "$doctor_path" ]; then
    contract_version="$(grep -oE 'contract-version:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+' "$doctor_path" 2>/dev/null | head -1 | sed 's/.*contract-version:[[:space:]]*//')"
  fi
  local cv_int=0
  if [[ "$contract_version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    cv_int=$(( ${BASH_REMATCH[1]} * 10000 + ${BASH_REMATCH[2]} * 100 + ${BASH_REMATCH[3]} ))
  fi
  local violation_is_fail=0
  if [ "$cv_int" -ge 60800 ] 2>/dev/null; then
    violation_is_fail=1
  fi

  local inventory_files=()
  local f
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    inventory_files+=("$f")
  done < <(find "$domains_dir" -maxdepth 2 -type f -name 'INVENTORY.md' 2>/dev/null)

  if [ "${#inventory_files[@]}" -eq 0 ]; then
    # v6.12.1 (issue #11 D-2): "not initialized" must not be indistinguishable
    # from "checked and clean". Say so explicitly instead of silent green.
    pass "INVENTORY bidirectional: SKIP (not initialized - no engine/domains/*/INVENTORY.md yet)"
    return 0
  fi

  # (a) INVENTORY→code: Entry file paths must exist.
  local inv_to_code_violations=0
  local entry_paths_seen=""
  for inv in "${inventory_files[@]}"; do
    # Parse table rows: | Feature | Entry file | Public API | Status | Last verified |
    # Skip header rows (|---|) and lines starting with `#` or `>`.
    while IFS= read -r line; do
      [[ "$line" =~ ^[[:space:]]*$ ]] && continue
      [[ "$line" =~ ^# ]] && continue
      [[ "$line" =~ ^\> ]] && continue
      [[ "$line" == "<!--"* ]] && continue
      [[ "$line" =~ ^\|[[:space:]]*- ]] && continue
      [[ "$line" =~ ^\|[[:space:]]*Feature ]] && continue
      # Extract columns by splitting on `|`.
      local cols
      IFS='|' read -ra cols <<< "$line"
      # cols[0] is empty (leading `|`), cols[1]=Feature, cols[2]=Entry file, ...
      local entry_file=""
      if [ "${#cols[@]}" -ge 3 ]; then
        entry_file="$(printf '%s' "${cols[2]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
      fi
      [ -z "$entry_file" ] && continue
      # Skip placeholders / glob patterns.
      [[ "$entry_file" == \[*\]* ]] && continue
      [[ "$entry_file" == *"<"*">"* ]] && continue
      if [ ! -f "$ROOT/$entry_file" ] && [ ! -f "$entry_file" ]; then
        inv_to_code_violations=$((inv_to_code_violations + 1))
        if [ "$violation_is_fail" -eq 1 ]; then
          fail "INVENTORY→code: $inv references non-existent Entry file '$entry_file'"
          echo "  human: INVENTORY row in $inv points to '$entry_file' which does not exist. Fix the path or remove the row."
        else
          warn "INVENTORY→code: $inv references '$entry_file' (grace period, cv=$contract_version < 6.8.0)"
        fi
      else
        entry_paths_seen="$entry_paths_seen$entry_file"$'\n'
      fi
    done < "$inv"
  done

  # (b) code→INVENTORY: done task cards' touched files should appear in their domain INVENTORY.
  # For dogfood simplicity, we only check files explicitly listed in WRITE-SET of done task cards
  # whose domain field is non-empty. Full code↔domain mapping is the federation.json's job.
  local code_to_inv_violations=0
  local tasks_dir="$ENGINE_DIR/tasks"
  if [ -d "$tasks_dir" ]; then
    local task_file
    for task_file in "$tasks_dir"/T-*.md; do
      [ -f "$task_file" ] || continue
      [[ "$task_file" == *.spec.md ]] && continue
      card_status_done "$task_file" || continue
      local tid; tid="$(basename "$task_file" .md)"
      local write_set
      # v6.12.1 (issue #11 B-2): unified parser (inline/section/frontmatter).
      write_set="$(doctor_parse_task_patterns WRITE-SET "$task_file" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || true)"
      [ -z "$write_set" ] && continue
      local ws_path
      while IFS= read -r ws_path; do
        [ -z "$ws_path" ] && continue
        # Skip globs and engine/* meta paths (only check concrete files).
        [[ "$ws_path" == *"*"* ]] && continue
        [[ "$ws_path" == "engine/"* ]] && continue
        [[ "$ws_path" == "plugin/"* ]] && continue
        [[ "$ws_path" == "VERSION" ]] && continue
        [[ "$ws_path" == "CHANGELOG.md" ]] && continue
        [[ "$ws_path" == "AGENTS.md" ]] && continue
        [[ "$ws_path" == ".github/"* ]] && continue
        # Check if this path appears in any INVENTORY entry column.
        if ! printf '%s' "$entry_paths_seen" | grep -qF "$ws_path"; then
          code_to_inv_violations=$((code_to_inv_violations + 1))
          if [ "$violation_is_fail" -eq 1 ]; then
            fail "code→INVENTORY: $tid touched '$ws_path' but no INVENTORY row references it"
            echo "  human: Done task $tid touched file '$ws_path' which is not in any domain INVENTORY. Add a row (Feature / Entry file / Public API / Status / Last verified) to the appropriate engine/domains/<domain>/INVENTORY.md."
          else
            warn "code→INVENTORY: $tid touched '$ws_path' (grace period, cv=$contract_version < 6.8.0)"
          fi
        fi
      done <<< "$write_set"
    done
  fi

  local total_inv="${#inventory_files[@]}"
  if [ "$inv_to_code_violations" -eq 0 ] && [ "$code_to_inv_violations" -eq 0 ]; then
    pass "INVENTORY bidirectional summary: $total_inv domain(s) checked, both directions clean (cv=$contract_version)"
  fi
}

# v6.8.0 (D-028 §10 mechanism C): INVENTORY Public API column must be unique across repo.
# Scans all engine/domains/*/INVENTORY.md + engine/domains/*/INVENTORY/*.md files.
# Migration grace period: contract-version < 6.8.0 → WARN; >= 6.8.0 → FAIL (D-028 §9).
check_inventory_api_uniqueness() {
  local domains_dir="$ENGINE_DIR/domains"
  [ -d "$domains_dir" ] || return 0

  local doctor_path="$ENGINE_DIR/ENGINE_DOCTOR.md"
  local contract_version=""
  if [ -f "$doctor_path" ]; then
    contract_version="$(grep -oE 'contract-version:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+' "$doctor_path" 2>/dev/null | head -1 | sed 's/.*contract-version:[[:space:]]*//')"
  fi
  local cv_int=0
  if [[ "$contract_version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    cv_int=$(( ${BASH_REMATCH[1]} * 10000 + ${BASH_REMATCH[2]} * 100 + ${BASH_REMATCH[3]} ))
  fi
  local violation_is_fail=0
  if [ "$cv_int" -ge 60800 ] 2>/dev/null; then
    violation_is_fail=1
  fi

  # Collect all inventory files: top-level INVENTORY.md + sub-files INVENTORY/*.md.
  local inventory_files=()
  local f
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    inventory_files+=("$f")
  done < <(find "$domains_dir" -maxdepth 3 -type f \( -name 'INVENTORY.md' -o -path '*/INVENTORY/*.md' \) 2>/dev/null)

  if [ "${#inventory_files[@]}" -eq 0 ]; then
    # v6.12.1 (issue #11 D-2): explicit SKIP instead of silent green.
    pass "INVENTORY API uniqueness: SKIP (not initialized)"
    return 0
  fi

  # Extract Public API column (3rd column) from each table row.
  # Save as "api<TAB>file" pairs to detect duplicates.
  local tmpfile; tmpfile="$(mktemp)"
  trap 'rm -f "$tmpfile"' RETURN
  local inv
  for inv in "${inventory_files[@]}"; do
    while IFS= read -r line; do
      [[ "$line" =~ ^[[:space:]]*$ ]] && continue
      [[ "$line" =~ ^# ]] && continue
      [[ "$line" =~ ^\> ]] && continue
      [[ "$line" == "<!--"* ]] && continue
      [[ "$line" =~ ^\|[[:space:]]*- ]] && continue
      [[ "$line" =~ ^\|[[:space:]]*Feature ]] && continue
      local cols
      IFS='|' read -ra cols <<< "$line"
      # cols[3] = Public API (0=empty, 1=Feature, 2=Entry, 3=Public API)
      local api=""
      if [ "${#cols[@]}" -ge 4 ]; then
        api="$(printf '%s' "${cols[3]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
      fi
      [ -z "$api" ] && continue
      [[ "$api" == \[*\]* ]] && continue
      [[ "$api" == *"<"*">"* ]] && continue
      printf '%s\t%s\n' "$api" "$inv" >> "$tmpfile"
    done < "$inv"
  done

  # Find duplicate API names.
  local dups
  dups="$(awk -F'\t' '{print $1}' "$tmpfile" | sort | uniq -d)"
  local dup_count=0
  if [ -n "$dups" ]; then
    while IFS= read -r dup; do
      [ -z "$dup" ] && continue
      dup_count=$((dup_count + 1))
      local occurrences
      occurrences="$(grep -F "$(printf '%s\t' "$dup")" "$tmpfile" | awk -F'\t' '{print $2}' | sort -u | tr '\n' ' ')"
      if [ "$violation_is_fail" -eq 1 ]; then
        fail "INVENTORY API uniqueness: '$dup' appears in multiple inventory files: $occurrences"
        echo "  human: Public API contract name '$dup' is duplicated across INVENTORY files. Rename one, or mark the deprecated one with Status=deprecated and a clear successor note."
      else
        warn "INVENTORY API uniqueness: '$dup' duplicated (grace period, cv=$contract_version < 6.8.0)"
      fi
    done <<< "$dups"
  fi

  if [ "$dup_count" -eq 0 ]; then
    local total_apis; total_apis="$(wc -l < "$tmpfile" | tr -d ' ')"
    pass "INVENTORY API uniqueness: $total_apis API names across ${#inventory_files[@]} file(s), all unique (cv=$contract_version)"
  fi
}

# v6.9.0 (D-028 §10 mechanism A / T-034 AC-5.1): WRITE-SET static budget soft gate.
# Sums `wc -c` of all files listed in active card's WRITE-SET; > 30KB triggers
# soft gate (FAIL unless checkpoint_plan field is declared, D-028 §9 tryout bypass).
# Migration grace period: contract-version < 6.9.0 -> WARN; >= 6.9.0 -> FAIL.
check_writeset_budget() {
  local tasks_dir="$ENGINE_DIR/tasks"
  [ -d "$tasks_dir" ] || return 0

  local doctor_path="$ENGINE_DIR/ENGINE_DOCTOR.md"
  local contract_version=""
  if [ -f "$doctor_path" ]; then
    contract_version="$(grep -oE 'contract-version:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+' "$doctor_path" 2>/dev/null | head -1 | sed 's/.*contract-version:[[:space:]]*//' || true)"
  fi
  local cv_int=0
  if [[ "$contract_version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    cv_int=$(( ${BASH_REMATCH[1]} * 10000 + ${BASH_REMATCH[2]} * 100 + ${BASH_REMATCH[3]} ))
  fi
  local violation_is_fail=0
  if [ "$cv_int" -ge 60900 ] 2>/dev/null; then
    violation_is_fail=1
  fi

  local BUDGET_BYTES=30720  # 30KB
  local f
  for f in "$tasks_dir"/T-*.md; do
    [ -f "$f" ] || continue
    [[ "$f" == *.spec.md ]] && continue
    card_status_active "$f" || continue
    local tid; tid="$(basename "$f" .md)"
    # checkpoint_plan bypass: any non-empty value (incl. tryout) downgrades FAIL->WARN.
    local checkpoint_plan
    checkpoint_plan="$(grep -oE 'checkpoint_plan:[[:space:]]*[^|]*' "$f" 2>/dev/null | head -1 | sed 's/.*checkpoint_plan:[[:space:]]*//' | tr -d ' \t' || true)"
    local has_bypass=0
    if [ -n "$checkpoint_plan" ]; then has_bypass=1; fi

    # Sum wc -c of all concrete files in WRITE-SET (skip globs).
    local write_set_line
    write_set_line="$(grep '^WRITE-SET:' "$f" 2>/dev/null | head -1 | sed 's/^WRITE-SET:[[:space:]]*//' || true)"
    [ -z "$write_set_line" ] && continue
    local total_bytes=0
    local ws_path
    local IFS_save="$IFS"
    IFS=','
    for ws_path in $write_set_line; do
      ws_path="$(printf '%s' "$ws_path" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
      [ -z "$ws_path" ] && continue
      # Skip globs.
      [[ "$ws_path" == *"*"* ]] && continue
      local full="$ROOT/$ws_path"
      if [ -f "$full" ]; then
        local sz; sz="$(wc -c < "$full" 2>/dev/null | tr -d ' ' || echo 0)"
        total_bytes=$((total_bytes + sz))
      fi
    done
    IFS="$IFS_save"
    if [ "$total_bytes" -gt "$BUDGET_BYTES" ]; then
      local kb=$((total_bytes / 1024))
      if [ "$has_bypass" -eq 1 ]; then
        warn "task $tid WRITE-SET budget ${kb}KB > 30KB but checkpoint_plan declared (bypass, cv=$contract_version)"
      elif [ "$violation_is_fail" -eq 1 ]; then
        fail "task $tid WRITE-SET budget ${kb}KB > 30KB - split card or declare checkpoint_plan"
        echo "  human: Active task $tid has WRITE-SET totaling ${kb}KB across listed files (threshold 30KB ~ 8000 tokens). Either split into smaller cards, or add a 'checkpoint_plan: <text or tryout>' field to the task card header to declare a bypass (D-028 §9)."
      else
        warn "task $tid WRITE-SET budget ${kb}KB > 30KB (grace period, cv=$contract_version < 6.9.0)"
      fi
    fi
  done
}

# v6.9.0 (D-028 §9 / T-034 AC-6): task granularity soft gate.
# 4 thresholds: AC count > 12, WRITE-SET distinct paths > 15, estimated_steps > 20,
# WRITE-SET bytes > 30KB (delegated to check_writeset_budget).
# Any threshold hit and no checkpoint_plan field = FAIL; declaring checkpoint_plan
# (non-empty, including `tryout`) downgrades FAIL->WARN.
# Migration grace period: contract-version < 6.9.0 -> WARN; >= 6.9.0 -> FAIL.
check_task_granularity() {
  local tasks_dir="$ENGINE_DIR/tasks"
  [ -d "$tasks_dir" ] || return 0

  local doctor_path="$ENGINE_DIR/ENGINE_DOCTOR.md"
  local contract_version=""
  if [ -f "$doctor_path" ]; then
    contract_version="$(grep -oE 'contract-version:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+' "$doctor_path" 2>/dev/null | head -1 | sed 's/.*contract-version:[[:space:]]*//' || true)"
  fi
  local cv_int=0
  if [[ "$contract_version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    cv_int=$(( ${BASH_REMATCH[1]} * 10000 + ${BASH_REMATCH[2]} * 100 + ${BASH_REMATCH[3]} ))
  fi
  local violation_is_fail=0
  if [ "$cv_int" -ge 60900 ] 2>/dev/null; then
    violation_is_fail=1
  fi

  local AC_THRESHOLD=12
  local PATH_THRESHOLD=15
  local STEPS_THRESHOLD=20

  local f
  for f in "$tasks_dir"/T-*.md; do
    [ -f "$f" ] || continue
    [[ "$f" == *.spec.md ]] && continue
    card_status_active "$f" || continue
    local tid; tid="$(basename "$f" .md)"

    # checkpoint_plan bypass: any non-empty value (incl. tryout) downgrades FAIL->WARN.
    local checkpoint_plan
    checkpoint_plan="$(grep -oE 'checkpoint_plan:[[:space:]]*[^|]*' "$f" 2>/dev/null | head -1 | sed 's/.*checkpoint_plan:[[:space:]]*//' | tr -d ' \t' || true)"
    local has_bypass=0
    if [ -n "$checkpoint_plan" ]; then has_bypass=1; fi

    # AC count: count lines starting with "AC:".
    # v6.12.1 (issue #11 E-3): grep -c already prints 0 on no-match (exit 1),
    # so `|| echo 0` appended a SECOND line ("0\n0") and every later integer
    # comparison died with "integer expression expected".
    local ac_count
    ac_count="$(grep -c '^AC:' "$f" 2>/dev/null || true)"
    case "$ac_count" in ''|*[!0-9]*) ac_count=0 ;; esac

    # WRITE-SET distinct paths: count comma-separated entries, de-dup mirror pairs
    # (engine/X and plugin/engine/X count as 1).
    local write_set_line
    write_set_line="$(grep '^WRITE-SET:' "$f" 2>/dev/null | head -1 | sed 's/^WRITE-SET:[[:space:]]*//' || true)"
    local distinct_count=0
    if [ -n "$write_set_line" ]; then
      local seen_tmp; seen_tmp="$(mktemp)"
      trap 'rm -f "$seen_tmp"' RETURN
      local p
      local IFS_save="$IFS"
      IFS=','
      for p in $write_set_line; do
        p="$(printf '%s' "$p" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        [ -z "$p" ] && continue
        # De-dup mirror pairs: strip "plugin/" prefix for comparison.
        local canonical="$p"
        case "$p" in
          plugin/*) canonical="${p#plugin/}" ;;
        esac
        printf '%s\n' "$canonical" >> "$seen_tmp"
      done
      IFS="$IFS_save"
      distinct_count="$(sort -u "$seen_tmp" | wc -l | tr -d ' ')"
      rm -f "$seen_tmp"
    fi

    # estimated_steps: parse from header line "> estimated_steps: N | ..."
    local estimated_steps=0
    local es_line
    es_line="$(grep -oE 'estimated_steps:[[:space:]]*[0-9]+' "$f" 2>/dev/null | head -1 | sed 's/.*estimated_steps:[[:space:]]*//' || true)"
    if [ -n "$es_line" ]; then
      estimated_steps="$es_line"
    fi

    # Check thresholds.
    local hit=0
    local hit_msg=""
    if [ "$ac_count" -gt "$AC_THRESHOLD" ]; then
      hit=1; hit_msg="AC count $ac_count > $AC_THRESHOLD"
    fi
    if [ "$distinct_count" -gt "$PATH_THRESHOLD" ]; then
      hit=1; hit_msg="$hit_msg; WRITE-SET distinct paths $distinct_count > $PATH_THRESHOLD"
    fi
    if [ "$estimated_steps" -gt 0 ] && [ "$estimated_steps" -gt "$STEPS_THRESHOLD" ]; then
      hit=1; hit_msg="$hit_msg; estimated_steps $estimated_steps > $STEPS_THRESHOLD"
    fi

    if [ "$hit" -eq 1 ]; then
      if [ "$has_bypass" -eq 1 ]; then
        warn "task $tid granularity soft gate hit ($hit_msg) but checkpoint_plan declared (bypass, cv=$contract_version)"
      elif [ "$violation_is_fail" -eq 1 ]; then
        fail "task $tid granularity soft gate hit ($hit_msg) - split card or declare checkpoint_plan"
        echo "  human: Active task $tid exceeds granularity thresholds ($hit_msg). Either split into smaller cards, or add a 'checkpoint_plan: <text or tryout>' field to the task card header to declare a bypass (D-028 §9)."
      else
        warn "task $tid granularity soft gate hit ($hit_msg) (grace period, cv=$contract_version < 6.9.0)"
      fi
    fi
  done
}

# v6.9.0 (D-028 §9 / T-034 AC-6): depends-on dependency gate.
# Active card with `depends-on: T-NNN, T-NNN` field where any upstream is not done = FAIL.
# Cross-domain split coordination. Migration grace period: < 6.9.0 -> WARN; >= 6.9.0 -> FAIL.
check_depends_on() {
  local tasks_dir="$ENGINE_DIR/tasks"
  [ -d "$tasks_dir" ] || return 0

  local doctor_path="$ENGINE_DIR/ENGINE_DOCTOR.md"
  local contract_version=""
  if [ -f "$doctor_path" ]; then
    contract_version="$(grep -oE 'contract-version:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+' "$doctor_path" 2>/dev/null | head -1 | sed 's/.*contract-version:[[:space:]]*//' || true)"
  fi
  local cv_int=0
  if [[ "$contract_version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    cv_int=$(( ${BASH_REMATCH[1]} * 10000 + ${BASH_REMATCH[2]} * 100 + ${BASH_REMATCH[3]} ))
  fi
  local violation_is_fail=0
  if [ "$cv_int" -ge 60900 ] 2>/dev/null; then
    violation_is_fail=1
  fi

  local f
  for f in "$tasks_dir"/T-*.md; do
    [ -f "$f" ] || continue
    [[ "$f" == *.spec.md ]] && continue
    card_status_active "$f" || continue
    local tid; tid="$(basename "$f" .md)"

    # Parse depends-on field (comma-separated list of T-NNN).
    local depends_line
    depends_line="$(grep -oE 'depends-on:[[:space:]]*[^|]*' "$f" 2>/dev/null | head -1 | sed 's/.*depends-on:[[:space:]]*//' || true)"
    # Also accept depends_on (underscore form).
    if [ -z "$depends_line" ]; then
      depends_line="$(grep -oE 'depends_on:[[:space:]]*[^|]*' "$f" 2>/dev/null | head -1 | sed 's/.*depends_on:[[:space:]]*//' || true)"
    fi
    [ -z "$depends_line" ] && continue

    local IFS_save="$IFS"
    IFS=','
    local upstream
    for upstream in $depends_line; do
      upstream="$(printf '%s' "$upstream" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
      [ -z "$upstream" ] && continue
      # Validate format T-NNN.
      [[ "$upstream" =~ ^T-[0-9]+$ ]] || continue
      local upstream_file="$tasks_dir/$upstream.md"
      if [ ! -f "$upstream_file" ]; then
        if [ "$violation_is_fail" -eq 1 ]; then
          fail "task $tid depends-on $upstream but upstream card not found"
          echo "  human: Active task $tid declares depends-on: $upstream, but no task card exists at engine/tasks/$upstream.md. Remove the depends-on entry or create the upstream card."
        else
          warn "task $tid depends-on $upstream not found (grace period, cv=$contract_version < 6.9.0)"
        fi
        continue
      fi
      if ! card_status_done "$upstream_file"; then
        if [ "$violation_is_fail" -eq 1 ]; then
          fail "task $tid depends-on $upstream which is not done - block active"
          echo "  human: Active task $tid declares depends-on: $upstream, but $upstream is not done. Either complete $upstream first (run 'engine verify $upstream' and mark done), or remove the depends-on entry if the dependency no longer applies."
        else
          warn "task $tid depends-on $upstream not done (grace period, cv=$contract_version < 6.9.0)"
        fi
      fi
    done
    IFS="$IFS_save"
  done
}

# v6.10.0 (D-028/T-035): warn_count → done gate. For any task card whose
# evidence/T-NNN/DEAD-CODE.json exists:
#  - top-level exempt_all: true  → pass (batch exemption, D-028 §9)
#  - summary.warn_count == 0     → pass (clean)
#  - all entries[].exempt: true → pass (per-entry exemption, fine-grained)
#  - otherwise: warn_count > 0 with unexempted entries → FAIL (or WARN if
#    contract-version < 6.10.0 grace period, aligned with D-028 §9).
# The check applies to any task with DEAD-CODE.json present (active or done).
# Architectural exemption is via top-level exempt_all + exempt_reason, or
# per-entry exempt + exempt_reason.
check_warn_done_gate() {
  local tasks_dir="$ENGINE_DIR/tasks"
  [ -d "$tasks_dir" ] || return 0

  local doctor_path="$ENGINE_DIR/ENGINE_DOCTOR.md"
  local contract_version=""
  if [ -f "$doctor_path" ]; then
    contract_version="$(grep -oE 'contract-version:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+' "$doctor_path" 2>/dev/null | head -1 | sed 's/.*contract-version:[[:space:]]*//' || true)"
  fi
  local cv_int=0
  if [[ "$contract_version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    cv_int=$(( ${BASH_REMATCH[1]} * 10000 + ${BASH_REMATCH[2]} * 100 + ${BASH_REMATCH[3]} ))
  fi
  local violation_is_fail=0
  if [ "$cv_int" -ge 61000 ] 2>/dev/null; then
    violation_is_fail=1
  fi

  local f
  local dc_missing=0
  for f in "$tasks_dir"/T-*.md; do
    [ -f "$f" ] || continue
    [[ "$f" == *.spec.md ]] && continue
    # Gate applies only to `done` tasks — active/paused tasks may have
    # in-progress DEAD-CODE.json with warn_count > 0 (architect hasn't
    # reviewed yet). The done gate fires when architect marks done.
    card_status_done "$f" || continue
    local tid; tid="$(basename "$f" .md)"
    local dc_file="$ENGINE_DIR/evidence/$tid/DEAD-CODE.json"
    # v6.12.1 (issue #11 D-2): count silent skips instead of hiding them.
    if [ ! -f "$dc_file" ]; then
      dc_missing=$((dc_missing + 1))
      continue
    fi

    # Top-level exempt_all: true → batch exemption (D-028 §9).
    if grep -Eq '"exempt_all"[[:space:]]*:[[:space:]]*true' "$dc_file" 2>/dev/null; then
      pass "task $tid DEAD-CODE.json exempt_all:true (batch exemption)"
      continue
    fi

    # Read summary.warn_count (grep -oE + extract trailing integer).
    local warn_count=0
    local wc_match
    wc_match="$(grep -oE '"warn_count"[[:space:]]*:[[:space:]]*[0-9]+' "$dc_file" 2>/dev/null | head -1 || true)"
    if [ -n "$wc_match" ]; then
      warn_count="$(printf '%s' "$wc_match" | grep -oE '[0-9]+$' || echo 0)"
    fi

    if [ "$warn_count" -eq 0 ]; then
      pass "task $tid DEAD-CODE.json warn_count=0 (clean)"
      continue
    fi

    # warn_count > 0: count per-entry exempt fields. Pattern `"exempt":` is
    # specific to per-entry (top-level is `"exempt_all":`, reason is
    # `"exempt_reason":`, count is `"exempt_count":` — none collide).
    # NOTE: `grep -c` returns exit 1 with no match — `|| echo 0` would append
    # a second "0" line and produce "0\n0", breaking the integer comparison
    # below. Use `|| true` and rely on `:-0` defaulting instead.
    local total_entries exempt_entries
    total_entries=$(grep -cE '"exempt"[[:space:]]*:[[:space:]]*' "$dc_file" 2>/dev/null || true)
    total_entries=${total_entries:-0}
    exempt_entries=$(grep -cE '"exempt"[[:space:]]*:[[:space:]]*true' "$dc_file" 2>/dev/null || true)
    exempt_entries=${exempt_entries:-0}
    # Defensive: if total_entries is 0 (parse failed), skip rather than
    # falsely failing on an unparseable file.
    if [ "$total_entries" -eq 0 ]; then
      warn "task $tid DEAD-CODE.json has warn_count=$warn_count but no entries[] parsed (skip)"
      continue
    fi

    if [ "$exempt_entries" -eq "$total_entries" ]; then
      pass "task $tid DEAD-CODE.json all $total_entries entries exempt (warn_count=$warn_count)"
      continue
    fi

    local unexempt=$((total_entries - exempt_entries))
    if [ "$violation_is_fail" -eq 1 ]; then
      fail "task $tid DEAD-CODE.json has $unexempt unexempted warn entry/entries (warn_count=$warn_count) - mark exempt:true or top-level exempt_all:true"
      echo "  human: Task $tid has dead-code warnings ($warn_count warn, $unexempt not exempted). Architect must review evidence/$tid/DEAD-CODE.json and mark each entry \"exempt\": true with a reason, or set top-level \"exempt_all\": true with \"exempt_reason\"."
    else
      warn "task $tid DEAD-CODE.json has $unexempt unexempted warn entry/entries (grace period, cv=$contract_version < 6.10.0)"
      echo "  human: Task $tid has dead-code warnings ($warn_count warn, $unexempt not exempted). Migration grace period (cv=$contract_version < 6.10.0); WARN only. To fix: mark exemptions in evidence/$tid/DEAD-CODE.json."
    fi
  done
  # v6.12.1 (issue #11 D-2): "no DEAD-CODE evidence" and "checked clean" must
  # not collapse into the same silence. One summary line, no per-card spam
  # (cards predating v6.10.0 legitimately have no DEAD-CODE.json).
  if [ "$dc_missing" -gt 0 ]; then
    pass "warn-done gate: $dc_missing done card(s) have no DEAD-CODE.json (not initialized - predates v6.10.0, skipped)"
  fi
}

# v6.12.1 (issue #11 C-1): a single card must never satisfy both the active and
# done predicates. When it does (frontmatter says done, a stray anchored line
# says active), every downstream gate disagrees about reality - report the
# contradiction itself instead of letting the diagnostics fight.
check_status_conflict() {
  local tasks_dir="$ENGINE_DIR/tasks"
  [ -d "$tasks_dir" ] || return 0
  local f tid
  for f in "$tasks_dir"/T-*.md; do
    [ -f "$f" ] || continue
    [[ "$f" == *.spec.md ]] && continue
    if card_status_active "$f" && card_status_done "$f"; then
      tid="$(basename "$f" .md)"
      fail "task $tid declares BOTH active and done status lines - card state is self-contradictory"
      echo "  human: engine/tasks/$tid.md contains an anchored 'status: active' line AND an anchored 'status: done' line. Gates cannot agree which one governs. Remove the stale line so the card has exactly one status."
    fi
  done
}

check_pitfalls_semantics() {
  is_registered_name "PITFALLS.md" || return 0
  local path="$ENGINE_DIR/PITFALLS.md"
  [[ -f "$path" ]] || return 0

  grep -Eq '^##[[:space:]]+(条目|Entries)' "$path" || { warn "PITFALLS.md is missing entries section"; echo "  human: PITFALLS.md is missing the 'Entries' (条目) section. Add a '## Entries' heading with your pitfall records."; }
  grep -Eq '^##[[:space:]]+(索引|Index)' "$path" || { warn "PITFALLS.md is missing index section"; echo "  human: PITFALLS.md is missing the 'Index' (索引) section. Add a '## Index' heading with a searchable index of all pitfalls."; }

  local ids
  ids="$(grep -E '^###[[:space:]]+P[0-9]{3}[[:space:]]+[—-]' "$path" | sed -E 's/^###[[:space:]]+(P[0-9]{3}).*/\1/' || true)"
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    local body
    body="$(awk -v id="$id" '
      $0 ~ "^###[[:space:]]+" id "[[:space:]]+[—-]" { in_entry=1; print; next }
      in_entry && $0 ~ "^###[[:space:]]+P[0-9]{3}[[:space:]]+[—-]" { exit }
      in_entry { print }
    ' "$path")"
    for field in 严重程度 类别 状态 你能观察到的现象 错误做法 正确做法 触发条件 验证方式; do
      if ! printf '%s\n' "$body" | grep -F "**$field：**" >/dev/null 2>&1; then
        warn "$id is missing pitfall field: $field"
        echo "  human: Pitfall entry $id is missing the required '$field' field. Add it to make the pitfall record complete."
      fi
    done
  done <<< "$ids"
}

check_sprint_semantics() {
  is_registered_name "SPRINT.md" || return 0
  local path="$ENGINE_DIR/SPRINT.md"
  [[ -f "$path" ]] || return 0

  grep -Eq '完成标准|验收|Acceptance' "$path" || { warn "SPRINT.md has no completion criteria"; echo "  human: SPRINT.md does not define when work is considered complete. Add a 'Completion Criteria' or 'Acceptance' section."; }
  grep -Eiq '验证方法|verify|verification' "$path" || { warn "SPRINT.md has no verification method pointers"; echo "  human: SPRINT.md has no pointers to verification methods. Add a section describing how to verify sprint deliverables."; }
}

changed_paths() {
  command -v git >/dev/null 2>&1 || return 0
  git -C "$ROOT" status --short 2>/dev/null | sed -E 's/^[[:space:]]*[A-Z?]{1,2}[[:space:]]+//'
}

check_change_capsule_semantics() {
  local changes_dir="$ENGINE_DIR/changes"
  local latest=""
  if [[ -d "$changes_dir" ]]; then
    latest="$(find "$changes_dir" -maxdepth 1 -type f -name 'CHANGE-*.md' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n 1 | cut -d' ' -f2-)"
    if [[ -z "$latest" ]]; then
      latest="$(find "$changes_dir" -maxdepth 1 -type f -name 'CHANGE-*.md' 2>/dev/null | sort | tail -n 1)"
    fi
  fi

  local meaningful=false
  while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    case "$path" in
      engine/changes/*|engine/.cache/*|.git/*|archive/*) continue ;;
    esac
    meaningful=true
    break
  done < <(changed_paths)

  if [[ "$meaningful" == true && -z "$latest" ]]; then
    warn "meaningful changed files exist but no change capsule was found in engine/changes"
    echo "  human: You have uncommitted changes but no change log file. Create a CHANGE-*.md file in engine/changes/ to document what you changed and why."
    return 0
  fi

  [[ -z "$latest" ]] && return 0
  pass "latest change capsule exists: ${latest#"$ROOT/"}"

  local section
  for section in \
    "Goal" \
    "Actual Changes" \
    "Impact Scope" \
    "Risk & Watchpoints" \
    "Verification" \
    "Rollback" \
    "Next Step" \
    "Responsibility Boundary"
  do
    if ! grep -Eq "^##[[:space:]]+$section[[:space:]]*$" "$latest"; then
      warn "$(basename "$latest") is missing change capsule section: $section"
      echo "  human: The change log '$(basename "$latest")' is missing the '$section' section. Add a '## $section' heading with the relevant content."
    fi
  done
  if grep -Eq '\[.*\]|TBD|TODO' "$latest"; then
    warn "$(basename "$latest") still contains placeholders"
    echo "  human: The change log '$(basename "$latest")' still has unfilled placeholders like [TBD] or TODO. Replace them with actual content."
  fi
}

check_contract_compile() {
  local src_dir="$ROOT/contract/src"
  local dist="$ROOT/ENGINE_FILE_SYSTEM_v5.md"
  local compile_sh="$ROOT/contract/compile.sh"
  [ -d "$src_dir" ] || return 0
  [ -f "$dist" ] || { warn "contract dist missing: $dist"; echo "  human: The compiled contract file is missing. Run 'bash contract/compile.sh' to generate it from source."; return; }
  [ -f "$compile_sh" ] || { warn "contract compile.sh missing"; echo "  human: The contract compile script is missing. Ensure contract/compile.sh exists in your project."; return; }
  local tmp; tmp="$(mktemp)"
  local banner='<!-- ENGINE_FILE_SYSTEM_v5.md: compiled from contract/src/*.md by engine compile. Do not edit dist directly; edit src and recompile. -->'
  { printf '%s\n' "$banner"; for m in "$src_dir"/[0-9]*.md; do [ -f "$m" ] || continue; cat "$m"; done; } > "$tmp"
  if diff -q "$tmp" "$dist" >/dev/null 2>&1; then
    pass "contract compile idempotent (compile(src) == dist)"
  else
    fail "contract dist is not compile(src) - run bash contract/compile.sh; do not edit dist directly"
    echo "  human: The compiled contract file is out of date. Run 'bash contract/compile.sh' to regenerate it. Do not edit the dist file directly."
  fi
  rm -f "$tmp"
  # D-015: 第 4 dist(engine-init.md = 横幅 + cli-preamble + 同一模块)同样幂等
  local init_dist="$ROOT/plugin/.claude/commands/engine-init.md"
  local preamble="$src_dir/cli-preamble.md"
  if [ -f "$preamble" ] && [ -f "$init_dist" ]; then
    local init_banner='<!-- plugin/.claude/commands/engine-init.md: compiled from contract/src/ (cli-preamble.md + [0-9]*.md) by engine compile. Do not edit dist directly; edit src and recompile. -->'
    local tmp2; tmp2="$(mktemp)"
    { printf '%s\n' "$init_banner"; cat "$preamble"; for m in "$src_dir"/[0-9]*.md; do [ -f "$m" ] || continue; cat "$m"; done; } > "$tmp2"
    if diff -q "$tmp2" "$init_dist" >/dev/null 2>&1; then
      pass "contract compile idempotent (engine-init.md == compile(preamble+src))"
    else
      fail "engine-init.md is not compile(src) - run bash contract/compile.sh; do not edit dist directly"
      echo "  human: The engine-init command file is out of date. Run 'bash contract/compile.sh' to regenerate it. Do not edit the output file directly."
    fi
    rm -f "$tmp2"
  fi
  local budget="$ROOT/contract/budget.json"
  if [ -f "$budget" ]; then
    local max_lines; max_lines="$(grep -o '"max_lines"[[:space:]]*:[[:space:]]*[0-9]*' "$budget" | grep -o '[0-9]*$' || true)"
    local src_lines; src_lines="$(cat "$src_dir"/[0-9]*.md 2>/dev/null | wc -l || true)"
    if [ -n "$max_lines" ] && [ "$src_lines" -le "$max_lines" ]; then
      pass "contract budget: src $src_lines lines <= $max_lines"
    elif [ -n "$max_lines" ]; then
      fail "contract budget exceeded: src $src_lines lines > $max_lines (subtraction rule: net-zero growth)"
      echo "  human: The contract source files have grown beyond the allowed budget ($src_lines > $max_lines lines). Trim content or apply the subtraction rule: new rules must offset existing ones to keep net-zero growth."
    fi
  fi
}

check_contract_debt() {
  local src_dir="$ROOT/contract/src"
  [ -d "$src_dir" ] || return 0
  local total_must; total_must="$(grep -hoE '\bMUST\b' "$src_dir"/[0-9]*.md 2>/dev/null | wc -l || true)"
  local rule_count; rule_count="$(grep -hE '\*\*[^*]*Rule \(v' "$src_dir"/[0-9]*.md 2>/dev/null | wc -l || true)"
  local debt=$((total_must - rule_count))
  local budget="$ROOT/contract/budget.json"
  local baseline=""
  if [ -f "$budget" ]; then
    baseline="$(grep -o '"debt_baseline"[[:space:]]*:[[:space:]]*[0-9]*' "$budget" | grep -o '[0-9]*$')"
  fi
  pass "contract debt: MUST=$total_must, gated Rules=$rule_count, debt=$debt${baseline:+, baseline=$baseline}"
  if [ -n "$baseline" ]; then
    if [ "$debt" -le "$baseline" ]; then
      pass "contract debt <= baseline ($debt <= $baseline) - net-zero holding"
    else
      warn "contract debt > baseline ($debt > $baseline) - move MUST into data tables (Rules/rules.json/federation.json)"
      echo "  human: There are more ungated MUST rules than allowed ($debt > $baseline). Move standalone MUST statements into structured data tables like Rules or federation.json to reduce contract debt."
    fi
  fi
}

# Evidence compatibility: current records use status=pass; pre-v6.13 records
# used verdict=PASS. Keep old cards readable while warning that re-verification
# will upgrade the evidence shape.
evidence_has_pass() {
  local content="${1:-}"
  printf '%s\n' "$content" | grep -Eiq '"status"[[:space:]]*:[[:space:]]*"pass"' && return 0
  printf '%s\n' "$content" | grep -Eiq '"status"[[:space:]]*:' && return 1
  printf '%s\n' "$content" | grep -Eiq '"verdict"[[:space:]]*:[[:space:]]*"pass"'
}

evidence_is_legacy_verdict() {
  local content="${1:-}"
  printf '%s\n' "$content" | grep -Eiq '"verdict"[[:space:]]*:[[:space:]]*"pass"' || return 1
  ! printf '%s\n' "$content" | grep -Eiq '"status"[[:space:]]*:'
}

check_task_card_done_evidence() {
  local tasks_dir="$ENGINE_DIR/tasks"
  local done_count=0 exempt_count=0 verified_count=0
  [ -d "$tasks_dir" ] || return 0
  for f in "$tasks_dir"/T-*.md; do
    [ -f "$f" ] || continue
    [[ "$f" == *.spec.md ]] && continue
    card_status_done "$f" || continue
    done_count=$((done_count + 1))
    local tid; tid="$(basename "$f" .md)"
    local ev_dir="$ENGINE_DIR/evidence/$tid"
    if grep -qi 'exempt' "$f" 2>/dev/null; then
      exempt_count=$((exempt_count + 1))
      continue
    fi
    local ac_ids ac_count missing ac ev
    ac_ids="$(parse_ac_declarations "$f" | cut -f1)"
    ac_count="$(printf '%s\n' "$ac_ids" | sed '/^$/d' | wc -l | tr -d ' ')"
    missing=""
    for ac in $ac_ids; do
      ev="$ev_dir/$ac.json"
      if [ ! -f "$ev" ]; then
        missing="${missing}${missing:+,}$ac"
      else
        ev_content="$(cat "$ev" 2>/dev/null || true)"
        if ! evidence_has_pass "$ev_content"; then
          missing="${missing}${missing:+,}$ac"
        elif evidence_is_legacy_verdict "$ev_content"; then
          warn "task $tid/$ac uses legacy verdict evidence (accepted; re-run 'engine verify $tid' to write status=pass)"
          echo "  human: Evidence for $tid/$ac uses the legacy verdict=PASS field. It is accepted for compatibility; re-run engine verify to upgrade it to status=pass."
        fi
      fi
    done
    if [ "$ac_count" -gt 0 ] 2>/dev/null && [ -z "$missing" ]; then
      verified_count=$((verified_count + 1))
    elif command -v git >/dev/null 2>&1 && git cat-file -e "HEAD:engine/tasks/$tid.md" 2>/dev/null; then
      [ -n "$missing" ] || missing="no declared AC"
      warn "task $tid (pre-existing in HEAD) done with AC evidence drift ($missing) - legacy card, run 'engine verify $tid' or mark exempt"
      echo "  human: Task $tid was 'done' in HEAD; evidence may have drifted. Re-verify or mark exempt."
    else
      [ -n "$missing" ] || missing="no declared AC"
      fail "task $tid done without complete PASS evidence ($missing) - run 'engine verify $tid' or mark exempt"
      echo "  human: Task $tid is marked 'done', but every declared AC needs a PASS evidence file. Missing/non-pass: $missing."
    fi
  done
  [ "$done_count" -eq 0 ] || pass "done task evidence summary: $done_count checked ($verified_count verified, $exempt_count exempt)"
}

# v6.20.0 (T-070): review evidence Doctor check (spec §3.3).
# 分档:新 done(HEAD status≠done)缺 evidence → FAIL;历史 done → WARN。
# 复用 check_task_card_done_evidence 的 HEAD status 比较逻辑(L1348-1386 precedent)。
check_review_evidence() {
  local tasks_dir="$ENGINE_DIR/tasks"
  [ -d "$tasks_dir" ] || return 0
  for f in "$tasks_dir"/T-*.md; do
    [ -f "$f" ] || continue
    [[ "$f" == *.spec.md ]] && continue
    card_status_done "$f" || continue
    local tid; tid="$(basename "$f" .md)"
    local review_file="$ENGINE_DIR/review/evidence/$tid/REVIEW.json"

    if [ ! -f "$review_file" ]; then
      # 判断 HEAD status:已 done → 历史 WARN;否则新 done FAIL
      if command -v git >/dev/null 2>&1 && git cat-file -e "HEAD:engine/tasks/$tid.md" 2>/dev/null \
        && git show "HEAD:engine/tasks/$tid.md" 2>/dev/null | grep -Eq '^[[:space:]]*(>[[:space:]]*)?status:[[:space:]]*done'; then
        warn "done task $tid missing review evidence (legacy)"
        echo "  human: Task $tid was 'done' in HEAD; review evidence missing (legacy). Run 'engine review $tid' or mark exempt."
      else
        fail "newly-done task $tid missing review evidence"
        echo "  human: Task $tid is marked 'done' but has no review evidence. Run 'engine review $tid'."
      fi
      continue
    fi

    # 校验 write_provenance
    local prov_writer prov_commit prov_argv head_commit
    prov_writer="$(grep -oE '"writer":"[^"]*"' "$review_file" | head -1 | sed 's/"writer":"//;s/"//')"
    prov_commit="$(grep -oE '"commit":"[^"]*"' "$review_file" | head -1 | sed 's/"commit":"//;s/"//')"
    prov_argv="$(grep -oE '"argv":"[^"]*"' "$review_file" | head -1 | sed 's/"argv":"//;s/"//')"
    head_commit="$(git rev-parse HEAD 2>/dev/null || echo unknown)"

    case "$prov_writer" in
      engine-review|engine-review-from-receipt) : ;;
      *) warn "$tid review evidence writer=$prov_writer (expected engine-review or engine-review-from-receipt)" ;;
    esac
    # D-040 (issue #28): stale 判定改为 ancestor-of-HEAD。正常 Coordinator closeout
    # 会在 review 之后提交 evidence/任务卡/CONTEXT/HANDOFF/ENGINE_MAP/胶囊,合法推进 HEAD;
    # review commit 仍为 HEAD 祖先即有效,只有被 rebase 掉/分叉/未知 commit 才报 stale。
    # git merge-base 置于 if 条件内,非祖先返回非零不触发 set -e;git 不可用/commit 空 → fail-open 回退 WARN。
    if [ "$prov_commit" != "$head_commit" ]; then
      if command -v git >/dev/null 2>&1 && [ -n "$prov_commit" ] && git merge-base --is-ancestor "$prov_commit" HEAD 2>/dev/null; then
        : # review commit 仍可从 HEAD 可达(closeout 合法推进)→ 非 stale
      else
        warn "$tid stale review evidence (commit=$prov_commit HEAD=$head_commit)"
        echo "  human: Task $tid review evidence is stale. Re-run 'engine review $tid' against current HEAD."
      fi
    fi
    case "$prov_argv" in
      "engine review $tid") : ;;
      "engine review $tid --from-receipt "*) : ;;
      *) warn "$tid review evidence argv mismatch: $prov_argv" ;;
    esac

    # tool_unavailable → WARN
    if grep -q '"tool_unavailable":true' "$review_file" 2>/dev/null; then
      warn "$tid review degraded (tool_unavailable=true), architect should confirm"
      echo "  human: Task $tid review ran with tools unavailable. Architect should confirm the skip is acceptable."
    fi

    # status == block → FAIL
    if grep -q '"status":"block"' "$review_file" 2>/dev/null; then
      fail "$tid done task has unresolved block findings"
      echo "  human: Task $tid is 'done' but review found critical/high findings. Waive via D-xxx decision or fix the findings."
    fi
  done
}

# v6.20.0 (T-070): review config protected check (spec §3.3).
check_review_config_protected() {
  local rules_file="$ENGINE_DIR/decisions/rules.json"
  local config_path="engine/review/config.json"
  [ -f "$rules_file" ] || return 0
  [ -f "$ENGINE_DIR/review/config.json" ] || return 0

  # 1. config 在 protected_paths?
  if ! grep -q '"engine/review/config.json"' "$rules_file" 2>/dev/null; then
    warn "engine/review/config.json not in protected_paths (rule gap)"
    echo "  human: engine/review/config.json should be in rules.json protected_paths."
    return 0
  fi

  # 2. config 修改是否有 covering decision?(类似 protected-path 检查)
  # 注:完整的 covering_decision 检查由既有 protected-path gate 负责,这里只做存在性 sanity
  if ! git diff --name-only HEAD..HEAD~1 -- "$config_path" 2>/dev/null | grep -q .; then
    : # 未在最近 commit 改动,无需检查
  fi
}

# v6.21.0 (T-072): agent-reviewer Doctor check.
# 对 done 卡:若 agent_review enabled(config 或 L2 override),检查 AGENT-REVIEW.json 存在且状态可接受。
# 新 done 缺 evidence → FAIL;历史 done → WARN;status=block → FAIL;status=concerns → WARN。
check_agent_review_evidence() {
  local tasks_dir="$ENGINE_DIR/tasks"
  local config_file="$ENGINE_DIR/review/config.json"
  [ -d "$tasks_dir" ] || return 0

  # 读 config: agent_review.enabled
  local ar_enabled=false
  if [ -f "$config_file" ]; then
    if command -v python3 >/dev/null 2>&1; then
      ar_enabled="$(CONFIG_FILE="$config_file" python3 -c "
import json, os
try:
    with open(os.environ['CONFIG_FILE']) as f: cfg = json.load(f)
except: cfg = {}
ar = cfg.get('defaults',{}).get('agent_review',{})
ar_ov = cfg.get('overrides',{}).get('agent_review',{})
if isinstance(ar_ov, dict): ar = {**ar, **ar_ov}
print('true' if ar.get('enabled', False) else 'false')
" 2>/dev/null || echo "false")"
    elif command -v python >/dev/null 2>&1; then
      ar_enabled="$(CONFIG_FILE="$config_file" python -c "
import json, os
try:
    with open(os.environ['CONFIG_FILE']) as f: cfg = json.load(f)
except: cfg = {}
ar = cfg.get('defaults',{}).get('agent_review',{})
ar_ov = cfg.get('overrides',{}).get('agent_review',{})
if isinstance(ar_ov, dict): ar = {**ar, **ar_ov}
print('true' if ar.get('enabled', False) else 'false')
" 2>/dev/null || echo "false")"
    fi
  fi

  for f in "$tasks_dir"/T-*.md; do
    [ -f "$f" ] || continue
    [[ "$f" == *.spec.md ]] && continue
    card_status_done "$f" || continue
    local tid; tid="$(basename "$f" .md)"

    # 判断此卡是否需要 agent review: config enabled 或 L2 override
    local needs_agent_review=false
    if [ "$ar_enabled" = "true" ]; then
      needs_agent_review=true
    else
      # L2 REVIEW-OVERRIDE: add_dimensions: agent_review
      if awk '/^## REVIEW-OVERRIDE/{f=1;next} /^## /{f=0} f' "$f" 2>/dev/null | grep -q 'add_dimensions:.*agent_review'; then
        needs_agent_review=true
      fi
    fi
    [ "$needs_agent_review" = true ] || continue

    local agent_review_file="$ENGINE_DIR/review/evidence/$tid/AGENT-REVIEW.json"

    if [ ! -f "$agent_review_file" ]; then
      # 判断 HEAD status:已 done → 历史 WARN;否则新 done FAIL
      if command -v git >/dev/null 2>&1 && git cat-file -e "HEAD:engine/tasks/$tid.md" 2>/dev/null \
        && git show "HEAD:engine/tasks/$tid.md" 2>/dev/null | grep -Eq '^[[:space:]]*(>[[:space:]]*)?status:[[:space:]]*done'; then
        warn "done task $tid missing agent review evidence (legacy)"
        echo "  human: Task $tid was 'done' in HEAD; agent review evidence missing (legacy). Run 'engine review-agent $tid --package' then validate."
      else
        fail "newly-done task $tid missing agent review evidence"
        echo "  human: Task $tid is marked 'done' but has no agent review evidence. Run 'engine review-agent $tid --package', feed to agent, then '--validate'."
      fi
      continue
    fi

    # 校验 status
    local agent_status
    agent_status="$(grep -oE '"status":"[^"]*"' "$agent_review_file" | head -1 | sed 's/"status":"//;s/"//')"
    case "$agent_status" in
      block)
        fail "$tid done task has agent review block status"
        echo "  human: Task $tid agent review found critical findings (status=block). Fix or waive via D-xxx decision."
        ;;
      concerns)
        warn "$tid agent review has concerns (architect should confirm)"
        echo "  human: Task $tid agent review status=concerns. Architect should confirm the high findings are acceptable."
        ;;
      pass) : ;;
      *)
        warn "$tid agent review has unknown status: $agent_status"
        ;;
    esac

    # provenance sanity: writer
    local ar_writer
    ar_writer="$(grep -oE '"writer":"[^"]*"' "$agent_review_file" | head -1 | sed 's/"writer":"//;s/"//')"
    if [ "$ar_writer" != "agent-reviewer" ]; then
      warn "$tid agent review writer=$ar_writer (expected agent-reviewer)"
    fi
  done
}

# v6.24.0 (T-077): Quality Gate registry check. Done cards (cv>=6.24.0) must
# have GATE.json with status=pass. Legacy done cards (cv<6.24.0) get WARN.
check_gate_registry() {
  local tasks_dir="$ENGINE_DIR/tasks"
  [ -d "$tasks_dir" ] || return 0
  # Determine contract-version
  local cv=""
  for _marker in "$ROOT/AGENTS.md" "$ENGINE_DIR/SYSTEM.md" "$ENGINE_DIR/ENGINE_DOCTOR.md"; do
    [ -f "$_marker" ] || continue
    cv="$(sed -n 's/.*contract-version:[[:space:]]*\([0-9][0-9.]*\).*/\1/p' "$_marker" 2>/dev/null | head -1)"
    [ -n "$cv" ] && break
  done
  local cv_minor=0
  if [ -n "$cv" ]; then
    local cv_major="${cv%%.*}"
    cv_minor="${cv#*.}"; cv_minor="${cv_minor%%.*}"
    case "$cv_major:$cv_minor" in *[!0-9:]*|:*) cv_minor=0 ;; esac
    [ "$cv_major" -gt 6 ] 2>/dev/null && cv_minor=99
  fi

  for f in "$tasks_dir"/T-*.md; do
    [ -f "$f" ] || continue
    [[ "$f" == *.spec.md ]] && continue
    card_status_done "$f" || continue
    local tid; tid="$(basename "$f" .md)"
    local gate_file="$ENGINE_DIR/evidence/$tid/GATE.json"

    if [ ! -f "$gate_file" ]; then
      if [ "$cv_minor" -ge 24 ] 2>/dev/null; then
        fail "done task $tid missing GATE.json (cv>=6.24.0)"
        echo "  human: Task $tid is done but has no gate evidence. Run 'engine gate $tid' and stage the result."
      else
        warn "done task $tid missing GATE.json (legacy, cv<6.24.0)"
      fi
      continue
    fi

    local gate_status
    gate_status="$(grep -oE '"status"[[:space:]]*:[[:space:]]*"[^"]*"' "$gate_file" | head -1 | sed 's/.*"status"[[:space:]]*:[[:space:]]*"//;s/"//')"
    case "$gate_status" in
      pass) : ;;
      block)
        fail "$tid GATE.json status=block"
        echo "  human: Task $tid gate verdict is block. Fix failing gates then re-run 'engine gate $tid'."
        ;;
      *)
        warn "$tid GATE.json has unexpected status: $gate_status"
        ;;
    esac
  done
}

# v6.18.0 (D-038/T-066 AC-8): drift-check integration. Defers to the
# standalone engine-drift-check.sh script (cheap fingerprint comparison,
# no verify re-run). Tamper/drift = FAIL; warn-only issues stay WARN.
check_drift() {
  local script="$ENGINE_DIR/scripts/engine-drift-check.sh"
  if [ ! -f "$script" ]; then
    warn "drift-check script missing: $script"
    return 0
  fi
  if ! command -v git >/dev/null 2>&1; then
    warn "git not on PATH - drift-check skipped"
    return 0
  fi
  local out rc
  if out="$(bash "$script" 2>&1)"; then
    rc=0
  else
    rc=$?
  fi
  echo "$out" | sed 's/^/  /'
  if [ "$rc" -ne 0 ]; then
    fail "drift-check detected tamper or drift (see above)"
    echo "  human: Evidence integrity or code fingerprint mismatch. Re-run 'engine verify <T-NNN>' against current HEAD, or mark evidence-manual-edit with a covering approved decision."
  else
    pass "drift-check passed (no tamper, no drift)"
  fi
}

# v6.19.0 (D-038c/T-067): derived status panel check. Double-write transition:
# CONTEXT.md static panel is labeled "legacy" while engine context outputs a
# real-time "Derived Status" segment. Doctor verifies (1) the legacy annotation
# exists and (2) derived values (git tag vs engine/VERSION) match the static
# declaration. Mismatches are WARN only during the double-write transition.
check_derived_status() {
  local ctx="$ENGINE_DIR/CONTEXT.md"
  [ -f "$ctx" ] || return 0
  if ! command -v git >/dev/null 2>&1; then
    warn "git not on PATH - derived status check skipped"
    return 0
  fi

  # (1) Legacy annotation check.
  if grep -q '<!-- legacy: status-panel' "$ctx" 2>/dev/null; then
    pass "CONTEXT.md status-panel has legacy annotation (double-write transition)"
  else
    warn "CONTEXT.md status-panel missing <!-- legacy: status-panel --> annotation"
    echo "  human: Add <!-- legacy: status-panel (double-write transition, v6.19.0~v6.20.0) --> after the '## 状态面板' header. See D-038c."
    return 0
  fi

  # (2) Derived value consistency: latest git tag vs engine/VERSION.
  local latest_tag engine_ver latest_ver
  latest_tag="$(cd "$ROOT" && git describe --tags --abbrev=0 2>/dev/null || echo 'none')"
  engine_ver="$(tr -d '[:space:]' < "$ENGINE_DIR/VERSION" 2>/dev/null || echo 'unknown')"
  latest_ver="${latest_tag#v}"

  if [ "$latest_ver" = "$engine_ver" ]; then
    pass "derived tag/VERSION consistent ($latest_tag = $engine_ver)"
  else
    warn "derived tag/VERSION mismatch: git tag=$latest_tag, engine/VERSION=$engine_ver"
    echo "  human: The latest git tag does not match engine/VERSION. Run 'engine update' or create a matching tag."
  fi

  # (3) Check static panel "上次完成" mentions the latest tag (stale panel detection).
  if grep -q "$latest_ver" "$ctx" 2>/dev/null; then
    pass "static panel references current version ($latest_ver)"
  else
    warn "static panel does not reference current version ($latest_ver) - panel may be stale"
    echo "  human: Update the '上次完成' row in CONTEXT.md to mention v$engine_ver, or rely on the Derived Status segment."
  fi
}

check_engine_version() {
  local ev="$ENGINE_DIR/VERSION"
  if [ ! -f "$ev" ]; then
    warn "engine/VERSION missing - run 'engine migrate' to stamp the local version"
    echo "  human: The engine version file is missing. Run 'engine migrate' to create it and stamp the current version."
    return 0
  fi
  local v; v="$(tr -d '[:space:]' < "$ev")"
  if [ -z "$v" ]; then
    fail "engine/VERSION is empty"
    echo "  human: The engine version file exists but is empty. Run 'engine migrate' to fill it with the current version number."
    return 0
  fi
  # Only compare engine/VERSION with repo root VERSION when this IS the
  # engine_system source repo (contract/src/ exists). In user projects,
  # $ROOT/VERSION is the product's own version (e.g. 1.0.0) with different
  # semantics — comparing it against the engine tooling version (e.g. 6.0.1)
  # is always a false positive. See P014 + CHANGE-2026-07-06-08.
  if [ -d "$ROOT/contract/src" ] && [ -f "$ROOT/VERSION" ]; then
    local rv; rv="$(tr -d '[:space:]' < "$ROOT/VERSION")"
    if [ "$v" != "$rv" ]; then
      warn "engine/VERSION ($v) differs from repo VERSION ($rv) - run 'engine migrate' to sync"
      echo "  human: The engine tooling version ($v) does not match the project version ($rv). Run 'engine migrate' to synchronize them."
    else
      pass "engine/VERSION ($v) matches repo VERSION"
    fi
  else
    pass "engine/VERSION present ($v)"
  fi
}

check_engineignore() {
  # v6.13.0 (T-052/D-036, issue #17): WARN if .engineignore lists product paths.
  local ei="$ROOT/.engineignore"
  [ -f "$ei" ] || return 0
  local product_patterns='src/** runtime/** contract/**'
  local p
  for p in $product_patterns; do
    if grep -qE "^[[:space:]]*(${p}|${p%%/\*\*})" "$ei" 2>/dev/null; then
      warn ".engineignore lists product path '$p' — .engineignore is for non-product paths only (cross-agent anchors, engine tooling, project config). Product paths in .engineignore undermine task-card discipline."
      echo "  human: The file .engineignore contains '$p' which is a product code path. .engineignore should only exempt non-product paths (anchors, tooling, config) from task-card union gating. Remove product paths from .engineignore."
    fi
  done
}

check_legacy_data_format() {
  # Version-agnostic detection of legacy (pre-v6) data residue.
  # Detects format features (not version numbers) so any old-format data
  # is reported. Empty projects (no changes/tasks/evidence) trigger 0 WARNs.
  local tasks_dir="$ENGINE_DIR/tasks"
  local changes_dir="$ENGINE_DIR/changes"
  local evidence_dir="$ENGINE_DIR/evidence"

  # 1. Task cards without v6 headers (write-set: or status:).
  if [ -d "$tasks_dir" ]; then
    local legacy_tasks=0
    local f
    for f in "$tasks_dir"/T-*.md; do
      [ -f "$f" ] || continue
      [[ "$f" == *.spec.md ]] && continue
      if ! grep -qi 'write-set:\|status:' "$f" 2>/dev/null; then
        legacy_tasks=$((legacy_tasks + 1))
      fi
    done
    if [ "$legacy_tasks" -gt 0 ]; then
      warn "$legacy_tasks task card(s) missing v6 headers (write-set/status) - may be legacy format"
      echo "  human: $legacy_tasks task card(s) in engine/tasks/ are missing the v6 machine-readable header (write-set: or status:). They may be from an older engine version. New work should use the v6 task card format (see engine/tasks/README.md)."
    fi
  fi

  # 2. changes/ has capsules but tasks/ is empty - v5 data residue.
  local changes_count=0
  local tasks_count=0
  [ -d "$changes_dir" ] && changes_count="$(find "$changes_dir" -maxdepth 1 -name 'CHANGE-*.md' -type f 2>/dev/null | wc -l || echo 0)"
  [ -d "$tasks_dir" ] && tasks_count="$(find "$tasks_dir" -maxdepth 1 -name 'T-*.md' -type f 2>/dev/null | wc -l || echo 0)"
  if [ "$changes_count" -gt 0 ] && [ "$tasks_count" -eq 0 ]; then
    warn "$changes_count change capsule(s) in engine/changes/ but 0 task cards - new work should use v6 task cards"
    echo "  human: Your project has $changes_count change capsules (engine/changes/) but no v6 task cards (engine/tasks/). This suggests the project was upgraded from an older engine version but new work hasn't adopted v6 task cards yet. New work should be tracked as T-NNN.md task cards."
  fi

  # 3. evidence/ has loose .md files (v5 format) instead of T-NNN/AC-N.json.
  if [ -d "$evidence_dir" ]; then
    local legacy_ev=0
    local ef
    while IFS= read -r ef; do
      [ -f "$ef" ] && legacy_ev=$((legacy_ev + 1))
    done < <(find "$evidence_dir" -maxdepth 1 -name '*.md' -type f 2>/dev/null)
    if [ "$legacy_ev" -gt 0 ]; then
      warn "$legacy_ev evidence file(s) are loose .md (legacy format) - new work should use evidence/T-NNN/AC-N.json"
      echo "  human: $legacy_ev evidence file(s) in engine/evidence/ are loose .md files (v5 format). New verification evidence should be stored as engine/evidence/T-NNN/AC-N.json (machine-readable, with sha256 fingerprint)."
    fi
  fi
}

# v6.11.0 (D-029/T-036) AC-6: multi-session isolation health check.
# cv >= 6.11.0 -> fail-closed (FAIL); cv < 6.11.0 -> fail-open (WARN, grace period).
# v6.12.2 (T-050): tombstone check downgraded FAIL->WARN. Tombstone is a historical
#   transition record (coordinator-exited / stale-recovered / forced-replaced), not
#   an active-state signal — lock file + lease mtime is the source of truth. A stale
#   tombstone just means the repo has been quiet; it auto-cleans on the next
#   coordinator start (SessionStart hook). cv < 6.12.2 keeps prior FAIL for migration.
# Checks: (1) .cache/sessions dir exists (SessionStart hook should create);
#         (2) session.lock format validity (>= 5 fields);
#         (3) tombstone file staleness (>24h): cv>=6.12.2 WARN, 6.11.0<=cv<6.12.2 FAIL, cv<6.11.0 WARN.
check_multi_session_isolation() {
  local doctor_path="$ENGINE_DIR/ENGINE_DOCTOR.md"
  local contract_version=""
  if [ -f "$doctor_path" ]; then
    contract_version="$(grep -oE 'contract-version:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+' "$doctor_path" 2>/dev/null | head -1 | sed 's/.*contract-version:[[:space:]]*//')"
  fi
  local cv_int=0
  if [[ "$contract_version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    cv_int=$(( ${BASH_REMATCH[1]} * 10000 + ${BASH_REMATCH[2]} * 100 + ${BASH_REMATCH[3]} ))
  fi
  local violation_is_fail=0
  if [ "$cv_int" -ge 61100 ] 2>/dev/null; then
    violation_is_fail=1
  fi
  # T-050 (v6.12.2): tombstone staleness FAIL only on old contract versions
  # (6.11.0 <= cv < 6.12.2). cv >= 6.12.2 downgrades to WARN (tombstone is
  # historical, not active state; auto-cleans on next coordinator start).
  local tombstone_is_fail=0
  if [ "$cv_int" -ge 61100 ] 2>/dev/null && [ "$cv_int" -lt 61202 ] 2>/dev/null; then
    tombstone_is_fail=1
  fi

  local sessions_dir="$ENGINE_DIR/.cache/sessions"
  local lock_file="$ENGINE_DIR/.cache/session.lock"
  local tombstone_file="$ENGINE_DIR/.cache/session.tombstone"

  # 1. sessions dir exists
  if [ ! -d "$sessions_dir" ]; then
    # CI/非交互式环境 (T-045): SessionStart hook 不会运行, sessions dir 缺失是正常状态
    if [ "${CI:-}" = "true" ] || [ "${GITHUB_ACTIONS:-}" = "true" ]; then
      warn "multi-session isolation: .cache/sessions dir missing (CI environment, SessionStart hook not expected to run, cv=$contract_version)"
      return 0
    fi
    if [ "$violation_is_fail" -eq 1 ]; then
      fail "multi-session isolation: .cache/sessions dir missing (cv=$contract_version >= 6.11.0, SessionStart hook should create it)"
      echo "  human: contract-version $contract_version requires multi-session isolation, but engine/.cache/sessions directory does not exist. SessionStart hook may not have run. Run 'engine context' to verify hook setup."
    else
      warn "multi-session isolation: .cache/sessions dir missing (grace period, cv=$contract_version < 6.11.0)"
    fi
    return 0
  fi

  # 2. lock file format validity
  if [ -f "$lock_file" ]; then
    local lock_line lock_field_count
    lock_line="$(cat "$lock_file" 2>/dev/null || true)"
    if [ -n "$lock_line" ]; then
      lock_field_count="$(printf '%s' "$lock_line" | awk -F'|' '{print NF}')"
      if [ "$lock_field_count" -lt 5 ]; then
        if [ "$violation_is_fail" -eq 1 ]; then
          fail "multi-session isolation: session.lock malformed ($lock_field_count fields, expected 5: pid|sid|role|started_at|task_id)"
          echo "  human: engine/.cache/session.lock has $lock_field_count pipe-separated fields, expected at least 5. Remove the file and let SessionStart hook recreate it."
        else
          warn "multi-session isolation: session.lock malformed (grace period)"
        fi
      fi
    fi
  fi

  # 3. tombstone staleness (>24h)
  # T-050 (v6.12.2): tombstone is a historical transition record, not active state.
  # lock file + lease mtime is the source of truth for active-state problems.
  # cv>=6.12.2 downgrades FAIL->WARN (tombstone auto-cleans on next coordinator start).
  if [ -f "$tombstone_file" ]; then
    local tombstone_line tombstone_ts ts_norm ts_sec now_sec age_sec tombstone_type
    tombstone_line="$(cat "$tombstone_file" 2>/dev/null || true)"
    tombstone_ts="$(printf '%s' "$tombstone_line" | cut -d'|' -f1)"
    tombstone_type="$(printf '%s' "$tombstone_line" | cut -d'|' -f3)"
    [ -n "$tombstone_type" ] || tombstone_type="unknown"
    if [ -n "$tombstone_ts" ]; then
      # Parse ISO 8601 timestamp (UTC). Try GNU date first, BSD date as fallback.
      ts_norm="$(printf '%s' "$tombstone_ts" | sed 's/T/ /;s/Z$//;s/\..*$//')"
      ts_sec="$(date -u -d "$ts_norm" +%s 2>/dev/null || date -u -j -f '%Y-%m-%d %H:%M:%S' "$ts_norm" +%s 2>/dev/null || echo 0)"
      if [ "$ts_sec" -gt 0 ]; then
        now_sec="$(date -u +%s 2>/dev/null || echo 0)"
        if [ "$now_sec" -gt 0 ]; then
          age_sec=$((now_sec - ts_sec))
          if [ "$age_sec" -gt 86400 ]; then
            if [ "$tombstone_is_fail" -eq 1 ]; then
              fail "multi-session isolation: tombstone file is stale (${age_sec}s old, type=$tombstone_type, >24h) - run 'engine assume-coordinator --force' to clean up"
              echo "  human: engine/.cache/session.tombstone is $((age_sec / 3600))h old (type=$tombstone_type). Run 'engine assume-coordinator --force' to take over."
            else
              warn "multi-session isolation: tombstone is a historical transition record (type=$tombstone_type, ${age_sec}s old, >24h); not an active failure — lock file + lease mtime is the source of truth; auto-cleans on next coordinator start (cv=$contract_version)"
            fi
          fi
        fi
      fi
    fi
  fi
}

# v6.12.0 (D-035) multi-card WRITE-SET overlap check (WARN level).
# Union gating allows several active cards in parallel; when two cards declare
# the SAME WRITE-SET entry (string-equal), both sessions may write it and the
# race falls back to git. Shared singletons (coordinator-lease-guarded) and the
# cards' own engine/tasks/* files are expected overlaps and excluded.
check_multi_card_writeset_overlap() {
  local card entries all="" dups
  local active_cards=""
  for card in "$ENGINE_DIR"/tasks/T-*.md; do
    [ -f "$card" ] || continue
    case "$card" in *.spec.md) continue ;; esac
    card_status_active "$card" || continue
    active_cards="${active_cards}${active_cards:+ }$card"
  done
  set -- $active_cards
  [ "$#" -ge 2 ] || return 0
  for card in "$@"; do
    entries="$(grep '^WRITE-SET:' "$card" 2>/dev/null | head -1 | sed 's/^WRITE-SET:[[:space:]]*//' | tr ',' '\n')" || true
    [ -n "$entries" ] || entries="$(awk '/^##[[:space:]]+WRITE-SET[[:space:]]*$/{on=1;next} on&&/^##[[:space:]]+/{exit} on&&/^-[[:space:]]+/{sub(/^-[[:space:]]+/,"");print}' "$card" 2>/dev/null)"
    all="$all$(printf '%s\n' "$entries" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$' | sed "s|$|\t$(basename "$card" .md)|")
"
  done
  dups="$(printf '%s' "$all" | awk -F'\t' '
    $1 == "" { next }
    $1 ~ /^engine\/(CONTEXT|HANDOFF|ENGINE_MAP|SYSTEM|REPO_GUIDE|PITFALLS|SPRINT|ROADMAP)\.md$/ { next }
    $1 ~ /^engine\/tasks\// { next }
    { if (seen[$1] != "" && seen[$1] != $2) { pair[$1] = seen[$1] "+" $2 } else { seen[$1] = $2 } }
    END { for (p in pair) printf "%s (%s)\n", p, pair[p] }
  ')"
  if [ -n "$dups" ]; then
    warn "multi-card WRITE-SET overlap: $(printf '%s' "$dups" | tr '\n' ';' | sed 's/;$//')"
    echo "  human: two active task cards declare the same WRITE-SET entry. Union gating lets both sessions write it, so concurrent edits race at the git layer. Narrow one card's WRITE-SET, or accept the risk knowingly."
  fi
  return 0
}

# v6.11.0 (D-029/T-036) AC-7: workstream orphan check (WARN level).
# For each engine/workstreams/<task>/<worker>/ shard, check if a matching
# .cache/sessions/<worker_key>.meta file exists. If not, WARN (worker may
# still be running, or exited without Stop hook firing).
check_workstream_orphan() {
  local workstreams_dir="$ENGINE_DIR/workstreams"
  [ -d "$workstreams_dir" ] || return 0

  local sessions_dir="$ENGINE_DIR/.cache/sessions"
  local orphan_count=0
  local task_dir worker_dir worker_name meta_found prefix meta meta_base meta_prefix
  for task_dir in "$workstreams_dir"/*/; do
    [ -d "$task_dir" ] || continue
    for worker_dir in "$task_dir"*/; do
      [ -d "$worker_dir" ] || continue
      worker_name="$(basename "$worker_dir")"
      meta_found=0
      if [ -d "$sessions_dir" ]; then
        if [ -f "$sessions_dir/$worker_name.meta" ]; then
          meta_found=1
        else
          # Short prefix match (worker_name first 8 chars) - tolerates worker_id=agent_id vs session_key mismatch
          prefix="${worker_name:0:8}"
          for meta in "$sessions_dir"/*.meta; do
            [ -f "$meta" ] || continue
            meta_base="$(basename "$meta" .meta)"
            meta_prefix="${meta_base:0:8}"
            if [ "$meta_prefix" = "$prefix" ]; then
              meta_found=1
              break
            fi
          done
        fi
      fi
      if [ "$meta_found" -eq 0 ]; then
        warn "orphan workstream shard: $(basename "$task_dir")/$worker_name (no matching .cache/sessions/$worker_name.meta)"
        echo "  human: Workstream shard for task $(basename "$task_dir") worker $worker_name has no .meta file. Worker may still be running, or exited without Stop hook firing. If stale, remove engine/workstreams/$(basename "$task_dir")/$worker_name/ manually."
        orphan_count=$((orphan_count + 1))
      fi
    done
  done
  if [ "$orphan_count" -eq 0 ]; then
    pass "workstream orphan: no orphan shards detected"
  fi
}

check_plan_acceptance_evidence() {
  while IFS='|' read -r _ id title status plan spec notes verified _; do
    id="$(trim "$id")"
    status="$(trim "$status")"
    spec="$(trim "$spec")"
    [[ -z "$id" || "$id" == "ID" || "$id" =~ ^-+$ || "$id" == \[* || "$id" == "无"* ]] && continue
    [[ "$status" == "done" ]] || continue
    [[ "$spec" == engine/* && "$spec" != *"+"* ]] || continue
    [[ -f "$ROOT/$spec" ]] || continue
    if ! grep -Eq 'Evidence|证据|engine/changes/CHANGE-|engine/evidence/' "$ROOT/$spec"; then
      warn "$id is marked done but has no acceptance evidence pointer"
      echo "  human: Plan $id is marked 'done' but the spec file has no evidence pointers. Add references to evidence files, change capsules, or engine/evidence/ in the spec."
    fi
  done < "$plan_tmp"
}

while IFS= read -r path; do
  rel="${path#"$ROOT/"}"
  if [[ "$rel" == engine/README.md || "$rel" == engine/README.zh.md ]]; then
    continue
  fi
  # External scratch spec, intentionally not registered as project authority.
  if [[ "${rel#engine/}" == ENGINE_FILE_SYSTEM_v5.md ]]; then
    continue
  fi
  # v6.6 (D-027): HANDOFF history archive files are search-only, not §1 authority.
  if [[ "${rel#engine/}" == handoff-archive-*.md ]]; then
    continue
  fi
  if ! is_registered "$rel" && ! is_registered "${rel#engine/}"; then
    fail "authority-looking file is not registered or explained: $rel"
    echo "  human: The file '$rel' looks like a project authority file but is not registered in ENGINE_MAP. Either register it in ENGINE_MAP section 1 or move it out of the engine/ directory."
  fi
done < <(find "$ENGINE_DIR" -maxdepth 1 -type f -name '*.md' 2>/dev/null)

if [[ -d "$ENGINE_DIR/agents" ]]; then
  while IFS= read -r path; do
    rel="${path#"$ROOT/"}"
    if ! is_registered "$rel"; then
      fail "agent adapter is not registered: $rel"
      echo "  human: The agent adapter file '$rel' is not registered in ENGINE_MAP. Register it in the file registry or remove it if it's no longer needed."
    fi
  done < <(find "$ENGINE_DIR/agents" -maxdepth 1 -type f -name '*.md' 2>/dev/null)
fi

# v6.23.0 (T-075): prove subsystem health check
check_prove_health() {
  local prove_dir="$ENGINE_DIR/prove"
  local scripts_dir="$ENGINE_DIR/scripts"

  # Git Bash may expose a Windows Python executable while ROOT is a POSIX
  # path such as /e/projects/.... Pass paths through argv so MSYS converts
  # them for Windows Python; embedding the POSIX path in Python source makes
  # valid JSON look unreadable and falsely fails Doctor.
  json_file_valid() {
    local json_path="$1"
    if command -v python3 >/dev/null 2>&1; then
      python3 -c 'import json,sys; json.load(open(sys.argv[1], encoding="utf-8"))' "$json_path" >/dev/null 2>&1
    elif command -v python >/dev/null 2>&1; then
      python -c 'import json,sys; json.load(open(sys.argv[1], encoding="utf-8"))' "$json_path" >/dev/null 2>&1
    else
      return 0
    fi
  }

  # Scripts exist
  if [[ -f "$scripts_dir/engine-prove.sh" ]]; then
    pass "prove script exists: engine/scripts/engine-prove.sh"
  else
    warn "prove script missing: engine/scripts/engine-prove.sh"
    echo "  human: The prove script is missing. Run 'engine sync' or restore from plugin mirror."
  fi
  if [[ -f "$scripts_dir/engine-prove.ps1" ]]; then
    pass "prove ps1 mirror exists: engine/scripts/engine-prove.ps1"
  else
    warn "prove ps1 mirror missing: engine/scripts/engine-prove.ps1"
  fi

  # Config valid
  if [[ -f "$prove_dir/config.json" ]]; then
    if command -v python3 >/dev/null 2>&1; then
      if json_file_valid "$prove_dir/config.json"; then
        pass "prove config.json is valid JSON"
      else
        fail "prove config.json is invalid JSON"
        echo "  human: engine/prove/config.json has a JSON syntax error. Fix it manually."
      fi
    elif command -v python >/dev/null 2>&1; then
      if json_file_valid "$prove_dir/config.json"; then
        pass "prove config.json is valid JSON"
      else
        fail "prove config.json is invalid JSON"
        echo "  human: engine/prove/config.json has a JSON syntax error. Fix it manually."
      fi
    fi
  else
    warn "prove config missing: engine/prove/config.json"
    echo "  human: The prove config is missing. Prove will use built-in defaults."
  fi

  # Schema valid
  if [[ -f "$prove_dir/prove-assertions.schema.json" ]]; then
    if command -v python3 >/dev/null 2>&1; then
      if json_file_valid "$prove_dir/prove-assertions.schema.json"; then
        pass "prove schema is valid JSON"
      else
        fail "prove schema is invalid JSON"
        echo "  human: engine/prove/prove-assertions.schema.json has a JSON syntax error."
      fi
    elif command -v python >/dev/null 2>&1; then
      if json_file_valid "$prove_dir/prove-assertions.schema.json"; then
        pass "prove schema is valid JSON"
      else
        fail "prove schema is invalid JSON"
        echo "  human: engine/prove/prove-assertions.schema.json has a JSON syntax error."
      fi
    fi
  else
    warn "prove schema missing: engine/prove/prove-assertions.schema.json"
  fi
}

check_prove_health
check_context_semantics
check_handoff_semantics
check_handoff_history_cap
check_progress_md
check_inventory_bidirectional
check_inventory_api_uniqueness
check_writeset_budget
check_task_granularity
check_depends_on
check_warn_done_gate
check_pitfalls_semantics
check_sprint_semantics
check_change_capsule_semantics
check_plan_acceptance_evidence
check_contract_compile
check_contract_debt
check_task_card_done_evidence
check_drift
check_derived_status
check_engine_version
check_engineignore
check_legacy_data_format
check_multi_session_isolation
check_multi_card_writeset_overlap
check_status_conflict
check_workstream_orphan
check_review_evidence
check_review_config_protected
check_agent_review_evidence
check_gate_registry

# ── Project-custom checks (engine/checks/) ──
# Each project may place executable check-*.sh (FAIL on non-zero) or warn-*.sh
# (WARN on non-zero) scripts into engine/checks/.  Doctor discovers and runs
# them after all built-in checks.  Stdout becomes the result message.
run_custom_checks() {
  local checks_dir="$ENGINE_DIR/checks"
  [ -d "$checks_dir" ] || return 0
  local found=false
  local script
  for script in "$checks_dir"/check-*.sh "$checks_dir"/warn-*.sh; do
    [ -f "$script" ] || continue
    found=true
    local name; name="$(basename "$script")"
    local is_warn=false
    [[ "$name" == warn-* ]] && is_warn=true
    if [ ! -x "$script" ]; then
      warn "custom check $name exists but is not executable"
      continue
    fi
    local output
    if output="$(bash "$script" 2>&1)"; then
      pass "custom check $name: PASS"
      [ -n "$output" ] && printf '%s\n' "$output"
    else
      if $is_warn; then
        warn "custom check $name: FAIL"
      else
        fail "custom check $name: FAIL"
      fi
      [ -n "$output" ] && printf '%s\n' "$output"
    fi
  done
  if ! $found; then
    pass "custom checks directory exists but is empty (engine/checks/)"
  fi
}
run_custom_checks

while IFS='|' read -r _ path type authority verified _; do
  path="$(trim "$path")"
  [[ -z "$path" || "$path" == "Path" || "$path" =~ ^-+$ || "$path" == \[* ]] && continue
  if [[ "$path" == *archived* || "$path" == *superseded* || "$path" == *external* ]]; then
    continue
  fi
  [[ -f "$ROOT/$path" ]] || { warn "registered anchor missing: $path"; echo "  human: The anchor file '$path' is registered in ENGINE_MAP but does not exist. Create it or remove the anchor entry."; }
done < "$anchor_tmp"

allowed_status=' draft proposed accepted active blocked done archived superseded '
while IFS='|' read -r _ id title status plan spec notes verified _; do
  id="$(trim "$id")"
  status="$(trim "$status")"
  plan="$(trim "$plan")"
  spec="$(trim "$spec")"
  [[ -z "$id" || "$id" == "ID" || "$id" =~ ^-+$ || "$id" == \[* || "$id" == "无"* ]] && continue
  if [[ "$allowed_status" != *" $status "* ]]; then
    fail "$id has invalid plan status '$status'"
    echo "  human: Plan $id has an unrecognized status '$status'. Valid statuses are: draft, proposed, accepted, active, blocked, done, archived, superseded."
  fi
  # Inline markers and composite paths are not single files on disk.
  if [[ -n "$plan" && "$plan" != \(* && "$plan" != *"+"* ]]; then
    [[ -f "$ROOT/$plan" ]] || { fail "$id plan file missing: $plan"; echo "  human: The plan file '$plan' for $id does not exist. Create it or update the ENGINE_MAP plan registry."; }
  fi
  has_inline=false; [[ "$spec" == *"内联"* ]] && has_inline=true
  has_spec_path=false; [[ "$spec" == engine/* ]] && has_spec_path=true
  if [[ "$has_inline" == false && "$has_spec_path" == false ]]; then
    case " $status " in
      " accepted "|" active "|" done ") fail "$id must have a spec twin path or inline spec marker: $spec"
        echo "  human: Plan $id is in status '$status' but has no spec twin file. Add a spec file path in the Spec column of ENGINE_MAP, or use an inline spec marker." ;;
    esac
  fi
  if [[ "$has_spec_path" == true && "$spec" != *"+"* ]]; then
    [[ -f "$ROOT/$spec" ]] || { fail "$id spec twin missing: $spec"; echo "  human: The spec twin file '$spec' for plan $id does not exist. Create the spec file or update the path in ENGINE_MAP."; }
  fi
done < "$plan_tmp"

for anchor in AGENTS.md CLAUDE.md; do
  if [[ -f "$ROOT/$anchor" ]]; then
    lines="$(wc -l < "$ROOT/$anchor" | tr -d ' ')"
    [[ "$lines" -gt 45 ]] && warn "$anchor exceeds bootloader hard cap ($lines > 45 lines)" && echo "  human: The bootloader file '$anchor' has $lines lines, exceeding the 45-line limit. Bootloader files should only contain pointers to engine files, not content. Trim it down."
  fi
done

# Anchor content quality: TOP RULES source attribution
for anchor in AGENTS.md CLAUDE.md; do
  if [[ -f "$ROOT/$anchor" ]]; then
    in_top_rules=false; unsourced=0
    while IFS= read -r line; do
      [[ "$line" == *"TOP RULES"* ]] && { in_top_rules=true; continue; }
      if $in_top_rules; then
        [[ "$line" == "## "* ]] && break
        [[ "$line" =~ ^[0-9]+\.\  ]] && [[ "$line" != *"source:"* ]] && unsourced=$((unsourced+1))
      fi
    done < "$ROOT/$anchor"
    if [[ "$unsourced" -gt 0 ]]; then
      warn "$anchor has $unsourced TOP RULES line(s) without source: attribution"
      echo "  human: The bootloader '$anchor' contains rule excerpts without 'source:' annotation."
      echo "  Each excerpted rule should cite its authority (e.g., 'source: engine/SYSTEM.md')."
      echo "  Unsourced rules may be originals that belong in engine/SYSTEM.md, not in the bootloader."
    fi
  fi
done

if [[ " $registered_names " != *" ENGINE_DOCTOR.md "* ]]; then
  warn "ENGINE_DOCTOR.md is not registered in ENGINE_MAP §1"
  echo "  human: The ENGINE_DOCTOR.md file is not listed in the ENGINE_MAP file registry. Add it to section 1 so the doctor can track its health."
fi

for script in \
  engine-doctor.sh \
  engine-doctor.ps1 \
  engine-context.sh \
  engine-context.ps1 \
  engine-hook-session-start.sh \
  engine-hook-session-start.ps1 \
  engine-hook-stop.sh \
  engine-hook-stop.ps1 \
  engine-hook-session-end.sh \
  engine-hook-session-end.ps1 \
  engine-hook.cmd \
  engine-sync-agent-anchors.sh \
  engine-sync-agent-anchors.ps1 \
  engine-migrate-contract.sh \
  engine-migrate-contract.ps1 \
  engine-verify.sh \
  engine-verify.ps1 \
  githooks/pre-commit
do
  if [[ -f "$ENGINE_DIR/scripts/$script" ]]; then
    pass "bundled maintenance script exists: engine/scripts/$script"
  else
    warn "bundled maintenance script missing: engine/scripts/$script"
    echo "  human: The maintenance script 'engine/scripts/$script' is missing. Run 'engine sync' to restore bundled scripts."
  fi
done

for cli in engine engine.ps1 engine.cmd; do
  if [[ -f "$ENGINE_DIR/bin/$cli" ]]; then
    pass "bundled CLI shim exists: engine/bin/$cli"
  else
    warn "bundled CLI shim missing: engine/bin/$cli"
    echo "  human: The CLI entry point 'engine/bin/$cli' is missing. Run 'engine sync' to restore bundled CLI shims."
  fi
done

printf '\nEngine Doctor: %s failure(s), %s warning(s)\n' "$fail_count" "$warn_count"
if [[ "$fail_count" -gt 0 ]]; then
  exit 1
fi
exit 0
