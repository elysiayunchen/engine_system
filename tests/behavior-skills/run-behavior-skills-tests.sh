#!/usr/bin/env bash
# Engine System - behavior skills distribution tests (D-019 P1 / T-023)
#
# Verifies the complete release-facing path:
# contract/src/behaviors -> engine prompts -> plugin Claude skills -> routing
# table -> manifest/installers -> isolated local install.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"

BEHAVIORS="decision-draft handoff scout task-run verify-writeback"

pass=0
fail=0

ok() { echo "PASS  $1"; pass=$((pass + 1)); }
bad() { echo "FAIL  $1"; fail=$((fail + 1)); }

echo "=== A. source and dist surfaces ==="

for b in $BEHAVIORS; do
  src="$REPO_ROOT/contract/src/behaviors/$b.md"
  prompt="$REPO_ROOT/engine/prompts/behaviors/$b.md"
  plugin_prompt="$REPO_ROOT/plugin/engine/prompts/behaviors/$b.md"
  skill="$REPO_ROOT/plugin/.claude/skills/engine-$b/SKILL.md"

  if [ -f "$src" ] && [ -f "$prompt" ] && [ -f "$plugin_prompt" ] && [ -f "$skill" ]; then
    ok "behavior files exist: $b"
  else
    bad "missing behavior files: $b"
    continue
  fi

  if cmp -s "$src" "$prompt" && cmp -s "$src" "$plugin_prompt" && cmp -s "$src" "$skill"; then
    ok "behavior mirrors match source: $b"
  else
    bad "behavior mirror drift: $b"
  fi

  if head -1 "$skill" | grep -qx -- '---' && grep -q "^name: engine-$b$" "$skill" && grep -q '^description: ' "$skill"; then
    ok "skill frontmatter valid enough: engine-$b"
  else
    bad "skill frontmatter invalid: engine-$b"
  fi
done

echo ""
echo "=== B. routing and distribution metadata ==="

if [ -f "$REPO_ROOT/engine/domains/routing.json" ] && cmp -s "$REPO_ROOT/engine/domains/routing.json" "$REPO_ROOT/plugin/engine/domains/routing.json"; then
  ok "routing table mirrored"
else
  bad "routing table missing or drifted"
fi

for b in $BEHAVIORS; do
  if grep -q "\"engine-$b\"" "$REPO_ROOT/engine/domains/routing.json"; then
    ok "routing includes engine-$b"
  else
    bad "routing missing engine-$b"
  fi

  if grep -q ".claude/skills/engine-$b/SKILL.md" "$REPO_ROOT/plugin/manifest.json" &&
     grep -q "engine/prompts/behaviors/$b.md" "$REPO_ROOT/plugin/manifest.json" &&
     grep -q ".claude/skills/engine-$b/SKILL.md" "$REPO_ROOT/install.sh" &&
     grep -q "engine/prompts/behaviors/$b.md" "$REPO_ROOT/install.sh" &&
     grep -q ".claude/skills/engine-$b/SKILL.md" "$REPO_ROOT/install.ps1" &&
     grep -q "engine/prompts/behaviors/$b.md" "$REPO_ROOT/install.ps1"; then
    ok "install surfaces include engine-$b"
  else
    bad "install surfaces missing engine-$b"
  fi
done

if grep -q '"engine/domains/routing.json"' "$REPO_ROOT/plugin/manifest.json" &&
   grep -q 'engine/domains/routing.json' "$REPO_ROOT/install.sh" &&
   grep -q 'engine/domains/routing.json' "$REPO_ROOT/install.ps1"; then
  ok "routing table distributed"
else
  bad "routing table not distributed"
fi

echo ""
echo "=== C. isolated local install ==="

SANDBOX="$(mktemp -d)"
cleanup() { rm -rf "$SANDBOX"; }
trap cleanup EXIT

(
  cd "$SANDBOX" &&
  bash "$REPO_ROOT/install.sh" --local "$REPO_ROOT/plugin" >/tmp/engine-behavior-install.log 2>&1
)
install_rc=$?

if [ "$install_rc" -eq 0 ]; then
  ok "local install completed"
else
  bad "local install failed (see /tmp/engine-behavior-install.log)"
fi

for b in $BEHAVIORS; do
  if [ -f "$SANDBOX/.claude/skills/engine-$b/SKILL.md" ] &&
     [ -f "$SANDBOX/engine/prompts/behaviors/$b.md" ]; then
    ok "installed behavior exists: $b"
  else
    bad "installed behavior missing: $b"
  fi
done

if [ -f "$SANDBOX/engine/domains/routing.json" ] && grep -q '"engine-task-run"' "$SANDBOX/engine/domains/routing.json"; then
  ok "installed routing table usable"
else
  bad "installed routing table missing"
fi

echo ""
echo "=========================================="
echo "PASS=$pass  FAIL=$fail"
[ "$fail" -eq 0 ]
