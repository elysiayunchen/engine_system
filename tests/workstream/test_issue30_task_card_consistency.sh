#!/usr/bin/env bash
# Regression coverage for GitHub issue #30.
set -euo pipefail

ROOT_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0

ok() { PASS=$((PASS + 1)); printf 'PASS %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf 'FAIL %s\n' "$1" >&2; }
assert_file_contains() {
  local name="$1" file="$2" pattern="$3"
  if grep -Eq -- "$pattern" "$file"; then ok "$name"; else bad "$name"; fi
}
assert_equal() {
  local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then ok "$name"; else bad "$name (expected=$expected got=$actual)"; fi
}

echo "=== issue #30 task-card/lifecycle regressions ==="

# The public lifecycle scripts and the shared parser must be part of both
# installer manifests.  This is the distribution half of the original bug.
for file in "$ROOT_REPO/install.sh" "$ROOT_REPO/install.ps1" "$ROOT_REPO/plugin/manifest.json"; do
  assert_file_contains "close distributed by $(basename "$file")" "$file" 'engine/scripts/engine-close\.(sh|ps1)'
done
for file in "$ROOT_REPO/install.sh" "$ROOT_REPO/install.ps1" "$ROOT_REPO/plugin/manifest.json"; do
  assert_file_contains "shared parser distributed by $(basename "$file")" "$file" 'engine/scripts/engine-task-card\.(sh|ps1)'
done

# All runtime mirrors that consume the grammar must be byte-identical.
for path in \
  engine/scripts/engine-task-card.sh engine/scripts/engine-task-card.ps1 \
  engine/scripts/engine-gate.sh engine/scripts/engine-gate.ps1 \
  engine/scripts/engine-review-pipeline.sh engine/scripts/engine-review-pipeline.ps1 \
  engine/scripts/engine-close.sh engine/scripts/engine-close.ps1 \
  engine/scripts/engine-verify.sh engine/scripts/engine-verify.ps1 \
  engine/scripts/engine-doctor.sh engine/scripts/engine-doctor.ps1 \
  engine/scripts/engine-hook-stop.sh engine/scripts/engine-hook-stop.ps1 \
  engine/scripts/githooks/pre-commit; do
  if cmp -s "$ROOT_REPO/$path" "$ROOT_REPO/plugin/$path"; then
    ok "mirror parity: $path"
  else
    bad "mirror parity: $path"
  fi
done

# Exercise the three accepted WRITE-SET spellings through the shared Bash
# helper.  Each form must produce the same normalized path list.
tmp="$(mktemp -d "${TMPDIR:-/tmp}/engine-issue30.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
source "$ROOT_REPO/engine/scripts/engine-task-card.sh"
printf '%s\n' 'WRITE-SET: src/a.sh, src/b.sh' > "$tmp/inline.md"
printf '%s\n' '## GOAL' 'section card' '## WRITE-SET' '- src/a.sh' '- src/b.sh' '## FORBIDDEN' > "$tmp/section.md"
printf '%s\n' '---' 'write-set:' '  - src/a.sh' '  - src/b.sh' '---' > "$tmp/frontmatter.md"
for form in inline section frontmatter; do
  parsed="$(task_card_parse_patterns WRITE-SET "$tmp/$form.md" | paste -sd, -)"
  assert_equal "WRITE-SET $form parser" 'src/a.sh,src/b.sh' "$parsed"
done
printf '%s\n' '# card' '## Notes' 'WRITE-SET: body-decoy' > "$tmp/body.md"
body_parsed="$(task_card_parse_patterns WRITE-SET "$tmp/body.md" | paste -sd, -)"
assert_equal 'WRITE-SET body prose ignored' '' "$body_parsed"

# PowerShell must normalize the same annotations and wildcard spelling when
# the host is available (the Bash assertions above remain the portable gate).
if command -v pwsh >/dev/null 2>&1; then
  ps_tmp="$tmp"
  ps_lib="$ROOT_REPO/engine/scripts/engine-task-card.ps1"
  if command -v cygpath >/dev/null 2>&1; then
    ps_tmp="$(cygpath -w "$ps_tmp")"
    ps_lib="$(cygpath -w "$ps_lib")"
  fi
  ps_script="$tmp/issue30-parser-test.ps1"
  cat > "$ps_script" <<'PS_SCRIPT'
    . $env:ISSUE30_LIB
    $forms = @("inline", "section", "frontmatter")
    foreach ($form in $forms) {
      $paths = @(Get-TaskCardPatterns -Path (Join-Path $env:ISSUE30_TMP "${form}.md") -Field "WRITE-SET")
      Write-Output ("{0}={1}" -f $form, ($paths -join ","))
    }
PS_SCRIPT
  if command -v cygpath >/dev/null 2>&1; then
    ps_script="$(cygpath -w "$ps_script")"
  fi
  ps_result="$(ISSUE30_TMP="$ps_tmp" ISSUE30_LIB="$ps_lib" pwsh -NoProfile -File "$ps_script")"
  for form in inline section frontmatter; do
    ps_value="$(printf '%s\n' "$ps_result" | sed -n "s/^${form}=//p")"
    assert_equal "PowerShell WRITE-SET $form parser" 'src/a.sh,src/b.sh' "$ps_value"
  done
fi

# Gate must count a section-heading AC declaration rather than falling back to
# the old 0/0 result.  The fixture is docs-only, so review/prove are skipped.
mkdir -p "$tmp/repo/engine/tasks" "$tmp/repo/engine/scripts" "$tmp/repo/engine/gate" "$tmp/repo/engine/evidence/T-001"
cp "$ROOT_REPO/engine/scripts/engine-gate.sh" "$tmp/repo/engine/scripts/engine-gate.sh"
cp "$ROOT_REPO/engine/scripts/engine-task-card.sh" "$tmp/repo/engine/scripts/engine-task-card.sh"
cat > "$tmp/repo/engine/gate/config.json" <<'JSON'
{"defaults":{"gates":["verify","review","review_agent","prove"],"code_extensions":[".sh"],"docs_only_skip":["review","review_agent","prove"]}}
JSON
cat > "$tmp/repo/engine/tasks/T-001.md" <<'CARD'
# docs-only gate fixture
status: active
## WRITE-SET
- docs/guide.md
## AC
### AC-1: docs remain valid
verify: true
CARD
printf '%s\n' '{"status":"pass"}' > "$tmp/repo/engine/evidence/T-001/AC-1.json"
set +e
(cd "$tmp/repo" && CLAUDE_PROJECT_DIR="$tmp/repo" bash engine/scripts/engine-gate.sh T-001 > "$tmp/gate.out" 2>&1)
gate_rc=$?
set -e
assert_equal 'gate section AC exits successfully' 0 "$gate_rc"
assert_file_contains 'gate reports 1/1 AC' "$tmp/gate.out" '1/1 AC PASS'
assert_file_contains 'gate skips docs-only review' "$tmp/repo/engine/evidence/T-001/GATE.json" 'no code changes in WRITE-SET'

# Review pipeline must accept compact inline WRITE-SET and create evidence.
mkdir -p "$tmp/review-repo/engine/tasks" "$tmp/review-repo/engine/review" "$tmp/review-repo/engine/scripts" "$tmp/review-repo/src"
cp "$ROOT_REPO/engine/scripts/engine-review-pipeline.sh" "$tmp/review-repo/engine/scripts/engine-review-pipeline.sh"
cp "$ROOT_REPO/engine/scripts/engine-task-card.sh" "$tmp/review-repo/engine/scripts/engine-task-card.sh"
cat > "$tmp/review-repo/engine/review/config.json" <<'JSON'
{"defaults":{"code_extensions":[".sh"],"severity_threshold":"high"}}
JSON
cat > "$tmp/review-repo/engine/tasks/T-002.md" <<'CARD'
# inline review fixture
status: active
WRITE-SET: src/main.sh
CARD
printf '%s\n' '#!/usr/bin/env bash' 'true' > "$tmp/review-repo/src/main.sh"
git -C "$tmp/review-repo" init -q
git -C "$tmp/review-repo" config user.email test@example.invalid
git -C "$tmp/review-repo" config user.name issue30
git -C "$tmp/review-repo" add .
git -C "$tmp/review-repo" commit -qm fixture
set +e
(cd "$tmp/review-repo" && CLAUDE_PROJECT_DIR="$tmp/review-repo" bash engine/scripts/engine-review-pipeline.sh T-002 > "$tmp/review.out" 2>&1)
review_rc=$?
set -e
assert_equal 'review accepts inline WRITE-SET' 0 "$review_rc"
test -f "$tmp/review-repo/engine/review/evidence/T-002/REVIEW.json" && ok 'review writes inline evidence' || bad 'review writes inline evidence'

echo "=== RESULTS: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
