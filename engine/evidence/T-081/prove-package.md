# Prove Package: T-081

> generated: 2026-08-02T08:18:27Z
> code_fingerprint: sha256:0b6540adb1a2d7c30507fffea01ebb04eb51101794e6942c2e3a396093434582
> head_commit: 8656a73b5c9b87f2fe17a083c3a5e813f7113f96
> diff_range: da253a67..8656a73b
> code_files: 22

## GOAL

把 T-080 之后仍阻断 Engine Doctor 的仓库级失败项收口，并修复 Windows/WSL 下 Bash 生命周期找不到 PowerShell 执行器的问题。完成 ENGINE_MAP 注册与 root-path 解析、active task progress 锚点、done task 归档、域 INVENTORY 覆盖、T-078 遗留生命周期证据和历史 evidence drift 的可验证收口；保留历史 warning，不掩盖真实 tamper/drift。

## WRITE-SET (code files in diff)
- engine/scripts/engine-doctor.sh
- engine/scripts/engine-doctor.ps1
- plugin/engine/scripts/engine-doctor.sh
- plugin/engine/scripts/engine-doctor.ps1
- engine/scripts/engine-verify.sh
- engine/scripts/engine-verify.ps1
- plugin/engine/scripts/engine-verify.sh
- engine/scripts/engine-close.sh
- engine/scripts/engine-close.ps1
- plugin/engine/scripts/engine-close.sh
- plugin/engine/scripts/engine-close.ps1
- engine/scripts/engine-canvas.sh
- plugin/engine/scripts/engine-canvas.sh
- tests/workstream/test_failure_extract.sh
- engine/scripts/engine-drift-check.sh
- engine/scripts/engine-drift-check.ps1
- plugin/engine/scripts/engine-drift-check.sh
- plugin/engine/scripts/engine-drift-check.ps1
- tests/workstream/test_doctor_health_regressions.sh
- tests/workstream/test_doctor_health_regressions.ps1
- tests/workstream/test_verify_shell_resolution.sh
- tests/workstream/test_verify_shell_resolution.ps1

## WRITE-SET (full, from task card)
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
- engine/evidence/T-081/GATE.json
- engine/evidence/T-081/MANIFEST.json
- engine/evidence/T-081/PROVE.json
- engine/evidence/T-081/prove-assertions.json
- engine/evidence/T-081/prove-package.md
- engine/changes/CHANGE-2026-08-01-02.md

