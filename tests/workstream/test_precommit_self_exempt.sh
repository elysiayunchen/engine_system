#!/usr/bin/env bash
# Test: pre-commit protected_paths task-card self-exemption (T-041, v6.11.3)
#
# Validates the self-exemption logic added to engine/scripts/githooks/pre-commit:
# the active/closing task card T-NNN and its derivative files (.md / .spec.md /
# subdirectory / archived progress) are exempt from protected_paths gating,
# because the gate's purpose is to prevent CROSS-task-card edits, not to block
# a task card from editing its own metadata.
#
# Other protected paths (ENGINE_FILE_SYSTEM_v5.md / contract/src/** /
# plugin/manifest.json / etc.) are NOT exempt and still require decision scope.
#
# This is a black-box test of the case-match exemption, extracted from the
# real pre-commit logic (lines 226-232). It does not invoke git.

set -euo pipefail

# Exemption logic extracted from engine/scripts/githooks/pre-commit (T-041).
# Returns 0 (exempt) if $file is the task card itself or its derivative, given
# the active/closing task id $1.
is_self_exempt() {
  local exempt_id="$1" file="$2"
  case "$file" in
    engine/tasks/$exempt_id.md|engine/tasks/$exempt_id.spec.md|engine/tasks/$exempt_id/*|engine/archive/tasks/$exempt_id-progress.md)
      return 0 ;;
    *)
      return 1 ;;
  esac
}

# Helper: assert a path IS exempt (should pass gate).
assert_exempt() {
  local task_id="$1" file="$2"
  if is_self_exempt "$task_id" "$file"; then
    echo "PASS: $file is exempt (task $task_id)"
  else
    echo "FAIL: $file should be exempt (task $task_id) but was NOT"; exit 1
  fi
}

# Helper: assert a path is NOT exempt (should still require decision scope).
assert_not_exempt() {
  local task_id="$1" file="$2"
  if is_self_exempt "$task_id" "$file"; then
    echo "FAIL: $file should NOT be exempt (task $task_id) but WAS"; exit 1
  else
    echo "PASS: $file is NOT exempt (task $task_id)"
  fi
}

echo "[test_precommit_self_exempt.sh] T-041 task-card self-exemption"

# Use T-999 as the active task card id for all test cases.
TASK_ID="T-999"

# --- Exempt cases: task card itself + derivative files ---
assert_exempt "$TASK_ID" "engine/tasks/T-999.md"
assert_exempt "$TASK_ID" "engine/tasks/T-999.spec.md"
assert_exempt "$TASK_ID" "engine/tasks/T-999/progress.md"
assert_exempt "$TASK_ID" "engine/tasks/T-999/sub/deep/note.md"
assert_exempt "$TASK_ID" "engine/archive/tasks/T-999-progress.md"

# --- Not exempt: different task card id ---
assert_not_exempt "$TASK_ID" "engine/tasks/T-888.md"
assert_not_exempt "$TASK_ID" "engine/tasks/T-888.spec.md"
assert_not_exempt "$TASK_ID" "engine/tasks/T-888/progress.md"
assert_not_exempt "$TASK_ID" "engine/archive/tasks/T-888-progress.md"

# --- Not exempt: protected paths outside task-card namespace ---
assert_not_exempt "$TASK_ID" "ENGINE_FILE_SYSTEM_v5.md"
assert_not_exempt "$TASK_ID" "contract/src/20-file-templates.md"
assert_not_exempt "$TASK_ID" "contract/src/behaviors/task-run.md"
assert_not_exempt "$TASK_ID" "plugin/manifest.json"
assert_not_exempt "$TASK_ID" "plugin/.claude/commands/engine-init.md"
assert_not_exempt "$TASK_ID" "install.sh"
assert_not_exempt "$TASK_ID" "install.ps1"
assert_not_exempt "$TASK_ID" ".gitattributes"
assert_not_exempt "$TASK_ID" "runtime-law.md"
assert_not_exempt "$TASK_ID" "rules.json"
assert_not_exempt "$TASK_ID" "engine/decisions/D-028.md"

# --- Edge case: task id substring should not false-match ---
# T-9999.md should NOT be exempt when active task is T-999 (prefix collision guard).
# Note: case glob engine/tasks/$exempt_id.md is anchored by .md suffix, so
# engine/tasks/T-9999.md does NOT match engine/tasks/T-999.md (different string).
assert_not_exempt "$TASK_ID" "engine/tasks/T-9999.md"
assert_not_exempt "$TASK_ID" "engine/tasks/T-999-alias.md"

echo ""
echo "All tests passed: task-card self-exemption behavior verified"
