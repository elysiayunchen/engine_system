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
  # v6.12.0 (D-035): the guard also renews this session's lease heartbeat and
  # re-claims a free coordinator lock at the earliest point of each turn.
  guard_payload=""
  if [ ! -t 0 ] && IFS= read -r -t 0 _ 2>/dev/null; then
    guard_payload="$(cat 2>/dev/null || true)"
  fi
  guard_sid="$(printf '%s' "$guard_payload" | grep -oE '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"session_id"[[:space:]]*:[[:space:]]*"//;s/"//')"
  guard_disabled="${ENGINE_DISABLE_MULTI_SESSION:-}"
  [ -f "$ENGINE_DIR/.cache/multi-session.disabled" ] && guard_disabled=1
  if [ -n "$guard_sid" ] && [ -z "$guard_disabled" ]; then
    guard_key="$(printf '%s-%s' "$guard_sid" "main" | tr -c 'A-Za-z0-9._-' '_' | cut -c1-64)"
    mkdir -p "$ENGINE_DIR/.cache/sessions" 2>/dev/null || true
    touch "$ENGINE_DIR/.cache/sessions/${guard_key}.hb" 2>/dev/null || true
    GUARD_LOCK="$ENGINE_DIR/.cache/session.lock"
    if [ -f "$GUARD_LOCK" ]; then
      guard_lock_sid="$(cut -d'|' -f2 "$GUARD_LOCK" 2>/dev/null | head -1)"
      if [ "$guard_lock_sid" = "$guard_sid" ]; then
        touch "$GUARD_LOCK" 2>/dev/null || true
      fi
    else
      guard_now="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date 2>/dev/null || echo unknown)"
      ( set -C; printf '%s|%s|coordinator|%s|\n' "$$" "$guard_sid" "$guard_now" > "$GUARD_LOCK" ) 2>/dev/null || true
    fi
  fi
  guard_ids=""
  guard_count=0
  for f in "$ENGINE_DIR"/tasks/T-*.md; do
    [ -f "$f" ] || continue
    case "$f" in *.spec.md) continue ;; esac
    grep -Eq '^[[:space:]]*(>[[:space:]]*)?status:[[:space:]]*active' "$f" 2>/dev/null || continue
    guard_id="$(basename "$f" .md)"
    guard_ids="${guard_ids:+$guard_ids, }$guard_id"
    guard_count=$((guard_count + 1))
    if [ "$guard_count" -le 3 ]; then
      guard_goal="$(grep -m 1 '^GOAL:' "$f" 2>/dev/null | sed 's/^GOAL:[[:space:]]*//')"
      [ -n "$guard_goal" ] || guard_goal="$(awk '/^##[[:space:]]+GOAL/{on=1;next} on && /^##/{exit} on && NF{print;exit}' "$f" 2>/dev/null)"
      guard_goals="${guard_goals:-}
$guard_id GOAL: $(printf '%.200s' "$guard_goal")"
    fi
  done
  if [ "$guard_count" -gt 0 ]; then
    echo "[Engine Guard] ACTIVE: $guard_ids | Re-check before writing."
    printf '%s\n' "${guard_goals:-}" | sed '/^$/d'
    echo "BOUNDARY: write only inside YOUR card's WRITE-SET; PreToolUse union-gates across all active cards."
  else
    echo "[Engine Guard] ACTIVE: none | v6.5+ ordinary writes are blocked; create/select a task card first."
  fi
  echo "PARALLEL: each session drives its own card; same-task workers write engine/workstreams/<task>/<agent>/; only the lease-holding coordinator writes shared memory."
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
# v6.12.0 (D-035): 多卡并行——注入全部 active 卡(≤3 张全文,超出仅列 header),
# 并提示 union gating 边界(只在自己卡的 WRITE-SET 内写)。
active_task=""
active_count=0
active_ids=""
for f in "$ENGINE_DIR"/tasks/T-*.md; do
  [ -f "$f" ] || continue
  case "$f" in *.spec.md) continue ;; esac
  grep -Eq '^[[:space:]]*(>[[:space:]]*)?status:[[:space:]]*active' "$f" 2>/dev/null || continue
  task_id="$(basename "$f" .md)"
  active_count=$((active_count + 1))
  active_ids="${active_ids:+$active_ids, }$task_id"
  [ -n "$active_task" ] || active_task="$f"
  if [ "$active_count" -le 3 ]; then
    echo "──── 🎯 Active Task Card ($task_id) ────"
    echo "⚠️ 所有项目路径(含 engine/*)必须在某张 active 卡的 WRITE-SET 内;本卡 FORBIDDEN 碰了即被拦截。"
    cat "$f" 2>/dev/null || log_error "failed to read active task card: $f"
    echo ""
  else
    echo "──── 🎯 Additional active card: $task_id (read engine/tasks/$task_id.md) ────"
    echo ""
  fi
