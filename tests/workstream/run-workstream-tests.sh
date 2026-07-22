#!/usr/bin/env bash
# Engine System workstream shard tests.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

pass=0
fail=0

ok() { echo "PASS  $1"; pass=$((pass + 1)); }
bad() { echo "FAIL  $1"; fail=$((fail + 1)); }

new_fixture() {
  d="$(mktemp -d "$TMP_ROOT/repo.XXXXXX")"
  mkdir -p "$d/engine/bin" "$d/engine/scripts" "$d/engine/tasks"
  cp "$REPO_ROOT/engine/bin/engine" "$d/engine/bin/engine"
  cp "$REPO_ROOT/engine/bin/engine.ps1" "$d/engine/bin/engine.ps1"
  cp "$REPO_ROOT/engine/scripts/engine-context.sh" "$d/engine/scripts/engine-context.sh"
  cp "$REPO_ROOT/engine/scripts/engine-context.ps1" "$d/engine/scripts/engine-context.ps1"
  printf 'root context\n' > "$d/engine/CONTEXT.md"
  printf 'root handoff\n' > "$d/engine/HANDOFF.md"
  cat > "$d/engine/tasks/T-001.md" <<'EOF'
# T-001
> status: active | lane: main | decision: | domain: root
GOAL: isolate parallel worker memory
WRITE-SET: src/**,engine/workstreams/**
FORBIDDEN:
AC: AC-1 test | verify: true
EOF
  printf '%s\n' "$d"
}

echo "=== workstream CLI (sh) ==="
r="$(new_fixture)"
root_before="$(sha256sum "$r/engine/CONTEXT.md" | cut -d' ' -f1)"
# v6.11.1 (D-029/T-038) AC-5: default --kind=subagent -> T-NNN/agents/a-<agent>/
if (cd "$r" && bash engine/bin/engine workstream T-001 worker-a >/dev/null); then ok "sh create"; else bad "sh create"; fi
[ -f "$r/engine/workstreams/T-001/agents/a-worker-a/CONTEXT.md" ] && [ -f "$r/engine/workstreams/T-001/agents/a-worker-a/HANDOFF.md" ] && ok "sh files" || bad "sh files"
grep -q 'isolate parallel worker memory' "$r/engine/workstreams/T-001/agents/a-worker-a/CONTEXT.md" && ok "sh goal copied" || bad "sh goal copied"
printf '\ncustom marker\n' >> "$r/engine/workstreams/T-001/agents/a-worker-a/CONTEXT.md"
(cd "$r" && bash engine/bin/engine workstream T-001 worker-a >/dev/null)
grep -q 'custom marker' "$r/engine/workstreams/T-001/agents/a-worker-a/CONTEXT.md" && ok "sh idempotent preserve" || bad "sh idempotent preserve"
# v6.11.1 (D-029/T-038) AC-5: --kind=session -> T-NNN/sessions/s-<agent>/
if (cd "$r" && bash engine/bin/engine workstream T-001 worker-sess --kind=session >/dev/null); then ok "sh create session"; else bad "sh create session"; fi
[ -f "$r/engine/workstreams/T-001/sessions/s-worker-sess/CONTEXT.md" ] && ok "sh session files" || bad "sh session files"
if (cd "$r" && ! bash engine/bin/engine workstream T-001 '../unsafe' >/dev/null 2>&1); then ok "sh unsafe id rejected"; else bad "sh unsafe id rejected"; fi
root_after="$(sha256sum "$r/engine/CONTEXT.md" | cut -d' ' -f1)"
[ "$root_before" = "$root_after" ] && ok "sh shared context untouched" || bad "sh shared context untouched"
ctx_out="$(bash "$r/engine/scripts/engine-context.sh" "$r")"
printf '%s' "$ctx_out" | grep -q 'Parallel Workstreams (unmerged)' && ok "sh context dashboard" || bad "sh context dashboard"
# v6.11.1 (D-029/T-038) AC-5: owner display strips a-/s- prefix, so 'worker-a' not 'a-worker-a'.
printf '%s' "$ctx_out" | grep -q 'worker-a' && ok "sh context owner" || bad "sh context owner"

PS_BIN=""
for c in pwsh powershell powershell.exe; do
  if command -v "$c" >/dev/null 2>&1; then PS_BIN="$c"; break; fi
done

if [ -n "$PS_BIN" ]; then
  echo ""
  echo "=== workstream CLI (ps1) ==="
  r="$(new_fixture)"
  # Windows PowerShell invoked from WSL auto-converts Linux /tmp/... paths to
  # \\wsl.localhost\... UNC paths, which System.IO.File::WriteAllText rejects.
  # Native Windows (PS + Windows paths) and native Linux (pwsh + Linux paths)
  # are covered by CI; SKIP here to match hook-parity SKIP convention.
  SKIP_PS_UNC=0
  if uname -s 2>/dev/null | grep -qi linux; then
    case "$PS_BIN" in
      powershell|powershell.exe)
        if grep -qi microsoft /proc/version 2>/dev/null; then
          SKIP_PS_UNC=1
        fi
        ;;
    esac
  fi
  if command -v cygpath >/dev/null 2>&1; then
    engine_ps="$(cygpath -w "$r/engine/bin/engine.ps1")"
    context_ps="$(cygpath -w "$r/engine/scripts/engine-context.ps1")"
    root_ps="$(cygpath -w "$r")"
  else
    engine_ps="$r/engine/bin/engine.ps1"
    context_ps="$r/engine/scripts/engine-context.ps1"
    root_ps="$r"
  fi
  if [ "$SKIP_PS_UNC" = "1" ]; then
    echo "SKIP  ps1 (WSL UNC paths unsupported by Windows PowerShell File API)"
  else
    if (cd "$r" && "$PS_BIN" -NoProfile -ExecutionPolicy Bypass -File "$engine_ps" workstream T-001 worker-ps >/dev/null); then ok "ps1 create"; else bad "ps1 create"; fi
    # v6.11.1 (D-029/T-038) AC-5: default --kind=subagent -> T-NNN/agents/a-<agent>/
    [ -f "$r/engine/workstreams/T-001/agents/a-worker-ps/CONTEXT.md" ] && [ -f "$r/engine/workstreams/T-001/agents/a-worker-ps/HANDOFF.md" ] && ok "ps1 files" || bad "ps1 files"
    ps_ctx="$("$PS_BIN" -NoProfile -ExecutionPolicy Bypass -File "$context_ps" -Root "$root_ps" 2>/dev/null)"
    printf '%s' "$ps_ctx" | grep -q 'Parallel Workstreams (unmerged)' && ok "ps1 context dashboard" || bad "ps1 context dashboard"
    printf '%s' "$ps_ctx" | grep -q 'worker-ps' && ok "ps1 context owner" || bad "ps1 context owner"
  fi
else
  echo "SKIP  ps1 (no PowerShell)"
fi

echo ""
echo "workstream result: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
