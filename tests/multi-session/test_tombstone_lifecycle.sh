#!/usr/bin/env bash
# T-050 (v6.12.2): tombstone lifecycle — SessionStart cleanup + Doctor WARN.
#
# Bug A: SessionStart hook did not clean up old tombstone files when acquiring a
# fresh coordinator lock (or via same-sid resume). Result: any repo quiet for
# 24h+ had a stale tombstone, and Doctor AC-4 (tombstone staleness) would FAIL
# every time. Fix: clean tombstone on every fresh coordinator path (acquire /
# same-sid resume); stale-takeover still overwrites with `stale-recovered`.
#
# Bug B: Doctor `check_multi_session_isolation` reported every >24h tombstone
# as "previous coordinator exited abnormally" and FAILed — but
# `coordinator-exited` is the *normal* Stop hook exit marker, and contract #17
# already said "triggers WARN". Fix: cv>=6.12.2 → WARN with historical-record
# messaging; 6.11.0<=cv<6.12.2 keeps prior FAIL (migration grace); cv<6.11.0
# WARN (advisory). Message drops "abnormally" and names tombstone as a
# historical transition record + points to lock+lease as active-state source.
#
# AC coverage:
#   AC-1  fresh coordinator cleans tombstone (sh)
#   AC-2  same-sid resume cleans tombstone (sh); stale-recovery overwrites
#   AC-3  ps1 hook parity (fresh + resume clean, stale-recovery overwrites)
#   AC-4  Doctor >24h tombstone: cv>=6.12.2 WARN, 6.11.0<=cv<6.12.2 FAIL, cv<6.11.0 WARN
#   AC-5  Doctor message: no "abnormally"; mentions "historical transition record"

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
START_SH="$REPO_ROOT/plugin/engine/scripts/engine-hook-session-start.sh"
START_PS1="$REPO_ROOT/plugin/engine/scripts/engine-hook-session-start.ps1"
DOCTOR_SH="$REPO_ROOT/engine/scripts/engine-doctor.sh"
DOCTOR_PS1="$REPO_ROOT/engine/scripts/engine-doctor.ps1"

command -v perl >/dev/null 2>&1 || { echo "SKIP  tombstone_lifecycle (perl not available for mtime backdating)"; exit 0; }

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
  printf 'ctx\n' > "$d/engine/CONTEXT.md"
  printf '%s\n' "$d"
}

# write_tombstone <repo> <type> <age_seconds>
write_tombstone() {
  local repo="$1" ttype="$2" age="$3"
  local ts
  ts="$(date -u -d "@$(( $(date +%s) - age ))" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-${age}S +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '%s|%s|%s\n' "$ts" "9999" "$ttype" > "$repo/engine/.cache/session.tombstone"
}

start_session() { # $1=repo $2=sid -> stdout of hook
  printf '{"session_id":"%s"}' "$2" | CLAUDE_PROJECT_DIR="$1" bash "$START_SH" 2>/dev/null
}

# Detect PowerShell (pwsh on Linux/macOS, powershell.exe on Windows Git-bash).
PS_BIN=""
for c in pwsh pwsh.exe powershell powershell.exe; do
  if command -v "$c" >/dev/null 2>&1; then PS_BIN="$c"; break; fi
done
# Windows Git-bash may only see powershell.exe via PATH but we want pwsh if
# available. Also try the well-known install path.
if [ -z "$PS_BIN" ] && [ -x "/c/Program Files/PowerShell/7/pwsh.exe" ]; then
  PS_BIN="/c/Program Files/PowerShell/7/pwsh.exe"
fi

# Convert a Unix path to a Windows path for PowerShell on Windows.
# On Linux/macOS, returns the input unchanged (PowerShell for Linux accepts
# Unix paths). On WSL, uses wslpath. On Git-bash, uses cygpath.
to_native_path() {
  if command -v wslpath >/dev/null 2>&1; then
    wslpath -w "$1" 2>/dev/null || printf '%s\n' "$1"
  elif command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$1" 2>/dev/null || printf '%s\n' "$1"
  else
    printf '%s\n' "$1"
  fi
}

