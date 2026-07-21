#!/usr/bin/env bash
# T-036 AC-18 end-to-end: kill switch for multi-session lock.
#
# Scenarios:
#   K1: ENGINE_DISABLE_MULTI_SESSION=1 env var → SessionStart skips lock detection
#   K2: engine/.cache/multi-session.disabled flag file → SessionStart skips lock detection
#   K3: engine disable-multi-session on → creates flag file
#   K4: engine disable-multi-session off → removes flag file
#   K5: engine disable-multi-session status → reports current state

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
  git -C "$d" config user.email ks@test
  git -C "$d" config user.name ks
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
GOAL: test kill switch
WRITE-SET: src/**,engine/workstreams/**
FORBIDDEN:
AC: AC-1 test | verify: true
EOF
  git -C "$d" add -A
  git -C "$d" commit -qm init
  printf '%s\n' "$d"
}

echo "=== kill switch (bash) ==="

# K1: ENGINE_DISABLE_MULTI_SESSION=1 → SessionStart skips lock detection entirely.
r="$(new_fixture)"
# Even with a live lock present, env var must cause SessionStart to skip lock acquisition
lock_file="$r/engine/.cache/session.lock"
started="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date)"
printf '%s|%s|%s|%s|%s\n' "$$" "other-coordinator" "coordinator" "$started" "T-001" > "$lock_file"
lock_hash_before="$(sha256sum "$lock_file" | cut -d' ' -f1)"

payload='{"session_id":"kill-switch-session"}'
out="$(printf '%s' "$payload" | ENGINE_DISABLE_MULTI_SESSION=1 CLAUDE_PROJECT_DIR="$r" bash "$START_SH" 2>/dev/null)"
# Output MUST NOT mention "Coordinator" or "Worker" — kill switch skips lock logic
if printf '%s' "$out" | grep -qv 'multi-session lock'; then ok "K1 env var skips lock detection"; else bad "K1 env var skips lock detection -> out=${out:0:120}"; fi
lock_hash_after="$(sha256sum "$lock_file" | cut -d' ' -f1)"
if [ "$lock_hash_before" = "$lock_hash_after" ]; then ok "K1 lock file untouched"; else bad "K1 lock file untouched"; fi
# No new .role=worker marker should be created
if [ ! -f "$r/engine/.cache/sessions/kill-switch-session-main.role=worker" ]; then ok "K1 no worker marker created"; else bad "K1 no worker marker created"; fi

# K2: .cache/multi-session.disabled flag file → SessionStart skips lock detection.
r2="$(new_fixture)"
: > "$r2/engine/.cache/multi-session.disabled"
lock_file2="$r2/engine/.cache/session.lock"
printf '%s|%s|%s|%s|%s\n' "$$" "other-coord-2" "coordinator" "$started" "T-001" > "$lock_file2"
lock_hash_before2="$(sha256sum "$lock_file2" | cut -d' ' -f1)"

payload2='{"session_id":"flag-disabled-session"}'
out2="$(printf '%s' "$payload2" | CLAUDE_PROJECT_DIR="$r2" bash "$START_SH" 2>/dev/null)"
if printf '%s' "$out2" | grep -qv 'multi-session lock'; then ok "K2 flag file skips lock detection"; else bad "K2 flag file skips lock detection -> out=${out2:0:120}"; fi
lock_hash_after2="$(sha256sum "$lock_file2" | cut -d' ' -f1)"
if [ "$lock_hash_before2" = "$lock_hash_after2" ]; then ok "K2 lock file untouched"; else bad "K2 lock file untouched"; fi

# K3: engine disable-multi-session on → creates flag file.
r3="$(new_fixture)"
[ ! -f "$r3/engine/.cache/multi-session.disabled" ] || { bad "K3 precondition: flag absent"; }
rc3=0
out3="$(cd "$r3" && bash "$ENGINE_BIN" disable-multi-session on 2>&1)" || rc3=$?
if [ "$rc3" -eq 0 ]; then ok "K3 disable on exit=0"; else bad "K3 disable on exit=$rc3"; fi
if [ -f "$r3/engine/.cache/multi-session.disabled" ]; then ok "K3 flag file created"; else bad "K3 flag file created"; fi
if printf '%s' "$out3" | grep -q 'DISABLED'; then ok "K3 DISABLED message shown"; else bad "K3 DISABLED message shown"; fi

# K4: engine disable-multi-session off → removes flag file.
rc4=0
out4="$(cd "$r3" && bash "$ENGINE_BIN" disable-multi-session off 2>&1)" || rc4=$?
if [ "$rc4" -eq 0 ]; then ok "K4 disable off exit=0"; else bad "K4 disable off exit=$rc4"; fi
if [ ! -f "$r3/engine/.cache/multi-session.disabled" ]; then ok "K4 flag file removed"; else bad "K4 flag file removed"; fi
if printf '%s' "$out4" | grep -q 'ENABLED'; then ok "K4 ENABLED message shown"; else bad "K4 ENABLED message shown"; fi

# K5: engine disable-multi-session status → reports ENABLED when no flag/env.
r5="$(new_fixture)"
rc5=0
out5="$(cd "$r5" && bash "$ENGINE_BIN" disable-multi-session status 2>&1)" || rc5=$?
if [ "$rc5" -eq 0 ]; then ok "K5 status exit=0"; else bad "K5 status exit=$rc5"; fi
if printf '%s' "$out5" | grep -q 'ENABLED'; then ok "K5 status reports ENABLED"; else bad "K5 status reports ENABLED -> out=${out5:0:120}"; fi

# K6: status reports DISABLED when flag file exists.
: > "$r5/engine/.cache/multi-session.disabled"
rc6=0
out6="$(cd "$r5" && bash "$ENGINE_BIN" disable-multi-session status 2>&1)" || rc6=$?
if printf '%s' "$out6" | grep -q 'DISABLED'; then ok "K6 status reports DISABLED (flag)"; else bad "K6 status reports DISABLED (flag) -> out=${out6:0:120}"; fi

# K7: status reports DISABLED when env var set (no flag file).
rm -f "$r5/engine/.cache/multi-session.disabled"
rc7=0
out7="$(cd "$r5" && ENGINE_DISABLE_MULTI_SESSION=1 bash "$ENGINE_BIN" disable-multi-session status 2>&1)" || rc7=$?
if printf '%s' "$out7" | grep -q 'DISABLED'; then ok "K7 status reports DISABLED (env)"; else bad "K7 status reports DISABLED (env) -> out=${out7:0:120}"; fi

echo ""
echo "kill_switch result: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
