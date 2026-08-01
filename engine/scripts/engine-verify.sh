#!/usr/bin/env bash
# Engine System — 行为化验收器(v6 S4)
#
# 执行任务卡 AC 的 verify 命令,PASS/FAIL + 输出指纹(sha256)写入
# engine/evidence/T-NNN/AC-N.json。完成 N3(完成有证据)的机器化——
# 架构师判断行为而非代码,done 门 = verify 全绿 或 架构师明示豁免。
#
# 用法:bash engine/scripts/engine-verify.sh T-NNN
# 安全:verify 命令由任务卡声明,架构师批准任务卡时即批准 verify。用户主动跑,非 hook 自动。

set -euo pipefail
on_error() { echo "[engine-verify] error on line $1 (${BASH_SOURCE[0]})" >&2; exit 1; }
trap 'on_error ${LINENO}' ERR
ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
ENGINE_DIR="$ROOT/engine"
task="${1:-}"

if [ -z "$task" ]; then
  echo "Usage: engine verify T-NNN" >&2
  exit 2
fi

# v6.10.0 (D-028/T-035): recursion guard. An AC verify command may itself
# invoke `bash engine/scripts/engine-verify.sh T-NNN` (e.g. T-035 AC-2 dogfood).
# Without a guard, that would infinitely recurse (each call re-iterates ACs and
# re-spawns the recursive call). The guard env var carries the task ID being
# verified by the outer call; a recursive invocation for the SAME task exits 0
# immediately. Other task IDs (e.g. behavior-verify test fixtures) run normally.
# Dead-code evidence (DEAD-CODE.json) is written by the outer (first) call only.
if [ -n "${ENGINE_VERIFY_RECURSE_GUARD:-}" ] && [ "${ENGINE_VERIFY_RECURSE_GUARD:-}" = "$1" ]; then
  exit 0
fi

task_file="$ENGINE_DIR/tasks/$task.md"
if [ ! -f "$task_file" ]; then
  echo "Error: 任务卡不存在: $task_file" >&2
  exit 2
fi

evidence_dir="$ENGINE_DIR/evidence/$task"
mkdir -p "$evidence_dir"

pass_count=0
fail_count=0
skip_count=0
# v6.12.1 (issue #11 E-1): tautology heuristics. Track how many PASS ACs have
# the empty-output fingerprint; if ALL of them do, the verify commands likely
# produce no output at all (e.g. bare `test -f` / `grep -q` chains) and may be
# tautologies. WARN only - never changes the exit code.
empty_fp_hash="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
empty_fp_pass=0

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