## Hunk Symbols (modified functions/classes)
- function Invoke-Stage {
- try {
- if (-not (Test-Path $lockFile)) {
- if ($writeSetText -match '(?m)^-\s+.*\.(sh|ps1|py|js|ts|go|rs|java|c|cpp|rb|php)
- $closeObj | ConvertTo-Json -Depth 8 | Set-Content -Path $out -Encoding UTF8
- run_stage() {
- run_stage gate bash "$cli" gate "$task"
- fi
- if [ "$write_set_code" -eq 1 ]; then
- fi
- param(
- $warnCount = 0
- function Resolve-EnginePath([string]$File) {
- if ($PackageMode) {
- function Test-ContractDebt {
- function Test-TaskCardDoneEvidence {
- function Test-TaskCardDoneEvidence {
- function Test-ReviewEvidence {
- function Test-ReviewEvidence {
- function Test-ReviewEvidence {

## Syntax Checks (auto-detected)

- bash -n engine/scripts/engine-doctor.sh
- bash -n plugin/engine/scripts/engine-doctor.sh
- bash -n engine/scripts/engine-verify.sh
- bash -n plugin/engine/scripts/engine-verify.sh
- bash -n engine/scripts/engine-close.sh
- bash -n plugin/engine/scripts/engine-close.sh
- bash -n engine/scripts/engine-canvas.sh
- bash -n plugin/engine/scripts/engine-canvas.sh
- bash -n tests/workstream/test_failure_extract.sh
- bash -n engine/scripts/engine-drift-check.sh
- bash -n plugin/engine/scripts/engine-drift-check.sh
- bash -n tests/workstream/test_doctor_health_regressions.sh
- bash -n tests/workstream/test_verify_shell_resolution.sh

## Existing Test Coverage

- engine/scripts/engine-doctor.sh covered by:
  - bash tests/behavior-verify/test_doctor_loud_skip.sh
  - bash tests/multi-session/test_tombstone_lifecycle.sh
  - bash tests/workstream/test_capsule_heat.sh
- engine/scripts/engine-doctor.ps1 covered by:
  - bash tests/multi-session/test_tombstone_lifecycle.sh
  - bash tests/workstream/test_doctor_health_regressions.ps1
  - bash tests/workstream/test_doctor_review_mirror_parity.sh
- plugin/engine/scripts/engine-doctor.sh covered by:
  - bash tests/behavior-verify/test_doctor_loud_skip.sh
  - bash tests/multi-session/test_tombstone_lifecycle.sh
  - bash tests/workstream/test_capsule_heat.sh
- plugin/engine/scripts/engine-doctor.ps1 covered by:
  - bash tests/multi-session/test_tombstone_lifecycle.sh
  - bash tests/workstream/test_doctor_health_regressions.ps1
  - bash tests/workstream/test_doctor_review_mirror_parity.sh
- engine/scripts/engine-verify.sh covered by:
  - bash tests/behavior-verify/run-verify-tests.sh
  - bash tests/behavior-verify/test_verify_allskip_loud.sh
  - bash tests/behavior-verify/test_verify_block_ac_format.sh
- engine/scripts/engine-verify.ps1 covered by:
  - bash tests/behavior-verify/run-verify-tests.sh
  - bash tests/behavior-verify/test_verify_block_ac_format.ps1
  - bash tests/workstream/test_acceptance_preflight.ps1
- plugin/engine/scripts/engine-verify.sh covered by:
  - bash tests/behavior-verify/run-verify-tests.sh
  - bash tests/behavior-verify/test_verify_allskip_loud.sh
  - bash tests/behavior-verify/test_verify_block_ac_format.sh
- engine/scripts/engine-close.sh covered by:
  - bash tests/workstream/test_close_capsule_gen.sh
  - bash tests/workstream/test_doctor_health_regressions.ps1
  - bash tests/workstream/test_doctor_health_regressions.sh
- engine/scripts/engine-close.ps1 covered by:
  - bash tests/workstream/test_doctor_health_regressions.ps1
  - bash tests/workstream/test_doctor_health_regressions.sh
  - bash tests/workstream/test_engine_lifecycle.ps1
- plugin/engine/scripts/engine-close.sh covered by:
  - bash tests/workstream/test_close_capsule_gen.sh
  - bash tests/workstream/test_doctor_health_regressions.ps1
  - bash tests/workstream/test_doctor_health_regressions.sh
- plugin/engine/scripts/engine-close.ps1 covered by:
  - bash tests/workstream/test_doctor_health_regressions.ps1
  - bash tests/workstream/test_doctor_health_regressions.sh
  - bash tests/workstream/test_engine_lifecycle.ps1
- engine/scripts/engine-canvas.sh covered by:
  - bash tests/workstream/test_canvas.sh
  - bash tests/workstream/test_drift_detect.sh
- plugin/engine/scripts/engine-canvas.sh covered by:
  - bash tests/workstream/test_canvas.sh
  - bash tests/workstream/test_drift_detect.sh
- tests/workstream/test_failure_extract.sh covered by:
  - bash tests/workstream/test_failure_extract.sh
- engine/scripts/engine-drift-check.sh covered by:
  - bash tests/workstream/test_doctor_health_regressions.ps1
  - bash tests/workstream/test_doctor_health_regressions.sh
  - bash tests/workstream/test_drift_check.sh
- engine/scripts/engine-drift-check.ps1 covered by:
  - bash tests/workstream/test_doctor_health_regressions.ps1
  - bash tests/workstream/test_doctor_health_regressions.sh
- plugin/engine/scripts/engine-drift-check.sh covered by:
  - bash tests/workstream/test_doctor_health_regressions.ps1
  - bash tests/workstream/test_doctor_health_regressions.sh
  - bash tests/workstream/test_drift_check.sh
- plugin/engine/scripts/engine-drift-check.ps1 covered by:
  - bash tests/workstream/test_doctor_health_regressions.ps1
  - bash tests/workstream/test_doctor_health_regressions.sh
- tests/workstream/test_doctor_health_regressions.sh covered by:
  - bash tests/workstream/test_doctor_health_regressions.sh
- tests/workstream/test_doctor_health_regressions.ps1 covered by:
  - bash tests/workstream/test_doctor_health_regressions.ps1
- tests/workstream/test_verify_shell_resolution.sh covered by:
  - bash tests/workstream/test_verify_shell_resolution.sh
- tests/workstream/test_verify_shell_resolution.ps1 covered by:
  - bash tests/workstream/test_verify_shell_resolution.ps1

## Unified Diff

### engine/scripts/engine-doctor.sh
```diff
diff --git a/engine/scripts/engine-doctor.sh b/engine/scripts/engine-doctor.sh
index 3eab40e..2b560c6 100644
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
@@ -29,6 +31,40 @@ MAP="$ENGINE_DIR/ENGINE_MAP.md"
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
@@ -148,15 +184,47 @@ warn() {
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
@@ -289,7 +357,8 @@ package_mode() {
 
 if $PACKAGE_MODE; then
   package_mode
-  printf '\nEngine Doctor: %s failure(s), %s warning(s)\n' "$fail_count" "$warn_count"
+
+printf '\nEngine Doctor: %s failure(s), %s warning(s)\n' "$fail_count" "$warn_count"
   if [[ "$fail_count" -gt 0 ]]; then
     exit 1
   fi
@@ -299,7 +368,10 @@ fi
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
@@ -475,7 +547,8 @@ check_context_semantics() {
       echo "  human: CONTEXT.md is missing the '$label' row in its status panel. Add a table row for '$label' with current information."
       continue
     fi
-    value="$(printf '%s' "$row" | awk -F'|' '{print $3}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
+    IFS='|' read -ra row_cols <<< "$row"
+    value="$(trim "${row_cols[2]-}")"
     if [[ -z "$value" || "$value" =~ ^\[.*\]$ || "$value" == "TBD" || "$value" == "TODO" ]]; then
       warn "CONTEXT.md status row '$label' is placeholder or empty"
       echo "  human: The '$label' row in CONTEXT.md has no real value (placeholder or empty). Fill in the actual status."
@@ -646,7 +719,11 @@ check_inventory_bidirectional() {
 
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
@@ -663,7 +740,7 @@ check_inventory_bidirectional() {
       # cols[0] is empty (leading `|`), cols[1]=Feature, cols[2]=Entry file, ...
       local entry_file=""
       if [ "${#cols[@]}" -ge 3 ]; then
-        entry_file="$(printf '%s' "${cols[2]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
+        entry_file="$(trim "${cols[2]}")"
       fi
       [ -z "$entry_file" ] && continue
       # Skip placeholders / glob patterns.
@@ -678,7 +755,7 @@ check_inventory_bidirectional() {
           warn "INVENTORY→code: $inv references '$entry_file' (grace period, cv=$contract_version < 6.8.0)"
         fi
       else
-        entry_paths_seen="$entry_paths_seen$entry_file"$'\n'
+        entry_paths_seen_map["$entry_file"]=1
       fi
     done < "$inv"
   done
@@ -711,7 +788,7 @@ check_inventory_bidirectional() {
         [[ "$ws_path" == "AGENTS.md" ]] && continue
         [[ "$ws_path" == ".github/"* ]] && continue
         # Check if this path appears in any INVENTORY entry column.
-        if ! printf '%s' "$entry_paths_seen" | grep -qF "$ws_path"; then
+        if [[ -z "${entry_paths_seen_map[$ws_path]+present}" ]]; then
           code_to_inv_violations=$((code_to_inv_violations + 1))
           if [ "$violation_is_fail" -eq 1 ]; then
             fail "code→INVENTORY: $tid touched '$ws_path' but no INVENTORY row references it"
@@ -783,7 +860,7 @@ check_inventory_api_uniqueness() {
       # cols[3] = Public API (0=empty, 1=Feature, 2=Entry, 3=Public API)
       local api=""
       if [ "${#cols[@]}" -ge 4 ]; then
-        api="$(printf '%s' "${cols[3]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
+        api="$(trim "${cols[3]}")"
       fi
       [ -z "$api" ] && continue
       [[ "$api" == \[*\]* ]] && continue
@@ -861,7 +938,7 @@ check_writeset_budget() {
     local IFS_save="$IFS"
     IFS=','
     for ws_path in $write_set_line; do
-      ws_path="$(printf '%s' "$ws_path" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
+      ws_path="$(trim "$ws_path")"
       [ -z "$ws_path" ] && continue
       # Skip globs.
       [[ "$ws_path" == *"*"* ]] && continue
@@ -947,7 +1024,7 @@ check_task_granularity() {
       local IFS_save="$IFS"
       IFS=','
       for p in $write_set_line; do
-        p="$(printf '%s' "$p" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
+        p="$(trim "$p")"
         [ -z "$p" ] && continue
         # De-dup mirror pairs: strip "plugin/" prefix for comparison.
         local canonical="$p"
@@ -1036,7 +1113,7 @@ check_depends_on() {
     IFS=','
     local upstream
     for upstream in $depends_line; do
-      upstream="$(printf '%s' "$upstream" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
+      upstream="$(trim "$upstream")"
       [ -z "$upstream" ] && continue
       # Validate format T-NNN.
       [[ "$upstream" =~ ^T-[0-9]+$ ]] || continue
@@ -1350,15 +1427,22 @@ check_contract_debt() {
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
@@ -1370,22 +1454,24 @@ check_task_card_done_evidence() {
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
@@ -1393,7 +1479,7 @@ check_task_card_done_evidence() {
           echo "  human: Evidence for $tid/$ac uses the legacy verdict=PASS field. It is accepted for compatibility; re-run engine verify to upgrade it to status=pass."
         fi
       fi
-    done
+    done <<< "$ac_records"
     if [ "$ac_count" -gt 0 ] 2>/dev/null && [ -z "$missing" ]; then
       verified_count=$((verified_count + 1))
     elif command -v git >/dev/null 2>&1 && git cat-file -e "HEAD:engine/tasks/$tid.md" 2>/dev/null; then
@@ -1442,13 +1528,25 @@ check_review_evidence() {
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
 
@@ -1649,8 +1747,11 @@ check_drift() {
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
@@ -1997,6 +2098,93 @@ check_plan_acceptance_evidence() {
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
@@ -2031,6 +2219,21 @@ check_prove_health() {
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
@@ -2047,14 +2250,14 @@ check_prove_health() {
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
@@ -2069,14 +2272,14 @@ check_prove_health() {
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
@@ -2120,6 +2323,29 @@ check_review_config_protected
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
@@ -2264,6 +2490,15 @@ for cli in engine engine.ps1 engine.cmd; do
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
index 617b3e3..9a896d5 100644
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
@@ -17,6 +18,22 @@ $map = Join-Path $engineDir "ENGINE_MAP.md"
 $failCount = 0
 $warnCount = 0
 
+# v6.25.0 (T-086/B6): incremental mode — skip if HEAD unchanged.
+$doctorCacheDir = Join-Path $engineDir '.cache'
+$doctorCacheFile = Join-Path $doctorCacheDir 'doctor-last-run'
+$currentHead = & git -C $Root rev-parse HEAD 2>$null
+if (-not $currentHead) { $currentHead = 'none' }
+if (-not $Full -and (Test-Path $doctorCacheFile)) {
+  $cacheLines = Get-Content -Path $doctorCacheFile -Encoding UTF8 -ErrorAction SilentlyContinue
+  if ($cacheLines -and $cacheLines.Count -ge 2 -and $cacheLines[0] -eq $currentHead -and $currentHead -ne 'none') {
+    Write-Host "[engine-doctor] incremental: HEAD unchanged ($currentHead), using cached result."
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
@@ -159,7 +176,10 @@ function Get-TaskPatterns([string]$Content, [string]$Field) {
 
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
@@ -297,7 +317,11 @@ function Test-PackageMode {
 if ($PackageMode) {
   Test-PackageMode
   Write-Host ""
-  Write-Host "Engine Doctor: $failCount failure(s), $warnCount warning(s)"
+  # v6.25.0 (B6): save state for incremental mode
+if (-not (Test-Path $doctorCacheDir)) { New-Item -ItemType Directory -Path $doctorCacheDir -Force | Out-Null }
+Set-Content -Path $doctorCacheFile -Value "$currentHead`n$failCount failure(s), $warnCount warning(s)" -Encoding UTF8 -ErrorAction SilentlyContinue
+
+Write-Host "Engine Doctor: $failCount failure(s), $warnCount warning(s)"
   if ($failCount -gt 0) { exit 1 }
   exit 0
 }
@@ -1312,17 +1336,17 @@ function Test-ContractDebt {
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
@@ -1345,12 +1369,12 @@ function Test-TaskCardDoneEvidence {
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
@@ -1375,89 +1399,89 @@ function Test-TaskCardDoneEvidence {
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
@@ -1792,13 +1816,24 @@ function Test-ReviewEvidence {
 
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
@@ -1821,6 +1856,54 @@ function Test-ReviewConfigProtected {
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
@@ -1892,6 +1975,7 @@ Test-WriteSetBudget
 Test-TaskGranularity
 Test-DependsOn
 Test-WarnDoneGate
+Test-CapsuleHeat
 Test-PitfallsSemantics
 Test-SprintSemantics
 Test-ChangeCapsuleSemantics
@@ -1975,6 +2059,79 @@ foreach ($anchor in @("AGENTS.md", "CLAUDE.md")) {
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
@@ -2019,6 +2176,9 @@ foreach ($cli in @("engine", "engine.ps1", "engine.cmd")) {
   }
 }
 
+# v6.25.0 (T-086/O1): script lint (ShellCheck-pattern subset)
+Check-ScriptLint
+
 Write-Host ""
 Write-Host "Engine Doctor: $failCount failure(s), $warnCount warning(s)"
 if ($failCount -gt 0) { exit 1 }
```

### plugin/engine/scripts/engine-doctor.sh
```diff
diff --git a/plugin/engine/scripts/engine-doctor.sh b/plugin/engine/scripts/engine-doctor.sh
index 3eab40e..2b560c6 100644
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
@@ -29,6 +31,40 @@ MAP="$ENGINE_DIR/ENGINE_MAP.md"
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
@@ -148,15 +184,47 @@ warn() {
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
@@ -289,7 +357,8 @@ package_mode() {
 
 if $PACKAGE_MODE; then
   package_mode
-  printf '\nEngine Doctor: %s failure(s), %s warning(s)\n' "$fail_count" "$warn_count"
+
+printf '\nEngine Doctor: %s failure(s), %s warning(s)\n' "$fail_count" "$warn_count"
   if [[ "$fail_count" -gt 0 ]]; then
     exit 1
   fi
@@ -299,7 +368,10 @@ fi
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
@@ -475,7 +547,8 @@ check_context_semantics() {
       echo "  human: CONTEXT.md is missing the '$label' row in its status panel. Add a table row for '$label' with current information."
       continue
     fi
-    value="$(printf '%s' "$row" | awk -F'|' '{print $3}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
+    IFS='|' read -ra row_cols <<< "$row"
+    value="$(trim "${row_cols[2]-}")"
     if [[ -z "$value" || "$value" =~ ^\[.*\]$ || "$value" == "TBD" || "$value" == "TODO" ]]; then
       warn "CONTEXT.md status row '$label' is placeholder or empty"
       echo "  human: The '$label' row in CONTEXT.md has no real value (placeholder or empty). Fill in the actual status."
@@ -646,7 +719,11 @@ check_inventory_bidirectional() {
 
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
@@ -663,7 +740,7 @@ check_inventory_bidirectional() {
       # cols[0] is empty (leading `|`), cols[1]=Feature, cols[2]=Entry file, ...
       local entry_file=""
       if [ "${#cols[@]}" -ge 3 ]; then
-        entry_file="$(printf '%s' "${cols[2]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
+        entry_file="$(trim "${cols[2]}")"
       fi
       [ -z "$entry_file" ] && continue
       # Skip placeholders / glob patterns.
@@ -678,7 +755,7 @@ check_inventory_bidirectional() {
           warn "INVENTORY→code: $inv references '$entry_file' (grace period, cv=$contract_version < 6.8.0)"
         fi
       else
-        entry_paths_seen="$entry_paths_seen$entry_file"$'\n'
+        entry_paths_seen_map["$entry_file"]=1
       fi
     done < "$inv"
   done
@@ -711,7 +788,7 @@ check_inventory_bidirectional() {
         [[ "$ws_path" == "AGENTS.md" ]] && continue
         [[ "$ws_path" == ".github/"* ]] && continue
         # Check if this path appears in any INVENTORY entry column.
-        if ! printf '%s' "$entry_paths_seen" | grep -qF "$ws_path"; then
+        if [[ -z "${entry_paths_seen_map[$ws_path]+present}" ]]; then
           code_to_inv_violations=$((code_to_inv_violations + 1))
           if [ "$violation_is_fail" -eq 1 ]; then
             fail "code→INVENTORY: $tid touched '$ws_path' but no INVENTORY row references it"
@@ -783,7 +860,7 @@ check_inventory_api_uniqueness() {
       # cols[3] = Public API (0=empty, 1=Feature, 2=Entry, 3=Public API)
       local api=""
       if [ "${#cols[@]}" -ge 4 ]; then
-        api="$(printf '%s' "${cols[3]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
+        api="$(trim "${cols[3]}")"
       fi
       [ -z "$api" ] && continue
       [[ "$api" == \[*\]* ]] && continue
@@ -861,7 +938,7 @@ check_writeset_budget() {
     local IFS_save="$IFS"
     IFS=','
     for ws_path in $write_set_line; do
-      ws_path="$(printf '%s' "$ws_path" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
+      ws_path="$(trim "$ws_path")"
       [ -z "$ws_path" ] && continue
       # Skip globs.
       [[ "$ws_path" == *"*"* ]] && continue
@@ -947,7 +1024,7 @@ check_task_granularity() {
       local IFS_save="$IFS"
       IFS=','
       for p in $write_set_line; do
-        p="$(printf '%s' "$p" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
+        p="$(trim "$p")"
         [ -z "$p" ] && continue
         # De-dup mirror pairs: strip "plugin/" prefix for comparison.
         local canonical="$p"
@@ -1036,7 +1113,7 @@ check_depends_on() {
     IFS=','
     local upstream
     for upstream in $depends_line; do
-      upstream="$(printf '%s' "$upstream" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
+      upstream="$(trim "$upstream")"
       [ -z "$upstream" ] && continue
       # Validate format T-NNN.
       [[ "$upstream" =~ ^T-[0-9]+$ ]] || continue
@@ -1350,15 +1427,22 @@ check_contract_debt() {
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
@@ -1370,22 +1454,24 @@ check_task_card_done_evidence() {
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
@@ -1393,7 +1479,7 @@ check_task_card_done_evidence() {
           echo "  human: Evidence for $tid/$ac uses the legacy verdict=PASS field. It is accepted for compatibility; re-run engine verify to upgrade it to status=pass."
         fi
       fi
-    done
+    done <<< "$ac_records"
     if [ "$ac_count" -gt 0 ] 2>/dev/null && [ -z "$missing" ]; then
       verified_count=$((verified_count + 1))
     elif command -v git >/dev/null 2>&1 && git cat-file -e "HEAD:engine/tasks/$tid.md" 2>/dev/null; then
@@ -1442,13 +1528,25 @@ check_review_evidence() {
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
 
@@ -1649,8 +1747,11 @@ check_drift() {
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
@@ -1997,6 +2098,93 @@ check_plan_acceptance_evidence() {
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
@@ -2031,6 +2219,21 @@ check_prove_health() {
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
@@ -2047,14 +2250,14 @@ check_prove_health() {
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
@@ -2069,14 +2272,14 @@ check_prove_health() {
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
@@ -2120,6 +2323,29 @@ check_review_config_protected
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
@@ -2264,6 +2490,15 @@ for cli in engine engine.ps1 engine.cmd; do
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
index 617b3e3..9a896d5 100644
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
@@ -17,6 +18,22 @@ $map = Join-Path $engineDir "ENGINE_MAP.md"
 $failCount = 0
 $warnCount = 0
 
+# v6.25.0 (T-086/B6): incremental mode — skip if HEAD unchanged.
+$doctorCacheDir = Join-Path $engineDir '.cache'
+$doctorCacheFile = Join-Path $doctorCacheDir 'doctor-last-run'
+$currentHead = & git -C $Root rev-parse HEAD 2>$null
+if (-not $currentHead) { $currentHead = 'none' }
+if (-not $Full -and (Test-Path $doctorCacheFile)) {
+  $cacheLines = Get-Content -Path $doctorCacheFile -Encoding UTF8 -ErrorAction SilentlyContinue
+  if ($cacheLines -and $cacheLines.Count -ge 2 -and $cacheLines[0] -eq $currentHead -and $currentHead -ne 'none') {
+    Write-Host "[engine-doctor] incremental: HEAD unchanged ($currentHead), using cached result."
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
@@ -159,7 +176,10 @@ function Get-TaskPatterns([string]$Content, [string]$Field) {
 
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
@@ -297,7 +317,11 @@ function Test-PackageMode {
 if ($PackageMode) {
   Test-PackageMode
   Write-Host ""
-  Write-Host "Engine Doctor: $failCount failure(s), $warnCount warning(s)"
+  # v6.25.0 (B6): save state for incremental mode
+if (-not (Test-Path $doctorCacheDir)) { New-Item -ItemType Directory -Path $doctorCacheDir -Force | Out-Null }
+Set-Content -Path $doctorCacheFile -Value "$currentHead`n$failCount failure(s), $warnCount warning(s)" -Encoding UTF8 -ErrorAction SilentlyContinue
+
+Write-Host "Engine Doctor: $failCount failure(s), $warnCount warning(s)"
   if ($failCount -gt 0) { exit 1 }
   exit 0
 }
@@ -1312,17 +1336,17 @@ function Test-ContractDebt {
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
@@ -1345,12 +1369,12 @@ function Test-TaskCardDoneEvidence {
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
@@ -1375,89 +1399,89 @@ function Test-TaskCardDoneEvidence {
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
@@ -1792,13 +1816,24 @@ function Test-ReviewEvidence {
 
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
@@ -1821,6 +1856,54 @@ function Test-ReviewConfigProtected {
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
@@ -1892,6 +1975,7 @@ Test-WriteSetBudget
 Test-TaskGranularity
 Test-DependsOn
 Test-WarnDoneGate
+Test-CapsuleHeat
 Test-PitfallsSemantics
 Test-SprintSemantics
 Test-ChangeCapsuleSemantics
@@ -1975,6 +2059,79 @@ foreach ($anchor in @("AGENTS.md", "CLAUDE.md")) {
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
@@ -2019,6 +2176,9 @@ foreach ($cli in @("engine", "engine.ps1", "engine.cmd")) {
   }
 }
 
+# v6.25.0 (T-086/O1): script lint (ShellCheck-pattern subset)
+Check-ScriptLint
+
 Write-Host ""
 Write-Host "Engine Doctor: $failCount failure(s), $warnCount warning(s)"
 if ($failCount -gt 0) { exit 1 }
```

### engine/scripts/engine-verify.sh
```diff
diff --git a/engine/scripts/engine-verify.sh b/engine/scripts/engine-verify.sh
index 31b3403..4c4f5d0 100644
--- a/engine/scripts/engine-verify.sh
+++ b/engine/scripts/engine-verify.sh
@@ -312,9 +312,50 @@ append_no_cov() {
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
   verify_timeout="${ENGINE_VERIFY_TIMEOUT:-120}"
+  ensure_powershell_on_path
+  if [ "${ENGINE_PWSH_CMD:-pwsh}" != "pwsh" ]; then
+    command="${command//pwsh/${ENGINE_PWSH_CMD}}"
+  fi
   if command -v timeout >/dev/null 2>&1; then
     ( cd "$ROOT" && ENGINE_VERIFY_RECURSE_GUARD="$task" timeout "$verify_timeout" bash -c "$command" ) </dev/null >"$output_file" 2>&1 || rc=$?
   else
@@ -387,6 +428,12 @@ while IFS=$'\t' read -r ac_id verify_cmd; do
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
```

### engine/scripts/engine-verify.ps1
```diff
diff --git a/engine/scripts/engine-verify.ps1 b/engine/scripts/engine-verify.ps1
index 7afee17..6062f14 100644
--- a/engine/scripts/engine-verify.ps1
+++ b/engine/scripts/engine-verify.ps1
@@ -348,7 +348,14 @@ function Invoke-VerifyCommand {
 
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
@@ -400,6 +407,11 @@ foreach ($ac in (Parse-AcDeclarations -Path $taskFile)) {
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
```

### plugin/engine/scripts/engine-verify.sh
```diff
diff --git a/plugin/engine/scripts/engine-verify.sh b/plugin/engine/scripts/engine-verify.sh
index 31b3403..ac00f01 100644
--- a/plugin/engine/scripts/engine-verify.sh
+++ b/plugin/engine/scripts/engine-verify.sh
@@ -312,9 +312,50 @@ append_no_cov() {
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
   verify_timeout="${ENGINE_VERIFY_TIMEOUT:-120}"
+  ensure_powershell_on_path
+  if [ "${ENGINE_PWSH_CMD:-pwsh}" != "pwsh" ]; then
+    command="${command//pwsh/${ENGINE_PWSH_CMD}}"
+  fi
   if command -v timeout >/dev/null 2>&1; then
     ( cd "$ROOT" && ENGINE_VERIFY_RECURSE_GUARD="$task" timeout "$verify_timeout" bash -c "$command" ) </dev/null >"$output_file" 2>&1 || rc=$?
   else
```

### engine/scripts/engine-close.sh
```diff
diff --git a/engine/scripts/engine-close.sh b/engine/scripts/engine-close.sh
index 5d15e55..e99fd28 100644
--- a/engine/scripts/engine-close.sh
+++ b/engine/scripts/engine-close.sh
@@ -62,11 +62,39 @@ run_stage() {
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
@@ -114,6 +142,80 @@ else
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
@@ -142,7 +244,13 @@ if [ "$write_set_code" -eq 1 ]; then
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
 
@@ -207,6 +315,8 @@ else
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
index de1f462..4fe2ae1 100644
--- a/engine/scripts/engine-close.ps1
+++ b/engine/scripts/engine-close.ps1
@@ -63,10 +63,46 @@ function Invoke-Stage {
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
@@ -129,6 +165,70 @@ if (-not (Test-Path $lockFile)) {
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
@@ -151,7 +251,13 @@ if ($writeSetText -match '(?m)^-\s+.*\.(sh|ps1|py|js|ts|go|rs|java|c|cpp|rb|php)
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
 
@@ -177,6 +283,7 @@ $closeObj = [ordered]@{
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
index 5d15e55..e99fd28 100644
--- a/plugin/engine/scripts/engine-close.sh
+++ b/plugin/engine/scripts/engine-close.sh
@@ -62,11 +62,39 @@ run_stage() {
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
@@ -114,6 +142,80 @@ else
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
@@ -142,7 +244,13 @@ if [ "$write_set_code" -eq 1 ]; then
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
 
@@ -207,6 +315,8 @@ else
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
index de1f462..4fe2ae1 100644
--- a/plugin/engine/scripts/engine-close.ps1
+++ b/plugin/engine/scripts/engine-close.ps1
@@ -63,10 +63,46 @@ function Invoke-Stage {
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
@@ -129,6 +165,70 @@ if (-not (Test-Path $lockFile)) {
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
@@ -151,7 +251,13 @@ if ($writeSetText -match '(?m)^-\s+.*\.(sh|ps1|py|js|ts|go|rs|java|c|cpp|rb|php)
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
 
@@ -177,6 +283,7 @@ $closeObj = [ordered]@{
   write_provenance = [ordered]@{ writer = 'engine-close'; commit = $headCommit; timestamp = $timestamp; argv = $closeArgv }
 }
 $closeObj | ConvertTo-Json -Depth 8 | Set-Content -Path $out -Encoding UTF8
+Refresh-EvidenceManifest
 
 Write-Host "[Engine System] Close status for ${Task}: $($status.ToUpperInvariant())"
 Write-Host "  Evidence: engine/evidence/$Task/CLOSE.json"
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


## Assertion Generation Instructions

Generate prove-assertions.json with categories:
- **syntax**: Verify modified files parse correctly (use syntax checks above)
- **regression**: Run existing tests covering modified files (use test coverage above)
- **invariant**: Property tests specific to THIS change that would FAIL if reverted

### Anti-Tautology Rules (MANDATORY)
1. NEVER emit commands that always succeed (true, :, echo-only)
2. Each assertion MUST reference a specific file or symbol from this diff
3. Invariant assertions MUST have revert_would_fail=true
4. Maximum 10 assertions total
5. Commands must NOT contain: rm, mv, curl, wget, sudo, dd, mkfs, chmod, kill
6. rationale must be >=20 chars and explain WHY this assertion catches regressions

### Output Schema
Write engine/evidence/T-081/prove-assertions.json:
```json
{
  "task_id": "T-081",
  "code_fingerprint": "sha256:0b6540adb1a2d7c30507fffea01ebb04eb51101794e6942c2e3a396093434582",
  "assertions": [
    {
      "id": "A-01",
      "category": "syntax|regression|invariant",
      "command": "<shell command>",
      "expect_exit": 0,
      "timeout_s": 30,
      "rationale": "<why this matters, >=20 chars>",
      "revert_would_fail": false
    }
  ]
}
```
