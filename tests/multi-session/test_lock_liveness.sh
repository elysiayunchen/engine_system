#!/usr/bin/env bash
# T-048 AC-3 (D-035 RC-3): lock liveness = heartbeat TTL, not pid.
#
# v6.11.0 recorded the transient hook-shell pid in session.lock; kill -0 always
# read dead, so every new session "recovered" the lock and became coordinator
# (protection no-op). v6.12.0 judges the lease by mtime freshness: newest of
# lock mtime / holder .hb mtime within ENGINE_SESSION_TTL_MIN (default 120min).

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
START_SH="$REPO_ROOT/plugin/engine/scripts/engine-hook-session-start.sh"

command -v perl >/dev/null 2>&1 || { echo "SKIP  lock_liveness (perl not available for mtime backdating)"; exit 0; }

pass=0
fail=0
ok() { echo "PASS  $1"; pass=$((pass + 1)); }
bad() { echo "FAIL  $1"; fail=$((fail + 1)); }

backdate() { # $1=seconds-ago $2=file
  perl -e 'my $t=time-$ARGV[0]; utime $t,$t,$ARGV[1] or exit 1' "$1" "$2"
}

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

new_fixture() {
  d="$(mktemp -d "$TMP_ROOT/repo.XXXXXX")"
  mkdir -p "$d/engine/tasks" "$d/engine/.cache/sessions"
  printf '<!-- contract-version: 6.12.0 -->\n' > "$d/AGENTS.md"
  printf 'ctx\n' > "$d/engine/CONTEXT.md"
  printf '%s\n' "$d"
}

start_session() { # $1=repo $2=sid -> stdout of hook
  printf '{"session_id":"%s"}' "$2" | CLAUDE_PROJECT_DIR="$1" bash "$START_SH" 2>/dev/null
}

echo "=== lock liveness by heartbeat TTL (bash) ==="

# L1: first session acquires the lease
r="$(new_fixture)"
out="$(start_session "$r" alpha)"
if printf '%s' "$out" | grep -q 'lease acquired'; then ok "L1 first session acquires lease"; else bad "L1 -> ${out:0:120}"; fi

# L2: second session while lock mtime fresh -> worker, even though the recorded
# hook pid is long dead (the old pid check would have wrongly recovered here)
out="$(start_session "$r" beta)"
if printf '%s' "$out" | grep -q 'Worker (lease held'; then ok "L2 fresh lease demotes second session (pid irrelevant)"; else bad "L2 -> $(printf '%s' "$out" | grep -E 'Coordinator|Worker' | head -1)"; fi

# L3: same sid re-entry -> re-acquires own lease (resume/compact)
out="$(start_session "$r" alpha)"
if printf '%s' "$out" | grep -q 'own lease re-acquired'; then ok "L3 same sid re-acquires own lease"; else bad "L3 -> $(printf '%s' "$out" | grep -E 'Coordinator|Worker' | head -1)"; fi

# L4: stale lock but FRESH holder heartbeat -> still alive -> worker
backdate 10800 "$r/engine/.cache/session.lock"
touch "$r/engine/.cache/sessions/alpha-main.hb"
out="$(start_session "$r" gamma)"
if printf '%s' "$out" | grep -q 'Worker (lease held'; then ok "L4 fresh heartbeat keeps lease alive"; else bad "L4 -> $(printf '%s' "$out" | grep -E 'Coordinator|Worker' | head -1)"; fi

# L5: lock AND holder heartbeat both past TTL -> stale -> takeover + tombstone
backdate 10800 "$r/engine/.cache/session.lock"
backdate 10800 "$r/engine/.cache/sessions/alpha-main.hb"
out="$(start_session "$r" gamma)"
if printf '%s' "$out" | grep -q 'recovered from stale lease'; then ok "L5 TTL-stale lease taken over"; else bad "L5 -> $(printf '%s' "$out" | grep -E 'Coordinator|Worker' | head -1)"; fi
if grep -q 'stale-recovered' "$r/engine/.cache/session.tombstone" 2>/dev/null; then ok "L5b tombstone written"; else bad "L5b tombstone missing"; fi
lock_sid="$(cut -d'|' -f2 "$r/engine/.cache/session.lock")"
if [ "$lock_sid" = "gamma" ]; then ok "L5c lock re-issued to taker"; else bad "L5c holder=$lock_sid"; fi

# L6: ENGINE_SESSION_TTL_MIN override shortens the window
r2="$(new_fixture)"
start_session "$r2" alpha >/dev/null
backdate 120 "$r2/engine/.cache/session.lock"
rm -f "$r2/engine/.cache/sessions/alpha-main.hb"
out="$(ENGINE_SESSION_TTL_MIN=1 bash -c 'printf "{\"session_id\":\"beta\"}" | CLAUDE_PROJECT_DIR="'"$r2"'" bash "'"$START_SH"'"' 2>/dev/null)"
if printf '%s' "$out" | grep -q 'recovered from stale lease'; then ok "L6 TTL override honored"; else bad "L6 -> $(printf '%s' "$out" | grep -E 'Coordinator|Worker' | head -1)"; fi

# L7: kill switch skips lease handling entirely
r3="$(new_fixture)"
: > "$r3/engine/.cache/multi-session.disabled"
out="$(start_session "$r3" alpha)"
if ! printf '%s' "$out" | grep -qE 'Coordinator|Worker'; then ok "L7 kill switch skips lease"; else bad "L7 lease ran despite kill switch"; fi

echo ""
echo "lock_liveness result: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
