#!/usr/bin/env bash
# T-048 AC-6 (D-035 RC-4): worker scope narrowed.
#
# - Top-level worker sessions (role flag, no agent_id) may write task-local
#   files (progress.md / checkpoint.md) of their OWN card via WRITE-SET union,
#   and their own workstream shard under ANY active card.
# - In-session subagents (agent_id set) keep the v6.5 blanket: shard only.

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
  git -C "$d" config core.autocrlf false
  git -C "$d" config commit.gpgsign false
  mkdir -p "$d/engine/tasks" "$d/engine/.cache/sessions" "$d/engine/workstreams"
  printf '<!-- contract-version: 6.12.0 -->\n' > "$d/AGENTS.md"
  printf 'ctx\n' > "$d/engine/CONTEXT.md"
  cat > "$d/engine/tasks/T-100.md" <<'EOF'
# T-100
> status: active | lane: a | decision: none | domain: root
GOAL: coordinator card
WRITE-SET: src/a/**, engine/tasks/T-100.md, engine/tasks/T-100/progress.md, engine/CONTEXT.md
AC: AC-1 t | verify: true
EOF
  cat > "$d/engine/tasks/T-101.md" <<'EOF'
# T-101
> status: active | lane: b | decision: none | domain: root
GOAL: worker session card
WRITE-SET: src/b/**, engine/tasks/T-101.md, engine/tasks/T-101/progress.md, engine/evidence/T-101/checkpoint.md
AC: AC-1 t | verify: true
EOF
  git -C "$d" add -A
  git -C "$d" commit -qm init
  # coordinator alpha holds a fresh lease; wsid is a demoted worker session
  printf '111|alpha|coordinator|2026-01-01T00:00:00Z|T-100\n' > "$d/engine/.cache/session.lock"
  : > "$d/engine/.cache/sessions/wsid-main.role=worker"
  printf '%s\n' "$d"
}

hook() { # $1=repo $2=payload
  printf '%s' "$2" | CLAUDE_PROJECT_DIR="$1" bash "$STOP_SH" --pre-tool-use 2>/dev/null
}

echo "=== worker scope narrowing (bash) ==="

r="$(new_fixture)"

# S1: worker session writes ITS OWN card's progress.md -> pass (union covers it)
got="$(classify "$(hook "$r" '{"session_id":"wsid","tool_name":"Edit","tool_input":{"file_path":"engine/tasks/T-101/progress.md"}}')")"
if [ "$got" = "pass" ]; then ok "S1 worker writes own task progress.md"; else bad "S1 -> $got"; fi

# S2: worker session writes its own checkpoint -> pass
got="$(classify "$(hook "$r" '{"session_id":"wsid","tool_name":"Edit","tool_input":{"file_path":"engine/evidence/T-101/checkpoint.md"}}')")"
if [ "$got" = "pass" ]; then ok "S2 worker writes own checkpoint"; else bad "S2 -> $got"; fi

# S3: worker session still blocked from shared singleton (lease held by alpha)
got="$(classify "$(hook "$r" '{"session_id":"wsid","tool_name":"Edit","tool_input":{"file_path":"engine/CONTEXT.md"}}')")"
if [ "$got" = "block" ]; then ok "S3 worker blocked from singleton"; else bad "S3 -> $got"; fi

# S4: worker session writes own shard under ITS card (not the lex-first card) -> pass
got="$(classify "$(hook "$r" '{"session_id":"wsid","tool_name":"Write","tool_input":{"file_path":"engine/workstreams/T-101/wsid-main/CONTEXT.md"}}')")"
if [ "$got" = "pass" ]; then ok "S4 worker shard under own (second) card"; else bad "S4 -> $got"; fi

# S5: worker shard under a non-active task id -> block
got="$(classify "$(hook "$r" '{"session_id":"wsid","tool_name":"Write","tool_input":{"file_path":"engine/workstreams/T-999/wsid-main/CONTEXT.md"}}')")"
if [ "$got" = "block" ]; then ok "S5 shard under non-active card blocked"; else bad "S5 -> $got"; fi

# S6: subagent (agent_id) still blocked from task-local files (v6.5 blanket)
got="$(classify "$(hook "$r" '{"session_id":"alpha","agent_id":"sub1","tool_name":"Edit","tool_input":{"file_path":"engine/tasks/T-100/progress.md"}}')")"
if [ "$got" = "block" ]; then ok "S6 subagent blocked from task-local file"; else bad "S6 -> $got"; fi

# S7: subagent writes its own shard -> pass
got="$(classify "$(hook "$r" '{"session_id":"alpha","agent_id":"sub1","tool_name":"Write","tool_input":{"file_path":"engine/workstreams/T-100/sub1/notes.md"}}')")"
if [ "$got" = "pass" ]; then ok "S7 subagent own shard passes"; else bad "S7 -> $got"; fi

# S8: worker editing its own task card -> pass (bootstrap)
got="$(classify "$(hook "$r" '{"session_id":"wsid","tool_name":"Edit","tool_input":{"file_path":"engine/tasks/T-101.md"}}')")"
if [ "$got" = "pass" ]; then ok "S8 worker edits own card (bootstrap)"; else bad "S8 -> $got"; fi

echo ""
echo "worker_scope result: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
