#!/usr/bin/env bash
# T-038 AC-10 end-to-end: D-029 three-file worker write boundary (progress.md / checkpoint.md / INVENTORY.md).
#
# Scenario: v6.11.1 (D-029/T-038) extends is_shared_memory in engine-hook-stop.{sh,ps1}
# to include the three D-028 worker-write-boundary files. Worker mode (signal 1
# agent_id non-empty OR signal 2 .role=worker marker) MUST:
#   - Block worker writing shared engine/tasks/T-NNN/progress.md
#   - Block worker writing shared engine/evidence/T-NNN/checkpoint.md
#   - Block worker writing shared engine/domains/<d>/INVENTORY.md
#   - Allow worker writing own engine/workstreams/T-NNN/<worker_id>/progress.md (shard)
#   - Allow coordinator (no worker signal) writing shared progress.md

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
  git -C "$d" config user.email ws@test
  git -C "$d" config user.name ws
  git -C "$d" config core.quotepath true
  git -C "$d" config core.autocrlf false
  git -C "$d" config commit.gpgsign false
  mkdir -p "$d/engine/tasks/T-001" "$d/engine/evidence/T-001" \
           "$d/engine/domains/routing" "$d/engine/.cache/sessions" \
           "$d/engine/workstreams/T-001/s-worker-1-main" "$d/src"
  printf 'ctx\n'      > "$d/engine/CONTEXT.md"
  printf 'hf\n'       > "$d/engine/HANDOFF.md"
  printf 'map\n'      > "$d/engine/ENGINE_MAP.md"
  printf 'inv\n'      > "$d/engine/domains/routing/INVENTORY.md"
  printf 'prog\n'     > "$d/engine/tasks/T-001/progress.md"
  printf 'ckpt\n'     > "$d/engine/evidence/T-001/checkpoint.md"
  printf 'code\n'     > "$d/src/app.js"
  cat > "$d/engine/tasks/T-001.md" <<'EOF'
# T-001
> status: active | lane: main | decision: | domain: root
GOAL: test worker write boundary
WRITE-SET: src/**,engine/workstreams/**,engine/CONTEXT.md,engine/HANDOFF.md,engine/tasks/T-001/**,engine/evidence/T-001/**,engine/domains/routing/INVENTORY.md
FORBIDDEN:
AC: AC-1 test | verify: true
EOF
  git -C "$d" add -A
  git -C "$d" commit -qm init
  printf '%s\n' "$d"
}

echo "=== Worker writes shard boundary (bash) ==="

# W1: Worker (signal 1 = agent_id) writes shared progress.md → block (AC-1 new pattern)
r="$(new_fixture)"
payload='{"session_id":"s-1","agent_id":"agent-1","tool_name":"Edit","tool_input":{"file_path":"engine/tasks/T-001/progress.md"}}'
out="$(printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$r" bash "$STOP_SH" --pre-tool-use 2>/dev/null)"
got="$(classify "$out")"
if [ "$got" = "block" ]; then ok "W1 worker blocked on shared progress.md"; else bad "W1 worker blocked on shared progress.md -> got=$got out=${out:0:120}"; fi

# W2: Worker writes shared checkpoint.md → block (AC-1 new pattern)
r="$(new_fixture)"
payload='{"session_id":"s-1","agent_id":"agent-1","tool_name":"Edit","tool_input":{"file_path":"engine/evidence/T-001/checkpoint.md"}}'
out="$(printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$r" bash "$STOP_SH" --pre-tool-use 2>/dev/null)"
got="$(classify "$out")"
if [ "$got" = "block" ]; then ok "W2 worker blocked on shared checkpoint.md"; else bad "W2 worker blocked on shared checkpoint.md -> got=$got out=${out:0:120}"; fi

# W3: Worker writes shared INVENTORY.md → block (AC-1 new pattern)
r="$(new_fixture)"
payload='{"session_id":"s-1","agent_id":"agent-1","tool_name":"Edit","tool_input":{"file_path":"engine/domains/routing/INVENTORY.md"}}'
out="$(printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$r" bash "$STOP_SH" --pre-tool-use 2>/dev/null)"
got="$(classify "$out")"
if [ "$got" = "block" ]; then ok "W3 worker blocked on shared INVENTORY.md"; else bad "W3 worker blocked on shared INVENTORY.md -> got=$got out=${out:0:120}"; fi

# W4: Worker writes own shard progress.md → pass (worker writes own shard)
# session_id="s-worker-1" -> session_key=safe_id("s-worker-1-main")="s-worker-1-main" -> worker_id="s-worker-1-main"
# Allowed shard path = engine/workstreams/T-001/s-worker-1-main/*
r="$(new_fixture)"
: > "$r/engine/.cache/sessions/s-worker-1-main.role=worker"
payload='{"session_id":"s-worker-1","tool_name":"Write","tool_input":{"file_path":"engine/workstreams/T-001/s-worker-1-main/progress.md"}}'
out="$(printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$r" bash "$STOP_SH" --pre-tool-use 2>/dev/null)"
got="$(classify "$out")"
if [ "$got" = "pass" ]; then ok "W4 worker writes own shard progress.md -> pass"; else bad "W4 worker writes own shard progress.md -> got=$got out=${out:0:120}"; fi

# W5: Worker writes own shard checkpoint.md → pass
r="$(new_fixture)"
: > "$r/engine/.cache/sessions/s-worker-1-main.role=worker"
payload='{"session_id":"s-worker-1","tool_name":"Write","tool_input":{"file_path":"engine/workstreams/T-001/s-worker-1-main/checkpoint.md"}}'
out="$(printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$r" bash "$STOP_SH" --pre-tool-use 2>/dev/null)"
got="$(classify "$out")"
if [ "$got" = "pass" ]; then ok "W5 worker writes own shard checkpoint.md -> pass"; else bad "W5 worker writes own shard checkpoint.md -> got=$got out=${out:0:120}"; fi

# W6: Coordinator (no worker signal) writes shared progress.md → pass (control)
r="$(new_fixture)"
payload='{"session_id":"s-coord","tool_name":"Edit","tool_input":{"file_path":"engine/tasks/T-001/progress.md"}}'
# Stage a writeback so precondition (engine_written) passes
printf 'updated\n' >> "$r/engine/CONTEXT.md"
out="$(printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$r" bash "$STOP_SH" --pre-tool-use 2>/dev/null)"
got="$(classify "$out")"
if [ "$got" != "block" ]; then ok "W6 coordinator writes shared progress.md -> pass (got=$got)"; else bad "W6 coordinator writes shared progress.md -> got=$got out=${out:0:120}"; fi

echo ""
echo "worker_writes_shard result: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
