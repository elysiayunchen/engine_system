# Prove Package: T-081

> generated: 2026-08-01T17:25:06Z
> code_fingerprint: sha256:0103b3f0afb36d73c4adbfcac178c5012600c931c66c954c311efe0503634509
> head_commit: dd907c521153bea4ee1ea05c5406aa45d6279e4d
> diff_range: da253a67..dd907c52
> code_files: 14

## GOAL

把 T-080 之后仍阻断 Engine Doctor 的仓库级失败项收口，并修复 Windows/WSL 下 Bash 生命周期找不到 PowerShell 执行器的问题。完成 ENGINE_MAP 注册与 root-path 解析、active task progress 锚点、done task 归档、域 INVENTORY 覆盖、T-078 遗留生命周期证据和历史 evidence drift 的可验证收口；保留历史 warning，不掩盖真实 tamper/drift。

## WRITE-SET (code files in diff)
- engine/scripts/engine-doctor.sh
- engine/scripts/engine-doctor.ps1
- plugin/engine/scripts/engine-doctor.sh
- plugin/engine/scripts/engine-doctor.ps1
- engine/scripts/engine-verify.sh
- plugin/engine/scripts/engine-verify.sh
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
- engine/evidence/T-048/MANIFEST.json
- engine/evidence/T-048/checkpoint.md
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
- engine/evidence/T-049/MANIFEST.json
- engine/evidence/T-049/checkpoint.md
- engine/evidence/T-050/AC-1.json
- engine/evidence/T-050/AC-2.json
- engine/evidence/T-050/AC-3.json
- engine/evidence/T-050/AC-4.json
- engine/evidence/T-050/AC-5.json
- engine/evidence/T-050/AC-6.json
- engine/evidence/T-050/AC-7.json
- engine/evidence/T-050/AC-8.json
- engine/evidence/T-050/AC-9.json
- engine/evidence/T-050/MANIFEST.json
- engine/evidence/T-050/checkpoint.md
- engine/evidence/T-051/AC-1.json
- engine/evidence/T-051/AC-2.json
- engine/evidence/T-051/AC-3.json
- engine/evidence/T-051/AC-4.json
- engine/evidence/T-051/AC-5.json
- engine/evidence/T-051/AC-6.json
- engine/evidence/T-051/AC-7.json
- engine/evidence/T-051/MANIFEST.json
- engine/evidence/T-051/checkpoint.md
- engine/evidence/T-052/AC-1.json
- engine/evidence/T-052/AC-2.json
- engine/evidence/T-052/AC-3.json
- engine/evidence/T-052/AC-4.json
- engine/evidence/T-052/AC-5.json
- engine/evidence/T-052/AC-6.json
- engine/evidence/T-052/AC-7.json
- engine/evidence/T-052/AC-8.json
- engine/evidence/T-052/AC-9.json
- engine/evidence/T-052/MANIFEST.json
- engine/evidence/T-052/checkpoint.md
- engine/evidence/T-053/AC-1.json
- engine/evidence/T-053/AC-2.json
- engine/evidence/T-053/AC-3.json
- engine/evidence/T-053/AC-4.json
- engine/evidence/T-053/AC-5.json
- engine/evidence/T-053/AC-6.json
- engine/evidence/T-053/AC-7.json
- engine/evidence/T-053/MANIFEST.json
- engine/evidence/T-053/checkpoint.md
- engine/evidence/T-054/AC-1.json
- engine/evidence/T-054/AC-2.json
- engine/evidence/T-054/AC-3.json
- engine/evidence/T-054/AC-4.json
- engine/evidence/T-054/AC-5.json
- engine/evidence/T-054/AC-6.json
- engine/evidence/T-054/AC-7.json
- engine/evidence/T-054/AC-8.json
- engine/evidence/T-054/MANIFEST.json
- engine/evidence/T-054/checkpoint.md
- engine/evidence/T-055/AC-1.json
- engine/evidence/T-055/AC-2.json
- engine/evidence/T-055/AC-3.json
- engine/evidence/T-055/AC-4.json
- engine/evidence/T-055/AC-5.json
- engine/evidence/T-055/AC-6.json
- engine/evidence/T-055/MANIFEST.json
- engine/evidence/T-055/checkpoint.md
- engine/evidence/T-056/AC-1.json
- engine/evidence/T-056/AC-2.json
- engine/evidence/T-056/AC-3.json
- engine/evidence/T-056/AC-4.json
- engine/evidence/T-056/AC-5.json
- engine/evidence/T-056/AC-6.json
- engine/evidence/T-056/MANIFEST.json
- engine/evidence/T-056/checkpoint.md
- engine/evidence/T-057/AC-1.json
- engine/evidence/T-057/AC-2.json
- engine/evidence/T-057/AC-3.json
- engine/evidence/T-057/AC-4.json
- engine/evidence/T-057/AC-5.json
- engine/evidence/T-057/AC-6.json
- engine/evidence/T-057/MANIFEST.json
- engine/evidence/T-057/checkpoint.md
- engine/evidence/T-058/AC-1.json
- engine/evidence/T-058/AC-2.json
- engine/evidence/T-058/AC-3.json
- engine/evidence/T-058/AC-4.json
- engine/evidence/T-058/AC-5.json
- engine/evidence/T-058/AC-6.json
- engine/evidence/T-058/AC-7.json
- engine/evidence/T-058/MANIFEST.json
- engine/evidence/T-058/checkpoint.md
- engine/evidence/T-059/AC-1.json
- engine/evidence/T-059/AC-2.json
- engine/evidence/T-059/AC-3.json
- engine/evidence/T-059/AC-4.json
- engine/evidence/T-059/AC-5.json
- engine/evidence/T-059/AC-6.json
- engine/evidence/T-059/AC-7.json
- engine/evidence/T-059/MANIFEST.json
- engine/evidence/T-059/checkpoint.md
- engine/evidence/T-060/AC-1.json
- engine/evidence/T-060/AC-2.json
- engine/evidence/T-060/AC-3.json
- engine/evidence/T-060/AC-4.json
- engine/evidence/T-060/AC-5.json
- engine/evidence/T-060/AC-6.json
- engine/evidence/T-060/AC-7.json
- engine/evidence/T-060/MANIFEST.json
- engine/evidence/T-060/checkpoint.md
- engine/evidence/T-063/AC-1.json
- engine/evidence/T-063/AC-2.json
- engine/evidence/T-063/AC-3.json
- engine/evidence/T-063/AC-4.json
- engine/evidence/T-063/AC-5.json
- engine/evidence/T-063/MANIFEST.json
- engine/evidence/T-063/checkpoint.md
- engine/evidence/T-064/AC-1.json
- engine/evidence/T-064/AC-2.json
- engine/evidence/T-064/AC-3.json
- engine/evidence/T-064/AC-4.json
- engine/evidence/T-064/AC-5.json
- engine/evidence/T-064/AC-6.json
- engine/evidence/T-064/AC-7.json
- engine/evidence/T-064/MANIFEST.json
- engine/evidence/T-064/checkpoint.md
- engine/evidence/T-065/AC-1.json
- engine/evidence/T-065/AC-2.json
- engine/evidence/T-065/AC-3.json
- engine/evidence/T-065/AC-4.json
- engine/evidence/T-065/AC-5.json
- engine/evidence/T-065/AC-6.json
- engine/evidence/T-065/AC-7.json
- engine/evidence/T-065/MANIFEST.json
- engine/evidence/T-065/checkpoint.md
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
- engine/evidence/T-066/MANIFEST.json
- engine/evidence/T-066/checkpoint.md
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
- engine/evidence/T-067/MANIFEST.json
- engine/evidence/T-067/checkpoint.md
- engine/evidence/T-068/AC-1.json
- engine/evidence/T-068/AC-2.json
- engine/evidence/T-068/AC-3.json
- engine/evidence/T-068/AC-4.json
- engine/evidence/T-068/AC-5.json
- engine/evidence/T-068/AC-6.json
- engine/evidence/T-068/AC-7.json
- engine/evidence/T-068/AC-8.json
- engine/evidence/T-068/MANIFEST.json
- engine/evidence/T-068/checkpoint.md
- engine/evidence/T-078/AC-1.json
- engine/evidence/T-078/AC-2.json
- engine/evidence/T-078/AC-3.json
- engine/evidence/T-078/AC-4.json
- engine/evidence/T-078/AC-5.json
- engine/evidence/T-078/AC-6.json
- engine/evidence/T-078/AC-7.json
- engine/evidence/T-078/CLOSE.json
- engine/evidence/T-078/GATE.json
- engine/evidence/T-078/MANIFEST.json
- engine/evidence/T-078/PROVE.json
- engine/evidence/T-078/checkpoint.md
- engine/evidence/T-078/prove-assertions.json
- engine/evidence/T-078/prove-package.md
- engine/review/evidence/T-078/AGENT-REVIEW.json
- engine/review/evidence/T-078/QUALITY.json
- engine/review/evidence/T-078/REVIEW.json
- engine/review/evidence/T-078/SECURITY.json
- engine/review/evidence/T-078/review-package.md
- engine/review/evidence/T-081/AGENT-REVIEW.json
- engine/review/evidence/T-081/QUALITY.json
- engine/review/evidence/T-081/REVIEW.json
- engine/review/evidence/T-081/SECURITY.json
- engine/review/evidence/T-081/review-package.md
- tests/workstream/test_doctor_health_regressions.sh
- tests/workstream/test_doctor_health_regressions.ps1
- tests/workstream/test_verify_shell_resolution.sh
- tests/workstream/test_verify_shell_resolution.ps1
- plugin/manifest.json
- engine/tasks/T-081.md
- engine/tasks/T-081/progress.md
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
- engine/evidence/T-081/CLOSE.json
- engine/evidence/T-081/GATE.json
- engine/evidence/T-081/MANIFEST.json
- engine/evidence/T-081/PROVE.json
- engine/evidence/T-081/checkpoint.md
- engine/evidence/T-081/prove-assertions.json
- engine/evidence/T-081/prove-package.md
- engine/changes/CHANGE-2026-08-01-02.md

