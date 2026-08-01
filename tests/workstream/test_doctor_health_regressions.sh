#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail() { echo "FAIL: $*" >&2; exit 1; }
contains() { grep -Fq -- "$2" "$1" || fail "$1 does not contain: $2"; }

map="$REPO_ROOT/engine/ENGINE_MAP.md"
doctor="$REPO_ROOT/engine/scripts/engine-doctor.sh"
doctor_plugin="$REPO_ROOT/plugin/engine/scripts/engine-doctor.sh"
verify="$REPO_ROOT/engine/scripts/engine-verify.sh"
verify_plugin="$REPO_ROOT/plugin/engine/scripts/engine-verify.sh"
drift_sh="$REPO_ROOT/engine/scripts/engine-drift-check.sh"
drift_plugin_sh="$REPO_ROOT/plugin/engine/scripts/engine-drift-check.sh"
drift_ps="$REPO_ROOT/engine/scripts/engine-drift-check.ps1"
drift_plugin_ps="$REPO_ROOT/plugin/engine/scripts/engine-drift-check.ps1"

for row in \
  'engine/scripts/engine-review-agent.sh' \
  'engine/scripts/engine-review-agent-package.sh' \
  'engine/scripts/engine-review-agent-validate.sh' \
  'engine/scripts/engine-gate.sh' \
  'engine/scripts/engine-gate.ps1'; do
  contains "$map" "| $row |"
done
if grep -Fq '| tool |' "$map"; then fail 'ENGINE_MAP still contains unsupported class tool'; fi
contains "$map" '| engine/gate/config.json | gates + policy | mixed |'

for task in T-075 T-076 T-077; do
  test -f "$REPO_ROOT/engine/tasks/$task/progress.md" || fail "$task progress anchor missing"
done
test ! -f "$REPO_ROOT/engine/tasks/T-078/progress.md" || fail 'T-078 live progress was not archived'
test -f "$REPO_ROOT/engine/archive/tasks/T-078-progress.md" || fail 'T-078 progress archive missing'

for path in \
  tests/workstream/test_review_agent_cli.sh \
  tests/workstream/test_review_agent_package.sh \
  tests/workstream/test_review_agent_validate.sh \
  tests/workstream/test_review_agent_config.sh \
  tests/workstream/test_review_agent_mirror.sh \
  docs/superpowers/specs/2026-07-31-agent-reviewer-design.md \
  tests/workstream/test_review_agent_gate.sh \
  tests/workstream/test_doctor_agent_review.sh \
  tests/workstream/test_review_agent_grounded.sh \
  tests/workstream/test_review_agent_dynamic.sh \
  tests/workstream/test_prove_infer.sh \
  tests/workstream/test_prove_execute.sh \
  tests/workstream/test_acceptance_preflight.sh \
  tests/workstream/test_acceptance_preflight.ps1; do
  contains "$REPO_ROOT/engine/domains/project-meta/INVENTORY.md" "| $path |"
done

contains "$doctor" 'Prefer an existing project-root path'
contains "$doctor" '-e "$ROOT/$file"'
contains "$doctor" 'if out="$(bash "$script" 2>&1)"; then'
contains "$drift_sh" 'historical_snapshot=0'
contains "$drift_sh" 'legacy evidence provenance.commit mismatch'
contains "$drift_ps" '$historicalSnapshot = $false'
contains "$drift_ps" 'array membership rather than HashSet constructors'
cmp -s "$doctor" "$doctor_plugin" || fail 'Doctor Bash mirrors differ'
cmp -s "$verify" "$verify_plugin" || fail 'Verify Bash mirrors differ'
cmp -s "$drift_sh" "$drift_plugin_sh" || fail 'Drift Bash mirrors differ'
cmp -s "$drift_ps" "$drift_plugin_ps" || fail 'Drift PowerShell mirrors differ'

echo 'PASS test_doctor_health_regressions.sh'
