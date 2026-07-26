#!/usr/bin/env bash
# T-049 AC-3 (issue #11 B-1): the PreToolUse hook parses YAML frontmatter
# multi-line write-set. Before this, a card written only in the frontmatter
# (spec) format was rejected with "no readable WRITE-SET", pausing all writes.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
STOP_SH="$REPO_ROOT/plugin/engine/scripts/engine-hook-stop.sh"

pass=0
fail=0
ok() { echo "PASS  $1"; pass=$((pass + 1)); }
bad() { echo "FAIL  $1"; fail=$((fail + 1)); }

classify() {
  case "$1" in
    *'"decision":"block"'*) echo block ;;
    *)                      echo pass ;;
  esac
}

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

new_fixture() {
  d="$(mktemp -d "$TMP_ROOT/repo.XXXXXX")"
  git -C "$d" init -q
  git -C "$d" config user.email fm@test
  git -C "$d" config user.name fm
  git -C "$d" config core.autocrlf false
  git -C "$d" config commit.gpgsign false
  mkdir -p "$d/engine/tasks" "$d/engine/.cache/sessions" "$d/src/a"
  printf '<!-- contract-version: 6.12.1 -->\n' > "$d/AGENTS.md"
  cat > "$d/engine/tasks/T-100.md" <<'EOF'
---
status: active
lane: fm
decision: none
domain: root
write-set:
  - src/a/**
  - engine/tasks/T-100.md
forbidden:
  - src/a/secret/**
---
# T-100
GOAL: frontmatter-only card
AC: AC-1 t | verify: true
EOF
  git -C "$d" add -A
  git -C "$d" commit -qm init
  printf '%s\n' "$d"
}

hook() {
  printf '{"session_id":"%s","tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$2" "$3" \
    | CLAUDE_PROJECT_DIR="$1" bash "$STOP_SH" --pre-tool-use 2>/dev/null
}

echo "=== hook frontmatter WRITE-SET (bash) ==="

r="$(new_fixture)"

# F1: path inside frontmatter write-set -> pass (was "no readable WRITE-SET" block)
got="$(classify "$(hook "$r" sid1 "src/a/f.txt")")"
if [ "$got" = "pass" ]; then ok "F1 frontmatter write-set path allowed"; else bad "F1 -> $got"; fi

# F2: path outside -> block
got="$(classify "$(hook "$r" sid1 "src/b/g.txt")")"
if [ "$got" = "block" ]; then ok "F2 outside path blocked"; else bad "F2 -> $got"; fi

# F3: frontmatter forbidden entry respected
got="$(classify "$(hook "$r" sid1 "src/a/secret/k.txt")")"
if [ "$got" = "block" ]; then ok "F3 frontmatter forbidden blocked"; else bad "F3 -> $got"; fi

# F4: block message must NOT claim the card is malformed
out="$(hook "$r" sid1 "src/b/g.txt")"
if ! printf '%s' "$out" | grep -q 'no readable WRITE-SET'; then ok "F4 no false malformed-card message"; else bad "F4 malformed-card message shown"; fi

echo ""
echo "hook_frontmatter_writeset result: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
