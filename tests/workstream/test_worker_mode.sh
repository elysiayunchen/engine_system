#!/usr/bin/env bash
# T-036 AC-18 end-to-end: worker mode activation when coordinator lock is held.
#
# Scenario: A live coordinator lock exists (pid=current). A new SessionStart hook
# invocation with a different session_id MUST:
#   - Detect the live lock holder
#   - Output "Worker" message indicating degraded mode
#   - Create .cache/sessions/<worker_key>.role=worker marker file
#   - NOT overwrite the existing lock file

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

new_fixture() {
  d="$(mktemp -d "$TMP_ROOT/repo.XXXXXX")"
  git -C "$d" init -q
  git -C "$d" config user.email wm@test
  git -C "$d" config user.name wm
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
GOAL: test worker mode
WRITE-SET: src/**,engine/workstreams/**
FORBIDDEN:
AC: AC-1 test | verify: true
EOF
  git -C "$d" add -A
  git -C "$d" commit -qm init
  printf '%s\n' "$d"
}

echo "=== worker mode activation (bash) ==="

# W1: Live lock holder → new session degrades to worker + writes .role=worker marker.
r="$(new_fixture)"
lock_file="$r/engine/.cache/session.lock"
live_pid="$$"
started="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date)"
printf '%s|%s|%s|%s|%s\n' "$live_pid" "coordinator-session-1" "coordinator" "$started" "T-001" > "$lock_file"
lock_before="$(sha256sum "$lock_file" | cut -d' ' -f1)"

# Invoke SessionStart with new session_id (stdin JSON payload like Claude Code provides)
payload='{"session_id":"worker-session-2"}'
out="$(printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$r" bash "$START_SH" 2>/dev/null)"

# Assertions
if printf '%s' "$out" | grep -q 'Worker'; then ok "W1 worker message shown"; else bad "W1 worker message shown"; fi
if [ -f "$r/engine/.cache/sessions/worker-session-2-main.role=worker" ]; then ok "W1 .role=worker marker created"; else bad "W1 .role=worker marker created"; fi
lock_after="$(sha256sum "$lock_file" | cut -d' ' -f1)"
if [ "$lock_before" = "$lock_after" ]; then ok "W1 lock file untouched"; else bad "W1 lock file untouched (coordinator overwritten)"; fi

# W2: No lock present → new session becomes coordinator.
r2="$(new_fixture)"
[ ! -f "$r2/engine/.cache/session.lock" ] || { bad "W2 precondition: lock absent"; }
payload='{"session_id":"fresh-session"}'
out2="$(printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$r2" bash "$START_SH" 2>/dev/null)"
if printf '%s' "$out2" | grep -q 'Coordinator'; then ok "W2 coordinator message shown"; else bad "W2 coordinator message shown"; fi
if [ -f "$r2/engine/.cache/session.lock" ]; then ok "W2 lock file created"; else bad "W2 lock file created"; fi
lock_content="$(cat "$r2/engine/.cache/session.lock")"
if printf '%s' "$lock_content" | grep -q 'fresh-session'; then ok "W2 lock contains session_id"; else bad "W2 lock contains session_id"; fi
if printf '%s' "$lock_content" | grep -q 'coordinator'; then ok "W2 lock role=coordinator"; else bad "W2 lock role=coordinator"; fi

echo ""
echo "worker_mode result: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
