#!/usr/bin/env bash
# Engine System — 分形记忆测试(v6 S2)
#
# 测试三组:
#   A. 联邦表解析(path → domain)
#   B. Stop hook 路由一致性门禁(越域 = block,域内 = pass,无域回退 S1)
#   C. SessionStart L2 装配 + 域仪表盘汇总协议
#
# 用法:bash tests/fractal-memory/run-fractal-tests.sh

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
STOP_SH="$REPO_ROOT/plugin/engine/scripts/engine-hook-stop.sh"
STOP_PS1="$REPO_ROOT/plugin/engine/scripts/engine-hook-stop.ps1"
START_SH="$REPO_ROOT/plugin/engine/scripts/engine-hook-session-start.sh"
START_PS1="$REPO_ROOT/plugin/engine/scripts/engine-hook-session-start.ps1"
PAYLOAD='{"stop_hook_active":false}'

PS_BIN=""
for c in pwsh powershell powershell.exe; do
  if command -v "$c" >/dev/null 2>&1; then PS_BIN="$c"; break; fi
done
if [ -n "$PS_BIN" ] && command -v wslpath >/dev/null 2>&1 && [[ "$PS_BIN" == *powershell.exe ]]; then
  PS_BIN=""
fi

ps_path() {
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$1"
  elif command -v wslpath >/dev/null 2>&1; then
    wslpath -w "$1"
  else
    printf '%s\n' "$1"
  fi
}

pass=0
fail=0
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

classify() {
  case "$1" in
    *'"decision":"block"'*) echo block ;;
    *'"systemMessage"'*)    echo warn ;;
    *)                      echo pass ;;
  esac
}

new_repo() {
  d="$(mktemp -d "$TMP_ROOT/repo.XXXXXX")"
  git -C "$d" init -q
  git -C "$d" config user.email fm@test
  git -C "$d" config user.name fm
  git -C "$d" config core.quotepath true
  git -C "$d" config core.autocrlf false
  git -C "$d" config commit.gpgsign false
  mkdir -p "$d/engine/tasks" "$d/engine/decisions" "$d/engine/changes" "$d/engine/domains" \
           "$d/src/alpha" "$d/src/beta"
  printf 'ctx\n' > "$d/engine/CONTEXT.md"
  printf 'hf\n'  > "$d/engine/HANDOFF.md"
  printf 'map\n' > "$d/engine/ENGINE_MAP.md"
  printf 'code\n' > "$d/src/seed.js"
  git -C "$d" add -A
  git -C "$d" commit -qm init
  printf '%s\n' "$d"
}

write_federation() {
  repo="$1"
  cat > "$repo/engine/domains/federation.json" <<'EOF'
{
  "_comment": "test federation",
  "domains": {
    "alpha": {
      "paths": ["src/alpha/**"],
      "summary": "ALPHA_SUMMARY"
    },
    "beta": {
      "paths": ["src/beta/**"],
      "summary": "BETA_SUMMARY"
    }
  },
  "default_domain": "root"
}
EOF
}

write_domain() {
  repo="$1"; dom="$2"
  mkdir -p "$repo/engine/domains/$dom"
  printf '# %s\n%s_CTX_MARKER\n' "$dom" "$(echo "$dom" | tr a-z A-Z)" > "$repo/engine/domains/$dom/CONTEXT.md"
  printf '# %s\n%s_PIT_MARKER\n' "$dom" "$(echo "$dom" | tr a-z A-Z)" > "$repo/engine/domains/$dom/PITFALLS.md"
}

write_task_domain() {
  repo="$1"; id="$2"; status="$3"; domain="$4"; write_set="$5"
  cat > "$repo/engine/tasks/$id.md" <<EOF
# TASK CARD — $id
> status: $status | lane: main | decision: | plan: none | domain: $domain
GOAL: test task
WRITE-SET: $write_set
FORBIDDEN: none
AC: AC-1 test → verify: true
CONSTRAINTS: none
EOF
}

write_capsule() {
  repo="$1"
  printf '# CHANGE-test\ntest capsule\n' > "$repo/engine/changes/CHANGE-2026-07-03-01.md"
}

