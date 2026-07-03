#!/usr/bin/env bash
# Engine System — Stop hook · "收尾守门员 / session-close gatekeeper"（硬门禁）
#
# 职责（三层，从严到宽）:
#   1. 任务卡校验（v6 S1+S2）:有 active 任务卡时——
#      ① WRITE-SET 越界 / FORBIDDEN → block（S1）;
#      ② 路由一致性:code_path 所属域(联邦表 federation.json)必须 ∈ 任务卡
#         domain 集合,越域 → block（S2）。无 active 任务卡 → 跳过本层（向后兼容）。
#   2. 硬门禁（v5.6）:改了代码但没回写 CONTEXT/HANDOFF/ENGINE_MAP → block。
#   3. 软门禁 WARN（v6 S0）:记忆已回写但无 change capsule → systemMessage 提示。
#
# 回写定义:engine/CONTEXT.md / HANDOFF.md / ENGINE_MAP.md 至少其一被触碰;
#   change capsule(engine/changes/CHANGE-*.md)计入观察,缺失只 WARN 不拦截。
#
# 解析契约:git status --porcelain -z -uall（NUL 分隔）。非 ASCII 路径在默认
#   core.quotepath=true 下会被引号+八进制转义包裹,击穿列位解析;-z 从不转义,
#   rename/copy 记录为 "XY 新路径\0旧路径\0" → 取新路径,跳过旧路径。
#   语义必须与 PowerShell 孪生实现一致,由 tests/hook-parity/run-parity.sh +
#   tests/task-card/run-task-tests.sh 强制。
#
# 安全契约:只读引擎文件;仅读取 git status。幂等(stop_hook_active 防死循环)。
#   任何异常都放行(宁可漏拦也不卡死会话)。触发:Stop。

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
ENGINE_DIR="$ROOT/engine"

payload="$(cat 2>/dev/null || true)"
case "$payload" in
  *'"stop_hook_active":true'*|*'"stop_hook_active": true'*) exit 0 ;;
esac