done
if [ "$active_count" -eq 0 ]; then
  echo "──── 🎯 Active Task Card: none ────"
  echo "contract-version 6.5+ blocks ordinary writes until a task card is active; finish with engine verify T-NNN."
  echo ""
elif [ "$active_count" -gt 1 ]; then
  echo "⚠️ Multi-card parallel ($active_ids): work under ONE card; write only inside YOUR card's WRITE-SET (union gating)."
  echo ""
fi

# v6.11.0 (D-029/T-036): 多会话 lock 检测 + 协调者/worker 角色分配。
# Claude Code 已通过 stdin JSON payload 传入 session_id(Stop hook 已在用,见 line 191-197)。
# 本会话用 atomic 独占创建 engine/.cache/session.lock:成功 → 协调者(写共享三件套);
# 失败(lock 已存在且 pid 存活)→ 降级 worker(写 engine/workstreams/<task>/<sid>/ 分片)。
# kill switch: ENGINE_DISABLE_MULTI_SESSION=1 或 .cache/multi-session.disabled 文件存在时跳过检测。
ms_disabled="${ENGINE_DISABLE_MULTI_SESSION:-}"
[ -f "$ENGINE_DIR/.cache/multi-session.disabled" ] && ms_disabled=1
if [ -z "$ms_disabled" ]; then
  LOCK="$ENGINE_DIR/.cache/session.lock"
  mkdir -p "$ENGINE_DIR/.cache/sessions" 2>/dev/null || true
  # v6.12.0 (D-035): GC orphan session files older than 7 days(旧会话的
  # role 旗标/心跳/账本不得阴魂不散地影响 resume 会话)。
  find "$ENGINE_DIR/.cache/sessions" -maxdepth 1 -type f -mtime +7 -delete 2>/dev/null || true
  # 从 stdin JSON payload 读取 session_id(Claude Code 已传入)。
  # 防阻塞:仅当 stdin 非终端且数据可立即读时才 cat;否则跳过(避免测试/CI 无 stdin 时挂起)。
  # read -t 0 是 bash builtin,不消费任何字节,仅检测 stdin 是否有数据可读。
  ms_payload=""
  if [ ! -t 0 ] && IFS= read -r -t 0 _ 2>/dev/null; then
    ms_payload="$(cat 2>/dev/null || true)"
  fi
  ms_sid="$(printf '%s' "$ms_payload" | grep -oE '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"session_id"[[:space:]]*:[[:space:]]*"//;s/"//')"
  # v6.11.1 (D-029/T-038) AC-3: UUID fallback 替换 anon-PID(PID 复用风险)
  # 优先级:Claude Code payload session_id > uuidgen > /proc/sys/kernel/random/uuid > timestamp(最后兜底)
  [ -n "$ms_sid" ] || ms_sid="$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || printf 'fallback-%s' "$(date +%s%N 2>/dev/null || date +%s)")"
  ms_pid="$$"
  ms_started="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date 2>/dev/null || echo unknown)"
  ms_task=""
  [ -n "$active_task" ] && ms_task="$(basename "$active_task" .md)"
  # key 算法与 Stop hook safe_id 完全一致(tr -c 'A-Za-z0-9._-' '_',截 64)。
  ms_key="$(printf '%s-%s' "$ms_sid" "main" | tr -c 'A-Za-z0-9._-' '_' | cut -c1-64)"
  [ -n "$ms_key" ] || ms_key="anon-main"
  touch "$ENGINE_DIR/.cache/sessions/${ms_key}.hb" 2>/dev/null || true

  # v6.12.0 (D-035) RC-3 fix:lock 内 pid 是 hook shell 的瞬时 pid(写完即死),
  # kill -0 恒判 stale → 人人接管 → 保护空转。液性改为租约:lock mtime 或持锁
  # 会话 .hb 心跳 mtime 在 ENGINE_SESSION_TTL_MIN(默认 120 分钟)内即算活。
  # 心跳由 PreToolUse(每次工具调用)与 UserPromptSubmit guard(每轮)续租。
  ms_mtime_epoch() {
    stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || printf ''
  }
  ms_lease_fresh() {
    local ttl_min="${ENGINE_SESSION_TTL_MIN:-120}" lock_sid hb newest m now age
    [ -f "$LOCK" ] || return 1
    case "$ttl_min" in ''|*[!0-9]*) ttl_min=120 ;; esac
    newest="$(ms_mtime_epoch "$LOCK")"
    lock_sid="$(cut -d'|' -f2 "$LOCK" 2>/dev/null | head -1)"
    if [ -n "$lock_sid" ]; then
      hb="$ENGINE_DIR/.cache/sessions/$(printf '%s-%s' "$lock_sid" "main" | tr -c 'A-Za-z0-9._-' '_' | cut -c1-64).hb"
      m="$(ms_mtime_epoch "$hb")"
      if [ -n "$m" ]; then
        if [ -z "$newest" ] || [ "$m" -gt "$newest" ] 2>/dev/null; then newest="$m"; fi
      fi
    fi
    [ -n "$newest" ] || return 1
    now="$(date +%s 2>/dev/null)" || return 0
    age=$((now - newest))
    [ "$age" -le $((ttl_min * 60)) ]
  }

  # atomic 独占创建+写入 lock(POSIX noclobber,无 TOCTOU;创建+写入一次完成,无空文件窗口)
  if ( set -C; printf '%s|%s|%s|%s|%s\n' "$ms_pid" "$ms_sid" "coordinator" "$ms_started" "$ms_task" > "$LOCK" ) 2>/dev/null; then
    rm -f "$ENGINE_DIR/.cache/sessions/${ms_key}.role=worker" 2>/dev/null || true
    # T-050 (v6.12.2): 新 coordinator 上任 → 旧 tombstone(上一任 transition 记录)已无意义,清理。
    # 对称 Stop hook 写 tombstone 的逻辑;tombstone 是历史事件,不是 active 状态(lock + lease mtime 才是)。
    rm -f "$ENGINE_DIR/.cache/session.tombstone" 2>/dev/null || true
    echo "──── 👑 Coordinator (multi-session lease acquired) ────"
    echo "本会话为协调者:可写共享三件套(CONTEXT/HANDOFF/ENGINE_MAP)。并行会话请各持一张任务卡。"
  else
    ms_lock_sid="$(cut -d'|' -f2 "$LOCK" 2>/dev/null | head -1)"
    if [ "$ms_lock_sid" = "$ms_sid" ]; then
      # 同一会话 resume/clear/compact 重入:重盖自己的租约,清掉残留 worker 旗标(RC-3b)。
      printf '%s|%s|%s|%s|%s\n' "$ms_pid" "$ms_sid" "coordinator" "$ms_started" "$ms_task" > "$LOCK" 2>/dev/null || true
      rm -f "$ENGINE_DIR/.cache/sessions/${ms_key}.role=worker" 2>/dev/null || true
      # T-050 (v6.12.2): resume 也清理 tombstone(同 session 上次 crash 后留下的 stale transition 记录)。
      rm -f "$ENGINE_DIR/.cache/session.tombstone" 2>/dev/null || true
      echo "──── 👑 Coordinator (own lease re-acquired) ────"
      echo "本会话恢复协调者租约(resume/compact 重入)。"
    elif ms_lease_fresh; then
      # 租约新鲜 → 降级 worker:写 .role=worker 旗标(PreToolUse 双信号第 2 信号)。
      : > "$ENGINE_DIR/.cache/sessions/${ms_key}.role=worker" 2>/dev/null || true
      echo "──── 🔧 Worker (lease held by another live session) ────"
      echo "本会话降级为 worker:激活/新建自己的任务卡照常干活(union gating);共享三件套由协调者写。"
      echo "同卡协作时跑 'engine workstream T-NNN <sid> --kind=session' 写自己的分片。"
    else
      # 租约超时 → 接管协调者(覆盖 lock + tombstone 通知 + 清自身旗标)。
      printf '%s|%s|%s|%s|%s\n' "$ms_pid" "$ms_sid" "coordinator" "$ms_started" "$ms_task" > "$LOCK" 2>/dev/null || true
      printf '%s|%s|%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date)" "${ms_lock_sid:-unknown}" "stale-recovered" > "$ENGINE_DIR/.cache/session.tombstone" 2>/dev/null || true
      rm -f "$ENGINE_DIR/.cache/sessions/${ms_key}.role=worker" 2>/dev/null || true
      echo "──── 👑 Coordinator (recovered from stale lease) ────"
      echo "本会话接管协调者(原持锁会话心跳超时 TTL=${ENGINE_SESSION_TTL_MIN:-120}min)。"
    fi
  fi
  echo ""
fi

# v6.9.0 (D-028/T-034): AC 级 checkpoint.md 优先注入——active/paused 卡存在时,
# 读取 engine/evidence/T-NNN/checkpoint.md 全文注入,优先级链 #1(覆盖 progress.md §4
# 与 HANDOFF 立即恢复点)。verify 脚本写 checkpoint,agent 写 progress.md。
for f in "$ENGINE_DIR"/tasks/T-*.md; do
  [ -f "$f" ] || continue
  [[ "$f" == *.spec.md ]] && continue
  if grep -Eq '^[[:space:]]*(>[[:space:]]*)?status:[[:space:]]*(active|paused)' "$f" 2>/dev/null; then
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
  if grep -Eq '^[[:space:]]*(>[[:space:]]*)?status:[[:space:]]*(active|paused)' "$f" 2>/dev/null; then
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
  if grep -Eq '^[[:space:]]*(>[[:space:]]*)?status:[[:space:]]*proposed' "$f" 2>/dev/null; then
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