# 改 CONTEXT.md 让 engine_written=1,使第 2 层硬门禁放行——这样第 1 层路由校验才会执行。
write_back() {
  repo="$1"
  printf 'updated\n' >> "$repo/engine/CONTEXT.md"
}

touch_code() {
  repo="$1"; path="$2"
  mkdir -p "$(dirname "$repo/$path")"
  printf 'x\n' > "$repo/$path"
}

run_stop() {
  name="$1"; repo="$2"; expect="$3"
  out="$(printf '%s' "$PAYLOAD" | CLAUDE_PROJECT_DIR="$repo" bash "$STOP_SH" 2>/dev/null)"
  got="$(classify "$out")"
  if [ "$got" = "$expect" ]; then
    echo "PASS  sh  $name -> $got"; pass=$((pass+1))
  else
    echo "FAIL  sh  $name -> expect=$expect got=$got out=${out:0:90}"; fail=$((fail+1))
  fi
  if [ -n "$PS_BIN" ]; then
    repo_ps="$(ps_path "$repo")"
    stop_ps1="$(ps_path "$STOP_PS1")"
    out_ps="$(printf '%s' "$PAYLOAD" | CLAUDE_PROJECT_DIR="$repo_ps" "$PS_BIN" -NoProfile -ExecutionPolicy Bypass -File "$stop_ps1" 2>/dev/null)"
    got_ps="$(classify "$out_ps")"
    if [ "$got_ps" = "$expect" ]; then
      echo "PASS  ps1 $name -> $got_ps"; pass=$((pass+1))
    else
      echo "FAIL  ps1 $name -> expect=$expect got=$got_ps out=${out_ps:0:90}"; fail=$((fail+1))
    fi
  fi
}

run_start() {
  name="$1"; repo="$2"; pattern="$3"; expect_present="$4"
  out="$(CLAUDE_PROJECT_DIR="$repo" bash "$START_SH" 2>/dev/null)"
  if printf '%s' "$out" | grep -q "$pattern"; then present=1; else present=0; fi
  if [ "$present" = "$expect_present" ]; then
    echo "PASS  sh  $name"; pass=$((pass+1))
  else
    echo "FAIL  sh  $name -> expect_present=$expect_present out=${out:0:90}"; fail=$((fail+1))
  fi
  if [ -n "$PS_BIN" ]; then
    repo_ps="$(ps_path "$repo")"
    start_ps1="$(ps_path "$START_PS1")"
    out_ps="$(CLAUDE_PROJECT_DIR="$repo_ps" "$PS_BIN" -NoProfile -ExecutionPolicy Bypass -File "$start_ps1" 2>/dev/null)"
    if printf '%s' "$out_ps" | grep -q "$pattern"; then present_ps=1; else present_ps=0; fi
    if [ "$present_ps" = "$expect_present" ]; then
      echo "PASS  ps1 $name"; pass=$((pass+1))
    else
      echo "FAIL  ps1 $name -> expect_present=$expect_present out=${out_ps:0:90}"; fail=$((fail+1))
    fi
  fi
}

echo "=== A. 联邦表解析 ==="