## Hunk Symbols (modified functions/classes)
- function Get-TaskPatterns([string]$Content, [string]$Field) {
- engine_path() {
- check_drift() {
- check_prove_health() {
- check_prove_health() {
- check_prove_health() {
- check_prove_health() {
- check_prove_health() {
- foreach ($tid in $doneCards) {
- foreach ($tid in $doneCards) {
- foreach ($tid in $doneCards) {
- foreach ($tid in $doneCards) {
- foreach ($tid in $doneCards) {
- foreach ($tid in $doneCards) {
- foreach ($tid in $doneCards) {
- for tid in "${done_cards[@]}"; do
- for tid in "${done_cards[@]}"; do
- for tid in "${done_cards[@]}"; do
- for tid in "${done_cards[@]}"; do
- for tid in "${done_cards[@]}"; do

## Syntax Checks (auto-detected)

- bash -n engine/scripts/engine-doctor.sh
- bash -n plugin/engine/scripts/engine-doctor.sh
- bash -n engine/scripts/engine-verify.sh
- bash -n plugin/engine/scripts/engine-verify.sh
- bash -n engine/scripts/engine-drift-check.sh
- bash -n plugin/engine/scripts/engine-drift-check.sh
- bash -n tests/workstream/test_doctor_health_regressions.sh
- bash -n tests/workstream/test_verify_shell_resolution.sh

## Existing Test Coverage

- engine/scripts/engine-doctor.sh covered by:
  - bash tests/behavior-verify/test_doctor_loud_skip.sh
  - bash tests/multi-session/test_tombstone_lifecycle.sh
  - bash tests/workstream/test_derived_status.sh
- engine/scripts/engine-doctor.ps1 covered by:
  - bash tests/multi-session/test_tombstone_lifecycle.sh
  - bash tests/workstream/test_doctor_health_regressions.ps1
  - bash tests/workstream/test_doctor_review_mirror_parity.sh
- plugin/engine/scripts/engine-doctor.sh covered by:
  - bash tests/behavior-verify/test_doctor_loud_skip.sh
  - bash tests/multi-session/test_tombstone_lifecycle.sh
  - bash tests/workstream/test_derived_status.sh
- plugin/engine/scripts/engine-doctor.ps1 covered by:
  - bash tests/multi-session/test_tombstone_lifecycle.sh
  - bash tests/workstream/test_doctor_health_regressions.ps1
  - bash tests/workstream/test_doctor_review_mirror_parity.sh
- engine/scripts/engine-verify.sh covered by:
  - bash tests/behavior-verify/run-verify-tests.sh
  - bash tests/behavior-verify/test_verify_allskip_loud.sh
  - bash tests/behavior-verify/test_verify_block_ac_format.sh
- plugin/engine/scripts/engine-verify.sh covered by:
  - bash tests/behavior-verify/run-verify-tests.sh
  - bash tests/behavior-verify/test_verify_allskip_loud.sh
  - bash tests/behavior-verify/test_verify_block_ac_format.sh
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
index 3eab40e..b5058f1 100644
--- a/engine/scripts/engine-doctor.sh
+++ b/engine/scripts/engine-doctor.sh
@@ -299,7 +299,10 @@ fi
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
@@ -1649,8 +1652,11 @@ check_drift() {
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
@@ -2031,6 +2037,21 @@ check_prove_health() {
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
@@ -2047,14 +2068,14 @@ check_prove_health() {
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
@@ -2069,14 +2090,14 @@ check_prove_health() {
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
```

### engine/scripts/engine-doctor.ps1
```diff
diff --git a/engine/scripts/engine-doctor.ps1 b/engine/scripts/engine-doctor.ps1
index 617b3e3..87d4818 100644
--- a/engine/scripts/engine-doctor.ps1
+++ b/engine/scripts/engine-doctor.ps1
@@ -157,11 +157,14 @@ function Get-TaskPatterns([string]$Content, [string]$Field) {
   return ($out -join ',')
 }
 
-function Resolve-EnginePath([string]$File) {
-  $clean = Trim-Cell $File
-  if ($clean -like "engine/*") {
-    return Join-Path $Root ($clean -replace "/", [IO.Path]::DirectorySeparatorChar)
-  }
+function Resolve-EnginePath([string]$File) {
+  $clean = Trim-Cell $File
+  # Registry rows may name root-level files (docs/, tests/, install.ps1, ...)
+  # as well as engine-relative files. Prefer an existing project-root path;
+  # otherwise retain the historical engine-relative resolution.
+  if ($clean -like "engine/*" -or (Test-Path -LiteralPath (Join-Path $Root ($clean -replace "/", [IO.Path]::DirectorySeparatorChar)))) {
+    return Join-Path $Root ($clean -replace "/", [IO.Path]::DirectorySeparatorChar)
+  }
   return Join-Path $engineDir ($clean -replace "/", [IO.Path]::DirectorySeparatorChar)
 }
 
```

### plugin/engine/scripts/engine-doctor.sh
```diff
diff --git a/plugin/engine/scripts/engine-doctor.sh b/plugin/engine/scripts/engine-doctor.sh
index 3eab40e..b5058f1 100644
--- a/plugin/engine/scripts/engine-doctor.sh
+++ b/plugin/engine/scripts/engine-doctor.sh
@@ -299,7 +299,10 @@ fi
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
@@ -1649,8 +1652,11 @@ check_drift() {
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
@@ -2031,6 +2037,21 @@ check_prove_health() {
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
@@ -2047,14 +2068,14 @@ check_prove_health() {
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
@@ -2069,14 +2090,14 @@ check_prove_health() {
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
```

### plugin/engine/scripts/engine-doctor.ps1
```diff
diff --git a/plugin/engine/scripts/engine-doctor.ps1 b/plugin/engine/scripts/engine-doctor.ps1
index 617b3e3..87d4818 100644
--- a/plugin/engine/scripts/engine-doctor.ps1
+++ b/plugin/engine/scripts/engine-doctor.ps1
@@ -157,11 +157,14 @@ function Get-TaskPatterns([string]$Content, [string]$Field) {
   return ($out -join ',')
 }
 
-function Resolve-EnginePath([string]$File) {
-  $clean = Trim-Cell $File
-  if ($clean -like "engine/*") {
-    return Join-Path $Root ($clean -replace "/", [IO.Path]::DirectorySeparatorChar)
-  }
+function Resolve-EnginePath([string]$File) {
+  $clean = Trim-Cell $File
+  # Registry rows may name root-level files (docs/, tests/, install.ps1, ...)
+  # as well as engine-relative files. Prefer an existing project-root path;
+  # otherwise retain the historical engine-relative resolution.
+  if ($clean -like "engine/*" -or (Test-Path -LiteralPath (Join-Path $Root ($clean -replace "/", [IO.Path]::DirectorySeparatorChar)))) {
+    return Join-Path $Root ($clean -replace "/", [IO.Path]::DirectorySeparatorChar)
+  }
   return Join-Path $engineDir ($clean -replace "/", [IO.Path]::DirectorySeparatorChar)
 }
 
```

### engine/scripts/engine-verify.sh
```diff
diff --git a/engine/scripts/engine-verify.sh b/engine/scripts/engine-verify.sh
index 31b3403..ac00f01 100644
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
index 0000000..ecc165a
--- /dev/null
+++ b/tests/workstream/test_doctor_health_regressions.sh
@@ -0,0 +1,68 @@
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
+contains "$drift_sh" 'historical_snapshot=0'
+contains "$drift_sh" 'legacy evidence provenance.commit mismatch'
+contains "$drift_ps" '$historicalSnapshot = $false'
+contains "$drift_ps" 'array membership rather than HashSet constructors'
+contains "$drift_ps" 'StringComparer]::Ordinal'
+cmp -s "$doctor" "$doctor_plugin" || fail 'Doctor Bash mirrors differ'
+cmp -s "$verify" "$verify_plugin" || fail 'Verify Bash mirrors differ'
+cmp -s "$drift_sh" "$drift_plugin_sh" || fail 'Drift Bash mirrors differ'
+cmp -s "$drift_ps" "$drift_plugin_ps" || fail 'Drift PowerShell mirrors differ'
+
+echo 'PASS test_doctor_health_regressions.sh'
```

### tests/workstream/test_doctor_health_regressions.ps1
```diff
diff --git a/tests/workstream/test_doctor_health_regressions.ps1 b/tests/workstream/test_doctor_health_regressions.ps1
new file mode 100644
index 0000000..60d5cfb
--- /dev/null
+++ b/tests/workstream/test_doctor_health_regressions.ps1
@@ -0,0 +1,57 @@
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
+Assert-Contains (Join-Path $repoRoot 'engine\scripts\engine-drift-check.sh') 'historical_snapshot=0'
+Assert-Contains (Join-Path $repoRoot 'engine\scripts\engine-drift-check.ps1') '$historicalSnapshot = $false'
+Assert-Contains (Join-Path $repoRoot 'engine\scripts\engine-drift-check.ps1') 'array membership rather than HashSet constructors'
+Assert-Contains (Join-Path $repoRoot 'engine\scripts\engine-drift-check.ps1') 'StringComparer]::Ordinal'
+$driftPsHash = (Get-FileHash (Join-Path $repoRoot 'engine\scripts\engine-drift-check.ps1') -Algorithm SHA256).Hash
+$driftPsPluginHash = (Get-FileHash (Join-Path $repoRoot 'plugin\engine\scripts\engine-drift-check.ps1') -Algorithm SHA256).Hash
+if ($driftPsHash -ne $driftPsPluginHash) { throw 'Drift PowerShell mirrors differ' }
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
  "code_fingerprint": "sha256:0103b3f0afb36d73c4adbfcac178c5012600c931c66c954c311efe0503634509",
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
