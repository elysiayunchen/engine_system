# Prove Package: T-078

> generated: 2026-08-01T14:22:59Z
> code_fingerprint: sha256:d5fcf414421ff830e650673c7c0f50638917f2685969b29eedae615c05238130
> head_commit: 21b75af9ded1c64ba517340121e5a45662b5d062
> diff_range: 4e9d1688..21b75af9
> code_files: 2

## GOAL

修复 GitHub issue #25：验收命令的 coverage fail-under 与声明环境缺依赖不能继续和产品行为失败共用一个 `status=fail`。新增 acceptance preflight，保留冻结命令结果，另行记录行为诊断结果、环境状态和 coverage 状态；`blocked` 不计为 PASS。

## WRITE-SET (code files in diff)
- tests/workstream/test_acceptance_preflight.sh
- tests/workstream/test_acceptance_preflight.ps1

## WRITE-SET (full, from task card)
- engine/scripts/engine-verify.sh
- engine/scripts/engine-verify.ps1
- plugin/engine/scripts/engine-verify.sh
- plugin/engine/scripts/engine-verify.ps1
- engine/bin/engine
- engine/bin/engine.ps1
- plugin/bin/engine
- plugin/bin/engine.ps1
- tests/workstream/test_acceptance_preflight.sh
- tests/workstream/test_acceptance_preflight.ps1
- engine/tasks/T-078.md
- engine/tasks/T-078/progress.md
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

## Hunk Symbols (modified functions/classes)
- 

## Syntax Checks (auto-detected)

- bash -n tests/workstream/test_acceptance_preflight.sh

## Existing Test Coverage

- tests/workstream/test_acceptance_preflight.sh covered by:
  - bash tests/workstream/test_doctor_health_regressions.ps1
  - bash tests/workstream/test_doctor_health_regressions.sh
- tests/workstream/test_acceptance_preflight.ps1 covered by:
  - bash tests/workstream/test_acceptance_preflight.sh
  - bash tests/workstream/test_doctor_health_regressions.ps1
  - bash tests/workstream/test_doctor_health_regressions.sh

## Unified Diff

