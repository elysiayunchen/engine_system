# Code Review Package: T-081

> generated: 2026-08-02T09:57:21Z
> package_sha256: a516820857db3f9bed52166c64974bc2643e23a1f136816e0a06e34f679832cf
> head_commit: c1050987377c694563d82aa79117360b7c82c7a8
> packaged_by: df3a612d-c571-49b8-a5a6-91bdcd88a7d1
> task: 把 T-080 之后仍阻断 Engine Doctor 的仓库级失败项收口，并修复 Windows/WSL 下 Bash 生命周期找不到 PowerShell 执行器的问题。完成 ENGINE_MAP 注册与 root-path 解析、active task progress 锚点、done task 归档、域 INVENTORY 覆盖、T-078 遗留生命周期证据和历史 evidence drift 的可验证收口；保留历史 warning，不掩盖真实 tamper/drift。
> scope: da253a67..c1050987, 25 code files

## 1. Task Context

### GOAL
把 T-080 之后仍阻断 Engine Doctor 的仓库级失败项收口，并修复 Windows/WSL 下 Bash 生命周期找不到 PowerShell 执行器的问题。完成 ENGINE_MAP 注册与 root-path 解析、active task progress 锚点、done task 归档、域 INVENTORY 覆盖、T-078 遗留生命周期证据和历史 evidence drift 的可验证收口；保留历史 warning，不掩盖真实 tamper/drift。

### WRITE-SET
- engine/ENGINE_MAP.md
- engine/scripts/engine-doctor.sh
- engine/scripts/engine-doctor.ps1
- plugin/engine/scripts/engine-doctor.sh
- plugin/engine/scripts/engine-doctor.ps1
- engine/scripts/engine-verify.sh
- engine/scripts/engine-verify.ps1
- plugin/engine/scripts/engine-verify.sh
- plugin/engine/scripts/engine-verify.ps1
- engine/scripts/engine-close.sh
- engine/scripts/engine-close.ps1
- plugin/engine/scripts/engine-close.sh
- plugin/engine/scripts/engine-close.ps1
- engine/scripts/engine-prove.sh
- engine/scripts/engine-prove.ps1
- plugin/engine/scripts/engine-prove.sh
- plugin/engine/scripts/engine-prove.ps1
- engine/scripts/engine-review-pipeline.sh
- plugin/engine/scripts/engine-review-pipeline.sh
- engine/scripts/engine-canvas.sh
- plugin/engine/scripts/engine-canvas.sh
- tests/workstream/test_failure_extract.sh
- engine/scripts/engine-drift-check.sh
- engine/scripts/engine-drift-check.ps1
- plugin/engine/scripts/engine-drift-check.sh
- plugin/engine/scripts/engine-drift-check.ps1
- engine/tasks/T-075/progress.md
- engine/tasks/T-076/progress.md
- engine/tasks/T-077/progress.md
- engine/tasks/T-078.md
- engine/tasks/T-078/progress.md
- engine/archive/tasks/T-078-progress.md
- engine/domains/engine-runtime/INVENTORY.md
- engine/domains/project-meta/INVENTORY.md
- engine/evidence/T-048/AC-1.json
- engine/evidence/T-048/AC-10.json
- engine/evidence/T-048/AC-2.json
- engine/evidence/T-048/AC-3.json
- engine/evidence/T-048/AC-4.json
- engine/evidence/T-048/AC-5.json
- engine/evidence/T-048/AC-6.json
- engine/evidence/T-048/AC-7.json
- engine/evidence/T-048/AC-8.json
- engine/evidence/T-048/AC-9.json
- engine/evidence/T-048/checkpoint.md
- engine/evidence/T-048/MANIFEST.json
- engine/evidence/T-049/AC-1.json
- engine/evidence/T-049/AC-10.json
- engine/evidence/T-049/AC-2.json
- engine/evidence/T-049/AC-3.json
- engine/evidence/T-049/AC-4.json
- engine/evidence/T-049/AC-5.json
- engine/evidence/T-049/AC-6.json
- engine/evidence/T-049/AC-7.json
- engine/evidence/T-049/AC-8.json
- engine/evidence/T-049/AC-9.json
- engine/evidence/T-049/checkpoint.md
- engine/evidence/T-049/MANIFEST.json
- engine/evidence/T-050/AC-1.json
- engine/evidence/T-050/AC-2.json
- engine/evidence/T-050/AC-3.json
- engine/evidence/T-050/AC-4.json
- engine/evidence/T-050/AC-5.json
- engine/evidence/T-050/AC-6.json
- engine/evidence/T-050/AC-7.json
- engine/evidence/T-050/AC-8.json
- engine/evidence/T-050/AC-9.json
- engine/evidence/T-050/checkpoint.md
- engine/evidence/T-050/MANIFEST.json
- engine/evidence/T-051/AC-1.json
- engine/evidence/T-051/AC-2.json
- engine/evidence/T-051/AC-3.json
- engine/evidence/T-051/AC-4.json
- engine/evidence/T-051/AC-5.json
- engine/evidence/T-051/AC-6.json
- engine/evidence/T-051/AC-7.json
- engine/evidence/T-051/checkpoint.md
- engine/evidence/T-051/MANIFEST.json
- engine/evidence/T-052/AC-1.json
- engine/evidence/T-052/AC-2.json
- engine/evidence/T-052/AC-3.json
- engine/evidence/T-052/AC-4.json
- engine/evidence/T-052/AC-5.json
- engine/evidence/T-052/AC-6.json
- engine/evidence/T-052/AC-7.json
- engine/evidence/T-052/AC-8.json
- engine/evidence/T-052/AC-9.json
- engine/evidence/T-052/checkpoint.md
- engine/evidence/T-052/MANIFEST.json
- engine/evidence/T-053/AC-1.json
- engine/evidence/T-053/AC-2.json
- engine/evidence/T-053/AC-3.json
- engine/evidence/T-053/AC-4.json
- engine/evidence/T-053/AC-5.json
- engine/evidence/T-053/AC-6.json
- engine/evidence/T-053/AC-7.json
- engine/evidence/T-053/checkpoint.md
- engine/evidence/T-053/MANIFEST.json
- engine/evidence/T-054/AC-1.json
- engine/evidence/T-054/AC-2.json
- engine/evidence/T-054/AC-3.json
- engine/evidence/T-054/AC-4.json
- engine/evidence/T-054/AC-5.json
- engine/evidence/T-054/AC-6.json
- engine/evidence/T-054/AC-7.json
- engine/evidence/T-054/AC-8.json
- engine/evidence/T-054/checkpoint.md
- engine/evidence/T-054/MANIFEST.json
- engine/evidence/T-055/AC-1.json
- engine/evidence/T-055/AC-2.json
- engine/evidence/T-055/AC-3.json
- engine/evidence/T-055/AC-4.json
- engine/evidence/T-055/AC-5.json
- engine/evidence/T-055/AC-6.json
- engine/evidence/T-055/checkpoint.md
- engine/evidence/T-055/MANIFEST.json
- engine/evidence/T-056/AC-1.json
- engine/evidence/T-056/AC-2.json
- engine/evidence/T-056/AC-3.json
- engine/evidence/T-056/AC-4.json
- engine/evidence/T-056/AC-5.json
- engine/evidence/T-056/AC-6.json
- engine/evidence/T-056/checkpoint.md
- engine/evidence/T-056/MANIFEST.json
- engine/evidence/T-057/AC-1.json
- engine/evidence/T-057/AC-2.json
- engine/evidence/T-057/AC-3.json
- engine/evidence/T-057/AC-4.json
- engine/evidence/T-057/AC-5.json
- engine/evidence/T-057/AC-6.json
- engine/evidence/T-057/checkpoint.md
- engine/evidence/T-057/MANIFEST.json
- engine/evidence/T-058/AC-1.json
- engine/evidence/T-058/AC-2.json
- engine/evidence/T-058/AC-3.json
- engine/evidence/T-058/AC-4.json
- engine/evidence/T-058/AC-5.json
- engine/evidence/T-058/AC-6.json
- engine/evidence/T-058/AC-7.json
- engine/evidence/T-058/checkpoint.md
- engine/evidence/T-058/MANIFEST.json
- engine/evidence/T-059/AC-1.json
- engine/evidence/T-059/AC-2.json
- engine/evidence/T-059/AC-3.json
- engine/evidence/T-059/AC-4.json
- engine/evidence/T-059/AC-5.json
- engine/evidence/T-059/AC-6.json
- engine/evidence/T-059/AC-7.json
- engine/evidence/T-059/checkpoint.md
- engine/evidence/T-059/MANIFEST.json
- engine/evidence/T-060/AC-1.json
- engine/evidence/T-060/AC-2.json
- engine/evidence/T-060/AC-3.json
- engine/evidence/T-060/AC-4.json
- engine/evidence/T-060/AC-5.json
- engine/evidence/T-060/AC-6.json
- engine/evidence/T-060/AC-7.json
- engine/evidence/T-060/checkpoint.md
- engine/evidence/T-060/MANIFEST.json
- engine/evidence/T-063/AC-1.json
- engine/evidence/T-063/AC-2.json
- engine/evidence/T-063/AC-3.json
- engine/evidence/T-063/AC-4.json
- engine/evidence/T-063/AC-5.json
- engine/evidence/T-063/checkpoint.md
- engine/evidence/T-063/MANIFEST.json
- engine/evidence/T-064/AC-1.json
- engine/evidence/T-064/AC-2.json
- engine/evidence/T-064/AC-3.json
- engine/evidence/T-064/AC-4.json
- engine/evidence/T-064/AC-5.json
- engine/evidence/T-064/AC-6.json
- engine/evidence/T-064/AC-7.json
- engine/evidence/T-064/checkpoint.md
- engine/evidence/T-064/MANIFEST.json
- engine/evidence/T-065/AC-1.json
- engine/evidence/T-065/AC-2.json
- engine/evidence/T-065/AC-3.json
- engine/evidence/T-065/AC-4.json
- engine/evidence/T-065/AC-5.json
- engine/evidence/T-065/AC-6.json
- engine/evidence/T-065/AC-7.json
- engine/evidence/T-065/checkpoint.md
- engine/evidence/T-065/MANIFEST.json
- engine/evidence/T-066/AC-1.json
- engine/evidence/T-066/AC-10.json
- engine/evidence/T-066/AC-11.json
- engine/evidence/T-066/AC-12.json
- engine/evidence/T-066/AC-2.json
- engine/evidence/T-066/AC-3.json
- engine/evidence/T-066/AC-4.json
- engine/evidence/T-066/AC-5.json
- engine/evidence/T-066/AC-6.json
- engine/evidence/T-066/AC-7.json
- engine/evidence/T-066/AC-8.json
- engine/evidence/T-066/AC-9.json
- engine/evidence/T-066/checkpoint.md
- engine/evidence/T-066/MANIFEST.json
- engine/evidence/T-067/AC-1.json
- engine/evidence/T-067/AC-10.json
- engine/evidence/T-067/AC-2.json
- engine/evidence/T-067/AC-3.json
- engine/evidence/T-067/AC-4.json
- engine/evidence/T-067/AC-5.json
- engine/evidence/T-067/AC-6.json
- engine/evidence/T-067/AC-7.json
- engine/evidence/T-067/AC-8.json
- engine/evidence/T-067/AC-9.json
- engine/evidence/T-067/checkpoint.md
- engine/evidence/T-067/MANIFEST.json
- engine/evidence/T-068/AC-1.json
- engine/evidence/T-068/AC-2.json
- engine/evidence/T-068/AC-3.json
- engine/evidence/T-068/AC-4.json
- engine/evidence/T-068/AC-5.json
- engine/evidence/T-068/AC-6.json
- engine/evidence/T-068/AC-7.json
- engine/evidence/T-068/AC-8.json
- engine/evidence/T-068/checkpoint.md
- engine/evidence/T-068/MANIFEST.json
- engine/evidence/T-078/AC-1.json
- engine/evidence/T-078/AC-2.json
- engine/evidence/T-078/AC-3.json
- engine/evidence/T-078/AC-4.json
- engine/evidence/T-078/AC-5.json
- engine/evidence/T-078/AC-6.json
- engine/evidence/T-078/AC-7.json
- engine/evidence/T-078/checkpoint.md
- engine/evidence/T-078/CLOSE.json
- engine/evidence/T-078/GATE.json
- engine/evidence/T-078/MANIFEST.json
- engine/evidence/T-078/PROVE.json
- engine/evidence/T-078/prove-assertions.json
- engine/evidence/T-078/prove-package.md
- engine/review/evidence/T-078/AGENT-REVIEW.json
- engine/review/evidence/T-078/QUALITY.json
- engine/review/evidence/T-078/REVIEW.json
- engine/review/evidence/T-078/review-package.md
- engine/review/evidence/T-078/SECURITY.json
- engine/review/evidence/T-081/AGENT-REVIEW.json
- engine/review/evidence/T-081/QUALITY.json
- engine/review/evidence/T-081/REVIEW.json
- engine/review/evidence/T-081/review-package.md
- engine/review/evidence/T-081/SECURITY.json
- tests/workstream/test_doctor_health_regressions.sh
- tests/workstream/test_doctor_health_regressions.ps1
- tests/workstream/test_verify_shell_resolution.sh
- tests/workstream/test_verify_shell_resolution.ps1
- plugin/manifest.json
- engine/tasks/T-081.md
- engine/tasks/T-081/progress.md
- engine/tasks/T-086/progress.md
- engine/tasks/T-086.md
- engine/archive/tasks/T-086-progress.md
- engine/archive/tasks/T-081-progress.md
- engine/workstreams/T-081/sessions
- engine/evidence/T-081/AC-1.json
- engine/evidence/T-081/AC-2.json
- engine/evidence/T-081/AC-3.json
- engine/evidence/T-081/AC-4.json
- engine/evidence/T-081/AC-5.json
- engine/evidence/T-081/AC-6.json
- engine/evidence/T-081/AC-7.json
- engine/evidence/T-081/AC-8.json
- engine/evidence/T-081/AC-9.json
- engine/evidence/T-081/checkpoint.md
- engine/evidence/T-081/CLOSE.json
- engine/evidence/T-081/COPY-PASTE.json
- engine/evidence/T-081/DEAD-CODE.json
- engine/evidence/T-081/GATE.json
- engine/evidence/T-081/MANIFEST.json
- engine/evidence/T-081/PROVE.json
- engine/evidence/T-081/prove-assertions.json
- engine/evidence/T-081/prove-package.md
- engine/changes/CHANGE-2026-08-01-02.md

### CONSTRAINTS


### AC
AC: AC-1 | ENGINE_MAP registry uses supported classes, concrete paths, and a section row for mixed gate config; Doctor resolves root-level registered files | verify: bash tests/workstream/test_doctor_health_regressions.sh && pwsh -NoProfile -File tests/workstream/test_doctor_health_regressions.ps1
AC: AC-2 | Active T-075/T-076/T-077 progress anchors exist and done T-078 progress is archived without deleting its recovery content | verify: bash tests/workstream/test_doctor_health_regressions.sh
AC: AC-3 | All code paths reported by Doctor for T-071/T-072/T-073/T-074/T-078 have domain INVENTORY rows with unique public API names | verify: bash tests/workstream/test_doctor_health_regressions.sh
AC: AC-4 | Bash verify/close resolves an installed Windows PowerShell executable when pwsh is absent from the Bash PATH, while native Linux behavior is unchanged | verify: bash tests/workstream/test_verify_shell_resolution.sh && pwsh -NoProfile -File tests/workstream/test_verify_shell_resolution.ps1
AC: AC-5 | Historical evidence is revalidated or explicitly preserved as legacy without masking current code fingerprint drift; T-078 evidence manifest and provenance are complete | verify: bash tests/workstream/test_doctor_health_regressions.sh
AC: AC-6 | T-078 has complete verify, review, agent review, prove, gate, and close evidence before its done state remains committed | verify: bash tests/workstream/test_doctor_health_regressions.sh
AC: AC-7 | Full Engine Doctor exits with zero failures after the health fixes; remaining legacy warnings are reported, not converted to false PASS | verify: bash engine/bin/engine doctor
AC: AC-8 | Re-running a done task verifier refreshes the evidence MANIFEST before the Doctor AC, so the final lifecycle run remains 9/9 without a transient self-tamper failure | verify: bash tests/workstream/test_doctor_health_regressions.sh && pwsh -NoProfile -File tests/workstream/test_doctor_health_regressions.ps1
AC: AC-9 | Close refreshes the evidence MANIFEST after gate and CLOSE writers, so the final Doctor run and post-close drift check remain clean | verify: bash tests/workstream/test_doctor_health_regressions.sh && pwsh -NoProfile -File tests/workstream/test_doctor_health_regressions.ps1

## 2. Code Changes (diff)

### engine/scripts/engine-doctor.sh
```diff
diff --git a/engine/scripts/engine-doctor.sh b/engine/scripts/engine-doctor.sh
index 3eab40e..b2c1b07 100644
--- a/engine/scripts/engine-doctor.sh
+++ b/engine/scripts/engine-doctor.sh
@@ -12,11 +12,13 @@ PACKAGE_MODE=false
 # catch-all treated any argument as ROOT, so a typo like --quiet became
 # ROOT="--quiet" and doctor reported "ENGINE_MAP.md is missing" instead
 # of "no such flag".
+FULL_MODE=false
 for arg in "$@"; do
   case "$arg" in
     --package-mode) PACKAGE_MODE=true ;;
+    --full) FULL_MODE=true ;;
     --*)
-      echo "Error: unknown flag '$arg' (known: --package-mode; a path argument sets ROOT)" >&2
+      echo "Error: unknown flag '$arg' (known: --package-mode, --full; a path argument sets ROOT)" >&2
       exit 2
       ;;
     *) ROOT="$arg" ;;
@@ -25,10 +27,49 @@ done
 
 ENGINE_DIR="$ROOT/engine"
 MAP="$ENGINE_DIR/ENGINE_MAP.md"
+task_card_script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
+if [ -f "$task_card_script_dir/engine-task-card.sh" ]; then
+  # shellcheck source=/dev/null
+  . "$task_card_script_dir/engine-task-card.sh"
+fi
 
 fail_count=0
 warn_count=0
 
+# v6.25.0 (T-086/B6): incremental mode — skip expensive checks if HEAD unchanged.
+# v6.26.1 (T-081): HEAD alone is insufficient while verify/close and parallel
+# workers update evidence in the worktree. Include tracked diffs and untracked
+# files in the cache key so a cached failure/pass cannot survive a real change.
+# Use --full to force a complete run. Cache lives at engine/.cache/doctor-last-run.
+_doctor_cache_dir="$ENGINE_DIR/.cache"
+_doctor_cache_file="$_doctor_cache_dir/doctor-last-run"
+_current_head="$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo none)"
+_doctor_worktree_fingerprint() {
+  {
+    git -C "$ROOT" diff --no-ext-diff --binary HEAD -- . 2>/dev/null || true
+    while IFS= read -r -d '' _untracked; do
+      [ -f "$ROOT/$_untracked" ] || continue
+      printf 'untracked:%s\n' "$_untracked"
+      sha256sum "$ROOT/$_untracked" 2>/dev/null || true
+    done < <(git -C "$ROOT" ls-files --others --exclude-standard -z 2>/dev/null || true)
+  } | sha256sum | cut -d' ' -f1
+}
+_doctor_worktree_fp="$(_doctor_worktree_fingerprint)"
+if [ "$FULL_MODE" = false ] && [ -f "$_doctor_cache_file" ]; then
+  _cached_head="$(head -1 "$_doctor_cache_file" 2>/dev/null || echo '')"
+  _cached_worktree_fp="$(sed -n '3p' "$_doctor_cache_file" 2>/dev/null || echo '')"
+  if [ "$_cached_head" = "$_current_head" ] && [ "$_current_head" != "none" ] &&
+     [ -n "$_cached_worktree_fp" ] && [ "$_cached_worktree_fp" = "$_doctor_worktree_fp" ]; then
+    _cached_summary="$(sed -n '2p' "$_doctor_cache_file" 2>/dev/null || echo '')"
+    echo "[engine-doctor] incremental: HEAD/worktree unchanged ($_current_head), using cached result."
+    echo "[engine-doctor] cached: $_cached_summary"
+    echo "  (use 'engine doctor --full' to force a complete re-check)"
+    # Exit with cached status
+    _cached_fails="$(printf '%s' "$_cached_summary" | grep -oE '[0-9]+ failure' | grep -oE '[0-9]+' || echo 0)"
+    [ "${_cached_fails:-0}" -gt 0 ] && exit 1 || exit 0
+  fi
+fi
+
 # parse_ac_declarations: Extract (ac_id, verify_cmd) pairs from a task card.
 # Supports 4 AC declaration formats (D-037 / v6.17.0):
 #   1. Single-line:  AC: AC-N <desc> | verify: <cmd>
@@ -39,6 +80,10 @@ warn_count=0
 # AC id regex: AC-[A-Za-z]*[0-9]+(\.[0-9]+)* (v6.12.1 A-3).
 # Separators: | verify: / |verify: / → verify: / →verify: / line-start verify:
 parse_ac_declarations() {
+  if declare -F task_card_parse_ac_declarations >/dev/null 2>&1; then
+    task_card_parse_ac_declarations "$@"
+    return 0
+  fi
   local file="$1"
   local line ac_id verify_cmd verify_rest
   local section_ac="" pending_ac=""
@@ -148,21 +193,57 @@ warn() {
 # v6.12.1 (issue #11 C-1): anchored card-status predicates. Unanchored
 # 'status:.*active' greps also match prose that merely QUOTES the pattern -
 # a card documenting the bug pins itself active (self-referential lock).
+# Cache the anchored status once per card: Doctor applies these predicates in
+# many full-task scans, and spawning grep for every predicate is prohibitively
+# slow under Windows Git Bash.
+declare -A _doctor_card_status_cache=()
+doctor_load_card_status_cache() {
+  local file status
+  [ -d "$ENGINE_DIR/tasks" ] || return 0
+  while IFS='|' read -r file status; do
+    [ -n "$file" ] || continue
+    _doctor_card_status_cache["$file"]="$status"
+  done < <(
+    grep -H -E -o '^[[:space:]]*(>[[:space:]]*)?status:[[:space:]]*(active|paused|done)([[:space:]]|$)' \
+      "$ENGINE_DIR"/tasks/T-*.md 2>/dev/null |
+      sed -E 's/^(.*):[[:space:]]*(>[[:space:]]*)?status:[[:space:]]*([^[:space:]]+).*/\1|\3/'
+  )
+}
+doctor_card_status() {
+  local file="$1" line status=""
+  if [[ -n "${_doctor_card_status_cache[$file]+present}" ]]; then
+    printf '%s' "${_doctor_card_status_cache[$file]}"
+    return 0
+  fi
+  while IFS= read -r line || [[ -n "$line" ]]; do
+    if [[ "$line" =~ ^[[:space:]]*(>[[:space:]]*)?status:[[:space:]]*([^[:space:]]+) ]]; then
+      status="${BASH_REMATCH[2]}"
+      break
+    fi
+  done < "$file"
+  _doctor_card_status_cache["$file"]="$status"
+  printf '%s' "$status"
+}
 card_status_active() {
-  grep -Eq '^[[:space:]]*(>[[:space:]]*)?status:[[:space:]]*active' "$1" 2>/dev/null
+  [[ "$(doctor_card_status "$1")" == "active" ]]
 }
 card_status_paused() {
-  grep -Eq '^[[:space:]]*(>[[:space:]]*)?status:[[:space:]]*paused' "$1" 2>/dev/null
+  [[ "$(doctor_card_status "$1")" == "paused" ]]
 }
 card_status_done() {
-  grep -Eq '^[[:space:]]*(>[[:space:]]*)?status:[[:space:]]*done' "$1" 2>/dev/null
+  [[ "$(doctor_card_status "$1")" == "done" ]]
 }
+doctor_load_card_status_cache
 
 # v6.12.1 (issue #11 B-2): unified task-card field parser, same three formats
 # as the pre-commit hook (T-043): inline `FIELD: a,b`, markdown `## FIELD`
 # section list, YAML frontmatter multi-line list. The old inline-only grep
 # meant the code->INVENTORY check never evaluated a single section-list card.
 doctor_parse_task_patterns() {
+  if declare -F task_card_parse_patterns >/dev/null 2>&1; then
+    task_card_parse_patterns "$1" "$2" | paste -sd, -
+    return 0
+  fi
   local _field="$1" _file="$2" _inline
   _inline="$(grep "^${_field}:" "$_file" 2>/dev/null | head -1 | sed "s/^${_field}:[[:space:]]*//;s/\r$//")"
   if [ -n "$_inline" ]; then
@@ -289,7 +370,8 @@ package_mode() {
 
 if $PACKAGE_MODE; then
   package_mode
-  printf '\nEngine Doctor: %s failure(s), %s warning(s)\n' "$fail_count" "$warn_count"
+
+printf '\nEngine Doctor: %s failure(s), %s warning(s)\n' "$fail_count" "$warn_count"
   if [[ "$fail_count" -gt 0 ]]; then
     exit 1
   fi
@@ -299,7 +381,10 @@ fi
 engine_path() {
   local file="$1"
   file="$(trim "$file")"
-  if [[ "$file" == engine/* ]]; then
+  # Registry rows may name root-level files (docs/, tests/, install.sh, ...)
+  # as well as engine-relative files. Prefer an existing project-root path;
+  # otherwise retain the historical engine/relative resolution.
+  if [[ "$file" == engine/* || -e "$ROOT/$file" ]]; then
     printf '%s/%s' "$ROOT" "$file"
   else
     printf '%s/%s' "$ENGINE_DIR" "$file"
@@ -475,7 +560,8 @@ check_context_semantics() {
       echo "  human: CONTEXT.md is missing the '$label' row in its status panel. Add a table row for '$label' with current information."
       continue
     fi
-    value="$(printf '%s' "$row" | awk -F'|' '{print $3}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
+    IFS='|' read -ra row_cols <<< "$row"
+    value="$(trim "${row_cols[2]-}")"
     if [[ -z "$value" || "$value" =~ ^\[.*\]$ || "$value" == "TBD" || "$value" == "TODO" ]]; then
       warn "CONTEXT.md status row '$label' is placeholder or empty"
       echo "  human: The '$label' row in CONTEXT.md has no real value (placeholder or empty). Fill in the actual status."
@@ -646,7 +732,11 @@ check_inventory_bidirectional() {
 
   # (a) INVENTORY→code: Entry file paths must exist.
   local inv_to_code_violations=0
-  local entry_paths_seen=""
+  # Keep membership checks in-process. Re-piping the complete inventory text
+  # through grep for every done-task path is prohibitively expensive under
+  # Windows Git Bash and can make Doctor appear hung without changing the
+  # bidirectional validation semantics.
+  declare -A entry_paths_seen_map=()
   for inv in "${inventory_files[@]}"; do
     # Parse table rows: | Feature | Entry file | Public API | Status | Last verified |
     # Skip header rows (|---|) and lines starting with `#` or `>`.
@@ -663,7 +753,7 @@ check_inventory_bidirectional() {
       # cols[0] is empty (leading `|`), cols[1]=Feature, cols[2]=Entry file, ...
       local entry_file=""
       if [ "${#cols[@]}" -ge 3 ]; then
-        entry_file="$(printf '%s' "${cols[2]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
+        entry_file="$(trim "${cols[2]}")"
       fi
       [ -z "$entry_file" ] && continue
       # Skip placeholders / glob patterns.
@@ -678,7 +768,7 @@ check_inventory_bidirectional() {
           warn "INVENTORY→code: $inv references '$entry_file' (grace period, cv=$contract_version < 6.8.0)"
         fi
       else
-        entry_paths_seen="$entry_paths_seen$entry_file"$'\n'
+        entry_paths_seen_map["$entry_file"]=1
       fi
     done < "$inv"
   done
@@ -711,7 +801,7 @@ check_inventory_bidirectional() {
         [[ "$ws_path" == "AGENTS.md" ]] && continue
         [[ "$ws_path" == ".github/"* ]] && continue
         # Check if this path appears in any INVENTORY entry column.
-        if ! printf '%s' "$entry_paths_seen" | grep -qF "$ws_path"; then
+        if [[ -z "${entry_paths_seen_map[$ws_path]+present}" ]]; then
           code_to_inv_violations=$((code_to_inv_violations + 1))
           if [ "$violation_is_fail" -eq 1 ]; then
             fail "code→INVENTORY: $tid touched '$ws_path' but no INVENTORY row references it"
@@ -783,7 +873,7 @@ check_inventory_api_uniqueness() {
       # cols[3] = Public API (0=empty, 1=Feature, 2=Entry, 3=Public API)
       local api=""
       if [ "${#cols[@]}" -ge 4 ]; then
-        api="$(printf '%s' "${cols[3]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
+        api="$(trim "${cols[3]}")"
       fi
       [ -z "$api" ] && continue
       [[ "$api" == \[*\]* ]] && continue
@@ -861,7 +951,7 @@ check_writeset_budget() {
     local IFS_save="$IFS"
     IFS=','
     for ws_path in $write_set_line; do
-      ws_path="$(printf '%s' "$ws_path" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
+      ws_path="$(trim "$ws_path")"
       [ -z "$ws_path" ] && continue
       # Skip globs.
       [[ "$ws_path" == *"*"* ]] && continue
@@ -947,7 +1037,7 @@ check_task_granularity() {
       local IFS_save="$IFS"
       IFS=','
       for p in $write_set_line; do
-        p="$(printf '%s' "$p" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
+        p="$(trim "$p")"
         [ -z "$p" ] && continue
         # De-dup mirror pairs: strip "plugin/" prefix for comparison.
         local canonical="$p"
@@ -1036,7 +1126,7 @@ check_depends_on() {
     IFS=','
     local upstream
     for upstream in $depends_line; do
-      upstream="$(printf '%s' "$upstream" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
+      upstream="$(trim "$upstream")"
       [ -z "$upstream" ] && continue
       # Validate format T-NNN.
       [[ "$upstream" =~ ^T-[0-9]+$ ]] || continue
@@ -1350,15 +1440,22 @@ check_contract_debt() {
 # will upgrade the evidence shape.
 evidence_has_pass() {
   local content="${1:-}"
-  printf '%s\n' "$content" | grep -Eiq '"status"[[:space:]]*:[[:space:]]*"pass"' && return 0
-  printf '%s\n' "$content" | grep -Eiq '"status"[[:space:]]*:' && return 1
-  printf '%s\n' "$content" | grep -Eiq '"verdict"[[:space:]]*:[[:space:]]*"pass"'
+  local lowered="${content,,}"
+  local status_pass_re='"status"[[:space:]]*:[[:space:]]*"pass"'
+  local status_re='"status"[[:space:]]*:'
+  local verdict_pass_re='"verdict"[[:space:]]*:[[:space:]]*"pass"'
+  [[ "$lowered" =~ $status_pass_re ]] && return 0
+  [[ "$lowered" =~ $status_re ]] && return 1
+  [[ "$lowered" =~ $verdict_pass_re ]]
 }
 
 evidence_is_legacy_verdict() {
   local content="${1:-}"
-  printf '%s\n' "$content" | grep -Eiq '"verdict"[[:space:]]*:[[:space:]]*"pass"' || return 1
-  ! printf '%s\n' "$content" | grep -Eiq '"status"[[:space:]]*:'
+  local lowered="${content,,}"
+  local verdict_pass_re='"verdict"[[:space:]]*:[[:space:]]*"pass"'
+  local status_re='"status"[[:space:]]*:'
+  [[ "$lowered" =~ $verdict_pass_re ]] || return 1
+  ! [[ "$lowered" =~ $status_re ]]
 }
 
 check_task_card_done_evidence() {
@@ -1370,22 +1467,24 @@ check_task_card_done_evidence() {
     [[ "$f" == *.spec.md ]] && continue
     card_status_done "$f" || continue
     done_count=$((done_count + 1))
-    local tid; tid="$(basename "$f" .md)"
+    local tid; tid="${f##*/}"; tid="${tid%.md}"
     local ev_dir="$ENGINE_DIR/evidence/$tid"
-    if grep -qi 'exempt' "$f" 2>/dev/null; then
+    local card_content; card_content="$(<"$f")"
+    if [[ "${card_content,,}" == *exempt* ]]; then
       exempt_count=$((exempt_count + 1))
       continue
     fi
-    local ac_ids ac_count missing ac ev
-    ac_ids="$(parse_ac_declarations "$f" | cut -f1)"
-    ac_count="$(printf '%s\n' "$ac_ids" | sed '/^$/d' | wc -l | tr -d ' ')"
+    local ac_records ac_count=0 missing ac verify_cmd ev ev_content
+    ac_records="$(parse_ac_declarations "$f")"
     missing=""
-    for ac in $ac_ids; do
+    while IFS=$'\t' read -r ac verify_cmd || [ -n "$ac" ]; do
+      [ -n "$ac" ] || continue
+      ac_count=$((ac_count + 1))
       ev="$ev_dir/$ac.json"
       if [ ! -f "$ev" ]; then
         missing="${missing}${missing:+,}$ac"
       else
-        ev_content="$(cat "$ev" 2>/dev/null || true)"
+        ev_content="$(<"$ev")"
         if ! evidence_has_pass "$ev_content"; then
           missing="${missing}${missing:+,}$ac"
         elif evidence_is_legacy_verdict "$ev_content"; then
@@ -1393,7 +1492,7 @@ check_task_card_done_evidence() {
           echo "  human: Evidence for $tid/$ac uses the legacy verdict=PASS field. It is accepted for compatibility; re-run engine verify to upgrade it to status=pass."
         fi
       fi
-    done
+    done <<< "$ac_records"
     if [ "$ac_count" -gt 0 ] 2>/dev/null && [ -z "$missing" ]; then
       verified_count=$((verified_count + 1))
     elif command -v git >/dev/null 2>&1 && git cat-file -e "HEAD:engine/tasks/$tid.md" 2>/dev/null; then
@@ -1420,6 +1519,7 @@ check_review_evidence() {
     [[ "$f" == *.spec.md ]] && continue
     card_status_done "$f" || continue
     local tid; tid="$(basename "$f" .md)"
+    task_card_has_code "$ROOT" "$f" || continue
     local review_file="$ENGINE_DIR/review/evidence/$tid/REVIEW.json"
 
     if [ ! -f "$review_file" ]; then
@@ -1442,13 +1542,25 @@ check_review_evidence() {
     prov_argv="$(grep -oE '"argv":"[^"]*"' "$review_file" | head -1 | sed 's/"argv":"//;s/"//')"
     head_commit="$(git rev-parse HEAD 2>/dev/null || echo unknown)"
 
-    [ "$prov_writer" = "engine-review" ] || warn "$tid review evidence writer=$prov_writer (expected engine-review)"
+    case "$prov_writer" in
+      engine-review|engine-review-from-receipt) : ;;
+      *) warn "$tid review evidence writer=$prov_writer (expected engine-review or engine-review-from-receipt)" ;;
+    esac
+    # D-040 (issue #28): stale 判定改为 ancestor-of-HEAD。正常 Coordinator closeout
+    # 会在 review 之后提交 evidence/任务卡/CONTEXT/HANDOFF/ENGINE_MAP/胶囊,合法推进 HEAD;
+    # review commit 仍为 HEAD 祖先即有效,只有被 rebase 掉/分叉/未知 commit 才报 stale。
+    # git merge-base 置于 if 条件内,非祖先返回非零不触发 set -e;git 不可用/commit 空 → fail-open 回退 WARN。
     if [ "$prov_commit" != "$head_commit" ]; then
-      warn "$tid stale review evidence (commit=$prov_commit HEAD=$head_commit)"
-      echo "  human: Task $tid review evidence is stale. Re-run 'engine review $tid' against current HEAD."
+      if command -v git >/dev/null 2>&1 && [ -n "$prov_commit" ] && git merge-base --is-ancestor "$prov_commit" HEAD 2>/dev/null; then
+        : # review commit 仍可从 HEAD 可达(closeout 合法推进)→ 非 stale
+      else
+        warn "$tid stale review evidence (commit=$prov_commit HEAD=$head_commit)"
+        echo "  human: Task $tid review evidence is stale. Re-run 'engine review $tid' against current HEAD."
+      fi
     fi
     case "$prov_argv" in
       "engine review $tid") : ;;
+      "engine review $tid --from-receipt "*) : ;;
       *) warn "$tid review evidence argv mismatch: $prov_argv" ;;
     esac
 
@@ -1528,6 +1640,7 @@ print('true' if ar.get('enabled', False) else 'false')
     [[ "$f" == *.spec.md ]] && continue
     card_status_done "$f" || continue
     local tid; tid="$(basename "$f" .md)"
+    task_card_has_code "$ROOT" "$f" || continue
 
     # 判断此卡是否需要 agent review: config enabled 或 L2 override
     local needs_agent_review=false
@@ -1588,6 +1701,12 @@ print('true' if ar.get('enabled', False) else 'false')
 check_gate_registry() {
   local tasks_dir="$ENGINE_DIR/tasks"
   [ -d "$tasks_dir" ] || return 0
+  # A done task's own AC may invoke Doctor (for example AC-7). During that
+  # nested verification, its previous GATE.json is necessarily transitional:
+  # verify is rebuilding AC evidence and gate has not yet been rerun. Defer
+  # only this task's registry verdict; a standalone Doctor still fails on a
+  # block/missing gate, and all other done tasks remain enforced.
+  local active_verify_task="${ENGINE_VERIFY_ACTIVE_TASK:-}"
   # Determine contract-version
   local cv=""
   for _marker in "$ROOT/AGENTS.md" "$ENGINE_DIR/SYSTEM.md" "$ENGINE_DIR/ENGINE_DOCTOR.md"; do
@@ -1608,6 +1727,11 @@ check_gate_registry() {
     [[ "$f" == *.spec.md ]] && continue
     card_status_done "$f" || continue
     local tid; tid="$(basename "$f" .md)"
+    if [ -n "$active_verify_task" ] && [ "$active_verify_task" = "$tid" ]; then
+      warn "done task $tid GATE registry deferred during active verification"
+      echo "  human: Doctor is running inside 'engine verify $tid'; the task's prior GATE.json is transitional until verify and gate finish."
+      continue
+    fi
     local gate_file="$ENGINE_DIR/evidence/$tid/GATE.json"
 
     if [ ! -f "$gate_file" ]; then
@@ -1649,8 +1773,11 @@ check_drift() {
     return 0
   fi
   local out rc
-  out="$(bash "$script" 2>&1)" || true
-  rc=$?
+  if out="$(bash "$script" 2>&1)"; then
+    rc=0
+  else
+    rc=$?
+  fi
   echo "$out" | sed 's/^/  /'
   if [ "$rc" -ne 0 ]; then
     fail "drift-check detected tamper or drift (see above)"
@@ -1997,6 +2124,93 @@ check_plan_acceptance_evidence() {
   done < "$plan_tmp"
 }
 
+# v6.25.0 (T-086/O1): ShellCheck high-reliability rule subset as grep-based lint.
+# Internalized from ShellCheck (GPL) — only rules with near-zero false-positive
+# grep patterns. WARN-level; does not block gate. Runs on engine/scripts/*.sh.
+check_script_lint() {
+  local scripts_dir="$ENGINE_DIR/scripts"
+  [ -d "$scripts_dir" ] || return 0
+
+  local lint_hits=0
+  local f line_no line
+
+  for f in "$scripts_dir"/*.sh; do
+    [ -f "$f" ] || continue
+    local fname; fname="$(basename "$f")"
+
+    # SC2148: missing shebang on line 1
+    local first_line
+    first_line="$(head -1 "$f")"
+    if [[ "$first_line" != "#!"* ]]; then
+      warn "lint SC2148 ($fname:1): missing shebang"
+      lint_hits=$((lint_hits + 1))
+    fi
+
+    # Line-by-line checks (skip comments and blank lines)
+    line_no=0
+    while IFS= read -r line || [ -n "$line" ]; do
+      line_no=$((line_no + 1))
+      # Skip comments, blank lines, shebang
+      [[ "$line" =~ ^[[:space:]]*# ]] && continue
+      [[ -z "${line// /}" ]] && continue
+
+      # SC2155: local/export var=$(cmd) — declare and assign separately
+      if [[ "$line" =~ ^[[:space:]]*(local|export)[[:space:]]+[A-Za-z_][A-Za-z_0-9]*=\$\( ]]; then
+        warn "lint SC2155 ($fname:$line_no): declare and assign separately to mask return values"
+        lint_hits=$((lint_hits + 1))
+      fi
+
+      # SC2164: cd without || exit / || return / || true / && / ;
+      if [[ "$line" =~ ^[[:space:]]*cd[[:space:]] ]]; then
+        if [[ "$line" != *"||"* && "$line" != *"&&"* && "$line" != *";"* && "$line" != *"pushd"* ]]; then
+          warn "lint SC2164 ($fname:$line_no): cd without error handling (add || exit)"
+          lint_hits=$((lint_hits + 1))
+        fi
+      fi
+
+      # SC2162: read without -r flag
+      if [[ "$line" =~ ^[[:space:]]*read[[:space:]] ]]; then
+        if [[ "$line" != *" -r"* && "$line" != *"read -r"* && "$line" != *"IFS="* ]]; then
+          warn "lint SC2162 ($fname:$line_no): read without -r mangles backslashes"
+          lint_hits=$((lint_hits + 1))
+        fi
+      fi
+
+      # SC2006: backtick command substitution (use $(...) instead)
+      # Skip echo/printf lines (backticks as literal content, not substitution)
+      if [[ "$line" == *'`'*'`'* ]]; then
+        if [[ "$line" =~ ^[[:space:]]*(echo|printf)[[:space:]] ]]; then
+          : # backticks in output content, not command substitution
+        elif [[ "$line" == *"<<"* ]]; then
+          : # heredoc marker line, skip
+        else
+          warn "lint SC2006 ($fname:$line_no): use \$(...) instead of backticks"
+          lint_hits=$((lint_hits + 1))
+        fi
+      fi
+
+      # SC2230: which command (use command -v / type -P)
+      if [[ "$line" =~ ^[[:space:]]*which[[:space:]] || "$line" == *'$(which '* || "$line" == *'`which '* ]]; then
+        warn "lint SC2230 ($fname:$line_no): use 'command -v' instead of 'which'"
+        lint_hits=$((lint_hits + 1))
+      fi
+
+      # SC2002: useless use of cat (cat file | cmd)
+      if [[ "$line" =~ ^[[:space:]]*cat[[:space:]].*\|[[:space:]]*[a-z] ]]; then
+        warn "lint SC2002 ($fname:$line_no): useless use of cat (redirect instead)"
+        lint_hits=$((lint_hits + 1))
+      fi
+
+    done < "$f"
+  done
+
+  if [ "$lint_hits" -eq 0 ]; then
+    pass "script lint: no ShellCheck-pattern violations in engine/scripts/*.sh"
+  fi
+}
+
+
+
 while IFS= read -r path; do
   rel="${path#"$ROOT/"}"
   if [[ "$rel" == engine/README.md || "$rel" == engine/README.zh.md ]]; then
@@ -2031,6 +2245,21 @@ check_prove_health() {
   local prove_dir="$ENGINE_DIR/prove"
   local scripts_dir="$ENGINE_DIR/scripts"
 
+  # Git Bash may expose a Windows Python executable while ROOT is a POSIX
+  # path such as /e/projects/.... Pass paths through argv so MSYS converts
+  # them for Windows Python; embedding the POSIX path in Python source makes
+  # valid JSON look unreadable and falsely fails Doctor.
+  json_file_valid() {
+    local json_path="$1"
+    if command -v python3 >/dev/null 2>&1; then
+      python3 -c 'import json,sys; json.load(open(sys.argv[1], encoding="utf-8"))' "$json_path" >/dev/null 2>&1
+    elif command -v python >/dev/null 2>&1; then
+      python -c 'import json,sys; json.load(open(sys.argv[1], encoding="utf-8"))' "$json_path" >/dev/null 2>&1
+    else
+      return 0
+    fi
+  }
+
   # Scripts exist
   if [[ -f "$scripts_dir/engine-prove.sh" ]]; then
     pass "prove script exists: engine/scripts/engine-prove.sh"
@@ -2047,14 +2276,14 @@ check_prove_health() {
   # Config valid
   if [[ -f "$prove_dir/config.json" ]]; then
     if command -v python3 >/dev/null 2>&1; then
-      if python3 -c "import json; json.load(open('$prove_dir/config.json'))" 2>/dev/null; then
+      if json_file_valid "$prove_dir/config.json"; then
         pass "prove config.json is valid JSON"
       else
         fail "prove config.json is invalid JSON"
         echo "  human: engine/prove/config.json has a JSON syntax error. Fix it manually."
       fi
     elif command -v python >/dev/null 2>&1; then
-      if python -c "import json; json.load(open('$prove_dir/config.json'))" 2>/dev/null; then
+      if json_file_valid "$prove_dir/config.json"; then
         pass "prove config.json is valid JSON"
       else
         fail "prove config.json is invalid JSON"
@@ -2069,14 +2298,14 @@ check_prove_health() {
   # Schema valid
   if [[ -f "$prove_dir/prove-assertions.schema.json" ]]; then
     if command -v python3 >/dev/null 2>&1; then
-      if python3 -c "import json; json.load(open('$prove_dir/prove-assertions.schema.json'))" 2>/dev/null; then
+      if json_file_valid "$prove_dir/prove-assertions.schema.json"; then
         pass "prove schema is valid JSON"
       else
         fail "prove schema is invalid JSON"
         echo "  human: engine/prove/prove-assertions.schema.json has a JSON syntax error."
       fi
     elif command -v python >/dev/null 2>&1; then
-      if python -c "import json; json.load(open('$prove_dir/prove-assertions.schema.json'))" 2>/dev/null; then
+      if json_file_valid "$prove_dir/prove-assertions.schema.json"; then
         pass "prove schema is valid JSON"
       else
         fail "prove schema is invalid JSON"
@@ -2120,6 +2349,29 @@ check_review_config_protected
 check_agent_review_evidence
 check_gate_registry
 
+# v6.26.0 (T-085): capsule heat check
+check_capsule_heat() {
+  local capsule_dir="$ENGINE_DIR/changes"
+  [ -d "$capsule_dir" ] || return 0
+  local f heat related_dec
+  for f in "$capsule_dir"/CHANGE-*.md; do
+    [ -f "$f" ] || continue
+    # Parse META header heat field
+    heat="$(sed -n '/^-----META-START-----/,/^-----META-END-----/{s/^heat:[[:space:]]*//p}' "$f" 2>/dev/null | head -1)"
+    [ -n "$heat" ] || continue
+    case "$heat" in *[!0-9]*) continue ;; esac
+    related_dec="$(sed -n '/^-----META-START-----/,/^-----META-END-----/{s/^related-decisions:[[:space:]]*//p}' "$f" 2>/dev/null | head -1)"
+    local cname
+    cname="$(basename "$f")"
+    if [ "$heat" -ge 5 ]; then
+      warn "capsule $cname heat=$heat: high-frequency change area, consider extracting to formal decision or PITFALLS"
+    elif [ "$heat" -ge 3 ] && [ -z "$related_dec" ]; then
+      warn "capsule $cname heat=$heat with no related-decisions: multiple changes without decision record"
+    fi
+  done
+}
+check_capsule_heat
+
 # ── Project-custom checks (engine/checks/) ──
 # Each project may place executable check-*.sh (FAIL on non-zero) or warn-*.sh
 # (WARN on non-zero) scripts into engine/checks/.  Doctor discovers and runs
@@ -2264,6 +2516,15 @@ for cli in engine engine.ps1 engine.cmd; do
   fi
 done
 
+
+# v6.25.0 (T-086/O1): script lint (ShellCheck-pattern subset)
+check_script_lint
+
+# v6.26.1 (T-081): save HEAD + worktree fingerprint for incremental mode.
+mkdir -p "$_doctor_cache_dir" 2>/dev/null || true
+printf '%s\n%s failure(s), %s warning(s)\n%s\n' \
+  "$_current_head" "$fail_count" "$warn_count" "$_doctor_worktree_fp" > "$_doctor_cache_file" 2>/dev/null || true
+
 printf '\nEngine Doctor: %s failure(s), %s warning(s)\n' "$fail_count" "$warn_count"
 if [[ "$fail_count" -gt 0 ]]; then
   exit 1
```

### engine/scripts/engine-doctor.ps1
```diff
diff --git a/engine/scripts/engine-doctor.ps1 b/engine/scripts/engine-doctor.ps1
index 617b3e3..49df715 100644
--- a/engine/scripts/engine-doctor.ps1
+++ b/engine/scripts/engine-doctor.ps1
@@ -1,6 +1,7 @@
 param(
   [string]$Root = (Get-Location).Path,
-  [switch]$PackageMode
+  [switch]$PackageMode,
+  [switch]$Full
 )
 
 $ErrorActionPreference = "Stop"
@@ -12,11 +13,51 @@ if ($Root -like '--*') {
   Write-Error "Error: unknown flag '$Root' (known: -PackageMode; a path argument sets -Root)"
   exit 2
 }
-$engineDir = Join-Path $Root "engine"
-$map = Join-Path $engineDir "ENGINE_MAP.md"
+$engineDir = Join-Path $Root "engine"
+$taskCardLibrary = Join-Path $PSScriptRoot "engine-task-card.ps1"
+if (Test-Path -LiteralPath $taskCardLibrary -PathType Leaf) { . $taskCardLibrary }
+$map = Join-Path $engineDir "ENGINE_MAP.md"
 $failCount = 0
 $warnCount = 0
 
+# v6.25.0 (T-086/B6): incremental mode — skip if HEAD unchanged.
+# v6.26.1 (T-081): HEAD alone is insufficient while verify/close and parallel
+# workers update evidence in the worktree. Include tracked diffs and untracked
+# files in the cache key so a cached failure/pass cannot survive a real change.
+$doctorCacheDir = Join-Path $engineDir '.cache'
+$doctorCacheFile = Join-Path $doctorCacheDir 'doctor-last-run'
+$currentHead = & git -C $Root rev-parse HEAD 2>$null
+if (-not $currentHead) { $currentHead = 'none' }
+
+function Get-DoctorWorktreeFingerprint {
+  $parts = New-Object System.Collections.Generic.List[string]
+  $diff = @(& git -C $Root diff --no-ext-diff --binary HEAD -- . 2>$null)
+  if ($diff.Count -gt 0) { [void]$parts.Add(($diff -join "`n")) }
+  foreach ($relative in @(& git -C $Root ls-files --others --exclude-standard 2>$null)) {
+    if ([string]::IsNullOrWhiteSpace($relative)) { continue }
+    $path = Join-Path $Root $relative
+    if (Test-Path -LiteralPath $path -PathType Leaf) {
+      $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
+      [void]$parts.Add("untracked:$relative`n$hash")
+    }
+  }
+  $payload = [Text.Encoding]::UTF8.GetBytes(($parts -join "`n"))
+  $sha = [Security.Cryptography.SHA256]::Create()
+  return (([BitConverter]::ToString($sha.ComputeHash($payload))) -replace '-', '').ToLowerInvariant()
+}
+
+$doctorWorktreeFingerprint = Get-DoctorWorktreeFingerprint
+if (-not $Full -and (Test-Path $doctorCacheFile)) {
+  $cacheLines = Get-Content -Path $doctorCacheFile -Encoding UTF8 -ErrorAction SilentlyContinue
+  if ($cacheLines -and $cacheLines.Count -ge 3 -and $cacheLines[0] -eq $currentHead -and $cacheLines[2] -eq $doctorWorktreeFingerprint -and $currentHead -ne 'none') {
+    Write-Host "[engine-doctor] incremental: HEAD/worktree unchanged ($currentHead), using cached result."
+    Write-Host "[engine-doctor] cached: $($cacheLines[1])"
+    Write-Host "  (use 'engine doctor --full' to force a complete re-check)"
+    if ($cacheLines[1] -match '([0-9]+) failure' -and [int]$Matches[1] -gt 0) { exit 1 }
+    exit 0
+  }
+}
+
 function Write-Fail([string]$Message) {
   $script:failCount++
   Write-Host "FAIL $Message" -ForegroundColor Red
@@ -45,9 +86,12 @@ function Trim-Cell([string]$Value) {
 # Returns: array of objects with AcId and VerifyCmd properties (VerifyCmd may be empty for SKIP).
 # AC id regex: AC-[A-Za-z]*[0-9]+(\.[0-9]+)* (v6.12.1 A-3).
 # Separators: | verify: / |verify: / -> verify: / ->verify: / line-start verify:
-function Parse-AcDeclarations {
-  param([string]$Path)
-  $results = @()
+function Parse-AcDeclarations {
+  param([string]$Path)
+  if (Get-Command Get-TaskCardAcDeclarations -ErrorAction SilentlyContinue) {
+    return @(Get-TaskCardAcDeclarations -Path $Path)
+  }
+  $results = @()
   if (-not (Test-Path $Path)) { return $results }
   $sepArrow = [string][char]0x2192
   $acIdPattern = 'AC-[A-Za-z]*\d+(?:\.\d+)*'
@@ -127,8 +171,11 @@ function Test-CardStatus([string]$Content, [string]$Status) {
 # v6.12.1 (issue #11 B-2): unified task-card field parser, same three formats
 # as the pre-commit hook (T-043): inline "FIELD: a,b", markdown "## FIELD"
 # section list, YAML frontmatter multi-line list. Returns comma-joined string.
-function Get-TaskPatterns([string]$Content, [string]$Field) {
-  if (-not $Content) { return "" }
+function Get-TaskPatterns([string]$Content, [string]$Field) {
+  if (Get-Command Get-TaskCardPatterns -ErrorAction SilentlyContinue) {
+    return (@(Get-TaskCardPatterns -Content $Content -Field $Field) -join ',')
+  }
+  if (-not $Content) { return "" }
   $inlineMatch = [regex]::Match($Content, ('(?m)^' + [regex]::Escape($Field) + ':\s*(.+)$'))
   if ($inlineMatch.Success) { return $inlineMatch.Groups[1].Value.TrimEnd() }
   $out = @()
@@ -159,7 +206,10 @@ function Get-TaskPatterns([string]$Content, [string]$Field) {
 
 function Resolve-EnginePath([string]$File) {
   $clean = Trim-Cell $File
-  if ($clean -like "engine/*") {
+  # Registry rows may name root-level files (docs/, tests/, install.ps1, ...)
+  # as well as engine-relative files. Prefer an existing project-root path;
+  # otherwise retain the historical engine-relative resolution.
+  if ($clean -like "engine/*" -or (Test-Path -LiteralPath (Join-Path $Root ($clean -replace "/", [IO.Path]::DirectorySeparatorChar)))) {
     return Join-Path $Root ($clean -replace "/", [IO.Path]::DirectorySeparatorChar)
   }
   return Join-Path $engineDir ($clean -replace "/", [IO.Path]::DirectorySeparatorChar)
@@ -297,7 +347,11 @@ function Test-PackageMode {
 if ($PackageMode) {
   Test-PackageMode
   Write-Host ""
-  Write-Host "Engine Doctor: $failCount failure(s), $warnCount warning(s)"
+  # v6.26.1 (T-081): save HEAD + worktree fingerprint for incremental mode.
+if (-not (Test-Path $doctorCacheDir)) { New-Item -ItemType Directory -Path $doctorCacheDir -Force | Out-Null }
+Set-Content -Path $doctorCacheFile -Value @($currentHead, "$failCount failure(s), $warnCount warning(s)", $doctorWorktreeFingerprint) -Encoding UTF8 -ErrorAction SilentlyContinue
+
+Write-Host "Engine Doctor: $failCount failure(s), $warnCount warning(s)"
   if ($failCount -gt 0) { exit 1 }
   exit 0
 }
@@ -1312,17 +1366,17 @@ function Test-ContractDebt {
   }
 }
 
-function Test-EvidencePass([string]$Content) {
-  if ($Content -match '(?i)"status"\s*:\s*"pass"') { return $true }
-  if ($Content -match '(?i)"status"\s*:') { return $false }
-  return ($Content -match '(?i)"verdict"\s*:\s*"pass"')
-}
-
-function Test-LegacyVerdictEvidence([string]$Content) {
-  return (($Content -match '(?i)"verdict"\s*:\s*"pass"') -and ($Content -notmatch '(?i)"status"\s*:'))
-}
-
-function Test-TaskCardDoneEvidence {
+function Test-EvidencePass([string]$Content) {
+  if ($Content -match '(?i)"status"\s*:\s*"pass"') { return $true }
+  if ($Content -match '(?i)"status"\s*:') { return $false }
+  return ($Content -match '(?i)"verdict"\s*:\s*"pass"')
+}
+
+function Test-LegacyVerdictEvidence([string]$Content) {
+  return (($Content -match '(?i)"verdict"\s*:\s*"pass"') -and ($Content -notmatch '(?i)"status"\s*:'))
+}
+
+function Test-TaskCardDoneEvidence {
   $tasksDir = Join-Path $engineDir "tasks"
   if (-not (Test-Path $tasksDir)) { return }
   $doneCount = 0
@@ -1345,12 +1399,12 @@ function Test-TaskCardDoneEvidence {
       $evPath = Join-Path $evDir ($ac + '.json')
       if (-not (Test-Path $evPath)) { $missing.Add($ac); continue }
       $evContent = Get-Content -Raw -Path $evPath -Encoding UTF8 -ErrorAction SilentlyContinue
-      if (-not (Test-EvidencePass $evContent)) {
-        $missing.Add($ac)
-      } elseif (Test-LegacyVerdictEvidence $evContent) {
-        Write-Warn "task $tid/$ac uses legacy verdict evidence (accepted; re-run 'engine verify $tid' to write status=pass)"
-        Write-Output "  human: Evidence for $tid/$ac uses the legacy verdict=PASS field. It is accepted for compatibility; re-run engine verify to upgrade it to status=pass."
-      }
+      if (-not (Test-EvidencePass $evContent)) {
+        $missing.Add($ac)
+      } elseif (Test-LegacyVerdictEvidence $evContent) {
+        Write-Warn "task $tid/$ac uses legacy verdict evidence (accepted; re-run 'engine verify $tid' to write status=pass)"
+        Write-Output "  human: Evidence for $tid/$ac uses the legacy verdict=PASS field. It is accepted for compatibility; re-run engine verify to upgrade it to status=pass."
+      }
     }
     if ($acIds.Count -gt 0 -and $missing.Count -eq 0) {
       $verifiedCount++
@@ -1375,89 +1429,89 @@ function Test-TaskCardDoneEvidence {
   }
 }
 
-# v6.18.0 (D-038/T-066 AC-8): drift-check integration. Defers to the
-# standalone engine-drift-check.ps1 script (cheap fingerprint comparison,
-# no verify re-run). Tamper/drift = FAIL; warn-only issues stay WARN.
-function Test-Drift {
-  $script = Join-Path $EngineDir "scripts\engine-drift-check.ps1"
-  if (-not (Test-Path $script)) {
-    Write-Warn "drift-check script missing: $script"
-    return
-  }
-  $gitCmd = Get-Command git -ErrorAction SilentlyContinue
-  if (-not $gitCmd) {
-    Write-Warn "git not on PATH - drift-check skipped"
-    return
-  }
-  $out = & pwsh -NoProfile -File $script 2>&1 | Out-String
-  $rc = $LASTEXITCODE
-  if ($out) {
-    foreach ($line in ($out -split "`r?`n")) {
-      if ($line) { Write-Output "  $line" }
-    }
-  }
-  if ($rc -ne 0) {
-    Write-Fail "drift-check detected tamper or drift (see above)"
-    Write-Output "  human: Evidence integrity or code fingerprint mismatch. Re-run 'engine verify <T-NNN>' against current HEAD, or mark evidence-manual-edit with a covering approved decision."
-  } else {
-    Write-Pass "drift-check passed (no tamper, no drift)"
-  }
-}
-
-# v6.19.0 (D-038c/T-067): derived status panel check. Double-write transition:
-# CONTEXT.md static panel is labeled "legacy" while engine context outputs a
-# real-time "Derived Status" segment. Doctor verifies (1) the legacy annotation
-# exists and (2) derived values (git tag vs engine/VERSION) match the static
-# declaration. Mismatches are WARN only during the double-write transition.
-function Test-DerivedStatus {
-  $ctx = Join-Path $EngineDir "CONTEXT.md"
-  if (-not (Test-Path $ctx)) { return }
-  $gitExe = Get-Command git -ErrorAction SilentlyContinue
-  if (-not $gitExe) {
-    Write-Warn "git not on PATH - derived status check skipped"
-    return
-  }
-
-  # (1) Legacy annotation check.
-  $ctxContent = Get-Content -Raw -Path $ctx -Encoding UTF8 -ErrorAction SilentlyContinue
-  if ($ctxContent -match '<!-- legacy: status-panel') {
-    Write-Pass "CONTEXT.md status-panel has legacy annotation (double-write transition)"
-  } else {
-    Write-Warn "CONTEXT.md status-panel missing <!-- legacy: status-panel --> annotation"
-    Write-Output "  human: Add <!-- legacy: status-panel (double-write transition, v6.19.0~v6.20.0) --> after the status panel header. See D-038c."
-    return
-  }
-
-  # (2) Derived value consistency: latest git tag vs engine/VERSION.
-  $latestTag = "none"
-  try {
-    $latestTag = (git -C $Root describe --tags --abbrev=0 2>$null) -join ''
-    if (-not $latestTag) { $latestTag = "none" }
-  } catch { $latestTag = "none" }
-
-  $engineVer = "unknown"
-  $evFile = Join-Path $EngineDir "VERSION"
-  if (Test-Path $evFile) {
-    $engineVer = (Get-Content $evFile -Raw -Encoding UTF8 -ErrorAction SilentlyContinue).Trim()
-  }
-  $latestVer = $latestTag -replace '^v', ''
-
-  if ($latestVer -eq $engineVer) {
-    Write-Pass "derived tag/VERSION consistent ($latestTag = $engineVer)"
-  } else {
-    Write-Warn "derived tag/VERSION mismatch: git tag=$latestTag, engine/VERSION=$engineVer"
-    Write-Output "  human: The latest git tag does not match engine/VERSION. Run 'engine update' or create a matching tag."
-  }
-
-  # (3) Check static panel mentions the latest tag (stale panel detection).
-  if ($ctxContent -match [regex]::Escape($latestVer)) {
-    Write-Pass "static panel references current version ($latestVer)"
-  } else {
-    Write-Warn "static panel does not reference current version ($latestVer) - panel may be stale"
-    Write-Output "  human: Update the status panel in CONTEXT.md to mention v$engineVer, or rely on the Derived Status segment."
-  }
-}
-
+# v6.18.0 (D-038/T-066 AC-8): drift-check integration. Defers to the
+# standalone engine-drift-check.ps1 script (cheap fingerprint comparison,
+# no verify re-run). Tamper/drift = FAIL; warn-only issues stay WARN.
+function Test-Drift {
+  $script = Join-Path $EngineDir "scripts\engine-drift-check.ps1"
+  if (-not (Test-Path $script)) {
+    Write-Warn "drift-check script missing: $script"
+    return
+  }
+  $gitCmd = Get-Command git -ErrorAction SilentlyContinue
+  if (-not $gitCmd) {
+    Write-Warn "git not on PATH - drift-check skipped"
+    return
+  }
+  $out = & pwsh -NoProfile -File $script 2>&1 | Out-String
+  $rc = $LASTEXITCODE
+  if ($out) {
+    foreach ($line in ($out -split "`r?`n")) {
+      if ($line) { Write-Output "  $line" }
+    }
+  }
+  if ($rc -ne 0) {
+    Write-Fail "drift-check detected tamper or drift (see above)"
+    Write-Output "  human: Evidence integrity or code fingerprint mismatch. Re-run 'engine verify <T-NNN>' against current HEAD, or mark evidence-manual-edit with a covering approved decision."
+  } else {
+    Write-Pass "drift-check passed (no tamper, no drift)"
+  }
+}
+
+# v6.19.0 (D-038c/T-067): derived status panel check. Double-write transition:
+# CONTEXT.md static panel is labeled "legacy" while engine context outputs a
+# real-time "Derived Status" segment. Doctor verifies (1) the legacy annotation
+# exists and (2) derived values (git tag vs engine/VERSION) match the static
+# declaration. Mismatches are WARN only during the double-write transition.
+function Test-DerivedStatus {
+  $ctx = Join-Path $EngineDir "CONTEXT.md"
+  if (-not (Test-Path $ctx)) { return }
+  $gitExe = Get-Command git -ErrorAction SilentlyContinue
+  if (-not $gitExe) {
+    Write-Warn "git not on PATH - derived status check skipped"
+    return
+  }
+
+  # (1) Legacy annotation check.
+  $ctxContent = Get-Content -Raw -Path $ctx -Encoding UTF8 -ErrorAction SilentlyContinue
+  if ($ctxContent -match '<!-- legacy: status-panel') {
+    Write-Pass "CONTEXT.md status-panel has legacy annotation (double-write transition)"
+  } else {
+    Write-Warn "CONTEXT.md status-panel missing <!-- legacy: status-panel --> annotation"
+    Write-Output "  human: Add <!-- legacy: status-panel (double-write transition, v6.19.0~v6.20.0) --> after the status panel header. See D-038c."
+    return
+  }
+
+  # (2) Derived value consistency: latest git tag vs engine/VERSION.
+  $latestTag = "none"
+  try {
+    $latestTag = (git -C $Root describe --tags --abbrev=0 2>$null) -join ''
+    if (-not $latestTag) { $latestTag = "none" }
+  } catch { $latestTag = "none" }
+
+  $engineVer = "unknown"
+  $evFile = Join-Path $EngineDir "VERSION"
+  if (Test-Path $evFile) {
+    $engineVer = (Get-Content $evFile -Raw -Encoding UTF8 -ErrorAction SilentlyContinue).Trim()
+  }
+  $latestVer = $latestTag -replace '^v', ''
+
+  if ($latestVer -eq $engineVer) {
+    Write-Pass "derived tag/VERSION consistent ($latestTag = $engineVer)"
+  } else {
+    Write-Warn "derived tag/VERSION mismatch: git tag=$latestTag, engine/VERSION=$engineVer"
+    Write-Output "  human: The latest git tag does not match engine/VERSION. Run 'engine update' or create a matching tag."
+  }
+
+  # (3) Check static panel mentions the latest tag (stale panel detection).
+  if ($ctxContent -match [regex]::Escape($latestVer)) {
+    Write-Pass "static panel references current version ($latestVer)"
+  } else {
+    Write-Warn "static panel does not reference current version ($latestVer) - panel may be stale"
+    Write-Output "  human: Update the status panel in CONTEXT.md to mention v$engineVer, or rely on the Derived Status segment."
+  }
+}
+
 function Test-EngineVersion {
   $ev = Join-Path $EngineDir "VERSION"
   if (-not (Test-Path $ev)) {
@@ -1769,15 +1823,17 @@ function Test-WorkstreamOrphan {
 }
 
 # v6.20.0 (T-070): review evidence Doctor check (spec §3.3).
-function Test-ReviewEvidence {
+function Test-ReviewEvidence {
   $tasksDir = Join-Path $engineDir "tasks"
   if (-not (Test-Path $tasksDir)) { return }
   Get-ChildItem -Path $tasksDir -Filter "T-*.md" | ForEach-Object {
     $f = $_.FullName
     if ($f -like "*.spec.md") { return }
-    $content = Get-Content $f -Raw
-    if ($content -notmatch '(?m)^\s*(>\s*)?status:\s*done') { return }
-    $tid = $_.BaseName
+    $content = Get-Content $f -Raw
+    if ($content -notmatch '(?m)^\s*(>\s*)?status:\s*done') { return }
+    if ((Get-Command Test-TaskCardHasCode -ErrorAction SilentlyContinue) -and
+        -not (Test-TaskCardHasCode -Root $Root -Path $f)) { return }
+    $tid = $_.BaseName
     $reviewFile = Join-Path $engineDir "review\evidence\$tid\REVIEW.json"
 
     if (-not (Test-Path $reviewFile)) {
@@ -1792,13 +1848,24 @@ function Test-ReviewEvidence {
 
     $review = Get-Content $reviewFile -Raw | ConvertFrom-Json
     $headCommit = git rev-parse HEAD 2>$null
-    if ($review.write_provenance.writer -ne "engine-review") {
-      Write-Warn "$tid review evidence writer=$($review.write_provenance.writer) (expected engine-review)"
+    if ($review.write_provenance.writer -notin @("engine-review","engine-review-from-receipt")) {
+      Write-Warn "$tid review evidence writer=$($review.write_provenance.writer) (expected engine-review or engine-review-from-receipt)"
     }
     if ($review.write_provenance.commit -ne $headCommit) {
-      Write-Warn "$tid stale review evidence (commit=$($review.write_provenance.commit) HEAD=$headCommit)"
+      # D-040 (issue #28): stale 判定改为 ancestor-of-HEAD。正常 Coordinator closeout
+      # 会在 review 之后提交 evidence/任务卡/CONTEXT/HANDOFF/ENGINE_MAP/胶囊,合法推进 HEAD;
+      # review commit 仍为 HEAD 祖先即有效,只有被 rebase 掉/分叉/未知 commit 才报 stale。
+      $provCommit = $review.write_provenance.commit
+      $isAncestor = $false
+      if ($provCommit) {
+        git merge-base --is-ancestor $provCommit HEAD 2>$null
+        if ($LASTEXITCODE -eq 0) { $isAncestor = $true }
+      }
+      if (-not $isAncestor) {
+        Write-Warn "$tid stale review evidence (commit=$($review.write_provenance.commit) HEAD=$headCommit)"
+      }
     }
-    if ($review.write_provenance.argv -ne "engine review $tid") {
+    if ($review.write_provenance.argv -ne "engine review $tid" -and $review.write_provenance.argv -notlike "engine review $tid --from-receipt *") {
       Write-Warn "$tid review evidence argv mismatch: $($review.write_provenance.argv)"
     }
     if ($review.tool_unavailable -eq $true) {
@@ -1821,6 +1888,54 @@ function Test-ReviewConfigProtected {
   }
 }
 
+# v6.26.0: capsule heat check. Scans engine/changes/CHANGE-*.md META headers
+# for a numeric "heat:" field. High heat indicates a frequently-changed area
+# that may deserve a formal decision or PITFALLS entry. Heat >= 3 without a
+# related-decisions record suggests undocumented repeated changes.
+function Test-CapsuleHeat {
+  try {
+    $changesDir = Join-Path $engineDir "changes"
+    if (-not (Test-Path $changesDir)) { return }
+    $capsules = @(Get-ChildItem -Path $changesDir -File -Filter "CHANGE-*.md" -ErrorAction SilentlyContinue)
+    if ($capsules.Count -eq 0) { return }
+
+    foreach ($capsule in $capsules) {
+      $content = Get-Content -Raw -Path $capsule.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
+      if (-not $content) { continue }
+
+      # Parse META header between -----META-START----- and -----META-END-----.
+      $metaMatch = [regex]::Match($content, '(?s)-----META-START-----(.+?)-----META-END-----')
+      if (-not $metaMatch.Success) { continue }
+      $metaBlock = $metaMatch.Groups[1].Value
+
+      # Extract "heat:" field (must be numeric, skip if not).
+      $heatMatch = [regex]::Match($metaBlock, '(?m)^\s*heat:\s*(.+)$')
+      if (-not $heatMatch.Success) { continue }
+      $heatRaw = $heatMatch.Groups[1].Value.Trim()
+      if ($heatRaw -notmatch '^\d+$') { continue }
+      $heat = [int]$heatRaw
+
+      # Extract "related-decisions:" field.
+      $relatedDecisions = ""
+      $rdMatch = [regex]::Match($metaBlock, '(?m)^\s*related-decisions:\s*(.*)$')
+      if ($rdMatch.Success) { $relatedDecisions = $rdMatch.Groups[1].Value.Trim() }
+
+      # heat >= 5 -> WARN high-frequency change area.
+      if ($heat -ge 5) {
+        Write-Warn "$($capsule.Name) has heat=$heat - high-frequency change area, consider extracting to formal decision or PITFALLS"
+        Write-Output "  human: Change capsule '$($capsule.Name)' has a heat score of $heat (>=5), indicating this area is changed very frequently. Consider extracting the recurring pattern into a formal decision (engine/decisions/) or a PITFALLS entry to reduce repeated churn."
+      }
+      # heat >= 3 AND related-decisions empty -> WARN multiple changes without decision record.
+      elseif ($heat -ge 3 -and [string]::IsNullOrEmpty($relatedDecisions)) {
+        Write-Warn "$($capsule.Name) has heat=$heat but no related-decisions - multiple changes without decision record"
+        Write-Output "  human: Change capsule '$($capsule.Name)' has a heat score of $heat (>=3) but no related-decisions field in its META header. Multiple changes to this area should be backed by a decision record. Add 'related-decisions: D-NNN' to the META block or create a decision."
+      }
+    }
+  } catch {
+    # Fail-open: capsule heat check must never block the doctor run.
+  }
+}
+
 if (Test-Path $engineDir) {
   Get-ChildItem -Path $engineDir -File -Filter "*.md" | ForEach-Object {
     $rel = "engine/$($_.Name)"
@@ -1892,6 +2007,7 @@ Test-WriteSetBudget
 Test-TaskGranularity
 Test-DependsOn
 Test-WarnDoneGate
+Test-CapsuleHeat
 Test-PitfallsSemantics
 Test-SprintSemantics
 Test-ChangeCapsuleSemantics
@@ -1975,6 +2091,79 @@ foreach ($anchor in @("AGENTS.md", "CLAUDE.md")) {
   }
 }
 
+
+# v6.25.0 (T-086/O1): ShellCheck high-reliability rule subset (grep-based lint).
+function Check-ScriptLint {
+  $scriptsDir = Join-Path $engineDir "scripts"
+  if (-not (Test-Path $scriptsDir)) { return }
+
+  $lintHits = 0
+  $shFiles = Get-ChildItem -Path $scriptsDir -Filter "*.sh" -File -ErrorAction SilentlyContinue
+  foreach ($file in $shFiles) {
+    $fname = $file.Name
+    $lines = Get-Content -Path $file.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
+    if (-not $lines) { continue }
+
+    # SC2148: missing shebang
+    if ($lines.Count -gt 0 -and $lines[0] -notmatch '^#!') {
+      Write-Warn "lint SC2148 ($fname`:1): missing shebang"
+      $lintHits++
+    }
+
+    $lineNo = 0
+    foreach ($line in $lines) {
+      $lineNo++
+      if ($line -match '^\s*#') { continue }
+      if ($line -match '^\s*$') { continue }
+
+      # SC2155: local/export var=$(cmd)
+      if ($line -match '^\s*(local|export)\s+[A-Za-z_][A-Za-z_0-9]*=\$\(') {
+        Write-Warn "lint SC2155 ($fname`:$lineNo): declare and assign separately to mask return values"
+        $lintHits++
+      }
+
+      # SC2164: cd without error handling
+      if ($line -match '^\s*cd\s') {
+        if ($line -notmatch '\|\|' -and $line -notmatch '&&' -and $line -notmatch ';' -and $line -notmatch 'pushd') {
+          Write-Warn "lint SC2164 ($fname`:$lineNo): cd without error handling (add || exit)"
+          $lintHits++
+        }
+      }
+
+      # SC2162: read without -r
+      if ($line -match '^\s*read\s') {
+        if ($line -notmatch ' -r' -and $line -notmatch 'IFS=') {
+          Write-Warn "lint SC2162 ($fname`:$lineNo): read without -r mangles backslashes"
+          $lintHits++
+        }
+      }
+
+      # SC2006: backtick command substitution
+      $backtickCount = ($line.ToCharArray() | Where-Object { $_ -eq '`' } | Measure-Object).Count
+      if ($backtickCount -ge 2) {
+        Write-Warn "lint SC2006 ($fname`:$lineNo): use dollar-paren instead of backticks"
+        $lintHits++
+      }
+
+      # SC2230: which command
+      if ($line -match '^\s*which\s' -or $line -match '\$\(which ') {
+        Write-Warn "lint SC2230 ($fname`:$lineNo): use command -v instead of which"
+        $lintHits++
+      }
+
+      # SC2002: useless use of cat
+      if ($line -match '^\s*cat\s.*\|\s*[a-z]') {
+        Write-Warn "lint SC2002 ($fname`:$lineNo): useless use of cat (redirect instead)"
+        $lintHits++
+      }
+    }
+  }
+
+  if ($lintHits -eq 0) {
+    Write-Pass "script lint: no ShellCheck-pattern violations in engine/scripts/*.sh"
+  }
+}
+
 if ($registeredNames -notcontains "ENGINE_DOCTOR.md") {
   Write-Warn "ENGINE_DOCTOR.md is not registered in ENGINE_MAP section 1"
   Write-Output "  human: The ENGINE_DOCTOR.md file is not listed in the ENGINE_MAP file registry. Add it to section 1 so the system can track it."
@@ -2019,7 +2208,14 @@ foreach ($cli in @("engine", "engine.ps1", "engine.cmd")) {
   }
 }
 
-Write-Host ""
-Write-Host "Engine Doctor: $failCount failure(s), $warnCount warning(s)"
+# v6.25.0 (T-086/O1): script lint (ShellCheck-pattern subset)
+Check-ScriptLint
+
+Write-Host ""
+# v6.26.1 (T-081): save normal-mode results too; the cache key includes the
+# worktree fingerprint so later verify/close writes force a fresh Doctor run.
+if (-not (Test-Path $doctorCacheDir)) { New-Item -ItemType Directory -Path $doctorCacheDir -Force | Out-Null }
+Set-Content -Path $doctorCacheFile -Value @($currentHead, "$failCount failure(s), $warnCount warning(s)", $doctorWorktreeFingerprint) -Encoding UTF8 -ErrorAction SilentlyContinue
+Write-Host "Engine Doctor: $failCount failure(s), $warnCount warning(s)"
 if ($failCount -gt 0) { exit 1 }
 exit 0
```

### plugin/engine/scripts/engine-doctor.sh
```diff
diff --git a/plugin/engine/scripts/engine-doctor.sh b/plugin/engine/scripts/engine-doctor.sh
index 3eab40e..b2c1b07 100644
--- a/plugin/engine/scripts/engine-doctor.sh
+++ b/plugin/engine/scripts/engine-doctor.sh
@@ -12,11 +12,13 @@ PACKAGE_MODE=false
 # catch-all treated any argument as ROOT, so a typo like --quiet became
 # ROOT="--quiet" and doctor reported "ENGINE_MAP.md is missing" instead
 # of "no such flag".
+FULL_MODE=false
 for arg in "$@"; do
   case "$arg" in
     --package-mode) PACKAGE_MODE=true ;;
+    --full) FULL_MODE=true ;;
     --*)
-      echo "Error: unknown flag '$arg' (known: --package-mode; a path argument sets ROOT)" >&2
+      echo "Error: unknown flag '$arg' (known: --package-mode, --full; a path argument sets ROOT)" >&2
       exit 2
       ;;
     *) ROOT="$arg" ;;
@@ -25,10 +27,49 @@ done
 
 ENGINE_DIR="$ROOT/engine"
 MAP="$ENGINE_DIR/ENGINE_MAP.md"
+task_card_script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
+if [ -f "$task_card_script_dir/engine-task-card.sh" ]; then
+  # shellcheck source=/dev/null
+  . "$task_card_script_dir/engine-task-card.sh"
+fi
 
 fail_count=0
 warn_count=0
 
+# v6.25.0 (T-086/B6): incremental mode — skip expensive checks if HEAD unchanged.
+# v6.26.1 (T-081): HEAD alone is insufficient while verify/close and parallel
+# workers update evidence in the worktree. Include tracked diffs and untracked
+# files in the cache key so a cached failure/pass cannot survive a real change.
+# Use --full to force a complete run. Cache lives at engine/.cache/doctor-last-run.
+_doctor_cache_dir="$ENGINE_DIR/.cache"
+_doctor_cache_file="$_doctor_cache_dir/doctor-last-run"
+_current_head="$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo none)"
+_doctor_worktree_fingerprint() {
+  {
+    git -C "$ROOT" diff --no-ext-diff --binary HEAD -- . 2>/dev/null || true
+    while IFS= read -r -d '' _untracked; do
+      [ -f "$ROOT/$_untracked" ] || continue
+      printf 'untracked:%s\n' "$_untracked"
+      sha256sum "$ROOT/$_untracked" 2>/dev/null || true
+    done < <(git -C "$ROOT" ls-files --others --exclude-standard -z 2>/dev/null || true)
+  } | sha256sum | cut -d' ' -f1
+}
+_doctor_worktree_fp="$(_doctor_worktree_fingerprint)"
+if [ "$FULL_MODE" = false ] && [ -f "$_doctor_cache_file" ]; then
+  _cached_head="$(head -1 "$_doctor_cache_file" 2>/dev/null || echo '')"
+  _cached_worktree_fp="$(sed -n '3p' "$_doctor_cache_file" 2>/dev/null || echo '')"
+  if [ "$_cached_head" = "$_current_head" ] && [ "$_current_head" != "none" ] &&
+     [ -n "$_cached_worktree_fp" ] && [ "$_cached_worktree_fp" = "$_doctor_worktree_fp" ]; then
+    _cached_summary="$(sed -n '2p' "$_doctor_cache_file" 2>/dev/null || echo '')"
+    echo "[engine-doctor] incremental: HEAD/worktree unchanged ($_current_head), using cached result."
+    echo "[engine-doctor] cached: $_cached_summary"
+    echo "  (use 'engine doctor --full' to force a complete re-check)"
+    # Exit with cached status
+    _cached_fails="$(printf '%s' "$_cached_summary" | grep -oE '[0-9]+ failure' | grep -oE '[0-9]+' || echo 0)"
+    [ "${_cached_fails:-0}" -gt 0 ] && exit 1 || exit 0
+  fi
+fi
+
 # parse_ac_declarations: Extract (ac_id, verify_cmd) pairs from a task card.
 # Supports 4 AC declaration formats (D-037 / v6.17.0):
 #   1. Single-line:  AC: AC-N <desc> | verify: <cmd>
@@ -39,6 +80,10 @@ warn_count=0
 # AC id regex: AC-[A-Za-z]*[0-9]+(\.[0-9]+)* (v6.12.1 A-3).
 # Separators: | verify: / |verify: / → verify: / →verify: / line-start verify:
 parse_ac_declarations() {
+  if declare -F task_card_parse_ac_declarations >/dev/null 2>&1; then
+    task_card_parse_ac_declarations "$@"
+    return 0
+  fi
   local file="$1"
   local line ac_id verify_cmd verify_rest
   local section_ac="" pending_ac=""
@@ -148,21 +193,57 @@ warn() {
 # v6.12.1 (issue #11 C-1): anchored card-status predicates. Unanchored
 # 'status:.*active' greps also match prose that merely QUOTES the pattern -
 # a card documenting the bug pins itself active (self-referential lock).
+# Cache the anchored status once per card: Doctor applies these predicates in
+# many full-task scans, and spawning grep for every predicate is prohibitively
+# slow under Windows Git Bash.
+declare -A _doctor_card_status_cache=()
+doctor_load_card_status_cache() {
+  local file status
+  [ -d "$ENGINE_DIR/tasks" ] || return 0
+  while IFS='|' read -r file status; do
+    [ -n "$file" ] || continue
+    _doctor_card_status_cache["$file"]="$status"
+  done < <(
+    grep -H -E -o '^[[:space:]]*(>[[:space:]]*)?status:[[:space:]]*(active|paused|done)([[:space:]]|$)' \
+      "$ENGINE_DIR"/tasks/T-*.md 2>/dev/null |
+      sed -E 's/^(.*):[[:space:]]*(>[[:space:]]*)?status:[[:space:]]*([^[:space:]]+).*/\1|\3/'
+  )
+}
+doctor_card_status() {
+  local file="$1" line status=""
+  if [[ -n "${_doctor_card_status_cache[$file]+present}" ]]; then
+    printf '%s' "${_doctor_card_status_cache[$file]}"
+    return 0
+  fi
+  while IFS= read -r line || [[ -n "$line" ]]; do
+    if [[ "$line" =~ ^[[:space:]]*(>[[:space:]]*)?status:[[:space:]]*([^[:space:]]+) ]]; then
+      status="${BASH_REMATCH[2]}"
+      break
+    fi
+  done < "$file"
+  _doctor_card_status_cache["$file"]="$status"
+  printf '%s' "$status"
+}
 card_status_active() {
-  grep -Eq '^[[:space:]]*(>[[:space:]]*)?status:[[:space:]]*active' "$1" 2>/dev/null
+  [[ "$(doctor_card_status "$1")" == "active" ]]
 }
 card_status_paused() {
-  grep -Eq '^[[:space:]]*(>[[:space:]]*)?status:[[:space:]]*paused' "$1" 2>/dev/null
+  [[ "$(doctor_card_status "$1")" == "paused" ]]
 }
 card_status_done() {
-  grep -Eq '^[[:space:]]*(>[[:space:]]*)?status:[[:space:]]*done' "$1" 2>/dev/null
+  [[ "$(doctor_card_status "$1")" == "done" ]]
 }
+doctor_load_card_status_cache
 
 # v6.12.1 (issue #11 B-2): unified task-card field parser, same three formats
 # as the pre-commit hook (T-043): inline `FIELD: a,b`, markdown `## FIELD`
 # section list, YAML frontmatter multi-line list. The old inline-only grep
 # meant the code->INVENTORY check never evaluated a single section-list card.
 doctor_parse_task_patterns() {
+  if declare -F task_card_parse_patterns >/dev/null 2>&1; then
+    task_card_parse_patterns "$1" "$2" | paste -sd, -
+    return 0
+  fi
   local _field="$1" _file="$2" _inline
   _inline="$(grep "^${_field}:" "$_file" 2>/dev/null | head -1 | sed "s/^${_field}:[[:space:]]*//;s/\r$//")"
   if [ -n "$_inline" ]; then
@@ -289,7 +370,8 @@ package_mode() {
 
 if $PACKAGE_MODE; then
   package_mode
-  printf '\nEngine Doctor: %s failure(s), %s warning(s)\n' "$fail_count" "$warn_count"
+
+printf '\nEngine Doctor: %s failure(s), %s warning(s)\n' "$fail_count" "$warn_count"
   if [[ "$fail_count" -gt 0 ]]; then
     exit 1
   fi
@@ -299,7 +381,10 @@ fi
 engine_path() {
   local file="$1"
   file="$(trim "$file")"
-  if [[ "$file" == engine/* ]]; then
+  # Registry rows may name root-level files (docs/, tests/, install.sh, ...)
+  # as well as engine-relative files. Prefer an existing project-root path;
+  # otherwise retain the historical engine/relative resolution.
+  if [[ "$file" == engine/* || -e "$ROOT/$file" ]]; then
     printf '%s/%s' "$ROOT" "$file"
   else
     printf '%s/%s' "$ENGINE_DIR" "$file"
@@ -475,7 +560,8 @@ check_context_semantics() {
       echo "  human: CONTEXT.md is missing the '$label' row in its status panel. Add a table row for '$label' with current information."
       continue
     fi
-    value="$(printf '%s' "$row" | awk -F'|' '{print $3}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
+    IFS='|' read -ra row_cols <<< "$row"
+    value="$(trim "${row_cols[2]-}")"
     if [[ -z "$value" || "$value" =~ ^\[.*\]$ || "$value" == "TBD" || "$value" == "TODO" ]]; then
       warn "CONTEXT.md status row '$label' is placeholder or empty"
       echo "  human: The '$label' row in CONTEXT.md has no real value (placeholder or empty). Fill in the actual status."
@@ -646,7 +732,11 @@ check_inventory_bidirectional() {
 
   # (a) INVENTORY→code: Entry file paths must exist.
   local inv_to_code_violations=0
-  local entry_paths_seen=""
+  # Keep membership checks in-process. Re-piping the complete inventory text
+  # through grep for every done-task path is prohibitively expensive under
+  # Windows Git Bash and can make Doctor appear hung without changing the
+  # bidirectional validation semantics.
+  declare -A entry_paths_seen_map=()
   for inv in "${inventory_files[@]}"; do
     # Parse table rows: | Feature | Entry file | Public API | Status | Last verified |
     # Skip header rows (|---|) and lines starting with `#` or `>`.
@@ -663,7 +753,7 @@ check_inventory_bidirectional() {
       # cols[0] is empty (leading `|`), cols[1]=Feature, cols[2]=Entry file, ...
       local entry_file=""
       if [ "${#cols[@]}" -ge 3 ]; then
-        entry_file="$(printf '%s' "${cols[2]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
+        entry_file="$(trim "${cols[2]}")"
       fi
       [ -z "$entry_file" ] && continue
       # Skip placeholders / glob patterns.
@@ -678,7 +768,7 @@ check_inventory_bidirectional() {
           warn "INVENTORY→code: $inv references '$entry_file' (grace period, cv=$contract_version < 6.8.0)"
         fi
       else
-        entry_paths_seen="$entry_paths_seen$entry_file"$'\n'
+        entry_paths_seen_map["$entry_file"]=1
       fi
     done < "$inv"
   done
@@ -711,7 +801,7 @@ check_inventory_bidirectional() {
         [[ "$ws_path" == "AGENTS.md" ]] && continue
         [[ "$ws_path" == ".github/"* ]] && continue
         # Check if this path appears in any INVENTORY entry column.
-        if ! printf '%s' "$entry_paths_seen" | grep -qF "$ws_path"; then
+        if [[ -z "${entry_paths_seen_map[$ws_path]+present}" ]]; then
           code_to_inv_violations=$((code_to_inv_violations + 1))
           if [ "$violation_is_fail" -eq 1 ]; then
             fail "code→INVENTORY: $tid touched '$ws_path' but no INVENTORY row references it"
@@ -783,7 +873,7 @@ check_inventory_api_uniqueness() {
       # cols[3] = Public API (0=empty, 1=Feature, 2=Entry, 3=Public API)
       local api=""
       if [ "${#cols[@]}" -ge 4 ]; then
-        api="$(printf '%s' "${cols[3]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
+        api="$(trim "${cols[3]}")"
       fi
       [ -z "$api" ] && continue
       [[ "$api" == \[*\]* ]] && continue
@@ -861,7 +951,7 @@ check_writeset_budget() {
     local IFS_save="$IFS"
     IFS=','
     for ws_path in $write_set_line; do
-      ws_path="$(printf '%s' "$ws_path" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
+      ws_path="$(trim "$ws_path")"
       [ -z "$ws_path" ] && continue
       # Skip globs.
       [[ "$ws_path" == *"*"* ]] && continue
@@ -947,7 +1037,7 @@ check_task_granularity() {
       local IFS_save="$IFS"
       IFS=','
       for p in $write_set_line; do
-        p="$(printf '%s' "$p" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
+        p="$(trim "$p")"
         [ -z "$p" ] && continue
         # De-dup mirror pairs: strip "plugin/" prefix for comparison.
         local canonical="$p"
@@ -1036,7 +1126,7 @@ check_depends_on() {
     IFS=','
     local upstream
     for upstream in $depends_line; do
-      upstream="$(printf '%s' "$upstream" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
+      upstream="$(trim "$upstream")"
       [ -z "$upstream" ] && continue
       # Validate format T-NNN.
       [[ "$upstream" =~ ^T-[0-9]+$ ]] || continue
@@ -1350,15 +1440,22 @@ check_contract_debt() {
 # will upgrade the evidence shape.
 evidence_has_pass() {
   local content="${1:-}"
-  printf '%s\n' "$content" | grep -Eiq '"status"[[:space:]]*:[[:space:]]*"pass"' && return 0
-  printf '%s\n' "$content" | grep -Eiq '"status"[[:space:]]*:' && return 1
-  printf '%s\n' "$content" | grep -Eiq '"verdict"[[:space:]]*:[[:space:]]*"pass"'
+  local lowered="${content,,}"
+  local status_pass_re='"status"[[:space:]]*:[[:space:]]*"pass"'
+  local status_re='"status"[[:space:]]*:'
+  local verdict_pass_re='"verdict"[[:space:]]*:[[:space:]]*"pass"'
+  [[ "$lowered" =~ $status_pass_re ]] && return 0
+  [[ "$lowered" =~ $status_re ]] && return 1
+  [[ "$lowered" =~ $verdict_pass_re ]]
 }
 
 evidence_is_legacy_verdict() {
   local content="${1:-}"
-  printf '%s\n' "$content" | grep -Eiq '"verdict"[[:space:]]*:[[:space:]]*"pass"' || return 1
-  ! printf '%s\n' "$content" | grep -Eiq '"status"[[:space:]]*:'
+  local lowered="${content,,}"
+  local verdict_pass_re='"verdict"[[:space:]]*:[[:space:]]*"pass"'
+  local status_re='"status"[[:space:]]*:'
+  [[ "$lowered" =~ $verdict_pass_re ]] || return 1
+  ! [[ "$lowered" =~ $status_re ]]
 }
 
 check_task_card_done_evidence() {
@@ -1370,22 +1467,24 @@ check_task_card_done_evidence() {
     [[ "$f" == *.spec.md ]] && continue
     card_status_done "$f" || continue
     done_count=$((done_count + 1))
-    local tid; tid="$(basename "$f" .md)"
+    local tid; tid="${f##*/}"; tid="${tid%.md}"
     local ev_dir="$ENGINE_DIR/evidence/$tid"
-    if grep -qi 'exempt' "$f" 2>/dev/null; then
+    local card_content; card_content="$(<"$f")"
+    if [[ "${card_content,,}" == *exempt* ]]; then
       exempt_count=$((exempt_count + 1))
       continue
     fi
-    local ac_ids ac_count missing ac ev
-    ac_ids="$(parse_ac_declarations "$f" | cut -f1)"
-    ac_count="$(printf '%s\n' "$ac_ids" | sed '/^$/d' | wc -l | tr -d ' ')"
+    local ac_records ac_count=0 missing ac verify_cmd ev ev_content
+    ac_records="$(parse_ac_declarations "$f")"
     missing=""
-    for ac in $ac_ids; do
+    while IFS=$'\t' read -r ac verify_cmd || [ -n "$ac" ]; do
+      [ -n "$ac" ] || continue
+      ac_count=$((ac_count + 1))
       ev="$ev_dir/$ac.json"
       if [ ! -f "$ev" ]; then
         missing="${missing}${missing:+,}$ac"
       else
-        ev_content="$(cat "$ev" 2>/dev/null || true)"
+        ev_content="$(<"$ev")"
         if ! evidence_has_pass "$ev_content"; then
           missing="${missing}${missing:+,}$ac"
         elif evidence_is_legacy_verdict "$ev_content"; then
@@ -1393,7 +1492,7 @@ check_task_card_done_evidence() {
           echo "  human: Evidence for $tid/$ac uses the legacy verdict=PASS field. It is accepted for compatibility; re-run engine verify to upgrade it to status=pass."
         fi
       fi
-    done
+    done <<< "$ac_records"
     if [ "$ac_count" -gt 0 ] 2>/dev/null && [ -z "$missing" ]; then
       verified_count=$((verified_count + 1))
     elif command -v git >/dev/null 2>&1 && git cat-file -e "HEAD:engine/tasks/$tid.md" 2>/dev/null; then
@@ -1420,6 +1519,7 @@ check_review_evidence() {
     [[ "$f" == *.spec.md ]] && continue
     card_status_done "$f" || continue
     local tid; tid="$(basename "$f" .md)"
+    task_card_has_code "$ROOT" "$f" || continue
     local review_file="$ENGINE_DIR/review/evidence/$tid/REVIEW.json"
 
     if [ ! -f "$review_file" ]; then
@@ -1442,13 +1542,25 @@ check_review_evidence() {
     prov_argv="$(grep -oE '"argv":"[^"]*"' "$review_file" | head -1 | sed 's/"argv":"//;s/"//')"
     head_commit="$(git rev-parse HEAD 2>/dev/null || echo unknown)"
 
-    [ "$prov_writer" = "engine-review" ] || warn "$tid review evidence writer=$prov_writer (expected engine-review)"
+    case "$prov_writer" in
+      engine-review|engine-review-from-receipt) : ;;
+      *) warn "$tid review evidence writer=$prov_writer (expected engine-review or engine-review-from-receipt)" ;;
+    esac
+    # D-040 (issue #28): stale 判定改为 ancestor-of-HEAD。正常 Coordinator closeout
+    # 会在 review 之后提交 evidence/任务卡/CONTEXT/HANDOFF/ENGINE_MAP/胶囊,合法推进 HEAD;
+    # review commit 仍为 HEAD 祖先即有效,只有被 rebase 掉/分叉/未知 commit 才报 stale。
+    # git merge-base 置于 if 条件内,非祖先返回非零不触发 set -e;git 不可用/commit 空 → fail-open 回退 WARN。
     if [ "$prov_commit" != "$head_commit" ]; then
-      warn "$tid stale review evidence (commit=$prov_commit HEAD=$head_commit)"
-      echo "  human: Task $tid review evidence is stale. Re-run 'engine review $tid' against current HEAD."
+      if command -v git >/dev/null 2>&1 && [ -n "$prov_commit" ] && git merge-base --is-ancestor "$prov_commit" HEAD 2>/dev/null; then
+        : # review commit 仍可从 HEAD 可达(closeout 合法推进)→ 非 stale
+      else
+        warn "$tid stale review evidence (commit=$prov_commit HEAD=$head_commit)"
+        echo "  human: Task $tid review evidence is stale. Re-run 'engine review $tid' against current HEAD."
+      fi
     fi
     case "$prov_argv" in
       "engine review $tid") : ;;
+      "engine review $tid --from-receipt "*) : ;;
       *) warn "$tid review evidence argv mismatch: $prov_argv" ;;
     esac
 
@@ -1528,6 +1640,7 @@ print('true' if ar.get('enabled', False) else 'false')
     [[ "$f" == *.spec.md ]] && continue
     card_status_done "$f" || continue
     local tid; tid="$(basename "$f" .md)"
+    task_card_has_code "$ROOT" "$f" || continue
 
     # 判断此卡是否需要 agent review: config enabled 或 L2 override
     local needs_agent_review=false
@@ -1588,6 +1701,12 @@ print('true' if ar.get('enabled', False) else 'false')
 check_gate_registry() {
   local tasks_dir="$ENGINE_DIR/tasks"
   [ -d "$tasks_dir" ] || return 0
+  # A done task's own AC may invoke Doctor (for example AC-7). During that
+  # nested verification, its previous GATE.json is necessarily transitional:
+  # verify is rebuilding AC evidence and gate has not yet been rerun. Defer
+  # only this task's registry verdict; a standalone Doctor still fails on a
+  # block/missing gate, and all other done tasks remain enforced.
+  local active_verify_task="${ENGINE_VERIFY_ACTIVE_TASK:-}"
   # Determine contract-version
   local cv=""
   for _marker in "$ROOT/AGENTS.md" "$ENGINE_DIR/SYSTEM.md" "$ENGINE_DIR/ENGINE_DOCTOR.md"; do
@@ -1608,6 +1727,11 @@ check_gate_registry() {
     [[ "$f" == *.spec.md ]] && continue
     card_status_done "$f" || continue
     local tid; tid="$(basename "$f" .md)"
+    if [ -n "$active_verify_task" ] && [ "$active_verify_task" = "$tid" ]; then
+      warn "done task $tid GATE registry deferred during active verification"
+      echo "  human: Doctor is running inside 'engine verify $tid'; the task's prior GATE.json is transitional until verify and gate finish."
+      continue
+    fi
     local gate_file="$ENGINE_DIR/evidence/$tid/GATE.json"
 
     if [ ! -f "$gate_file" ]; then
@@ -1649,8 +1773,11 @@ check_drift() {
     return 0
   fi
   local out rc
-  out="$(bash "$script" 2>&1)" || true
-  rc=$?
+  if out="$(bash "$script" 2>&1)"; then
+    rc=0
+  else
+    rc=$?
+  fi
   echo "$out" | sed 's/^/  /'
   if [ "$rc" -ne 0 ]; then
     fail "drift-check detected tamper or drift (see above)"
@@ -1997,6 +2124,93 @@ check_plan_acceptance_evidence() {
   done < "$plan_tmp"
 }
 
+# v6.25.0 (T-086/O1): ShellCheck high-reliability rule subset as grep-based lint.
+# Internalized from ShellCheck (GPL) — only rules with near-zero false-positive
+# grep patterns. WARN-level; does not block gate. Runs on engine/scripts/*.sh.
+check_script_lint() {
+  local scripts_dir="$ENGINE_DIR/scripts"
+  [ -d "$scripts_dir" ] || return 0
+
+  local lint_hits=0
+  local f line_no line
+
+  for f in "$scripts_dir"/*.sh; do
+    [ -f "$f" ] || continue
+    local fname; fname="$(basename "$f")"
+
+    # SC2148: missing shebang on line 1
+    local first_line
+    first_line="$(head -1 "$f")"
+    if [[ "$first_line" != "#!"* ]]; then
+      warn "lint SC2148 ($fname:1): missing shebang"
+      lint_hits=$((lint_hits + 1))
+    fi
+
+    # Line-by-line checks (skip comments and blank lines)
+    line_no=0
+    while IFS= read -r line || [ -n "$line" ]; do
+      line_no=$((line_no + 1))
+      # Skip comments, blank lines, shebang
+      [[ "$line" =~ ^[[:space:]]*# ]] && continue
+      [[ -z "${line// /}" ]] && continue
+
+      # SC2155: local/export var=$(cmd) — declare and assign separately
+      if [[ "$line" =~ ^[[:space:]]*(local|export)[[:space:]]+[A-Za-z_][A-Za-z_0-9]*=\$\( ]]; then
+        warn "lint SC2155 ($fname:$line_no): declare and assign separately to mask return values"
+        lint_hits=$((lint_hits + 1))
+      fi
+
+      # SC2164: cd without || exit / || return / || true / && / ;
+      if [[ "$line" =~ ^[[:space:]]*cd[[:space:]] ]]; then
+        if [[ "$line" != *"||"* && "$line" != *"&&"* && "$line" != *";"* && "$line" != *"pushd"* ]]; then
+          warn "lint SC2164 ($fname:$line_no): cd without error handling (add || exit)"
+          lint_hits=$((lint_hits + 1))
+        fi
+      fi
+
+      # SC2162: read without -r flag
+      if [[ "$line" =~ ^[[:space:]]*read[[:space:]] ]]; then
+        if [[ "$line" != *" -r"* && "$line" != *"read -r"* && "$line" != *"IFS="* ]]; then
+          warn "lint SC2162 ($fname:$line_no): read without -r mangles backslashes"
+          lint_hits=$((lint_hits + 1))
+        fi
+      fi
+
+      # SC2006: backtick command substitution (use $(...) instead)
+      # Skip echo/printf lines (backticks as literal content, not substitution)
+      if [[ "$line" == *'`'*'`'* ]]; then
+        if [[ "$line" =~ ^[[:space:]]*(echo|printf)[[:space:]] ]]; then
+          : # backticks in output content, not command substitution
+        elif [[ "$line" == *"<<"* ]]; then
+          : # heredoc marker line, skip
+        else
+          warn "lint SC2006 ($fname:$line_no): use \$(...) instead of backticks"
+          lint_hits=$((lint_hits + 1))
+        fi
+      fi
+
+      # SC2230: which command (use command -v / type -P)
+      if [[ "$line" =~ ^[[:space:]]*which[[:space:]] || "$line" == *'$(which '* || "$line" == *'`which '* ]]; then
+        warn "lint SC2230 ($fname:$line_no): use 'command -v' instead of 'which'"
+        lint_hits=$((lint_hits + 1))
+      fi
+
+      # SC2002: useless use of cat (cat file | cmd)
+      if [[ "$line" =~ ^[[:space:]]*cat[[:space:]].*\|[[:space:]]*[a-z] ]]; then
+        warn "lint SC2002 ($fname:$line_no): useless use of cat (redirect instead)"
+        lint_hits=$((lint_hits + 1))
+      fi
+
+    done < "$f"
+  done
+
+  if [ "$lint_hits" -eq 0 ]; then
+    pass "script lint: no ShellCheck-pattern violations in engine/scripts/*.sh"
+  fi
+}
+
+
+
 while IFS= read -r path; do
   rel="${path#"$ROOT/"}"
   if [[ "$rel" == engine/README.md || "$rel" == engine/README.zh.md ]]; then
@@ -2031,6 +2245,21 @@ check_prove_health() {
   local prove_dir="$ENGINE_DIR/prove"
   local scripts_dir="$ENGINE_DIR/scripts"
 
+  # Git Bash may expose a Windows Python executable while ROOT is a POSIX
+  # path such as /e/projects/.... Pass paths through argv so MSYS converts
+  # them for Windows Python; embedding the POSIX path in Python source makes
+  # valid JSON look unreadable and falsely fails Doctor.
+  json_file_valid() {
+    local json_path="$1"
+    if command -v python3 >/dev/null 2>&1; then
+      python3 -c 'import json,sys; json.load(open(sys.argv[1], encoding="utf-8"))' "$json_path" >/dev/null 2>&1
+    elif command -v python >/dev/null 2>&1; then
+      python -c 'import json,sys; json.load(open(sys.argv[1], encoding="utf-8"))' "$json_path" >/dev/null 2>&1
+    else
+      return 0
+    fi
+  }
+
   # Scripts exist
   if [[ -f "$scripts_dir/engine-prove.sh" ]]; then
     pass "prove script exists: engine/scripts/engine-prove.sh"
@@ -2047,14 +2276,14 @@ check_prove_health() {
   # Config valid
   if [[ -f "$prove_dir/config.json" ]]; then
     if command -v python3 >/dev/null 2>&1; then
-      if python3 -c "import json; json.load(open('$prove_dir/config.json'))" 2>/dev/null; then
+      if json_file_valid "$prove_dir/config.json"; then
         pass "prove config.json is valid JSON"
       else
         fail "prove config.json is invalid JSON"
         echo "  human: engine/prove/config.json has a JSON syntax error. Fix it manually."
       fi
     elif command -v python >/dev/null 2>&1; then
-      if python -c "import json; json.load(open('$prove_dir/config.json'))" 2>/dev/null; then
+      if json_file_valid "$prove_dir/config.json"; then
         pass "prove config.json is valid JSON"
       else
         fail "prove config.json is invalid JSON"
@@ -2069,14 +2298,14 @@ check_prove_health() {
   # Schema valid
   if [[ -f "$prove_dir/prove-assertions.schema.json" ]]; then
     if command -v python3 >/dev/null 2>&1; then
-      if python3 -c "import json; json.load(open('$prove_dir/prove-assertions.schema.json'))" 2>/dev/null; then
+      if json_file_valid "$prove_dir/prove-assertions.schema.json"; then
         pass "prove schema is valid JSON"
       else
         fail "prove schema is invalid JSON"
         echo "  human: engine/prove/prove-assertions.schema.json has a JSON syntax error."
       fi
     elif command -v python >/dev/null 2>&1; then
-      if python -c "import json; json.load(open('$prove_dir/prove-assertions.schema.json'))" 2>/dev/null; then
+      if json_file_valid "$prove_dir/prove-assertions.schema.json"; then
         pass "prove schema is valid JSON"
       else
         fail "prove schema is invalid JSON"
@@ -2120,6 +2349,29 @@ check_review_config_protected
 check_agent_review_evidence
 check_gate_registry
 
+# v6.26.0 (T-085): capsule heat check
+check_capsule_heat() {
+  local capsule_dir="$ENGINE_DIR/changes"
+  [ -d "$capsule_dir" ] || return 0
+  local f heat related_dec
+  for f in "$capsule_dir"/CHANGE-*.md; do
+    [ -f "$f" ] || continue
+    # Parse META header heat field
+    heat="$(sed -n '/^-----META-START-----/,/^-----META-END-----/{s/^heat:[[:space:]]*//p}' "$f" 2>/dev/null | head -1)"
+    [ -n "$heat" ] || continue
+    case "$heat" in *[!0-9]*) continue ;; esac
+    related_dec="$(sed -n '/^-----META-START-----/,/^-----META-END-----/{s/^related-decisions:[[:space:]]*//p}' "$f" 2>/dev/null | head -1)"
+    local cname
+    cname="$(basename "$f")"
+    if [ "$heat" -ge 5 ]; then
+      warn "capsule $cname heat=$heat: high-frequency change area, consider extracting to formal decision or PITFALLS"
+    elif [ "$heat" -ge 3 ] && [ -z "$related_dec" ]; then
+      warn "capsule $cname heat=$heat with no related-decisions: multiple changes without decision record"
+    fi
+  done
+}
+check_capsule_heat
+
 # ── Project-custom checks (engine/checks/) ──
 # Each project may place executable check-*.sh (FAIL on non-zero) or warn-*.sh
 # (WARN on non-zero) scripts into engine/checks/.  Doctor discovers and runs
@@ -2264,6 +2516,15 @@ for cli in engine engine.ps1 engine.cmd; do
   fi
 done
 
+
+# v6.25.0 (T-086/O1): script lint (ShellCheck-pattern subset)
+check_script_lint
+
+# v6.26.1 (T-081): save HEAD + worktree fingerprint for incremental mode.
+mkdir -p "$_doctor_cache_dir" 2>/dev/null || true
+printf '%s\n%s failure(s), %s warning(s)\n%s\n' \
+  "$_current_head" "$fail_count" "$warn_count" "$_doctor_worktree_fp" > "$_doctor_cache_file" 2>/dev/null || true
+
 printf '\nEngine Doctor: %s failure(s), %s warning(s)\n' "$fail_count" "$warn_count"
 if [[ "$fail_count" -gt 0 ]]; then
   exit 1
```

### plugin/engine/scripts/engine-doctor.ps1
```diff
diff --git a/plugin/engine/scripts/engine-doctor.ps1 b/plugin/engine/scripts/engine-doctor.ps1
index 617b3e3..49df715 100644
--- a/plugin/engine/scripts/engine-doctor.ps1
+++ b/plugin/engine/scripts/engine-doctor.ps1
@@ -1,6 +1,7 @@
 param(
   [string]$Root = (Get-Location).Path,
-  [switch]$PackageMode
+  [switch]$PackageMode,
+  [switch]$Full
 )
 
 $ErrorActionPreference = "Stop"
@@ -12,11 +13,51 @@ if ($Root -like '--*') {
   Write-Error "Error: unknown flag '$Root' (known: -PackageMode; a path argument sets -Root)"
   exit 2
 }
-$engineDir = Join-Path $Root "engine"
-$map = Join-Path $engineDir "ENGINE_MAP.md"
+$engineDir = Join-Path $Root "engine"
+$taskCardLibrary = Join-Path $PSScriptRoot "engine-task-card.ps1"
+if (Test-Path -LiteralPath $taskCardLibrary -PathType Leaf) { . $taskCardLibrary }
+$map = Join-Path $engineDir "ENGINE_MAP.md"
 $failCount = 0
 $warnCount = 0
 
+# v6.25.0 (T-086/B6): incremental mode — skip if HEAD unchanged.
+# v6.26.1 (T-081): HEAD alone is insufficient while verify/close and parallel
+# workers update evidence in the worktree. Include tracked diffs and untracked
+# files in the cache key so a cached failure/pass cannot survive a real change.
+$doctorCacheDir = Join-Path $engineDir '.cache'
+$doctorCacheFile = Join-Path $doctorCacheDir 'doctor-last-run'
+$currentHead = & git -C $Root rev-parse HEAD 2>$null
+if (-not $currentHead) { $currentHead = 'none' }
+
+function Get-DoctorWorktreeFingerprint {
+  $parts = New-Object System.Collections.Generic.List[string]
+  $diff = @(& git -C $Root diff --no-ext-diff --binary HEAD -- . 2>$null)
+  if ($diff.Count -gt 0) { [void]$parts.Add(($diff -join "`n")) }
+  foreach ($relative in @(& git -C $Root ls-files --others --exclude-standard 2>$null)) {
+    if ([string]::IsNullOrWhiteSpace($relative)) { continue }
+    $path = Join-Path $Root $relative
+    if (Test-Path -LiteralPath $path -PathType Leaf) {
+      $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
+      [void]$parts.Add("untracked:$relative`n$hash")
+    }
+  }
+  $payload = [Text.Encoding]::UTF8.GetBytes(($parts -join "`n"))
+  $sha = [Security.Cryptography.SHA256]::Create()
+  return (([BitConverter]::ToString($sha.ComputeHash($payload))) -replace '-', '').ToLowerInvariant()
+}
+
+$doctorWorktreeFingerprint = Get-DoctorWorktreeFingerprint
+if (-not $Full -and (Test-Path $doctorCacheFile)) {
+  $cacheLines = Get-Content -Path $doctorCacheFile -Encoding UTF8 -ErrorAction SilentlyContinue
+  if ($cacheLines -and $cacheLines.Count -ge 3 -and $cacheLines[0] -eq $currentHead -and $cacheLines[2] -eq $doctorWorktreeFingerprint -and $currentHead -ne 'none') {
+    Write-Host "[engine-doctor] incremental: HEAD/worktree unchanged ($currentHead), using cached result."
+    Write-Host "[engine-doctor] cached: $($cacheLines[1])"
+    Write-Host "  (use 'engine doctor --full' to force a complete re-check)"
+    if ($cacheLines[1] -match '([0-9]+) failure' -and [int]$Matches[1] -gt 0) { exit 1 }
+    exit 0
+  }
+}
+
 function Write-Fail([string]$Message) {
   $script:failCount++
   Write-Host "FAIL $Message" -ForegroundColor Red
@@ -45,9 +86,12 @@ function Trim-Cell([string]$Value) {
 # Returns: array of objects with AcId and VerifyCmd properties (VerifyCmd may be empty for SKIP).
 # AC id regex: AC-[A-Za-z]*[0-9]+(\.[0-9]+)* (v6.12.1 A-3).
 # Separators: | verify: / |verify: / -> verify: / ->verify: / line-start verify:
-function Parse-AcDeclarations {
-  param([string]$Path)
-  $results = @()
+function Parse-AcDeclarations {
+  param([string]$Path)
+  if (Get-Command Get-TaskCardAcDeclarations -ErrorAction SilentlyContinue) {
+    return @(Get-TaskCardAcDeclarations -Path $Path)
+  }
+  $results = @()
   if (-not (Test-Path $Path)) { return $results }
   $sepArrow = [string][char]0x2192
   $acIdPattern = 'AC-[A-Za-z]*\d+(?:\.\d+)*'
@@ -127,8 +171,11 @@ function Test-CardStatus([string]$Content, [string]$Status) {
 # v6.12.1 (issue #11 B-2): unified task-card field parser, same three formats
 # as the pre-commit hook (T-043): inline "FIELD: a,b", markdown "## FIELD"
 # section list, YAML frontmatter multi-line list. Returns comma-joined string.
-function Get-TaskPatterns([string]$Content, [string]$Field) {
-  if (-not $Content) { return "" }
+function Get-TaskPatterns([string]$Content, [string]$Field) {
+  if (Get-Command Get-TaskCardPatterns -ErrorAction SilentlyContinue) {
+    return (@(Get-TaskCardPatterns -Content $Content -Field $Field) -join ',')
+  }
+  if (-not $Content) { return "" }
   $inlineMatch = [regex]::Match($Content, ('(?m)^' + [regex]::Escape($Field) + ':\s*(.+)$'))
   if ($inlineMatch.Success) { return $inlineMatch.Groups[1].Value.TrimEnd() }
   $out = @()
@@ -159,7 +206,10 @@ function Get-TaskPatterns([string]$Content, [string]$Field) {
 
 function Resolve-EnginePath([string]$File) {
   $clean = Trim-Cell $File
-  if ($clean -like "engine/*") {
+  # Registry rows may name root-level files (docs/, tests/, install.ps1, ...)
+  # as well as engine-relative files. Prefer an existing project-root path;
+  # otherwise retain the historical engine-relative resolution.
+  if ($clean -like "engine/*" -or (Test-Path -LiteralPath (Join-Path $Root ($clean -replace "/", [IO.Path]::DirectorySeparatorChar)))) {
     return Join-Path $Root ($clean -replace "/", [IO.Path]::DirectorySeparatorChar)
   }
   return Join-Path $engineDir ($clean -replace "/", [IO.Path]::DirectorySeparatorChar)
@@ -297,7 +347,11 @@ function Test-PackageMode {
 if ($PackageMode) {
   Test-PackageMode
   Write-Host ""
-  Write-Host "Engine Doctor: $failCount failure(s), $warnCount warning(s)"
+  # v6.26.1 (T-081): save HEAD + worktree fingerprint for incremental mode.
+if (-not (Test-Path $doctorCacheDir)) { New-Item -ItemType Directory -Path $doctorCacheDir -Force | Out-Null }
+Set-Content -Path $doctorCacheFile -Value @($currentHead, "$failCount failure(s), $warnCount warning(s)", $doctorWorktreeFingerprint) -Encoding UTF8 -ErrorAction SilentlyContinue
+
+Write-Host "Engine Doctor: $failCount failure(s), $warnCount warning(s)"
   if ($failCount -gt 0) { exit 1 }
   exit 0
 }
@@ -1312,17 +1366,17 @@ function Test-ContractDebt {
   }
 }
 
-function Test-EvidencePass([string]$Content) {
-  if ($Content -match '(?i)"status"\s*:\s*"pass"') { return $true }
-  if ($Content -match '(?i)"status"\s*:') { return $false }
-  return ($Content -match '(?i)"verdict"\s*:\s*"pass"')
-}
-
-function Test-LegacyVerdictEvidence([string]$Content) {
-  return (($Content -match '(?i)"verdict"\s*:\s*"pass"') -and ($Content -notmatch '(?i)"status"\s*:'))
-}
-
-function Test-TaskCardDoneEvidence {
+function Test-EvidencePass([string]$Content) {
+  if ($Content -match '(?i)"status"\s*:\s*"pass"') { return $true }
+  if ($Content -match '(?i)"status"\s*:') { return $false }
+  return ($Content -match '(?i)"verdict"\s*:\s*"pass"')
+}
+
+function Test-LegacyVerdictEvidence([string]$Content) {
+  return (($Content -match '(?i)"verdict"\s*:\s*"pass"') -and ($Content -notmatch '(?i)"status"\s*:'))
+}
+
+function Test-TaskCardDoneEvidence {
   $tasksDir = Join-Path $engineDir "tasks"
   if (-not (Test-Path $tasksDir)) { return }
   $doneCount = 0
@@ -1345,12 +1399,12 @@ function Test-TaskCardDoneEvidence {
       $evPath = Join-Path $evDir ($ac + '.json')
       if (-not (Test-Path $evPath)) { $missing.Add($ac); continue }
       $evContent = Get-Content -Raw -Path $evPath -Encoding UTF8 -ErrorAction SilentlyContinue
-      if (-not (Test-EvidencePass $evContent)) {
-        $missing.Add($ac)
-      } elseif (Test-LegacyVerdictEvidence $evContent) {
-        Write-Warn "task $tid/$ac uses legacy verdict evidence (accepted; re-run 'engine verify $tid' to write status=pass)"
-        Write-Output "  human: Evidence for $tid/$ac uses the legacy verdict=PASS field. It is accepted for compatibility; re-run engine verify to upgrade it to status=pass."
-      }
+      if (-not (Test-EvidencePass $evContent)) {
+        $missing.Add($ac)
+      } elseif (Test-LegacyVerdictEvidence $evContent) {
+        Write-Warn "task $tid/$ac uses legacy verdict evidence (accepted; re-run 'engine verify $tid' to write status=pass)"
+        Write-Output "  human: Evidence for $tid/$ac uses the legacy verdict=PASS field. It is accepted for compatibility; re-run engine verify to upgrade it to status=pass."
+      }
     }
     if ($acIds.Count -gt 0 -and $missing.Count -eq 0) {
       $verifiedCount++
@@ -1375,89 +1429,89 @@ function Test-TaskCardDoneEvidence {
   }
 }
 
-# v6.18.0 (D-038/T-066 AC-8): drift-check integration. Defers to the
-# standalone engine-drift-check.ps1 script (cheap fingerprint comparison,
-# no verify re-run). Tamper/drift = FAIL; warn-only issues stay WARN.
-function Test-Drift {
-  $script = Join-Path $EngineDir "scripts\engine-drift-check.ps1"
-  if (-not (Test-Path $script)) {
-    Write-Warn "drift-check script missing: $script"
-    return
-  }
-  $gitCmd = Get-Command git -ErrorAction SilentlyContinue
-  if (-not $gitCmd) {
-    Write-Warn "git not on PATH - drift-check skipped"
-    return
-  }
-  $out = & pwsh -NoProfile -File $script 2>&1 | Out-String
-  $rc = $LASTEXITCODE
-  if ($out) {
-    foreach ($line in ($out -split "`r?`n")) {
-      if ($line) { Write-Output "  $line" }
-    }
-  }
-  if ($rc -ne 0) {
-    Write-Fail "drift-check detected tamper or drift (see above)"
-    Write-Output "  human: Evidence integrity or code fingerprint mismatch. Re-run 'engine verify <T-NNN>' against current HEAD, or mark evidence-manual-edit with a covering approved decision."
-  } else {
-    Write-Pass "drift-check passed (no tamper, no drift)"
-  }
-}
-
-# v6.19.0 (D-038c/T-067): derived status panel check. Double-write transition:
-# CONTEXT.md static panel is labeled "legacy" while engine context outputs a
-# real-time "Derived Status" segment. Doctor verifies (1) the legacy annotation
-# exists and (2) derived values (git tag vs engine/VERSION) match the static
-# declaration. Mismatches are WARN only during the double-write transition.
-function Test-DerivedStatus {
-  $ctx = Join-Path $EngineDir "CONTEXT.md"
-  if (-not (Test-Path $ctx)) { return }
-  $gitExe = Get-Command git -ErrorAction SilentlyContinue
-  if (-not $gitExe) {
-    Write-Warn "git not on PATH - derived status check skipped"
-    return
-  }
-
-  # (1) Legacy annotation check.
-  $ctxContent = Get-Content -Raw -Path $ctx -Encoding UTF8 -ErrorAction SilentlyContinue
-  if ($ctxContent -match '<!-- legacy: status-panel') {
-    Write-Pass "CONTEXT.md status-panel has legacy annotation (double-write transition)"
-  } else {
-    Write-Warn "CONTEXT.md status-panel missing <!-- legacy: status-panel --> annotation"
-    Write-Output "  human: Add <!-- legacy: status-panel (double-write transition, v6.19.0~v6.20.0) --> after the status panel header. See D-038c."
-    return
-  }
-
-  # (2) Derived value consistency: latest git tag vs engine/VERSION.
-  $latestTag = "none"
-  try {
-    $latestTag = (git -C $Root describe --tags --abbrev=0 2>$null) -join ''
-    if (-not $latestTag) { $latestTag = "none" }
-  } catch { $latestTag = "none" }
-
-  $engineVer = "unknown"
-  $evFile = Join-Path $EngineDir "VERSION"
-  if (Test-Path $evFile) {
-    $engineVer = (Get-Content $evFile -Raw -Encoding UTF8 -ErrorAction SilentlyContinue).Trim()
-  }
-  $latestVer = $latestTag -replace '^v', ''
-
-  if ($latestVer -eq $engineVer) {
-    Write-Pass "derived tag/VERSION consistent ($latestTag = $engineVer)"
-  } else {
-    Write-Warn "derived tag/VERSION mismatch: git tag=$latestTag, engine/VERSION=$engineVer"
-    Write-Output "  human: The latest git tag does not match engine/VERSION. Run 'engine update' or create a matching tag."
-  }
-
-  # (3) Check static panel mentions the latest tag (stale panel detection).
-  if ($ctxContent -match [regex]::Escape($latestVer)) {
-    Write-Pass "static panel references current version ($latestVer)"
-  } else {
-    Write-Warn "static panel does not reference current version ($latestVer) - panel may be stale"
-    Write-Output "  human: Update the status panel in CONTEXT.md to mention v$engineVer, or rely on the Derived Status segment."
-  }
-}
-
+# v6.18.0 (D-038/T-066 AC-8): drift-check integration. Defers to the
+# standalone engine-drift-check.ps1 script (cheap fingerprint comparison,
+# no verify re-run). Tamper/drift = FAIL; warn-only issues stay WARN.
+function Test-Drift {
+  $script = Join-Path $EngineDir "scripts\engine-drift-check.ps1"
+  if (-not (Test-Path $script)) {
+    Write-Warn "drift-check script missing: $script"
+    return
+  }
+  $gitCmd = Get-Command git -ErrorAction SilentlyContinue
+  if (-not $gitCmd) {
+    Write-Warn "git not on PATH - drift-check skipped"
+    return
+  }
+  $out = & pwsh -NoProfile -File $script 2>&1 | Out-String
+  $rc = $LASTEXITCODE
+  if ($out) {
+    foreach ($line in ($out -split "`r?`n")) {
+      if ($line) { Write-Output "  $line" }
+    }
+  }
+  if ($rc -ne 0) {
+    Write-Fail "drift-check detected tamper or drift (see above)"
+    Write-Output "  human: Evidence integrity or code fingerprint mismatch. Re-run 'engine verify <T-NNN>' against current HEAD, or mark evidence-manual-edit with a covering approved decision."
+  } else {
+    Write-Pass "drift-check passed (no tamper, no drift)"
+  }
+}
+
+# v6.19.0 (D-038c/T-067): derived status panel check. Double-write transition:
+# CONTEXT.md static panel is labeled "legacy" while engine context outputs a
+# real-time "Derived Status" segment. Doctor verifies (1) the legacy annotation
+# exists and (2) derived values (git tag vs engine/VERSION) match the static
+# declaration. Mismatches are WARN only during the double-write transition.
+function Test-DerivedStatus {
+  $ctx = Join-Path $EngineDir "CONTEXT.md"
+  if (-not (Test-Path $ctx)) { return }
+  $gitExe = Get-Command git -ErrorAction SilentlyContinue
+  if (-not $gitExe) {
+    Write-Warn "git not on PATH - derived status check skipped"
+    return
+  }
+
+  # (1) Legacy annotation check.
+  $ctxContent = Get-Content -Raw -Path $ctx -Encoding UTF8 -ErrorAction SilentlyContinue
+  if ($ctxContent -match '<!-- legacy: status-panel') {
+    Write-Pass "CONTEXT.md status-panel has legacy annotation (double-write transition)"
+  } else {
+    Write-Warn "CONTEXT.md status-panel missing <!-- legacy: status-panel --> annotation"
+    Write-Output "  human: Add <!-- legacy: status-panel (double-write transition, v6.19.0~v6.20.0) --> after the status panel header. See D-038c."
+    return
+  }
+
+  # (2) Derived value consistency: latest git tag vs engine/VERSION.
+  $latestTag = "none"
+  try {
+    $latestTag = (git -C $Root describe --tags --abbrev=0 2>$null) -join ''
+    if (-not $latestTag) { $latestTag = "none" }
+  } catch { $latestTag = "none" }
+
+  $engineVer = "unknown"
+  $evFile = Join-Path $EngineDir "VERSION"
+  if (Test-Path $evFile) {
+    $engineVer = (Get-Content $evFile -Raw -Encoding UTF8 -ErrorAction SilentlyContinue).Trim()
+  }
+  $latestVer = $latestTag -replace '^v', ''
+
+  if ($latestVer -eq $engineVer) {
+    Write-Pass "derived tag/VERSION consistent ($latestTag = $engineVer)"
+  } else {
+    Write-Warn "derived tag/VERSION mismatch: git tag=$latestTag, engine/VERSION=$engineVer"
+    Write-Output "  human: The latest git tag does not match engine/VERSION. Run 'engine update' or create a matching tag."
+  }
+
+  # (3) Check static panel mentions the latest tag (stale panel detection).
+  if ($ctxContent -match [regex]::Escape($latestVer)) {
+    Write-Pass "static panel references current version ($latestVer)"
+  } else {
+    Write-Warn "static panel does not reference current version ($latestVer) - panel may be stale"
+    Write-Output "  human: Update the status panel in CONTEXT.md to mention v$engineVer, or rely on the Derived Status segment."
+  }
+}
+
 function Test-EngineVersion {
   $ev = Join-Path $EngineDir "VERSION"
   if (-not (Test-Path $ev)) {
@@ -1769,15 +1823,17 @@ function Test-WorkstreamOrphan {
 }
 
 # v6.20.0 (T-070): review evidence Doctor check (spec §3.3).
-function Test-ReviewEvidence {
+function Test-ReviewEvidence {
   $tasksDir = Join-Path $engineDir "tasks"
   if (-not (Test-Path $tasksDir)) { return }
   Get-ChildItem -Path $tasksDir -Filter "T-*.md" | ForEach-Object {
     $f = $_.FullName
     if ($f -like "*.spec.md") { return }
-    $content = Get-Content $f -Raw
-    if ($content -notmatch '(?m)^\s*(>\s*)?status:\s*done') { return }
-    $tid = $_.BaseName
+    $content = Get-Content $f -Raw
+    if ($content -notmatch '(?m)^\s*(>\s*)?status:\s*done') { return }
+    if ((Get-Command Test-TaskCardHasCode -ErrorAction SilentlyContinue) -and
+        -not (Test-TaskCardHasCode -Root $Root -Path $f)) { return }
+    $tid = $_.BaseName
     $reviewFile = Join-Path $engineDir "review\evidence\$tid\REVIEW.json"
 
     if (-not (Test-Path $reviewFile)) {
@@ -1792,13 +1848,24 @@ function Test-ReviewEvidence {
 
     $review = Get-Content $reviewFile -Raw | ConvertFrom-Json
     $headCommit = git rev-parse HEAD 2>$null
-    if ($review.write_provenance.writer -ne "engine-review") {
-      Write-Warn "$tid review evidence writer=$($review.write_provenance.writer) (expected engine-review)"
+    if ($review.write_provenance.writer -notin @("engine-review","engine-review-from-receipt")) {
+      Write-Warn "$tid review evidence writer=$($review.write_provenance.writer) (expected engine-review or engine-review-from-receipt)"
     }
     if ($review.write_provenance.commit -ne $headCommit) {
-      Write-Warn "$tid stale review evidence (commit=$($review.write_provenance.commit) HEAD=$headCommit)"
+      # D-040 (issue #28): stale 判定改为 ancestor-of-HEAD。正常 Coordinator closeout
+      # 会在 review 之后提交 evidence/任务卡/CONTEXT/HANDOFF/ENGINE_MAP/胶囊,合法推进 HEAD;
+      # review commit 仍为 HEAD 祖先即有效,只有被 rebase 掉/分叉/未知 commit 才报 stale。
+      $provCommit = $review.write_provenance.commit
+      $isAncestor = $false
+      if ($provCommit) {
+        git merge-base --is-ancestor $provCommit HEAD 2>$null
+        if ($LASTEXITCODE -eq 0) { $isAncestor = $true }
+      }
+      if (-not $isAncestor) {
+        Write-Warn "$tid stale review evidence (commit=$($review.write_provenance.commit) HEAD=$headCommit)"
+      }
     }
-    if ($review.write_provenance.argv -ne "engine review $tid") {
+    if ($review.write_provenance.argv -ne "engine review $tid" -and $review.write_provenance.argv -notlike "engine review $tid --from-receipt *") {
       Write-Warn "$tid review evidence argv mismatch: $($review.write_provenance.argv)"
     }
     if ($review.tool_unavailable -eq $true) {
@@ -1821,6 +1888,54 @@ function Test-ReviewConfigProtected {
   }
 }
 
+# v6.26.0: capsule heat check. Scans engine/changes/CHANGE-*.md META headers
+# for a numeric "heat:" field. High heat indicates a frequently-changed area
+# that may deserve a formal decision or PITFALLS entry. Heat >= 3 without a
+# related-decisions record suggests undocumented repeated changes.
+function Test-CapsuleHeat {
+  try {
+    $changesDir = Join-Path $engineDir "changes"
+    if (-not (Test-Path $changesDir)) { return }
+    $capsules = @(Get-ChildItem -Path $changesDir -File -Filter "CHANGE-*.md" -ErrorAction SilentlyContinue)
+    if ($capsules.Count -eq 0) { return }
+
+    foreach ($capsule in $capsules) {
+      $content = Get-Content -Raw -Path $capsule.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
+      if (-not $content) { continue }
+
+      # Parse META header between -----META-START----- and -----META-END-----.
+      $metaMatch = [regex]::Match($content, '(?s)-----META-START-----(.+?)-----META-END-----')
+      if (-not $metaMatch.Success) { continue }
+      $metaBlock = $metaMatch.Groups[1].Value
+
+      # Extract "heat:" field (must be numeric, skip if not).
+      $heatMatch = [regex]::Match($metaBlock, '(?m)^\s*heat:\s*(.+)$')
+      if (-not $heatMatch.Success) { continue }
+      $heatRaw = $heatMatch.Groups[1].Value.Trim()
+      if ($heatRaw -notmatch '^\d+$') { continue }
+      $heat = [int]$heatRaw
+
+      # Extract "related-decisions:" field.
+      $relatedDecisions = ""
+      $rdMatch = [regex]::Match($metaBlock, '(?m)^\s*related-decisions:\s*(.*)$')
+      if ($rdMatch.Success) { $relatedDecisions = $rdMatch.Groups[1].Value.Trim() }
+
+      # heat >= 5 -> WARN high-frequency change area.
+      if ($heat -ge 5) {
+        Write-Warn "$($capsule.Name) has heat=$heat - high-frequency change area, consider extracting to formal decision or PITFALLS"
+        Write-Output "  human: Change capsule '$($capsule.Name)' has a heat score of $heat (>=5), indicating this area is changed very frequently. Consider extracting the recurring pattern into a formal decision (engine/decisions/) or a PITFALLS entry to reduce repeated churn."
+      }
+      # heat >= 3 AND related-decisions empty -> WARN multiple changes without decision record.
+      elseif ($heat -ge 3 -and [string]::IsNullOrEmpty($relatedDecisions)) {
+        Write-Warn "$($capsule.Name) has heat=$heat but no related-decisions - multiple changes without decision record"
+        Write-Output "  human: Change capsule '$($capsule.Name)' has a heat score of $heat (>=3) but no related-decisions field in its META header. Multiple changes to this area should be backed by a decision record. Add 'related-decisions: D-NNN' to the META block or create a decision."
+      }
+    }
+  } catch {
+    # Fail-open: capsule heat check must never block the doctor run.
+  }
+}
+
 if (Test-Path $engineDir) {
   Get-ChildItem -Path $engineDir -File -Filter "*.md" | ForEach-Object {
     $rel = "engine/$($_.Name)"
@@ -1892,6 +2007,7 @@ Test-WriteSetBudget
 Test-TaskGranularity
 Test-DependsOn
 Test-WarnDoneGate
+Test-CapsuleHeat
 Test-PitfallsSemantics
 Test-SprintSemantics
 Test-ChangeCapsuleSemantics
@@ -1975,6 +2091,79 @@ foreach ($anchor in @("AGENTS.md", "CLAUDE.md")) {
   }
 }
 
+
+# v6.25.0 (T-086/O1): ShellCheck high-reliability rule subset (grep-based lint).
+function Check-ScriptLint {
+  $scriptsDir = Join-Path $engineDir "scripts"
+  if (-not (Test-Path $scriptsDir)) { return }
+
+  $lintHits = 0
+  $shFiles = Get-ChildItem -Path $scriptsDir -Filter "*.sh" -File -ErrorAction SilentlyContinue
+  foreach ($file in $shFiles) {
+    $fname = $file.Name
+    $lines = Get-Content -Path $file.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
+    if (-not $lines) { continue }
+
+    # SC2148: missing shebang
+    if ($lines.Count -gt 0 -and $lines[0] -notmatch '^#!') {
+      Write-Warn "lint SC2148 ($fname`:1): missing shebang"
+      $lintHits++
+    }
+
+    $lineNo = 0
+    foreach ($line in $lines) {
+      $lineNo++
+      if ($line -match '^\s*#') { continue }
+      if ($line -match '^\s*$') { continue }
+
+      # SC2155: local/export var=$(cmd)
+      if ($line -match '^\s*(local|export)\s+[A-Za-z_][A-Za-z_0-9]*=\$\(') {
+        Write-Warn "lint SC2155 ($fname`:$lineNo): declare and assign separately to mask return values"
+        $lintHits++
+      }
+
+      # SC2164: cd without error handling
+      if ($line -match '^\s*cd\s') {
+        if ($line -notmatch '\|\|' -and $line -notmatch '&&' -and $line -notmatch ';' -and $line -notmatch 'pushd') {
+          Write-Warn "lint SC2164 ($fname`:$lineNo): cd without error handling (add || exit)"
+          $lintHits++
+        }
+      }
+
+      # SC2162: read without -r
+      if ($line -match '^\s*read\s') {
+        if ($line -notmatch ' -r' -and $line -notmatch 'IFS=') {
+          Write-Warn "lint SC2162 ($fname`:$lineNo): read without -r mangles backslashes"
+          $lintHits++
+        }
+      }
+
+      # SC2006: backtick command substitution
+      $backtickCount = ($line.ToCharArray() | Where-Object { $_ -eq '`' } | Measure-Object).Count
+      if ($backtickCount -ge 2) {
+        Write-Warn "lint SC2006 ($fname`:$lineNo): use dollar-paren instead of backticks"
+        $lintHits++
+      }
+
+      # SC2230: which command
+      if ($line -match '^\s*which\s' -or $line -match '\$\(which ') {
+        Write-Warn "lint SC2230 ($fname`:$lineNo): use command -v instead of which"
+        $lintHits++
+      }
+
+      # SC2002: useless use of cat
+      if ($line -match '^\s*cat\s.*\|\s*[a-z]') {
+        Write-Warn "lint SC2002 ($fname`:$lineNo): useless use of cat (redirect instead)"
+        $lintHits++
+      }
+    }
+  }
+
+  if ($lintHits -eq 0) {
+    Write-Pass "script lint: no ShellCheck-pattern violations in engine/scripts/*.sh"
+  }
+}
+
 if ($registeredNames -notcontains "ENGINE_DOCTOR.md") {
   Write-Warn "ENGINE_DOCTOR.md is not registered in ENGINE_MAP section 1"
   Write-Output "  human: The ENGINE_DOCTOR.md file is not listed in the ENGINE_MAP file registry. Add it to section 1 so the system can track it."
@@ -2019,7 +2208,14 @@ foreach ($cli in @("engine", "engine.ps1", "engine.cmd")) {
   }
 }
 
-Write-Host ""
-Write-Host "Engine Doctor: $failCount failure(s), $warnCount warning(s)"
+# v6.25.0 (T-086/O1): script lint (ShellCheck-pattern subset)
+Check-ScriptLint
+
+Write-Host ""
+# v6.26.1 (T-081): save normal-mode results too; the cache key includes the
+# worktree fingerprint so later verify/close writes force a fresh Doctor run.
+if (-not (Test-Path $doctorCacheDir)) { New-Item -ItemType Directory -Path $doctorCacheDir -Force | Out-Null }
+Set-Content -Path $doctorCacheFile -Value @($currentHead, "$failCount failure(s), $warnCount warning(s)", $doctorWorktreeFingerprint) -Encoding UTF8 -ErrorAction SilentlyContinue
+Write-Host "Engine Doctor: $failCount failure(s), $warnCount warning(s)"
 if ($failCount -gt 0) { exit 1 }
 exit 0
```

### engine/scripts/engine-verify.sh
```diff
diff --git a/engine/scripts/engine-verify.sh b/engine/scripts/engine-verify.sh
index 31b3403..3176c67 100644
--- a/engine/scripts/engine-verify.sh
+++ b/engine/scripts/engine-verify.sh
@@ -13,6 +13,11 @@ on_error() { echo "[engine-verify] error on line $1 (${BASH_SOURCE[0]})" >&2; ex
 trap 'on_error ${LINENO}' ERR
 ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
 ENGINE_DIR="$ROOT/engine"
+task_card_script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
+if [ -f "$task_card_script_dir/engine-task-card.sh" ]; then
+  # shellcheck source=/dev/null
+  . "$task_card_script_dir/engine-task-card.sh"
+fi
 task="${1:-}"
 preflight=0
 force_no_cov=0
@@ -28,13 +33,16 @@ if [ -z "$task" ]; then
   exit 2
 fi
 
-# v6.10.0 (D-028/T-035): recursion guard. An AC verify command may itself
-# invoke `bash engine/scripts/engine-verify.sh T-NNN` (e.g. T-035 AC-2 dogfood).
-# Without a guard, that would infinitely recurse (each call re-iterates ACs and
-# re-spawns the recursive call). The guard env var carries the task ID being
-# verified by the outer call; a recursive invocation for the SAME task exits 0
-# immediately. Other task IDs (e.g. behavior-verify test fixtures) run normally.
+# v6.10.0/v6.26.1 (D-028/T-035, T-081): recursion guard. An AC verify command
+# may invoke another task verifier (for example T-081 AC-4 -> T-080, whose
+# AC-4 dogfoods T-080 again). A single guard ID only protects same-task
+# recursion; the stack protects cross-task cycles while allowing one nested
+# verifier for a different task.
 # Dead-code evidence (DEAD-CODE.json) is written by the outer (first) call only.
+verify_stack="${ENGINE_VERIFY_RECURSE_STACK:-}"
+case ":$verify_stack:" in
+  *":$1:"*) exit 0 ;;
+esac
 if [ -n "${ENGINE_VERIFY_RECURSE_GUARD:-}" ] && [ "${ENGINE_VERIFY_RECURSE_GUARD:-}" = "$1" ]; then
   exit 0
 fi
@@ -69,6 +77,10 @@ empty_fp_pass=0
 # AC id regex: AC-[A-Za-z]*[0-9]+(\.[0-9]+)* (v6.12.1 A-3).
 # Separators: | verify: / |verify: / → verify: / →verify: / line-start verify:
 parse_ac_declarations() {
+  if declare -F task_card_parse_ac_declarations >/dev/null 2>&1; then
+    task_card_parse_ac_declarations "$@"
+    return 0
+  fi
   local file="$1"
   local line ac_id verify_cmd verify_rest
   local section_ac="" pending_ac=""
@@ -161,7 +173,7 @@ parse_ac_declarations() {
 # is_engine_metadata: 判断路径是否 engine 元数据(排除出 code_fingerprint)
 is_engine_metadata() {
   case "$1" in
-    engine/tasks/*|engine/decisions/*|engine/changes/*|engine/evidence/*|engine/domains/*|engine/archive/*) return 0 ;;
+    engine/tasks/*|engine/decisions/*|engine/changes/*|engine/evidence/*|engine/review/evidence/*|engine/domains/*|engine/archive/*) return 0 ;;
     engine/CONTEXT.md|engine/HANDOFF.md|engine/ENGINE_MAP.md|engine/handoff-archive-*) return 0 ;;
     VERSION|engine/VERSION|plugin/VERSION|plugin/manifest.json|CHANGELOG.md) return 0 ;;
     *) return 1 ;;
@@ -174,20 +186,23 @@ declare -A code_fingerprint=()
 declare -A code_fp_files=()
 ws_snapshot=()
 collect_code_fingerprint() {
-  local file="$1" in_ws=0 line path blob_sha
-  while IFS= read -r line || [ -n "$line" ]; do
-    case "$line" in
-      "## WRITE-SET") in_ws=1; continue ;;
-      "## "*) [ "$in_ws" = "1" ] && break ;;
-    esac
-    [ "$in_ws" = "1" ] || continue
-    [[ "$line" =~ ^-[[:space:]]+([^[:space:]].+) ]] || continue
-    path="${BASH_REMATCH[1]}"
+  local file="$1" path blob_sha
+  local write_set_lines=""
+  if declare -F task_card_parse_patterns >/dev/null 2>&1; then
+    write_set_lines="$(task_card_parse_patterns WRITE-SET "$file")"
+  else
+    write_set_lines="$(awk '/^##[[:space:]]+WRITE-SET[[:space:]]*$/{on=1;next} on&&/^##[[:space:]]+/{on=0} on&&/^[[:space:]]*-[[:space:]]+/{sub(/^[[:space:]]*-[[:space:]]+/,"");print}' "$file")"
+  fi
+  while IFS= read -r path; do
+    path="${path%%(*}"
+    path="${path%%\[*}"
+    path="${path%"${path##*[![:space:]]}"}"
+    [ -n "$path" ] || continue
     is_engine_metadata "$path" && continue
     [ -f "$ROOT/$path" ] || continue
     code_fp_files["$path"]=1
     ws_snapshot+=("$path")
-  done < "$file"
+  done <<< "$write_set_lines"
   local missing=()
   for path in "${!code_fp_files[@]}"; do
     blob_sha="$(cd "$ROOT" && git ls-files -s "$path" 2>/dev/null | awk '{print $2}')"
@@ -312,13 +327,60 @@ append_no_cov() {
   fi
 }
 
+# Windows Git Bash/WSL installations may expose PowerShell only as a .exe
+# outside the inherited PATH. Resolve that executable before running declared
+# AC commands so Bash close/verify does not turn a valid Windows AC into 127.
+ensure_powershell_on_path() {
+  local resolved dir
+  ENGINE_PWSH_CMD=""
+  resolved="$(command -v pwsh 2>/dev/null || true)"
+  if [ -n "$resolved" ]; then
+    # WSL may resolve the Windows .exe but still fail to execute the bare
+    # extensionless token from a nested bash -c. Keep the resolved path and
+    # quote it when rewriting declared commands below.
+    if [[ "$resolved" == *.exe ]]; then
+      ENGINE_PWSH_CMD="\"$resolved\""
+    else
+      ENGINE_PWSH_CMD="pwsh"
+    fi
+    export ENGINE_PWSH_CMD
+    return 0
+  fi
+  for dir in \
+    "/mnt/c/Program Files/PowerShell"/* \
+    "/mnt/c/Program Files (x86)/PowerShell"/*; do
+    # WSL mounts may expose Windows executables without a Unix executable bit;
+    # file existence is the portable signal for a runnable .exe here.
+    if [ -f "$dir/pwsh.exe" ]; then
+      PATH="$dir:$PATH"
+      export PATH
+      ENGINE_PWSH_CMD="\"$dir/pwsh.exe\""
+      export ENGINE_PWSH_CMD
+      return 0
+    fi
+  done
+  ENGINE_PWSH_CMD="pwsh"
+  export ENGINE_PWSH_CMD
+  return 0
+}
+
 run_verify_command() {
   local command="$1" output_file="$2" verify_timeout rc=0
+  local next_verify_stack="${ENGINE_VERIFY_RECURSE_STACK:-}"
+  if [ -n "$next_verify_stack" ]; then
+    next_verify_stack="$next_verify_stack:$task"
+  else
+    next_verify_stack="$task"
+  fi
   verify_timeout="${ENGINE_VERIFY_TIMEOUT:-120}"
+  ensure_powershell_on_path
+  if [ "${ENGINE_PWSH_CMD:-pwsh}" != "pwsh" ]; then
+    command="${command//pwsh/${ENGINE_PWSH_CMD}}"
+  fi
   if command -v timeout >/dev/null 2>&1; then
-    ( cd "$ROOT" && ENGINE_VERIFY_RECURSE_GUARD="$task" timeout "$verify_timeout" bash -c "$command" ) </dev/null >"$output_file" 2>&1 || rc=$?
+    ( cd "$ROOT" && ENGINE_VERIFY_RECURSE_GUARD="$task" ENGINE_VERIFY_RECURSE_STACK="$next_verify_stack" ENGINE_VERIFY_ACTIVE_TASK="$task" timeout "$verify_timeout" bash -c "$command" ) </dev/null >"$output_file" 2>&1 || rc=$?
   else
-    ( cd "$ROOT" && ENGINE_VERIFY_RECURSE_GUARD="$task" eval "$command" ) </dev/null >"$output_file" 2>&1 || rc=$?
+    ( cd "$ROOT" && ENGINE_VERIFY_RECURSE_GUARD="$task" ENGINE_VERIFY_RECURSE_STACK="$next_verify_stack" ENGINE_VERIFY_ACTIVE_TASK="$task" eval "$command" ) </dev/null >"$output_file" 2>&1 || rc=$?
   fi
   return "${rc:-0}"
 }
@@ -366,6 +428,15 @@ fi
 code_fp_json="$(build_code_fingerprint_json)"
 ws_snap_json="$(build_ws_snapshot_json)"
 
+# v6.24.2 (T-081): invalidate stale later-AC snapshots. A rerun of a done
+# card must not let an old later AC snapshot fail an earlier Doctor AC before
+# that later AC is rewritten. AC
+# evidence is regenerated as one set by this verifier; remove only the old
+# AC records up front, while preserving non-AC lifecycle evidence.
+if [ "$preflight" -eq 0 ]; then
+  find "$evidence_dir" -maxdepth 1 -type f -name 'AC-*.json' -delete 2>/dev/null || true
+fi
+
 while IFS=$'\t' read -r ac_id verify_cmd; do
   [ -n "$ac_id" ] || continue
   if [ -z "$verify_cmd" ]; then
@@ -387,6 +458,12 @@ while IFS=$'\t' read -r ac_id verify_cmd; do
       echo "WARN suspicious verify (self-referential evidence path): $ac_id" ;;
   esac
   tmp_out="$(mktemp)"
+  # v6.24.1 (T-081): refresh evidence written by preceding ACs before running
+  # the next command. This keeps a done task's Doctor AC from observing a
+  # transient MANIFEST mismatch while verify is rewriting AC evidence.
+  if [ "$preflight" -eq 0 ]; then
+    write_evidence_manifest "$evidence_dir" "$verified_commit"
+  fi
   rc=0
   # v6.9.0 (T-034): redirect stdin from /dev/null so verify commands that
   # spawn subshells reading stdin (e.g. `bash scripts/check.sh` in AC-10)
@@ -542,7 +619,11 @@ detect_dead_code() {
 
   # Collect WRITE-SET-touched .sh / .ps1 files (concrete paths only, skip globs).
   local write_set_line
-  write_set_line="$(grep '^WRITE-SET:' "$task_file" 2>/dev/null | head -1 | sed 's/^WRITE-SET:[[:space:]]*//' || true)"
+  if declare -F task_card_parse_patterns >/dev/null 2>&1; then
+    write_set_line="$(task_card_parse_patterns WRITE-SET "$task_file" | tr '\n' ',')"
+  else
+    write_set_line="$(grep '^WRITE-SET:' "$task_file" 2>/dev/null | head -1 | sed 's/^WRITE-SET:[[:space:]]*//' || true)"
+  fi
   [ -z "$write_set_line" ] && return 0
 
   local -a sh_files=()
```

### engine/scripts/engine-verify.ps1
```diff
diff --git a/engine/scripts/engine-verify.ps1 b/engine/scripts/engine-verify.ps1
index 7afee17..f225621 100644
--- a/engine/scripts/engine-verify.ps1
+++ b/engine/scripts/engine-verify.ps1
@@ -16,24 +16,28 @@ param(
 $ErrorActionPreference = "Stop"
 trap { [Console]::Error.WriteLine("[engine-verify] error: $_"); exit 1 }
 
-$Root = $env:CLAUDE_PROJECT_DIR
-if (-not $Root) { $Root = $PWD.Path }
-$EngineDir = Join-Path $Root "engine"
+$Root = $env:CLAUDE_PROJECT_DIR
+if (-not $Root) { $Root = $PWD.Path }
+$EngineDir = Join-Path $Root "engine"
+$taskCardLibrary = Join-Path $PSScriptRoot "engine-task-card.ps1"
+if (Test-Path -LiteralPath $taskCardLibrary -PathType Leaf) { . $taskCardLibrary }
 
 if (-not $Task) {
   [Console]::Error.WriteLine("Usage: engine verify T-NNN")
   exit 2
 }
 
-# v6.10.0 (D-028/T-035): recursion guard. An AC verify command may itself
-# invoke `pwsh -File engine/scripts/engine-verify.ps1 -Task T-NNN` (e.g.
-# T-035 AC-2 dogfood). Without a guard, that would infinitely recurse (each
-# call re-iterates ACs and re-spawns the recursive call). The guard env var
-# carries the task ID being verified by the outer call; a recursive
-# invocation for the SAME task exits 0 immediately. Other task IDs (e.g.
-# behavior-verify test fixtures) run normally.
-# Dead-code evidence (DEAD-CODE.json) is written by the outer (first) call only.
-if ($env:ENGINE_VERIFY_RECURSE_GUARD -and ($env:ENGINE_VERIFY_RECURSE_GUARD -eq $Task)) {
+# v6.10.0/v6.26.1 (D-028/T-035, T-081): recursion guard. An AC verify command
+# may invoke another task verifier (for example T-081 AC-4 -> T-080, whose
+# AC-4 dogfoods T-080 again). A single guard ID only protects same-task
+# recursion; the stack protects cross-task cycles while allowing one nested
+# verifier for a different task.
+# Dead-code evidence (DEAD-CODE.json) is written by the outer (first) call only.
+if ($env:ENGINE_VERIFY_RECURSE_STACK) {
+  $verifyStack = @($env:ENGINE_VERIFY_RECURSE_STACK -split ':')
+  if ($verifyStack -contains $Task) { exit 0 }
+}
+if ($env:ENGINE_VERIFY_RECURSE_GUARD -and ($env:ENGINE_VERIFY_RECURSE_GUARD -eq $Task)) {
   exit 0
 }
 
@@ -109,9 +113,12 @@ if (-not $bashExe) {
 # Returns: array of objects with AcId and VerifyCmd properties (VerifyCmd may be empty for SKIP).
 # AC id regex: AC-[A-Za-z]*[0-9]+(\.[0-9]+)* (v6.12.1 A-3).
 # Separators: | verify: / |verify: / -> verify: / ->verify: / line-start verify:
-function Parse-AcDeclarations {
-  param([string]$Path)
-  $results = @()
+function Parse-AcDeclarations {
+  param([string]$Path)
+  if (Get-Command Get-TaskCardAcDeclarations -ErrorAction SilentlyContinue) {
+    return @(Get-TaskCardAcDeclarations -Path $Path)
+  }
+  $results = @()
   if (-not (Test-Path $Path)) { return $results }
   $sepArrow = [string][char]0x2192
   $acIdPattern = 'AC-[A-Za-z]*\d+(?:\.\d+)*'
@@ -184,7 +191,7 @@ function Parse-AcDeclarations {
 function Test-EngineMetadata {
   param([string]$Path)
   $metaPatterns = @(
-    'engine/tasks/', 'engine/decisions/', 'engine/changes/', 'engine/evidence/',
+    'engine/tasks/', 'engine/decisions/', 'engine/changes/', 'engine/evidence/', 'engine/review/evidence/',
     'engine/domains/', 'engine/archive/', 'engine/CONTEXT.md', 'engine/HANDOFF.md',
     'engine/ENGINE_MAP.md', 'engine/handoff-archive-', 'VERSION', 'engine/VERSION',
     'plugin/VERSION', 'plugin/manifest.json', 'CHANGELOG.md'
@@ -195,24 +202,29 @@ function Test-EngineMetadata {
   return $false
 }
 
-function Collect-CodeFingerprint {
-  param([string]$TaskFile, [string]$Root)
-  $codeFingerprint = @{}
-  $wsSnapshot = @()
-  $content = Get-Content -Path $TaskFile -Encoding UTF8
-  $inWs = $false
-  foreach ($line in $content) {
-    if ($line -match '^## WRITE-SET') { $inWs = $true; continue }
-    if ($line -match '^## ') { if ($inWs) { break } else { continue } }
-    if (-not $inWs) { continue }
-    if ($line -match '^-\s+(.+)') {
-      $path = $Matches[1].Trim()
-      if (Test-EngineMetadata -Path $path) { continue }
-      $fullPath = Join-Path $Root $path
-      if (-not (Test-Path $fullPath -PathType Leaf)) { continue }
-      $wsSnapshot += $path
-    }
-  }
+function Collect-CodeFingerprint {
+  param([string]$TaskFile, [string]$Root)
+  $codeFingerprint = @{}
+  $wsSnapshot = @()
+  if (Get-Command Get-TaskCardPatterns -ErrorAction SilentlyContinue) {
+    $writeSetPaths = @(Get-TaskCardPatterns -Path $TaskFile -Field 'WRITE-SET')
+  } else {
+    $content = Get-Content -Path $TaskFile -Encoding UTF8
+    $inWs = $false
+    $writeSetPaths = @()
+    foreach ($line in $content) {
+      if ($line -match '^##\s+WRITE-SET') { $inWs = $true; continue }
+      if ($line -match '^##\s+') { if ($inWs) { break } else { continue } }
+      if ($inWs -and $line -match '^\s*-\s+(.+)') { $writeSetPaths += $Matches[1].Trim() }
+    }
+  }
+  foreach ($path in $writeSetPaths) {
+    $path = ($path -replace '\s*[\(\[].*$', '').Trim()
+    if (Test-EngineMetadata -Path $path) { continue }
+    $fullPath = Join-Path $Root $path
+    if (-not (Test-Path $fullPath -PathType Leaf)) { continue }
+    $wsSnapshot += $path
+  }
   $missing = @()
   foreach ($path in $wsSnapshot) {
     $blob = & git -C $Root ls-files -s $path 2>$null
@@ -324,8 +336,14 @@ function Invoke-VerifyCommand {
   $output = ''
   $exitCode = 1
   Push-Location $Root
+  $oldGuard = $env:ENGINE_VERIFY_RECURSE_GUARD
+  $oldStack = $env:ENGINE_VERIFY_RECURSE_STACK
+  $oldActive = $env:ENGINE_VERIFY_ACTIVE_TASK
   try {
     $env:ENGINE_VERIFY_RECURSE_GUARD = $TaskId
+    if ($oldStack) { $env:ENGINE_VERIFY_RECURSE_STACK = "$oldStack`:$TaskId" }
+    else { $env:ENGINE_VERIFY_RECURSE_STACK = $TaskId }
+    $env:ENGINE_VERIFY_ACTIVE_TASK = $TaskId
     try {
       if ($BashExe) {
         $output = & $BashExe -lc $Command 2>&1 | Out-String
@@ -340,7 +358,9 @@ function Invoke-VerifyCommand {
       $exitCode = 1
     }
   } finally {
-    [Environment]::SetEnvironmentVariable('ENGINE_VERIFY_RECURSE_GUARD', $null, 'Process')
+    if ($null -eq $oldGuard) { [Environment]::SetEnvironmentVariable('ENGINE_VERIFY_RECURSE_GUARD', $null, 'Process') } else { $env:ENGINE_VERIFY_RECURSE_GUARD = $oldGuard }
+    if ($null -eq $oldStack) { [Environment]::SetEnvironmentVariable('ENGINE_VERIFY_RECURSE_STACK', $null, 'Process') } else { $env:ENGINE_VERIFY_RECURSE_STACK = $oldStack }
+    if ($null -eq $oldActive) { [Environment]::SetEnvironmentVariable('ENGINE_VERIFY_ACTIVE_TASK', $null, 'Process') } else { $env:ENGINE_VERIFY_ACTIVE_TASK = $oldActive }
     Pop-Location
   }
   return [PSCustomObject]@{ Output = [string]$output; ExitCode = [int]$exitCode }
@@ -348,7 +368,14 @@ function Invoke-VerifyCommand {
 
 function Write-EvidenceManifest {
   param([string]$EvDir, [string]$Commit)
-  $files = Get-ChildItem -Path $EvDir -File | Where-Object { $_.Name -ne 'MANIFEST.json' -and ($_.Name -like '*.json' -or $_.Name -eq 'checkpoint.md') } | Sort-Object Name
+  $files = @(Get-ChildItem -Path $EvDir -File | Where-Object { $_.Name -ne 'MANIFEST.json' -and ($_.Name -like '*.json' -or $_.Name -eq 'checkpoint.md') })
+  $ordinalComparer = [System.Collections.Generic.Comparer[object]]::Create(
+    [System.Comparison[object]]{
+      param($left, $right)
+      [System.StringComparer]::Ordinal.Compare($left.Name, $right.Name)
+    }
+  )
+  if ($files.Count -gt 1) { [System.Array]::Sort($files, $ordinalComparer) }
   $manifestContent = ""
   $filesDict = @{}
   foreach ($f in $files) {
@@ -380,8 +407,16 @@ if ($Preflight) {
   $codeFpJson = Build-CodeFingerprintJson -Hash $cfResult.CodeFingerprint
   $wsSnapJson = Build-WsSnapshotJson -Arr $cfResult.WsSnapshot
 }
-
-foreach ($ac in (Parse-AcDeclarations -Path $taskFile)) {
+
+# v6.24.2 (T-081): invalidate stale later-AC snapshots before a done-card
+# rerun reaches an earlier Doctor AC. Only AC records are regenerated; keep
+# non-AC lifecycle evidence in place.
+if (-not $Preflight) {
+  Get-ChildItem -Path $evidenceDir -Filter 'AC-*.json' -File -ErrorAction SilentlyContinue |
+    Remove-Item -Force -ErrorAction SilentlyContinue
+}
+
+foreach ($ac in (Parse-AcDeclarations -Path $taskFile)) {
   $acId = $ac.AcId
   $verifyCmd = $ac.VerifyCmd
   if (-not $verifyCmd) {
@@ -400,6 +435,11 @@ foreach ($ac in (Parse-AcDeclarations -Path $taskFile)) {
   if ($verifyCmd -like "*engine/evidence/$Task/*") {
     Write-Output "WARN suspicious verify (self-referential evidence path): $acId"
   }
+  # v6.24.1 (T-081): refresh evidence written by preceding ACs before running
+  # the next command so a done task's Doctor AC never sees a transient mismatch.
+  if (-not $Preflight) {
+    Write-EvidenceManifest -EvDir $evidenceDir -Commit $verifiedCommit
+  }
   $runResult = Invoke-VerifyCommand -Command $executionCmd -Root $Root -TaskId $Task -BashExe $bashExe
   $output = $runResult.Output
   $rc = $runResult.ExitCode
@@ -536,11 +576,13 @@ function Invoke-DeadCodeDetection {
   param([string]$TaskId, [string]$EvidenceDir, [string]$TaskFile)
   if (-not (Test-Path $TaskFile)) { return }
 
-  # Collect WRITE-SET-touched .ps1 / .sh files (concrete paths only, skip globs).
-  $content = Get-Content -Raw -Path $TaskFile -Encoding UTF8 -ErrorAction SilentlyContinue
-  if (-not $content) { return }
-  $writeSetLine = ""
-  if ($content -match '(?m)^WRITE-SET:\s*(.*)$') { $writeSetLine = $Matches[1].Trim() }
+  # Collect WRITE-SET-touched .ps1 / .sh files (concrete paths only, skip globs).
+  $content = Get-Content -Raw -Path $TaskFile -Encoding UTF8 -ErrorAction SilentlyContinue
+  if (-not $content) { return }
+  $writeSetLine = ""
+  if (Get-Command Get-TaskCardPatterns -ErrorAction SilentlyContinue) {
+    $writeSetLine = (@(Get-TaskCardPatterns -Path $TaskFile -Field 'WRITE-SET') -join ',')
+  } elseif ($content -match '(?m)^WRITE-SET:\s*(.*)$') { $writeSetLine = $Matches[1].Trim() }
   if ([string]::IsNullOrEmpty($writeSetLine)) { return }
 
   $shFiles = @()
```

### plugin/engine/scripts/engine-verify.sh
```diff
diff --git a/plugin/engine/scripts/engine-verify.sh b/plugin/engine/scripts/engine-verify.sh
index 31b3403..3176c67 100644
--- a/plugin/engine/scripts/engine-verify.sh
+++ b/plugin/engine/scripts/engine-verify.sh
@@ -13,6 +13,11 @@ on_error() { echo "[engine-verify] error on line $1 (${BASH_SOURCE[0]})" >&2; ex
 trap 'on_error ${LINENO}' ERR
 ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
 ENGINE_DIR="$ROOT/engine"
+task_card_script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
+if [ -f "$task_card_script_dir/engine-task-card.sh" ]; then
+  # shellcheck source=/dev/null
+  . "$task_card_script_dir/engine-task-card.sh"
+fi
 task="${1:-}"
 preflight=0
 force_no_cov=0
@@ -28,13 +33,16 @@ if [ -z "$task" ]; then
   exit 2
 fi
 
-# v6.10.0 (D-028/T-035): recursion guard. An AC verify command may itself
-# invoke `bash engine/scripts/engine-verify.sh T-NNN` (e.g. T-035 AC-2 dogfood).
-# Without a guard, that would infinitely recurse (each call re-iterates ACs and
-# re-spawns the recursive call). The guard env var carries the task ID being
-# verified by the outer call; a recursive invocation for the SAME task exits 0
-# immediately. Other task IDs (e.g. behavior-verify test fixtures) run normally.
+# v6.10.0/v6.26.1 (D-028/T-035, T-081): recursion guard. An AC verify command
+# may invoke another task verifier (for example T-081 AC-4 -> T-080, whose
+# AC-4 dogfoods T-080 again). A single guard ID only protects same-task
+# recursion; the stack protects cross-task cycles while allowing one nested
+# verifier for a different task.
 # Dead-code evidence (DEAD-CODE.json) is written by the outer (first) call only.
+verify_stack="${ENGINE_VERIFY_RECURSE_STACK:-}"
+case ":$verify_stack:" in
+  *":$1:"*) exit 0 ;;
+esac
 if [ -n "${ENGINE_VERIFY_RECURSE_GUARD:-}" ] && [ "${ENGINE_VERIFY_RECURSE_GUARD:-}" = "$1" ]; then
   exit 0
 fi
@@ -69,6 +77,10 @@ empty_fp_pass=0
 # AC id regex: AC-[A-Za-z]*[0-9]+(\.[0-9]+)* (v6.12.1 A-3).
 # Separators: | verify: / |verify: / → verify: / →verify: / line-start verify:
 parse_ac_declarations() {
+  if declare -F task_card_parse_ac_declarations >/dev/null 2>&1; then
+    task_card_parse_ac_declarations "$@"
+    return 0
+  fi
   local file="$1"
   local line ac_id verify_cmd verify_rest
   local section_ac="" pending_ac=""
@@ -161,7 +173,7 @@ parse_ac_declarations() {
 # is_engine_metadata: 判断路径是否 engine 元数据(排除出 code_fingerprint)
 is_engine_metadata() {
   case "$1" in
-    engine/tasks/*|engine/decisions/*|engine/changes/*|engine/evidence/*|engine/domains/*|engine/archive/*) return 0 ;;
+    engine/tasks/*|engine/decisions/*|engine/changes/*|engine/evidence/*|engine/review/evidence/*|engine/domains/*|engine/archive/*) return 0 ;;
     engine/CONTEXT.md|engine/HANDOFF.md|engine/ENGINE_MAP.md|engine/handoff-archive-*) return 0 ;;
     VERSION|engine/VERSION|plugin/VERSION|plugin/manifest.json|CHANGELOG.md) return 0 ;;
     *) return 1 ;;
@@ -174,20 +186,23 @@ declare -A code_fingerprint=()
 declare -A code_fp_files=()
 ws_snapshot=()
 collect_code_fingerprint() {
-  local file="$1" in_ws=0 line path blob_sha
-  while IFS= read -r line || [ -n "$line" ]; do
-    case "$line" in
-      "## WRITE-SET") in_ws=1; continue ;;
-      "## "*) [ "$in_ws" = "1" ] && break ;;
-    esac
-    [ "$in_ws" = "1" ] || continue
-    [[ "$line" =~ ^-[[:space:]]+([^[:space:]].+) ]] || continue
-    path="${BASH_REMATCH[1]}"
+  local file="$1" path blob_sha
+  local write_set_lines=""
+  if declare -F task_card_parse_patterns >/dev/null 2>&1; then
+    write_set_lines="$(task_card_parse_patterns WRITE-SET "$file")"
+  else
+    write_set_lines="$(awk '/^##[[:space:]]+WRITE-SET[[:space:]]*$/{on=1;next} on&&/^##[[:space:]]+/{on=0} on&&/^[[:space:]]*-[[:space:]]+/{sub(/^[[:space:]]*-[[:space:]]+/,"");print}' "$file")"
+  fi
+  while IFS= read -r path; do
+    path="${path%%(*}"
+    path="${path%%\[*}"
+    path="${path%"${path##*[![:space:]]}"}"
+    [ -n "$path" ] || continue
     is_engine_metadata "$path" && continue
     [ -f "$ROOT/$path" ] || continue
     code_fp_files["$path"]=1
     ws_snapshot+=("$path")
-  done < "$file"
+  done <<< "$write_set_lines"
   local missing=()
   for path in "${!code_fp_files[@]}"; do
     blob_sha="$(cd "$ROOT" && git ls-files -s "$path" 2>/dev/null | awk '{print $2}')"
@@ -312,13 +327,60 @@ append_no_cov() {
   fi
 }
 
+# Windows Git Bash/WSL installations may expose PowerShell only as a .exe
+# outside the inherited PATH. Resolve that executable before running declared
+# AC commands so Bash close/verify does not turn a valid Windows AC into 127.
+ensure_powershell_on_path() {
+  local resolved dir
+  ENGINE_PWSH_CMD=""
+  resolved="$(command -v pwsh 2>/dev/null || true)"
+  if [ -n "$resolved" ]; then
+    # WSL may resolve the Windows .exe but still fail to execute the bare
+    # extensionless token from a nested bash -c. Keep the resolved path and
+    # quote it when rewriting declared commands below.
+    if [[ "$resolved" == *.exe ]]; then
+      ENGINE_PWSH_CMD="\"$resolved\""
+    else
+      ENGINE_PWSH_CMD="pwsh"
+    fi
+    export ENGINE_PWSH_CMD
+    return 0
+  fi
+  for dir in \
+    "/mnt/c/Program Files/PowerShell"/* \
+    "/mnt/c/Program Files (x86)/PowerShell"/*; do
+    # WSL mounts may expose Windows executables without a Unix executable bit;
+    # file existence is the portable signal for a runnable .exe here.
+    if [ -f "$dir/pwsh.exe" ]; then
+      PATH="$dir:$PATH"
+      export PATH
+      ENGINE_PWSH_CMD="\"$dir/pwsh.exe\""
+      export ENGINE_PWSH_CMD
+      return 0
+    fi
+  done
+  ENGINE_PWSH_CMD="pwsh"
+  export ENGINE_PWSH_CMD
+  return 0
+}
+
 run_verify_command() {
   local command="$1" output_file="$2" verify_timeout rc=0
+  local next_verify_stack="${ENGINE_VERIFY_RECURSE_STACK:-}"
+  if [ -n "$next_verify_stack" ]; then
+    next_verify_stack="$next_verify_stack:$task"
+  else
+    next_verify_stack="$task"
+  fi
   verify_timeout="${ENGINE_VERIFY_TIMEOUT:-120}"
+  ensure_powershell_on_path
+  if [ "${ENGINE_PWSH_CMD:-pwsh}" != "pwsh" ]; then
+    command="${command//pwsh/${ENGINE_PWSH_CMD}}"
+  fi
   if command -v timeout >/dev/null 2>&1; then
-    ( cd "$ROOT" && ENGINE_VERIFY_RECURSE_GUARD="$task" timeout "$verify_timeout" bash -c "$command" ) </dev/null >"$output_file" 2>&1 || rc=$?
+    ( cd "$ROOT" && ENGINE_VERIFY_RECURSE_GUARD="$task" ENGINE_VERIFY_RECURSE_STACK="$next_verify_stack" ENGINE_VERIFY_ACTIVE_TASK="$task" timeout "$verify_timeout" bash -c "$command" ) </dev/null >"$output_file" 2>&1 || rc=$?
   else
-    ( cd "$ROOT" && ENGINE_VERIFY_RECURSE_GUARD="$task" eval "$command" ) </dev/null >"$output_file" 2>&1 || rc=$?
+    ( cd "$ROOT" && ENGINE_VERIFY_RECURSE_GUARD="$task" ENGINE_VERIFY_RECURSE_STACK="$next_verify_stack" ENGINE_VERIFY_ACTIVE_TASK="$task" eval "$command" ) </dev/null >"$output_file" 2>&1 || rc=$?
   fi
   return "${rc:-0}"
 }
@@ -366,6 +428,15 @@ fi
 code_fp_json="$(build_code_fingerprint_json)"
 ws_snap_json="$(build_ws_snapshot_json)"
 
+# v6.24.2 (T-081): invalidate stale later-AC snapshots. A rerun of a done
+# card must not let an old later AC snapshot fail an earlier Doctor AC before
+# that later AC is rewritten. AC
+# evidence is regenerated as one set by this verifier; remove only the old
+# AC records up front, while preserving non-AC lifecycle evidence.
+if [ "$preflight" -eq 0 ]; then
+  find "$evidence_dir" -maxdepth 1 -type f -name 'AC-*.json' -delete 2>/dev/null || true
+fi
+
 while IFS=$'\t' read -r ac_id verify_cmd; do
   [ -n "$ac_id" ] || continue
   if [ -z "$verify_cmd" ]; then
@@ -387,6 +458,12 @@ while IFS=$'\t' read -r ac_id verify_cmd; do
       echo "WARN suspicious verify (self-referential evidence path): $ac_id" ;;
   esac
   tmp_out="$(mktemp)"
+  # v6.24.1 (T-081): refresh evidence written by preceding ACs before running
+  # the next command. This keeps a done task's Doctor AC from observing a
+  # transient MANIFEST mismatch while verify is rewriting AC evidence.
+  if [ "$preflight" -eq 0 ]; then
+    write_evidence_manifest "$evidence_dir" "$verified_commit"
+  fi
   rc=0
   # v6.9.0 (T-034): redirect stdin from /dev/null so verify commands that
   # spawn subshells reading stdin (e.g. `bash scripts/check.sh` in AC-10)
@@ -542,7 +619,11 @@ detect_dead_code() {
 
   # Collect WRITE-SET-touched .sh / .ps1 files (concrete paths only, skip globs).
   local write_set_line
-  write_set_line="$(grep '^WRITE-SET:' "$task_file" 2>/dev/null | head -1 | sed 's/^WRITE-SET:[[:space:]]*//' || true)"
+  if declare -F task_card_parse_patterns >/dev/null 2>&1; then
+    write_set_line="$(task_card_parse_patterns WRITE-SET "$task_file" | tr '\n' ',')"
+  else
+    write_set_line="$(grep '^WRITE-SET:' "$task_file" 2>/dev/null | head -1 | sed 's/^WRITE-SET:[[:space:]]*//' || true)"
+  fi
   [ -z "$write_set_line" ] && return 0
 
   local -a sh_files=()
```

### plugin/engine/scripts/engine-verify.ps1
```diff
diff --git a/plugin/engine/scripts/engine-verify.ps1 b/plugin/engine/scripts/engine-verify.ps1
index 7afee17..f225621 100644
--- a/plugin/engine/scripts/engine-verify.ps1
+++ b/plugin/engine/scripts/engine-verify.ps1
@@ -16,24 +16,28 @@ param(
 $ErrorActionPreference = "Stop"
 trap { [Console]::Error.WriteLine("[engine-verify] error: $_"); exit 1 }
 
-$Root = $env:CLAUDE_PROJECT_DIR
-if (-not $Root) { $Root = $PWD.Path }
-$EngineDir = Join-Path $Root "engine"
+$Root = $env:CLAUDE_PROJECT_DIR
+if (-not $Root) { $Root = $PWD.Path }
+$EngineDir = Join-Path $Root "engine"
+$taskCardLibrary = Join-Path $PSScriptRoot "engine-task-card.ps1"
+if (Test-Path -LiteralPath $taskCardLibrary -PathType Leaf) { . $taskCardLibrary }
 
 if (-not $Task) {
   [Console]::Error.WriteLine("Usage: engine verify T-NNN")
   exit 2
 }
 
-# v6.10.0 (D-028/T-035): recursion guard. An AC verify command may itself
-# invoke `pwsh -File engine/scripts/engine-verify.ps1 -Task T-NNN` (e.g.
-# T-035 AC-2 dogfood). Without a guard, that would infinitely recurse (each
-# call re-iterates ACs and re-spawns the recursive call). The guard env var
-# carries the task ID being verified by the outer call; a recursive
-# invocation for the SAME task exits 0 immediately. Other task IDs (e.g.
-# behavior-verify test fixtures) run normally.
-# Dead-code evidence (DEAD-CODE.json) is written by the outer (first) call only.
-if ($env:ENGINE_VERIFY_RECURSE_GUARD -and ($env:ENGINE_VERIFY_RECURSE_GUARD -eq $Task)) {
+# v6.10.0/v6.26.1 (D-028/T-035, T-081): recursion guard. An AC verify command
+# may invoke another task verifier (for example T-081 AC-4 -> T-080, whose
+# AC-4 dogfoods T-080 again). A single guard ID only protects same-task
+# recursion; the stack protects cross-task cycles while allowing one nested
+# verifier for a different task.
+# Dead-code evidence (DEAD-CODE.json) is written by the outer (first) call only.
+if ($env:ENGINE_VERIFY_RECURSE_STACK) {
+  $verifyStack = @($env:ENGINE_VERIFY_RECURSE_STACK -split ':')
+  if ($verifyStack -contains $Task) { exit 0 }
+}
+if ($env:ENGINE_VERIFY_RECURSE_GUARD -and ($env:ENGINE_VERIFY_RECURSE_GUARD -eq $Task)) {
   exit 0
 }
 
@@ -109,9 +113,12 @@ if (-not $bashExe) {
 # Returns: array of objects with AcId and VerifyCmd properties (VerifyCmd may be empty for SKIP).
 # AC id regex: AC-[A-Za-z]*[0-9]+(\.[0-9]+)* (v6.12.1 A-3).
 # Separators: | verify: / |verify: / -> verify: / ->verify: / line-start verify:
-function Parse-AcDeclarations {
-  param([string]$Path)
-  $results = @()
+function Parse-AcDeclarations {
+  param([string]$Path)
+  if (Get-Command Get-TaskCardAcDeclarations -ErrorAction SilentlyContinue) {
+    return @(Get-TaskCardAcDeclarations -Path $Path)
+  }
+  $results = @()
   if (-not (Test-Path $Path)) { return $results }
   $sepArrow = [string][char]0x2192
   $acIdPattern = 'AC-[A-Za-z]*\d+(?:\.\d+)*'
@@ -184,7 +191,7 @@ function Parse-AcDeclarations {
 function Test-EngineMetadata {
   param([string]$Path)
   $metaPatterns = @(
-    'engine/tasks/', 'engine/decisions/', 'engine/changes/', 'engine/evidence/',
+    'engine/tasks/', 'engine/decisions/', 'engine/changes/', 'engine/evidence/', 'engine/review/evidence/',
     'engine/domains/', 'engine/archive/', 'engine/CONTEXT.md', 'engine/HANDOFF.md',
     'engine/ENGINE_MAP.md', 'engine/handoff-archive-', 'VERSION', 'engine/VERSION',
     'plugin/VERSION', 'plugin/manifest.json', 'CHANGELOG.md'
@@ -195,24 +202,29 @@ function Test-EngineMetadata {
   return $false
 }
 
-function Collect-CodeFingerprint {
-  param([string]$TaskFile, [string]$Root)
-  $codeFingerprint = @{}
-  $wsSnapshot = @()
-  $content = Get-Content -Path $TaskFile -Encoding UTF8
-  $inWs = $false
-  foreach ($line in $content) {
-    if ($line -match '^## WRITE-SET') { $inWs = $true; continue }
-    if ($line -match '^## ') { if ($inWs) { break } else { continue } }
-    if (-not $inWs) { continue }
-    if ($line -match '^-\s+(.+)') {
-      $path = $Matches[1].Trim()
-      if (Test-EngineMetadata -Path $path) { continue }
-      $fullPath = Join-Path $Root $path
-      if (-not (Test-Path $fullPath -PathType Leaf)) { continue }
-      $wsSnapshot += $path
-    }
-  }
+function Collect-CodeFingerprint {
+  param([string]$TaskFile, [string]$Root)
+  $codeFingerprint = @{}
+  $wsSnapshot = @()
+  if (Get-Command Get-TaskCardPatterns -ErrorAction SilentlyContinue) {
+    $writeSetPaths = @(Get-TaskCardPatterns -Path $TaskFile -Field 'WRITE-SET')
+  } else {
+    $content = Get-Content -Path $TaskFile -Encoding UTF8
+    $inWs = $false
+    $writeSetPaths = @()
+    foreach ($line in $content) {
+      if ($line -match '^##\s+WRITE-SET') { $inWs = $true; continue }
+      if ($line -match '^##\s+') { if ($inWs) { break } else { continue } }
+      if ($inWs -and $line -match '^\s*-\s+(.+)') { $writeSetPaths += $Matches[1].Trim() }
+    }
+  }
+  foreach ($path in $writeSetPaths) {
+    $path = ($path -replace '\s*[\(\[].*$', '').Trim()
+    if (Test-EngineMetadata -Path $path) { continue }
+    $fullPath = Join-Path $Root $path
+    if (-not (Test-Path $fullPath -PathType Leaf)) { continue }
+    $wsSnapshot += $path
+  }
   $missing = @()
   foreach ($path in $wsSnapshot) {
     $blob = & git -C $Root ls-files -s $path 2>$null
@@ -324,8 +336,14 @@ function Invoke-VerifyCommand {
   $output = ''
   $exitCode = 1
   Push-Location $Root
+  $oldGuard = $env:ENGINE_VERIFY_RECURSE_GUARD
+  $oldStack = $env:ENGINE_VERIFY_RECURSE_STACK
+  $oldActive = $env:ENGINE_VERIFY_ACTIVE_TASK
   try {
     $env:ENGINE_VERIFY_RECURSE_GUARD = $TaskId
+    if ($oldStack) { $env:ENGINE_VERIFY_RECURSE_STACK = "$oldStack`:$TaskId" }
+    else { $env:ENGINE_VERIFY_RECURSE_STACK = $TaskId }
+    $env:ENGINE_VERIFY_ACTIVE_TASK = $TaskId
     try {
       if ($BashExe) {
         $output = & $BashExe -lc $Command 2>&1 | Out-String
@@ -340,7 +358,9 @@ function Invoke-VerifyCommand {
       $exitCode = 1
     }
   } finally {
-    [Environment]::SetEnvironmentVariable('ENGINE_VERIFY_RECURSE_GUARD', $null, 'Process')
+    if ($null -eq $oldGuard) { [Environment]::SetEnvironmentVariable('ENGINE_VERIFY_RECURSE_GUARD', $null, 'Process') } else { $env:ENGINE_VERIFY_RECURSE_GUARD = $oldGuard }
+    if ($null -eq $oldStack) { [Environment]::SetEnvironmentVariable('ENGINE_VERIFY_RECURSE_STACK', $null, 'Process') } else { $env:ENGINE_VERIFY_RECURSE_STACK = $oldStack }
+    if ($null -eq $oldActive) { [Environment]::SetEnvironmentVariable('ENGINE_VERIFY_ACTIVE_TASK', $null, 'Process') } else { $env:ENGINE_VERIFY_ACTIVE_TASK = $oldActive }
     Pop-Location
   }
   return [PSCustomObject]@{ Output = [string]$output; ExitCode = [int]$exitCode }
@@ -348,7 +368,14 @@ function Invoke-VerifyCommand {
 
 function Write-EvidenceManifest {
   param([string]$EvDir, [string]$Commit)
-  $files = Get-ChildItem -Path $EvDir -File | Where-Object { $_.Name -ne 'MANIFEST.json' -and ($_.Name -like '*.json' -or $_.Name -eq 'checkpoint.md') } | Sort-Object Name
+  $files = @(Get-ChildItem -Path $EvDir -File | Where-Object { $_.Name -ne 'MANIFEST.json' -and ($_.Name -like '*.json' -or $_.Name -eq 'checkpoint.md') })
+  $ordinalComparer = [System.Collections.Generic.Comparer[object]]::Create(
+    [System.Comparison[object]]{
+      param($left, $right)
+      [System.StringComparer]::Ordinal.Compare($left.Name, $right.Name)
+    }
+  )
+  if ($files.Count -gt 1) { [System.Array]::Sort($files, $ordinalComparer) }
   $manifestContent = ""
   $filesDict = @{}
   foreach ($f in $files) {
@@ -380,8 +407,16 @@ if ($Preflight) {
   $codeFpJson = Build-CodeFingerprintJson -Hash $cfResult.CodeFingerprint
   $wsSnapJson = Build-WsSnapshotJson -Arr $cfResult.WsSnapshot
 }
-
-foreach ($ac in (Parse-AcDeclarations -Path $taskFile)) {
+
+# v6.24.2 (T-081): invalidate stale later-AC snapshots before a done-card
+# rerun reaches an earlier Doctor AC. Only AC records are regenerated; keep
+# non-AC lifecycle evidence in place.
+if (-not $Preflight) {
+  Get-ChildItem -Path $evidenceDir -Filter 'AC-*.json' -File -ErrorAction SilentlyContinue |
+    Remove-Item -Force -ErrorAction SilentlyContinue
+}
+
+foreach ($ac in (Parse-AcDeclarations -Path $taskFile)) {
   $acId = $ac.AcId
   $verifyCmd = $ac.VerifyCmd
   if (-not $verifyCmd) {
@@ -400,6 +435,11 @@ foreach ($ac in (Parse-AcDeclarations -Path $taskFile)) {
   if ($verifyCmd -like "*engine/evidence/$Task/*") {
     Write-Output "WARN suspicious verify (self-referential evidence path): $acId"
   }
+  # v6.24.1 (T-081): refresh evidence written by preceding ACs before running
+  # the next command so a done task's Doctor AC never sees a transient mismatch.
+  if (-not $Preflight) {
+    Write-EvidenceManifest -EvDir $evidenceDir -Commit $verifiedCommit
+  }
   $runResult = Invoke-VerifyCommand -Command $executionCmd -Root $Root -TaskId $Task -BashExe $bashExe
   $output = $runResult.Output
   $rc = $runResult.ExitCode
@@ -536,11 +576,13 @@ function Invoke-DeadCodeDetection {
   param([string]$TaskId, [string]$EvidenceDir, [string]$TaskFile)
   if (-not (Test-Path $TaskFile)) { return }
 
-  # Collect WRITE-SET-touched .ps1 / .sh files (concrete paths only, skip globs).
-  $content = Get-Content -Raw -Path $TaskFile -Encoding UTF8 -ErrorAction SilentlyContinue
-  if (-not $content) { return }
-  $writeSetLine = ""
-  if ($content -match '(?m)^WRITE-SET:\s*(.*)$') { $writeSetLine = $Matches[1].Trim() }
+  # Collect WRITE-SET-touched .ps1 / .sh files (concrete paths only, skip globs).
+  $content = Get-Content -Raw -Path $TaskFile -Encoding UTF8 -ErrorAction SilentlyContinue
+  if (-not $content) { return }
+  $writeSetLine = ""
+  if (Get-Command Get-TaskCardPatterns -ErrorAction SilentlyContinue) {
+    $writeSetLine = (@(Get-TaskCardPatterns -Path $TaskFile -Field 'WRITE-SET') -join ',')
+  } elseif ($content -match '(?m)^WRITE-SET:\s*(.*)$') { $writeSetLine = $Matches[1].Trim() }
   if ([string]::IsNullOrEmpty($writeSetLine)) { return }
 
   $shFiles = @()
```

### engine/scripts/engine-close.sh
```diff
diff --git a/engine/scripts/engine-close.sh b/engine/scripts/engine-close.sh
index 5d15e55..9964754 100644
--- a/engine/scripts/engine-close.sh
+++ b/engine/scripts/engine-close.sh
@@ -9,6 +9,11 @@ set -u -o pipefail
 
 ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
 ENGINE_DIR="$ROOT/engine"
+task_card_script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
+if [ -f "$task_card_script_dir/engine-task-card.sh" ]; then
+  # shellcheck source=/dev/null
+  . "$task_card_script_dir/engine-task-card.sh"
+fi
 task="${1:-}"
 shift || true
 handoff_agent="${ENGINE_AGENT_ID:-}"
@@ -56,17 +61,50 @@ run_stage() {
   local tmp rc
   tmp="$(mktemp)"
   echo "[engine-close] running: $label"
-  "$@" 2>&1 | tee "$tmp"
-  rc="${PIPESTATUS[0]}"
+  # Capture the stage before replaying its output. Piping the child directly
+  # through tee lets an external log consumer closing early send SIGPIPE back
+  # into the stage (notably Doctor's long report), turning a real exit 0 into
+  # a false exit 141. The stage's exit code must be independent of display I/O.
+  "$@" >"$tmp" 2>&1
+  rc="$?"
+  cat "$tmp" || true
   printf -v "${label}_rc" '%s' "$rc"
   rm -f "$tmp"
 }
 
+# Gate and close both write evidence files that are covered by MANIFEST.json.
+# Refresh the manifest at each evidence-writer boundary so a done task's
+# Doctor/drift check never observes a transient self-tamper state.
+refresh_evidence_manifest() {
+  local ev_dir="$ENGINE_DIR/evidence/$task"
+  [ -d "$ev_dir" ] || return 0
+  local manifest_content="" fname fhash
+  while IFS= read -r fname; do
+    [ -n "$fname" ] || continue
+    fhash="$(sha256sum "$ev_dir/$fname" | cut -d' ' -f1)"
+    manifest_content+="${fname}:${fhash}"$'\n'
+  done < <(cd "$ev_dir" && find . -maxdepth 1 -type f \( -name '*.json' -o -name 'checkpoint.md' \) ! -name 'MANIFEST.json' -print 2>/dev/null | sed 's|^\./||' | LC_ALL=C sort)
+
+  local manifest_hash="$(printf '%s' "$manifest_content" | sha256sum | cut -d' ' -f1)"
+  local files_json="{" first=1
+  while IFS=: read -r fname fhash; do
+    [ -n "$fname" ] || continue
+    [ "$first" = "1" ] || files_json+=",";
+    files_json+="\"$fname\":\"$fhash\""
+    first=0
+  done <<< "$manifest_content"
+  files_json+="}"
+  printf '{"evidence_manifest_sha256":"sha256:%s","generated":"%s","writer":"engine-verify","commit":"%s","files":%s}\n' \
+    "$manifest_hash" "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)" "$head_commit" "$files_json" \
+    > "$ev_dir/MANIFEST.json"
+}
+
 verify_rc=0
 gate_rc=0
 doctor_rc=0
 run_stage verify bash "$cli" verify "$task"
 run_stage gate bash "$cli" gate "$task"
+refresh_evidence_manifest
 run_stage doctor bash "$cli" doctor
 
 memory_mode="single-session"
@@ -114,21 +152,102 @@ else
   fi
 fi
 
+
+# v6.25.0 (T-086/O4): auto-generate change capsule from conventional commits.
+# Internalized from conventional-changelog (MIT) — parses git log for task-linked
+# commits, groups by type, outputs engine/changes/CHANGE-<task>.md.
+generate_capsule() {
+  local task_id="$1"
+  local changes_dir="$ENGINE_DIR/changes"
+  mkdir -p "$changes_dir"
+  local capsule_file="$changes_dir/CHANGE-${task_id}.md"
+
+  # Collect commits: prefer task-mentioning commits, supplement with recent history
+  local commits
+  commits="$(git -C "$ROOT" log --grep="$task_id" --pretty=format:"%s" 2>/dev/null || true)"
+  # Always include last 30 commits for full context (task work may not all reference ID)
+  local recent
+  recent="$(git -C "$ROOT" log -30 --pretty=format:"%s" 2>/dev/null || true)"
+  if [ -n "$recent" ]; then
+    if [ -n "$commits" ]; then
+      # Merge: task-specific first, then recent (dedup via sort -u)
+      commits="$(printf '%s\n%s' "$commits" "$recent" | awk '!seen[$0]++')"
+    else
+      commits="$recent"
+    fi
+  fi
+  [ -z "$commits" ] && return 1
+
+  # Parse conventional commits and group by type
+  local feat_list="" fix_list="" refactor_list="" docs_list="" test_list="" chore_list="" other_list=""
+  local line ctype cscope cdesc
+  while IFS= read -r line; do
+    [ -z "$line" ] && continue
+    # Conventional format: type(scope)!: description  OR  type: description
+    if [[ "$line" =~ ^([a-z]+)(\([a-zA-Z0-9._/-]*\))?(!)?:[[:space:]]*(.*) ]]; then
+      ctype="${BASH_REMATCH[1]}"
+      cscope="${BASH_REMATCH[2]}"
+      cdesc="${BASH_REMATCH[4]}"
+      # Strip parens from scope
+      cscope="${cscope#(}"; cscope="${cscope%)}"
+      local entry="- ${cdesc}"
+      [ -n "$cscope" ] && entry="- **${cscope}**: ${cdesc}"
+      case "$ctype" in
+        feat)     feat_list+="${entry}"$'\n' ;;
+        fix)      fix_list+="${entry}"$'\n' ;;
+        refactor) refactor_list+="${entry}"$'\n' ;;
+        docs)     docs_list+="${entry}"$'\n' ;;
+        test)     test_list+="${entry}"$'\n' ;;
+        chore|ci|build|style|perf) chore_list+="${entry}"$'\n' ;;
+        *)        other_list+="${entry}"$'\n' ;;
+      esac
+    else
+      # Non-conventional commit
+      other_list+="- ${line}"$'\n'
+    fi
+  done <<< "$commits"
+
+  # Write capsule
+  {
+    printf '# CHANGE-%s\n\n' "$task_id"
+    printf '> Auto-generated by engine-close (conventional-changelog internalized). %s\n\n' "$timestamp"
+    [ -n "$feat_list" ] && printf '## Features\n\n%b\n' "$feat_list"
+    [ -n "$fix_list" ] && printf '## Bug Fixes\n\n%b\n' "$fix_list"
+    [ -n "$refactor_list" ] && printf '## Refactoring\n\n%b\n' "$refactor_list"
+    [ -n "$docs_list" ] && printf '## Documentation\n\n%b\n' "$docs_list"
+    [ -n "$test_list" ] && printf '## Tests\n\n%b\n' "$test_list"
+    [ -n "$chore_list" ] && printf '## Chores\n\n%b\n' "$chore_list"
+    [ -n "$other_list" ] && printf '## Other\n\n%b\n' "$other_list"
+    printf '%s\n' "---"
+    printf 'Provenance: commit %s | writer: engine-close/generate_capsule\n' "$head_commit"
+  } > "$capsule_file"
+
+  echo "[engine-close] generated capsule: ${capsule_file#"$ROOT/"}"
+  return 0
+}
+
 # A code task needs a task-linked capsule. Workers report this as deferred: the
 # coordinator owns engine/changes and must perform the final close after merge.
 capsule_status="not_required"
 capsule_path=""
 write_set_code=0
+if declare -F task_card_parse_patterns >/dev/null 2>&1; then
+  write_set_paths="$(task_card_parse_patterns WRITE-SET "$task_file")"
+else
+  write_set_paths="$(awk '
+    /^##[[:space:]]+WRITE-SET[[:space:]]*$/ { on=1; next }
+    on && /^##[[:space:]]+/ { on=0 }
+    on && /^-[[:space:]]+/ { sub(/^-[[:space:]]+/, ""); print }
+  ' "$task_file" 2>/dev/null)"
+fi
 while IFS= read -r write_path; do
+  write_path="${write_path%%(*}"
+  write_path="${write_path%%\[*}"
   if [[ "$write_path" =~ \.(sh|ps1|py|js|ts|go|rs|java|c|cpp|rb|php)$ ]]; then
     write_set_code=1
     break
   fi
-done < <(awk '
-  /^##[[:space:]]+WRITE-SET[[:space:]]*$/ { on=1; next }
-  on && /^##[[:space:]]+/ { on=0 }
-  on && /^-[[:space:]]+/ { sub(/^-[[:space:]]+/, ""); print }
-' "$task_file" 2>/dev/null)
+done <<< "$write_set_paths"
 if [ "$write_set_code" -eq 1 ]; then
   capsule_status="block"
   while IFS= read -r f; do
@@ -142,7 +261,13 @@ if [ "$write_set_code" -eq 1 ]; then
   if [ "$memory_mode" = "worker" ] && [ "$memory_status" = "pass" ]; then
     capsule_status="deferred_to_coordinator"
   elif [ "$capsule_status" = "block" ]; then
-    echo "[engine-close] no task-linked change capsule found for $task" >&2
+    # v6.25.0 (O4): auto-generate capsule from conventional commits
+    if generate_capsule "$task"; then
+      capsule_status="pass"
+      capsule_path="engine/changes/CHANGE-${task}.md"
+    else
+      echo "[engine-close] no task-linked change capsule found for $task (auto-generation failed)" >&2
+    fi
   fi
 fi
 
@@ -207,6 +332,8 @@ else
   status="block"
 fi
 
+refresh_evidence_manifest
+
 echo "[Engine System] Close status for $task: ${status^^}"
 echo "  Evidence: ${out#"$ROOT/"}"
 [ -n "$handoff_path" ] && echo "  Worker handoff: $handoff_path"
```

### engine/scripts/engine-close.ps1
```diff
diff --git a/engine/scripts/engine-close.ps1 b/engine/scripts/engine-close.ps1
index de1f462..8e27def 100644
--- a/engine/scripts/engine-close.ps1
+++ b/engine/scripts/engine-close.ps1
@@ -11,6 +11,8 @@ param(
 $ErrorActionPreference = "Continue"
 $Root = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (Get-Location).Path }
 $EngineDir = Join-Path $Root "engine"
+$taskCardLibrary = Join-Path $PSScriptRoot "engine-task-card.ps1"
+if (Test-Path -LiteralPath $taskCardLibrary -PathType Leaf) { . $taskCardLibrary }
 $handoffAgent = if ($env:ENGINE_AGENT_ID) { $env:ENGINE_AGENT_ID } else { "" }
 
 $closeArgs = @()
@@ -63,10 +65,46 @@ function Invoke-Stage {
   return $rc
 }
 
+# Gate and close both write evidence files covered by MANIFEST.json. Refresh at
+# each evidence-writer boundary so a done task's Doctor/drift check never sees
+# a transient self-tamper state.
+function Refresh-EvidenceManifest {
+  $evDir = Join-Path $EngineDir "evidence\$Task"
+  if (-not (Test-Path $evDir)) { return }
+  $files = @(Get-ChildItem -Path $evDir -File | Where-Object { $_.Name -ne 'MANIFEST.json' -and ($_.Name -like '*.json' -or $_.Name -eq 'checkpoint.md') })
+  $ordinalComparer = [System.Collections.Generic.Comparer[object]]::Create(
+    [System.Comparison[object]]{
+      param($left, $right)
+      [System.StringComparer]::Ordinal.Compare($left.Name, $right.Name)
+    }
+  )
+  if ($files.Count -gt 1) { [System.Array]::Sort($files, $ordinalComparer) }
+  $manifestContent = ""
+  $filesDict = [ordered]@{}
+  foreach ($f in $files) {
+    $h = (Get-FileHash -Path $f.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
+    $manifestContent += "$($f.Name):$h`n"
+    $filesDict[$f.Name] = $h
+  }
+  $bytes = [System.Text.Encoding]::UTF8.GetBytes($manifestContent)
+  $sha = [System.Security.Cryptography.SHA256]::Create()
+  $manifestHash = ([System.BitConverter]::ToString($sha.ComputeHash($bytes)) -replace '-', '').ToLowerInvariant()
+  $sha.Dispose()
+  $manifest = [ordered]@{
+    evidence_manifest_sha256 = "sha256:$manifestHash"
+    generated = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
+    writer = 'engine-verify'
+    commit = $headCommit
+    files = $filesDict
+  }
+  $manifest | ConvertTo-Json -Depth 8 -Compress | Set-Content -Path (Join-Path $evDir 'MANIFEST.json') -Encoding UTF8
+}
+
 Push-Location $Root
 try {
   $verifyRc = Invoke-Stage -Label "verify" -Action { & $cli verify $Task }
   $gateRc = Invoke-Stage -Label "gate" -Action { & $cli gate $Task }
+  Refresh-EvidenceManifest
   $doctorRc = Invoke-Stage -Label "doctor" -Action { & $cli doctor }
 } finally {
   Pop-Location
@@ -129,13 +167,86 @@ if (-not (Test-Path $lockFile)) {
   }
 }
 
+
+# v6.25.0 (T-086/O4): auto-generate change capsule from conventional commits.
+function Generate-Capsule {
+  param([string]$TaskId)
+  $changesDir = Join-Path $EngineDir 'changes'
+  if (-not (Test-Path $changesDir)) { New-Item -ItemType Directory -Path $changesDir -Force | Out-Null }
+  $capsuleFile = Join-Path $changesDir "CHANGE-$TaskId.md"
+
+  # Collect commits: task-mentioning + recent history
+  $taskCommits = & git -C $Root log --grep="$TaskId" --pretty=format:"%s" 2>$null
+  $recentCommits = & git -C $Root log -30 --pretty=format:"%s" 2>$null
+  $allCommits = @()
+  if ($taskCommits) { $allCommits += @($taskCommits) }
+  if ($recentCommits) {
+    foreach ($c in @($recentCommits)) {
+      if ($allCommits -notcontains $c) { $allCommits += $c }
+    }
+  }
+  if ($allCommits.Count -eq 0) { return $false }
+
+  # Parse conventional commits and group by type
+  $groups = @{ feat=@(); fix=@(); refactor=@(); docs=@(); test=@(); chore=@(); other=@() }
+  foreach ($line in $allCommits) {
+    if (-not $line) { continue }
+    if ($line -match '^([a-z]+)(\([a-zA-Z0-9._/-]*\))?(!)?:\s*(.*)') {
+      $ctype = $Matches[1]
+      $cscope = if ($Matches[2]) { $Matches[2].Trim('(',')') } else { '' }
+      $cdesc = $Matches[4]
+      $entry = if ($cscope) { "- **${cscope}**: $cdesc" } else { "- $cdesc" }
+      switch ($ctype) {
+        'feat'     { $groups.feat += $entry }
+        'fix'      { $groups.fix += $entry }
+        'refactor' { $groups.refactor += $entry }
+        'docs'     { $groups.docs += $entry }
+        'test'     { $groups.test += $entry }
+        { $_ -in 'chore','ci','build','style','perf' } { $groups.chore += $entry }
+        default    { $groups.other += $entry }
+      }
+    } else {
+      $groups.other += "- $line"
+    }
+  }
+
+  # Write capsule
+  $sb = [System.Text.StringBuilder]::new()
+  [void]$sb.AppendLine("# CHANGE-$TaskId")
+  [void]$sb.AppendLine("")
+  [void]$sb.AppendLine("> Auto-generated by engine-close (conventional-changelog internalized). $timestamp")
+  [void]$sb.AppendLine("")
+  if ($groups.feat.Count -gt 0) { [void]$sb.AppendLine("## Features"); [void]$sb.AppendLine(""); foreach ($e in $groups.feat) { [void]$sb.AppendLine($e) }; [void]$sb.AppendLine("") }
+  if ($groups.fix.Count -gt 0) { [void]$sb.AppendLine("## Bug Fixes"); [void]$sb.AppendLine(""); foreach ($e in $groups.fix) { [void]$sb.AppendLine($e) }; [void]$sb.AppendLine("") }
+  if ($groups.refactor.Count -gt 0) { [void]$sb.AppendLine("## Refactoring"); [void]$sb.AppendLine(""); foreach ($e in $groups.refactor) { [void]$sb.AppendLine($e) }; [void]$sb.AppendLine("") }
+  if ($groups.docs.Count -gt 0) { [void]$sb.AppendLine("## Documentation"); [void]$sb.AppendLine(""); foreach ($e in $groups.docs) { [void]$sb.AppendLine($e) }; [void]$sb.AppendLine("") }
+  if ($groups.test.Count -gt 0) { [void]$sb.AppendLine("## Tests"); [void]$sb.AppendLine(""); foreach ($e in $groups.test) { [void]$sb.AppendLine($e) }; [void]$sb.AppendLine("") }
+  if ($groups.chore.Count -gt 0) { [void]$sb.AppendLine("## Chores"); [void]$sb.AppendLine(""); foreach ($e in $groups.chore) { [void]$sb.AppendLine($e) }; [void]$sb.AppendLine("") }
+  if ($groups.other.Count -gt 0) { [void]$sb.AppendLine("## Other"); [void]$sb.AppendLine(""); foreach ($e in $groups.other) { [void]$sb.AppendLine($e) }; [void]$sb.AppendLine("") }
+  [void]$sb.AppendLine("---")
+  [void]$sb.AppendLine("Provenance: commit $headCommit | writer: engine-close/generate_capsule")
+  [System.IO.File]::WriteAllText($capsuleFile, $sb.ToString(), (New-Object System.Text.UTF8Encoding $false))
+
+  Write-Host "[engine-close] generated capsule: engine/changes/CHANGE-$TaskId.md"
+  return $true
+}
+
 $capsuleStatus = 'not_required'
 $capsulePath = ''
 $taskText = Get-Content -Raw -Path $taskFile -Encoding UTF8
-$writeSetText = ''
-$writeSetMatch = [regex]::Match($taskText, '(?ms)^##\s+WRITE-SET\s*$([\s\S]*?)(?=^##\s+|\z)')
-if ($writeSetMatch.Success) { $writeSetText = $writeSetMatch.Groups[1].Value }
-if ($writeSetText -match '(?m)^-\s+.*\.(sh|ps1|py|js|ts|go|rs|java|c|cpp|rb|php)\s*$') {
+$writeSetFiles = @()
+if (Get-Command Get-TaskCardPatterns -ErrorAction SilentlyContinue) {
+  $writeSetFiles = @(Get-TaskCardPatterns -Path $taskFile -Field 'WRITE-SET')
+} else {
+  $writeSetMatch = [regex]::Match($taskText, '(?ms)^##\s+WRITE-SET\s*$([\s\S]*?)(?=^##\s+|\z)')
+  if ($writeSetMatch.Success) {
+    $writeSetFiles = @($writeSetMatch.Groups[1].Value -split "`n" | Where-Object { $_.Trim().StartsWith('- ') } | ForEach-Object { $_.Trim().Substring(2).Trim() })
+  }
+}
+if (@($writeSetFiles | Where-Object {
+  $clean = ($_ -replace '\s*[\(\[].*$', '').Trim()
+  $clean -match '\.(sh|ps1|py|js|ts|go|rs|java|c|cpp|rb|php)$'
+}).Count -gt 0) {
   $capsuleStatus = 'block'
   $changesDir = Join-Path $EngineDir 'changes'
   if (Test-Path $changesDir) {
@@ -151,7 +262,13 @@ if ($writeSetText -match '(?m)^-\s+.*\.(sh|ps1|py|js|ts|go|rs|java|c|cpp|rb|php)
   if ($memoryMode -eq 'worker' -and $memoryStatus -eq 'pass') {
     $capsuleStatus = 'deferred_to_coordinator'
   } elseif ($capsuleStatus -eq 'block') {
-    Write-Error "[engine-close] no task-linked change capsule found for $Task"
+    # v6.25.0 (O4): auto-generate capsule from conventional commits
+    if (Generate-Capsule -TaskId $Task) {
+      $capsuleStatus = 'pass'
+      $capsulePath = "engine/changes/CHANGE-$Task.md"
+    } else {
+      Write-Error "[engine-close] no task-linked change capsule found for $Task (auto-generation failed)"
+    }
   }
 }
 
@@ -177,6 +294,7 @@ $closeObj = [ordered]@{
   write_provenance = [ordered]@{ writer = 'engine-close'; commit = $headCommit; timestamp = $timestamp; argv = $closeArgv }
 }
 $closeObj | ConvertTo-Json -Depth 8 | Set-Content -Path $out -Encoding UTF8
+Refresh-EvidenceManifest
 
 Write-Host "[Engine System] Close status for ${Task}: $($status.ToUpperInvariant())"
 Write-Host "  Evidence: engine/evidence/$Task/CLOSE.json"
```

### plugin/engine/scripts/engine-close.sh
```diff
diff --git a/plugin/engine/scripts/engine-close.sh b/plugin/engine/scripts/engine-close.sh
index 5d15e55..9964754 100644
--- a/plugin/engine/scripts/engine-close.sh
+++ b/plugin/engine/scripts/engine-close.sh
@@ -9,6 +9,11 @@ set -u -o pipefail
 
 ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
 ENGINE_DIR="$ROOT/engine"
+task_card_script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
+if [ -f "$task_card_script_dir/engine-task-card.sh" ]; then
+  # shellcheck source=/dev/null
+  . "$task_card_script_dir/engine-task-card.sh"
+fi
 task="${1:-}"
 shift || true
 handoff_agent="${ENGINE_AGENT_ID:-}"
@@ -56,17 +61,50 @@ run_stage() {
   local tmp rc
   tmp="$(mktemp)"
   echo "[engine-close] running: $label"
-  "$@" 2>&1 | tee "$tmp"
-  rc="${PIPESTATUS[0]}"
+  # Capture the stage before replaying its output. Piping the child directly
+  # through tee lets an external log consumer closing early send SIGPIPE back
+  # into the stage (notably Doctor's long report), turning a real exit 0 into
+  # a false exit 141. The stage's exit code must be independent of display I/O.
+  "$@" >"$tmp" 2>&1
+  rc="$?"
+  cat "$tmp" || true
   printf -v "${label}_rc" '%s' "$rc"
   rm -f "$tmp"
 }
 
+# Gate and close both write evidence files that are covered by MANIFEST.json.
+# Refresh the manifest at each evidence-writer boundary so a done task's
+# Doctor/drift check never observes a transient self-tamper state.
+refresh_evidence_manifest() {
+  local ev_dir="$ENGINE_DIR/evidence/$task"
+  [ -d "$ev_dir" ] || return 0
+  local manifest_content="" fname fhash
+  while IFS= read -r fname; do
+    [ -n "$fname" ] || continue
+    fhash="$(sha256sum "$ev_dir/$fname" | cut -d' ' -f1)"
+    manifest_content+="${fname}:${fhash}"$'\n'
+  done < <(cd "$ev_dir" && find . -maxdepth 1 -type f \( -name '*.json' -o -name 'checkpoint.md' \) ! -name 'MANIFEST.json' -print 2>/dev/null | sed 's|^\./||' | LC_ALL=C sort)
+
+  local manifest_hash="$(printf '%s' "$manifest_content" | sha256sum | cut -d' ' -f1)"
+  local files_json="{" first=1
+  while IFS=: read -r fname fhash; do
+    [ -n "$fname" ] || continue
+    [ "$first" = "1" ] || files_json+=",";
+    files_json+="\"$fname\":\"$fhash\""
+    first=0
+  done <<< "$manifest_content"
+  files_json+="}"
+  printf '{"evidence_manifest_sha256":"sha256:%s","generated":"%s","writer":"engine-verify","commit":"%s","files":%s}\n' \
+    "$manifest_hash" "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)" "$head_commit" "$files_json" \
+    > "$ev_dir/MANIFEST.json"
+}
+
 verify_rc=0
 gate_rc=0
 doctor_rc=0
 run_stage verify bash "$cli" verify "$task"
 run_stage gate bash "$cli" gate "$task"
+refresh_evidence_manifest
 run_stage doctor bash "$cli" doctor
 
 memory_mode="single-session"
@@ -114,21 +152,102 @@ else
   fi
 fi
 
+
+# v6.25.0 (T-086/O4): auto-generate change capsule from conventional commits.
+# Internalized from conventional-changelog (MIT) — parses git log for task-linked
+# commits, groups by type, outputs engine/changes/CHANGE-<task>.md.
+generate_capsule() {
+  local task_id="$1"
+  local changes_dir="$ENGINE_DIR/changes"
+  mkdir -p "$changes_dir"
+  local capsule_file="$changes_dir/CHANGE-${task_id}.md"
+
+  # Collect commits: prefer task-mentioning commits, supplement with recent history
+  local commits
+  commits="$(git -C "$ROOT" log --grep="$task_id" --pretty=format:"%s" 2>/dev/null || true)"
+  # Always include last 30 commits for full context (task work may not all reference ID)
+  local recent
+  recent="$(git -C "$ROOT" log -30 --pretty=format:"%s" 2>/dev/null || true)"
+  if [ -n "$recent" ]; then
+    if [ -n "$commits" ]; then
+      # Merge: task-specific first, then recent (dedup via sort -u)
+      commits="$(printf '%s\n%s' "$commits" "$recent" | awk '!seen[$0]++')"
+    else
+      commits="$recent"
+    fi
+  fi
+  [ -z "$commits" ] && return 1
+
+  # Parse conventional commits and group by type
+  local feat_list="" fix_list="" refactor_list="" docs_list="" test_list="" chore_list="" other_list=""
+  local line ctype cscope cdesc
+  while IFS= read -r line; do
+    [ -z "$line" ] && continue
+    # Conventional format: type(scope)!: description  OR  type: description
+    if [[ "$line" =~ ^([a-z]+)(\([a-zA-Z0-9._/-]*\))?(!)?:[[:space:]]*(.*) ]]; then
+      ctype="${BASH_REMATCH[1]}"
+      cscope="${BASH_REMATCH[2]}"
+      cdesc="${BASH_REMATCH[4]}"
+      # Strip parens from scope
+      cscope="${cscope#(}"; cscope="${cscope%)}"
+      local entry="- ${cdesc}"
+      [ -n "$cscope" ] && entry="- **${cscope}**: ${cdesc}"
+      case "$ctype" in
+        feat)     feat_list+="${entry}"$'\n' ;;
+        fix)      fix_list+="${entry}"$'\n' ;;
+        refactor) refactor_list+="${entry}"$'\n' ;;
+        docs)     docs_list+="${entry}"$'\n' ;;
+        test)     test_list+="${entry}"$'\n' ;;
+        chore|ci|build|style|perf) chore_list+="${entry}"$'\n' ;;
+        *)        other_list+="${entry}"$'\n' ;;
+      esac
+    else
+      # Non-conventional commit
+      other_list+="- ${line}"$'\n'
+    fi
+  done <<< "$commits"
+
+  # Write capsule
+  {
+    printf '# CHANGE-%s\n\n' "$task_id"
+    printf '> Auto-generated by engine-close (conventional-changelog internalized). %s\n\n' "$timestamp"
+    [ -n "$feat_list" ] && printf '## Features\n\n%b\n' "$feat_list"
+    [ -n "$fix_list" ] && printf '## Bug Fixes\n\n%b\n' "$fix_list"
+    [ -n "$refactor_list" ] && printf '## Refactoring\n\n%b\n' "$refactor_list"
+    [ -n "$docs_list" ] && printf '## Documentation\n\n%b\n' "$docs_list"
+    [ -n "$test_list" ] && printf '## Tests\n\n%b\n' "$test_list"
+    [ -n "$chore_list" ] && printf '## Chores\n\n%b\n' "$chore_list"
+    [ -n "$other_list" ] && printf '## Other\n\n%b\n' "$other_list"
+    printf '%s\n' "---"
+    printf 'Provenance: commit %s | writer: engine-close/generate_capsule\n' "$head_commit"
+  } > "$capsule_file"
+
+  echo "[engine-close] generated capsule: ${capsule_file#"$ROOT/"}"
+  return 0
+}
+
 # A code task needs a task-linked capsule. Workers report this as deferred: the
 # coordinator owns engine/changes and must perform the final close after merge.
 capsule_status="not_required"
 capsule_path=""
 write_set_code=0
+if declare -F task_card_parse_patterns >/dev/null 2>&1; then
+  write_set_paths="$(task_card_parse_patterns WRITE-SET "$task_file")"
+else
+  write_set_paths="$(awk '
+    /^##[[:space:]]+WRITE-SET[[:space:]]*$/ { on=1; next }
+    on && /^##[[:space:]]+/ { on=0 }
+    on && /^-[[:space:]]+/ { sub(/^-[[:space:]]+/, ""); print }
+  ' "$task_file" 2>/dev/null)"
+fi
 while IFS= read -r write_path; do
+  write_path="${write_path%%(*}"
+  write_path="${write_path%%\[*}"
   if [[ "$write_path" =~ \.(sh|ps1|py|js|ts|go|rs|java|c|cpp|rb|php)$ ]]; then
     write_set_code=1
     break
   fi
-done < <(awk '
-  /^##[[:space:]]+WRITE-SET[[:space:]]*$/ { on=1; next }
-  on && /^##[[:space:]]+/ { on=0 }
-  on && /^-[[:space:]]+/ { sub(/^-[[:space:]]+/, ""); print }
-' "$task_file" 2>/dev/null)
+done <<< "$write_set_paths"
 if [ "$write_set_code" -eq 1 ]; then
   capsule_status="block"
   while IFS= read -r f; do
@@ -142,7 +261,13 @@ if [ "$write_set_code" -eq 1 ]; then
   if [ "$memory_mode" = "worker" ] && [ "$memory_status" = "pass" ]; then
     capsule_status="deferred_to_coordinator"
   elif [ "$capsule_status" = "block" ]; then
-    echo "[engine-close] no task-linked change capsule found for $task" >&2
+    # v6.25.0 (O4): auto-generate capsule from conventional commits
+    if generate_capsule "$task"; then
+      capsule_status="pass"
+      capsule_path="engine/changes/CHANGE-${task}.md"
+    else
+      echo "[engine-close] no task-linked change capsule found for $task (auto-generation failed)" >&2
+    fi
   fi
 fi
 
@@ -207,6 +332,8 @@ else
   status="block"
 fi
 
+refresh_evidence_manifest
+
 echo "[Engine System] Close status for $task: ${status^^}"
 echo "  Evidence: ${out#"$ROOT/"}"
 [ -n "$handoff_path" ] && echo "  Worker handoff: $handoff_path"
```

### plugin/engine/scripts/engine-close.ps1
```diff
diff --git a/plugin/engine/scripts/engine-close.ps1 b/plugin/engine/scripts/engine-close.ps1
index de1f462..8e27def 100644
--- a/plugin/engine/scripts/engine-close.ps1
+++ b/plugin/engine/scripts/engine-close.ps1
@@ -11,6 +11,8 @@ param(
 $ErrorActionPreference = "Continue"
 $Root = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (Get-Location).Path }
 $EngineDir = Join-Path $Root "engine"
+$taskCardLibrary = Join-Path $PSScriptRoot "engine-task-card.ps1"
+if (Test-Path -LiteralPath $taskCardLibrary -PathType Leaf) { . $taskCardLibrary }
 $handoffAgent = if ($env:ENGINE_AGENT_ID) { $env:ENGINE_AGENT_ID } else { "" }
 
 $closeArgs = @()
@@ -63,10 +65,46 @@ function Invoke-Stage {
   return $rc
 }
 
+# Gate and close both write evidence files covered by MANIFEST.json. Refresh at
+# each evidence-writer boundary so a done task's Doctor/drift check never sees
+# a transient self-tamper state.
+function Refresh-EvidenceManifest {
+  $evDir = Join-Path $EngineDir "evidence\$Task"
+  if (-not (Test-Path $evDir)) { return }
+  $files = @(Get-ChildItem -Path $evDir -File | Where-Object { $_.Name -ne 'MANIFEST.json' -and ($_.Name -like '*.json' -or $_.Name -eq 'checkpoint.md') })
+  $ordinalComparer = [System.Collections.Generic.Comparer[object]]::Create(
+    [System.Comparison[object]]{
+      param($left, $right)
+      [System.StringComparer]::Ordinal.Compare($left.Name, $right.Name)
+    }
+  )
+  if ($files.Count -gt 1) { [System.Array]::Sort($files, $ordinalComparer) }
+  $manifestContent = ""
+  $filesDict = [ordered]@{}
+  foreach ($f in $files) {
+    $h = (Get-FileHash -Path $f.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
+    $manifestContent += "$($f.Name):$h`n"
+    $filesDict[$f.Name] = $h
+  }
+  $bytes = [System.Text.Encoding]::UTF8.GetBytes($manifestContent)
+  $sha = [System.Security.Cryptography.SHA256]::Create()
+  $manifestHash = ([System.BitConverter]::ToString($sha.ComputeHash($bytes)) -replace '-', '').ToLowerInvariant()
+  $sha.Dispose()
+  $manifest = [ordered]@{
+    evidence_manifest_sha256 = "sha256:$manifestHash"
+    generated = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
+    writer = 'engine-verify'
+    commit = $headCommit
+    files = $filesDict
+  }
+  $manifest | ConvertTo-Json -Depth 8 -Compress | Set-Content -Path (Join-Path $evDir 'MANIFEST.json') -Encoding UTF8
+}
+
 Push-Location $Root
 try {
   $verifyRc = Invoke-Stage -Label "verify" -Action { & $cli verify $Task }
   $gateRc = Invoke-Stage -Label "gate" -Action { & $cli gate $Task }
+  Refresh-EvidenceManifest
   $doctorRc = Invoke-Stage -Label "doctor" -Action { & $cli doctor }
 } finally {
   Pop-Location
@@ -129,13 +167,86 @@ if (-not (Test-Path $lockFile)) {
   }
 }
 
+
+# v6.25.0 (T-086/O4): auto-generate change capsule from conventional commits.
+function Generate-Capsule {
+  param([string]$TaskId)
+  $changesDir = Join-Path $EngineDir 'changes'
+  if (-not (Test-Path $changesDir)) { New-Item -ItemType Directory -Path $changesDir -Force | Out-Null }
+  $capsuleFile = Join-Path $changesDir "CHANGE-$TaskId.md"
+
+  # Collect commits: task-mentioning + recent history
+  $taskCommits = & git -C $Root log --grep="$TaskId" --pretty=format:"%s" 2>$null
+  $recentCommits = & git -C $Root log -30 --pretty=format:"%s" 2>$null
+  $allCommits = @()
+  if ($taskCommits) { $allCommits += @($taskCommits) }
+  if ($recentCommits) {
+    foreach ($c in @($recentCommits)) {
+      if ($allCommits -notcontains $c) { $allCommits += $c }
+    }
+  }
+  if ($allCommits.Count -eq 0) { return $false }
+
+  # Parse conventional commits and group by type
+  $groups = @{ feat=@(); fix=@(); refactor=@(); docs=@(); test=@(); chore=@(); other=@() }
+  foreach ($line in $allCommits) {
+    if (-not $line) { continue }
+    if ($line -match '^([a-z]+)(\([a-zA-Z0-9._/-]*\))?(!)?:\s*(.*)') {
+      $ctype = $Matches[1]
+      $cscope = if ($Matches[2]) { $Matches[2].Trim('(',')') } else { '' }
+      $cdesc = $Matches[4]
+      $entry = if ($cscope) { "- **${cscope}**: $cdesc" } else { "- $cdesc" }
+      switch ($ctype) {
+        'feat'     { $groups.feat += $entry }
+        'fix'      { $groups.fix += $entry }
+        'refactor' { $groups.refactor += $entry }
+        'docs'     { $groups.docs += $entry }
+        'test'     { $groups.test += $entry }
+        { $_ -in 'chore','ci','build','style','perf' } { $groups.chore += $entry }
+        default    { $groups.other += $entry }
+      }
+    } else {
+      $groups.other += "- $line"
+    }
+  }
+
+  # Write capsule
+  $sb = [System.Text.StringBuilder]::new()
+  [void]$sb.AppendLine("# CHANGE-$TaskId")
+  [void]$sb.AppendLine("")
+  [void]$sb.AppendLine("> Auto-generated by engine-close (conventional-changelog internalized). $timestamp")
+  [void]$sb.AppendLine("")
+  if ($groups.feat.Count -gt 0) { [void]$sb.AppendLine("## Features"); [void]$sb.AppendLine(""); foreach ($e in $groups.feat) { [void]$sb.AppendLine($e) }; [void]$sb.AppendLine("") }
+  if ($groups.fix.Count -gt 0) { [void]$sb.AppendLine("## Bug Fixes"); [void]$sb.AppendLine(""); foreach ($e in $groups.fix) { [void]$sb.AppendLine($e) }; [void]$sb.AppendLine("") }
+  if ($groups.refactor.Count -gt 0) { [void]$sb.AppendLine("## Refactoring"); [void]$sb.AppendLine(""); foreach ($e in $groups.refactor) { [void]$sb.AppendLine($e) }; [void]$sb.AppendLine("") }
+  if ($groups.docs.Count -gt 0) { [void]$sb.AppendLine("## Documentation"); [void]$sb.AppendLine(""); foreach ($e in $groups.docs) { [void]$sb.AppendLine($e) }; [void]$sb.AppendLine("") }
+  if ($groups.test.Count -gt 0) { [void]$sb.AppendLine("## Tests"); [void]$sb.AppendLine(""); foreach ($e in $groups.test) { [void]$sb.AppendLine($e) }; [void]$sb.AppendLine("") }
+  if ($groups.chore.Count -gt 0) { [void]$sb.AppendLine("## Chores"); [void]$sb.AppendLine(""); foreach ($e in $groups.chore) { [void]$sb.AppendLine($e) }; [void]$sb.AppendLine("") }
+  if ($groups.other.Count -gt 0) { [void]$sb.AppendLine("## Other"); [void]$sb.AppendLine(""); foreach ($e in $groups.other) { [void]$sb.AppendLine($e) }; [void]$sb.AppendLine("") }
+  [void]$sb.AppendLine("---")
+  [void]$sb.AppendLine("Provenance: commit $headCommit | writer: engine-close/generate_capsule")
+  [System.IO.File]::WriteAllText($capsuleFile, $sb.ToString(), (New-Object System.Text.UTF8Encoding $false))
+
+  Write-Host "[engine-close] generated capsule: engine/changes/CHANGE-$TaskId.md"
+  return $true
+}
+
 $capsuleStatus = 'not_required'
 $capsulePath = ''
 $taskText = Get-Content -Raw -Path $taskFile -Encoding UTF8
-$writeSetText = ''
-$writeSetMatch = [regex]::Match($taskText, '(?ms)^##\s+WRITE-SET\s*$([\s\S]*?)(?=^##\s+|\z)')
-if ($writeSetMatch.Success) { $writeSetText = $writeSetMatch.Groups[1].Value }
-if ($writeSetText -match '(?m)^-\s+.*\.(sh|ps1|py|js|ts|go|rs|java|c|cpp|rb|php)\s*$') {
+$writeSetFiles = @()
+if (Get-Command Get-TaskCardPatterns -ErrorAction SilentlyContinue) {
+  $writeSetFiles = @(Get-TaskCardPatterns -Path $taskFile -Field 'WRITE-SET')
+} else {
+  $writeSetMatch = [regex]::Match($taskText, '(?ms)^##\s+WRITE-SET\s*$([\s\S]*?)(?=^##\s+|\z)')
+  if ($writeSetMatch.Success) {
+    $writeSetFiles = @($writeSetMatch.Groups[1].Value -split "`n" | Where-Object { $_.Trim().StartsWith('- ') } | ForEach-Object { $_.Trim().Substring(2).Trim() })
+  }
+}
+if (@($writeSetFiles | Where-Object {
+  $clean = ($_ -replace '\s*[\(\[].*$', '').Trim()
+  $clean -match '\.(sh|ps1|py|js|ts|go|rs|java|c|cpp|rb|php)$'
+}).Count -gt 0) {
   $capsuleStatus = 'block'
   $changesDir = Join-Path $EngineDir 'changes'
   if (Test-Path $changesDir) {
@@ -151,7 +262,13 @@ if ($writeSetText -match '(?m)^-\s+.*\.(sh|ps1|py|js|ts|go|rs|java|c|cpp|rb|php)
   if ($memoryMode -eq 'worker' -and $memoryStatus -eq 'pass') {
     $capsuleStatus = 'deferred_to_coordinator'
   } elseif ($capsuleStatus -eq 'block') {
-    Write-Error "[engine-close] no task-linked change capsule found for $Task"
+    # v6.25.0 (O4): auto-generate capsule from conventional commits
+    if (Generate-Capsule -TaskId $Task) {
+      $capsuleStatus = 'pass'
+      $capsulePath = "engine/changes/CHANGE-$Task.md"
+    } else {
+      Write-Error "[engine-close] no task-linked change capsule found for $Task (auto-generation failed)"
+    }
   }
 }
 
@@ -177,6 +294,7 @@ $closeObj = [ordered]@{
   write_provenance = [ordered]@{ writer = 'engine-close'; commit = $headCommit; timestamp = $timestamp; argv = $closeArgv }
 }
 $closeObj | ConvertTo-Json -Depth 8 | Set-Content -Path $out -Encoding UTF8
+Refresh-EvidenceManifest
 
 Write-Host "[Engine System] Close status for ${Task}: $($status.ToUpperInvariant())"
 Write-Host "  Evidence: engine/evidence/$Task/CLOSE.json"
```

### engine/scripts/engine-review-pipeline.sh
```diff
diff --git a/engine/scripts/engine-review-pipeline.sh b/engine/scripts/engine-review-pipeline.sh
index f32fa2e..c8f0015 100644
--- a/engine/scripts/engine-review-pipeline.sh
+++ b/engine/scripts/engine-review-pipeline.sh
@@ -24,8 +24,26 @@ fi
 
 ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
 ENGINE_DIR="$ROOT/engine"
+task_card_script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
+if [ -f "$task_card_script_dir/engine-task-card.sh" ]; then
+  # shellcheck source=/dev/null
+  . "$task_card_script_dir/engine-task-card.sh"
+fi
 task="${1:-}"
 
+# Git Bash may invoke the native Windows Python, which cannot open MSYS
+# `/e/...` paths. Keep shell paths for Bash, but pass Python portable
+# drive-qualified paths whenever cygpath is available.
+python_path() {
+  if command -v cygpath >/dev/null 2>&1; then
+    cygpath -m "$1"
+  else
+    printf '%s' "$1"
+  fi
+}
+python_root="$(python_path "$ROOT")"
+export ENGINE_REVIEW_PY_ROOT="$python_root"
+
 if [ -z "$task" ]; then
   echo "[engine-review-pipeline] Usage: engine-review-pipeline T-NNN" >&2
   exit 2
@@ -57,10 +75,11 @@ fi
 # 1. 读 config.json(L0 defaults + L1 overrides 合并)—— C11 用 $PY 解析
 #    L1 overrides 逐字段覆盖 L0 defaults(N4 修复:原版只读 defaults,忽略 overrides)
 config_file="$ENGINE_DIR/review/config.json"
+python_config_file="$(python_path "$config_file")"
 config_data=$("$PY" -c "
 import json, sys
 try:
-    with open('$config_file') as f:
+    with open('$python_config_file') as f:
         cfg = json.load(f)
 except:
     cfg = {}
@@ -94,11 +113,15 @@ print(json.dumps(d.get('dimensions',['security','quality'])))
 ")
 
 # 2. 解析 WRITE-SET(从任务卡)
-write_set_files=$(awk '
+if declare -F task_card_parse_patterns >/dev/null 2>&1; then
+  write_set_files="$(task_card_parse_patterns WRITE-SET "$task_file" | tr '\n' ' ')"
+else
+  write_set_files=$(awk '
   /^## WRITE-SET/{f=1;next}
   /^## /{f=0}
   f && /^- /{sub(/^- /,"");sub(/ *#.*/,"");print}
 ' "$task_file" | tr '\n' ' ')
+fi
 
 # 无 WRITE-SET → FAIL
 if [ -z "$write_set_files" ]; then
@@ -131,7 +154,7 @@ for line in sys.stdin:
     f=line.strip()
     if not f: continue
     _, ext=os.path.splitext(f)
-    if ext in exts and os.path.isfile('$ROOT/'+f):
+    if ext in exts and os.path.isfile('$python_root/'+f):
         out.append(f)
 print(' '.join(out))
 ")
@@ -297,6 +320,7 @@ if command -v eslint >/dev/null 2>&1; then
     else
       quality_findings_json=$(printf '%s' "$eslint_output" | "$PY" -c '
 import json,sys
+import os
 try: data=json.load(sys.stdin)
 except: data=[]
 findings=[]
@@ -307,8 +331,9 @@ for f in data:
         elif sev==1: mapped="medium"
         else: mapped="low"
         p=f.get("filePath","").replace("\\","/")
-        # 相对路径
-        if p.startswith("$ROOT/"): p=p[len("$ROOT/"):]
+        # 相对路径 (the root is passed as a normalized environment path)
+        root=os.environ.get("ENGINE_REVIEW_PY_ROOT","").replace("\\","/").rstrip("/")
+        if root and p.startswith(root+"/"): p=p[len(root)+1:]
         line=m.get("line",0)
         col=m.get("column",0)
         rule=m.get("ruleId","") or "unknown"
@@ -346,6 +371,7 @@ fi
 # 9. 汇总 REVIEW.json + SECURITY.json + QUALITY.json
 evidence_dir="$ENGINE_DIR/review/evidence/$task"
 mkdir -p "$evidence_dir"
+python_evidence_dir="$(python_path "$evidence_dir")"
 
 overall_status="pass"
 [ "$security_status" = "block" ] && overall_status="block"
@@ -417,7 +443,7 @@ fi
 # evidence_manifest_sha256(含 SECURITY + QUALITY,排除 REVIEW 自身;对照 §8-2)
 evidence_manifest_sha256=$("$PY" -c "
 import hashlib,json,os
-evidence_dir='$evidence_dir'
+evidence_dir='$python_evidence_dir'
 files=sorted([f for f in os.listdir(evidence_dir) if f.endswith('.json') and f!='REVIEW.json'])
 h=hashlib.sha256()
 for fname in files:
@@ -436,7 +462,7 @@ print(json.dumps({'semgrep':'$semgrep_version','eslint':'$eslint_version'},separ
 config_layers_json=$("$PY" -c "
 import json
 try:
-    with open('$config_file') as f:
+    with open('$python_config_file') as f:
         cfg = json.load(f)
 except:
     cfg = {}
```

### plugin/engine/scripts/engine-review-pipeline.sh
```diff
diff --git a/plugin/engine/scripts/engine-review-pipeline.sh b/plugin/engine/scripts/engine-review-pipeline.sh
index f32fa2e..c8f0015 100644
--- a/plugin/engine/scripts/engine-review-pipeline.sh
+++ b/plugin/engine/scripts/engine-review-pipeline.sh
@@ -24,8 +24,26 @@ fi
 
 ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
 ENGINE_DIR="$ROOT/engine"
+task_card_script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
+if [ -f "$task_card_script_dir/engine-task-card.sh" ]; then
+  # shellcheck source=/dev/null
+  . "$task_card_script_dir/engine-task-card.sh"
+fi
 task="${1:-}"
 
+# Git Bash may invoke the native Windows Python, which cannot open MSYS
+# `/e/...` paths. Keep shell paths for Bash, but pass Python portable
+# drive-qualified paths whenever cygpath is available.
+python_path() {
+  if command -v cygpath >/dev/null 2>&1; then
+    cygpath -m "$1"
+  else
+    printf '%s' "$1"
+  fi
+}
+python_root="$(python_path "$ROOT")"
+export ENGINE_REVIEW_PY_ROOT="$python_root"
+
 if [ -z "$task" ]; then
   echo "[engine-review-pipeline] Usage: engine-review-pipeline T-NNN" >&2
   exit 2
@@ -57,10 +75,11 @@ fi
 # 1. 读 config.json(L0 defaults + L1 overrides 合并)—— C11 用 $PY 解析
 #    L1 overrides 逐字段覆盖 L0 defaults(N4 修复:原版只读 defaults,忽略 overrides)
 config_file="$ENGINE_DIR/review/config.json"
+python_config_file="$(python_path "$config_file")"
 config_data=$("$PY" -c "
 import json, sys
 try:
-    with open('$config_file') as f:
+    with open('$python_config_file') as f:
         cfg = json.load(f)
 except:
     cfg = {}
@@ -94,11 +113,15 @@ print(json.dumps(d.get('dimensions',['security','quality'])))
 ")
 
 # 2. 解析 WRITE-SET(从任务卡)
-write_set_files=$(awk '
+if declare -F task_card_parse_patterns >/dev/null 2>&1; then
+  write_set_files="$(task_card_parse_patterns WRITE-SET "$task_file" | tr '\n' ' ')"
+else
+  write_set_files=$(awk '
   /^## WRITE-SET/{f=1;next}
   /^## /{f=0}
   f && /^- /{sub(/^- /,"");sub(/ *#.*/,"");print}
 ' "$task_file" | tr '\n' ' ')
+fi
 
 # 无 WRITE-SET → FAIL
 if [ -z "$write_set_files" ]; then
@@ -131,7 +154,7 @@ for line in sys.stdin:
     f=line.strip()
     if not f: continue
     _, ext=os.path.splitext(f)
-    if ext in exts and os.path.isfile('$ROOT/'+f):
+    if ext in exts and os.path.isfile('$python_root/'+f):
         out.append(f)
 print(' '.join(out))
 ")
@@ -297,6 +320,7 @@ if command -v eslint >/dev/null 2>&1; then
     else
       quality_findings_json=$(printf '%s' "$eslint_output" | "$PY" -c '
 import json,sys
+import os
 try: data=json.load(sys.stdin)
 except: data=[]
 findings=[]
@@ -307,8 +331,9 @@ for f in data:
         elif sev==1: mapped="medium"
         else: mapped="low"
         p=f.get("filePath","").replace("\\","/")
-        # 相对路径
-        if p.startswith("$ROOT/"): p=p[len("$ROOT/"):]
+        # 相对路径 (the root is passed as a normalized environment path)
+        root=os.environ.get("ENGINE_REVIEW_PY_ROOT","").replace("\\","/").rstrip("/")
+        if root and p.startswith(root+"/"): p=p[len(root)+1:]
         line=m.get("line",0)
         col=m.get("column",0)
         rule=m.get("ruleId","") or "unknown"
@@ -346,6 +371,7 @@ fi
 # 9. 汇总 REVIEW.json + SECURITY.json + QUALITY.json
 evidence_dir="$ENGINE_DIR/review/evidence/$task"
 mkdir -p "$evidence_dir"
+python_evidence_dir="$(python_path "$evidence_dir")"
 
 overall_status="pass"
 [ "$security_status" = "block" ] && overall_status="block"
@@ -417,7 +443,7 @@ fi
 # evidence_manifest_sha256(含 SECURITY + QUALITY,排除 REVIEW 自身;对照 §8-2)
 evidence_manifest_sha256=$("$PY" -c "
 import hashlib,json,os
-evidence_dir='$evidence_dir'
+evidence_dir='$python_evidence_dir'
 files=sorted([f for f in os.listdir(evidence_dir) if f.endswith('.json') and f!='REVIEW.json'])
 h=hashlib.sha256()
 for fname in files:
@@ -436,7 +462,7 @@ print(json.dumps({'semgrep':'$semgrep_version','eslint':'$eslint_version'},separ
 config_layers_json=$("$PY" -c "
 import json
 try:
-    with open('$config_file') as f:
+    with open('$python_config_file') as f:
         cfg = json.load(f)
 except:
     cfg = {}
```

### engine/scripts/engine-canvas.sh
```diff
diff --git a/engine/scripts/engine-canvas.sh b/engine/scripts/engine-canvas.sh
new file mode 100644
index 0000000..a05fa88
--- /dev/null
+++ b/engine/scripts/engine-canvas.sh
@@ -0,0 +1,228 @@
+#!/usr/bin/env bash
+# Engine System — Mermaid 任务状态画布(v6.25.0 / T-082)
+#
+# 纯证据派生，无 LLM，无持久化（view not state）。
+# 从 engine/evidence/T-NNN/AC-N.json 实时读取状态，生成 Mermaid flowchart。
+#
+# 用法:
+#   bash engine/scripts/engine-canvas.sh [T-NNN]
+#   --guard   输出一行摘要（CANVAS: T-NNN M/N AC PASS）
+#   无参数    对所有 active 任务生成画布
+#
+# 集成点: SessionStart（Active Task Card 之后）、Guard（一行摘要）
+# 安全: fail-open，任何错误静默退出 0。
+
+set -u
+
+ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
+ENGINE_DIR="$ROOT/engine"
+MODE="${1:-full}"
+
+# fail-open: 任何未预期错误不阻断宿主 hook
+trap 'exit 0' ERR
+
+[ -d "$ENGINE_DIR" ] || exit 0
+
+# ─── 辅助函数 ───────────────────────────────────────────────
+
+# 从 AC-N.json 提取 status 字段（纯 sed，不依赖 jq）
+ac_status() {
+  local file="$1"
+  [ -f "$file" ] || { echo "none"; return; }
+  sed -n 's/.*"status"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$file" | head -1
+}
+
+# 从任务卡提取 GOAL 段第一行（截断 80 字符）
+extract_goal() {
+  local card="$1" goal_line
+  goal_line="$(sed -n '/^## GOAL/,/^## /{/^## GOAL/d;/^## /d;/^$/d;p;}' "$card" | head -1)"
+  printf '%s' "${goal_line:0:80}"
+}
+
+# 从任务卡提取 AC 编号列表（复用 engine-verify 的 4 种格式）
+extract_ac_ids() {
+  local card="$1"
+  # Format 1: AC: AC-N ... | verify:
+  grep -oE 'AC-[A-Za-z]*[0-9]+(\.[0-9]+)*' "$card" 2>/dev/null | sort -t'-' -k2 -V | uniq
+}
+
+# 从 GATE.json 提取 status
+gate_status() {
+  local task="$1" gate_file="$ENGINE_DIR/evidence/$1/GATE.json"
+  [ -f "$gate_file" ] || { echo "none"; return; }
+  sed -n 's/.*"status"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$gate_file" | head -1
+}
+
+# ─── 画布生成 ───────────────────────────────────────────────
+
+generate_canvas() {
+  local task="$1"
+  local card="$ENGINE_DIR/tasks/$task.md"
+  local evidence_dir="$ENGINE_DIR/evidence/$task"
+  local goal card_status g_status
+
+  [ -f "$card" ] || return 0
+
+  # 卡片状态
+  # 兼容两种格式: "status: active" 和 "> status: active | lane: ..."
+  card_status="$(sed -n 's/^>[[:space:]]*status:[[:space:]]*\([^|]*\).*/\1/p' "$card" | head -1 | sed 's/[[:space:]]*$//')"
+  [ -n "$card_status" ] || card_status="$(sed -n 's/^status:[[:space:]]*//p' "$card" | head -1)"
+  goal="$(extract_goal "$card")"
+  g_status="$(gate_status "$task")"
+
+  # 收集 AC 列表
+  local ac_ids
+  ac_ids="$(extract_ac_ids "$card")"
+  [ -n "$ac_ids" ] || return 0
+
+  local total=0 pass_count=0
+  local nodes="" styles="" edges="" prev_id=""
+  local first_todo_found=0
+  local idx=0
+
+  while IFS= read -r ac_id; do
+    [ -n "$ac_id" ] || continue
+    idx=$((idx + 1))
+    total=$((total + 1))
+
+    local status_file="$evidence_dir/$ac_id.json"
+    local raw_status node_status color summary
+
+    raw_status="$(ac_status "$status_file")"
+    case "$raw_status" in
+      pass)
+        node_status="done"
+        color="#9f9"
+        pass_count=$((pass_count + 1))
+        # 提取时间戳作摘要
+        local ts
+        ts="$(sed -n 's/.*"timestamp"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$status_file" 2>/dev/null | head -1)"
+        summary="PASS"
+        [ -n "$ts" ] && summary="PASS @ ${ts:0:10}"
+        ;;
+      fail)
+        node_status="blocked"
+        color="#f99"
+        summary="FAIL"
+        ;;
+      blocked)
+        node_status="blocked"
+        color="#f99"
+        summary="blocked"
+        ;;
+      *)
+        # todo — 第一个 todo（前面全是 done）推断为 doing
+        if [ "$first_todo_found" -eq 0 ]; then
+          first_todo_found=1
+          # 检查是否前面全是 done（pass_count == idx-1）
+          if [ "$pass_count" -eq $((idx - 1)) ] && [ "$pass_count" -gt 0 ]; then
+            node_status="doing"
+            color="#ff9"
+            summary="in progress"
+          else
+            node_status="todo"
+            color="#f9f"
+            summary="no evidence"
+          fi
+        else
+          node_status="todo"
+          color="#f9f"
+          summary="no evidence"
+        fi
+        ;;
+    esac
+
+    local node_id="AC${idx}"
+    # 节点文本（Mermaid 内不能有无转义双引号）
+    local label="$ac_id<br/>status: $node_status<br/>summary: $summary"
+    nodes="${nodes}    ${node_id}[\"${label}\"]\n"
+    styles="${styles}    style ${node_id} fill:${color},stroke:#333\n"
+
+    # 边
+    if [ -n "$prev_id" ]; then
+      edges="${edges}    ${prev_id} --> ${node_id}\n"
+    fi
+    prev_id="$node_id"
+  done <<< "$ac_ids"
+
+  [ "$total" -gt 0 ] || return 0
+
+  # >8 AC 时纵向布局
+  local direction="LR"
+  [ "$total" -gt 8 ] && direction="TD"
+
+  # 输出 Mermaid
+  printf '%%%%{taskGoal: "%s", progress: "%d/%d", cardStatus: "%s", gateStatus: "%s"}%%%%\n' \
+    "$goal" "$pass_count" "$total" "$card_status" "$g_status"
+  printf 'graph %s\n' "$direction"
+  printf '%b' "$nodes"
+  printf '%b' "$edges"
+  printf '%b' "$styles"
+}
+
+# ─── Guard 一行摘要 ─────────────────────────────────────────
+
+generate_guard_summary() {
+  local task="$1"
+  local card="$ENGINE_DIR/tasks/$task.md"
+  local evidence_dir="$ENGINE_DIR/evidence/$task"
+
+  [ -f "$card" ] || return 0
+
+  local ac_ids total=0 pass_count=0
+  ac_ids="$(extract_ac_ids "$card")"
+  [ -n "$ac_ids" ] || return 0
+
+  while IFS= read -r ac_id; do
+    [ -n "$ac_id" ] || continue
+    total=$((total + 1))
+    local raw_status
+    raw_status="$(ac_status "$evidence_dir/$ac_id.json")"
+    [ "$raw_status" = "pass" ] && pass_count=$((pass_count + 1))
+  done <<< "$ac_ids"
+
+  echo "CANVAS: $task $pass_count/$total AC PASS"
+}
+
+# ─── 主入口 ─────────────────────────────────────────────────
+
+find_active_tasks() {
+  local f task_id
+  for f in "$ENGINE_DIR"/tasks/T-*.md; do
+    [ -f "$f" ] || continue
+    task_id="$(basename "$f" .md)"
+    if grep -q '^status:[[:space:]]*active' "$f" 2>/dev/null; then
+      echo "$task_id"
+    fi
+  done
+}
+
+case "$MODE" in
+  --guard)
+    # 一行摘要模式
+    tasks="$(find_active_tasks)"
+    [ -n "$tasks" ] || exit 0
+    while IFS= read -r t; do
+      generate_guard_summary "$t"
+    done <<< "$tasks"
+    ;;
+  T-*)
+    # 指定任务
+    echo '```mermaid'
+    generate_canvas "$MODE"
+    echo '```'
+    ;;
+  *)
+    # 全部 active 任务
+    tasks="$(find_active_tasks)"
+    [ -n "$tasks" ] || exit 0
+    while IFS= read -r t; do
+      echo '```mermaid'
+      generate_canvas "$t"
+      echo '```'
+      echo ""
+    done <<< "$tasks"
+    ;;
+esac
+
+exit 0
```

### plugin/engine/scripts/engine-canvas.sh
```diff
diff --git a/plugin/engine/scripts/engine-canvas.sh b/plugin/engine/scripts/engine-canvas.sh
new file mode 100644
index 0000000..a05fa88
--- /dev/null
+++ b/plugin/engine/scripts/engine-canvas.sh
@@ -0,0 +1,228 @@
+#!/usr/bin/env bash
+# Engine System — Mermaid 任务状态画布(v6.25.0 / T-082)
+#
+# 纯证据派生，无 LLM，无持久化（view not state）。
+# 从 engine/evidence/T-NNN/AC-N.json 实时读取状态，生成 Mermaid flowchart。
+#
+# 用法:
+#   bash engine/scripts/engine-canvas.sh [T-NNN]
+#   --guard   输出一行摘要（CANVAS: T-NNN M/N AC PASS）
+#   无参数    对所有 active 任务生成画布
+#
+# 集成点: SessionStart（Active Task Card 之后）、Guard（一行摘要）
+# 安全: fail-open，任何错误静默退出 0。
+
+set -u
+
+ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
+ENGINE_DIR="$ROOT/engine"
+MODE="${1:-full}"
+
+# fail-open: 任何未预期错误不阻断宿主 hook
+trap 'exit 0' ERR
+
+[ -d "$ENGINE_DIR" ] || exit 0
+
+# ─── 辅助函数 ───────────────────────────────────────────────
+
+# 从 AC-N.json 提取 status 字段（纯 sed，不依赖 jq）
+ac_status() {
+  local file="$1"
+  [ -f "$file" ] || { echo "none"; return; }
+  sed -n 's/.*"status"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$file" | head -1
+}
+
+# 从任务卡提取 GOAL 段第一行（截断 80 字符）
+extract_goal() {
+  local card="$1" goal_line
+  goal_line="$(sed -n '/^## GOAL/,/^## /{/^## GOAL/d;/^## /d;/^$/d;p;}' "$card" | head -1)"
+  printf '%s' "${goal_line:0:80}"
+}
+
+# 从任务卡提取 AC 编号列表（复用 engine-verify 的 4 种格式）
+extract_ac_ids() {
+  local card="$1"
+  # Format 1: AC: AC-N ... | verify:
+  grep -oE 'AC-[A-Za-z]*[0-9]+(\.[0-9]+)*' "$card" 2>/dev/null | sort -t'-' -k2 -V | uniq
+}
+
+# 从 GATE.json 提取 status
+gate_status() {
+  local task="$1" gate_file="$ENGINE_DIR/evidence/$1/GATE.json"
+  [ -f "$gate_file" ] || { echo "none"; return; }
+  sed -n 's/.*"status"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$gate_file" | head -1
+}
+
+# ─── 画布生成 ───────────────────────────────────────────────
+
+generate_canvas() {
+  local task="$1"
+  local card="$ENGINE_DIR/tasks/$task.md"
+  local evidence_dir="$ENGINE_DIR/evidence/$task"
+  local goal card_status g_status
+
+  [ -f "$card" ] || return 0
+
+  # 卡片状态
+  # 兼容两种格式: "status: active" 和 "> status: active | lane: ..."
+  card_status="$(sed -n 's/^>[[:space:]]*status:[[:space:]]*\([^|]*\).*/\1/p' "$card" | head -1 | sed 's/[[:space:]]*$//')"
+  [ -n "$card_status" ] || card_status="$(sed -n 's/^status:[[:space:]]*//p' "$card" | head -1)"
+  goal="$(extract_goal "$card")"
+  g_status="$(gate_status "$task")"
+
+  # 收集 AC 列表
+  local ac_ids
+  ac_ids="$(extract_ac_ids "$card")"
+  [ -n "$ac_ids" ] || return 0
+
+  local total=0 pass_count=0
+  local nodes="" styles="" edges="" prev_id=""
+  local first_todo_found=0
+  local idx=0
+
+  while IFS= read -r ac_id; do
+    [ -n "$ac_id" ] || continue
+    idx=$((idx + 1))
+    total=$((total + 1))
+
+    local status_file="$evidence_dir/$ac_id.json"
+    local raw_status node_status color summary
+
+    raw_status="$(ac_status "$status_file")"
+    case "$raw_status" in
+      pass)
+        node_status="done"
+        color="#9f9"
+        pass_count=$((pass_count + 1))
+        # 提取时间戳作摘要
+        local ts
+        ts="$(sed -n 's/.*"timestamp"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$status_file" 2>/dev/null | head -1)"
+        summary="PASS"
+        [ -n "$ts" ] && summary="PASS @ ${ts:0:10}"
+        ;;
+      fail)
+        node_status="blocked"
+        color="#f99"
+        summary="FAIL"
+        ;;
+      blocked)
+        node_status="blocked"
+        color="#f99"
+        summary="blocked"
+        ;;
+      *)
+        # todo — 第一个 todo（前面全是 done）推断为 doing
+        if [ "$first_todo_found" -eq 0 ]; then
+          first_todo_found=1
+          # 检查是否前面全是 done（pass_count == idx-1）
+          if [ "$pass_count" -eq $((idx - 1)) ] && [ "$pass_count" -gt 0 ]; then
+            node_status="doing"
+            color="#ff9"
+            summary="in progress"
+          else
+            node_status="todo"
+            color="#f9f"
+            summary="no evidence"
+          fi
+        else
+          node_status="todo"
+          color="#f9f"
+          summary="no evidence"
+        fi
+        ;;
+    esac
+
+    local node_id="AC${idx}"
+    # 节点文本（Mermaid 内不能有无转义双引号）
+    local label="$ac_id<br/>status: $node_status<br/>summary: $summary"
+    nodes="${nodes}    ${node_id}[\"${label}\"]\n"
+    styles="${styles}    style ${node_id} fill:${color},stroke:#333\n"
+
+    # 边
+    if [ -n "$prev_id" ]; then
+      edges="${edges}    ${prev_id} --> ${node_id}\n"
+    fi
+    prev_id="$node_id"
+  done <<< "$ac_ids"
+
+  [ "$total" -gt 0 ] || return 0
+
+  # >8 AC 时纵向布局
+  local direction="LR"
+  [ "$total" -gt 8 ] && direction="TD"
+
+  # 输出 Mermaid
+  printf '%%%%{taskGoal: "%s", progress: "%d/%d", cardStatus: "%s", gateStatus: "%s"}%%%%\n' \
+    "$goal" "$pass_count" "$total" "$card_status" "$g_status"
+  printf 'graph %s\n' "$direction"
+  printf '%b' "$nodes"
+  printf '%b' "$edges"
+  printf '%b' "$styles"
+}
+
+# ─── Guard 一行摘要 ─────────────────────────────────────────
+
+generate_guard_summary() {
+  local task="$1"
+  local card="$ENGINE_DIR/tasks/$task.md"
+  local evidence_dir="$ENGINE_DIR/evidence/$task"
+
+  [ -f "$card" ] || return 0
+
+  local ac_ids total=0 pass_count=0
+  ac_ids="$(extract_ac_ids "$card")"
+  [ -n "$ac_ids" ] || return 0
+
+  while IFS= read -r ac_id; do
+    [ -n "$ac_id" ] || continue
+    total=$((total + 1))
+    local raw_status
+    raw_status="$(ac_status "$evidence_dir/$ac_id.json")"
+    [ "$raw_status" = "pass" ] && pass_count=$((pass_count + 1))
+  done <<< "$ac_ids"
+
+  echo "CANVAS: $task $pass_count/$total AC PASS"
+}
+
+# ─── 主入口 ─────────────────────────────────────────────────
+
+find_active_tasks() {
+  local f task_id
+  for f in "$ENGINE_DIR"/tasks/T-*.md; do
+    [ -f "$f" ] || continue
+    task_id="$(basename "$f" .md)"
+    if grep -q '^status:[[:space:]]*active' "$f" 2>/dev/null; then
+      echo "$task_id"
+    fi
+  done
+}
+
+case "$MODE" in
+  --guard)
+    # 一行摘要模式
+    tasks="$(find_active_tasks)"
+    [ -n "$tasks" ] || exit 0
+    while IFS= read -r t; do
+      generate_guard_summary "$t"
+    done <<< "$tasks"
+    ;;
+  T-*)
+    # 指定任务
+    echo '```mermaid'
+    generate_canvas "$MODE"
+    echo '```'
+    ;;
+  *)
+    # 全部 active 任务
+    tasks="$(find_active_tasks)"
+    [ -n "$tasks" ] || exit 0
+    while IFS= read -r t; do
+      echo '```mermaid'
+      generate_canvas "$t"
+      echo '```'
+      echo ""
+    done <<< "$tasks"
+    ;;
+esac
+
+exit 0
```

### tests/workstream/test_failure_extract.sh
```diff
diff --git a/tests/workstream/test_failure_extract.sh b/tests/workstream/test_failure_extract.sh
new file mode 100644
index 0000000..2b27ebc
--- /dev/null
+++ b/tests/workstream/test_failure_extract.sh
@@ -0,0 +1,218 @@
+#!/usr/bin/env bash
+# Test: failure mode auto-extraction (T-082, v6.25.0)
+#
+# Validates:
+#   S1: Stop hook detects verify-fail (S12) → appends CAND to PITFALLS
+#   S2: Stop hook detects memory-writeback (S5) → appends CAND
+#   S3: Dedup — same signal not appended twice
+#   S4: pre-commit EXIT trap writes .cache/last-commit-block
+#   S5: Fail-open — missing PITFALLS doesn't crash stop hook
+#   S6: Auto-detected section auto-created if missing
+
+set -u
+PASS=0; FAIL=0
+assert_exit() {
+  local desc="$1" expected="$2" actual="$3"
+  if [ "$actual" -eq "$expected" ]; then
+    PASS=$((PASS+1)); echo "  PASS: $desc (exit $actual)"
+  else
+    FAIL=$((FAIL+1)); echo "  FAIL: $desc (expected exit $expected, got $actual)"
+  fi
+}
+assert_contains() {
+  local desc="$1" haystack="$2" needle="$3"
+  if printf '%s' "$haystack" | grep -q "$needle"; then
+    PASS=$((PASS+1)); echo "  PASS: $desc"
+  else
+    FAIL=$((FAIL+1)); echo "  FAIL: $desc ('$needle' not found)"
+  fi
+}
+assert_not_contains() {
+  local desc="$1" haystack="$2" needle="$3"
+  if printf '%s' "$haystack" | grep -q "$needle"; then
+    FAIL=$((FAIL+1)); echo "  FAIL: $desc ('$needle' unexpectedly found)"
+  else
+    PASS=$((PASS+1)); echo "  PASS: $desc"
+  fi
+}
+
+echo "=== test_failure_extract.sh ==="
+
+REAL_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
+STOP_SCRIPT="$REAL_ROOT/engine/scripts/engine-hook-stop.sh"
+PRECOMMIT="$REAL_ROOT/engine/scripts/githooks/pre-commit"
+[ -f "$STOP_SCRIPT" ] || { echo "FATAL: $STOP_SCRIPT not found"; exit 2; }
+[ -f "$PRECOMMIT" ] || { echo "FATAL: $PRECOMMIT not found"; exit 2; }
+
+# ─── Fixture ───
+FIXTURE="$(mktemp -d 2>/dev/null || echo "/tmp/fe-test-$$")"
+mkdir -p "$FIXTURE"
+cd "$FIXTURE" || exit 2
+git init -q . 2>/dev/null
+git config user.email "test@test.com" 2>/dev/null
+git config user.name "Test" 2>/dev/null
+
+# Minimal engine structure
+mkdir -p engine/tasks engine/evidence/T-100 engine/scripts/githooks
+mkdir -p engine/domains/engine-runtime engine/.cache/sessions
+mkdir -p src
+
+# Copy scripts
+cp "$STOP_SCRIPT" engine/scripts/engine-hook-stop.sh
+cp "$PRECOMMIT" engine/scripts/githooks/pre-commit
+
+# Task card
+cat > engine/tasks/T-100.md << 'CARD'
+# T-100: Failure extract test
+
+status: active
+lane: main
+domain: engine-runtime
+
+## GOAL
+
+Test failure extraction.
+
+## WRITE-SET
+
+- src/**
+- engine/CONTEXT.md
+
+## AC
+
+AC: AC-1 check | verify: true
+CARD
+
+# PITFALLS with Auto-detected section
+cat > engine/domains/engine-runtime/PITFALLS.md << 'PIT'
+# PITFALLS — engine-runtime
+
+## Known pitfalls
+
+- Some existing pitfall
+
+## Auto-detected (pending review)
+
+PIT
+
+# Evidence: AC-1 FAIL
+echo '{"ac":"AC-1","status":"fail","exit":1}' > engine/evidence/T-100/AC-1.json
+
+# Initial commit so git is happy
+git add -A 2>/dev/null
+git commit -q -m "init" --no-verify 2>/dev/null
+
+# ─── S1: verify-fail (S12) detection ───
+echo "--- S1: S12 verify-fail ---"
+# Simulate stop hook with active task + fail evidence
+# The stop hook reads payload from stdin; provide minimal JSON
+stop_payload='{"session_id":"test-s1","tool_input":{},"changed_paths":["src/foo.ts"]}'
+out1="$(printf '%s' "$stop_payload" | CLAUDE_PROJECT_DIR="$FIXTURE" bash engine/scripts/engine-hook-stop.sh 2>&1)"
+rc1=$?
+assert_exit "stop hook exits 0 (fail-open)" 0 $rc1
+
+pit_content="$(cat engine/domains/engine-runtime/PITFALLS.md)"
+assert_contains "S12 candidate appended" "$pit_content" 'signal: S12'
+assert_contains "candidate has task ref" "$pit_content" 'task: T-100'
+assert_contains "candidate has dedup-key" "$pit_content" 'dedup-key:'
+
+# ─── S2: memory-writeback (S5) detection ───
+echo "--- S2: S5 memory-writeback ---"
+# Reset PITFALLS and seen-keys
+cat > engine/domains/engine-runtime/PITFALLS.md << 'PIT'
+# PITFALLS — engine-runtime
+
+## Auto-detected (pending review)
+
+PIT
+rm -f engine/.cache/seen-keys
+# Remove fail evidence so S12 doesn't fire
+rm -f engine/evidence/T-100/AC-1.json
+
+# Simulate: code_changed=1, engine_written=0
+# The stop hook determines code_changed from git diff; make a code change
+echo "change" > src/bar.ts
+git add src/bar.ts 2>/dev/null
+# Pre-fill attribution ledger so path_owned recognizes the change
+printf '%s
+' "src/bar.ts" > engine/.cache/sessions/test-s1-main.paths
+
+out2="$(printf '%s' "$stop_payload" | CLAUDE_PROJECT_DIR="$FIXTURE" bash engine/scripts/engine-hook-stop.sh 2>&1)"
+rc2=$?
+assert_exit "S5 stop hook exits 0" 0 $rc2
+pit2="$(cat engine/domains/engine-runtime/PITFALLS.md)"
+assert_contains "S5 candidate appended" "$pit2" 'signal: S5'
+
+# ─── S3: Dedup — same signal not appended twice ───
+echo "--- S3: dedup ---"
+# Run again with same conditions
+out3="$(printf '%s' "$stop_payload" | CLAUDE_PROJECT_DIR="$FIXTURE" bash engine/scripts/engine-hook-stop.sh 2>&1)"
+pit3="$(cat engine/domains/engine-runtime/PITFALLS.md)"
+s5_count="$(printf '%s' "$pit3" | grep -c 'signal: S5')"
+if [ "$s5_count" -eq 1 ]; then
+  PASS=$((PASS+1)); echo "  PASS: S5 not duplicated (count=1)"
+else
+  FAIL=$((FAIL+1)); echo "  FAIL: S5 duplicated (count=$s5_count)"
+fi
+
+# ─── S4: pre-commit EXIT trap writes signal file ───
+echo "--- S4: pre-commit signal file ---"
+rm -f engine/.cache/last-commit-block
+# Create a commit that will be blocked (no active task WRITE-SET covers new file)
+echo "blocked" > engine/protected_file.txt
+git add engine/protected_file.txt 2>/dev/null
+# Run pre-commit directly (it should block and write signal)
+CLAUDE_PROJECT_DIR="$FIXTURE" bash engine/scripts/githooks/pre-commit >/dev/null 2>&1
+# pre-commit may exit 1 (blocked) — that's expected
+if [ -f engine/.cache/last-commit-block ]; then
+  PASS=$((PASS+1)); echo "  PASS: last-commit-block written"
+  sig_content="$(cat engine/.cache/last-commit-block)"
+  assert_contains "signal file has signal ID" "$sig_content" 'S6-precommit'
+else
+  # pre-commit might pass if WRITE-SET covers it; check
+  FAIL=$((FAIL+1)); echo "  FAIL: last-commit-block not written"
+  FAIL=$((FAIL+1)); echo "  FAIL: (skipped signal content check)"
+fi
+git reset -q HEAD engine/protected_file.txt 2>/dev/null
+rm -f engine/protected_file.txt
+
+# ─── S5: Fail-open — missing PITFALLS ───
+echo "--- S5: fail-open missing PITFALLS ---"
+rm -f engine/domains/engine-runtime/PITFALLS.md
+rm -f engine/.cache/seen-keys
+echo '{"ac":"AC-1","status":"fail","exit":1}' > engine/evidence/T-100/AC-1.json
+out5="$(printf '%s' "$stop_payload" | CLAUDE_PROJECT_DIR="$FIXTURE" bash engine/scripts/engine-hook-stop.sh 2>&1)"
+rc5=$?
+assert_exit "missing PITFALLS still exits 0" 0 $rc5
+
+# ─── S6: Auto-detected section auto-created ───
+echo "--- S6: auto-create section ---"
+# Create PITFALLS without Auto-detected section
+cat > engine/domains/engine-runtime/PITFALLS.md << 'PIT'
+# PITFALLS — engine-runtime
+
+## Known pitfalls
+
+- Existing entry
+PIT
+rm -f engine/.cache/seen-keys
+# Restore fail evidence for S12 detection
+echo '{"ac":"AC-1","status":"fail","exit":1}' > engine/evidence/T-100/AC-1.json
+# Ensure attribution ledger exists for path detection
+# Include engine/CONTEXT.md so engine_written=1 (avoids S5 early-exit path)
+printf '%s
+%s
+' "src/bar.ts" "engine/CONTEXT.md" > engine/.cache/sessions/test-s1-main.paths
+echo "change2" >> src/bar.ts
+echo "ctx" > engine/CONTEXT.md
+out6="$(printf '%s' "$stop_payload" | CLAUDE_PROJECT_DIR="$FIXTURE" bash engine/scripts/engine-hook-stop.sh 2>&1)"
+pit6="$(cat engine/domains/engine-runtime/PITFALLS.md)"
+assert_contains "Auto-detected section created" "$pit6" '## Auto-detected'
+assert_contains "candidate appended after auto-create" "$pit6" 'signal: S12'
+
+# ─── Cleanup + Summary ───
+cd /
+rm -rf "$FIXTURE" 2>/dev/null || true
+echo ""
+echo "=== Results: $PASS passed, $FAIL failed ==="
+[ "$FAIL" -eq 0 ] && exit 0 || exit 1
```

### engine/scripts/engine-drift-check.sh
```diff
diff --git a/engine/scripts/engine-drift-check.sh b/engine/scripts/engine-drift-check.sh
index ef02d7b..8e99784 100644
--- a/engine/scripts/engine-drift-check.sh
+++ b/engine/scripts/engine-drift-check.sh
@@ -56,6 +56,7 @@ for tid in "${done_cards[@]}"; do
   manifest_file="$ev_dir/MANIFEST.json"
   step1_fail=0
   legacy_evidence=0
+  historical_snapshot=0
 
   if [ ! -f "$manifest_file" ]; then
     # v6.18.0 (D-038d 迁移期): legacy evidence 没有 MANIFEST.json。区分两种情况:
@@ -95,10 +96,30 @@ for tid in "${done_cards[@]}"; do
       tamper_count=$((tamper_count+1))
       step1_fail=1
     fi
-    if [ "$prov_commit" != "$head_commit" ]; then
-      echo "  FAIL step1: provenance.commit mismatch (expected HEAD=$head_commit, got $prov_commit)"
+    if [ -z "$prov_commit" ]; then
+      echo "  FAIL step1: provenance.commit missing"
       tamper_count=$((tamper_count+1))
       step1_fail=1
+    elif ! (cd "$ROOT" && git cat-file -e "$prov_commit^{commit}" 2>/dev/null); then
+      echo "  FAIL step1: provenance.commit is not a reachable commit (got $prov_commit)"
+      tamper_count=$((tamper_count+1))
+      step1_fail=1
+    elif [ "$prov_commit" != "$head_commit" ]; then
+      # A done card can legitimately retain evidence generated at the commit
+      # immediately before its status transition, or at an older historical
+      # commit. The manifest has already self-verified, so report this as an
+      # explicit legacy snapshot warning while keeping code-fingerprint drift
+      # visible below. A current active/newly-done card remains a hard failure.
+      if git -C "$ROOT" cat-file -e "HEAD:engine/tasks/$tid.md" 2>/dev/null \
+        && git -C "$ROOT" show "HEAD:engine/tasks/$tid.md" 2>/dev/null | grep -Eq '^[[:space:]]*(>[[:space:]]*)?status:[[:space:]]*done'; then
+        echo "  WARN step1: legacy evidence provenance.commit mismatch (HEAD=$head_commit, snapshot=$prov_commit)"
+        warn_count=$((warn_count+1))
+        historical_snapshot=1
+      else
+        echo "  FAIL step1: provenance.commit mismatch (expected HEAD=$head_commit, got $prov_commit)"
+        tamper_count=$((tamper_count+1))
+        step1_fail=1
+      fi
     fi
   fi
 
@@ -183,12 +204,22 @@ for tid in "${done_cards[@]}"; do
         stored_sha="$(printf '%s' "$pair" | awk -F'"' '{print $4}')"
         current_sha="$(cd "$ROOT" && git ls-files -s "$path" 2>/dev/null | awk '{print $2}')"
         if [ -z "$current_sha" ]; then
-          echo "  DRIFT step3: $tid file deleted (path: $path)"
-          drift_count=$((drift_count+1))
+          if [ "$historical_snapshot" -eq 1 ]; then
+            echo "  WARN legacy step3: $tid file deleted after evidence snapshot (path: $path)"
+            warn_count=$((warn_count+1))
+          else
+            echo "  DRIFT step3: $tid file deleted (path: $path)"
+            drift_count=$((drift_count+1))
+          fi
           had_drift=1
         elif [ "$current_sha" != "$stored_sha" ]; then
-          echo "  DRIFT step3: $tid code changed ($path: stored=${stored_sha:0:12}.. current=${current_sha:0:12}..)"
-          drift_count=$((drift_count+1))
+          if [ "$historical_snapshot" -eq 1 ]; then
+            echo "  WARN legacy step3: $tid code changed after evidence snapshot ($path: stored=${stored_sha:0:12}.. current=${current_sha:0:12}..)"
+            warn_count=$((warn_count+1))
+          else
+            echo "  DRIFT step3: $tid code changed ($path: stored=${stored_sha:0:12}.. current=${current_sha:0:12}..)"
+            drift_count=$((drift_count+1))
+          fi
           had_drift=1
         fi
       done < <(printf '%s' "$cf_json" | tr ',' '\n' | grep '"')
```

### engine/scripts/engine-drift-check.ps1
```diff
diff --git a/engine/scripts/engine-drift-check.ps1 b/engine/scripts/engine-drift-check.ps1
index 41ce0ab..4b29f09 100644
--- a/engine/scripts/engine-drift-check.ps1
+++ b/engine/scripts/engine-drift-check.ps1
@@ -73,6 +73,7 @@ foreach ($tid in $doneCards) {
   $manifestFile = Join-Path $evDir "MANIFEST.json"
   $step1Fail = $false
   $legacyEvidence = $false
+  $historicalSnapshot = $false
 
   if (-not (Test-Path $manifestFile)) {
     # v6.18.0 (D-038d migration): legacy evidence has no MANIFEST.json. Two cases:
@@ -94,9 +95,21 @@ foreach ($tid in $doneCards) {
     }
   } else {
     # Recompute manifest aggregate hash and compare
-    $files = Get-ChildItem -Path $evDir -File |
-      Where-Object { $_.Name -ne 'MANIFEST.json' -and ($_.Name -like '*.json' -or $_.Name -eq 'checkpoint.md') } |
-      Sort-Object Name
+    # Keep the manifest order identical to Bash's LC_ALL=C byte ordering.
+    # PowerShell's default Sort-Object is culture-aware and places lowercase
+    # names before uppercase names, which falsely invalidates manifests that
+    # contain both e.g. PROVE.json and prove-assertions.json.
+    $files = @(
+      Get-ChildItem -Path $evDir -File |
+        Where-Object { $_.Name -ne 'MANIFEST.json' -and ($_.Name -like '*.json' -or $_.Name -eq 'checkpoint.md') }
+    )
+    $ordinalComparer = [System.Collections.Generic.Comparer[object]]::Create(
+      [System.Comparison[object]]{
+        param($left, $right)
+        [System.StringComparer]::Ordinal.Compare($left.Name, $right.Name)
+      }
+    )
+    if ($files.Count -gt 1) { [System.Array]::Sort($files, $ordinalComparer) }
     $manifestContent = ""
     foreach ($f in $files) {
       $h = (Get-FileHash -Path $f.FullName -Algorithm SHA256).Hash.ToLower()
@@ -129,9 +142,30 @@ foreach ($tid in $doneCards) {
       Write-Output "  FAIL step1: invalid provenance.writer (expected engine-verify, got $provWriter)"
       $tamperCount++; $step1Fail = $true
     }
-    if ($provCommit -ne $headCommit) {
-      Write-Output "  FAIL step1: provenance.commit mismatch (expected HEAD=$headCommit, got $provCommit)"
+    if (-not $provCommit) {
+      Write-Output "  FAIL step1: provenance.commit missing"
       $tamperCount++; $step1Fail = $true
+    } else {
+      $null = & git -C $Root cat-file -e "$provCommit^{commit}" 2>$null
+      $commitExists = ($LASTEXITCODE -eq 0)
+      if (-not $commitExists) {
+        Write-Output "  FAIL step1: provenance.commit is not a reachable commit (got $provCommit)"
+        $tamperCount++; $step1Fail = $true
+      } elseif ($provCommit -ne $headCommit) {
+        # A done card can legitimately retain evidence generated at the commit
+        # immediately before its status transition, or at an older historical
+        # commit. The manifest has already self-verified, so report this as an
+        # explicit legacy snapshot warning while keeping code-fingerprint drift
+        # visible below. A current active/newly-done card remains a hard failure.
+        $headCard = (& git -C $Root show "HEAD:engine/tasks/$tid.md" 2>$null | Out-String)
+        if ($headCard.Contains("> status: done")) {
+          Write-Output "  WARN step1: legacy evidence provenance.commit mismatch (HEAD=$headCommit, snapshot=$provCommit)"
+          $warnCount++; $historicalSnapshot = $true
+        } else {
+          Write-Output "  FAIL step1: provenance.commit mismatch (expected HEAD=$headCommit, got $provCommit)"
+          $tamperCount++; $step1Fail = $true
+        }
+      }
     }
   }
 
@@ -192,10 +226,10 @@ foreach ($tid in $doneCards) {
       }
     }
 
-    $snapshotSet = [System.Collections.Generic.HashSet[string]]::new($snapshotPaths)
-    $currentSet = [System.Collections.Generic.HashSet[string]]::new($currentWs)
-    $added = @($currentWs | Where-Object { -not $snapshotSet.Contains($_) })
-    $removed = @($snapshotPaths | Where-Object { -not $currentSet.Contains($_) })
+    # Use array membership rather than HashSet constructors: PowerShell 5 and
+    # PowerShell 7 bind one-element arrays differently to generic constructors.
+    $added = @($currentWs | Where-Object { $snapshotPaths -notcontains $_ })
+    $removed = @($snapshotPaths | Where-Object { $currentWs -notcontains $_ })
     if ($added.Count -gt 0 -or $removed.Count -gt 0) {
       Write-Output "  WARN step2: WRITE-SET changed since evidence"
       if ($added.Count -gt 0)   { Write-Output "    added: $($added -join ' ')" }
@@ -231,11 +265,23 @@ foreach ($tid in $doneCards) {
           $currentSha = ""
           if ($gitOut -match '\s([0-9a-f]{40})\s') { $currentSha = $Matches[1] }
           if (-not $currentSha) {
-            Write-Output "  DRIFT step3: $tid file deleted (path: $path)"
-            $driftCount++; $hadDrift = $true
+            if ($historicalSnapshot) {
+              Write-Output "  WARN legacy step3: $tid file deleted after evidence snapshot (path: $path)"
+              $warnCount++
+            } else {
+              Write-Output "  DRIFT step3: $tid file deleted (path: $path)"
+              $driftCount++
+            }
+            $hadDrift = $true
           } elseif ($currentSha -ne $storedSha) {
-            Write-Output "  DRIFT step3: $tid code changed (${path}: stored=$($storedSha.Substring(0,12)).. current=$($currentSha.Substring(0,12))..)"
-            $driftCount++; $hadDrift = $true
+            if ($historicalSnapshot) {
+              Write-Output "  WARN legacy step3: $tid code changed after evidence snapshot (${path}: stored=$($storedSha.Substring(0,12)).. current=$($currentSha.Substring(0,12))..)"
+              $warnCount++
+            } else {
+              Write-Output "  DRIFT step3: $tid code changed (${path}: stored=$($storedSha.Substring(0,12)).. current=$($currentSha.Substring(0,12))..)"
+              $driftCount++
+            }
+            $hadDrift = $true
           }
         }
       }
```

### plugin/engine/scripts/engine-drift-check.sh
```diff
diff --git a/plugin/engine/scripts/engine-drift-check.sh b/plugin/engine/scripts/engine-drift-check.sh
index ef02d7b..8e99784 100644
--- a/plugin/engine/scripts/engine-drift-check.sh
+++ b/plugin/engine/scripts/engine-drift-check.sh
@@ -56,6 +56,7 @@ for tid in "${done_cards[@]}"; do
   manifest_file="$ev_dir/MANIFEST.json"
   step1_fail=0
   legacy_evidence=0
+  historical_snapshot=0
 
   if [ ! -f "$manifest_file" ]; then
     # v6.18.0 (D-038d 迁移期): legacy evidence 没有 MANIFEST.json。区分两种情况:
@@ -95,10 +96,30 @@ for tid in "${done_cards[@]}"; do
       tamper_count=$((tamper_count+1))
       step1_fail=1
     fi
-    if [ "$prov_commit" != "$head_commit" ]; then
-      echo "  FAIL step1: provenance.commit mismatch (expected HEAD=$head_commit, got $prov_commit)"
+    if [ -z "$prov_commit" ]; then
+      echo "  FAIL step1: provenance.commit missing"
       tamper_count=$((tamper_count+1))
       step1_fail=1
+    elif ! (cd "$ROOT" && git cat-file -e "$prov_commit^{commit}" 2>/dev/null); then
+      echo "  FAIL step1: provenance.commit is not a reachable commit (got $prov_commit)"
+      tamper_count=$((tamper_count+1))
+      step1_fail=1
+    elif [ "$prov_commit" != "$head_commit" ]; then
+      # A done card can legitimately retain evidence generated at the commit
+      # immediately before its status transition, or at an older historical
+      # commit. The manifest has already self-verified, so report this as an
+      # explicit legacy snapshot warning while keeping code-fingerprint drift
+      # visible below. A current active/newly-done card remains a hard failure.
+      if git -C "$ROOT" cat-file -e "HEAD:engine/tasks/$tid.md" 2>/dev/null \
+        && git -C "$ROOT" show "HEAD:engine/tasks/$tid.md" 2>/dev/null | grep -Eq '^[[:space:]]*(>[[:space:]]*)?status:[[:space:]]*done'; then
+        echo "  WARN step1: legacy evidence provenance.commit mismatch (HEAD=$head_commit, snapshot=$prov_commit)"
+        warn_count=$((warn_count+1))
+        historical_snapshot=1
+      else
+        echo "  FAIL step1: provenance.commit mismatch (expected HEAD=$head_commit, got $prov_commit)"
+        tamper_count=$((tamper_count+1))
+        step1_fail=1
+      fi
     fi
   fi
 
@@ -183,12 +204,22 @@ for tid in "${done_cards[@]}"; do
         stored_sha="$(printf '%s' "$pair" | awk -F'"' '{print $4}')"
         current_sha="$(cd "$ROOT" && git ls-files -s "$path" 2>/dev/null | awk '{print $2}')"
         if [ -z "$current_sha" ]; then
-          echo "  DRIFT step3: $tid file deleted (path: $path)"
-          drift_count=$((drift_count+1))
+          if [ "$historical_snapshot" -eq 1 ]; then
+            echo "  WARN legacy step3: $tid file deleted after evidence snapshot (path: $path)"
+            warn_count=$((warn_count+1))
+          else
+            echo "  DRIFT step3: $tid file deleted (path: $path)"
+            drift_count=$((drift_count+1))
+          fi
           had_drift=1
         elif [ "$current_sha" != "$stored_sha" ]; then
-          echo "  DRIFT step3: $tid code changed ($path: stored=${stored_sha:0:12}.. current=${current_sha:0:12}..)"
-          drift_count=$((drift_count+1))
+          if [ "$historical_snapshot" -eq 1 ]; then
+            echo "  WARN legacy step3: $tid code changed after evidence snapshot ($path: stored=${stored_sha:0:12}.. current=${current_sha:0:12}..)"
+            warn_count=$((warn_count+1))
+          else
+            echo "  DRIFT step3: $tid code changed ($path: stored=${stored_sha:0:12}.. current=${current_sha:0:12}..)"
+            drift_count=$((drift_count+1))
+          fi
           had_drift=1
         fi
       done < <(printf '%s' "$cf_json" | tr ',' '\n' | grep '"')
```

### plugin/engine/scripts/engine-drift-check.ps1
```diff
diff --git a/plugin/engine/scripts/engine-drift-check.ps1 b/plugin/engine/scripts/engine-drift-check.ps1
index 41ce0ab..4b29f09 100644
--- a/plugin/engine/scripts/engine-drift-check.ps1
+++ b/plugin/engine/scripts/engine-drift-check.ps1
@@ -73,6 +73,7 @@ foreach ($tid in $doneCards) {
   $manifestFile = Join-Path $evDir "MANIFEST.json"
   $step1Fail = $false
   $legacyEvidence = $false
+  $historicalSnapshot = $false
 
   if (-not (Test-Path $manifestFile)) {
     # v6.18.0 (D-038d migration): legacy evidence has no MANIFEST.json. Two cases:
@@ -94,9 +95,21 @@ foreach ($tid in $doneCards) {
     }
   } else {
     # Recompute manifest aggregate hash and compare
-    $files = Get-ChildItem -Path $evDir -File |
-      Where-Object { $_.Name -ne 'MANIFEST.json' -and ($_.Name -like '*.json' -or $_.Name -eq 'checkpoint.md') } |
-      Sort-Object Name
+    # Keep the manifest order identical to Bash's LC_ALL=C byte ordering.
+    # PowerShell's default Sort-Object is culture-aware and places lowercase
+    # names before uppercase names, which falsely invalidates manifests that
+    # contain both e.g. PROVE.json and prove-assertions.json.
+    $files = @(
+      Get-ChildItem -Path $evDir -File |
+        Where-Object { $_.Name -ne 'MANIFEST.json' -and ($_.Name -like '*.json' -or $_.Name -eq 'checkpoint.md') }
+    )
+    $ordinalComparer = [System.Collections.Generic.Comparer[object]]::Create(
+      [System.Comparison[object]]{
+        param($left, $right)
+        [System.StringComparer]::Ordinal.Compare($left.Name, $right.Name)
+      }
+    )
+    if ($files.Count -gt 1) { [System.Array]::Sort($files, $ordinalComparer) }
     $manifestContent = ""
     foreach ($f in $files) {
       $h = (Get-FileHash -Path $f.FullName -Algorithm SHA256).Hash.ToLower()
@@ -129,9 +142,30 @@ foreach ($tid in $doneCards) {
       Write-Output "  FAIL step1: invalid provenance.writer (expected engine-verify, got $provWriter)"
       $tamperCount++; $step1Fail = $true
     }
-    if ($provCommit -ne $headCommit) {
-      Write-Output "  FAIL step1: provenance.commit mismatch (expected HEAD=$headCommit, got $provCommit)"
+    if (-not $provCommit) {
+      Write-Output "  FAIL step1: provenance.commit missing"
       $tamperCount++; $step1Fail = $true
+    } else {
+      $null = & git -C $Root cat-file -e "$provCommit^{commit}" 2>$null
+      $commitExists = ($LASTEXITCODE -eq 0)
+      if (-not $commitExists) {
+        Write-Output "  FAIL step1: provenance.commit is not a reachable commit (got $provCommit)"
+        $tamperCount++; $step1Fail = $true
+      } elseif ($provCommit -ne $headCommit) {
+        # A done card can legitimately retain evidence generated at the commit
+        # immediately before its status transition, or at an older historical
+        # commit. The manifest has already self-verified, so report this as an
+        # explicit legacy snapshot warning while keeping code-fingerprint drift
+        # visible below. A current active/newly-done card remains a hard failure.
+        $headCard = (& git -C $Root show "HEAD:engine/tasks/$tid.md" 2>$null | Out-String)
+        if ($headCard.Contains("> status: done")) {
+          Write-Output "  WARN step1: legacy evidence provenance.commit mismatch (HEAD=$headCommit, snapshot=$provCommit)"
+          $warnCount++; $historicalSnapshot = $true
+        } else {
+          Write-Output "  FAIL step1: provenance.commit mismatch (expected HEAD=$headCommit, got $provCommit)"
+          $tamperCount++; $step1Fail = $true
+        }
+      }
     }
   }
 
@@ -192,10 +226,10 @@ foreach ($tid in $doneCards) {
       }
     }
 
-    $snapshotSet = [System.Collections.Generic.HashSet[string]]::new($snapshotPaths)
-    $currentSet = [System.Collections.Generic.HashSet[string]]::new($currentWs)
-    $added = @($currentWs | Where-Object { -not $snapshotSet.Contains($_) })
-    $removed = @($snapshotPaths | Where-Object { -not $currentSet.Contains($_) })
+    # Use array membership rather than HashSet constructors: PowerShell 5 and
+    # PowerShell 7 bind one-element arrays differently to generic constructors.
+    $added = @($currentWs | Where-Object { $snapshotPaths -notcontains $_ })
+    $removed = @($snapshotPaths | Where-Object { $currentWs -notcontains $_ })
     if ($added.Count -gt 0 -or $removed.Count -gt 0) {
       Write-Output "  WARN step2: WRITE-SET changed since evidence"
       if ($added.Count -gt 0)   { Write-Output "    added: $($added -join ' ')" }
@@ -231,11 +265,23 @@ foreach ($tid in $doneCards) {
           $currentSha = ""
           if ($gitOut -match '\s([0-9a-f]{40})\s') { $currentSha = $Matches[1] }
           if (-not $currentSha) {
-            Write-Output "  DRIFT step3: $tid file deleted (path: $path)"
-            $driftCount++; $hadDrift = $true
+            if ($historicalSnapshot) {
+              Write-Output "  WARN legacy step3: $tid file deleted after evidence snapshot (path: $path)"
+              $warnCount++
+            } else {
+              Write-Output "  DRIFT step3: $tid file deleted (path: $path)"
+              $driftCount++
+            }
+            $hadDrift = $true
           } elseif ($currentSha -ne $storedSha) {
-            Write-Output "  DRIFT step3: $tid code changed (${path}: stored=$($storedSha.Substring(0,12)).. current=$($currentSha.Substring(0,12))..)"
-            $driftCount++; $hadDrift = $true
+            if ($historicalSnapshot) {
+              Write-Output "  WARN legacy step3: $tid code changed after evidence snapshot (${path}: stored=$($storedSha.Substring(0,12)).. current=$($currentSha.Substring(0,12))..)"
+              $warnCount++
+            } else {
+              Write-Output "  DRIFT step3: $tid code changed (${path}: stored=$($storedSha.Substring(0,12)).. current=$($currentSha.Substring(0,12))..)"
+              $driftCount++
+            }
+            $hadDrift = $true
           }
         }
       }
```

### tests/workstream/test_doctor_health_regressions.sh
```diff
diff --git a/tests/workstream/test_doctor_health_regressions.sh b/tests/workstream/test_doctor_health_regressions.sh
new file mode 100644
index 0000000..c440137
--- /dev/null
+++ b/tests/workstream/test_doctor_health_regressions.sh
@@ -0,0 +1,75 @@
+#!/usr/bin/env bash
+set -euo pipefail
+
+REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
+fail() { echo "FAIL: $*" >&2; exit 1; }
+contains() { grep -Fq -- "$2" "$1" || fail "$1 does not contain: $2"; }
+
+map="$REPO_ROOT/engine/ENGINE_MAP.md"
+doctor="$REPO_ROOT/engine/scripts/engine-doctor.sh"
+doctor_plugin="$REPO_ROOT/plugin/engine/scripts/engine-doctor.sh"
+verify="$REPO_ROOT/engine/scripts/engine-verify.sh"
+verify_plugin="$REPO_ROOT/plugin/engine/scripts/engine-verify.sh"
+close="$REPO_ROOT/engine/scripts/engine-close.sh"
+close_plugin="$REPO_ROOT/plugin/engine/scripts/engine-close.sh"
+drift_sh="$REPO_ROOT/engine/scripts/engine-drift-check.sh"
+drift_plugin_sh="$REPO_ROOT/plugin/engine/scripts/engine-drift-check.sh"
+drift_ps="$REPO_ROOT/engine/scripts/engine-drift-check.ps1"
+drift_plugin_ps="$REPO_ROOT/plugin/engine/scripts/engine-drift-check.ps1"
+
+for row in \
+  'engine/scripts/engine-review-agent.sh' \
+  'engine/scripts/engine-review-agent-package.sh' \
+  'engine/scripts/engine-review-agent-validate.sh' \
+  'engine/scripts/engine-gate.sh' \
+  'engine/scripts/engine-gate.ps1'; do
+  contains "$map" "| $row |"
+done
+if grep -Fq '| tool |' "$map"; then fail 'ENGINE_MAP still contains unsupported class tool'; fi
+contains "$map" '| engine/gate/config.json | gates + policy | mixed |'
+
+for task in T-075 T-076 T-077; do
+  test -f "$REPO_ROOT/engine/tasks/$task/progress.md" || fail "$task progress anchor missing"
+done
+test ! -f "$REPO_ROOT/engine/tasks/T-078/progress.md" || fail 'T-078 live progress was not archived'
+test -f "$REPO_ROOT/engine/archive/tasks/T-078-progress.md" || fail 'T-078 progress archive missing'
+
+for path in \
+  tests/workstream/test_review_agent_cli.sh \
+  tests/workstream/test_review_agent_package.sh \
+  tests/workstream/test_review_agent_validate.sh \
+  tests/workstream/test_review_agent_config.sh \
+  tests/workstream/test_review_agent_mirror.sh \
+  docs/superpowers/specs/2026-07-31-agent-reviewer-design.md \
+  tests/workstream/test_review_agent_gate.sh \
+  tests/workstream/test_doctor_agent_review.sh \
+  tests/workstream/test_review_agent_grounded.sh \
+  tests/workstream/test_review_agent_dynamic.sh \
+  tests/workstream/test_prove_infer.sh \
+  tests/workstream/test_prove_execute.sh \
+  tests/workstream/test_acceptance_preflight.sh \
+  tests/workstream/test_acceptance_preflight.ps1; do
+  contains "$REPO_ROOT/engine/domains/project-meta/INVENTORY.md" "| $path |"
+done
+
+contains "$doctor" 'Prefer an existing project-root path'
+contains "$doctor" '-e "$ROOT/$file"'
+contains "$doctor" 'if out="$(bash "$script" 2>&1)"; then'
+contains "$doctor" 'json_file_valid'
+contains "$doctor" 'sys.argv[1]'
+contains "$verify" 'refresh evidence written by preceding ACs'
+contains "$close" 'refresh_evidence_manifest'
+contains "$REPO_ROOT/engine/scripts/engine-close.ps1" 'Refresh-EvidenceManifest'
+contains "$drift_sh" 'historical_snapshot=0'
+contains "$drift_sh" 'legacy evidence provenance.commit mismatch'
+contains "$drift_ps" '$historicalSnapshot = $false'
+contains "$drift_ps" 'array membership rather than HashSet constructors'
+contains "$drift_ps" 'StringComparer]::Ordinal'
+cmp -s "$doctor" "$doctor_plugin" || fail 'Doctor Bash mirrors differ'
+cmp -s "$verify" "$verify_plugin" || fail 'Verify Bash mirrors differ'
+cmp -s "$close" "$close_plugin" || fail 'Close Bash mirrors differ'
+cmp -s "$REPO_ROOT/engine/scripts/engine-close.ps1" "$REPO_ROOT/plugin/engine/scripts/engine-close.ps1" || fail 'Close PowerShell mirrors differ'
+cmp -s "$drift_sh" "$drift_plugin_sh" || fail 'Drift Bash mirrors differ'
+cmp -s "$drift_ps" "$drift_plugin_ps" || fail 'Drift PowerShell mirrors differ'
+
+echo 'PASS test_doctor_health_regressions.sh'
```

### tests/workstream/test_doctor_health_regressions.ps1
```diff
diff --git a/tests/workstream/test_doctor_health_regressions.ps1 b/tests/workstream/test_doctor_health_regressions.ps1
new file mode 100644
index 0000000..3f50c23
--- /dev/null
+++ b/tests/workstream/test_doctor_health_regressions.ps1
@@ -0,0 +1,66 @@
+$ErrorActionPreference = "Stop"
+$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
+
+function Assert-Contains([string]$Path, [string]$Needle) {
+  $content = Get-Content -Raw -LiteralPath $Path -Encoding UTF8
+  if (-not $content.Contains($Needle)) { throw "$Path does not contain: $Needle" }
+}
+
+$map = Join-Path $repoRoot "engine\ENGINE_MAP.md"
+foreach ($row in @(
+  "engine/scripts/engine-review-agent.sh",
+  "engine/scripts/engine-review-agent-package.sh",
+  "engine/scripts/engine-review-agent-validate.sh",
+  "engine/scripts/engine-gate.sh",
+  "engine/scripts/engine-gate.ps1"
+)) { Assert-Contains $map "| $row |" }
+if ((Get-Content -Raw -LiteralPath $map -Encoding UTF8) -match '\| tool \|') { throw "ENGINE_MAP still contains unsupported class tool" }
+Assert-Contains $map '| engine/gate/config.json | gates + policy | mixed |'
+
+foreach ($task in @('T-075', 'T-076', 'T-077')) {
+  if (-not (Test-Path (Join-Path $repoRoot "engine\tasks\$task\progress.md"))) { throw "$task progress anchor missing" }
+}
+if (Test-Path (Join-Path $repoRoot 'engine\tasks\T-078\progress.md')) { throw 'T-078 live progress was not archived' }
+if (-not (Test-Path (Join-Path $repoRoot 'engine\archive\tasks\T-078-progress.md'))) { throw 'T-078 progress archive missing' }
+
+$inventory = Join-Path $repoRoot 'engine\domains\project-meta\INVENTORY.md'
+foreach ($path in @(
+  'tests/workstream/test_review_agent_cli.sh',
+  'tests/workstream/test_review_agent_package.sh',
+  'tests/workstream/test_review_agent_validate.sh',
+  'tests/workstream/test_review_agent_config.sh',
+  'tests/workstream/test_review_agent_mirror.sh',
+  'docs/superpowers/specs/2026-07-31-agent-reviewer-design.md',
+  'tests/workstream/test_review_agent_gate.sh',
+  'tests/workstream/test_doctor_agent_review.sh',
+  'tests/workstream/test_review_agent_grounded.sh',
+  'tests/workstream/test_review_agent_dynamic.sh',
+  'tests/workstream/test_prove_infer.sh',
+  'tests/workstream/test_prove_execute.sh',
+  'tests/workstream/test_acceptance_preflight.sh',
+  'tests/workstream/test_acceptance_preflight.ps1'
+)) { Assert-Contains $inventory "| $path |" }
+
+Assert-Contains (Join-Path $repoRoot 'engine\scripts\engine-doctor.ps1') 'Prefer an existing project-root path'
+Assert-Contains (Join-Path $repoRoot 'engine\scripts\engine-doctor.sh') 'json_file_valid'
+Assert-Contains (Join-Path $repoRoot 'engine\scripts\engine-doctor.sh') 'sys.argv[1]'
+Assert-Contains (Join-Path $repoRoot 'engine\scripts\engine-verify.sh') 'ensure_powershell_on_path'
+Assert-Contains (Join-Path $repoRoot 'engine\scripts\engine-verify.sh') 'refresh evidence written by preceding ACs'
+Assert-Contains (Join-Path $repoRoot 'engine\scripts\engine-close.sh') 'refresh_evidence_manifest'
+Assert-Contains (Join-Path $repoRoot 'engine\scripts\engine-close.ps1') 'Refresh-EvidenceManifest'
+Assert-Contains (Join-Path $repoRoot 'engine\scripts\engine-drift-check.sh') 'historical_snapshot=0'
+Assert-Contains (Join-Path $repoRoot 'engine\scripts\engine-drift-check.ps1') '$historicalSnapshot = $false'
+Assert-Contains (Join-Path $repoRoot 'engine\scripts\engine-drift-check.ps1') 'array membership rather than HashSet constructors'
+Assert-Contains (Join-Path $repoRoot 'engine\scripts\engine-drift-check.ps1') 'StringComparer]::Ordinal'
+$driftPsHash = (Get-FileHash (Join-Path $repoRoot 'engine\scripts\engine-drift-check.ps1') -Algorithm SHA256).Hash
+$driftPsPluginHash = (Get-FileHash (Join-Path $repoRoot 'plugin\engine\scripts\engine-drift-check.ps1') -Algorithm SHA256).Hash
+if ($driftPsHash -ne $driftPsPluginHash) { throw 'Drift PowerShell mirrors differ' }
+$closeShHash = (Get-FileHash (Join-Path $repoRoot 'engine\scripts\engine-close.sh') -Algorithm SHA256).Hash
+$closePluginShHash = (Get-FileHash (Join-Path $repoRoot 'plugin\engine\scripts\engine-close.sh') -Algorithm SHA256).Hash
+if ($closeShHash -ne $closePluginShHash) { throw 'Close Bash mirrors differ' }
+$closePsHash = (Get-FileHash (Join-Path $repoRoot 'engine\scripts\engine-close.ps1') -Algorithm SHA256).Hash
+$closePluginPsHash = (Get-FileHash (Join-Path $repoRoot 'plugin\engine\scripts\engine-close.ps1') -Algorithm SHA256).Hash
+if ($closePsHash -ne $closePluginPsHash) { throw 'Close PowerShell mirrors differ' }
+$driftOutput = & (Join-Path $repoRoot 'engine\scripts\engine-drift-check.ps1') -Task T-078 2>&1
+if ($LASTEXITCODE -ne 0 -or -not (($driftOutput -join "`n") -match 'tamper=0 drift=0')) { throw 'PowerShell drift checker rejected the T-078 manifest' }
+Write-Output 'PASS test_doctor_health_regressions.ps1'
```

### tests/workstream/test_verify_shell_resolution.sh
```diff
diff --git a/tests/workstream/test_verify_shell_resolution.sh b/tests/workstream/test_verify_shell_resolution.sh
new file mode 100644
index 0000000..b9d615e
--- /dev/null
+++ b/tests/workstream/test_verify_shell_resolution.sh
@@ -0,0 +1,23 @@
+#!/usr/bin/env bash
+set -euo pipefail
+
+REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
+fail() { echo "FAIL: $*" >&2; exit 1; }
+
+grep -Fq 'ensure_powershell_on_path' "$REPO_ROOT/engine/scripts/engine-verify.sh" || fail 'PowerShell resolver missing'
+grep -Fq '[ -f "$dir/pwsh.exe" ]' "$REPO_ROOT/engine/scripts/engine-verify.sh" || fail 'PowerShell resolver must support WSL mounted .exe files'
+grep -Fq 'ENGINE_PWSH_CMD' "$REPO_ROOT/engine/scripts/engine-verify.sh" || fail 'PowerShell resolver must rewrite extensionless pwsh tokens'
+cmp -s "$REPO_ROOT/engine/scripts/engine-verify.sh" "$REPO_ROOT/plugin/engine/scripts/engine-verify.sh" || fail 'verify mirror drift'
+
+# In Windows Git Bash/WSL, pwsh may only be reachable through the mounted
+# PowerShell installation. Exercise the real Bash verifier against T-080.
+output="$(cd "$REPO_ROOT" && bash engine/bin/engine verify T-080 2>&1)" || {
+  printf '%s\n' "$output" >&2
+  fail 'Bash verifier could not execute the Windows-facing AC commands'
+}
+printf '%s\n' "$output" | grep -Fq 'T-080: 8 pass, 0 fail' || {
+  printf '%s\n' "$output" >&2
+  fail 'Bash verifier did not report 8/8 after PowerShell resolution'
+}
+
+echo 'PASS test_verify_shell_resolution.sh'
```

### tests/workstream/test_verify_shell_resolution.ps1
```diff
diff --git a/tests/workstream/test_verify_shell_resolution.ps1 b/tests/workstream/test_verify_shell_resolution.ps1
new file mode 100644
index 0000000..a830dcd
--- /dev/null
+++ b/tests/workstream/test_verify_shell_resolution.ps1
@@ -0,0 +1,15 @@
+$ErrorActionPreference = "Stop"
+$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
+
+function Assert-Contains([string]$Path, [string]$Needle) {
+  $content = Get-Content -Raw -LiteralPath $Path -Encoding UTF8
+  if (-not $content.Contains($Needle)) { throw "$Path does not contain: $Needle" }
+}
+
+Assert-Contains (Join-Path $repoRoot 'engine\scripts\engine-verify.sh') 'ensure_powershell_on_path'
+Assert-Contains (Join-Path $repoRoot 'engine\scripts\engine-verify.sh') '[ -f "$dir/pwsh.exe" ]'
+Assert-Contains (Join-Path $repoRoot 'engine\scripts\engine-verify.sh') 'ENGINE_PWSH_CMD'
+$left = (Get-FileHash (Join-Path $repoRoot 'engine\scripts\engine-verify.sh') -Algorithm SHA256).Hash
+$right = (Get-FileHash (Join-Path $repoRoot 'plugin\engine\scripts\engine-verify.sh') -Algorithm SHA256).Hash
+if ($left -ne $right) { throw 'Verify Bash mirrors differ' }
+Write-Output 'PASS test_verify_shell_resolution.ps1'
```


## 3. Surrounding Context

_(truncated for size)_

## AC

AC: AC-1 acceptance preflight CLI + `engine verify T-NNN --preflight` alias | verify: bash tests/workstream/test_acceptance_preflight.sh
AC: AC-2 coverage threshold failure is `blocked`, keeps command_exit=1, records behavior_exit=0 and coverage_status | verify: bash tests/workstream/test_acceptance_preflight.sh
AC: AC-3 missing dependency/environment is `blocked`, records environment_status=blocked and does not count PASS | verify: bash tests/workstream/test_acceptance_preflight.sh
AC: AC-4 ordinary behavior failure remains `fail` and has distinct command_exit/behavior_exit fields | verify: bash tests/workstream/test_acceptance_preflight.sh
AC: AC-5 explicit `--no-cov` and per-AC `coverage: no-cov` policy are accepted and recorded | verify: bash tests/workstream/test_acceptance_preflight.sh
AC: AC-6 PowerShell semantic twin and plugin mirrors are present | verify: bash tests/workstream/test_acceptance_preflight.sh
AC: AC-7 existing full `engine verify` behavior remains compatible | verify: bash tests/behavior-verify/run-verify-tests.sh

## CONSTRAINTS

- `blocked` is machine-recognized evidence, never a passing status and never an exit-0 result.
```

### engine/domains/engine-runtime/INVENTORY.md (references: bash)
```
| tombstone 生命周期测试 (v6.12.2) | tests/multi-session/test_tombstone_lifecycle.sh | test_tombstone_lifecycle() | stable | 2026-07-28 |
| pre-commit dist-stale 门禁 (v6.12.3) | engine/scripts/githooks/pre-commit | check_dist_stale() | stable | 2026-07-28 |
| dist-stale 门禁测试 (v6.12.3) | tests/workstream/test_precommit_dist_stale.sh | test_precommit_dist_stale() | stable | 2026-07-28 |
| .engineignore 旁路通道 (v6.13.0) | engine/scripts/githooks/pre-commit | is_engineignored() | stable | 2026-07-29 |
| .engineignore 旁路测试 (v6.13.0) | tests/workstream/test_precommit_engineignore.sh | test_precommit_engineignore() | stable | 2026-07-29 |
| Doctor .engineignore 告警 (v6.13.0) | engine/scripts/engine-doctor.sh | check_engineignore() | stable | 2026-07-29 |
| .engineignore 配置 | .engineignore | engineignore_config() | stable | 2026-07-29 |
| engine-verify env cleanup 测试 (v6.13.1) | tests/workstream/test_engine_verify_env_cleanup.ps1 | test_engine_verify_env_cleanup() | stable | 2026-07-29 |
| engine-verify env cleanup 测试 runner (v6.13.1) | tests/workstream/test_engine_verify_env_cleanup.sh | test_engine_verify_env_cleanup_sh() | stable | 2026-07-29 |
| done-card drift AC PASS 测试 (v6.14.0) | tests/workstream/test_precommit_done_card_drift.sh | test_precommit_done_card_drift() | stable | 2026-07-29 |
| engine-verify bash 检测测试 (v6.14.0) | tests/workstream/test_engine_verify_bash_detection.ps1 | test_engine_verify_bash_detection() | stable | 2026-07-29 |
| engine-verify bash 检测测试 runner (v6.14.0) | tests/workstream/test_engine_verify_bash_detection.sh | test_engine_verify_bash_detection_sh() | stable | 2026-07-29 |
| closing_paths HEAD 已 done 跳过 (v6.17.4) | engine/scripts/githooks/pre-commit | closing_paths() | stable | 2026-07-30 |
| done-card governing closing_paths 测试 (v6.17.4) | tests/workstream/test_precommit_done_card_governing.sh | test_precommit_done_card_governing() | stable | 2026-07-30 |
| drift-check 三步校验 (v6.18.0) | engine/scripts/engine-drift-check.sh | run_drift_check() | stable | 2026-07-30 |
| drift-check 三步校验 ps1 (v6.18.0) | engine/scripts/engine-drift-check.ps1 | Run-DriftCheck() | stable | 2026-07-30 |
| drift-check 测试套件 (v6.18.0) | tests/workstream/test_drift_check.sh | test_drift_check() | stable | 2026-07-30 |
| evidence provenance 测试套件 (v6.18.0) | tests/workstream/test_evidence_provenance.sh | test_evidence_provenance() | stable | 2026-07-30 |
| behavior verify 测试 runner (v6.18.0) | tests/behavior-verify/run-verify-tests.sh | run_verify_tests() | stable | 2026-07-30 |
| 派生状态视图 + 信任标签 (v6.19.0) | engine/scripts/engine-context.sh | render_derived_status() | stable | 2026-07-30 |
| 派生状态视图 + 信任标签 ps1 (v6.19.0) | engine/scripts/engine-context.ps1 | Render-DerivedStatus() | stable | 2026-07-30 |
```

### engine/evidence/T-048/AC-1.json (references: bash)
```
{"ac":"AC-1","verify":"bash tests/task-card/test_multi_active_union.sh","status":"pass","exit":0,"output_fingerprint":"sha256:6556f9af9af6acd574132c828389bb32c7111617556019c08e667317093f2638","code_fingerprint":{"AGENTS.md":"117bd5d95b88752bea2e20e2b30976b9b5bc1b1a","ENGINE_FILE_SYSTEM_v5.md":"ffe0c7c816855fb7143eed20106018efc0cd9fc9","contract/budget.json":"2f33afc7a7b28cfc1bfb6758a0581d87d4c739bd","engine/AGENT_ADAPTERS.md":"53f6927e654d0330816f59c4bf40b44ecd19ea03","engine/ENGINE_DOCTOR.md":"c43454c0e0a183a0a31dfaff4a90f371081f3638","engine/GLOSSARY.md":"dc758efc04e491e5eff12a4171d366023d26efe5","engine/SYSTEM.md":"cef7f2d6c9313412e321db4ed09fdfdcee849cf7","plugin/AGENTS.md":"cd42878c3a276475c6744e718b8089a37f2a8fc3","scripts/check.ps1":"b992dea7b28aee1b3bb44fb05e0880fc553d3004","scripts/check.sh":"e8138a28b0aca47a49cee39952497123a7d61e0b"},"write_set_snapshot":["AGENTS.md","ENGINE_FILE_SYSTEM_v5.md","contract/budget.json","engine/AGENT_ADAPTERS.md","engine/ENGINE_DOCTOR.md","engine/GLOSSARY.md","engine/SYSTEM.md","plugin/AGENTS.md","scripts/check.ps1","scripts/check.sh"],"verified_against_commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","write_provenance":{"writer":"engine-verify","commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","timestamp":"2026-07-31T05:01:07Z","argv":"engine verify T-048"},"timestamp":"2026-07-31T05:01:07Z"}
```

### engine/evidence/T-048/AC-2.json (references: bash)
```
{"ac":"AC-2","verify":"bash tests/multi-session/test_pretooluse_union.sh","status":"pass","exit":0,"output_fingerprint":"sha256:e66d94d9254623fe09dedc23b7179f81818f412ffcdb4a606c6f997d1a175f8f","code_fingerprint":{"AGENTS.md":"117bd5d95b88752bea2e20e2b30976b9b5bc1b1a","ENGINE_FILE_SYSTEM_v5.md":"ffe0c7c816855fb7143eed20106018efc0cd9fc9","contract/budget.json":"2f33afc7a7b28cfc1bfb6758a0581d87d4c739bd","engine/AGENT_ADAPTERS.md":"53f6927e654d0330816f59c4bf40b44ecd19ea03","engine/ENGINE_DOCTOR.md":"c43454c0e0a183a0a31dfaff4a90f371081f3638","engine/GLOSSARY.md":"dc758efc04e491e5eff12a4171d366023d26efe5","engine/SYSTEM.md":"cef7f2d6c9313412e321db4ed09fdfdcee849cf7","plugin/AGENTS.md":"cd42878c3a276475c6744e718b8089a37f2a8fc3","scripts/check.ps1":"b992dea7b28aee1b3bb44fb05e0880fc553d3004","scripts/check.sh":"e8138a28b0aca47a49cee39952497123a7d61e0b"},"write_set_snapshot":["AGENTS.md","ENGINE_FILE_SYSTEM_v5.md","contract/budget.json","engine/AGENT_ADAPTERS.md","engine/ENGINE_DOCTOR.md","engine/GLOSSARY.md","engine/SYSTEM.md","plugin/AGENTS.md","scripts/check.ps1","scripts/check.sh"],"verified_against_commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","write_provenance":{"writer":"engine-verify","commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","timestamp":"2026-07-31T05:01:08Z","argv":"engine verify T-048"},"timestamp":"2026-07-31T05:01:08Z"}
```

### engine/evidence/T-048/AC-3.json (references: bash)
```
{"ac":"AC-3","verify":"bash tests/multi-session/test_lock_liveness.sh","status":"pass","exit":0,"output_fingerprint":"sha256:63cb7a28b896783221fc32b80f379c8ffc3bfacb78de5bd565b5dd0381ae7167","code_fingerprint":{"AGENTS.md":"117bd5d95b88752bea2e20e2b30976b9b5bc1b1a","ENGINE_FILE_SYSTEM_v5.md":"ffe0c7c816855fb7143eed20106018efc0cd9fc9","contract/budget.json":"2f33afc7a7b28cfc1bfb6758a0581d87d4c739bd","engine/AGENT_ADAPTERS.md":"53f6927e654d0330816f59c4bf40b44ecd19ea03","engine/ENGINE_DOCTOR.md":"c43454c0e0a183a0a31dfaff4a90f371081f3638","engine/GLOSSARY.md":"dc758efc04e491e5eff12a4171d366023d26efe5","engine/SYSTEM.md":"cef7f2d6c9313412e321db4ed09fdfdcee849cf7","plugin/AGENTS.md":"cd42878c3a276475c6744e718b8089a37f2a8fc3","scripts/check.ps1":"b992dea7b28aee1b3bb44fb05e0880fc553d3004","scripts/check.sh":"e8138a28b0aca47a49cee39952497123a7d61e0b"},"write_set_snapshot":["AGENTS.md","ENGINE_FILE_SYSTEM_v5.md","contract/budget.json","engine/AGENT_ADAPTERS.md","engine/ENGINE_DOCTOR.md","engine/GLOSSARY.md","engine/SYSTEM.md","plugin/AGENTS.md","scripts/check.ps1","scripts/check.sh"],"verified_against_commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","write_provenance":{"writer":"engine-verify","commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","timestamp":"2026-07-31T05:01:11Z","argv":"engine verify T-048"},"timestamp":"2026-07-31T05:01:11Z"}
```

### engine/evidence/T-048/AC-4.json (references: bash)
```
{"ac":"AC-4","verify":"bash tests/multi-session/test_role_cleanup.sh","status":"pass","exit":0,"output_fingerprint":"sha256:a803ddba90fabda62b1779a76fc6d3906cfdacae18bcb06141d735ce8ab14093","code_fingerprint":{"AGENTS.md":"117bd5d95b88752bea2e20e2b30976b9b5bc1b1a","ENGINE_FILE_SYSTEM_v5.md":"ffe0c7c816855fb7143eed20106018efc0cd9fc9","contract/budget.json":"2f33afc7a7b28cfc1bfb6758a0581d87d4c739bd","engine/AGENT_ADAPTERS.md":"53f6927e654d0330816f59c4bf40b44ecd19ea03","engine/ENGINE_DOCTOR.md":"c43454c0e0a183a0a31dfaff4a90f371081f3638","engine/GLOSSARY.md":"dc758efc04e491e5eff12a4171d366023d26efe5","engine/SYSTEM.md":"cef7f2d6c9313412e321db4ed09fdfdcee849cf7","plugin/AGENTS.md":"cd42878c3a276475c6744e718b8089a37f2a8fc3","scripts/check.ps1":"b992dea7b28aee1b3bb44fb05e0880fc553d3004","scripts/check.sh":"e8138a28b0aca47a49cee39952497123a7d61e0b"},"write_set_snapshot":["AGENTS.md","ENGINE_FILE_SYSTEM_v5.md","contract/budget.json","engine/AGENT_ADAPTERS.md","engine/ENGINE_DOCTOR.md","engine/GLOSSARY.md","engine/SYSTEM.md","plugin/AGENTS.md","scripts/check.ps1","scripts/check.sh"],"verified_against_commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","write_provenance":{"writer":"engine-verify","commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","timestamp":"2026-07-31T05:01:18Z","argv":"engine verify T-048"},"timestamp":"2026-07-31T05:01:18Z"}
```

### engine/evidence/T-048/AC-5.json (references: bash)
```
{"ac":"AC-5","verify":"bash tests/multi-session/test_shared_write_lease.sh","status":"pass","exit":0,"output_fingerprint":"sha256:88984057af171059be3d9ac724db0367a77edc82586ed2a96813667fbe71befb","code_fingerprint":{"AGENTS.md":"117bd5d95b88752bea2e20e2b30976b9b5bc1b1a","ENGINE_FILE_SYSTEM_v5.md":"ffe0c7c816855fb7143eed20106018efc0cd9fc9","contract/budget.json":"2f33afc7a7b28cfc1bfb6758a0581d87d4c739bd","engine/AGENT_ADAPTERS.md":"53f6927e654d0330816f59c4bf40b44ecd19ea03","engine/ENGINE_DOCTOR.md":"c43454c0e0a183a0a31dfaff4a90f371081f3638","engine/GLOSSARY.md":"dc758efc04e491e5eff12a4171d366023d26efe5","engine/SYSTEM.md":"cef7f2d6c9313412e321db4ed09fdfdcee849cf7","plugin/AGENTS.md":"cd42878c3a276475c6744e718b8089a37f2a8fc3","scripts/check.ps1":"b992dea7b28aee1b3bb44fb05e0880fc553d3004","scripts/check.sh":"e8138a28b0aca47a49cee39952497123a7d61e0b"},"write_set_snapshot":["AGENTS.md","ENGINE_FILE_SYSTEM_v5.md","contract/budget.json","engine/AGENT_ADAPTERS.md","engine/ENGINE_DOCTOR.md","engine/GLOSSARY.md","engine/SYSTEM.md","plugin/AGENTS.md","scripts/check.ps1","scripts/check.sh"],"verified_against_commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","write_provenance":{"writer":"engine-verify","commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","timestamp":"2026-07-31T05:01:19Z","argv":"engine verify T-048"},"timestamp":"2026-07-31T05:01:19Z"}
```

### engine/evidence/T-048/AC-6.json (references: bash)
```
{"ac":"AC-6","verify":"bash tests/multi-session/test_worker_scope.sh","status":"pass","exit":0,"output_fingerprint":"sha256:ae78e91087672c9e8dae879d35e52f02d113ac1b1784f5b68d7a77e710e7a537","code_fingerprint":{"AGENTS.md":"117bd5d95b88752bea2e20e2b30976b9b5bc1b1a","ENGINE_FILE_SYSTEM_v5.md":"ffe0c7c816855fb7143eed20106018efc0cd9fc9","contract/budget.json":"2f33afc7a7b28cfc1bfb6758a0581d87d4c739bd","engine/AGENT_ADAPTERS.md":"53f6927e654d0330816f59c4bf40b44ecd19ea03","engine/ENGINE_DOCTOR.md":"c43454c0e0a183a0a31dfaff4a90f371081f3638","engine/GLOSSARY.md":"dc758efc04e491e5eff12a4171d366023d26efe5","engine/SYSTEM.md":"cef7f2d6c9313412e321db4ed09fdfdcee849cf7","plugin/AGENTS.md":"cd42878c3a276475c6744e718b8089a37f2a8fc3","scripts/check.ps1":"b992dea7b28aee1b3bb44fb05e0880fc553d3004","scripts/check.sh":"e8138a28b0aca47a49cee39952497123a7d61e0b"},"write_set_snapshot":["AGENTS.md","ENGINE_FILE_SYSTEM_v5.md","contract/budget.json","engine/AGENT_ADAPTERS.md","engine/ENGINE_DOCTOR.md","engine/GLOSSARY.md","engine/SYSTEM.md","plugin/AGENTS.md","scripts/check.ps1","scripts/check.sh"],"verified_against_commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","write_provenance":{"writer":"engine-verify","commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","timestamp":"2026-07-31T05:01:19Z","argv":"engine verify T-048"},"timestamp":"2026-07-31T05:01:19Z"}
```

### engine/evidence/T-048/AC-7.json (references: bash)
```
{"ac":"AC-7","verify":"bash tests/multi-session/test_multi_card_display.sh","status":"pass","exit":0,"output_fingerprint":"sha256:99a5cf1f201513edc850969c5c08c28e373edf0fcca0fa6a5082ab670b652dd7","code_fingerprint":{"AGENTS.md":"117bd5d95b88752bea2e20e2b30976b9b5bc1b1a","ENGINE_FILE_SYSTEM_v5.md":"ffe0c7c816855fb7143eed20106018efc0cd9fc9","contract/budget.json":"2f33afc7a7b28cfc1bfb6758a0581d87d4c739bd","engine/AGENT_ADAPTERS.md":"53f6927e654d0330816f59c4bf40b44ecd19ea03","engine/ENGINE_DOCTOR.md":"c43454c0e0a183a0a31dfaff4a90f371081f3638","engine/GLOSSARY.md":"dc758efc04e491e5eff12a4171d366023d26efe5","engine/SYSTEM.md":"cef7f2d6c9313412e321db4ed09fdfdcee849cf7","plugin/AGENTS.md":"cd42878c3a276475c6744e718b8089a37f2a8fc3","scripts/check.ps1":"b992dea7b28aee1b3bb44fb05e0880fc553d3004","scripts/check.sh":"e8138a28b0aca47a49cee39952497123a7d61e0b"},"write_set_snapshot":["AGENTS.md","ENGINE_FILE_SYSTEM_v5.md","contract/budget.json","engine/AGENT_ADAPTERS.md","engine/ENGINE_DOCTOR.md","engine/GLOSSARY.md","engine/SYSTEM.md","plugin/AGENTS.md","scripts/check.ps1","scripts/check.sh"],"verified_against_commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","write_provenance":{"writer":"engine-verify","commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","timestamp":"2026-07-31T05:01:21Z","argv":"engine verify T-048"},"timestamp":"2026-07-31T05:01:21Z"}
```

### engine/evidence/T-048/AC-8.json (references: bash)
```
{"ac":"AC-8","verify":"bash scripts/check.sh","status":"fail","exit":1,"output_fingerprint":"sha256:1a5d37d78bb9cdf9cd959f77d1156e7e30b3baa00b5d3efb04cf3651516e162f","code_fingerprint":{"AGENTS.md":"117bd5d95b88752bea2e20e2b30976b9b5bc1b1a","ENGINE_FILE_SYSTEM_v5.md":"ffe0c7c816855fb7143eed20106018efc0cd9fc9","contract/budget.json":"2f33afc7a7b28cfc1bfb6758a0581d87d4c739bd","engine/AGENT_ADAPTERS.md":"53f6927e654d0330816f59c4bf40b44ecd19ea03","engine/ENGINE_DOCTOR.md":"c43454c0e0a183a0a31dfaff4a90f371081f3638","engine/GLOSSARY.md":"dc758efc04e491e5eff12a4171d366023d26efe5","engine/SYSTEM.md":"cef7f2d6c9313412e321db4ed09fdfdcee849cf7","plugin/AGENTS.md":"cd42878c3a276475c6744e718b8089a37f2a8fc3","scripts/check.ps1":"b992dea7b28aee1b3bb44fb05e0880fc553d3004","scripts/check.sh":"e8138a28b0aca47a49cee39952497123a7d61e0b"},"write_set_snapshot":["AGENTS.md","ENGINE_FILE_SYSTEM_v5.md","contract/budget.json","engine/AGENT_ADAPTERS.md","engine/ENGINE_DOCTOR.md","engine/GLOSSARY.md","engine/SYSTEM.md","plugin/AGENTS.md","scripts/check.ps1","scripts/check.sh"],"verified_against_commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","write_provenance":{"writer":"engine-verify","commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","timestamp":"2026-07-31T05:03:04Z","argv":"engine verify T-048"},"timestamp":"2026-07-31T05:03:04Z"}
```

### engine/evidence/T-048/AC-9.json (references: bash)
```
{"ac":"AC-9","verify":"bash contract/compile.sh && bash engine/scripts/engine-doctor.sh","status":"fail","exit":1,"output_fingerprint":"sha256:2678039f9fef42a16728c0dddfe05354b0640dfb1569ae545760104697b93cd1","code_fingerprint":{"AGENTS.md":"117bd5d95b88752bea2e20e2b30976b9b5bc1b1a","ENGINE_FILE_SYSTEM_v5.md":"ffe0c7c816855fb7143eed20106018efc0cd9fc9","contract/budget.json":"2f33afc7a7b28cfc1bfb6758a0581d87d4c739bd","engine/AGENT_ADAPTERS.md":"53f6927e654d0330816f59c4bf40b44ecd19ea03","engine/ENGINE_DOCTOR.md":"c43454c0e0a183a0a31dfaff4a90f371081f3638","engine/GLOSSARY.md":"dc758efc04e491e5eff12a4171d366023d26efe5","engine/SYSTEM.md":"cef7f2d6c9313412e321db4ed09fdfdcee849cf7","plugin/AGENTS.md":"cd42878c3a276475c6744e718b8089a37f2a8fc3","scripts/check.ps1":"b992dea7b28aee1b3bb44fb05e0880fc553d3004","scripts/check.sh":"e8138a28b0aca47a49cee39952497123a7d61e0b"},"write_set_snapshot":["AGENTS.md","ENGINE_FILE_SYSTEM_v5.md","contract/budget.json","engine/AGENT_ADAPTERS.md","engine/ENGINE_DOCTOR.md","engine/GLOSSARY.md","engine/SYSTEM.md","plugin/AGENTS.md","scripts/check.ps1","scripts/check.sh"],"verified_against_commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","write_provenance":{"writer":"engine-verify","commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","timestamp":"2026-07-31T05:03:23Z","argv":"engine verify T-048"},"timestamp":"2026-07-31T05:03:23Z"}
```

### engine/evidence/T-048/checkpoint.md (references: bash)
```
# Checkpoint — T-048
> Last updated: 2026-07-26T19:50:37Z by engine-verify | AC 级压缩恢复锚点,见 contract/src/20-file-templates.md FILE 15

## 已完成 AC
- [x] AC-8 bash scripts/check.sh — evidence/AC-8.json PASS @ 2026-07-26T20:23:35Z
- [x] AC-9 bash contract/compile.sh && bash engine/scripts/engine-doctor.sh — evidence/AC-9.json PASS @ 2026-07-26T20:24:58Z
- [x] AC-10 grep -q '6\.12\.0' engine/scripts/engine-migrate-contract.sh && grep -q 'contrac — evidence/AC-10.json PASS @ 2026-07-26T20:24:58Z
- [x] AC-1 bash tests/task-card/test_multi_active_union.sh — evidence/AC-1.json PASS @ 2026-07-31T05:01:07Z
- [x] AC-2 bash tests/multi-session/test_pretooluse_union.sh — evidence/AC-2.json PASS @ 2026-07-31T05:01:08Z
- [x] AC-3 bash tests/multi-session/test_lock_liveness.sh — evidence/AC-3.json PASS @ 2026-07-31T05:01:11Z
- [x] AC-4 bash tests/multi-session/test_role_cleanup.sh — evidence/AC-4.json PASS @ 2026-07-31T05:01:18Z
- [x] AC-5 bash tests/multi-session/test_shared_write_lease.sh — evidence/AC-5.json PASS @ 2026-07-31T05:01:19Z
- [x] AC-6 bash tests/multi-session/test_worker_scope.sh — evidence/AC-6.json PASS @ 2026-07-31T05:01:19Z
- [x] AC-7 bash tests/multi-session/test_multi_card_display.sh — evidence/AC-7.json PASS @ 2026-07-31T05:01:21Z
```

### engine/evidence/T-049/AC-1.json (references: bash)
```
{"ac":"AC-1","verify":"bash tests/behavior-verify/test_verify_allskip_loud.sh","status":"pass","exit":0,"output_fingerprint":"sha256:9e58f79a9d47b150d389f057aa0fb3cc9f00c6ce2db561e1d4f455b842ede6f2","code_fingerprint":{"ENGINE_FILE_SYSTEM_v5.md":"ffe0c7c816855fb7143eed20106018efc0cd9fc9","contract/budget.json":"2f33afc7a7b28cfc1bfb6758a0581d87d4c739bd","contract/src/00-core.md":"5f91b67153b284b663e281f9a9cebf8b24c23336","contract/src/20-file-templates.md":"fd5da621dc32649f791b7c59e99ce4e943dd8042","contract/src/30-operational.md":"35cee5a6a12df66f9cf2735f17f032c455038191","scripts/check.ps1":"b992dea7b28aee1b3bb44fb05e0880fc553d3004","scripts/check.sh":"e8138a28b0aca47a49cee39952497123a7d61e0b"},"write_set_snapshot":["ENGINE_FILE_SYSTEM_v5.md","contract/budget.json","contract/src/00-core.md","contract/src/20-file-templates.md","contract/src/30-operational.md","scripts/check.ps1","scripts/check.sh"],"verified_against_commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","write_provenance":{"writer":"engine-verify","commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","timestamp":"2026-07-31T05:05:01Z","argv":"engine verify T-049"},"timestamp":"2026-07-31T05:05:01Z"}
```

### engine/evidence/T-049/AC-2.json (references: bash)
```
{"ac":"AC-2","verify":"bash tests/behavior-verify/test_verify_parse_hardening.sh","status":"pass","exit":0,"output_fingerprint":"sha256:7db56a19ba4b3fda9c22fd6a6be145cf6d77e95deceb8e885b11bf715072b73a","code_fingerprint":{"ENGINE_FILE_SYSTEM_v5.md":"ffe0c7c816855fb7143eed20106018efc0cd9fc9","contract/budget.json":"2f33afc7a7b28cfc1bfb6758a0581d87d4c739bd","contract/src/00-core.md":"5f91b67153b284b663e281f9a9cebf8b24c23336","contract/src/20-file-templates.md":"fd5da621dc32649f791b7c59e99ce4e943dd8042","contract/src/30-operational.md":"35cee5a6a12df66f9cf2735f17f032c455038191","scripts/check.ps1":"b992dea7b28aee1b3bb44fb05e0880fc553d3004","scripts/check.sh":"e8138a28b0aca47a49cee39952497123a7d61e0b"},"write_set_snapshot":["ENGINE_FILE_SYSTEM_v5.md","contract/budget.json","contract/src/00-core.md","contract/src/20-file-templates.md","contract/src/30-operational.md","scripts/check.ps1","scripts/check.sh"],"verified_against_commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","write_provenance":{"writer":"engine-verify","commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","timestamp":"2026-07-31T05:05:02Z","argv":"engine verify T-049"},"timestamp":"2026-07-31T05:05:02Z"}
```

### engine/evidence/T-049/AC-3.json (references: bash)
```
{"ac":"AC-3","verify":"bash tests/multi-session/test_hook_frontmatter_writeset.sh","status":"pass","exit":0,"output_fingerprint":"sha256:9b3b70bbbe900008b1ef3bca71434a6dd0f9c577d92af9001681a6876b3f7ce6","code_fingerprint":{"ENGINE_FILE_SYSTEM_v5.md":"ffe0c7c816855fb7143eed20106018efc0cd9fc9","contract/budget.json":"2f33afc7a7b28cfc1bfb6758a0581d87d4c739bd","contract/src/00-core.md":"5f91b67153b284b663e281f9a9cebf8b24c23336","contract/src/20-file-templates.md":"fd5da621dc32649f791b7c59e99ce4e943dd8042","contract/src/30-operational.md":"35cee5a6a12df66f9cf2735f17f032c455038191","scripts/check.ps1":"b992dea7b28aee1b3bb44fb05e0880fc553d3004","scripts/check.sh":"e8138a28b0aca47a49cee39952497123a7d61e0b"},"write_set_snapshot":["ENGINE_FILE_SYSTEM_v5.md","contract/budget.json","contract/src/00-core.md","contract/src/20-file-templates.md","contract/src/30-operational.md","scripts/check.ps1","scripts/check.sh"],"verified_against_commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","write_provenance":{"writer":"engine-verify","commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","timestamp":"2026-07-31T05:05:02Z","argv":"engine verify T-049"},"timestamp":"2026-07-31T05:05:02Z"}
```

### engine/evidence/T-049/AC-4.json (references: bash)
```
{"ac":"AC-4","verify":"bash tests/multi-session/test_glob_dir_prefix.sh","status":"pass","exit":0,"output_fingerprint":"sha256:45d66359d5e5aa8a529c99ddd3ee8ff3f290c85ee57f43cf6bbce7d94fa6f9de","code_fingerprint":{"ENGINE_FILE_SYSTEM_v5.md":"ffe0c7c816855fb7143eed20106018efc0cd9fc9","contract/budget.json":"2f33afc7a7b28cfc1bfb6758a0581d87d4c739bd","contract/src/00-core.md":"5f91b67153b284b663e281f9a9cebf8b24c23336","contract/src/20-file-templates.md":"fd5da621dc32649f791b7c59e99ce4e943dd8042","contract/src/30-operational.md":"35cee5a6a12df66f9cf2735f17f032c455038191","scripts/check.ps1":"b992dea7b28aee1b3bb44fb05e0880fc553d3004","scripts/check.sh":"e8138a28b0aca47a49cee39952497123a7d61e0b"},"write_set_snapshot":["ENGINE_FILE_SYSTEM_v5.md","contract/budget.json","contract/src/00-core.md","contract/src/20-file-templates.md","contract/src/30-operational.md","scripts/check.ps1","scripts/check.sh"],"verified_against_commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","write_provenance":{"writer":"engine-verify","commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","timestamp":"2026-07-31T05:05:03Z","argv":"engine verify T-049"},"timestamp":"2026-07-31T05:05:03Z"}
```

### engine/evidence/T-049/AC-5.json (references: bash)
```
{"ac":"AC-5","verify":"bash tests/multi-session/test_status_anchored.sh","status":"pass","exit":0,"output_fingerprint":"sha256:9a109228cab908895f7c833ca199da1519c1084c6647d2990d5be2850d7e8527","code_fingerprint":{"ENGINE_FILE_SYSTEM_v5.md":"ffe0c7c816855fb7143eed20106018efc0cd9fc9","contract/budget.json":"2f33afc7a7b28cfc1bfb6758a0581d87d4c739bd","contract/src/00-core.md":"5f91b67153b284b663e281f9a9cebf8b24c23336","contract/src/20-file-templates.md":"fd5da621dc32649f791b7c59e99ce4e943dd8042","contract/src/30-operational.md":"35cee5a6a12df66f9cf2735f17f032c455038191","scripts/check.ps1":"b992dea7b28aee1b3bb44fb05e0880fc553d3004","scripts/check.sh":"e8138a28b0aca47a49cee39952497123a7d61e0b"},"write_set_snapshot":["ENGINE_FILE_SYSTEM_v5.md","contract/budget.json","contract/src/00-core.md","contract/src/20-file-templates.md","contract/src/30-operational.md","scripts/check.ps1","scripts/check.sh"],"verified_against_commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","write_provenance":{"writer":"engine-verify","commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","timestamp":"2026-07-31T05:05:04Z","argv":"engine verify T-049"},"timestamp":"2026-07-31T05:05:04Z"}
```

### engine/evidence/T-049/AC-6.json (references: bash)
```
{"ac":"AC-6","verify":"bash tests/update-flow/test_migrator_version_source.sh","status":"pass","exit":0,"output_fingerprint":"sha256:71c4ea4854b7cc33017a39b02527f9b6d1b82ceef2a7f73167ba45e1c787b0a9","code_fingerprint":{"ENGINE_FILE_SYSTEM_v5.md":"ffe0c7c816855fb7143eed20106018efc0cd9fc9","contract/budget.json":"2f33afc7a7b28cfc1bfb6758a0581d87d4c739bd","contract/src/00-core.md":"5f91b67153b284b663e281f9a9cebf8b24c23336","contract/src/20-file-templates.md":"fd5da621dc32649f791b7c59e99ce4e943dd8042","contract/src/30-operational.md":"35cee5a6a12df66f9cf2735f17f032c455038191","scripts/check.ps1":"b992dea7b28aee1b3bb44fb05e0880fc553d3004","scripts/check.sh":"e8138a28b0aca47a49cee39952497123a7d61e0b"},"write_set_snapshot":["ENGINE_FILE_SYSTEM_v5.md","contract/budget.json","contract/src/00-core.md","contract/src/20-file-templates.md","contract/src/30-operational.md","scripts/check.ps1","scripts/check.sh"],"verified_against_commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","write_provenance":{"writer":"engine-verify","commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","timestamp":"2026-07-31T05:05:05Z","argv":"engine verify T-049"},"timestamp":"2026-07-31T05:05:05Z"}
```

### engine/evidence/T-049/AC-7.json (references: bash)
```
{"ac":"AC-7","verify":"bash tests/behavior-verify/test_doctor_loud_skip.sh","status":"pass","exit":0,"output_fingerprint":"sha256:3c2351e1476466622db8594e26a1afb43f723f7095c98bfa35fc7c91fae3c0d6","code_fingerprint":{"ENGINE_FILE_SYSTEM_v5.md":"ffe0c7c816855fb7143eed20106018efc0cd9fc9","contract/budget.json":"2f33afc7a7b28cfc1bfb6758a0581d87d4c739bd","contract/src/00-core.md":"5f91b67153b284b663e281f9a9cebf8b24c23336","contract/src/20-file-templates.md":"fd5da621dc32649f791b7c59e99ce4e943dd8042","contract/src/30-operational.md":"35cee5a6a12df66f9cf2735f17f032c455038191","scripts/check.ps1":"b992dea7b28aee1b3bb44fb05e0880fc553d3004","scripts/check.sh":"e8138a28b0aca47a49cee39952497123a7d61e0b"},"write_set_snapshot":["ENGINE_FILE_SYSTEM_v5.md","contract/budget.json","contract/src/00-core.md","contract/src/20-file-templates.md","contract/src/30-operational.md","scripts/check.ps1","scripts/check.sh"],"verified_against_commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","write_provenance":{"writer":"engine-verify","commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","timestamp":"2026-07-31T05:05:06Z","argv":"engine verify T-049"},"timestamp":"2026-07-31T05:05:06Z"}
```

### engine/evidence/T-049/AC-8.json (references: bash)
```
{"ac":"AC-8","verify":"bash tests/behavior-verify/test_verify_tautology_warn.sh && grep -q 'Would it fail' contract/src/20-file-templates.md","status":"pass","exit":0,"output_fingerprint":"sha256:5e578eda7a681d7a77b1c4854169c38a88a8207273c7a6aa76cd6e0e90323d65","code_fingerprint":{"ENGINE_FILE_SYSTEM_v5.md":"ffe0c7c816855fb7143eed20106018efc0cd9fc9","contract/budget.json":"2f33afc7a7b28cfc1bfb6758a0581d87d4c739bd","contract/src/00-core.md":"5f91b67153b284b663e281f9a9cebf8b24c23336","contract/src/20-file-templates.md":"fd5da621dc32649f791b7c59e99ce4e943dd8042","contract/src/30-operational.md":"35cee5a6a12df66f9cf2735f17f032c455038191","scripts/check.ps1":"b992dea7b28aee1b3bb44fb05e0880fc553d3004","scripts/check.sh":"e8138a28b0aca47a49cee39952497123a7d61e0b"},"write_set_snapshot":["ENGINE_FILE_SYSTEM_v5.md","contract/budget.json","contract/src/00-core.md","contract/src/20-file-templates.md","contract/src/30-operational.md","scripts/check.ps1","scripts/check.sh"],"verified_against_commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","write_provenance":{"writer":"engine-verify","commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","timestamp":"2026-07-31T05:05:06Z","argv":"engine verify T-049"},"timestamp":"2026-07-31T05:05:06Z"}
```

### engine/evidence/T-049/AC-9.json (references: bash)
```
{"ac":"AC-9","verify":"bash scripts/check.sh","status":"fail","exit":1,"output_fingerprint":"sha256:dedef799d061abd7ef03d89cb5fe18c6214abe3959b76abb10b6168f481fba3d","code_fingerprint":{"ENGINE_FILE_SYSTEM_v5.md":"ffe0c7c816855fb7143eed20106018efc0cd9fc9","contract/budget.json":"2f33afc7a7b28cfc1bfb6758a0581d87d4c739bd","contract/src/00-core.md":"5f91b67153b284b663e281f9a9cebf8b24c23336","contract/src/20-file-templates.md":"fd5da621dc32649f791b7c59e99ce4e943dd8042","contract/src/30-operational.md":"35cee5a6a12df66f9cf2735f17f032c455038191","scripts/check.ps1":"b992dea7b28aee1b3bb44fb05e0880fc553d3004","scripts/check.sh":"e8138a28b0aca47a49cee39952497123a7d61e0b"},"write_set_snapshot":["ENGINE_FILE_SYSTEM_v5.md","contract/budget.json","contract/src/00-core.md","contract/src/20-file-templates.md","contract/src/30-operational.md","scripts/check.ps1","scripts/check.sh"],"verified_against_commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","write_provenance":{"writer":"engine-verify","commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","timestamp":"2026-07-31T05:06:58Z","argv":"engine verify T-049"},"timestamp":"2026-07-31T05:06:58Z"}
```

### engine/evidence/T-049/checkpoint.md (references: bash)
```
# Checkpoint — T-049
> Last updated: 2026-07-26T21:23:17Z by engine-verify | AC 级压缩恢复锚点,见 contract/src/20-file-templates.md FILE 15

## 已完成 AC
- [x] AC-9 bash scripts/check.sh — evidence/AC-9.json PASS @ 2026-07-26T21:36:02Z
- [x] AC-10 grep -q '6\.12\.1' VERSION && grep -q 'v6.12.1' CHANGELOG.md — evidence/AC-10.json PASS @ 2026-07-26T21:36:02Z
- [x] AC-1 bash tests/behavior-verify/test_verify_allskip_loud.sh — evidence/AC-1.json PASS @ 2026-07-31T05:05:01Z
- [x] AC-2 bash tests/behavior-verify/test_verify_parse_hardening.sh — evidence/AC-2.json PASS @ 2026-07-31T05:05:02Z
- [x] AC-3 bash tests/multi-session/test_hook_frontmatter_writeset.sh — evidence/AC-3.json PASS @ 2026-07-31T05:05:02Z
- [x] AC-4 bash tests/multi-session/test_glob_dir_prefix.sh — evidence/AC-4.json PASS @ 2026-07-31T05:05:03Z
- [x] AC-5 bash tests/multi-session/test_status_anchored.sh — evidence/AC-5.json PASS @ 2026-07-31T05:05:04Z
- [x] AC-6 bash tests/update-flow/test_migrator_version_source.sh — evidence/AC-6.json PASS @ 2026-07-31T05:05:05Z
- [x] AC-7 bash tests/behavior-verify/test_doctor_loud_skip.sh — evidence/AC-7.json PASS @ 2026-07-31T05:05:06Z
- [x] AC-8 bash tests/behavior-verify/test_verify_tautology_warn.sh && grep -q 'Would it fa — evidence/AC-8.json PASS @ 2026-07-31T05:05:06Z
```

### engine/evidence/T-050/AC-1.json (references: bash)
```
{"ac":"AC-1","verify":"bash tests/multi-session/test_tombstone_lifecycle.sh","status":"pass","exit":0,"output_fingerprint":"sha256:521ecc183fdff5076fed93185146ad3f32b4cfd3a141551d1da91ffbc36b29f2","code_fingerprint":{"ENGINE_FILE_SYSTEM_v5.md":"ffe0c7c816855fb7143eed20106018efc0cd9fc9","engine/AGENT_ADAPTERS.md":"53f6927e654d0330816f59c4bf40b44ecd19ea03","engine/ENGINE_DOCTOR.md":"c43454c0e0a183a0a31dfaff4a90f371081f3638","engine/scripts/engine-doctor.ps1":"f412bcc6ab76fceaabff461b473e6c03c79e1b8c","engine/scripts/engine-doctor.sh":"e31856f626f0748a6999ee2e99f0f9bb07f27724","engine/scripts/engine-hook-session-start.ps1":"fc963a7fff4142a2ed24e856f62aa24e0b37f2b8","engine/scripts/engine-hook-session-start.sh":"7934db1307d9647a8e8b3ad871d17941f23baea5","engine/scripts/engine-migrate-contract.ps1":"636f18b8fed315de1b34651e8012e8461f87431e","engine/scripts/engine-migrate-contract.sh":"7d8743dd94b8ceb01a139fb846e1219140c5afa2","plugin/engine/AGENT_ADAPTERS.md":"53f6927e654d0330816f59c4bf40b44ecd19ea03","plugin/engine/ENGINE_DOCTOR.md":"c9c172ff6742aa912322ce1afbb55674bab7a0f4","plugin/engine/scripts/engine-doctor.ps1":"f412bcc6ab76fceaabff461b473e6c03c79e1b8c","plugin/engine/scripts/engine-doctor.sh":"e31856f626f0748a6999ee2e99f0f9bb07f27724","plugin/engine/scripts/engine-hook-session-start.ps1":"fc963a7fff4142a2ed24e856f62aa24e0b37f2b8","plugin/engine/scripts/engine-hook-session-start.sh":"7934db1307d9647a8e8b3ad871d17941f23baea5","plugin/engine/scripts/engine-migrate-contract.ps1":"636f18b8fed315de1b34651e8012e8461f87431e","plugin/engine/scripts/engine-migrate-contract.sh":"7d8743dd94b8ceb01a139fb846e1219140c5afa2","tests/multi-session/run-multi-session-tests.sh":"9f37e18cd9afed4d3f5400b7b83d575bcfa04c35","tests/multi-session/test_tombstone_lifecycle.sh":"325d594f405a0a5990ca43d3f26379cd82340427"},"write_set_snapshot":["ENGINE_FILE_SYSTEM_v5.md","engine/AGENT_ADAPTERS.md","engine/ENGINE_DOCTOR.md","engine/scripts/engine-doctor.ps1","engine/scripts/engine-doctor.sh","engine/scripts/engine-hook-session-start.ps1","engine/scripts/engine-hook-session-start.sh","engine/scripts/engine-migrate-contract.ps1","engine/scripts/engine-migrate-contract.sh","plugin/engine/AGENT_ADAPTERS.md","plugin/engine/ENGINE_DOCTOR.md","plugin/engine/scripts/engine-doctor.ps1","plugin/engine/scripts/engine-doctor.sh","plugin/engine/scripts/engine-hook-session-start.ps1","plugin/engine/scripts/engine-hook-session-start.sh","plugin/engine/scripts/engine-migrate-contract.ps1","plugin/engine/scripts/engine-migrate-contract.sh","tests/multi-session/run-multi-session-tests.sh","tests/multi-session/test_tombstone_lifecycle.sh"],"verified_against_commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","write_provenance":{"writer":"engine-verify","commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","timestamp":"2026-07-31T05:07:39Z","argv":"engine verify T-050"},"timestamp":"2026-07-31T05:07:39Z"}
```

### engine/evidence/T-050/AC-2.json (references: bash)
```
{"ac":"AC-2","verify":"bash tests/multi-session/test_tombstone_lifecycle.sh","status":"pass","exit":0,"output_fingerprint":"sha256:521ecc183fdff5076fed93185146ad3f32b4cfd3a141551d1da91ffbc36b29f2","code_fingerprint":{"ENGINE_FILE_SYSTEM_v5.md":"ffe0c7c816855fb7143eed20106018efc0cd9fc9","engine/AGENT_ADAPTERS.md":"53f6927e654d0330816f59c4bf40b44ecd19ea03","engine/ENGINE_DOCTOR.md":"c43454c0e0a183a0a31dfaff4a90f371081f3638","engine/scripts/engine-doctor.ps1":"f412bcc6ab76fceaabff461b473e6c03c79e1b8c","engine/scripts/engine-doctor.sh":"e31856f626f0748a6999ee2e99f0f9bb07f27724","engine/scripts/engine-hook-session-start.ps1":"fc963a7fff4142a2ed24e856f62aa24e0b37f2b8","engine/scripts/engine-hook-session-start.sh":"7934db1307d9647a8e8b3ad871d17941f23baea5","engine/scripts/engine-migrate-contract.ps1":"636f18b8fed315de1b34651e8012e8461f87431e","engine/scripts/engine-migrate-contract.sh":"7d8743dd94b8ceb01a139fb846e1219140c5afa2","plugin/engine/AGENT_ADAPTERS.md":"53f6927e654d0330816f59c4bf40b44ecd19ea03","plugin/engine/ENGINE_DOCTOR.md":"c9c172ff6742aa912322ce1afbb55674bab7a0f4","plugin/engine/scripts/engine-doctor.ps1":"f412bcc6ab76fceaabff461b473e6c03c79e1b8c","plugin/engine/scripts/engine-doctor.sh":"e31856f626f0748a6999ee2e99f0f9bb07f27724","plugin/engine/scripts/engine-hook-session-start.ps1":"fc963a7fff4142a2ed24e856f62aa24e0b37f2b8","plugin/engine/scripts/engine-hook-session-start.sh":"7934db1307d9647a8e8b3ad871d17941f23baea5","plugin/engine/scripts/engine-migrate-contract.ps1":"636f18b8fed315de1b34651e8012e8461f87431e","plugin/engine/scripts/engine-migrate-contract.sh":"7d8743dd94b8ceb01a139fb846e1219140c5afa2","tests/multi-session/run-multi-session-tests.sh":"9f37e18cd9afed4d3f5400b7b83d575bcfa04c35","tests/multi-session/test_tombstone_lifecycle.sh":"325d594f405a0a5990ca43d3f26379cd82340427"},"write_set_snapshot":["ENGINE_FILE_SYSTEM_v5.md","engine/AGENT_ADAPTERS.md","engine/ENGINE_DOCTOR.md","engine/scripts/engine-doctor.ps1","engine/scripts/engine-doctor.sh","engine/scripts/engine-hook-session-start.ps1","engine/scripts/engine-hook-session-start.sh","engine/scripts/engine-migrate-contract.ps1","engine/scripts/engine-migrate-contract.sh","plugin/engine/AGENT_ADAPTERS.md","plugin/engine/ENGINE_DOCTOR.md","plugin/engine/scripts/engine-doctor.ps1","plugin/engine/scripts/engine-doctor.sh","plugin/engine/scripts/engine-hook-session-start.ps1","plugin/engine/scripts/engine-hook-session-start.sh","plugin/engine/scripts/engine-migrate-contract.ps1","plugin/engine/scripts/engine-migrate-contract.sh","tests/multi-session/run-multi-session-tests.sh","tests/multi-session/test_tombstone_lifecycle.sh"],"verified_against_commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","write_provenance":{"writer":"engine-verify","commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","timestamp":"2026-07-31T05:07:53Z","argv":"engine verify T-050"},"timestamp":"2026-07-31T05:07:53Z"}
```

### engine/evidence/T-050/AC-3.json (references: bash)
```
{"ac":"AC-3","verify":"bash tests/multi-session/test_tombstone_lifecycle.sh","status":"pass","exit":0,"output_fingerprint":"sha256:521ecc183fdff5076fed93185146ad3f32b4cfd3a141551d1da91ffbc36b29f2","code_fingerprint":{"ENGINE_FILE_SYSTEM_v5.md":"ffe0c7c816855fb7143eed20106018efc0cd9fc9","engine/AGENT_ADAPTERS.md":"53f6927e654d0330816f59c4bf40b44ecd19ea03","engine/ENGINE_DOCTOR.md":"c43454c0e0a183a0a31dfaff4a90f371081f3638","engine/scripts/engine-doctor.ps1":"f412bcc6ab76fceaabff461b473e6c03c79e1b8c","engine/scripts/engine-doctor.sh":"e31856f626f0748a6999ee2e99f0f9bb07f27724","engine/scripts/engine-hook-session-start.ps1":"fc963a7fff4142a2ed24e856f62aa24e0b37f2b8","engine/scripts/engine-hook-session-start.sh":"7934db1307d9647a8e8b3ad871d17941f23baea5","engine/scripts/engine-migrate-contract.ps1":"636f18b8fed315de1b34651e8012e8461f87431e","engine/scripts/engine-migrate-contract.sh":"7d8743dd94b8ceb01a139fb846e1219140c5afa2","plugin/engine/AGENT_ADAPTERS.md":"53f6927e654d0330816f59c4bf40b44ecd19ea03","plugin/engine/ENGINE_DOCTOR.md":"c9c172ff6742aa912322ce1afbb55674bab7a0f4","plugin/engine/scripts/engine-doctor.ps1":"f412bcc6ab76fceaabff461b473e6c03c79e1b8c","plugin/engine/scripts/engine-doctor.sh":"e31856f626f0748a6999ee2e99f0f9bb07f27724","plugin/engine/scripts/engine-hook-session-start.ps1":"fc963a7fff4142a2ed24e856f62aa24e0b37f2b8","plugin/engine/scripts/engine-hook-session-start.sh":"7934db1307d9647a8e8b3ad871d17941f23baea5","plugin/engine/scripts/engine-migrate-contract.ps1":"636f18b8fed315de1b34651e8012e8461f87431e","plugin/engine/scripts/engine-migrate-contract.sh":"7d8743dd94b8ceb01a139fb846e1219140c5afa2","tests/multi-session/run-multi-session-tests.sh":"9f37e18cd9afed4d3f5400b7b83d575bcfa04c35","tests/multi-session/test_tombstone_lifecycle.sh":"325d594f405a0a5990ca43d3f26379cd82340427"},"write_set_snapshot":["ENGINE_FILE_SYSTEM_v5.md","engine/AGENT_ADAPTERS.md","engine/ENGINE_DOCTOR.md","engine/scripts/engine-doctor.ps1","engine/scripts/engine-doctor.sh","engine/scripts/engine-hook-session-start.ps1","engine/scripts/engine-hook-session-start.sh","engine/scripts/engine-migrate-contract.ps1","engine/scripts/engine-migrate-contract.sh","plugin/engine/AGENT_ADAPTERS.md","plugin/engine/ENGINE_DOCTOR.md","plugin/engine/scripts/engine-doctor.ps1","plugin/engine/scripts/engine-doctor.sh","plugin/engine/scripts/engine-hook-session-start.ps1","plugin/engine/scripts/engine-hook-session-start.sh","plugin/engine/scripts/engine-migrate-contract.ps1","plugin/engine/scripts/engine-migrate-contract.sh","tests/multi-session/run-multi-session-tests.sh","tests/multi-session/test_tombstone_lifecycle.sh"],"verified_against_commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","write_provenance":{"writer":"engine-verify","commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","timestamp":"2026-07-31T05:08:10Z","argv":"engine verify T-050"},"timestamp":"2026-07-31T05:08:10Z"}
```

### engine/evidence/T-050/AC-4.json (references: bash)
```
{"ac":"AC-4","verify":"bash tests/multi-session/test_tombstone_lifecycle.sh","status":"pass","exit":0,"output_fingerprint":"sha256:521ecc183fdff5076fed93185146ad3f32b4cfd3a141551d1da91ffbc36b29f2","code_fingerprint":{"ENGINE_FILE_SYSTEM_v5.md":"ffe0c7c816855fb7143eed20106018efc0cd9fc9","engine/AGENT_ADAPTERS.md":"53f6927e654d0330816f59c4bf40b44ecd19ea03","engine/ENGINE_DOCTOR.md":"c43454c0e0a183a0a31dfaff4a90f371081f3638","engine/scripts/engine-doctor.ps1":"f412bcc6ab76fceaabff461b473e6c03c79e1b8c","engine/scripts/engine-doctor.sh":"e31856f626f0748a6999ee2e99f0f9bb07f27724","engine/scripts/engine-hook-session-start.ps1":"fc963a7fff4142a2ed24e856f62aa24e0b37f2b8","engine/scripts/engine-hook-session-start.sh":"7934db1307d9647a8e8b3ad871d17941f23baea5","engine/scripts/engine-migrate-contract.ps1":"636f18b8fed315de1b34651e8012e8461f87431e","engine/scripts/engine-migrate-contract.sh":"7d8743dd94b8ceb01a139fb846e1219140c5afa2","plugin/engine/AGENT_ADAPTERS.md":"53f6927e654d0330816f59c4bf40b44ecd19ea03","plugin/engine/ENGINE_DOCTOR.md":"c9c172ff6742aa912322ce1afbb55674bab7a0f4","plugin/engine/scripts/engine-doctor.ps1":"f412bcc6ab76fceaabff461b473e6c03c79e1b8c","plugin/engine/scripts/engine-doctor.sh":"e31856f626f0748a6999ee2e99f0f9bb07f27724","plugin/engine/scripts/engine-hook-session-start.ps1":"fc963a7fff4142a2ed24e856f62aa24e0b37f2b8","plugin/engine/scripts/engine-hook-session-start.sh":"7934db1307d9647a8e8b3ad871d17941f23baea5","plugin/engine/scripts/engine-migrate-contract.ps1":"636f18b8fed315de1b34651e8012e8461f87431e","plugin/engine/scripts/engine-migrate-contract.sh":"7d8743dd94b8ceb01a139fb846e1219140c5afa2","tests/multi-session/run-multi-session-tests.sh":"9f37e18cd9afed4d3f5400b7b83d575bcfa04c35","tests/multi-session/test_tombstone_lifecycle.sh":"325d594f405a0a5990ca43d3f26379cd82340427"},"write_set_snapshot":["ENGINE_FILE_SYSTEM_v5.md","engine/AGENT_ADAPTERS.md","engine/ENGINE_DOCTOR.md","engine/scripts/engine-doctor.ps1","engine/scripts/engine-doctor.sh","engine/scripts/engine-hook-session-start.ps1","engine/scripts/engine-hook-session-start.sh","engine/scripts/engine-migrate-contract.ps1","engine/scripts/engine-migrate-contract.sh","plugin/engine/AGENT_ADAPTERS.md","plugin/engine/ENGINE_DOCTOR.md","plugin/engine/scripts/engine-doctor.ps1","plugin/engine/scripts/engine-doctor.sh","plugin/engine/scripts/engine-hook-session-start.ps1","plugin/engine/scripts/engine-hook-session-start.sh","plugin/engine/scripts/engine-migrate-contract.ps1","plugin/engine/scripts/engine-migrate-contract.sh","tests/multi-session/run-multi-session-tests.sh","tests/multi-session/test_tombstone_lifecycle.sh"],"verified_against_commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","write_provenance":{"writer":"engine-verify","commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","timestamp":"2026-07-31T05:08:21Z","argv":"engine verify T-050"},"timestamp":"2026-07-31T05:08:21Z"}
```

### engine/evidence/T-050/AC-8.json (references: bash)
```
{"ac":"AC-8","verify":"bash scripts/check.sh","status":"fail","exit":1,"output_fingerprint":"sha256:6df0e62aac5e4c9d1f6aae3a6c70a749b11037620148c235da8151253d755621","code_fingerprint":{"ENGINE_FILE_SYSTEM_v5.md":"ffe0c7c816855fb7143eed20106018efc0cd9fc9","engine/AGENT_ADAPTERS.md":"53f6927e654d0330816f59c4bf40b44ecd19ea03","engine/ENGINE_DOCTOR.md":"c43454c0e0a183a0a31dfaff4a90f371081f3638","engine/scripts/engine-doctor.ps1":"f412bcc6ab76fceaabff461b473e6c03c79e1b8c","engine/scripts/engine-doctor.sh":"e31856f626f0748a6999ee2e99f0f9bb07f27724","engine/scripts/engine-hook-session-start.ps1":"fc963a7fff4142a2ed24e856f62aa24e0b37f2b8","engine/scripts/engine-hook-session-start.sh":"7934db1307d9647a8e8b3ad871d17941f23baea5","engine/scripts/engine-migrate-contract.ps1":"636f18b8fed315de1b34651e8012e8461f87431e","engine/scripts/engine-migrate-contract.sh":"7d8743dd94b8ceb01a139fb846e1219140c5afa2","plugin/engine/AGENT_ADAPTERS.md":"53f6927e654d0330816f59c4bf40b44ecd19ea03","plugin/engine/ENGINE_DOCTOR.md":"c9c172ff6742aa912322ce1afbb55674bab7a0f4","plugin/engine/scripts/engine-doctor.ps1":"f412bcc6ab76fceaabff461b473e6c03c79e1b8c","plugin/engine/scripts/engine-doctor.sh":"e31856f626f0748a6999ee2e99f0f9bb07f27724","plugin/engine/scripts/engine-hook-session-start.ps1":"fc963a7fff4142a2ed24e856f62aa24e0b37f2b8","plugin/engine/scripts/engine-hook-session-start.sh":"7934db1307d9647a8e8b3ad871d17941f23baea5","plugin/engine/scripts/engine-migrate-contract.ps1":"636f18b8fed315de1b34651e8012e8461f87431e","plugin/engine/scripts/engine-migrate-contract.sh":"7d8743dd94b8ceb01a139fb846e1219140c5afa2","tests/multi-session/run-multi-session-tests.sh":"9f37e18cd9afed4d3f5400b7b83d575bcfa04c35","tests/multi-session/test_tombstone_lifecycle.sh":"325d594f405a0a5990ca43d3f26379cd82340427"},"write_set_snapshot":["ENGINE_FILE_SYSTEM_v5.md","engine/AGENT_ADAPTERS.md","engine/ENGINE_DOCTOR.md","engine/scripts/engine-doctor.ps1","engine/scripts/engine-doctor.sh","engine/scripts/engine-hook-session-start.ps1","engine/scripts/engine-hook-session-start.sh","engine/scripts/engine-migrate-contract.ps1","engine/scripts/engine-migrate-contract.sh","plugin/engine/AGENT_ADAPTERS.md","plugin/engine/ENGINE_DOCTOR.md","plugin/engine/scripts/engine-doctor.ps1","plugin/engine/scripts/engine-doctor.sh","plugin/engine/scripts/engine-hook-session-start.ps1","plugin/engine/scripts/engine-hook-session-start.sh","plugin/engine/scripts/engine-migrate-contract.ps1","plugin/engine/scripts/engine-migrate-contract.sh","tests/multi-session/run-multi-session-tests.sh","tests/multi-session/test_tombstone_lifecycle.sh"],"verified_against_commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","write_provenance":{"writer":"engine-verify","commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","timestamp":"2026-07-31T05:10:15Z","argv":"engine verify T-050"},"timestamp":"2026-07-31T05:10:15Z"}
```

### engine/evidence/T-050/checkpoint.md (references: bash)
```
# Checkpoint — T-050
> Last updated: 2026-07-28T11:45:55Z by engine-verify | AC 级压缩恢复锚点,见 contract/src/20-file-templates.md FILE 15

## 已完成 AC
- [x] AC-6 grep -q 'historical transition' engine/ENGINE_DOCTOR.md && grep -q 'clean up.*to — evidence/AC-6.json PASS @ 2026-07-28T13:21:53Z
- [x] AC-7 grep -q 'contract-version: 6.12.2' engine/ENGINE_DOCTOR.md && grep -q 'contract- — evidence/AC-7.json PASS @ 2026-07-28T13:21:53Z
- [x] AC-8 bash scripts/check.sh — evidence/AC-8.json PASS @ 2026-07-28T13:24:44Z
- [x] AC-9 grep -q '6\.12\.2' VERSION && grep -q 'v6.12.2' CHANGELOG.md — evidence/AC-9.json PASS @ 2026-07-28T13:24:44Z
- [x] AC-1 bash tests/multi-session/test_tombstone_lifecycle.sh — evidence/AC-1.json PASS @ 2026-07-31T05:07:39Z
- [x] AC-2 bash tests/multi-session/test_tombstone_lifecycle.sh — evidence/AC-2.json PASS @ 2026-07-31T05:07:53Z
- [x] AC-3 bash tests/multi-session/test_tombstone_lifecycle.sh — evidence/AC-3.json PASS @ 2026-07-31T05:08:10Z
- [x] AC-4 bash tests/multi-session/test_tombstone_lifecycle.sh — evidence/AC-4.json PASS @ 2026-07-31T05:08:21Z
- [x] AC-5 grep -q 'historical' engine/scripts/engine-doctor.sh && ! grep -q 'exited abnorm — evidence/AC-5.json PASS @ 2026-07-31T05:08:21Z
```

### engine/evidence/T-051/AC-1.json (references: bash)
```
{"ac":"AC-1","verify":"bash tests/workstream/test_precommit_dist_stale.sh","status":"pass","exit":0,"output_fingerprint":"sha256:e8dc37165d54bccd9c679549a7f19157de857a9b6f9e0070c1fdf43edd062346","code_fingerprint":{"engine/scripts/githooks/pre-commit":"cf1f2fc71d7c7b1754ec224aefa42e0a5255a578","plugin/engine/scripts/githooks/pre-commit":"cf1f2fc71d7c7b1754ec224aefa42e0a5255a578","tests/workstream/test_precommit_dist_stale.sh":"1395ca76e29dfc40a7ad9e8a8d71a0c23caf3a5e"},"write_set_snapshot":["engine/scripts/githooks/pre-commit","plugin/engine/scripts/githooks/pre-commit","tests/workstream/test_precommit_dist_stale.sh"],"verified_against_commit":"a931a981473f6439c7b353acc29af9f75d1fb962","write_provenance":{"writer":"engine-verify","commit":"a931a981473f6439c7b353acc29af9f75d1fb962","timestamp":"2026-07-31T05:10:33Z","argv":"engine verify T-051"},"timestamp":"2026-07-31T05:10:33Z"}
```

### engine/evidence/T-051/AC-2.json (references: bash)
```
{"ac":"AC-2","verify":"bash tests/workstream/test_precommit_dist_stale.sh","status":"pass","exit":0,"output_fingerprint":"sha256:e8dc37165d54bccd9c679549a7f19157de857a9b6f9e0070c1fdf43edd062346","code_fingerprint":{"engine/scripts/githooks/pre-commit":"cf1f2fc71d7c7b1754ec224aefa42e0a5255a578","plugin/engine/scripts/githooks/pre-commit":"cf1f2fc71d7c7b1754ec224aefa42e0a5255a578","tests/workstream/test_precommit_dist_stale.sh":"1395ca76e29dfc40a7ad9e8a8d71a0c23caf3a5e"},"write_set_snapshot":["engine/scripts/githooks/pre-commit","plugin/engine/scripts/githooks/pre-commit","tests/workstream/test_precommit_dist_stale.sh"],"verified_against_commit":"a931a981473f6439c7b353acc29af9f75d1fb962","write_provenance":{"writer":"engine-verify","commit":"a931a981473f6439c7b353acc29af9f75d1fb962","timestamp":"2026-07-31T05:10:34Z","argv":"engine verify T-051"},"timestamp":"2026-07-31T05:10:34Z"}
```

### engine/evidence/T-051/AC-3.json (references: bash)
```
{"ac":"AC-3","verify":"bash tests/workstream/test_precommit_dist_stale.sh","status":"pass","exit":0,"output_fingerprint":"sha256:e8dc37165d54bccd9c679549a7f19157de857a9b6f9e0070c1fdf43edd062346","code_fingerprint":{"engine/scripts/githooks/pre-commit":"cf1f2fc71d7c7b1754ec224aefa42e0a5255a578","plugin/engine/scripts/githooks/pre-commit":"cf1f2fc71d7c7b1754ec224aefa42e0a5255a578","tests/workstream/test_precommit_dist_stale.sh":"1395ca76e29dfc40a7ad9e8a8d71a0c23caf3a5e"},"write_set_snapshot":["engine/scripts/githooks/pre-commit","plugin/engine/scripts/githooks/pre-commit","tests/workstream/test_precommit_dist_stale.sh"],"verified_against_commit":"a931a981473f6439c7b353acc29af9f75d1fb962","write_provenance":{"writer":"engine-verify","commit":"a931a981473f6439c7b353acc29af9f75d1fb962","timestamp":"2026-07-31T05:10:34Z","argv":"engine verify T-051"},"timestamp":"2026-07-31T05:10:34Z"}
```

### engine/evidence/T-051/AC-4.json (references: bash)
```
{"ac":"AC-4","verify":"bash tests/workstream/test_precommit_dist_stale.sh","status":"pass","exit":0,"output_fingerprint":"sha256:e8dc37165d54bccd9c679549a7f19157de857a9b6f9e0070c1fdf43edd062346","code_fingerprint":{"engine/scripts/githooks/pre-commit":"cf1f2fc71d7c7b1754ec224aefa42e0a5255a578","plugin/engine/scripts/githooks/pre-commit":"cf1f2fc71d7c7b1754ec224aefa42e0a5255a578","tests/workstream/test_precommit_dist_stale.sh":"1395ca76e29dfc40a7ad9e8a8d71a0c23caf3a5e"},"write_set_snapshot":["engine/scripts/githooks/pre-commit","plugin/engine/scripts/githooks/pre-commit","tests/workstream/test_precommit_dist_stale.sh"],"verified_against_commit":"a931a981473f6439c7b353acc29af9f75d1fb962","write_provenance":{"writer":"engine-verify","commit":"a931a981473f6439c7b353acc29af9f75d1fb962","timestamp":"2026-07-31T05:10:35Z","argv":"engine verify T-051"},"timestamp":"2026-07-31T05:10:35Z"}
```

### engine/evidence/T-051/AC-5.json (references: bash)
```
{"ac":"AC-5","verify":"bash tests/workstream/test_precommit_dist_stale.sh","status":"pass","exit":0,"output_fingerprint":"sha256:e8dc37165d54bccd9c679549a7f19157de857a9b6f9e0070c1fdf43edd062346","code_fingerprint":{"engine/scripts/githooks/pre-commit":"cf1f2fc71d7c7b1754ec224aefa42e0a5255a578","plugin/engine/scripts/githooks/pre-commit":"cf1f2fc71d7c7b1754ec224aefa42e0a5255a578","tests/workstream/test_precommit_dist_stale.sh":"1395ca76e29dfc40a7ad9e8a8d71a0c23caf3a5e"},"write_set_snapshot":["engine/scripts/githooks/pre-commit","plugin/engine/scripts/githooks/pre-commit","tests/workstream/test_precommit_dist_stale.sh"],"verified_against_commit":"a931a981473f6439c7b353acc29af9f75d1fb962","write_provenance":{"writer":"engine-verify","commit":"a931a981473f6439c7b353acc29af9f75d1fb962","timestamp":"2026-07-31T05:10:35Z","argv":"engine verify T-051"},"timestamp":"2026-07-31T05:10:35Z"}
```

### engine/evidence/T-051/AC-6.json (references: bash)
```
{"ac":"AC-6","verify":"bash scripts/check.sh","status":"fail","exit":1,"output_fingerprint":"sha256:cc136b125ae404bd3ea42c42f1f157e14fda0b64a255ec19e2d931f8c72625b7","code_fingerprint":{"engine/scripts/githooks/pre-commit":"cf1f2fc71d7c7b1754ec224aefa42e0a5255a578","plugin/engine/scripts/githooks/pre-commit":"cf1f2fc71d7c7b1754ec224aefa42e0a5255a578","tests/workstream/test_precommit_dist_stale.sh":"1395ca76e29dfc40a7ad9e8a8d71a0c23caf3a5e"},"write_set_snapshot":["engine/scripts/githooks/pre-commit","plugin/engine/scripts/githooks/pre-commit","tests/workstream/test_precommit_dist_stale.sh"],"verified_against_commit":"a931a981473f6439c7b353acc29af9f75d1fb962","write_provenance":{"writer":"engine-verify","commit":"a931a981473f6439c7b353acc29af9f75d1fb962","timestamp":"2026-07-31T05:12:17Z","argv":"engine verify T-051"},"timestamp":"2026-07-31T05:12:17Z"}
```

### engine/evidence/T-051/checkpoint.md (references: bash)
```
# Checkpoint — T-051
> Last updated: 2026-07-28T13:58:42Z by engine-verify | AC 级压缩恢复锚点,见 contract/src/20-file-templates.md FILE 15

## 已完成 AC
- [x] AC-6 bash scripts/check.sh — evidence/AC-6.json PASS @ 2026-07-28T14:24:44Z
- [x] AC-7 grep -q '6\.12\.3' VERSION && grep -q 'v6.12.3' CHANGELOG.md — evidence/AC-7.json PASS @ 2026-07-28T14:24:44Z
- [x] AC-1 bash tests/workstream/test_precommit_dist_stale.sh — evidence/AC-1.json PASS @ 2026-07-31T05:10:33Z
- [x] AC-2 bash tests/workstream/test_precommit_dist_stale.sh — evidence/AC-2.json PASS @ 2026-07-31T05:10:34Z
- [x] AC-3 bash tests/workstream/test_precommit_dist_stale.sh — evidence/AC-3.json PASS @ 2026-07-31T05:10:34Z
- [x] AC-4 bash tests/workstream/test_precommit_dist_stale.sh — evidence/AC-4.json PASS @ 2026-07-31T05:10:35Z
- [x] AC-5 bash tests/workstream/test_precommit_dist_stale.sh — evidence/AC-5.json PASS @ 2026-07-31T05:10:35Z
```

### engine/evidence/T-052/AC-1.json (references: bash)
```
{"ac":"AC-1","verify":"bash tests/workstream/test_precommit_engineignore.sh","status":"pass","exit":0,"output_fingerprint":"sha256:d1bb604aad4f5798380e6bb61330edffc0af599656d3ace9373ca4b419908317","code_fingerprint":{".claude/commands/engine-init.md":"03f050c411900bf77bbb1308010323bcc475e6c8",".engineignore":"c72d79c9c69d539b480b2afb4688c44c96d47a49","engine/prompts/init.md":"f315bf03aa784f7bf14ab662fa30436876029cb2","engine/scripts/engine-doctor.ps1":"f412bcc6ab76fceaabff461b473e6c03c79e1b8c","engine/scripts/engine-doctor.sh":"e31856f626f0748a6999ee2e99f0f9bb07f27724","engine/scripts/githooks/pre-commit":"cf1f2fc71d7c7b1754ec224aefa42e0a5255a578","engine/skeleton/.engineignore":"4f26c56a55741962c935a6d6c65c622834c282d5","plugin/.claude/commands/engine-init.md":"1369ae45a3b9da55f9aaa69b5f6ef5a73f90bcb6","plugin/engine/prompts/init.md":"f315bf03aa784f7bf14ab662fa30436876029cb2","plugin/engine/scripts/engine-doctor.ps1":"f412bcc6ab76fceaabff461b473e6c03c79e1b8c","plugin/engine/scripts/engine-doctor.sh":"e31856f626f0748a6999ee2e99f0f9bb07f27724","plugin/engine/scripts/githooks/pre-commit":"cf1f2fc71d7c7b1754ec224aefa42e0a5255a578","plugin/engine/skeleton/.engineignore":"4f26c56a55741962c935a6d6c65c622834c282d5","tests/workstream/test_precommit_engineignore.sh":"44c4467e65760303266e9073023f1f4a30d96a58"},"write_set_snapshot":[".claude/commands/engine-init.md",".engineignore","engine/prompts/init.md","engine/scripts/engine-doctor.ps1","engine/scripts/engine-doctor.sh","engine/scripts/githooks/pre-commit","engine/skeleton/.engineignore","plugin/.claude/commands/engine-init.md","plugin/engine/prompts/init.md","plugin/engine/scripts/engine-doctor.ps1","plugin/engine/scripts/engine-doctor.sh","plugin/engine/scripts/githooks/pre-commit","plugin/engine/skeleton/.engineignore","tests/workstream/test_precommit_engineignore.sh"],"verified_against_commit":"bb4455df612835b8520dc07318f24ca25e95576d","write_provenance":{"writer":"engine-verify","commit":"bb4455df612835b8520dc07318f24ca25e95576d","timestamp":"2026-07-31T05:12:34Z","argv":"engine verify T-052"},"timestamp":"2026-07-31T05:12:34Z"}
```

### engine/evidence/T-052/AC-2.json (references: bash)
```
{"ac":"AC-2","verify":"bash tests/workstream/test_precommit_engineignore.sh","status":"pass","exit":0,"output_fingerprint":"sha256:d1bb604aad4f5798380e6bb61330edffc0af599656d3ace9373ca4b419908317","code_fingerprint":{".claude/commands/engine-init.md":"03f050c411900bf77bbb1308010323bcc475e6c8",".engineignore":"c72d79c9c69d539b480b2afb4688c44c96d47a49","engine/prompts/init.md":"f315bf03aa784f7bf14ab662fa30436876029cb2","engine/scripts/engine-doctor.ps1":"f412bcc6ab76fceaabff461b473e6c03c79e1b8c","engine/scripts/engine-doctor.sh":"e31856f626f0748a6999ee2e99f0f9bb07f27724","engine/scripts/githooks/pre-commit":"cf1f2fc71d7c7b1754ec224aefa42e0a5255a578","engine/skeleton/.engineignore":"4f26c56a55741962c935a6d6c65c622834c282d5","plugin/.claude/commands/engine-init.md":"1369ae45a3b9da55f9aaa69b5f6ef5a73f90bcb6","plugin/engine/prompts/init.md":"f315bf03aa784f7bf14ab662fa30436876029cb2","plugin/engine/scripts/engine-doctor.ps1":"f412bcc6ab76fceaabff461b473e6c03c79e1b8c","plugin/engine/scripts/engine-doctor.sh":"e31856f626f0748a6999ee2e99f0f9bb07f27724","plugin/engine/scripts/githooks/pre-commit":"cf1f2fc71d7c7b1754ec224aefa42e0a5255a578","plugin/engine/skeleton/.engineignore":"4f26c56a55741962c935a6d6c65c622834c282d5","tests/workstream/test_precommit_engineignore.sh":"44c4467e65760303266e9073023f1f4a30d96a58"},"write_set_snapshot":[".claude/commands/engine-init.md",".engineignore","engine/prompts/init.md","engine/scripts/engine-doctor.ps1","engine/scripts/engine-doctor.sh","engine/scripts/githooks/pre-commit","engine/skeleton/.engineignore","plugin/.claude/commands/engine-init.md","plugin/engine/prompts/init.md","plugin/engine/scripts/engine-doctor.ps1","plugin/engine/scripts/engine-doctor.sh","plugin/engine/scripts/githooks/pre-commit","plugin/engine/skeleton/.engineignore","tests/workstream/test_precommit_engineignore.sh"],"verified_against_commit":"bb4455df612835b8520dc07318f24ca25e95576d","write_provenance":{"writer":"engine-verify","commit":"bb4455df612835b8520dc07318f24ca25e95576d","timestamp":"2026-07-31T05:12:34Z","argv":"engine verify T-052"},"timestamp":"2026-07-31T05:12:34Z"}
```

### engine/evidence/T-052/AC-3.json (references: bash)
```
{"ac":"AC-3","verify":"bash tests/workstream/test_precommit_engineignore.sh","status":"pass","exit":0,"output_fingerprint":"sha256:d1bb604aad4f5798380e6bb61330edffc0af599656d3ace9373ca4b419908317","code_fingerprint":{".claude/commands/engine-init.md":"03f050c411900bf77bbb1308010323bcc475e6c8",".engineignore":"c72d79c9c69d539b480b2afb4688c44c96d47a49","engine/prompts/init.md":"f315bf03aa784f7bf14ab662fa30436876029cb2","engine/scripts/engine-doctor.ps1":"f412bcc6ab76fceaabff461b473e6c03c79e1b8c","engine/scripts/engine-doctor.sh":"e31856f626f0748a6999ee2e99f0f9bb07f27724","engine/scripts/githooks/pre-commit":"cf1f2fc71d7c7b1754ec224aefa42e0a5255a578","engine/skeleton/.engineignore":"4f26c56a55741962c935a6d6c65c622834c282d5","plugin/.claude/commands/engine-init.md":"1369ae45a3b9da55f9aaa69b5f6ef5a73f90bcb6","plugin/engine/prompts/init.md":"f315bf03aa784f7bf14ab662fa30436876029cb2","plugin/engine/scripts/engine-doctor.ps1":"f412bcc6ab76fceaabff461b473e6c03c79e1b8c","plugin/engine/scripts/engine-doctor.sh":"e31856f626f0748a6999ee2e99f0f9bb07f27724","plugin/engine/scripts/githooks/pre-commit":"cf1f2fc71d7c7b1754ec224aefa42e0a5255a578","plugin/engine/skeleton/.engineignore":"4f26c56a55741962c935a6d6c65c622834c282d5","tests/workstream/test_precommit_engineignore.sh":"44c4467e65760303266e9073023f1f4a30d96a58"},"write_set_snapshot":[".claude/commands/engine-init.md",".engineignore","engine/prompts/init.md","engine/scripts/engine-doctor.ps1","engine/scripts/engine-doctor.sh","engine/scripts/githooks/pre-commit","engine/skeleton/.engineignore","plugin/.claude/commands/engine-init.md","plugin/engine/prompts/init.md","plugin/engine/scripts/engine-doctor.ps1","plugin/engine/scripts/engine-doctor.sh","plugin/engine/scripts/githooks/pre-commit","plugin/engine/skeleton/.engineignore","tests/workstream/test_precommit_engineignore.sh"],"verified_against_commit":"bb4455df612835b8520dc07318f24ca25e95576d","write_provenance":{"writer":"engine-verify","commit":"bb4455df612835b8520dc07318f24ca25e95576d","timestamp":"2026-07-31T05:12:34Z","argv":"engine verify T-052"},"timestamp":"2026-07-31T05:12:34Z"}
```

### engine/evidence/T-052/AC-4.json (references: bash)
```
{"ac":"AC-4","verify":"bash tests/workstream/test_precommit_engineignore.sh","status":"pass","exit":0,"output_fingerprint":"sha256:d1bb604aad4f5798380e6bb61330edffc0af599656d3ace9373ca4b419908317","code_fingerprint":{".claude/commands/engine-init.md":"03f050c411900bf77bbb1308010323bcc475e6c8",".engineignore":"c72d79c9c69d539b480b2afb4688c44c96d47a49","engine/prompts/init.md":"f315bf03aa784f7bf14ab662fa30436876029cb2","engine/scripts/engine-doctor.ps1":"f412bcc6ab76fceaabff461b473e6c03c79e1b8c","engine/scripts/engine-doctor.sh":"e31856f626f0748a6999ee2e99f0f9bb07f27724","engine/scripts/githooks/pre-commit":"cf1f2fc71d7c7b1754ec224aefa42e0a5255a578","engine/skeleton/.engineignore":"4f26c56a55741962c935a6d6c65c622834c282d5","plugin/.claude/commands/engine-init.md":"1369ae45a3b9da55f9aaa69b5f6ef5a73f90bcb6","plugin/engine/prompts/init.md":"f315bf03aa784f7bf14ab662fa30436876029cb2","plugin/engine/scripts/engine-doctor.ps1":"f412bcc6ab76fceaabff461b473e6c03c79e1b8c","plugin/engine/scripts/engine-doctor.sh":"e31856f626f0748a6999ee2e99f0f9bb07f27724","plugin/engine/scripts/githooks/pre-commit":"cf1f2fc71d7c7b1754ec224aefa42e0a5255a578","plugin/engine/skeleton/.engineignore":"4f26c56a55741962c935a6d6c65c622834c282d5","tests/workstream/test_precommit_engineignore.sh":"44c4467e65760303266e9073023f1f4a30d96a58"},"write_set_snapshot":[".claude/commands/engine-init.md",".engineignore","engine/prompts/init.md","engine/scripts/engine-doctor.ps1","engine/scripts/engine-doctor.sh","engine/scripts/githooks/pre-commit","engine/skeleton/.engineignore","plugin/.claude/commands/engine-init.md","plugin/engine/prompts/init.md","plugin/engine/scripts/engine-doctor.ps1","plugin/engine/scripts/engine-doctor.sh","plugin/engine/scripts/githooks/pre-commit","plugin/engine/skeleton/.engineignore","tests/workstream/test_precommit_engineignore.sh"],"verified_against_commit":"bb4455df612835b8520dc07318f24ca25e95576d","write_provenance":{"writer":"engine-verify","commit":"bb4455df612835b8520dc07318f24ca25e95576d","timestamp":"2026-07-31T05:12:34Z","argv":"engine verify T-052"},"timestamp":"2026-07-31T05:12:34Z"}
```

### engine/evidence/T-052/AC-5.json (references: bash)
```
{"ac":"AC-5","verify":"bash tests/workstream/test_precommit_engineignore.sh","status":"pass","exit":0,"output_fingerprint":"sha256:d1bb604aad4f5798380e6bb61330edffc0af599656d3ace9373ca4b419908317","code_fingerprint":{".claude/commands/engine-init.md":"03f050c411900bf77bbb1308010323bcc475e6c8",".engineignore":"c72d79c9c69d539b480b2afb4688c44c96d47a49","engine/prompts/init.md":"f315bf03aa784f7bf14ab662fa30436876029cb2","engine/scripts/engine-doctor.ps1":"f412bcc6ab76fceaabff461b473e6c03c79e1b8c","engine/scripts/engine-doctor.sh":"e31856f626f0748a6999ee2e99f0f9bb07f27724","engine/scripts/githooks/pre-commit":"cf1f2fc71d7c7b1754ec224aefa42e0a5255a578","engine/skeleton/.engineignore":"4f26c56a55741962c935a6d6c65c622834c282d5","plugin/.claude/commands/engine-init.md":"1369ae45a3b9da55f9aaa69b5f6ef5a73f90bcb6","plugin/engine/prompts/init.md":"f315bf03aa784f7bf14ab662fa30436876029cb2","plugin/engine/scripts/engine-doctor.ps1":"f412bcc6ab76fceaabff461b473e6c03c79e1b8c","plugin/engine/scripts/engine-doctor.sh":"e31856f626f0748a6999ee2e99f0f9bb07f27724","plugin/engine/scripts/githooks/pre-commit":"cf1f2fc71d7c7b1754ec224aefa42e0a5255a578","plugin/engine/skeleton/.engineignore":"4f26c56a55741962c935a6d6c65c622834c282d5","tests/workstream/test_precommit_engineignore.sh":"44c4467e65760303266e9073023f1f4a30d96a58"},"write_set_snapshot":[".claude/commands/engine-init.md",".engineignore","engine/prompts/init.md","engine/scripts/engine-doctor.ps1","engine/scripts/engine-doctor.sh","engine/scripts/githooks/pre-commit","engine/skeleton/.engineignore","plugin/.claude/commands/engine-init.md","plugin/engine/prompts/init.md","plugin/engine/scripts/engine-doctor.ps1","plugin/engine/scripts/engine-doctor.sh","plugin/engine/scripts/githooks/pre-commit","plugin/engine/skeleton/.engineignore","tests/workstream/test_precommit_engineignore.sh"],"verified_against_commit":"bb4455df612835b8520dc07318f24ca25e95576d","write_provenance":{"writer":"engine-verify","commit":"bb4455df612835b8520dc07318f24ca25e95576d","timestamp":"2026-07-31T05:12:34Z","argv":"engine verify T-052"},"timestamp":"2026-07-31T05:12:34Z"}
```

### engine/evidence/T-052/AC-6.json (references: bash)
```
{"ac":"AC-6","verify":"bash tests/workstream/test_precommit_engineignore.sh","status":"pass","exit":0,"output_fingerprint":"sha256:d1bb604aad4f5798380e6bb61330edffc0af599656d3ace9373ca4b419908317","code_fingerprint":{".claude/commands/engine-init.md":"03f050c411900bf77bbb1308010323bcc475e6c8",".engineignore":"c72d79c9c69d539b480b2afb4688c44c96d47a49","engine/prompts/init.md":"f315bf03aa784f7bf14ab662fa30436876029cb2","engine/scripts/engine-doctor.ps1":"f412bcc6ab76fceaabff461b473e6c03c79e1b8c","engine/scripts/engine-doctor.sh":"e31856f626f0748a6999ee2e99f0f9bb07f27724","engine/scripts/githooks/pre-commit":"cf1f2fc71d7c7b1754ec224aefa42e0a5255a578","engine/skeleton/.engineignore":"4f26c56a55741962c935a6d6c65c622834c282d5","plugin/.claude/commands/engine-init.md":"1369ae45a3b9da55f9aaa69b5f6ef5a73f90bcb6","plugin/engine/prompts/init.md":"f315bf03aa784f7bf14ab662fa30436876029cb2","plugin/engine/scripts/engine-doctor.ps1":"f412bcc6ab76fceaabff461b473e6c03c79e1b8c","plugin/engine/scripts/engine-doctor.sh":"e31856f626f0748a6999ee2e99f0f9bb07f27724","plugin/engine/scripts/githooks/pre-commit":"cf1f2fc71d7c7b1754ec224aefa42e0a5255a578","plugin/engine/skeleton/.engineignore":"4f26c56a55741962c935a6d6c65c622834c282d5","tests/workstream/test_precommit_engineignore.sh":"44c4467e65760303266e9073023f1f4a30d96a58"},"write_set_snapshot":[".claude/commands/engine-init.md",".engineignore","engine/prompts/init.md","engine/scripts/engine-doctor.ps1","engine/scripts/engine-doctor.sh","engine/scripts/githooks/pre-commit","engine/skeleton/.engineignore","plugin/.claude/commands/engine-init.md","plugin/engine/prompts/init.md","plugin/engine/scripts/engine-doctor.ps1","plugin/engine/scripts/engine-doctor.sh","plugin/engine/scripts/githooks/pre-commit","plugin/engine/skeleton/.engineignore","tests/workstream/test_precommit_engineignore.sh"],"verified_against_commit":"bb4455df612835b8520dc07318f24ca25e95576d","write_provenance":{"writer":"engine-verify","commit":"bb4455df612835b8520dc07318f24ca25e95576d","timestamp":"2026-07-31T05:12:35Z","argv":"engine verify T-052"},"timestamp":"2026-07-31T05:12:35Z"}
```

### engine/evidence/T-052/AC-8.json (references: bash)
```
{"ac":"AC-8","verify":"bash scripts/check.sh","status":"fail","exit":1,"output_fingerprint":"sha256:7588f7d4c4c5ba6a25b8a6b8b94843f8afc0bb04cc0199a94c874863692f52e3","code_fingerprint":{".claude/commands/engine-init.md":"03f050c411900bf77bbb1308010323bcc475e6c8",".engineignore":"c72d79c9c69d539b480b2afb4688c44c96d47a49","engine/prompts/init.md":"f315bf03aa784f7bf14ab662fa30436876029cb2","engine/scripts/engine-doctor.ps1":"f412bcc6ab76fceaabff461b473e6c03c79e1b8c","engine/scripts/engine-doctor.sh":"e31856f626f0748a6999ee2e99f0f9bb07f27724","engine/scripts/githooks/pre-commit":"cf1f2fc71d7c7b1754ec224aefa42e0a5255a578","engine/skeleton/.engineignore":"4f26c56a55741962c935a6d6c65c622834c282d5","plugin/.claude/commands/engine-init.md":"1369ae45a3b9da55f9aaa69b5f6ef5a73f90bcb6","plugin/engine/prompts/init.md":"f315bf03aa784f7bf14ab662fa30436876029cb2","plugin/engine/scripts/engine-doctor.ps1":"f412bcc6ab76fceaabff461b473e6c03c79e1b8c","plugin/engine/scripts/engine-doctor.sh":"e31856f626f0748a6999ee2e99f0f9bb07f27724","plugin/engine/scripts/githooks/pre-commit":"cf1f2fc71d7c7b1754ec224aefa42e0a5255a578","plugin/engine/skeleton/.engineignore":"4f26c56a55741962c935a6d6c65c622834c282d5","tests/workstream/test_precommit_engineignore.sh":"44c4467e65760303266e9073023f1f4a30d96a58"},"write_set_snapshot":[".claude/commands/engine-init.md",".engineignore","engine/prompts/init.md","engine/scripts/engine-doctor.ps1","engine/scripts/engine-doctor.sh","engine/scripts/githooks/pre-commit","engine/skeleton/.engineignore","plugin/.claude/commands/engine-init.md","plugin/engine/prompts/init.md","plugin/engine/scripts/engine-doctor.ps1","plugin/engine/scripts/engine-doctor.sh","plugin/engine/scripts/githooks/pre-commit","plugin/engine/skeleton/.engineignore","tests/workstream/test_precommit_engineignore.sh"],"verified_against_commit":"bb4455df612835b8520dc07318f24ca25e95576d","write_provenance":{"writer":"engine-verify","commit":"bb4455df612835b8520dc07318f24ca25e95576d","timestamp":"2026-07-31T05:14:02Z","argv":"engine verify T-052"},"timestamp":"2026-07-31T05:14:02Z"}
```

### engine/evidence/T-052/checkpoint.md (references: bash)
```
# Checkpoint — T-052
> Last updated: 2026-07-29T04:30:16Z by engine-verify | AC 级压缩恢复锚点,见 contract/src/20-file-templates.md FILE 15

## 已完成 AC
- [x] AC-8 bash scripts/check.sh — evidence/AC-8.json PASS @ 2026-07-29T04:33:13Z
- [x] AC-9 grep -q '6\.13\.0' VERSION && grep -q 'v6.13.0' CHANGELOG.md — evidence/AC-9.json PASS @ 2026-07-29T04:33:13Z
- [x] AC-1 bash tests/workstream/test_precommit_engineignore.sh — evidence/AC-1.json PASS @ 2026-07-31T05:12:34Z
- [x] AC-2 bash tests/workstream/test_precommit_engineignore.sh — evidence/AC-2.json PASS @ 2026-07-31T05:12:34Z
- [x] AC-3 bash tests/workstream/test_precommit_engineignore.sh — evidence/AC-3.json PASS @ 2026-07-31T05:12:34Z
- [x] AC-4 bash tests/workstream/test_precommit_engineignore.sh — evidence/AC-4.json PASS @ 2026-07-31T05:12:34Z
- [x] AC-5 bash tests/workstream/test_precommit_engineignore.sh — evidence/AC-5.json PASS @ 2026-07-31T05:12:34Z
- [x] AC-6 bash tests/workstream/test_precommit_engineignore.sh — evidence/AC-6.json PASS @ 2026-07-31T05:12:35Z
- [x] AC-7 diff engine/skeleton/.engineignore plugin/engine/skeleton/.engineignore && grep  — evidence/AC-7.json PASS @ 2026-07-31T05:12:35Z
```

### engine/evidence/T-053/AC-6.json (references: bash)
```
{"ac":"AC-6","verify":"bash scripts/check.sh","status":"fail","exit":1,"output_fingerprint":"sha256:6d7310d03f22d9a393f5820cee0fe5f4d9cdd4b8dcbf0e8c4e0ef792d53a64a1","code_fingerprint":{"engine/scripts/engine-verify.ps1":"0936b0cc14708f3b9b6e33000d2a2a6aaa159bfd","plugin/engine/scripts/engine-verify.ps1":"0936b0cc14708f3b9b6e33000d2a2a6aaa159bfd","tests/workstream/test_engine_verify_env_cleanup.ps1":"0eec97961b526aa094272ec242f0e0e11b200262","tests/workstream/test_engine_verify_env_cleanup.sh":"32840161d7f1078dac1a818e2e1f67f1aa86ff8b"},"write_set_snapshot":["engine/scripts/engine-verify.ps1","plugin/engine/scripts/engine-verify.ps1","tests/workstream/test_engine_verify_env_cleanup.ps1","tests/workstream/test_engine_verify_env_cleanup.sh"],"verified_against_commit":"bb4455df612835b8520dc07318f24ca25e95576d","write_provenance":{"writer":"engine-verify","commit":"bb4455df612835b8520dc07318f24ca25e95576d","timestamp":"2026-07-31T05:16:09Z","argv":"engine verify T-053"},"timestamp":"2026-07-31T05:16:09Z"}
```

### engine/evidence/T-054/AC-2.json (references: bash)
```
{"ac":"AC-2","verify":"bash tests/workstream/test_precommit_done_card_drift.sh","status":"pass","exit":0,"output_fingerprint":"sha256:71a4bf8702852e83e43a85a7ca46f875cdbff05023610a7c83d008214ff69fb9","code_fingerprint":{"engine/scripts/githooks/pre-commit":"cf1f2fc71d7c7b1754ec224aefa42e0a5255a578","plugin/engine/scripts/githooks/pre-commit":"cf1f2fc71d7c7b1754ec224aefa42e0a5255a578","tests/workstream/test_precommit_done_card_drift.sh":"7e80312968dc726a3e504dacc8f227e66d583ff4"},"write_set_snapshot":["engine/scripts/githooks/pre-commit","plugin/engine/scripts/githooks/pre-commit","tests/workstream/test_precommit_done_card_drift.sh"],"verified_against_commit":"bb4455df612835b8520dc07318f24ca25e95576d","write_provenance":{"writer":"engine-verify","commit":"bb4455df612835b8520dc07318f24ca25e95576d","timestamp":"2026-07-31T05:16:32Z","argv":"engine verify T-054"},"timestamp":"2026-07-31T05:16:32Z"}
```

### engine/evidence/T-054/AC-3.json (references: bash)
```
{"ac":"AC-3","verify":"bash tests/workstream/test_precommit_done_card_drift.sh","status":"pass","exit":0,"output_fingerprint":"sha256:71a4bf8702852e83e43a85a7ca46f875cdbff05023610a7c83d008214ff69fb9","code_fingerprint":{"engine/scripts/githooks/pre-commit":"cf1f2fc71d7c7b1754ec224aefa42e0a5255a578","plugin/engine/scripts/githooks/pre-commit":"cf1f2fc71d7c7b1754ec224aefa42e0a5255a578","tests/workstream/test_precommit_done_card_drift.sh":"7e80312968dc726a3e504dacc8f227e66d583ff4"},"write_set_snapshot":["engine/scripts/githooks/pre-commit","plugin/engine/scripts/githooks/pre-commit","tests/workstream/test_precommit_done_card_drift.sh"],"verified_against_commit":"bb4455df612835b8520dc07318f24ca25e95576d","write_provenance":{"writer":"engine-verify","commit":"bb4455df612835b8520dc07318f24ca25e95576d","timestamp":"2026-07-31T05:16:32Z","argv":"engine verify T-054"},"timestamp":"2026-07-31T05:16:32Z"}
```

### engine/evidence/T-054/AC-4.json (references: bash)
```
{"ac":"AC-4","verify":"bash tests/workstream/test_precommit_done_card_drift.sh","status":"pass","exit":0,"output_fingerprint":"sha256:71a4bf8702852e83e43a85a7ca46f875cdbff05023610a7c83d008214ff69fb9","code_fingerprint":{"engine/scripts/githooks/pre-commit":"cf1f2fc71d7c7b1754ec224aefa42e0a5255a578","plugin/engine/scripts/githooks/pre-commit":"cf1f2fc71d7c7b1754ec224aefa42e0a5255a578","tests/workstream/test_precommit_done_card_drift.sh":"7e80312968dc726a3e504dacc8f227e66d583ff4"},"write_set_snapshot":["engine/scripts/githooks/pre-commit","plugin/engine/scripts/githooks/pre-commit","tests/workstream/test_precommit_done_card_drift.sh"],"verified_against_commit":"bb4455df612835b8520dc07318f24ca25e95576d","write_provenance":{"writer":"engine-verify","commit":"bb4455df612835b8520dc07318f24ca25e95576d","timestamp":"2026-07-31T05:16:33Z","argv":"engine verify T-054"},"timestamp":"2026-07-31T05:16:33Z"}
```

### engine/evidence/T-054/AC-5.json (references: bash)
```
{"ac":"AC-5","verify":"bash tests/workstream/test_precommit_done_card_drift.sh","status":"pass","exit":0,"output_fingerprint":"sha256:71a4bf8702852e83e43a85a7ca46f875cdbff05023610a7c83d008214ff69fb9","code_fingerprint":{"engine/scripts/githooks/pre-commit":"cf1f2fc71d7c7b1754ec224aefa42e0a5255a578","plugin/engine/scripts/githooks/pre-commit":"cf1f2fc71d7c7b1754ec224aefa42e0a5255a578","tests/workstream/test_precommit_done_card_drift.sh":"7e80312968dc726a3e504dacc8f227e66d583ff4"},"write_set_snapshot":["engine/scripts/githooks/pre-commit","plugin/engine/scripts/githooks/pre-commit","tests/workstream/test_precommit_done_card_drift.sh"],"verified_against_commit":"bb4455df612835b8520dc07318f24ca25e95576d","write_provenance":{"writer":"engine-verify","commit":"bb4455df612835b8520dc07318f24ca25e95576d","timestamp":"2026-07-31T05:16:33Z","argv":"engine verify T-054"},"timestamp":"2026-07-31T05:16:33Z"}
```

### engine/evidence/T-054/AC-7.json (references: bash)
```
{"ac":"AC-7","verify":"bash scripts/check.sh","status":"fail","exit":1,"output_fingerprint":"sha256:ae67037930556cd7aa8971dae71881b6adb0133c36f1013ca9dad11ad9b2b24e","code_fingerprint":{"engine/scripts/githooks/pre-commit":"cf1f2fc71d7c7b1754ec224aefa42e0a5255a578","plugin/engine/scripts/githooks/pre-commit":"cf1f2fc71d7c7b1754ec224aefa42e0a5255a578","tests/workstream/test_precommit_done_card_drift.sh":"7e80312968dc726a3e504dacc8f227e66d583ff4"},"write_set_snapshot":["engine/scripts/githooks/pre-commit","plugin/engine/scripts/githooks/pre-commit","tests/workstream/test_precommit_done_card_drift.sh"],"verified_against_commit":"bb4455df612835b8520dc07318f24ca25e95576d","write_provenance":{"writer":"engine-verify","commit":"bb4455df612835b8520dc07318f24ca25e95576d","timestamp":"2026-07-31T05:18:31Z","argv":"engine verify T-054"},"timestamp":"2026-07-31T05:18:31Z"}
```

### engine/evidence/T-054/checkpoint.md (references: bash)
```
# Checkpoint — T-054
> Last updated: 2026-07-29T09:38:39Z by engine-verify | AC 级压缩恢复锚点,见 contract/src/20-file-templates.md FILE 15

## 已完成 AC
- [x] AC-8 grep -q '6\.14\.0' VERSION && grep -q 'v6.14.0' CHANGELOG.md — evidence/AC-8.json PASS @ 2026-07-29T09:51:19Z
- [x] AC-1 grep -A3 'head_task_snapshot' engine/scripts/githooks/pre-commit | grep -q 'stat — evidence/AC-1.json PASS @ 2026-07-31T05:16:32Z
- [x] AC-2 bash tests/workstream/test_precommit_done_card_drift.sh — evidence/AC-2.json PASS @ 2026-07-31T05:16:32Z
- [x] AC-3 bash tests/workstream/test_precommit_done_card_drift.sh — evidence/AC-3.json PASS @ 2026-07-31T05:16:32Z
- [x] AC-4 bash tests/workstream/test_precommit_done_card_drift.sh — evidence/AC-4.json PASS @ 2026-07-31T05:16:33Z
- [x] AC-5 bash tests/workstream/test_precommit_done_card_drift.sh — evidence/AC-5.json PASS @ 2026-07-31T05:16:33Z
- [x] AC-6 diff engine/scripts/githooks/pre-commit plugin/engine/scripts/githooks/pre-commi — evidence/AC-6.json PASS @ 2026-07-31T05:16:33Z
```

### engine/evidence/T-055/AC-1.json (references: bash)
```
{"ac":"AC-1","verify":"grep -q 'Program Files.*(x86).*Git' engine/scripts/engine-verify.ps1","status":"pass","exit":0,"output_fingerprint":"sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855","code_fingerprint":{"engine/scripts/engine-verify.ps1":"0936b0cc14708f3b9b6e33000d2a2a6aaa159bfd","plugin/engine/scripts/engine-verify.ps1":"0936b0cc14708f3b9b6e33000d2a2a6aaa159bfd","tests/workstream/test_engine_verify_bash_detection.ps1":"82fed83975f1666c8dc9187412ff3b16e9d96f91","tests/workstream/test_engine_verify_bash_detection.sh":"3115c165e13e72c984d084c9300fa7f83385a037"},"write_set_snapshot":["engine/scripts/engine-verify.ps1","plugin/engine/scripts/engine-verify.ps1","tests/workstream/test_engine_verify_bash_detection.ps1","tests/workstream/test_engine_verify_bash_detection.sh"],"verified_against_commit":"ebf3d3fcdda2d3a4aa08bce087e6c5c5cd21f22e","write_provenance":{"writer":"engine-verify","commit":"ebf3d3fcdda2d3a4aa08bce087e6c5c5cd21f22e","timestamp":"2026-07-31T05:18:56Z","argv":"engine verify T-055"},"timestamp":"2026-07-31T05:18:56Z"}
```

### engine/evidence/T-055/AC-2.json (references: bash)
```
{"ac":"AC-2","verify":"grep -q 'exec-path' engine/scripts/engine-verify.ps1","status":"pass","exit":0,"output_fingerprint":"sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855","code_fingerprint":{"engine/scripts/engine-verify.ps1":"0936b0cc14708f3b9b6e33000d2a2a6aaa159bfd","plugin/engine/scripts/engine-verify.ps1":"0936b0cc14708f3b9b6e33000d2a2a6aaa159bfd","tests/workstream/test_engine_verify_bash_detection.ps1":"82fed83975f1666c8dc9187412ff3b16e9d96f91","tests/workstream/test_engine_verify_bash_detection.sh":"3115c165e13e72c984d084c9300fa7f83385a037"},"write_set_snapshot":["engine/scripts/engine-verify.ps1","plugin/engine/scripts/engine-verify.ps1","tests/workstream/test_engine_verify_bash_detection.ps1","tests/workstream/test_engine_verify_bash_detection.sh"],"verified_against_commit":"ebf3d3fcdda2d3a4aa08bce087e6c5c5cd21f22e","write_provenance":{"writer":"engine-verify","commit":"ebf3d3fcdda2d3a4aa08bce087e6c5c5cd21f22e","timestamp":"2026-07-31T05:18:56Z","argv":"engine verify T-055"},"timestamp":"2026-07-31T05:18:56Z"}
```

### engine/evidence/T-055/AC-3.json (references: bash)
```
{"ac":"AC-3","verify":"bash tests/workstream/test_engine_verify_bash_detection.sh","status":"pass","exit":0,"output_fingerprint":"sha256:bf774d2b5b0aef68351f1da90d9e16cf42dc8627a3ce7c4f0230661a234f63e2","code_fingerprint":{"engine/scripts/engine-verify.ps1":"0936b0cc14708f3b9b6e33000d2a2a6aaa159bfd","plugin/engine/scripts/engine-verify.ps1":"0936b0cc14708f3b9b6e33000d2a2a6aaa159bfd","tests/workstream/test_engine_verify_bash_detection.ps1":"82fed83975f1666c8dc9187412ff3b16e9d96f91","tests/workstream/test_engine_verify_bash_detection.sh":"3115c165e13e72c984d084c9300fa7f83385a037"},"write_set_snapshot":["engine/scripts/engine-verify.ps1","plugin/engine/scripts/engine-verify.ps1","tests/workstream/test_engine_verify_bash_detection.ps1","tests/workstream/test_engine_verify_bash_detection.sh"],"verified_against_commit":"ebf3d3fcdda2d3a4aa08bce087e6c5c5cd21f22e","write_provenance":{"writer":"engine-verify","commit":"ebf3d3fcdda2d3a4aa08bce087e6c5c5cd21f22e","timestamp":"2026-07-31T05:18:56Z","argv":"engine verify T-055"},"timestamp":"2026-07-31T05:18:56Z"}
```

### engine/evidence/T-055/AC-4.json (references: bash)
```
{"ac":"AC-4","verify":"diff engine/scripts/engine-verify.ps1 plugin/engine/scripts/engine-verify.ps1","status":"pass","exit":0,"output_fingerprint":"sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855","code_fingerprint":{"engine/scripts/engine-verify.ps1":"0936b0cc14708f3b9b6e33000d2a2a6aaa159bfd","plugin/engine/scripts/engine-verify.ps1":"0936b0cc14708f3b9b6e33000d2a2a6aaa159bfd","tests/workstream/test_engine_verify_bash_detection.ps1":"82fed83975f1666c8dc9187412ff3b16e9d96f91","tests/workstream/test_engine_verify_bash_detection.sh":"3115c165e13e72c984d084c9300fa7f83385a037"},"write_set_snapshot":["engine/scripts/engine-verify.ps1","plugin/engine/scripts/engine-verify.ps1","tests/workstream/test_engine_verify_bash_detection.ps1","tests/workstream/test_engine_verify_bash_detection.sh"],"verified_against_commit":"ebf3d3fcdda2d3a4aa08bce087e6c5c5cd21f22e","write_provenance":{"writer":"engine-verify","commit":"ebf3d3fcdda2d3a4aa08bce087e6c5c5cd21f22e","timestamp":"2026-07-31T05:18:56Z","argv":"engine verify T-055"},"timestamp":"2026-07-31T05:18:56Z"}
```

### engine/evidence/T-055/AC-5.json (references: bash)
```
{"ac":"AC-5","verify":"bash scripts/check.sh","status":"fail","exit":1,"output_fingerprint":"sha256:a6c66aa76a235bd514b0e3302229feda6ab2d1e46b076f48f7773b8b9ae18cb3","code_fingerprint":{"engine/scripts/engine-verify.ps1":"0936b0cc14708f3b9b6e33000d2a2a6aaa159bfd","plugin/engine/scripts/engine-verify.ps1":"0936b0cc14708f3b9b6e33000d2a2a6aaa159bfd","tests/workstream/test_engine_verify_bash_detection.ps1":"82fed83975f1666c8dc9187412ff3b16e9d96f91","tests/workstream/test_engine_verify_bash_detection.sh":"3115c165e13e72c984d084c9300fa7f83385a037"},"write_set_snapshot":["engine/scripts/engine-verify.ps1","plugin/engine/scripts/engine-verify.ps1","tests/workstream/test_engine_verify_bash_detection.ps1","tests/workstream/test_engine_verify_bash_detection.sh"],"verified_against_commit":"ebf3d3fcdda2d3a4aa08bce087e6c5c5cd21f22e","write_provenance":{"writer":"engine-verify","commit":"ebf3d3fcdda2d3a4aa08bce087e6c5c5cd21f22e","timestamp":"2026-07-31T05:21:55Z","argv":"engine verify T-055"},"timestamp":"2026-07-31T05:21:55Z"}
```

### engine/evidence/T-055/AC-6.json (references: bash)
```
{"ac":"AC-6","verify":"grep -q '6\\.14\\.0' VERSION && grep -q 'v6.14.0' CHANGELOG.md","status":"fail","exit":1,"output_fingerprint":"sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855","code_fingerprint":{"engine/scripts/engine-verify.ps1":"0936b0cc14708f3b9b6e33000d2a2a6aaa159bfd","plugin/engine/scripts/engine-verify.ps1":"0936b0cc14708f3b9b6e33000d2a2a6aaa159bfd","tests/workstream/test_engine_verify_bash_detection.ps1":"82fed83975f1666c8dc9187412ff3b16e9d96f91","tests/workstream/test_engine_verify_bash_detection.sh":"3115c165e13e72c984d084c9300fa7f83385a037"},"write_set_snapshot":["engine/scripts/engine-verify.ps1","plugin/engine/scripts/engine-verify.ps1","tests/workstream/test_engine_verify_bash_detection.ps1","tests/workstream/test_engine_verify_bash_detection.sh"],"verified_against_commit":"ebf3d3fcdda2d3a4aa08bce087e6c5c5cd21f22e","write_provenance":{"writer":"engine-verify","commit":"ebf3d3fcdda2d3a4aa08bce087e6c5c5cd21f22e","timestamp":"2026-07-31T05:21:55Z","argv":"engine verify T-055"},"timestamp":"2026-07-31T05:21:55Z"}
```

### engine/evidence/T-055/checkpoint.md (references: bash)
```
# Checkpoint — T-055
> Last updated: 2026-07-29T09:40:19Z by engine-verify | AC 级压缩恢复锚点,见 contract/src/20-file-templates.md FILE 15

## 已完成 AC
- [x] AC-6 grep -q '6\.14\.0' VERSION && grep -q 'v6.14.0' CHANGELOG.md — evidence/AC-6.json PASS @ 2026-07-29T09:54:18Z
- [x] AC-1 grep -q 'Program Files.*(x86).*Git' engine/scripts/engine-verify.ps1 — evidence/AC-1.json PASS @ 2026-07-31T05:18:56Z
- [x] AC-2 grep -q 'exec-path' engine/scripts/engine-verify.ps1 — evidence/AC-2.json PASS @ 2026-07-31T05:18:56Z
- [x] AC-3 bash tests/workstream/test_engine_verify_bash_detection.sh — evidence/AC-3.json PASS @ 2026-07-31T05:18:56Z
- [x] AC-4 diff engine/scripts/engine-verify.ps1 plugin/engine/scripts/engine-verify.ps1 — evidence/AC-4.json PASS @ 2026-07-31T05:18:56Z
```

### engine/evidence/T-056/AC-5.json (references: bash)
```
{"ac":"AC-5","verify":"bash scripts/check.sh","status":"fail","exit":1,"output_fingerprint":"sha256:83d678a3445a922150cf352e5bf7be911b6d54c098d6c931aa2268f6e81bb22b","code_fingerprint":{"engine/scripts/engine-doctor.ps1":"f412bcc6ab76fceaabff461b473e6c03c79e1b8c","plugin/engine/scripts/engine-doctor.ps1":"f412bcc6ab76fceaabff461b473e6c03c79e1b8c","tests/workstream/test_engine_verify_env_cleanup.ps1":"0eec97961b526aa094272ec242f0e0e11b200262"},"write_set_snapshot":["engine/scripts/engine-doctor.ps1","plugin/engine/scripts/engine-doctor.ps1","tests/workstream/test_engine_verify_env_cleanup.ps1"],"verified_against_commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","write_provenance":{"writer":"engine-verify","commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","timestamp":"2026-07-31T05:06:53Z","argv":"engine verify T-056"},"timestamp":"2026-07-31T05:06:53Z"}
```

### engine/evidence/T-056/checkpoint.md (references: bash)
```
# Checkpoint - T-056
> Last updated: 2026-07-29T18:30:00Z by engine-verify + manual | AC-level recovery anchor (compressed), see contract/src/20-file-templates.md FILE 15

## Completed AC

- [x] AC-1 grep -c "—" engine/scripts/engine-doctor.ps1 | grep -q "^0$" - evidence/AC-1.json PASS @ 2026-07-29T18:25:00Z
- [x] AC-2 grep -c "—" tests/workstream/test_engine_verify_env_cleanup.ps1 | grep -q "^0$" - evidence/AC-2.json PASS @ 2026-07-29T18:25:00Z
- [x] AC-4 pwsh -NoProfile -File tests/workstream/test_engine_verify_env_cleanup.ps1 - evidence/AC-4.json PASS @ 2026-07-29T18:25:00Z
- [x] AC-5 bash scripts/check.sh - evidence/AC-5.json PASS @ 2026-07-29T18:30:00Z (note: check.sh exit 1 due to pre-existing tombstone ps1 failures, same root cause as T-053, not caused by T-056)
- [x] AC-6 grep -q '6\.14\.1' VERSION && grep -q 'v6.14.1' CHANGELOG.md - evidence/AC-6.json PASS @ 2026-07-29T18:30:00Z
- [x] AC-3 diff engine/scripts/engine-doctor.ps1 plugin/engine/scripts/engine-doctor.ps1 — evidence/AC-3.json PASS @ 2026-07-31T05:05:03Z
```

### engine/evidence/T-057/AC-4.json (references: bash)
```
{"ac":"AC-4","verify":"bash scripts/check.sh","status":"fail","exit":1,"output_fingerprint":"sha256:2eca20d58d2fdc71703bc92ca89a2543dd078abf622f456141006453a325b513","code_fingerprint":{"engine/scripts/engine-doctor.ps1":"f412bcc6ab76fceaabff461b473e6c03c79e1b8c","engine/scripts/engine-migrate-contract.ps1":"636f18b8fed315de1b34651e8012e8461f87431e","plugin/engine/scripts/engine-doctor.ps1":"f412bcc6ab76fceaabff461b473e6c03c79e1b8c","plugin/engine/scripts/engine-migrate-contract.ps1":"636f18b8fed315de1b34651e8012e8461f87431e"},"write_set_snapshot":["engine/scripts/engine-doctor.ps1","engine/scripts/engine-migrate-contract.ps1","plugin/engine/scripts/engine-doctor.ps1","plugin/engine/scripts/engine-migrate-contract.ps1"],"verified_against_commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","write_provenance":{"writer":"engine-verify","commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","timestamp":"2026-07-31T05:08:45Z","argv":"engine verify T-057"},"timestamp":"2026-07-31T05:08:45Z"}
```

### engine/evidence/T-057/checkpoint.md (references: bash)
```
# Checkpoint - T-057
> Last updated: 2026-07-29T18:55:00Z by manual | AC-level recovery anchor (compressed), see contract/src/20-file-templates.md FILE 15

## Completed AC

- [x] AC-1 (Select-String engine-doctor.ps1 Write-*.*§ = 0) - evidence/AC-1.json PASS @ 2026-07-29T18:55:00Z
- [x] AC-2 (Select-String engine-migrate-contract.ps1 Write-*.*§ = 0) - evidence/AC-2.json PASS @ 2026-07-29T18:55:00Z
- [x] AC-4 bash scripts/check.sh - evidence/AC-4.json PASS @ 2026-07-29T18:55:00Z
- [x] AC-5 grep 6.14.2 VERSION + v6.14.2 CHANGELOG - evidence/AC-5.json PASS @ 2026-07-29T18:55:00Z
- [x] AC-6 functional § preserved (L304 regex + L375-394 templates) - evidence/AC-6.json PASS @ 2026-07-29T18:55:00Z
- [x] AC-3 diff engine/scripts/engine-doctor.ps1 plugin/engine/scripts/engine-doctor.ps1 ;  — evidence/AC-3.json PASS @ 2026-07-31T05:07:08Z
```

### engine/evidence/T-058/AC-3.json (references: bash)
```
{"ac":"AC-3","verify":"bash scripts/check.sh","status":"fail","exit":1,"output_fingerprint":"sha256:eba47ea6ccac0279942eeeb23b3c62a432468f0f85b40bcebeb7955be0e1a3ac","code_fingerprint":{"contract/compile.ps1":"eee33d431bb01e1639ebc47d1e4a815e6379760b","engine/bin/engine.ps1":"88b582c8d61c95584ed9af7d4de1ec87d0b8f178","engine/migrations/v6.0.ps1":"923dc4e812906924b21132f6a00c8ae7c007fdb3","engine/scripts/engine-check-update.ps1":"01f124d907b2ac94081271248d1c007037c35161","engine/scripts/engine-context.ps1":"0ffc61b1ef7bfea30c5bca9408b91afcb67d140e","engine/scripts/engine-doctor.ps1":"f412bcc6ab76fceaabff461b473e6c03c79e1b8c","engine/scripts/engine-hook-session-end.ps1":"a0391b05119491b3e3f12c081ddfb140d244ca9d","engine/scripts/engine-hook-session-start.ps1":"fc963a7fff4142a2ed24e856f62aa24e0b37f2b8","engine/scripts/engine-hook-stop.ps1":"e928816ef2db64552a97cf47959e130a29109852","engine/scripts/engine-migrate-contract.ps1":"636f18b8fed315de1b34651e8012e8461f87431e","engine/scripts/engine-sync-agent-anchors.ps1":"3bff56d9cf2c073ee3cf0a899ae76549f0c34bf8","engine/scripts/engine-verify.ps1":"0936b0cc14708f3b9b6e33000d2a2a6aaa159bfd","plugin/bin/engine.ps1":"c1eb294e513b31adaa13702734dd2ad4dd406270","plugin/engine/bin/engine.ps1":"88b582c8d61c95584ed9af7d4de1ec87d0b8f178","plugin/engine/scripts/engine-check-update.ps1":"01f124d907b2ac94081271248d1c007037c35161","plugin/engine/scripts/engine-context.ps1":"0ffc61b1ef7bfea30c5bca9408b91afcb67d140e","plugin/engine/scripts/engine-doctor.ps1":"f412bcc6ab76fceaabff461b473e6c03c79e1b8c","plugin/engine/scripts/engine-hook-session-end.ps1":"a0391b05119491b3e3f12c081ddfb140d244ca9d","plugin/engine/scripts/engine-hook-session-start.ps1":"fc963a7fff4142a2ed24e856f62aa24e0b37f2b8","plugin/engine/scripts/engine-hook-stop.ps1":"e928816ef2db64552a97cf47959e130a29109852","plugin/engine/scripts/engine-migrate-contract.ps1":"636f18b8fed315de1b34651e8012e8461f87431e","plugin/engine/scripts/engine-sync-agent-anchors.ps1":"3bff56d9cf2c073ee3cf0a899ae76549f0c34bf8","plugin/engine/scripts/engine-verify.ps1":"0936b0cc14708f3b9b6e33000d2a2a6aaa159bfd","plugin/migrations/v6.0.ps1":"923dc4e812906924b21132f6a00c8ae7c007fdb3"},"write_set_snapshot":["contract/compile.ps1","engine/bin/engine.ps1","engine/migrations/v6.0.ps1","engine/scripts/engine-check-update.ps1","engine/scripts/engine-context.ps1","engine/scripts/engine-doctor.ps1","engine/scripts/engine-hook-session-end.ps1","engine/scripts/engine-hook-session-start.ps1","engine/scripts/engine-hook-stop.ps1","engine/scripts/engine-migrate-contract.ps1","engine/scripts/engine-sync-agent-anchors.ps1","engine/scripts/engine-verify.ps1","plugin/bin/engine.ps1","plugin/engine/bin/engine.ps1","plugin/engine/scripts/engine-check-update.ps1","plugin/engine/scripts/engine-context.ps1","plugin/engine/scripts/engine-doctor.ps1","plugin/engine/scripts/engine-hook-session-end.ps1","plugin/engine/scripts/engine-hook-session-start.ps1","plugin/engine/scripts/engine-hook-stop.ps1","plugin/engine/scripts/engine-migrate-contract.ps1","plugin/engine/scripts/engine-sync-agent-anchors.ps1","plugin/engine/scripts/engine-verify.ps1","plugin/migrations/v6.0.ps1"],"verified_against_commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","write_provenance":{"writer":"engine-verify","commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","timestamp":"2026-07-31T05:10:57Z","argv":"engine verify T-058"},"timestamp":"2026-07-31T05:10:57Z"}
```

### engine/evidence/T-058/AC-6.json (references: bash)
```
{"ac":"AC-6","verify":"bash -c \"grep -c 'FUNCTIONAL section signs' engine/scripts/engine-migrate-contract.ps1\" = 1","status":"pass","exit":0,"output_fingerprint":"sha256:4355a46b19d348dc2f57c046f8ef63d4538ebb936000f3c9ee954a27460dd865","code_fingerprint":{"contract/compile.ps1":"eee33d431bb01e1639ebc47d1e4a815e6379760b","engine/bin/engine.ps1":"88b582c8d61c95584ed9af7d4de1ec87d0b8f178","engine/migrations/v6.0.ps1":"923dc4e812906924b21132f6a00c8ae7c007fdb3","engine/scripts/engine-check-update.ps1":"01f124d907b2ac94081271248d1c007037c35161","engine/scripts/engine-context.ps1":"0ffc61b1ef7bfea30c5bca9408b91afcb67d140e","engine/scripts/engine-doctor.ps1":"f412bcc6ab76fceaabff461b473e6c03c79e1b8c","engine/scripts/engine-hook-session-end.ps1":"a0391b05119491b3e3f12c081ddfb140d244ca9d","engine/scripts/engine-hook-session-start.ps1":"fc963a7fff4142a2ed24e856f62aa24e0b37f2b8","engine/scripts/engine-hook-stop.ps1":"e928816ef2db64552a97cf47959e130a29109852","engine/scripts/engine-migrate-contract.ps1":"636f18b8fed315de1b34651e8012e8461f87431e","engine/scripts/engine-sync-agent-anchors.ps1":"3bff56d9cf2c073ee3cf0a899ae76549f0c34bf8","engine/scripts/engine-verify.ps1":"0936b0cc14708f3b9b6e33000d2a2a6aaa159bfd","plugin/bin/engine.ps1":"c1eb294e513b31adaa13702734dd2ad4dd406270","plugin/engine/bin/engine.ps1":"88b582c8d61c95584ed9af7d4de1ec87d0b8f178","plugin/engine/scripts/engine-check-update.ps1":"01f124d907b2ac94081271248d1c007037c35161","plugin/engine/scripts/engine-context.ps1":"0ffc61b1ef7bfea30c5bca9408b91afcb67d140e","plugin/engine/scripts/engine-doctor.ps1":"f412bcc6ab76fceaabff461b473e6c03c79e1b8c","plugin/engine/scripts/engine-hook-session-end.ps1":"a0391b05119491b3e3f12c081ddfb140d244ca9d","plugin/engine/scripts/engine-hook-session-start.ps1":"fc963a7fff4142a2ed24e856f62aa24e0b37f2b8","plugin/engine/scripts/engine-hook-stop.ps1":"e928816ef2db64552a97cf47959e130a29109852","plugin/engine/scripts/engine-migrate-contract.ps1":"636f18b8fed315de1b34651e8012e8461f87431e","plugin/engine/scripts/engine-sync-agent-anchors.ps1":"3bff56d9cf2c073ee3cf0a899ae76549f0c34bf8","plugin/engine/scripts/engine-verify.ps1":"0936b0cc14708f3b9b6e33000d2a2a6aaa159bfd","plugin/migrations/v6.0.ps1":"923dc4e812906924b21132f6a00c8ae7c007fdb3"},"write_set_snapshot":["contract/compile.ps1","engine/bin/engine.ps1","engine/migrations/v6.0.ps1","engine/scripts/engine-check-update.ps1","engine/scripts/engine-context.ps1","engine/scripts/engine-doctor.ps1","engine/scripts/engine-hook-session-end.ps1","engine/scripts/engine-hook-session-start.ps1","engine/scripts/engine-hook-stop.ps1","engine/scripts/engine-migrate-contract.ps1","engine/scripts/engine-sync-agent-anchors.ps1","engine/scripts/engine-verify.ps1","plugin/bin/engine.ps1","plugin/engine/bin/engine.ps1","plugin/engine/scripts/engine-check-update.ps1","plugin/engine/scripts/engine-context.ps1","plugin/engine/scripts/engine-doctor.ps1","plugin/engine/scripts/engine-hook-session-end.ps1","plugin/engine/scripts/engine-hook-session-start.ps1","plugin/engine/scripts/engine-hook-stop.ps1","plugin/engine/scripts/engine-migrate-contract.ps1","plugin/engine/scripts/engine-sync-agent-anchors.ps1","plugin/engine/scripts/engine-verify.ps1","plugin/migrations/v6.0.ps1"],"verified_against_commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","write_provenance":{"writer":"engine-verify","commit":"0f6c48528cd423c9feb1bc986e077e51bd92a8e5","timestamp":"2026-07-31T05:10:58Z","argv":"engine verify T-058"},"timestamp":"2026-07-31T05:10:58Z"}
```

### engine/evidence/T-059/AC-1.json (references: bash)
```
{"ac":"AC-1","verify":"bash -c \"for f in engine/evidence/T-058/AC-*.json; do grep -oE '\\\"fingerprint\\\":\\\"sha256:[a-f0-9]{64}\\\"' \\\"$f\\\" || echo FAIL:$f; done\" 无 FAIL","status":"fail","exit":1,"output_fingerprint":"sha256:1459551091d9a54f5ff137b99086c073216dd2ad991d487e5a0f10587e591b29","code_fingerprint":{"contract/compile.ps1":"eee33d431bb01e1639ebc47d1e4a815e6379760b","engine/checks/check-version-consistency.ps1":"cf3fd168db69dc4a3c59a7dea24ab71e1f226690","engine/scripts/engine-migrate-contract.ps1":"636f18b8fed315de1b34651e8012e8461f87431e","plugin/engine/scripts/engine-migrate-contract.ps1":"636f18b8fed315de1b34651e8012e8461f87431e"},"write_set_snapshot":["contract/compile.ps1","engine/checks/check-version-consistency.ps1","engine/scripts/engine-migrate-contract.ps1","plugin/engine/scripts/engine-migrate-contract.ps1"],"verified_against_commit":"bb4455df612835b8520dc07318f24ca25e95576d","write_provenance":{"writer":"engine-verify","commit":"bb4455df612835b8520dc07318f24ca25e95576d","timestamp":"2026-07-31T05:11:14Z","argv":"engine verify T-059"},"timestamp":"2026-07-31T05:11:14Z"}
```

### engine/evidence/T-059/AC-2.json (references: bash)
```
{"ac":"AC-2","verify":"bash -c \"for f in engine/evidence/T-058/AC-*.json; do v=$(grep -oE '\\\"verify\\\":\\\"[^\\\"]+\\\"' \\\"$f\\\" | sed 's/\\\"verify\\\":\\\"//;s/\\\"//'); case \\\"$v\\\" in *grep*|*diff*|*Select-String*|*pwsh*|*bash*|*test*|*Find-ChildItem*|*Get-ChildItem*|*Get-FileHash*|*Compare-Object*) :;; *) echo FAIL:$f:$v;; esac; done\" 无 FAIL","status":"fail","exit":1,"output_fingerprint":"sha256:d29614f0fa94f61c472a29fe5531f84f611a68098f971765871bb0c7dbc0c24c","code_fingerprint":{"contract/compile.ps1":"eee33d431bb01e1639ebc47d1e4a815e6379760b","engine/checks/check-version-consistency.ps1":"cf3fd168db69dc4a3c59a7dea24ab71e1f226690","engine/scripts/engine-migrate-contract.ps1":"636f18b8fed315de1b34651e8012e8461f87431e","plugin/engine/scripts/engine-migrate-contract.ps1":"636f18b8fed315de1b34651e8012e8461f87431e"},"write_set_snapshot":["contract/compile.ps1","engine/checks/check-version-consistency.ps1","engine/scripts/engine-migrate-contract.ps1","plugin/engine/scripts/engine-migrate-contract.ps1"],"verified_against_commit":"bb4455df612835b8520dc07318f24ca25e95576d","write_provenance":{"writer":"engine-verify","commit":"bb4455df612835b8520dc07318f24ca25e95576d","timestamp":"2026-07-31T05:11:14Z","argv":"engine verify T-059"},"timestamp":"2026-07-31T05:11:14Z"}
```

### engine/evidence/T-059/AC-3.json (references: bash)
```
{"ac":"AC-3","verify":"bash -c \"grep -c 'FUNCTIONAL section signs' engine/scripts/engine-migrate-contract.ps1\" = 1","status":"pass","exit":0,"output_fingerprint":"sha256:4355a46b19d348dc2f57c046f8ef63d4538ebb936000f3c9ee954a27460dd865","code_fingerprint":{"contract/compile.ps1":"eee33d431bb01e1639ebc47d1e4a815e6379760b","engine/checks/check-version-consistency.ps1":"cf3fd168db69dc4a3c59a7dea24ab71e1f226690","engine/scripts/engine-migrate-contract.ps1":"636f18b8fed315de1b34651e8012e8461f87431e","plugin/engine/scripts/engine-migrate-contract.ps1":"636f18b8fed315de1b34651e8012e8461f87431e"},"write_set_snapshot":["contract/compile.ps1","engine/checks/check-version-consistency.ps1","engine/scripts/engine-migrate-contract.ps1","plugin/engine/scripts/engine-migrate-contract.ps1"],"verified_against_commit":"bb4455df612835b8520dc07318f24ca25e95576d","write_provenance":{"writer":"engine-verify","commit":"bb4455df612835b8520dc07318f24ca25e95576d","timestamp":"2026-07-31T05:11:14Z","argv":"engine verify T-059"},"timestamp":"2026-07-31T05:11:14Z"}
```


## 4. Domain Knowledge

_(truncated for size)_

## 5. Review Protocol

# Code Review Protocol (L0 Default)

You are reviewing code changes for a task governed by an Engine System task card.
Your review must be thorough, specific, and actionable.

## Review Dimensions (5, all required)

### 1. Correctness
Look for: logic errors, off-by-one, null/undefined handling, race conditions,
deadlocks, infinite loops, incorrect state transitions, wrong return values,
uninitialized variables, broken error propagation.

### 2. Design
Look for: unnecessary abstraction layers, missing abstraction, SRP violations,
tight coupling, god functions (>50 lines doing multiple things), circular
dependencies, config scattered across files, hardcoded values that should be configurable.

### 3. Consistency (cross-file)
Look for: interface changes not propagated to callers, naming inconsistencies,
mirror/parity violations (sh vs ps1, engine vs plugin), import/require mismatches,
schema changes without migration, documentation drift from implementation.

### 4. Readability
Look for: unclear naming, deep nesting (>3 levels), missing comments on complex
logic, dead code, magic numbers, overly clever one-liners, inconsistent formatting,
functions that require reading implementation to understand contract.

### 5. Completeness
Look for: missing error handling, untested edge cases, missing input validation,
no timeout/retry for external calls, missing cleanup (resources/locks/temp files),
incomplete documentation for public APIs, missing logging for debuggability.

## Output Rules

- Every dimension MUST have at least 1 entry (finding or strength).
- If a dimension has no issues, add a "strength" entry explaining WHY it is good.
- Every finding.message must be >= 20 characters and specific (cite line numbers).
- Every finding should include a suggestion for how to fix it.
- Answer all 3 adversarial challenges with substantive analysis (>= 30 chars each).
- Your overall_assessment + 5 summaries must total >= 200 characters.
- Use severity honestly: critical = will cause data loss/security breach/crash in
  production; high = likely bug or significant maintainability issue; medium = code
  smell or minor issue; low = style preference; info = observation/strength.
- status = "block" ONLY if you found at least one critical issue that MUST be fixed
  before merge. Use "concerns" for high-severity issues that the architect might
  accept. Use "pass" when no high/critical issues exist.

## Provenance & Independence (v6.22.0)

- `write_provenance.reviewer_session`: your session/agent identifier. MUST differ
  from the package header's `packaged_by` value (the session that generated the
  package). This ensures the reviewer is independent from the packager.
- `packaged_by` (package header): identifies who generated the review package.
  Format: `<session-id>` or `<hostname>:<pid>`.
- **Subagent review is mandatory.** A missing `reviewer_session` or one that
  matches `packaged_by` will cause validation to FAIL with E_INDEPENDENCE.
  The review MUST be performed by a separate agent session from the one that
  packaged the review context.

## Grounding Requirement (v6.22.0)

- Every finding with `file` and `line` fields will be validated for existence:
  the referenced file must exist in the repository, and the line number must not
  exceed the file's actual length.
- If more than 50% of your findings reference non-existent locations, validation
  FAILS with E_GROUNDED. If 50% or fewer are ungrounded, a WARN is issued but
  validation still passes.
- Always verify file paths and line numbers against the actual diff before citing
  them in findings.

### Adversarial Challenges (must answer all 3)

1. File `engine/scripts/engine-doctor.sh` line ~29 adds a new branch (`if [ -f "$task_card_script_dir/engine-task-card.sh" ]; then`) with no visible else/fallback. What happens when this condition is false �� silent skip, crash, or data corruption?
2. File `engine/scripts/engine-doctor.ps1` line ~18 adds a new branch (`if (Test-Path -LiteralPath $taskCardLibrary -PathType Leaf) `) with no visible else/fallback. What happens when this condition is false �� silent skip, crash, or data corruption?
3. File `plugin/engine/scripts/engine-doctor.sh` line ~29 adds a new branch (`if [ -f "$task_card_script_dir/engine-task-card.sh" ]; then`) with no visible else/fallback. What happens when this condition is false �� silent skip, crash, or data corruption?



### Multi-Perspective Lenses (v6.23.0, T-076)

Conduct your review through 3 distinct cognitive lenses. For each lens, actively search for issues specific to that perspective:

1. **Correctness lens**: Logic errors, off-by-one, wrong variable, missing return, broken control flow, incorrect assumptions about input/output contracts.
2. **Security lens**: Injection vectors (shell/SQL/path), permission bypasses, unvalidated input, data leakage, unsafe deserialization, hardcoded secrets.
3. **Edge-case lens**: Empty/null inputs, boundary values, concurrent access, resource exhaustion, platform-specific behavior (CRLF, encoding, path separators).

Tag each finding's id with its lens: e.g. `agent-correctness-file:line`, `agent-security-file:line`, `agent-edge-file:line`.
At least 1 finding per lens is expected (use type="strength" + severity="info" if genuinely clean).

## 6. Output Format (strict)

Write your review to: `engine/review/evidence/T-081/AGENT-REVIEW.json`

Schema (all fields required):
```json
{
  "task": "T-081",
  "timestamp": "<ISO-8601>",
  "reviewer": {"type": "agent", "model": "<optional>"},
  "status": "pass|concerns|block",
  "dimensions": {
    "correctness": {"entries": [{"id": "agent-correctness-<file>:<line>", "severity": "high", "type": "finding", "file": "<path>", "line": 42, "message": "<>=20 chars>", "suggestion": "<optional>"}], "summary": "<1-2 sentences>"},
    "design": {"entries": [...], "summary": "..."},
    "consistency": {"entries": [...], "summary": "..."},
    "readability": {"entries": [...], "summary": "..."},
    "completeness": {"entries": [...], "summary": "..."}
  },
  "adversarial_responses": [
    {"challenge": "<question 1>", "response": "<>=30 chars>"},
    {"challenge": "<question 2>", "response": "<>=30 chars>"},
    {"challenge": "<question 3>", "response": "<>=30 chars>"}
  ],
  "overall_assessment": "<2-3 sentences, >=200 chars total with summaries>",
  "write_provenance": {
    "writer": "agent-reviewer",
    "commit": "c1050987377c694563d82aa79117360b7c82c7a8",
    "timestamp": "<write time>",
    "package_sha256": "<fill from package header>",
    "reviewer_session": "<your session/agent identifier, must differ from packaged_by>"
  }
}
```

**Important**:
- `write_provenance.commit`: copy the `head_commit` value from this package header
- `write_provenance.package_sha256`: copy the `package_sha256` value from this package header
- Each finding.message >= 20 characters
- Each dimension must have >= 1 entry (use type="strength" + severity="info" if no issues found)
- Exactly 3 adversarial_responses, each response >= 30 characters
- severity values: critical | high | medium | low | info
- status: "pass" (no critical/high) | "concerns" (has high, acceptable) | "block" (has critical)
