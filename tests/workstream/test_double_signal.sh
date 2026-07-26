#!/usr/bin/env bash
# T-036 AC-18 end-to-end: PreToolUse dual-signal worker detection.
#
# Scenario: v6.11.0 extends PreToolUse from single signal (agent_id non-empty) to
# dual-signal OR (agent_id OR .role=worker marker). The new signal 2 covers top-level
# sessions (no agent_id) that have been degraded to worker by SessionStart.
#
# Tests signal 2 (the NEW v6.11.0 path). Signal 1 is already covered by
# tests/hook-parity/run-parity.sh "pre-worker-shared-block".

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
  git -C "$d" config user.email ds@test
  git -C "$d" config user.name ds
  git -C "$d" config core.quotepath true
  git -C "$d" config core.autocrlf false
  git -C "$d" config commit.gpgsign false
  mkdir -p "$d/engine/tasks" "$d/engine/.cache/sessions" "$d/engine/workstreams/T-001/worker-top" "$d/src"
  printf 'ctx\n' > "$d/engine/CONTEXT.md"
  printf 'hf\n'  > "$d/engine/HANDOFF.md"
  printf 'map\n' > "$d/engine/ENGINE_MAP.md"
  printf 'code\n' > "$d/src/app.js"
  # T-001 WRITE-SET explicitly includes engine/CONTEXT.md + engine/HANDOFF.md so that
  # block_scope does not block shared-memory writes by the coordinator (signal-less) mode.
  # Workers are blocked from shared memory by the is_shared_memory check (line ~230 of
  # engine-hook-stop.sh), not by block_scope.
  cat > "$d/engine/tasks/T-001.md" <<'EOF'
# T-001
> status: active | lane: main | decision: | domain: root
GOAL: test dual signal
WRITE-SET: src/**,engine/workstreams/**,engine/CONTEXT.md,engine/HANDOFF.md
FORBIDDEN:
AC: AC-1 test | verify: true
EOF
  git -C "$d" add -A
  git -C "$d" commit -qm init
  printf '%s\n' "$d"
}

echo "=== PreToolUse dual-signal (bash) ==="

# D1: Top-level session (no agent_id) + .role=worker marker + a FRESH lease held
# by another session → MUST block shared write. (v6.12.0 D-035: a worker flag
# with no live lease self-heals into coordinator instead - see
# tests/multi-session/test_shared_write_lease.sh W1/W4.)
r="$(new_fixture)"
# Create .role=worker marker for s-top-main (matches SessionStart worker_key algo: <sid>-main, safe_id'd)
: > "$r/engine/.cache/sessions/s-top-main.role=worker"
printf '111|other-session|coordinator|2026-01-01T00:00:00Z|T-001\n' > "$r/engine/.cache/session.lock"
payload='{"session_id":"s-top","tool_name":"Edit","tool_input":{"file_path":"engine/CONTEXT.md"}}'
out="$(printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$r" bash "$STOP_SH" --pre-tool-use 2>/dev/null)"
got="$(classify "$out")"
if [ "$got" = "block" ]; then ok "D1 signal-2 blocks shared write (no agent_id, marker present)"; else bad "D1 signal-2 blocks shared write -> got=$got out=${out:0:120}"; fi

# D2: Top-level session + NO .role=worker marker + NO agent_id → coordinator mode, no block (precondition check)
r="$(new_fixture)"
payload='{"session_id":"s-coordinator","tool_name":"Edit","tool_input":{"file_path":"engine/CONTEXT.md"}}'
# Stage a writeback so precondition (engine_written) passes; otherwise it'd block on no-writeback instead
printf 'updated\n' >> "$r/engine/CONTEXT.md"
out="$(printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$r" bash "$STOP_SH" --pre-tool-use 2>/dev/null)"
got="$(classify "$out")"
if [ "$got" != "block" ]; then ok "D2 no signal = coordinator mode (got=$got)"; else bad "D2 no signal = coordinator mode -> got=$got"; fi

# D3: Top-level session + .role=worker marker + writes own workstream shard → pass (worker writes own shard).
# session_id="s-top" (no agent_id) → session_key=safe_id("s-top-main")=s-top-main → worker_id=s-top-main (fallback).
# Allowed shard path = engine/workstreams/T-001/s-top-main/* (matches worker_id after safe_id).
r="$(new_fixture)"
: > "$r/engine/.cache/sessions/s-top-main.role=worker"
payload='{"session_id":"s-top","tool_name":"Write","tool_input":{"file_path":"engine/workstreams/T-001/s-top-main/HANDOFF.md"}}'
out="$(printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$r" bash "$STOP_SH" --pre-tool-use 2>/dev/null)"
got="$(classify "$out")"
if [ "$got" = "pass" ]; then ok "D3 signal-2 worker writes own shard -> pass"; else bad "D3 signal-2 worker writes own shard -> got=$got out=${out:0:120}"; fi

# D4: Top-level session + .role=worker marker + writes sibling's shard → block (worker cannot write siblings).
r="$(new_fixture)"
: > "$r/engine/.cache/sessions/s-top-main.role=worker"
mkdir -p "$r/engine/workstreams/T-001/worker-sibling"
payload='{"session_id":"s-top","tool_name":"Write","tool_input":{"file_path":"engine/workstreams/T-001/worker-sibling/HANDOFF.md"}}'
out="$(printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$r" bash "$STOP_SH" --pre-tool-use 2>/dev/null)"
got="$(classify "$out")"
if [ "$got" = "block" ]; then ok "D4 signal-2 worker blocked on sibling shard"; else bad "D4 signal-2 worker blocked on sibling shard -> got=$got"; fi

echo ""
echo "double_signal result: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
