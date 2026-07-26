#!/usr/bin/env bash
# T-048 AC-7 (D-035): display layer goes multi-card.
# - UserPromptSubmit guard lists EVERY active card id + per-card GOAL.
# - SessionStart full mode injects up to 3 active cards in full, headers beyond.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
START_SH="$REPO_ROOT/plugin/engine/scripts/engine-hook-session-start.sh"

pass=0
fail=0
ok() { echo "PASS  $1"; pass=$((pass + 1)); }
bad() { echo "FAIL  $1"; fail=$((fail + 1)); }

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

new_fixture() { # $1 = number of active cards
  d="$(mktemp -d "$TMP_ROOT/repo.XXXXXX")"
  mkdir -p "$d/engine/tasks" "$d/engine/.cache/sessions"
  printf '<!-- contract-version: 6.12.0 -->\n' > "$d/AGENTS.md"
  i=1
  while [ "$i" -le "$1" ]; do
    cat > "$d/engine/tasks/T-10$i.md" <<EOF
# T-10$i
> status: active | lane: l$i | decision: none | domain: root
GOAL: goal number $i
WRITE-SET: src/$i/**, engine/tasks/T-10$i.md
AC: AC-1 t | verify: true
EOF
    i=$((i + 1))
  done
  printf '%s\n' "$d"
}

echo "=== multi-card display (bash) ==="

# G1: guard lists both cards + both goals
r="$(new_fixture 2)"
out="$(printf '{"session_id":"alpha"}' | CLAUDE_PROJECT_DIR="$r" bash "$START_SH" --guard 2>/dev/null)"
if printf '%s' "$out" | grep -q 'ACTIVE: T-101, T-102'; then ok "G1 guard lists all active ids"; else bad "G1 -> $(printf '%s' "$out" | head -1)"; fi
if printf '%s' "$out" | grep -q 'T-101 GOAL: goal number 1' && printf '%s' "$out" | grep -q 'T-102 GOAL: goal number 2'; then
  ok "G1b guard shows per-card GOAL"
else
  bad "G1b goals missing"
fi

# G2: guard with no active card keeps the none message
r0="$(new_fixture 0)"
out="$(printf '{"session_id":"alpha"}' | CLAUDE_PROJECT_DIR="$r0" bash "$START_SH" --guard 2>/dev/null)"
if printf '%s' "$out" | grep -q 'ACTIVE: none'; then ok "G2 guard none message"; else bad "G2 -> $(printf '%s' "$out" | head -1)"; fi

# G3: guard renews the holder's lock mtime (lease keep-alive)
r1="$(new_fixture 1)"
printf '{"session_id":"alpha"}' | CLAUDE_PROJECT_DIR="$r1" bash "$START_SH" >/dev/null 2>&1
old_lock="$r1/engine/.cache/session.lock"
[ -f "$old_lock" ] || bad "G3 precondition: no lock"
printf '{"session_id":"alpha"}' | CLAUDE_PROJECT_DIR="$r1" bash "$START_SH" --guard >/dev/null 2>&1
if [ -f "$r1/engine/.cache/sessions/alpha-main.hb" ]; then ok "G3 guard touches heartbeat"; else bad "G3 heartbeat missing"; fi

# F1: full mode with 4 active cards -> 3 full sections + 1 header-only + multi-card note
r4="$(new_fixture 4)"
out="$(printf '{"session_id":"alpha"}' | CLAUDE_PROJECT_DIR="$r4" bash "$START_SH" 2>/dev/null)"
full_count="$(printf '%s' "$out" | grep -c 'Active Task Card (T-10')"
extra_count="$(printf '%s' "$out" | grep -c 'Additional active card: T-104')"
if [ "$full_count" = "3" ]; then ok "F1 three cards injected in full"; else bad "F1 full_count=$full_count"; fi
if [ "$extra_count" = "1" ]; then ok "F1b fourth card header-only"; else bad "F1b extra_count=$extra_count"; fi
if printf '%s' "$out" | grep -q 'Multi-card parallel'; then ok "F1c multi-card note shown"; else bad "F1c note missing"; fi

# F2: single card -> no multi-card note (no noise regression)
out="$(printf '{"session_id":"alpha"}' | CLAUDE_PROJECT_DIR="$r1" bash "$START_SH" 2>/dev/null)"
if ! printf '%s' "$out" | grep -q 'Multi-card parallel'; then ok "F2 single card has no multi note"; else bad "F2 noise"; fi

echo ""
echo "multi_card_display result: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
