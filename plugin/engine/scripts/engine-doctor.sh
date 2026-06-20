#!/usr/bin/env bash
set -u

ROOT="${1:-$(pwd)}"
ENGINE_DIR="$ROOT/engine"
MAP="$ENGINE_DIR/ENGINE_MAP.md"

fail_count=0
warn_count=0

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

pass() {
  printf 'PASS %s\n' "$1"
}

engine_path() {
  local file="$1"
  file="$(trim "$file")"
  if [[ "$file" == engine/* ]]; then
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
  printf '\nEngine Doctor: %s failure(s), %s warning(s)\n' "$fail_count" "$warn_count"
  exit 1
fi

pass "ENGINE_MAP exists"

profile="$(grep -E '^\|[[:space:]]*Active profile[[:space:]]*\|' "$MAP" | head -n 1 | awk -F'|' '{print $3}' | tr -d ' `')"
[[ -z "$profile" ]] && warn "Active profile not found in ENGINE_MAP §0"

registered_tmp="$(mktemp)"
section_tmp="$(mktemp)"
anchor_tmp="$(mktemp)"
plan_tmp="$(mktemp)"
trap 'rm -f "$registered_tmp" "$section_tmp" "$anchor_tmp" "$plan_tmp"' EXIT

awk '
  /^## 1\. / { in_reg=1; next }
  /^### 1\.1/ { in_reg=0 }
  in_reg && /^\|/ { print }
' "$MAP" > "$registered_tmp"

awk '
  /^### 1\.1/ { in_sec=1; next }
  /^### 1\.2/ { in_sec=0 }
  in_sec && /^\|/ { print }
' "$MAP" > "$section_tmp"

awk '
  /^### 1\.2/ { in_anchor=1; next }
  /^## 2\./ { in_anchor=0 }
  in_anchor && /^\|/ { print }
' "$MAP" > "$anchor_tmp"

awk '
  /^## 2\./ { in_plan=1; next }
  /^## 3\./ { in_plan=0 }
  in_plan && /^\|/ { print }
' "$MAP" > "$plan_tmp"

registered_names=""
while IFS='|' read -r _ file class priority revision verified _; do
  file="$(trim "$file")"
  class="$(trim "$class")"
  priority="$(trim "$priority")"
  [[ -z "$file" || "$file" == "File" || "$file" =~ ^-+$ || "$file" == \[* ]] && continue
  registered_names="$registered_names $file"
  case "$class" in
    index|irreducible|derivable|mixed|anchor|generated-cache) ;;
    *) fail "$file has illegal class '$class' in ENGINE_MAP §1" ;;
  esac
  [[ -z "$priority" ]] && fail "$file has empty read priority"
  path="$(engine_path "$file")"
  if [[ -f "$path" ]]; then
    pass "registered file exists: $file"
  else
    fail "registered file missing: $file"
  fi
  cap="$(budget_cap "$file")"
  if [[ "$cap" -gt 0 && -f "$path" ]]; then
    lines="$(wc -l < "$path" | tr -d ' ')"
    if [[ "$lines" -gt "$cap" ]]; then
      warn "$file exceeds hard budget ($lines > $cap lines)"
    fi
  fi
  if [[ "$class" == "mixed" ]] && ! grep -F "| $file |" "$section_tmp" >/dev/null 2>&1; then
    fail "$file is mixed but missing §1.1 section-class row"
  fi
  if [[ "$profile" == "CLI-LEAN" && "$class" == "derivable" && -f "$path" ]]; then
    lines="$(wc -l < "$path" | tr -d ' ')"
    [[ "$lines" -gt 120 ]] && warn "$file is derivable in CLI-LEAN and longer than stub budget"
    if grep -E '^[[:space:]]*(├|└|│)|file inventory|directory tree|module count|version dump' "$path" >/dev/null 2>&1; then
      warn "$file may contain live derivable inventory in CLI-LEAN"
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

while IFS= read -r path; do
  rel="${path#"$ROOT/"}"
  if [[ "$rel" == engine/README.md || "$rel" == engine/README.zh.md ]]; then
    continue
  fi
  # External scratch spec, intentionally NOT registered as project authority
  # (see REPO_GUIDE Engine File Maintenance + scripts/engine-lint.ts). Keep in parity.
  if [[ "${rel#engine/}" == ENGINE_FILE_SYSTEM_v5.md ]]; then
    continue
  fi
  if ! is_registered "$rel" && ! is_registered "${rel#engine/}"; then
    fail "authority-looking file is not registered or explained: $rel"
  fi
done < <(find "$ENGINE_DIR" -maxdepth 1 -type f -name '*.md' 2>/dev/null)

if [[ -d "$ENGINE_DIR/agents" ]]; then
  while IFS= read -r path; do
    rel="${path#"$ROOT/"}"
    if ! is_registered "$rel"; then
      fail "agent adapter is not registered: $rel"
    fi
  done < <(find "$ENGINE_DIR/agents" -maxdepth 1 -type f -name '*.md' 2>/dev/null)
fi

while IFS='|' read -r _ path type authority verified _; do
  path="$(trim "$path")"
  [[ -z "$path" || "$path" == "Path" || "$path" =~ ^-+$ || "$path" == \[* ]] && continue
  if [[ "$path" == *archived* || "$path" == *superseded* || "$path" == *external* ]]; then
    continue
  fi
  [[ -f "$ROOT/$path" ]] || warn "registered anchor missing: $path"
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
  fi
  # Plan path: an inline "(...)" marker or a composite "a + b" path is not a single file
  # on disk; only verify a plain single path (parity with scripts/engine-lint.ts).
  if [[ -n "$plan" && "$plan" != \(* && "$plan" != *"+"* ]]; then
    [[ -f "$ROOT/$plan" ]] || fail "$id plan file missing: $plan"
  fi
  # Spec twin: accept an inline-spec marker ("内联") or a real engine/ path; only check
  # existence for a plain engine/ path (parity with scripts/engine-lint.ts).
  has_inline=false; [[ "$spec" == *"内联"* ]] && has_inline=true
  has_spec_path=false; [[ "$spec" == engine/* ]] && has_spec_path=true
  if [[ "$has_inline" == false && "$has_spec_path" == false ]]; then
    case " $status " in
      " accepted "|" active "|" done ") fail "$id must have a spec twin path or inline spec marker: $spec" ;;
    esac
  fi
  if [[ "$has_spec_path" == true && "$spec" != *"+"* ]]; then
    [[ -f "$ROOT/$spec" ]] || fail "$id spec twin missing: $spec"
  fi
done < "$plan_tmp"

for anchor in AGENTS.md CLAUDE.md; do
  if [[ -f "$ROOT/$anchor" ]]; then
    lines="$(wc -l < "$ROOT/$anchor" | tr -d ' ')"
    [[ "$lines" -gt 45 ]] && warn "$anchor exceeds bootloader hard cap ($lines > 45 lines)"
  fi
done

if [[ " $registered_names " != *" ENGINE_DOCTOR.md "* ]]; then
  warn "ENGINE_DOCTOR.md is not registered in ENGINE_MAP §1"
fi

printf '\nEngine Doctor: %s failure(s), %s warning(s)\n' "$fail_count" "$warn_count"
if [[ "$fail_count" -gt 0 ]]; then
  exit 1
fi
exit 0