# Detect if we need WSLENV forwarding (WSL→Windows process env var passing).
# Without this, CLAUDE_PROJECT_DIR set in bash won't reach pwsh.exe on Windows.
NEED_WSLENV=0
if command -v wslpath >/dev/null 2>&1; then
  NEED_WSLENV=1
fi

start_session_ps1() { # $1=repo (unix path) $2=sid -> stdout of hook
  local win_root win_ps1
  win_root="$(to_native_path "$1")"
  win_ps1="$(to_native_path "$START_PS1")"
  # WSL needs WSLENV to forward CLAUDE_PROJECT_DIR to pwsh.exe. We export both
  # in a subshell so the test process env stays clean.
  (
    export CLAUDE_PROJECT_DIR="$win_root"
    if [ "$NEED_WSLENV" -eq 1 ]; then
      export WSLENV="CLAUDE_PROJECT_DIR${WSLENV:+:$WSLENV}"
    fi
    printf '{"session_id":"%s"}' "$2" | "$PS_BIN" -NoProfile -File "$win_ps1" 2>/dev/null
  )
}

echo "=== tombstone lifecycle (sh) — AC-1 / AC-2 ==="

# T1 (AC-1): fresh coordinator acquisition cleans existing tombstone (any type)
for ttype in coordinator-exited stale-recovered forced-replaced; do
  r="$(new_fixture)"
  write_tombstone "$r" "$ttype" 3600
  out="$(start_session "$r" alpha)"
  if [ ! -f "$r/engine/.cache/session.tombstone" ]; then
    ok "T1 fresh coordinator cleans $ttype tombstone"
  else
    bad "T1 fresh coordinator did NOT clean $ttype tombstone"
  fi
done

# T2 (AC-1 regression): two start_session in a row — second must not see the OLD
# tombstone (the one that existed before the first start_session). The first
# session's cleanup is persistent — the tombstone doesn't reappear. Second
# session may demote to worker; that's fine, the point is the old tombstone
# is gone and nothing resurrects it.
r="$(new_fixture)"
write_tombstone "$r" "coordinator-exited" 3600
start_session "$r" alpha >/dev/null
[ ! -f "$r/engine/.cache/session.tombstone" ] || bad "T2 precondition: alpha did not clean tombstone"
out="$(start_session "$r" beta)"   # beta demotes to worker (alpha lease fresh)
if [ ! -f "$r/engine/.cache/session.tombstone" ]; then
  ok "T2 second session — old tombstone still gone (not resurrected)"
else
  bad "T2 old tombstone resurrected by second session"
fi

# T3 (AC-2): same-sid resume cleans existing tombstone
r="$(new_fixture)"
start_session "$r" alpha >/dev/null
write_tombstone "$r" "coordinator-exited" 60
out="$(start_session "$r" alpha)"
if printf '%s' "$out" | grep -q 'own lease re-acquired'; then
  :
else
  bad "T3 precondition: alpha did not re-acquire own lease -> $(printf '%s' "$out" | grep -E 'Coordinator|Worker' | head -1)"
fi
if [ ! -f "$r/engine/.cache/session.tombstone" ]; then
  ok "T3 same-sid resume cleans tombstone"
else
  bad "T3 same-sid resume did NOT clean tombstone"
fi

# T4 (AC-2): stale-recovery path overwrites tombstone with stale-recovered (behavior unchanged)
r="$(new_fixture)"
start_session "$r" alpha >/dev/null
write_tombstone "$r" "coordinator-exited" 60   # pre-existing tombstone
# Force stale lease: backdate lock + holder heartbeat past TTL
backdate 10800 "$r/engine/.cache/session.lock"
backdate 10800 "$r/engine/.cache/sessions/alpha-main.hb"
out="$(start_session "$r" gamma)"
if printf '%s' "$out" | grep -q 'recovered from stale lease'; then
  :
else
  bad "T4 precondition: gamma did not take over stale lease -> $(printf '%s' "$out" | grep -E 'Coordinator|Worker' | head -1)"
fi
if [ -f "$r/engine/.cache/session.tombstone" ]; then
  t="$(cut -d'|' -f3 "$r/engine/.cache/session.tombstone")"
  if [ "$t" = "stale-recovered" ]; then
    ok "T4 stale-recovery overwrites tombstone with stale-recovered"
  else
    bad "T4 tombstone type=$t (expected stale-recovered)"
  fi