### tests/workstream/test_acceptance_preflight.sh
```diff
diff --git a/tests/workstream/test_acceptance_preflight.sh b/tests/workstream/test_acceptance_preflight.sh
new file mode 100644
index 0000000..474bf79
--- /dev/null
+++ b/tests/workstream/test_acceptance_preflight.sh
@@ -0,0 +1,141 @@
+#!/usr/bin/env bash
+# T-078 / issue #25: acceptance preflight separates harness failures from behavior.
+
+set -u
+
+HERE="$(cd "$(dirname "$0")" && pwd)"
+ROOT_REPO="$(cd "$HERE/../.." && pwd)"
+VERIFY_SH="$ROOT_REPO/engine/scripts/engine-verify.sh"
+CLI_SH="$ROOT_REPO/engine/bin/engine"
+TMP_ROOT="$(mktemp -d)"
+trap 'rm -rf "$TMP_ROOT"' EXIT
+
+pass=0
+fail=0
+
+assert_rc() {
+  local name="$1" expected="$2" actual="$3"
+  if [ "$expected" -eq "$actual" ]; then
+    echo "PASS  $name (exit=$actual)"
+    pass=$((pass+1))
+  else
+    echo "FAIL  $name (expected exit=$expected got=$actual)"
+    fail=$((fail+1))
+  fi
+}
+
+assert_file_has() {
+  local name="$1" file="$2" pattern="$3"
+  if grep -Eq "$pattern" "$file"; then
+    echo "PASS  $name"
+    pass=$((pass+1))
+  else
+    echo "FAIL  $name (pattern not found: $pattern)"
+    fail=$((fail+1))
+  fi
+}
+
+assert_files_equal() {
+  local name="$1" left="$2" right="$3"
+  if cmp -s "$left" "$right"; then
+    echo "PASS  $name"
+    pass=$((pass+1))
+  else
+    echo "FAIL  $name ($left differs from $right)"
+    fail=$((fail+1))
+  fi
+}
+
+REPO="$TMP_ROOT/repo"
+mkdir -p "$REPO/engine/tasks" "$REPO/engine/scripts" "$REPO/engine/bin" "$REPO/engine/evidence" "$REPO/bin"
+cp "$VERIFY_SH" "$REPO/engine/scripts/engine-verify.sh"
+cp "$CLI_SH" "$REPO/engine/bin/engine"
+chmod +x "$REPO/engine/scripts/engine-verify.sh" "$REPO/engine/bin/engine"
+
+cat > "$REPO/engine/tasks/T-TEST.md" <<'CARD'
+# T-TEST: acceptance preflight fixture
+
+## WRITE-SET
+
+- src/not-yet-created.sh
+
+## AC
+
+AC: AC-1 coverage harness | verify: pytest -q | coverage: auto
+AC: AC-2 missing dependency | verify: bash -c 'echo "ModuleNotFoundError: No module named missing" >&2; exit 1'
+AC: AC-3 behavior failure | verify: bash -c 'exit 9' | behavior: bash -c 'exit 7'
+AC: AC-4 no coverage policy | verify: pytest -q --no-cov | coverage: no-cov
+CARD
+
+# Deterministic pytest stand-in: the frozen command fails only because of the
+# repository coverage threshold; the diagnostic command passes with --no-cov.
+cat > "$REPO/bin/pytest" <<'PYTEST'
+#!/usr/bin/env bash
+case " $* " in
+  *" --no-cov "*) echo "behavior passed"; exit 0 ;;
+  *) echo "FAIL Required test coverage of 80% not reached" >&2; exit 1 ;;
+esac
+PYTEST
+chmod +x "$REPO/bin/pytest"
+
+export PATH="$REPO/bin:$PATH"
+export CLAUDE_PROJECT_DIR="$REPO"
+
+echo "=== acceptance preflight behavior classification ==="
+OUTPUT="$TMP_ROOT/verify.out"
+bash "$VERIFY_SH" T-TEST --preflight >"$OUTPUT" 2>&1
+rc=$?
+assert_rc "preflight returns non-zero for blocked/fail ACs" 1 "$rc"
+
+EVIDENCE="$REPO/engine/evidence/T-TEST"
+assert_file_has "coverage result is blocked" "$EVIDENCE/AC-1.json" '"status":"blocked"'
+assert_file_has "coverage keeps command_exit=1" "$EVIDENCE/AC-1.json" '"command_exit":1'
+assert_file_has "coverage behavior diagnostic passes" "$EVIDENCE/AC-1.json" '"behavior_exit":0'
+assert_file_has "coverage failure is classified" "$EVIDENCE/AC-1.json" '"coverage_status":"failed_threshold"'
+assert_file_has "coverage policy defaults to auto" "$EVIDENCE/AC-1.json" '"coverage_policy":"auto"'
+
+assert_file_has "missing dependency is blocked" "$EVIDENCE/AC-2.json" '"status":"blocked"'
+assert_file_has "missing dependency is classified" "$EVIDENCE/AC-2.json" '"environment_status":"blocked"'
+if grep -q '"status":"pass"' "$EVIDENCE/AC-2.json"; then
+  echo "FAIL  missing dependency cannot be PASS"
+  fail=$((fail+1))
+else
+  echo "PASS  missing dependency cannot be PASS"
+  pass=$((pass+1))
+fi
+
+assert_file_has "ordinary behavior failure remains fail" "$EVIDENCE/AC-3.json" '"status":"fail"'
+assert_file_has "ordinary command exit is retained" "$EVIDENCE/AC-3.json" '"command_exit":9'
+assert_file_has "ordinary behavior exit is separate" "$EVIDENCE/AC-3.json" '"behavior_exit":7'
+
+assert_file_has "per-AC no-cov policy is recorded" "$EVIDENCE/AC-4.json" '"coverage_policy":"no-cov"'
+assert_file_has "per-AC no-cov disables coverage" "$EVIDENCE/AC-4.json" '"coverage_status":"disabled"'
+
+echo "=== CLI aliases ==="
+CLI_OUTPUT="$TMP_ROOT/cli.out"
+(cd "$REPO" && ./engine/bin/engine acceptance-preflight T-TEST --no-cov >"$CLI_OUTPUT" 2>&1)
+cli_rc=$?
+assert_rc "acceptance-preflight CLI is wired" 1 "$cli_rc"
+assert_file_has "CLI --no-cov is recorded" "$EVIDENCE/AC-1.json" '"coverage_policy":"no-cov"'
+assert_file_has "CLI invokes preflight mode" "$EVIDENCE/AC-1.json" '"preflight":true'
+
+(cd "$REPO" && ./engine/bin/engine verify T-TEST --preflight >"$CLI_OUTPUT" 2>&1)
+alias_rc=$?
+assert_rc "verify --preflight alias is wired" 1 "$alias_rc"
+
+echo "=== mirror parity ==="
+assert_files_equal "bash engine/plugin mirror" "$ROOT_REPO/engine/scripts/engine-verify.sh" "$ROOT_REPO/plugin/engine/scripts/engine-verify.sh"
+assert_files_equal "powershell engine/plugin mirror" "$ROOT_REPO/engine/scripts/engine-verify.ps1" "$ROOT_REPO/plugin/engine/scripts/engine-verify.ps1"
+assert_files_equal "bash CLI engine/plugin mirror" "$ROOT_REPO/engine/bin/engine" "$ROOT_REPO/plugin/bin/engine"
+assert_files_equal "powershell CLI engine/plugin mirror" "$ROOT_REPO/engine/bin/engine.ps1" "$ROOT_REPO/plugin/bin/engine.ps1"
+
+if command -v pwsh >/dev/null 2>&1; then
+  pwsh -NoProfile -ExecutionPolicy Bypass -File "$HERE/test_acceptance_preflight.ps1" >"$TMP_ROOT/ps.out" 2>&1
+  ps_rc=$?
+  assert_rc "PowerShell preflight smoke test" 0 "$ps_rc"
+else
+  echo "SKIP  PowerShell preflight smoke test (pwsh unavailable)"
+fi
+
+echo "=== RESULTS: $pass passed, $fail failed ==="
+[ "$fail" -eq 0 ]
```

