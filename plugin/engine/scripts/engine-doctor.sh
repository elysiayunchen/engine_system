#!/usr/bin/env bash
# Strict error handling: fail on any error, unbound var, or pipe failure.
# Intentional soft-fail sites (where we checked that failure is safe) use || true.
set -euo pipefail
on_error() { echo "[engine-doctor] error on line $1" >&2; exit 1; }
trap 'on_error ${LINENO}' ERR

ROOT="$(pwd)"
PACKAGE_MODE=false

for arg in "$@"; do
  case "$arg" in
    --package-mode) PACKAGE_MODE=true ;;
    *) ROOT="$arg" ;;
  esac
done

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
    value="$(printf '%s' "$row" | awk -F'|' '{print $3}' | xargs)"
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

check_task_card_done_evidence() {
  local tasks_dir="$ENGINE_DIR/tasks"
  [ -d "$tasks_dir" ] || return 0
  for f in "$tasks_dir"/T-*.md; do
    [ -f "$f" ] || continue
    grep -q 'status:.*done' "$f" 2>/dev/null || continue
    local tid; tid="$(basename "$f" .md)"
    local ev_dir="$ENGINE_DIR/evidence/$tid"
    if grep -qi 'exempt' "$f" 2>/dev/null; then
      pass "task $tid done (exempt - no evidence required)"
      continue
    fi
    if [ -d "$ev_dir" ] && ls "$ev_dir"/AC-*.json >/dev/null 2>&1; then
      local n; n="$(ls "$ev_dir"/AC-*.json 2>/dev/null | wc -l || true)"
      pass "task $tid done with $n evidence file(s)"
    else
      fail "task $tid done but no evidence (engine/evidence/$tid/AC-*.json) and no exempt marker - run 'engine verify $tid' or mark exempt"
      echo "  human: Task $tid is marked 'done' but has no verification evidence. Run 'engine verify $tid' to generate evidence, or add 'exempt' to the task card if verification is not needed."
    fi
  done
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

check_context_semantics
check_handoff_semantics
check_pitfalls_semantics
check_sprint_semantics
check_change_capsule_semantics
check_plan_acceptance_evidence
check_contract_compile
check_contract_debt
check_task_card_done_evidence
check_engine_version

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

if [[ " $registered_names " != *" ENGINE_DOCTOR.md "* ]]; then
  warn "ENGINE_DOCTOR.md is not registered in ENGINE_MAP §1"
  echo "  human: The ENGINE_DOCTOR.md file is not listed in the ENGINE_MAP file registry. Add it to section 1 so the doctor can track its health."
fi

for script in \
  engine-doctor.sh \
  engine-doctor.ps1 \
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
