#!/usr/bin/env bash
# T-036 AC-18 end-to-end: lock recovery (stale lock + assume-coordinator override).
#
# Scenarios:
#   L1: SessionStart detects stale lock (pid dead) → auto-recovers coordinator role + writes tombstone
#   L2: engine assume-coordinator (no --force) refuses when lock held by live pid
#   L3: engine assume-coordinator --force overrides live lock + writes forced-replaced tombstone
#   L4: engine assume-coordinator on no-lock → fresh coordinator (clears stale tombstone)

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
START_SH="$REPO_ROOT/plugin/engine/scripts/engine-hook-session-start.sh"
ENGINE_BIN="$REPO_ROOT/plugin/engine/bin/engine"

pass=0
fail=0
ok() { echo "PASS  $1"; pass=$((pass + 1)); }
bad() { echo "FAIL  $1"; fail=$((fail + 1)); }

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

new_fixture() {
  d="$(mktemp -d "$TMP_ROOT/repo.XXXXXX")"
  git -C "$d" init -q
  git -C "$d" config user.email lr@test
  git -C "$d" config user.name lr
  git -C "$d" config core.quotepath true
  git -C "$d" config core.autocrlf false
  git -C "$d" config commit.gpgsign false
  mkdir -p "$d/engine/tasks" "$d/engine/.cache/sessions"
  printf 'ctx\n' > "$d/engine/CONTEXT.md"
  printf 'hf\n'  > "$d/engine/HANDOFF.md"
  printf 'map\n' > "$d/engine/ENGINE_MAP.md"
  cat > "$d/engine/tasks/T-001.md" <<'EOF'
# T-001
> status: active | lane: main | decision: | domain: root
GOAL: test lock recovery
WRITE-SET: src/**,engine/workstreams/**
FORBIDDEN:
AC: AC-1 test | verify: true
EOF
  git -C "$d" add -A
  git -C "$d" commit -qm init
  printf '%s\n' "$d"
}

echo "=== lock recovery (bash) ==="

# L1: Stale lease (v6.12.0 D-035: staleness = lock/heartbeat mtime past TTL, not
# pid death - the recorded pid is the transient hook shell and is always dead).
# A dead pid with a FRESH mtime must NOT be recovered; a TTL-old lock must be.
command -v perl >/dev/null 2>&1 || { echo "SKIP  lock_recovery (perl not available)"; exit 0; }
backdate() { perl -e 'my $t=time-$ARGV[0]; utime $t,$t,$ARGV[1] or exit 1' "$1" "$2"; }
r="$(new_fixture)"
lock_file="$r/engine/.cache/session.lock"
tombstone_file="$r/engine/.cache/session.tombstone"
started="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date)"
printf '999999|stale-coordinator|coordinator|%s|T-001\n' "$started" > "$lock_file"

# L1a: fresh mtime (dead pid) -> second session demoted, NOT recovered
payload='{"session_id":"recovery-session"}'
out="$(printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$r" bash "$START_SH" 2>/dev/null)"
if printf '%s' "$out" | grep -q 'Worker (lease held'; then ok "L1a fresh-mtime lock demotes (pid irrelevant)"; else bad "L1a -> $(printf '%s' "$out" | grep -E 'Coordinator|Worker' | head -1)"; fi

# L1b: TTL-old lock -> auto-recovered + tombstone
backdate 10800 "$lock_file"
out="$(printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$r" bash "$START_SH" 2>/dev/null)"
if printf '%s' "$out" | grep -q 'recovered from stale'; then ok "L1b stale lease auto-recovered message"; else bad "L1b stale lease auto-recovered message -> out=${out:0:120}"; fi
if [ -f "$tombstone_file" ]; then ok "L1b tombstone written"; else bad "L1b tombstone written"; fi
lock_content="$(cat "$lock_file")"
if printf '%s' "$lock_content" | grep -q 'recovery-session'; then ok "L1b lock now held by recovery-session"; else bad "L1b lock now held by recovery-session"; fi

# L2: engine assume-coordinator (no --force) refuses when lock held by live pid.
r2="$(new_fixture)"
lock_file2="$r2/engine/.cache/session.lock"
started2="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date)"
# Live pid = current shell's pid
printf '%s|%s|%s|%s|%s\n' "$$" "live-coordinator" "coordinator" "$started2" "T-001" > "$lock_file2"

rc=0
out2="$(cd "$r2" && bash "$ENGINE_BIN" assume-coordinator 2>&1)" || rc=$?
if [ "$rc" -ne 0 ]; then ok "L2 assume-coordinator refused (exit=$rc)"; else bad "L2 assume-coordinator refused -> exit=0 (expected non-zero)"; fi
if printf '%s' "$out2" | grep -q 'Error.*lock held'; then ok "L2 error message shows lock holder"; else bad "L2 error message shows lock holder -> out=${out2:0:120}"; fi
# Lock should NOT be overwritten
lock_after="$(cat "$lock_file2")"
if printf '%s' "$lock_after" | grep -q 'live-coordinator'; then ok "L2 lock untouched (still live-coordinator)"; else bad "L2 lock untouched"; fi

# L3: engine assume-coordinator --force overrides live lock + writes forced-replaced tombstone.
r3="$(new_fixture)"
lock_file3="$r3/engine/.cache/session.lock"
tombstone3="$r3/engine/.cache/session.tombstone"
started3="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date)"
printf '%s|%s|%s|%s|%s\n' "$$" "old-coordinator" "coordinator" "$started3" "T-001" > "$lock_file3"

rc3=0
out3="$(cd "$r3" && bash "$ENGINE_BIN" assume-coordinator --force 2>&1)" || rc3=$?
if [ "$rc3" -eq 0 ]; then ok "L3 --force override success (exit=0)"; else bad "L3 --force override success -> exit=$rc3"; fi
if printf '%s' "$out3" | grep -q 'force-replaced'; then ok "L3 force-replaced message shown"; else bad "L3 force-replaced message shown -> out=${out3:0:120}"; fi
if [ -f "$tombstone3" ]; then ok "L3 tombstone written"; else bad "L3 tombstone written"; fi
if grep -q 'forced-replaced' "$tombstone3" 2>/dev/null; then ok "L3 tombstone reason=forced-replaced"; else bad "L3 tombstone reason=forced-replaced"; fi
lock_after3="$(cat "$lock_file3")"
if printf '%s' "$lock_after3" | grep -qv 'old-coordinator'; then ok "L3 lock overwritten (old-coordinator gone)"; else bad "L3 lock overwritten"; fi

# L3b: assume-coordinator WITHOUT --force succeeds on a TTL-stale lease (v6.12.0:
# crash recovery is the no-force case; stale-recovered tombstone).
r3b="$(new_fixture)"
lock3b="$r3b/engine/.cache/session.lock"
printf '999999|gone-coordinator|coordinator|2026-01-01T00:00:00Z|T-001\n' > "$lock3b"
backdate 10800 "$lock3b"
rc3b=0
out3b="$(cd "$r3b" && bash "$ENGINE_BIN" assume-coordinator 2>&1)" || rc3b=$?
if [ "$rc3b" -eq 0 ]; then ok "L3b no-force takeover of stale lease"; else bad "L3b -> exit=$rc3b out=${out3b:0:120}"; fi
if grep -q 'stale-recovered' "$r3b/engine/.cache/session.tombstone" 2>/dev/null; then ok "L3b tombstone reason=stale-recovered"; else bad "L3b tombstone reason"; fi

# L4: engine assume-coordinator on no-lock → fresh coordinator + clears stale tombstone.
r4="$(new_fixture)"
tombstone4="$r4/engine/.cache/session.tombstone"
# Pre-existing stale tombstone from prior crash
printf '2026-01-01T00:00:00Z|999999|prior-crash\n' > "$tombstone4"

rc4=0
out4="$(cd "$r4" && bash "$ENGINE_BIN" assume-coordinator 2>&1)" || rc4=$?
if [ "$rc4" -eq 0 ]; then ok "L4 fresh coordinator success (exit=0)"; else bad "L4 fresh coordinator success -> exit=$rc4"; fi
if printf '%s' "$out4" | grep -q 'Cleared stale tombstone'; then ok "L4 stale tombstone cleared message"; else bad "L4 stale tombstone cleared message -> out=${out4:0:120}"; fi
if [ ! -f "$tombstone4" ]; then ok "L4 stale tombstone removed"; else bad "L4 stale tombstone removed"; fi
if [ -f "$r4/engine/.cache/session.lock" ]; then ok "L4 fresh lock created"; else bad "L4 fresh lock created"; fi

echo ""
echo "lock_recovery result: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