### tests/workstream/test_acceptance_preflight.ps1
```diff
diff --git a/tests/workstream/test_acceptance_preflight.ps1 b/tests/workstream/test_acceptance_preflight.ps1
new file mode 100644
index 0000000..db23416
--- /dev/null
+++ b/tests/workstream/test_acceptance_preflight.ps1
@@ -0,0 +1,28 @@
+# T-078 / issue #25: PowerShell acceptance-preflight smoke test.
+
+$ErrorActionPreference = 'Stop'
+$Root = Split-Path (Split-Path $PSScriptRoot)
+$pass = 0
+$fail = 0
+
+function Assert-True {
+  param([string]$Name, [bool]$Condition)
+  if ($Condition) { Write-Output "PASS  $Name"; $script:pass++ }
+  else { Write-Output "FAIL  $Name"; $script:fail++ }
+}
+
+Assert-True 'PowerShell verifier exists' (Test-Path (Join-Path $Root 'engine/scripts/engine-verify.ps1'))
+Assert-True 'plugin PowerShell verifier mirrors engine' ((Get-FileHash (Join-Path $Root 'engine/scripts/engine-verify.ps1')).Hash -eq (Get-FileHash (Join-Path $Root 'plugin/engine/scripts/engine-verify.ps1')).Hash)
+Assert-True 'PowerShell CLI mirrors engine' ((Get-FileHash (Join-Path $Root 'engine/bin/engine.ps1')).Hash -eq (Get-FileHash (Join-Path $Root 'plugin/bin/engine.ps1')).Hash)
+
+$tokens = $null
+$parseErrors = $null
+[System.Management.Automation.Language.Parser]::ParseFile((Join-Path $Root 'engine/scripts/engine-verify.ps1'), [ref]$tokens, [ref]$parseErrors) | Out-Null
+Assert-True 'PowerShell verifier parses' ($parseErrors.Count -eq 0)
+
+$task = Join-Path $Root 'engine/tasks/T-078.md'
+$taskText = Get-Content -Raw -Path $task -Encoding UTF8
+Assert-True 'task card exposes preflight ACs' ($taskText -match 'acceptance preflight' -and $taskText -match 'coverage: no-cov')
+
+Write-Output "=== RESULTS: $pass passed, $fail failed ==="
+if ($fail -ne 0) { exit 1 }
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
Write engine/evidence/T-078/prove-assertions.json:
```json
{
  "task_id": "T-078",
  "code_fingerprint": "sha256:d5fcf414421ff830e650673c7c0f50638917f2685969b29eedae615c05238130",
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