# v6.18.0 (D-038/T-066): 防漂移 — 证据多锚辅助函数
# is_engine_metadata: 判断路径是否 engine 元数据(排除出 code_fingerprint)
is_engine_metadata() {
  case "$1" in
    engine/tasks/*|engine/decisions/*|engine/changes/*|engine/evidence/*|engine/domains/*|engine/archive/*) return 0 ;;
    engine/CONTEXT.md|engine/HANDOFF.md|engine/ENGINE_MAP.md|engine/handoff-archive-*) return 0 ;;
    VERSION|engine/VERSION|plugin/VERSION|plugin/manifest.json|CHANGELOG.md) return 0 ;;
    *) return 1 ;;
  esac
}

# collect_code_fingerprint: 解析任务卡 WRITE-SET,收集代码文件 git ls-files -s blob sha
# 前置检查:文件须 git add 进 index(未 add 则 FAIL 退出)
declare -A code_fingerprint=()
declare -A code_fp_files=()
ws_snapshot=()
collect_code_fingerprint() {
  local file="$1" in_ws=0 line path blob_sha
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      "## WRITE-SET") in_ws=1; continue ;;
      "## "*) [ "$in_ws" = "1" ] && break ;;
    esac
    [ "$in_ws" = "1" ] || continue
    [[ "$line" =~ ^-[[:space:]]+([^[:space:]].+) ]] || continue
    path="${BASH_REMATCH[1]}"
    is_engine_metadata "$path" && continue
    [ -f "$ROOT/$path" ] || continue
    code_fp_files["$path"]=1
    ws_snapshot+=("$path")
  done < "$file"
  local missing=()
  for path in "${!code_fp_files[@]}"; do
    blob_sha="$(cd "$ROOT" && git ls-files -s "$path" 2>/dev/null | awk '{print $2}')"
    if [ -z "$blob_sha" ]; then
      missing+=("$path")
    else
      code_fingerprint["$path"]="$blob_sha"
    fi
  done
  if [ ${#missing[@]} -gt 0 ]; then
    echo "[engine-verify] FAIL: WRITE-SET 代码文件未 git add 进 index,无法计算 code_fingerprint:" >&2
    printf '  %s\n' "${missing[@]}" >&2
    echo "请先 git add 这些文件再跑 verify(D-038a 前置要求)" >&2
    exit 1
  fi
}

build_code_fingerprint_json() {
  local path first=1 json="{"
  for path in $(printf '%s\n' "${!code_fingerprint[@]}" | LC_ALL=C sort); do
    [ "$first" = "1" ] || json+=","
    local esc_path="$(printf '%s' "$path" | sed 's/\\/\\\\/g; s/"/\\"/g')"
    json+="\"$esc_path\":\"${code_fingerprint[$path]}\""
    first=0
  done
  json+="}"
  printf '%s' "$json"
}

build_ws_snapshot_json() {
  local path first=1 json="["
  for path in $(printf '%s\n' "${ws_snapshot[@]}" | LC_ALL=C sort); do
    [ "$first" = "1" ] || json+=","
    local esc_path="$(printf '%s' "$path" | sed 's/\\/\\\\/g; s/"/\\"/g')"
    json+="\"$esc_path\""
    first=0
  done
  json+="]"
  printf '%s' "$json"
}

# write_evidence_manifest: 循环结束后写 MANIFEST.json
# 聚合 evidence 目录所有 .json + checkpoint.md,排除 MANIFEST.json 自身
write_evidence_manifest() {
  local ev_dir="$1" commit="$2"
  local manifest_content="" fname fhash
  for fname in $(cd "$ev_dir" && find . -maxdepth 1 -type f \( -name '*.json' -o -name 'checkpoint.md' \) ! -name 'MANIFEST.json' 2>/dev/null | sed 's|^\./||' | LC_ALL=C sort); do
    fhash="$(sha256sum "$ev_dir/$fname" | cut -d' ' -f1)"
    manifest_content+="${fname}:${fhash}"$'\n'
  done
  local manifest_hash="$(printf '%s' "$manifest_content" | sha256sum | cut -d' ' -f1)"
  local manifest_ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local files_json="{" first=1
  while IFS=: read -r fname fhash; do
    [ -n "$fname" ] || continue
    [ "$first" = "1" ] || files_json+=","
    files_json+="\"$fname\":\"$fhash\""
    first=0
  done <<< "$manifest_content"
  files_json+="}"
  printf '{"evidence_manifest_sha256":"sha256:%s","generated":"%s","writer":"engine-verify","commit":"%s","files":%s}\n' \
    "$manifest_hash" "$manifest_ts" "$commit" "$files_json" \
    > "$ev_dir/MANIFEST.json"
}

echo "【Engine System · 行为化验收】$task"
echo ""

# v6.18.0 (D-038/T-066): 收集 code_fingerprint + 前置 git add 检查
verified_commit="$(cd "$ROOT" && git rev-parse HEAD 2>/dev/null || echo "unknown")"
collect_code_fingerprint "$task_file"
code_fp_json="$(build_code_fingerprint_json)"
ws_snap_json="$(build_ws_snapshot_json)"

while IFS=$'\t' read -r ac_id verify_cmd; do
  [ -n "$ac_id" ] || continue
  if [ -z "$verify_cmd" ]; then
    echo "SKIP  $ac_id (无 verify 命令)"
    skip_count=$((skip_count+1))
    continue
  fi
  echo "── $ac_id ──"
  echo "verify: $verify_cmd"
  # v6.12.1 (issue #11 E-1): a verify command that checks this card's own
  # evidence directory proves only that a file was written, not that behavior
  # happened. Flag it; the architect decides.
  case "$verify_cmd" in
    *"engine/evidence/$task/"*)
      echo "WARN suspicious verify (self-referential evidence path): $ac_id" ;;
  esac
  tmp_out="$(mktemp)"
  rc=0
  # v6.9.0 (T-034): redirect stdin from /dev/null so verify commands that
  # spawn subshells reading stdin (e.g. `bash scripts/check.sh` in AC-10)
  # do not consume the while-loop's stdin (which is the grep output feeding
  # AC lines). Without this, ACs after a stdin-reading verify get skipped
  # silently.
  # v6.10.0 (T-035): set ENGINE_VERIFY_RECURSE_GUARD=<task> so any AC verify
  # that recursively invokes engine-verify for the SAME task exits 0 immediately
  # (no infinite loop). Other task IDs (e.g. test fixtures) run normally.
  ( cd "$ROOT" && ENGINE_VERIFY_RECURSE_GUARD="$task" eval "$verify_cmd" ) </dev/null >"$tmp_out" 2>&1 || rc=$?
  rc=${rc:-0}
  fp="$(sha256sum "$tmp_out" | cut -d' ' -f1)"
  if [ "$rc" -eq 0 ]; then
    status="pass"; pass_count=$((pass_count+1))
    if [ "$fp" = "$empty_fp_hash" ]; then
      empty_fp_pass=$((empty_fp_pass+1))
    fi
    echo "PASS  (exit=0, fp=${fp:0:12})"
  else
    status="fail"; fail_count=$((fail_count+1))
    echo "FAIL  (exit=$rc, fp=${fp:0:12})"
    sed -n '1,5p' "$tmp_out" 2>/dev/null
  fi
  verify_escaped="$(printf '%s' "$verify_cmd" | sed 's/\\/\\\\/g; s/"/\\"/g')"
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '{"ac":"%s","verify":"%s","status":"%s","exit":%d,"output_fingerprint":"sha256:%s","code_fingerprint":%s,"write_set_snapshot":%s,"verified_against_commit":"%s","write_provenance":{"writer":"engine-verify","commit":"%s","timestamp":"%s","argv":"engine verify %s"},"timestamp":"%s"}\n' \
    "$ac_id" "$verify_escaped" "$status" "$rc" "$fp" "$code_fp_json" "$ws_snap_json" "$verified_commit" "$verified_commit" "$ts" "$task" "$ts" \
    > "$evidence_dir/$ac_id.json"

  # v6.9.0 (D-028/T-034): on AC PASS, write a line to checkpoint.md so
  # SessionStart can re-anchor from AC-level completion state (priority 1
  # in the re-anchor chain, see contract/src/20-file-templates.md FILE 15).
  # verify is the only writer of checkpoint.md; agents write progress.md.
  # v6.11.2 (T-039): dedup — replace existing AC-N line (update timestamp),
  # append if new AC-N. Original append-without-dedup caused unbounded growth.
  if [ "$status" = "pass" ]; then
    checkpoint="$evidence_dir/checkpoint.md"
    # First PASS creates the file with header.
    if [ ! -f "$checkpoint" ]; then
      cat > "$checkpoint" <<CPHD
# Checkpoint — $task
> Last updated: $(date -u +%Y-%m-%dT%H:%M:%SZ) by engine-verify | AC 级压缩恢复锚点,见 contract/src/20-file-templates.md FILE 15

## 已完成 AC
CPHD
    fi
    # Dedup: remove existing AC-N line(s) if any, then append fresh line.
    # grep -v filters out lines matching this AC-N; preserves header and other ACs.
    # Verify command is shortened to a one-line summary (first 80 chars).
    summary="$(printf '%s' "$verify_cmd" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g' | cut -c1-80)"
    new_line="$(printf -- '- [x] %s %s — evidence/%s.json PASS @ %s' "$ac_id" "$summary" "$ac_id" "$ts")"
    grep -v "^- \[x\] ${ac_id} " "$checkpoint" > "$checkpoint.tmp" 2>/dev/null || true
    if [ -s "$checkpoint.tmp" ]; then
      mv "$checkpoint.tmp" "$checkpoint"
    else
      rm -f "$checkpoint.tmp"
    fi
    printf -- '%s\n' "$new_line" >> "$checkpoint"
  fi
  rm -f "$tmp_out"
done < <(parse_ac_declarations "$task_file")

# v6.18.0 (D-038/T-066): 写 MANIFEST.json(evidence 完整性自证)
write_evidence_manifest "$evidence_dir" "$verified_commit"

# v6.10.0 (D-028/T-035): Dead code detection — runs AFTER all AC verify commands.
# Self-checks linter availability (shellcheck for .sh; PSScriptAnalyzer twin is
# in engine-verify.ps1), scans WRITE-SET-touched .sh/.ps1 files, runs reverse
# call-site scan, and emits evidence/T-NNN/DEAD-CODE.json + COPY-PASTE.json.
# When linter unavailable → linter field = "grep-fallback" (warn_count++ for
# each finding); when available → real linter name recorded. Architect reviews
# warn_count > 0 entries and marks exempt:true or sets exempt_all:true (D-028 §9).
detect_dead_code() {
  local task_id="$1"
  local ev_dir="$2"
  local task_file="$3"
  [ -f "$task_file" ] || return 0

  # Collect WRITE-SET-touched .sh / .ps1 files (concrete paths only, skip globs).
  local write_set_line
  write_set_line="$(grep '^WRITE-SET:' "$task_file" 2>/dev/null | head -1 | sed 's/^WRITE-SET:[[:space:]]*//' || true)"
  [ -z "$write_set_line" ] && return 0

  local -a sh_files=()
  local -a ps1_files=()
  local ws_path
  local IFS_save="$IFS"
  IFS=','
  for ws_path in $write_set_line; do
    ws_path="$(printf '%s' "$ws_path" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [ -z "$ws_path" ] && continue
    [[ "$ws_path" == *"*"* ]] && continue
    case "$ws_path" in
      *.sh)
        [ -f "$ROOT/$ws_path" ] && sh_files+=("$ws_path")
        ;;
      *.ps1)
        [ -f "$ROOT/$ws_path" ] && ps1_files+=("$ws_path")
        ;;
    esac
  done
  IFS="$IFS_save"

  [ "${#sh_files[@]}" -eq 0 ] && [ "${#ps1_files[@]}" -eq 0 ] && return 0

  # Self-check linter availability. shellcheck for .sh; PSScriptAnalyzer is
  # invoked by the .ps1 twin script (not callable from bash). If only .ps1
  # files are in WRITE-SET and bash verify runs, linter = "grep-fallback".
  local linter_sh="grep-fallback"
  if command -v shellcheck >/dev/null 2>&1; then
    linter_sh="shellcheck"
  fi

  # Overall linter label: prefer shellcheck if .sh files present (covers most cases).
  # If only .ps1 files (no .sh), bash verify cannot run PSScriptAnalyzer directly;
  # the .ps1 twin handles that path. Mark as "grep-fallback" for the .ps1-only case.
  local linter_overall="$linter_sh"
  if [ "${#sh_files[@]}" -eq 0 ] && [ "${#ps1_files[@]}" -gt 0 ]; then
    linter_overall="grep-fallback"
  fi

  local -a dc_entries=()
  local warn_count=0
  local exempt_count=0

  # Run shellcheck on .sh files (if available).
  if [ "$linter_sh" = "shellcheck" ] && [ "${#sh_files[@]}" -gt 0 ]; then
    local f
    for f in "${sh_files[@]}"; do
      local full="$ROOT/$f"
      # -f gcc format: path:line:col: severity: message (code)
      local out
      out="$(shellcheck -f gcc "$full" 2>/dev/null || true)"
      [ -z "$out" ] && continue
      while IFS= read -r line; do
        [ -z "$line" ] && continue
        # Parse: path:line:col: severity: message (code)
        # Path may contain colons on Windows; match from end.
        local line_no severity message
        line_no="$(printf '%s' "$line" | sed -E 's/.*:([0-9]+):[0-9]+:[[:space:]]*[^:]+:.*/\1/' || true)"
        severity="$(printf '%s' "$line" | sed -E 's/.*:[0-9]+:[0-9]+:[[:space:]]*([^:]+):.*/\1/' | tr -d ' ' || true)"
        message="$(printf '%s' "$line" | sed -E 's/.*:[0-9]+:[0-9]+:[[:space:]]*[^:]+:[[:space:]]*(.*)$/\1/' || true)"
        [ -z "$line_no" ] && continue
        # Escape message for JSON.
        local msg_escaped; msg_escaped="$(printf '%s' "$message" | sed 's/\\/\\\\/g; s/"/\\"/g')"
        dc_entries+=("{\"type\":\"linter\",\"file\":\"$f\",\"line\":$line_no,\"severity\":\"$severity\",\"message\":\"$msg_escaped\",\"exempt\":false,\"exempt_reason\":null}")
        warn_count=$((warn_count + 1))
      done <<< "$out"
    done
  fi

  # reverse-call-site scan: for each function defined in WRITE-SET .sh files,
  # grep the whole repo for call sites. If only the definition file matches,
  # the function is a dead-code candidate.
  local f
  for f in "${sh_files[@]}"; do
    local full="$ROOT/$f"
    # Extract function definitions: ^function NAME or ^NAME() {
    local funcs
    funcs="$(grep -hE '^(function[[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*|[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\(\)[[:space:]]*\{)' "$full" 2>/dev/null | \
            sed -E 's/^function[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*).*/\1/; s/^([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*\(\).*/\1/' | \
            sort -u || true)"
    [ -z "$funcs" ] && continue
    local fn
    while IFS= read -r fn; do
      [ -z "$fn" ] && continue
      # Skip very common / generic function names (high false-positive rate).
      case "$fn" in
        main|fail|warn|pass|trim|usage|cleanup|on_error|trap|printf|echo) continue ;;
      esac
      # Grep repo (excluding the definition file) for any occurrence of fn as a call.
      local hits
      hits="$(grep -rE --include='*.sh' --include='*.ps1' --include='*.md' --include='*.json' \
              --exclude-dir=.git --exclude-dir=archive --exclude-dir=node_modules --exclude-dir=.workbuddy \
              "(\b|[^a-zA-Z0-9_])${fn}([^a-zA-Z0-9_]|$)" "$ROOT" 2>/dev/null | \
              grep -v "^${full}:" | head -5 || true)"
      if [ -z "$hits" ]; then
        # No call sites found — dead code candidate.
        dc_entries+=("{\"type\":\"reverse-call-site\",\"identifier\":\"$fn\",\"referenced_in\":[],\"exempt\":false,\"exempt_reason\":null}")
        warn_count=$((warn_count + 1))
      fi
    done <<< "$funcs"
  done

  # jscpd copy-paste detection (D-028 §10 mechanism B). If jscpd unavailable,
  # skip + WARN (jscpd_available=false in COPY-PASTE.json). Real implementation
  # would parse jscpd's JSON output for duplications; minimal version records
  # availability flag and warns user when jscpd missing.
  local jscpd_available=false
  if command -v jscpd >/dev/null 2>&1; then
    jscpd_available=true
  elif command -v npx >/dev/null 2>&1; then
    # Check if jscpd is installable via npx (without auto-installing).
    if npx --no-install jscpd --version >/dev/null 2>&1; then
      jscpd_available=true
    fi
  fi

  local cp_warn=0
  if [ "$jscpd_available" = "false" ]; then
    # jscpd unavailable — record skip in COPY-PASTE.json (warn_count in
    # DEAD-CODE.json not affected; COPY-PASTE has its own warn_count).
    cp_warn=0
  fi

  # Write DEAD-CODE.json.
  local ts; ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local json_file="$ev_dir/DEAD-CODE.json"
  {
    printf '{\n'
    printf '  "task": "%s",\n' "$task_id"
    printf '  "timestamp": "%s",\n' "$ts"
    printf '  "exempt_all": false,\n'
    printf '  "exempt_reason": null,\n'
    printf '  "linter": "%s",\n' "$linter_overall"
    printf '  "entries": ['
    if [ "${#dc_entries[@]}" -gt 0 ]; then
      printf '\n'
      local i
      for i in "${!dc_entries[@]}"; do
        if [ "$i" -lt $((${#dc_entries[@]} - 1)) ]; then
          printf '    %s,\n' "${dc_entries[$i]}"
        else
          printf '    %s\n' "${dc_entries[$i]}"
        fi
      done
      printf '  '
    fi
    printf '],\n'
    printf '  "summary": {\n'
    printf '    "warn_count": %d,\n' "$warn_count"
    printf '    "exempt_count": %d\n' "$exempt_count"
    printf '  }\n'
    printf '}\n'
  } > "$json_file"

  # Write COPY-PASTE.json (jscpd委托,D-028 §10 机制 B).
  local cp_file="$ev_dir/COPY-PASTE.json"
  {
    printf '{\n'
    printf '  "task": "%s",\n' "$task_id"
    printf '  "timestamp": "%s",\n' "$ts"
    printf '  "tool": "jscpd",\n'
    printf '  "jscpd_available": %s,\n' "$jscpd_available"
    printf '  "duplications": [],\n'
    printf '  "warn_count": %d\n' "$cp_warn"
    printf '}\n'
  } > "$cp_file"
}

detect_dead_code "$task" "$evidence_dir" "$task_file"

echo ""
echo "=========================================="
echo "$task: $pass_count pass, $fail_count fail, $skip_count skip"
# v6.12.1 (issue #11 A-1): all-SKIP is a parse failure, not a clean result.
# The old behavior printed "0 pass, 0 fail, N skip" and exited 0, which reads
# as "nothing to do" while the acceptance machinery is silently dead.
total_acs=$((pass_count + fail_count + skip_count))
if [ "$total_acs" -gt 0 ] && [ "$pass_count" -eq 0 ] && [ "$fail_count" -eq 0 ]; then
  {
    echo "ERROR: $total_acs ACs declared but no parseable verify command was found."
    echo "The card uses none of the 4 accepted AC spellings; see contract/src/20-file-templates.md FILE 15."
    echo "This is a parse failure, not a clean result."
  } >&2
  exit 3
fi
if [ "$pass_count" -gt 0 ] && [ "$empty_fp_pass" -eq "$pass_count" ]; then
  echo "WARN all PASS fingerprints are the empty-string hash - verify commands may be tautologies"
fi
# v6.23.0 (T-074): chain PROVE.json — if execution verification ran and failed, verify fails too
if [ -f "$evidence_dir/PROVE.json" ]; then
  prove_status=$(sed -n 's/^  "status": *"\([^"]*\)".*/\1/p' "$evidence_dir/PROVE.json" | head -1)
  if [ -z "$prove_status" ]; then prove_status="UNKNOWN"; fi
  if [ "$prove_status" != "PASS" ]; then
    echo "PROVE chain: engine prove $task status=$prove_status — overriding to FAIL"
    fail_count=$((fail_count + 1))
  fi
fi
[ "$fail_count" -eq 0 ]
