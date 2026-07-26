#!/usr/bin/env bash
# T-049 AC-4 (issue #11 B-3): a bare directory WRITE-SET entry matches its
# children in both the PreToolUse hook and the pre-commit gate.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
STOP_SH="$REPO_ROOT/plugin/engine/scripts/engine-hook-stop.sh"
PRE_COMMIT="$REPO_ROOT/plugin/engine/scripts/githooks/pre-commit"

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
  git -C "$d" config user.email dp@test
  git -C "$d" config user.name dp
  git -C "$d" config core.autocrlf false
  git -C "$d" config commit.gpgsign false
  mkdir -p "$d/engine/tasks" "$d/engine/.cache/sessions" "$d/engine/evidence/T-100" "$d/src"
  printf '<!-- contract-version: 6.12.1 -->\n' > "$d/AGENTS.md"
  printf 'ctx\n' > "$d/engine/CONTEXT.md"
  # WRITE-SET uses the bare-directory spelling (no /* and no /**)
  cat > "$d/engine/tasks/T-100.md" <<'EOF'
# T-100
> status: active | lane: dp | decision: none | domain: root
GOAL: dir prefix
WRITE-SET: src, engine/evidence/T-100, engine/tasks/T-100.md, engine/CONTEXT.md
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

echo "=== glob dir prefix expansion (bash) ==="

r="$(new_fixture)"

# D1: child of bare-dir entry passes in PreToolUse
got="$(classify "$(hook "$r" sid1 "engine/evidence/T-100/AC-1.json")")"
if [ "$got" = "pass" ]; then ok "D1 hook: bare dir covers child"; else bad "D1 -> $got"; fi

# D2: deep child passes
got="$(classify "$(hook "$r" sid1 "src/deep/nested/f.txt")")"
if [ "$got" = "pass" ]; then ok "D2 hook: deep child covered"; else bad "D2 -> $got"; fi

# D3: sibling with same prefix string is NOT covered (src2 != src/)
mkdir -p "$r/src2"
got="$(classify "$(hook "$r" sid1 "src2/f.txt")")"
if [ "$got" = "block" ]; then ok "D3 hook: prefix-sibling not covered"; else bad "D3 -> $got"; fi

# D4: pre-commit accepts child of bare-dir entry
echo x > "$r/engine/evidence/T-100/AC-1.json"
echo up >> "$r/engine/CONTEXT.md"
git -C "$r" add engine/evidence/T-100/AC-1.json engine/CONTEXT.md
if ( cd "$r" && CLAUDE_PROJECT_DIR="$r" sh "$PRE_COMMIT" ) >/dev/null 2>&1; then
  ok "D4 pre-commit: bare dir covers child"
else
  bad "D4 pre-commit blocked"
fi

echo ""
echo "glob_dir_prefix result: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
