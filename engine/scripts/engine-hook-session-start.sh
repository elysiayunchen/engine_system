#!/usr/bin/env bash
# Fail-open by design: errors are logged to stderr but never block the agent session.
set -u
log_error() { echo "[engine-hook-session-start] ERROR: $*" >&2; }
# Engine System — SessionStart hook · "自动接手 / auto-handoff"
#
# 在新会话开始时读取项目记忆,把状态摘要打到 stdout 注入 agent 上下文,
# 让 agent 无需架构师重新介绍即可接手上次的工作。
#
# v6 S1: 始终注入 active 任务卡。压缩后(compact)/恢复(resume)是漂移最危险
# 的时刻——任务卡把 GOAL/WRITE-SET/FORBIDDEN 重新打到 agent 眼前,锚住意图。
#
# 安全契约:只读。不写引擎文件、不碰代码、不联网。任何失败都绝不致命(始终 exit 0)。
# 触发:SessionStart(新会话 / --resume / /clear / 自动压缩后)。

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
ENGINE_DIR="$ROOT/engine"
MODE="${1:-full}"

if [ ! -d "$ENGINE_DIR" ]; then
  echo "[Engine System] engine/ directory not found. Run /engine-init to create the project memory layer."
  exit 0
fi

# UserPromptSubmit calls this compact mode. It is deliberately short: enough to
# restore the non-negotiable boundary after long runs without reinjecting L2.
if [ "$MODE" = "--guard" ]; then
  guard_task=""
  for f in "$ENGINE_DIR"/tasks/T-*.md; do
    [ -f "$f" ] || continue
    if grep -q 'status:.*active' "$f" 2>/dev/null; then guard_task="$f"; break; fi
  done
  if [ -n "$guard_task" ]; then
    guard_id="$(basename "$guard_task" .md)"
    guard_goal="$(grep -m 1 '^GOAL:' "$guard_task" 2>/dev/null | sed 's/^GOAL:[[:space:]]*//')"
    [ -n "$guard_goal" ] || guard_goal="$(awk '/^##[[:space:]]+GOAL/{on=1;next} on && /^##/{exit} on && NF{print;exit}' "$guard_task" 2>/dev/null)"
    echo "[Engine Guard] ACTIVE: $guard_id | Re-check before writing."
    printf 'GOAL: %.240s\n' "$guard_goal"
    echo "BOUNDARY: read engine/tasks/$guard_id.md before edits; PreToolUse enforces WRITE-SET/FORBIDDEN."
  else
    echo "[Engine Guard] ACTIVE: none | v6.5+ ordinary writes are blocked; create/select a task card first."
  fi
  echo "PARALLEL: workers share the task and write engine/workstreams/<task>/<agent>/; coordinator owns shared memory."
  exit 0
fi

echo "【Engine System · 自动接手】下面是项目记忆当前快照。请先检测开发者使用的语言,然后用该语言复述当前状态,再开始工作。"
echo ""

# v6 中优先: L0 宪法注入(runtime-law.md ≤40 行常驻法,对抗漂移的顶层锚点)。
if [ -f "$ROOT/runtime-law.md" ]; then
  echo "──── ⚖️  L0 Constitution (runtime-law) ────"
  sed -n '1,40p' "$ROOT/runtime-law.md" 2>/dev/null
  echo ""
fi

# v6.1: GLOSSARY 术语表注入——agent 与开发者交流时必须使用 Plain meaning 列。
# 只注入 header + 指令(3 行),完整术语表按需读取,节省 token 预算。
glossary="$ENGINE_DIR/GLOSSARY.md"
if [ -f "$glossary" ]; then
  echo "──── 📖 术语表 (engine/GLOSSARY.md) ────"
  echo "与开发者交流时,必须使用 GLOSSARY.md 的 Plain meaning 列解释引擎概念。"
  echo "用开发者使用的语言(非固定中文)解释。完整术语表: engine/GLOSSARY.md"
  echo ""
fi

if [ -f "$ENGINE_DIR/CONTEXT.md" ]; then
  echo "──── 📊 Current State (engine/CONTEXT.md) ────"
  sed -n '1,50p' "$ENGINE_DIR/CONTEXT.md" 2>/dev/null
  echo ""
fi

if [ -f "$ENGINE_DIR/HANDOFF.md" ]; then
  echo "──── 🔀 Last Handoff (engine/HANDOFF.md, newest first) ────"
  grep -m 4 '^|' "$ENGINE_DIR/HANDOFF.md" 2>/dev/null
  echo ""
fi