else
  bad "T4 stale-recovery did NOT write tombstone"
fi

echo ""
echo "=== tombstone lifecycle (ps1) — AC-3 hook parity ==="

# T5-T7 (AC-3): PowerShell hook parity — fresh + resume clean, stale-recovery overwrites
if [ -n "$PS_BIN" ]; then
  # T5: fresh coordinator cleans tombstone (ps1)
  r="$(new_fixture)"
  write_tombstone "$r" "coordinator-exited" 3600
  start_session_ps1 "$r" alpha >/dev/null 2>&1 || true
  if [ ! -f "$r/engine/.cache/session.tombstone" ]; then
    ok "T5 (ps1) fresh coordinator cleans tombstone"
  else
    bad "T5 (ps1) fresh coordinator did NOT clean tombstone"
  fi

  # T6: same-sid resume cleans tombstone (ps1)
  r="$(new_fixture)"
  start_session_ps1 "$r" alpha >/dev/null 2>&1 || true
  write_tombstone "$r" "coordinator-exited" 60
  start_session_ps1 "$r" alpha >/dev/null 2>&1 || true
  if [ ! -f "$r/engine/.cache/session.tombstone" ]; then
    ok "T6 (ps1) same-sid resume cleans tombstone"
  else
    bad "T6 (ps1) same-sid resume did NOT clean tombstone"
  fi

  # T7: stale-recovery overwrites tombstone (ps1)
  r="$(new_fixture)"
  start_session_ps1 "$r" alpha >/dev/null 2>&1 || true
  write_tombstone "$r" "coordinator-exited" 60
  backdate 10800 "$r/engine/.cache/session.lock"
  backdate 10800 "$r/engine/.cache/sessions/alpha-main.hb"
  start_session_ps1 "$r" gamma >/dev/null 2>&1 || true
  if [ -f "$r/engine/.cache/session.tombstone" ]; then
    t="$(cut -d'|' -f3 "$r/engine/.cache/session.tombstone")"
    if [ "$t" = "stale-recovered" ]; then
      ok "T7 (ps1) stale-recovery overwrites tombstone"
    else
      bad "T7 (ps1) tombstone type=$t (expected stale-recovered)"
    fi
  else
    bad "T7 (ps1) stale-recovery did NOT write tombstone"
  fi
else
  echo "SKIP  T5/T6/T7 (pwsh not available) — AC-3 ps1 parity not exercised"
fi

echo ""
echo "=== Doctor tombstone WARN — AC-4 / AC-5 ==="

# Stub fail/warn/pass counters (doctor.sh uses these globals)
fail_count=0
warn_count=0
last_fail_msg=""
last_warn_msg=""
fail() { fail_count=$((fail_count + 1)); last_fail_msg="$1"; printf 'FAIL %s\n' "$1"; }
warn() { warn_count=$((warn_count + 1)); last_warn_msg="$1"; printf 'WARN %s\n' "$1"; }
pass() { printf 'PASS %s\n' "$1"; }

# Extract real check_multi_session_isolation() from doctor.sh
if ! eval "$(sed -n '/^check_multi_session_isolation()/,/^}$/p' "$DOCTOR_SH")"; then
  echo "FAIL setup: could not extract check_multi_session_isolation() from doctor.sh"
  exit 1
fi

# Doctor test fixture: ENGINE_DIR with contract-version + .cache/sessions + tombstone
doctor_fixture() { # $1=cv  $2=tombstone_age_seconds  $3=tombstone_type
  local cv="$1" age="$2" ttype="$3"
  local d; d="$(mktemp -d "$TMP_ROOT/doctor.XXXXXX")"
  mkdir -p "$d/engine/.cache/sessions"
  cat > "$d/engine/ENGINE_DOCTOR.md" <<EOF
<!-- ENGINE_SYSTEM_CONTRACT_MIGRATIONS_START -->
<!-- contract-version: $cv -->
## Current Contract Checks
> Managed by Engine System contract migration.
managed block placeholder
<!-- ENGINE_SYSTEM_CONTRACT_MIGRATIONS_END -->
EOF
  if [ -n "$ttype" ]; then
    write_tombstone "$d" "$ttype" "$age"
  fi
  printf '%s' "$d"
}

