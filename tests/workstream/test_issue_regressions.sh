#!/usr/bin/env bash
# Focused regressions for GitHub issues #22, #23, #24, #26, #27 and legacy
# evidence compatibility from #14.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

assert_file_contains() {
  local file="$1" pattern="$2"
  grep -Fq -- "$pattern" "$file" || {
    echo "FAIL: $file does not contain: $pattern" >&2
    exit 1
  }
}

for file in \
  "$REPO_ROOT/engine/scripts/engine-review.ps1" \
  "$REPO_ROOT/plugin/engine/scripts/engine-review.ps1"; do
  assert_file_contains "$file" '[Parameter(Position=0)]'
  assert_file_contains "$file" '$task = $Task'
done
for file in \
  "$REPO_ROOT/engine/scripts/engine-review-pipeline.ps1" \
  "$REPO_ROOT/plugin/engine/scripts/engine-review-pipeline.ps1"; do
  assert_file_contains "$file" '${task}:'
done

# The update wrapper passes the internal skip flag to the installer, leaving
# exactly one contract-migrator owner in the wrapper path.
assert_file_contains "$REPO_ROOT/install.sh" '--skip-migrate'
assert_file_contains "$REPO_ROOT/install.sh" 'if ! $SKIP_MIGRATE &&'
assert_file_contains "$REPO_ROOT/install.ps1" '[switch]$SkipMigrate'
assert_file_contains "$REPO_ROOT/install.ps1" 'if (-not $SkipMigrate -and'
assert_file_contains "$REPO_ROOT/engine/bin/engine" 'bash "$tmp" --update --skip-migrate'
assert_file_contains "$REPO_ROOT/engine/bin/engine.ps1" '-Update -SkipMigrate'

# Check-update must distinguish a newer remote from a stale/older remote.
fixture="$(mktemp -d "${TMPDIR:-/tmp}/engine-update-check.XXXXXX")"
cleanup() { rm -rf "$fixture"; }
trap cleanup EXIT
mkdir -p "$fixture/engine" "$fixture/bin"
printf '%s\n' '6.24.0' > "$fixture/engine/VERSION"
cat > "$fixture/bin/curl" <<'CURL'
#!/usr/bin/env bash
printf '%s' "${FAKE_REMOTE_VERSION:?}"
CURL
chmod +x "$fixture/bin/curl"

run_check() {
  local remote="$1" expected_rc="$2" needle="$3" output rc
  set +e
  output="$(PATH="$fixture/bin:$PATH" FAKE_REMOTE_VERSION="$remote" bash "$REPO_ROOT/engine/scripts/engine-check-update.sh" "$fixture" 2>&1)"
  rc=$?
  set -e
  test "$rc" -eq "$expected_rc" || { printf '%s\n' "$output" >&2; echo "FAIL: remote $remote returned $rc, expected $expected_rc" >&2; exit 1; }
  grep -Fqi -- "$needle" <<< "$output" || { printf '%s\n' "$output" >&2; echo "FAIL: output for remote $remote lacks '$needle'" >&2; exit 1; }
}
run_check '6.25.0' 7 'Update available'
run_check '6.23.0' 0 'no downgrade'
run_check '6.24' 0 'Up to date.'

# Evidence readers accept both current status=pass and legacy verdict=PASS.
for file in \
  "$REPO_ROOT/engine/scripts/engine-doctor.sh" \
  "$REPO_ROOT/plugin/engine/scripts/engine-doctor.sh" \
  "$REPO_ROOT/engine/scripts/githooks/pre-commit" \
  "$REPO_ROOT/plugin/engine/scripts/githooks/pre-commit"; do
  assert_file_contains "$file" '"verdict"'
  assert_file_contains "$file" '"status"'
done

