#!/usr/bin/env bash
# T-048 AC-5 (D-035): write-time lease check on shared singletons.
#
# Writing engine/CONTEXT.md etc. now requires holding the coordinator lease:
# a session that lost (or never had) the lock is blocked while the lease is
# fresh, claims a free lock on the spot, and takes over a stale one.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
STOP_SH="$REPO_ROOT/plugin/engine/scripts/engine-hook-stop.sh"

command -v perl >/dev/null 2>&1 || { echo "SKIP  shared_write_lease (perl not available)"; exit 0; }

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

backdate() { perl -e 'my $t=time-$ARGV[0]; utime $t,$t,$ARGV[1] or exit 1' "$1" "$2"; }

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

new_fixture() {
  d="$(mktemp -d "$TMP_ROOT/repo.XXXXXX")"
  git -C "$d" init -q
  git -C "$d" config user.email lease@test
  git -C "$d" config user.name lease
  git -C "$d" config core.autocrlf false
  git -C "$d" config commit.gpgsign false
  mkdir -p "$d/engine/tasks" "$d/engine/.cache/sessions"
  printf '<!-- contract-version: 6.12.0 -->\n' > "$d/AGENTS.md"
  printf 'ctx\n' > "$d/engine/CONTEXT.md"
  cat > "$d/engine/tasks/T-100.md" <<'EOF'
# T-100
> status: active | lane: a | decision: none | domain: root
GOAL: g
WRITE-SET: src/**, engine/tasks/T-100.md, engine/CONTEXT.md
AC: AC-1 t | verify: true
EOF
  git -C "$d" add -A
  git -C "$d" commit -qm init
  printf '%s\n' "$d"
}

hook() { # $1=repo $2=sid $3=path
  printf '{"session_id":"%s","tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$2" "$3" \
    | CLAUDE_PROJECT_DIR="$1" bash "$STOP_SH" --pre-tool-use 2>/dev/null
}

echo "=== write-time lease on shared singletons (bash) ==="

# W1: no lock -> the writer claims the lease and passes
r="$(new_fixture)"
got="$(classify "$(hook "$r" alpha engine/CONTEXT.md)")"
if [ "$got" = "pass" ]; then ok "W1 free lease claimed on write"; else bad "W1 -> $got"; fi
lock_sid="$(cut -d'|' -f2 "$r/engine/.cache/session.lock" 2>/dev/null)"
if [ "$lock_sid" = "alpha" ]; then ok "W1b lock issued to writer"; else bad "W1b holder=$lock_sid"; fi

# W2: another session writing the singleton while the lease is fresh -> block
out="$(hook "$r" beta engine/CONTEXT.md)"
got="$(classify "$out")"
if [ "$got" = "block" ] && printf '%s' "$out" | grep -q 'assume-coordinator'; then
  ok "W2 non-holder blocked while lease fresh (hints assume-coordinator)"
else
  bad "W2 -> got=$got out=${out:0:140}"
fi

# W3: non-singleton path is NOT lease-gated (union only)
got="$(classify "$(hook "$r" beta src/f.txt)")"
if [ "$got" = "pass" ]; then ok "W3 ordinary path ignores lease"; else bad "W3 -> $got"; fi

# W4: stale lease -> takeover on write + tombstone
backdate 10800 "$r/engine/.cache/session.lock"
rm -f "$r/engine/.cache/sessions/alpha-main.hb"
got="$(classify "$(hook "$r" beta engine/CONTEXT.md)")"
lock_sid="$(cut -d'|' -f2 "$r/engine/.cache/session.lock" 2>/dev/null)"
if [ "$got" = "pass" ] && [ "$lock_sid" = "beta" ]; then ok "W4 stale lease taken over on write"; else bad "W4 got=$got holder=$lock_sid"; fi
if grep -q 'stale-recovered' "$r/engine/.cache/session.tombstone" 2>/dev/null; then ok "W4b tombstone written"; else bad "W4b tombstone missing"; fi

# W5: holder's own writes keep passing (heartbeat renewed by the same call)
got="$(classify "$(hook "$r" beta engine/CONTEXT.md)")"
if [ "$got" = "pass" ]; then ok "W5 holder writes pass"; else bad "W5 -> $got"; fi

# W6: in-session subagent (agent_id set) always blocked from singletons
out="$(printf '{"session_id":"beta","agent_id":"sub1","tool_name":"Edit","tool_input":{"file_path":"engine/CONTEXT.md"}}' \
  | CLAUDE_PROJECT_DIR="$r" bash "$STOP_SH" --pre-tool-use 2>/dev/null)"
got="$(classify "$out")"
if [ "$got" = "block" ]; then ok "W6 subagent always blocked from singleton"; else bad "W6 -> $got"; fi

echo ""
echo "shared_write_lease result: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