# D1 (AC-4): cv>=6.12.2 + >24h tombstone (any type) → WARN (not FAIL)
for ttype in coordinator-exited stale-recovered forced-replaced; do
  r="$(doctor_fixture 6.12.2 100000 "$ttype")"
  fail_count=0; warn_count=0; last_warn_msg=""
  ENGINE_DIR="$r/engine" check_multi_session_isolation >/dev/null 2>&1 || true
  if [ "$fail_count" -eq 0 ] && [ "$warn_count" -ge 1 ]; then
    ok "D1 cv=6.12.2 + $ttype >24h → WARN (fail=$fail_count warn=$warn_count)"
  else
    bad "D1 cv=6.12.2 + $ttype >24h expected WARN, got fail=$fail_count warn=$warn_count"
  fi
done

# D2 (AC-4): 6.11.0 <= cv < 6.12.2 + >24h tombstone → FAIL (migration grace keeps old behavior)
r="$(doctor_fixture 6.11.5 100000 coordinator-exited)"
fail_count=0; warn_count=0
ENGINE_DIR="$r/engine" check_multi_session_isolation >/dev/null 2>&1 || true
if [ "$fail_count" -ge 1 ] && [ "$warn_count" -eq 0 ]; then
  ok "D2 cv=6.11.5 + coordinator-exited >24h → FAIL (grace, fail=$fail_count)"
else
  bad "D2 cv=6.11.5 expected FAIL, got fail=$fail_count warn=$warn_count"
fi

# D3 (AC-4): cv < 6.11.0 + >24h tombstone → WARN (advisory, fail-open)
r="$(doctor_fixture 6.10.0 100000 coordinator-exited)"
fail_count=0; warn_count=0
ENGINE_DIR="$r/engine" check_multi_session_isolation >/dev/null 2>&1 || true
if [ "$fail_count" -eq 0 ]; then
  ok "D3 cv=6.10.0 + tombstone >24h → no FAIL (fail-open, fail=$fail_count warn=$warn_count)"
else
  bad "D3 cv=6.10.0 expected no FAIL, got fail=$fail_count"
fi

# D4 (AC-5): cv>=6.12.2 message does NOT say "abnormally"; DOES mention "historical"
r="$(doctor_fixture 6.12.2 100000 coordinator-exited)"
fail_count=0; warn_count=0; last_warn_msg=""
ENGINE_DIR="$r/engine" check_multi_session_isolation >/dev/null 2>&1 || true
if printf '%s' "$last_warn_msg" | grep -qi 'abnormally'; then
  bad "D4 message still says 'abnormally': $last_warn_msg"
elif ! printf '%s' "$last_warn_msg" | grep -qi 'historical'; then
  bad "D4 message missing 'historical': $last_warn_msg"
else
  ok "D4 message: no 'abnormally', has 'historical'"
fi

# D5 (AC-5): every tombstone type gets the historical-record message (no "abnormally")
for ttype in coordinator-exited stale-recovered forced-replaced; do
  r="$(doctor_fixture 6.12.2 100000 "$ttype")"
  fail_count=0; warn_count=0; last_warn_msg=""
  ENGINE_DIR="$r/engine" check_multi_session_isolation >/dev/null 2>&1 || true
  if printf '%s' "$last_warn_msg" | grep -qi 'abnormally'; then
    bad "D5 $ttype message says 'abnormally'"
  elif ! printf '%s' "$last_warn_msg" | grep -qi 'historical'; then
    bad "D5 $ttype message missing 'historical'"
  else
    ok "D5 $ttype message OK"
  fi
done

# D6 (AC-4 regression): <24h tombstone → no FAIL/WARN (any cv)
r="$(doctor_fixture 6.12.2 100 coordinator-exited)"
fail_count=0; warn_count=0
ENGINE_DIR="$r/engine" check_multi_session_isolation >/dev/null 2>&1 || true
if [ "$fail_count" -eq 0 ] && [ "$warn_count" -eq 0 ]; then
  ok "D6 <24h tombstone → no FAIL/WARN (fail=$fail_count warn=$warn_count)"
else
  bad "D6 <24h tombstone expected quiet, got fail=$fail_count warn=$warn_count"
fi

echo ""
echo "tombstone_lifecycle result: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