# Every changed runtime mirror and CLI pair must stay byte-identical.
for pair in \
  'engine/bin/engine|plugin/bin/engine' \
  'engine/bin/engine.ps1|plugin/bin/engine.ps1' \
  'engine/scripts/engine-check-update.sh|plugin/engine/scripts/engine-check-update.sh' \
  'engine/scripts/engine-check-update.ps1|plugin/engine/scripts/engine-check-update.ps1' \
  'engine/scripts/engine-doctor.sh|plugin/engine/scripts/engine-doctor.sh' \
  'engine/scripts/engine-doctor.ps1|plugin/engine/scripts/engine-doctor.ps1' \
  'engine/scripts/engine-review.ps1|plugin/engine/scripts/engine-review.ps1' \
  'engine/scripts/engine-review-pipeline.ps1|plugin/engine/scripts/engine-review-pipeline.ps1' \
  'engine/scripts/githooks/pre-commit|plugin/engine/scripts/githooks/pre-commit'; do
  left="${pair%%|*}"; right="${pair#*|}"
  cmp -s "$REPO_ROOT/$left" "$REPO_ROOT/$right" || { echo "FAIL: mirror drift: $left != $right" >&2; exit 1; }
done

# The manifest must carry the normalized SHA-256 of every changed plugin file.
manifest="$REPO_ROOT/plugin/manifest.json"
for src in \
  bin/engine bin/engine.ps1 \
  engine/scripts/engine-check-update.sh engine/scripts/engine-check-update.ps1 \
  engine/scripts/engine-doctor.sh engine/scripts/engine-doctor.ps1 \
  engine/scripts/engine-review.ps1 engine/scripts/engine-review-pipeline.ps1 \
  engine/scripts/githooks/pre-commit; do
  recorded="$(grep -F '"src": "'"$src"'"' "$manifest" | sed -n 's/.*"sha256": "\([0-9a-f]*\)".*/\1/p' | head -1)"
  actual="$(sed 's/\r$//' "$REPO_ROOT/plugin/$src" | sha256sum | cut -d' ' -f1)"
  test -n "$recorded" && test "$recorded" = "$actual" || {
    echo "FAIL: manifest hash mismatch: $src" >&2
    exit 1
  }
done

# README claims should track the shipped v6.24.0 lifecycle.
for file in "$REPO_ROOT/README.md" "$REPO_ROOT/README.zh.md"; do
  assert_file_contains "$file" 'v6.24.0'
  assert_file_contains "$file" 'acceptance-preflight'
  assert_file_contains "$file" 'engine prove'
  assert_file_contains "$file" 'engine review'
  assert_file_contains "$file" 'engine gate'
  assert_file_contains "$file" 'engine close'
done

# Candidate commits may omit shared memory, while the default role remains
# strict. Use a temporary repository so the real worktree is untouched.
candidate_repo="$(mktemp -d "${TMPDIR:-/tmp}/engine-candidate.XXXXXX")"
trap 'rm -rf "$fixture" "$candidate_repo"' EXIT
mkdir -p "$candidate_repo/engine/tasks" "$candidate_repo/src" "$candidate_repo/.githooks"
printf '%s\n' '# contract-version: 6.24.0' > "$candidate_repo/AGENTS.md"
cat > "$candidate_repo/engine/tasks/T-001.md" <<'CARD'
status: active
## WRITE-SET
- src/**
## FORBIDDEN
- never
CARD
printf '%s\n' 'initial' > "$candidate_repo/src/main.txt"
git -C "$candidate_repo" init -q
git -C "$candidate_repo" config user.email test@example.invalid
git -C "$candidate_repo" config user.name "Engine Test"
git -C "$candidate_repo" add .
git -C "$candidate_repo" commit -q -m initial
cp "$REPO_ROOT/engine/scripts/githooks/pre-commit" "$candidate_repo/.githooks/pre-commit"
chmod +x "$candidate_repo/.githooks/pre-commit"
git -C "$candidate_repo" config core.hooksPath .githooks
printf '%s\n' 'candidate change' > "$candidate_repo/src/main.txt"
git -C "$candidate_repo" add src/main.txt
if (cd "$candidate_repo" && CLAUDE_PROJECT_DIR="$candidate_repo" env -u ENGINE_COMMIT_ROLE git commit -q -m strict); then
  echo 'FAIL: default commit unexpectedly bypassed shared-memory gate' >&2
  exit 1
fi
(cd "$candidate_repo" && CLAUDE_PROJECT_DIR="$candidate_repo" ENGINE_COMMIT_ROLE=implementer-candidate git commit -q -m candidate)

echo "PASS test_issue_regressions.sh"