[ -d "$ENGINE_DIR" ] || exit 0
command -v git >/dev/null 2>&1 || exit 0
git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# ── 路径分类 ──────────────────────────────────────────────────────────────
code_changed=0
engine_written=0
capsule_written=0
code_paths=()
skip_next=0
while IFS= read -r -d '' rec || [ -n "$rec" ]; do
  if [ "$skip_next" -eq 1 ]; then skip_next=0; continue; fi
  [ "${#rec}" -ge 4 ] || continue
  st="${rec:0:2}"
  path="${rec:3}"
  case "$st" in *R*|*C*) skip_next=1 ;; esac
  case "$path" in
    engine/CONTEXT.md|engine/HANDOFF.md|engine/ENGINE_MAP.md) engine_written=1 ;;
    engine/changes/CHANGE-*.md) capsule_written=1 ;;
    engine/.cache/*|.engine/*) : ;;
    engine/*) : ;;
    *) code_changed=1; code_paths+=("$path") ;;
  esac
done < <(git -C "$ROOT" status --porcelain -z -uall 2>/dev/null)

# ── 第 2 层:硬门禁（回写检查）──────────────────────────────────────────
if [ "$code_changed" -eq 1 ] && [ "$engine_written" -eq 0 ]; then
  reason="【Engine System · 收尾守门员】本次会话改动了代码,但项目记忆(engine/CONTEXT.md / HANDOFF.md)还没同步。结束前请先增量回写:1) 更新 CONTEXT 状态面板的『上次完成』『进行中』;2) 在 HANDOFF 顶部追加一行交接(日期 | 做了什么 | 下一步 | 改动文件);3) 若这是一次有意义的改动,建议补一份 change capsule(engine/changes/CHANGE-YYYY-MM-DD-nn.md)。完成后即可结束。"
  printf '{"decision":"block","reason":"%s"}\n' "$reason"
  exit 0
fi

# ── 第 1 层:任务卡写集校验（v6 S1）──────────────────────────────────────
# 找到 active 任务卡（取 NNN 最小的一个）。
active_task=""
active_task_id=""
for f in "$ENGINE_DIR"/tasks/T-*.md; do
  [ -f "$f" ] || continue
  if grep -q 'status:.*active' "$f" 2>/dev/null; then
    active_task="$f"
    active_task_id="$(basename "$f" .md)"
    break
  fi
done

if [ -n "$active_task" ] && [ "${#code_paths[@]}" -gt 0 ]; then
  # 解析 WRITE-SET / FORBIDDEN（首行,逗号分隔 glob）。
  write_set="$(grep '^WRITE-SET:' "$active_task" 2>/dev/null | head -1 | sed 's/^WRITE-SET://')"
  forbidden="$(grep '^FORBIDDEN:' "$active_task" 2>/dev/null | head -1 | sed 's/^FORBIDDEN://')"

  # glob 匹配:逗号分隔的 pattern 列表,path 命中任一即 true。
  match_glob() {
    local path="$1" patterns="$2" p=""
    [ -n "$patterns" ] || return 1
    local saved_IFS="$IFS"
    IFS=','
    for p in $patterns; do
      p="${p#"${p%%[![:space:]]*}"}"
      p="${p%"${p##*[![:space:]]}"}"
      [ -n "$p" ] || continue
      case "$path" in
        $p) IFS="$saved_IFS"; return 0 ;;
      esac
    done
    IFS="$saved_IFS"
    return 1
  }

  for path in "${code_paths[@]}"; do
    # FORBIDDEN 优先（架构师否决权）。
    if [ -n "$forbidden" ] && match_glob "$path" "$forbidden"; then
      reason="【Engine System · 任务卡禁区】路径 $path 在任务卡 $active_task_id 的 FORBIDDEN 列表中。这是架构师的否决权——禁止触碰。若需解禁,请创建新决策(engine/decisions/D-NNN.md)并更新任务卡。"
      printf '{"decision":"block","reason":"%s"}\n' "$reason"
      exit 0
    fi
    # WRITE-SET 越界。
    if [ -n "$write_set" ] && ! match_glob "$path" "$write_set"; then
      reason="【Engine System · 写集越界】路径 $path 不在任务卡 $active_task_id 的 WRITE-SET 中。若需扩展写集,请更新 engine/tasks/$active_task_id.md 的 WRITE-SET,或创建新决策。当前 WRITE-SET: $write_set"
      printf '{"decision":"block","reason":"%s"}\n' "$reason"
      exit 0
    fi
  done

  # ── S2: 路由一致性校验 ──────────────────────────────────────────────
  # federation.json 存在 + 任务卡声明 domain 时,每条 code_path 所属域(联邦表
  # 解析)必须 ∈ 任务卡 domain 集合,越域 = block。无 federation.json / 任务卡
  # 无 domain → 跳过(向后兼容 S1)。
  fed="$ENGINE_DIR/domains/federation.json"
  task_domains="$(grep '^>.*domain:' "$active_task" 2>/dev/null | head -1 | sed 's/.*domain:[[:space:]]*//' | sed 's/|.*//' | tr -d ' ')"
  if [ -f "$fed" ] && [ -n "$task_domains" ]; then
    federation="$(awk '
      /"default_domain"/ { if (match($0, /"default_domain"[[:space:]]*:[[:space:]]*"([^"]+)"/, m)) print "DEFAULT\t" m[1]; next }
      /^[[:space:]]*"[A-Za-z0-9_-]+"[[:space:]]*:[[:space:]]*\{/ { if (match($0, /"([A-Za-z0-9_-]+)"/, m)) { domain=m[1]; in_paths=0 }; next }
      /"paths"/ { in_paths=1; s=$0; sub(/.*"paths"[[:space:]]*:[[:space:]]*/, "", s); if (s ~ /\]/) { in_paths=0; while (match(s, /"([^"]+)"/, m)) { if (domain!="") print domain "\t" m[1]; s=substr(s, RSTART+RLENGTH) } }; next }
      in_paths && /\]/ { in_paths=0; next }
      in_paths { s=$0; while (match(s, /"([^"]+)"/, m)) { if (domain!="") print domain "\t" m[1]; s=substr(s, RSTART+RLENGTH) } }
    ' "$fed" 2>/dev/null)"
    default_dom="$(printf '%s\n' "$federation" | awk -F'\t' '/^DEFAULT/{print $2; exit}')"
    if [ -n "$federation" ]; then
      for path in "${code_paths[@]}"; do
        path_dom=""
        while IFS=$'\t' read -r d g; do
          [ "$d" = "DEFAULT" ] && continue
          [ -n "$g" ] || continue
          case "$path" in
            $g) path_dom="$d"; break ;;
          esac
        done <<< "$federation"
        [ -n "$path_dom" ] || path_dom="${default_dom:-root}"
        if ! printf '%s' ",$task_domains," | grep -qF ",$path_dom,"; then
          reason="【Engine System · 路由越域】路径 $path 属于域「$path_dom」,但任务卡 $active_task_id 的 domain 只覆盖 [$task_domains]。若需跨域工作,请更新任务卡的 domain 字段(逗号分隔)。"
          printf '{"decision":"block","reason":"%s"}\n' "$reason"
          exit 0
        fi
      done
    fi
  fi
fi

# ── 第 3 层:软门禁 WARN（capsule 缺失）─────────────────────────────────
if [ "$code_changed" -eq 1 ] && [ "$engine_written" -eq 1 ] && [ "$capsule_written" -eq 0 ]; then
  printf '{"systemMessage":"【Engine System】代码改动已回写 CONTEXT/HANDOFF,但未见 change capsule(engine/changes/CHANGE-*.md)。若这是一次有意义的改动,建议让 agent 补一份架构师可读的变更胶囊。(WARN,不拦截)"}\n'
  exit 0
fi

exit 0