# v6 S2: 域仪表盘(汇总协议)——每个域一句话摘要,根文件规模 = O(域数),不是 O(仓库)。
fed="$ENGINE_DIR/domains/federation.json"
if [ -f "$fed" ]; then
  echo "──── 🗺️  Domain Dashboard (federation) ────"
  awk '
    /^[[:space:]]*"[A-Za-z0-9_-]+"[[:space:]]*:[[:space:]]*\{/ { if (match($0, /"([A-Za-z0-9_-]+)"/, m)) { domain=m[1]; next } }
    /"summary"/ { if (match($0, /"summary"[[:space:]]*:[[:space:]]*"([^"]+)"/, m)) print "• " domain ": " m[1]; next }
  ' "$fed" 2>/dev/null
  echo ""
fi

# v6 S1: active 任务卡重注入——对抗漂移的核心锚点。
active_task=""
for f in "$ENGINE_DIR"/tasks/T-*.md; do
  [ -f "$f" ] || continue
  if grep -q 'status:.*active' "$f" 2>/dev/null; then
    active_task="$f"
    break
  fi
done
if [ -n "$active_task" ]; then
  task_id="$(basename "$active_task" .md)"
  echo "──── 🎯 Active Task Card ($task_id) ────"
  echo "⚠️ 所有项目路径(含 engine/*)必须在 WRITE-SET 内;FORBIDDEN 碰了即被拦截。"
  cat "$active_task" 2>/dev/null || log_error "failed to read active task card: $active_task"
  echo ""
else
  echo "──── 🎯 Active Task Card: none ────"
  echo "contract-version 6.5+ blocks ordinary writes until a task card is active; finish with engine verify T-NNN."
  echo ""
fi

# v6.9.0 (D-028/T-034): AC 级 checkpoint.md 优先注入——active/paused 卡存在时,
# 读取 engine/evidence/T-NNN/checkpoint.md 全文注入,优先级链 #1(覆盖 progress.md §4
# 与 HANDOFF 立即恢复点)。verify 脚本写 checkpoint,agent 写 progress.md。
for f in "$ENGINE_DIR"/tasks/T-*.md; do
  [ -f "$f" ] || continue
  [[ "$f" == *.spec.md ]] && continue
  if grep -q 'status:.*\(active\|paused\)' "$f" 2>/dev/null; then
    cp_id="$(basename "$f" .md)"
    cp="$ENGINE_DIR/evidence/$cp_id/checkpoint.md"
    if [ -f "$cp" ]; then
      echo "──── ✅ AC Checkpoint ($cp_id/checkpoint.md) ────"
      cat "$cp" 2>/dev/null || log_error "failed to read checkpoint: $cp"
      echo ""
    fi
  fi
done

# v6.7.0 (D-028/T-032): 任务级 progress.md 注入——active/paused 卡存在时,
# 读取 engine/tasks/T-NNN/progress.md 全文注入,覆盖 HANDOFF「立即恢复点」§4 段。
# 多张 active/paused 卡按 ID 升序全部注入(实践应 ≤2 张,超出 Doctor WARN)。
for f in "$ENGINE_DIR"/tasks/T-*.md; do
  [ -f "$f" ] || continue
  [[ "$f" == *.spec.md ]] && continue
  if grep -q 'status:.*\(active\|paused\)' "$f" 2>/dev/null; then
    prog_id="$(basename "$f" .md)"
    prog="$ENGINE_DIR/tasks/$prog_id/progress.md"
    if [ -f "$prog" ]; then
      echo "──── 📌 Task Progress ($prog_id/progress.md) ────"
      cat "$prog" 2>/dev/null || log_error "failed to read progress: $prog"
      echo ""
    else
      echo "──── 📌 Task Progress: $prog_id 缺 progress.md (Doctor WARN) ────"
      echo "active/paused 卡 $prog_id 缺 progress.md;按 contract/src/20-file-templates.md FILE 13 从 engine/skeleton/progress.md 实例化。"
      echo ""
    fi
  fi
done

# v6 S2: L2 所属域装配——按 active 任务卡 domain 拉取对应域的 CONTEXT+PITFALLS(各受预算约束)。
if [ -n "$active_task" ] && [ -f "$fed" ]; then
  task_domains_l2="$(grep '^>.*domain:' "$active_task" 2>/dev/null | head -1 | sed 's/.*domain:[[:space:]]*//' | sed 's/|.*//' | tr -d ' ')"
  if [ -n "$task_domains_l2" ]; then
    saved_IFS="$IFS"; IFS=','
    for dom in $task_domains_l2; do
      [ -n "$dom" ] || continue
      dom_ctx="$ENGINE_DIR/domains/$dom/CONTEXT.md"
      dom_pit="$ENGINE_DIR/domains/$dom/PITFALLS.md"
      if [ -f "$dom_ctx" ] || [ -f "$dom_pit" ]; then
        echo "──── 📦 L2 Domain: $dom ────"
        [ -f "$dom_ctx" ] && sed -n '1,50p' "$dom_ctx" 2>/dev/null
        [ -f "$dom_pit" ] && sed -n '1,40p' "$dom_pit" 2>/dev/null
        echo ""
      fi
    done
    IFS="$saved_IFS"
  fi
fi

# 「等你拍板」队列:proposed 决策,提示架构师需要拍板。
proposed_count=0
for f in "$ENGINE_DIR"/decisions/D-*.md; do
  [ -f "$f" ] || continue
  if grep -q 'status:.*proposed' "$f" 2>/dev/null; then
    if [ "$proposed_count" -eq 0 ]; then
      echo "──── ⏳ Pending Decisions (proposed) ────"
    fi
    head -3 "$f" 2>/dev/null
    echo ""
    proposed_count=$((proposed_count + 1))
  fi
done

# SessionEnd hook 会把遗留待办/Doctor 结果写到这里，由本钩子读出。
if [ -f "$ENGINE_DIR/.cache/pending.txt" ]; then
  echo "──── ⚠️  Pending from Previous Session ────"
  cat "$ENGINE_DIR/.cache/pending.txt" 2>/dev/null
  echo ""
fi

# v6 自动检测更新: 24h 缓存, fail-open(联网失败/无 curl 静默跳过,绝不阻塞会话)。
# 安全: 只读远程 VERSION 单文件, 不写引擎记忆, 不碰代码。提示非阻塞。
cache="$ENGINE_DIR/.cache/update-check.json"
now="$(date +%s)"
check_interval=86400  # 24h
need_check=1
if [ -f "$cache" ]; then
  last_check="$(grep -oE '"last_check":[[:space:]]*[0-9]+' "$cache" 2>/dev/null | head -1 | sed 's/.*:[[:space:]]*//')"
  if [ -n "$last_check" ] && [ $((now - last_check)) -lt $check_interval ]; then
    need_check=0
  fi
fi

if [ "$need_check" -eq 1 ]; then
  REPO_U="${ENGINE_SYSTEM_REPO:-elysiayunchen/engine_system}"
  BRANCH_U="${ENGINE_SYSTEM_BRANCH:-main}"
  remote_version=""
  if command -v curl >/dev/null 2>&1; then
    remote_version="$(curl -sSL --max-time 5 "https://raw.githubusercontent.com/${REPO_U}/${BRANCH_U}/VERSION" 2>/dev/null || true)"
  elif command -v wget >/dev/null 2>&1; then
    remote_version="$(wget -qO - --timeout=5 "https://raw.githubusercontent.com/${REPO_U}/${BRANCH_U}/VERSION" 2>/dev/null || true)"
  fi
  remote_version="$(printf '%s' "$remote_version" | tr -d '[:space:]')"

  local_version="unknown"
  [ -f "$ENGINE_DIR/VERSION" ] && local_version="$(tr -d '[:space:]' < "$ENGINE_DIR/VERSION")"

  # Write cache (best effort; never fail the session on a cache write error).
  mkdir -p "$ENGINE_DIR/.cache" 2>/dev/null || true
  printf '{"last_check":%s,"latest":"%s","current":"%s"}\n' "$now" "$remote_version" "$local_version" > "$cache" 2>/dev/null || true
fi

# Hint if a newer version exists (read from cache, non-blocking).
# D-015: 归一化比较(6.0 ≡ 6.0.0)防伪更新提示;非数字版本退回原始不等判定。
norm_v() {
  v="$(printf '%s' "${1:-}" | tr -d '[:space:]')"
  case "$v" in ''|*[!0-9.]*) printf '%s' "$v"; return ;; esac
  case "$v" in *.*.*) ;; *.*) v="$v.0" ;; *) v="$v.0.0" ;; esac
  printf '%s' "$v"
}
if [ -f "$cache" ]; then
  latest="$(grep -oE '"latest":[[:space:]]*"[^"]*"' "$cache" 2>/dev/null | head -1 | sed 's/.*"latest":[[:space:]]*"//;s/"//')"
  current="$(grep -oE '"current":[[:space:]]*"[^"]*"' "$cache" 2>/dev/null | head -1 | sed 's/.*"current":[[:space:]]*"//;s/"//')"
  if [ -n "$latest" ] && [ "$latest" != "" ] && [ "$(norm_v "$latest")" != "$(norm_v "$current")" ]; then
    echo "──── 🔄 Engine Update Available ────"
    echo "本地 $current -> 远程 $latest。运行 engine update 更新。"
    echo ""
  fi
fi

exit 0