# A1: awk 解析 federation.json 输出 domain→glob 对 + DEFAULT(paths 同行闭合不泄漏到 summary)。
r="$(new_repo)"
write_federation "$r"
parsed="$(awk '
  /"default_domain"/ { if (match($0, /"default_domain"[[:space:]]*:[[:space:]]*"([^"]+)"/, m)) print "DEFAULT\t" m[1]; next }
  /^[[:space:]]*"[A-Za-z0-9_-]+"[[:space:]]*:[[:space:]]*\{/ { if (match($0, /"([A-Za-z0-9_-]+)"/, m)) { domain=m[1]; in_paths=0 }; next }
  /"paths"/ { in_paths=1; s=$0; sub(/.*"paths"[[:space:]]*:[[:space:]]*/, "", s); if (s ~ /\]/) { in_paths=0; while (match(s, /"([^"]+)"/, m)) { if (domain!="") print domain "\t" m[1]; s=substr(s, RSTART+RLENGTH) } }; next }
  in_paths && /\]/ { in_paths=0; next }
  in_paths { s=$0; while (match(s, /"([^"]+)"/, m)) { if (domain!="") print domain "\t" m[1]; s=substr(s, RSTART+RLENGTH) } }
' "$r/engine/domains/federation.json")"
expected=$'alpha\tsrc/alpha/**\nbeta\tsrc/beta/**\nDEFAULT\troot'
if [ "$parsed" = "$expected" ]; then
  echo "PASS  sh  A1 federation parse"; pass=$((pass+1))
else
  echo "FAIL  sh  A1 federation parse"; echo "--- got ---"; printf '%s\n' "$parsed"; echo "--- want ---"; printf '%s\n' "$expected"; fail=$((fail+1))
fi

echo ""
echo "=== B. Stop hook 路由一致性门禁 ==="

# B1: code_path 在声明域内 → pass(write_back 过第2层,capsule 过第3层,路由 alpha∈{alpha})。
r="$(new_repo)"; write_federation "$r"; write_domain "$r" alpha; write_domain "$r" beta
write_back "$r"; write_task_domain "$r" T-001 active "alpha" "src/**"; write_capsule "$r"
touch_code "$r" "src/alpha/x.js"
run_stop "B1 route-in-domain-pass" "$r" pass

# B2: code_path 越域(beta ∉ {alpha}) → block。
r="$(new_repo)"; write_federation "$r"; write_back "$r"
write_task_domain "$r" T-001 active "alpha" "src/**"
touch_code "$r" "src/beta/y.js"
run_stop "B2 route-out-of-domain-block" "$r" block

# B3: code_path 落 default root(root ∉ {alpha}) → block(WRITE-SET 含 README 隔离变量)。
r="$(new_repo)"; write_federation "$r"; write_back "$r"
write_task_domain "$r" T-001 active "alpha" "src/**, README.md"
touch_code "$r" "README.md"
run_stop "B3 route-default-block" "$r" block

# B4: 多 domain 声明(alpha,beta),code_path 在 beta → pass。
r="$(new_repo)"; write_federation "$r"; write_back "$r"
write_task_domain "$r" T-001 active "alpha, beta" "src/**"; write_capsule "$r"
touch_code "$r" "src/beta/y.js"
run_stop "B4 multi-domain-pass" "$r" pass

# B5: 向后兼容——无 federation.json,domain: alpha,code 在 alpha → pass(S1 行为,不校验路由)。
r="$(new_repo)"; write_back "$r"
write_task_domain "$r" T-001 active "alpha" "src/**"; write_capsule "$r"
touch_code "$r" "src/alpha/x.js"
run_stop "B5 compat-no-federation-pass" "$r" pass

# B6: 向后兼容——federation.json 存在但任务卡 domain 为空,code 在 beta → pass(不校验路由)。
r="$(new_repo)"; write_federation "$r"; write_back "$r"
write_task_domain "$r" T-001 active "" "src/**"; write_capsule "$r"
touch_code "$r" "src/beta/y.js"
run_stop "B6 compat-no-domain-pass" "$r" pass

echo ""
echo "=== C. SessionStart L2 装配 + 域仪表盘 ==="

# C1: federation.json 存在 → 注入域仪表盘(含 summary)。
r="$(new_repo)"; write_federation "$r"
run_start "C1 dashboard-summary" "$r" "ALPHA_SUMMARY" 1

# C2: active 任务卡 domain: alpha → 注入 alpha 域 L2(含 CONTEXT marker)。
r="$(new_repo)"; write_federation "$r"; write_domain "$r" alpha
write_task_domain "$r" T-001 active "alpha" "src/**"
run_start "C2 l2-assemble-domain" "$r" "ALPHA_CTX_MARKER" 1

# C3: active 任务卡无 domain → 不注入 L2(CONTEXT marker absent;dashboard 仍在)。
r="$(new_repo)"; write_federation "$r"; write_domain "$r" alpha
write_task_domain "$r" T-001 active "" "src/**"
run_start "C3 l2-compat-no-domain" "$r" "ALPHA_CTX_MARKER" 0

# C4: 无 federation.json → 无域仪表盘(summary absent)。
r="$(new_repo)"
run_start "C4 compat-no-dashboard" "$r" "ALPHA_SUMMARY" 0

echo ""
echo "=========================================="
echo "PASS=$pass  FAIL=$fail"
[ "$fail" -eq 0 ]
