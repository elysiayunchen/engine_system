#!/usr/bin/env bash
# T-049 AC-5 (issue #11 C-1): status detection is anchored to line start.
# A done card whose PROSE quotes the pattern 'status:.*active' (e.g. while
# documenting hook behavior) must no longer be pinned as the active card.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
STOP_SH="$REPO_ROOT/plugin/engine/scripts/engine-hook-stop.sh"
START_SH="$REPO_ROOT/plugin/engine/scripts/engine-hook-session-start.sh"
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
  git -C "$d" config user.email an@test
  git -C "$d" config user.name an
  git -C "$d" config core.autocrlf false
  git -C "$d" config commit.gpgsign false
  mkdir -p "$d/engine/tasks" "$d/engine/.cache/sessions" "$d/src/a" "$d/src/b"
  printf '<!-- contract-version: 6.12.1 -->\n' > "$d/AGENTS.md"
  printf 'ctx\n' > "$d/engine/CONTEXT.md"
  # T-050: DONE card whose prose quotes the trap patterns (the issue #11 C-1
  # trigger, hit three separate times downstream).
  cat > "$d/engine/tasks/T-050.md" <<'EOF'
# T-050
> status: done | lane: an | decision: none | domain: root
GOAL: documents a hook bug
WRITE-SET: src/a/**, engine/tasks/T-050.md
AC: AC-1 t | verify: true

Notes: Task card status raised from active to done (pre-commit hook grep
'status:.*active' misfires - governance fix). The correct form is an anchored
'^status:[[:space:]]*active' so prose like this line stays inert.
EOF
  # T-051: genuinely active card, lexicographically AFTER the trap card.
  cat > "$d/engine/tasks/T-051.md" <<'EOF'
# T-051
> status: active | lane: an | decision: none | domain: root
GOAL: real active card
WRITE-SET: src/b/**, engine/tasks/T-051.md, engine/CONTEXT.md
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

echo "=== anchored status detection (bash) ==="

r="$(new_fixture)"

# A1: prose-trap done card does NOT govern - real card's path passes
got="$(classify "$(hook "$r" sid1 "src/b/f.txt")")"
if [ "$got" = "pass" ]; then ok "A1 real active card's path passes"; else bad "A1 -> $got"; fi

# A2: block message names only the real card, not the trap card
out="$(hook "$r" sid1 "elsewhere/f.txt")"
if printf '%s' "$out" | grep -q 'T-051' && ! printf '%s' "$out" | grep -q 'T-050'; then
  ok "A2 trap card absent from governing set"
else
  bad "A2 -> ${out:0:160}"
fi

# A3: guard mode shows only the real active card
out="$(printf '{"session_id":"sid1"}' | CLAUDE_PROJECT_DIR="$r" bash "$START_SH" --guard 2>/dev/null)"
if printf '%s' "$out" | grep -q 'ACTIVE: T-051' && ! printf '%s' "$out" | grep -q 'T-050'; then
  ok "A3 guard lists only real active card"
else
  bad "A3 -> $(printf '%s' "$out" | head -1)"
fi

# A4: pre-commit governs by the real card (trap card does not block)
echo x > "$r/src/b/f.txt"
echo up >> "$r/engine/CONTEXT.md"
git -C "$r" add src/b/f.txt engine/CONTEXT.md
if ( cd "$r" && CLAUDE_PROJECT_DIR="$r" sh "$PRE_COMMIT" ) >/dev/null 2>&1; then
  ok "A4 pre-commit ignores prose-trap card"
else
  bad "A4 pre-commit blocked"
fi

# A5: frontmatter-form status is still recognized as active
r2="$(mktemp -d "$TMP_ROOT/repo.XXXXXX")"
git -C "$r2" init -q; git -C "$r2" config user.email a@t; git -C "$r2" config user.name a
git -C "$r2" config commit.gpgsign false
mkdir -p "$r2/engine/tasks" "$r2/engine/.cache/sessions" "$r2/src"
printf '<!-- contract-version: 6.12.1 -->\n' > "$r2/AGENTS.md"
printf -- '---\nstatus: active\nwrite-set:\n  - src/**\n  - engine/tasks/T-100.md\n---\n# T-100\nGOAL: fm\nAC: AC-1 t | verify: true\n' > "$r2/engine/tasks/T-100.md"
git -C "$r2" add -A; git -C "$r2" commit -qm init
got="$(classify "$(hook "$r2" sid1 "src/f.txt")")"
if [ "$got" = "pass" ]; then ok "A5 frontmatter status recognized"; else bad "A5 -> $got"; fi

echo ""
echo "status_anchored result: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
