#!/usr/bin/env bash
# T-048 AC-2 (D-035 RC-1/RC-2): PreToolUse union gating across multiple active
# cards + bootstrap constant exemption.
#
# v6.12.0 replaces the single-card gate (lex-first active card governs every
# path) with per-path union: a path passes when at least one active card lists
# it in WRITE-SET and not in that same card's FORBIDDEN. Task/decision card
# files are always writable (bootstrap channel).

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
    *'"systemMessage"'*)    echo warn ;;
    *)                      echo pass ;;
  esac
}

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

new_fixture() {
  d="$(mktemp -d "$TMP_ROOT/repo.XXXXXX")"
  git -C "$d" init -q
  git -C "$d" config user.email mu@test
  git -C "$d" config user.name mu
  git -C "$d" config core.autocrlf false
  git -C "$d" config commit.gpgsign false
  mkdir -p "$d/engine/tasks" "$d/engine/.cache/sessions" "$d/src/a" "$d/src/b"
  printf '<!-- contract-version: 6.12.0 -->\n' > "$d/AGENTS.md"
  printf 'ctx\n' > "$d/engine/CONTEXT.md"
  cat > "$d/engine/tasks/T-100.md" <<'EOF'
# T-100
> status: active | lane: a | decision: none | domain: root
GOAL: first card
WRITE-SET: src/a/**, engine/tasks/T-100.md, engine/CONTEXT.md
FORBIDDEN: src/b/**
AC: AC-1 t | verify: true
EOF
  cat > "$d/engine/tasks/T-101.md" <<'EOF'
# T-101
> status: active | lane: b | decision: none | domain: root
GOAL: second card
WRITE-SET: src/b/**, engine/tasks/T-101.md
AC: AC-1 t | verify: true
EOF
  git -C "$d" add -A
  git -C "$d" commit -qm init
  printf '%s\n' "$d"
}

run_hook() {
  # $1=repo $2=sid $3=path
  printf '{"session_id":"%s","tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$2" "$3" \
    | CLAUDE_PROJECT_DIR="$1" bash "$STOP_SH" --pre-tool-use 2>/dev/null
}

echo "=== PreToolUse union gating (bash) ==="

# U1: path in first card's WRITE-SET -> pass
r="$(new_fixture)"
got="$(classify "$(run_hook "$r" sid1 "src/a/f.txt")")"
if [ "$got" = "pass" ]; then ok "U1 card-1 path allowed"; else bad "U1 card-1 path -> $got"; fi

# U2: path in SECOND card's WRITE-SET -> pass (old single-card gate blocked this)
got="$(classify "$(run_hook "$r" sid1 "src/b/f.txt")")"
if [ "$got" = "pass" ]; then ok "U2 card-2 path allowed (union)"; else bad "U2 card-2 path -> $got"; fi

# U3: card-1 FORBIDDEN does not veto card-2 WRITE-SET (same path as U2, T-100 forbids src/b/**)
# (U2 already proves it; keep as explicit contract statement)
got="$(classify "$(run_hook "$r" sid1 "src/b/g.txt")")"
if [ "$got" = "pass" ]; then ok "U3 one card's FORBIDDEN never vetoes another card"; else bad "U3 forbidden cross-veto -> $got"; fi

# U4: path outside every card -> block, message names all cards
out="$(run_hook "$r" sid1 "src/c/h.txt")"
got="$(classify "$out")"
if [ "$got" = "block" ] && printf '%s' "$out" | grep -q 'T-100' && printf '%s' "$out" | grep -q 'T-101'; then
  ok "U4 path outside every card blocked, lists all cards"
else
  bad "U4 outside-all -> got=$got out=${out:0:140}"
fi

# U5: bootstrap constant exemption - creating a NEW task card while others are active
got="$(classify "$(run_hook "$r" sid1 "engine/tasks/T-102.md")")"
if [ "$got" = "pass" ]; then ok "U5 new task card creation allowed (bootstrap)"; else bad "U5 new card -> $got"; fi

# U6: bootstrap constant exemption - decision card
got="$(classify "$(run_hook "$r" sid1 "engine/decisions/D-900.md")")"
if [ "$got" = "pass" ]; then ok "U6 decision card write allowed (bootstrap)"; else bad "U6 decision card -> $got"; fi

# U7: with NO active card, ordinary path still blocked (strict), bootstrap still allowed
r2="$(new_fixture)"
sed -i.bak 's/status: active/status: done/' "$r2/engine/tasks/T-100.md" "$r2/engine/tasks/T-101.md" && rm -f "$r2/engine/tasks/"*.bak
git -C "$r2" add -A && git -C "$r2" commit -qm done
got="$(classify "$(run_hook "$r2" sid1 "src/a/f.txt")")"
if [ "$got" = "block" ]; then ok "U7a no-active-card ordinary write blocked"; else bad "U7a -> $got"; fi
got="$(classify "$(run_hook "$r2" sid1 "engine/tasks/T-200.md")")"
if [ "$got" = "pass" ]; then ok "U7b no-active-card bootstrap allowed"; else bad "U7b -> $got"; fi

echo ""
echo "pretooluse_union result: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
