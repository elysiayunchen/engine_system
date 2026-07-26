#!/usr/bin/env bash
# T-048 AC-4 (D-035 RC-3b): .role=worker flag lifecycle.
#
# v6.11.x wrote the worker flag and never removed it: a session demoted once
# stayed worker forever (blocked from shared memory, then dead-locked against
# the Stop write-back gate on resume). v6.12.0 removes the own flag on every
# coordinator acquisition path and GCs orphan session files older than 7 days.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
START_SH="$REPO_ROOT/plugin/engine/scripts/engine-hook-session-start.sh"

command -v perl >/dev/null 2>&1 || { echo "SKIP  role_cleanup (perl not available)"; exit 0; }

pass=0
fail=0
ok() { echo "PASS  $1"; pass=$((pass + 1)); }
bad() { echo "FAIL  $1"; fail=$((fail + 1)); }

backdate() { perl -e 'my $t=time-$ARGV[0]; utime $t,$t,$ARGV[1] or exit 1' "$1" "$2"; }

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

new_fixture() {
  d="$(mktemp -d "$TMP_ROOT/repo.XXXXXX")"
  mkdir -p "$d/engine/tasks" "$d/engine/.cache/sessions"
  printf '<!-- contract-version: 6.12.0 -->\n' > "$d/AGENTS.md"
  printf '%s\n' "$d"
}

start_session() {
  printf '{"session_id":"%s"}' "$2" | CLAUDE_PROJECT_DIR="$1" bash "$START_SH" >/dev/null 2>&1
}

echo "=== role flag lifecycle (bash) ==="

# R1: demoted session leaves a flag; when the lease goes stale and it restarts,
# it takes over and its own stale flag is removed (resume no longer stuck worker)
r="$(new_fixture)"
start_session "$r" alpha
start_session "$r" beta
[ -f "$r/engine/.cache/sessions/beta-main.role=worker" ] || { bad "R1 precondition: beta flag missing"; }
backdate 10800 "$r/engine/.cache/session.lock"
backdate 10800 "$r/engine/.cache/sessions/alpha-main.hb"
start_session "$r" beta
if [ ! -f "$r/engine/.cache/sessions/beta-main.role=worker" ]; then ok "R1 takeover clears own worker flag"; else bad "R1 flag survived takeover"; fi
lock_sid="$(cut -d'|' -f2 "$r/engine/.cache/session.lock")"
if [ "$lock_sid" = "beta" ]; then ok "R1b beta now holds lease"; else bad "R1b holder=$lock_sid"; fi

# R2: first acquisition also clears a leftover flag (fresh repo state, stale flag present)
r2="$(new_fixture)"
: > "$r2/engine/.cache/sessions/alpha-main.role=worker"
start_session "$r2" alpha
if [ ! -f "$r2/engine/.cache/sessions/alpha-main.role=worker" ]; then ok "R2 acquisition clears leftover flag"; else bad "R2 flag survived acquisition"; fi

# R3: own-lease re-entry (resume) clears leftover flag
r3="$(new_fixture)"
start_session "$r3" alpha
: > "$r3/engine/.cache/sessions/alpha-main.role=worker"
start_session "$r3" alpha
if [ ! -f "$r3/engine/.cache/sessions/alpha-main.role=worker" ]; then ok "R3 resume re-entry clears flag"; else bad "R3 flag survived resume"; fi

# R4: orphan GC - session files older than 7 days are removed at SessionStart
r4="$(new_fixture)"
: > "$r4/engine/.cache/sessions/old-main.role=worker"
: > "$r4/engine/.cache/sessions/old-main.hb"
: > "$r4/engine/.cache/sessions/recent-main.hb"
backdate 700000 "$r4/engine/.cache/sessions/old-main.role=worker"
backdate 700000 "$r4/engine/.cache/sessions/old-main.hb"
start_session "$r4" alpha
if [ ! -f "$r4/engine/.cache/sessions/old-main.role=worker" ] && [ ! -f "$r4/engine/.cache/sessions/old-main.hb" ]; then
  ok "R4 orphans older than 7 days GCed"
else
  bad "R4 orphans survived"
fi
if [ -f "$r4/engine/.cache/sessions/recent-main.hb" ]; then ok "R4b recent files kept"; else bad "R4b recent file GCed wrongly"; fi

# R5: worker demotion still writes the flag (no regression)
r5="$(new_fixture)"
start_session "$r5" alpha
start_session "$r5" beta
if [ -f "$r5/engine/.cache/sessions/beta-main.role=worker" ]; then ok "R5 demotion still writes flag"; else bad "R5 flag not written"; fi

echo ""
echo "role_cleanup result: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
