#!/usr/bin/env bash
# Engine System — 防漂移校验器(v6.18.0 D-038b)
#
# 不重跑 verify,只做廉价指纹比对。三步顺序:
#   1. 完整性自证(MANIFEST + write_provenance)
#   2. WRITE-SET 二阶检测(snapshot vs 当前任务卡)
#   3. 代码指纹比对(git ls-files -s vs code_fingerprint)
# 任一步 FAIL 仍输出后续摘要(标 unverified),避免 manifest 失败掩盖更深漂移。
#
# 用法: bash engine/scripts/engine-drift-check.sh [--task T-NNN]
#   无 --task: 全量 done 卡
#   --task T-NNN: 单卡

set -uo pipefail
ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
ENGINE_DIR="$ROOT/engine"
TASK_FILTER=""

while [ $# -gt 0 ]; do
  case "$1" in
    --task) TASK_FILTER="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

# 收集 done 卡
done_cards=()
for tf in "$ENGINE_DIR"/tasks/T-*.md; do
  [ -f "$tf" ] || continue
  tid="$(basename "$tf" .md)"
  # 单卡过滤
  if [ -n "$TASK_FILTER" ] && [ "$tid" != "$TASK_FILTER" ]; then continue; fi
  # 检查 status:done(行首锚定)
  if grep -qE '^>.*status:[[:space:]]*done' "$tf"; then
    done_cards+=("$tid")
  fi
done

if [ ${#done_cards[@]} -eq 0 ]; then
  echo "[drift-check] 无 done 卡,跳过"
  exit 0
fi

drift_count=0
tamper_count=0
warn_count=0

for tid in "${done_cards[@]}"; do
  ev_dir="$ENGINE_DIR/evidence/$tid"
  [ -d "$ev_dir" ] || { echo "WARN: $tid done 但 evidence 目录不存在"; warn_count=$((warn_count+1)); continue; }
  task_file="$ENGINE_DIR/tasks/$tid.md"

  echo "── $tid ──"

  # ========== 步骤 1: 完整性自证 ==========
  manifest_file="$ev_dir/MANIFEST.json"
  step1_fail=0
  legacy_evidence=0

  if [ ! -f "$manifest_file" ]; then
    # v6.18.0 (D-038d 迁移期): legacy evidence 没有 MANIFEST.json。区分两种情况:
    #   (a) AC-*.json 也不含 write_provenance 字段 → 真·legacy,迁移期 WARN,跳过
    #   (b) AC-*.json 含 write_provenance 但 MANIFEST 缺失 → MANIFEST 被删,FAIL tamper
    first_ac_for_legacy="$(cd "$ev_dir" && ls AC-*.json 2>/dev/null | LC_ALL=C sort | head -1)"
    if [ -n "$first_ac_for_legacy" ] && ! grep -q '"write_provenance"' "$ev_dir/$first_ac_for_legacy" 2>/dev/null; then
      echo "  WARN step1: legacy evidence (no MANIFEST, no write_provenance) - 迁移期跳过,信任级 T2"
      warn_count=$((warn_count+1))
      legacy_evidence=1
    else
      echo "  FAIL step1: MANIFEST.json 不存在(有 write_provenance 但 MANIFEST 缺失 - 疑似篡改)"
      tamper_count=$((tamper_count+1))
      step1_fail=1
    fi
  else
    # 重算 manifest 聚合 hash 并比对
    manifest_content=""
    for f in $(cd "$ev_dir" && find . -maxdepth 1 -type f \( -name '*.json' -o -name 'checkpoint.md' \) ! -name 'MANIFEST.json' 2>/dev/null | sed 's|^\./||' | LC_ALL=C sort); do
      fhash="$(sha256sum "$ev_dir/$f" | cut -d' ' -f1)"
      manifest_content+="${f}:${fhash}"$'\n'
    done
    recomputed_hash="$(printf '%s' "$manifest_content" | sha256sum | cut -d' ' -f1)"
    stored_hash="$(grep -oE '"evidence_manifest_sha256":"sha256:[^"]*"' "$manifest_file" | sed 's/.*sha256://;s/"//')"
    if [ "$recomputed_hash" != "$stored_hash" ]; then
      echo "  FAIL step1: evidence tampered (manifest mismatch: stored=${stored_hash:0:12}.. recomputed=${recomputed_hash:0:12}..)"
      tamper_count=$((tamper_count+1))
      step1_fail=1
    fi

    # 校验 write_provenance
    head_commit="$(cd "$ROOT" && git rev-parse HEAD 2>/dev/null || echo "unknown")"
    prov_writer="$(grep -oE '"writer":"[^"]*"' "$manifest_file" | sed 's/"writer":"//;s/"//')"
    prov_commit="$(grep -oE '"commit":"[^"]*"' "$manifest_file" | head -1 | sed 's/"commit":"//;s/"//')"
    if [ "$prov_writer" != "engine-verify" ]; then
      echo "  FAIL step1: invalid provenance.writer (expected engine-verify, got $prov_writer)"
      tamper_count=$((tamper_count+1))
      step1_fail=1
    fi
    if [ "$prov_commit" != "$head_commit" ]; then
      echo "  FAIL step1: provenance.commit mismatch (expected HEAD=$head_commit, got $prov_commit)"
      tamper_count=$((tamper_count+1))
      step1_fail=1
    fi
  fi

  if [ $step1_fail -eq 1 ]; then
    echo "  (step1 FAIL,后续步骤标 unverified)"
  elif [ $legacy_evidence -eq 1 ]; then
    echo "  (legacy evidence,后续步骤 SKIP)"
  else
    echo "  OK   step1: manifest + provenance 校验通过"
  fi

  # ========== 步骤 2: WRITE-SET 二阶检测 ==========
  if [ $step1_fail -eq 1 ]; then
    echo "  SKIP step2: (unverified - manifest 失败)"
  elif [ $legacy_evidence -eq 1 ]; then
    echo "  SKIP step2: (legacy evidence - 迁移期跳过)"
  else
    # 从第一个 AC evidence 读 write_set_snapshot
    first_ac_ev="$(cd "$ev_dir" && ls AC-*.json 2>/dev/null | LC_ALL=C sort | head -1)"
    if [ -z "$first_ac_ev" ]; then
      echo "  WARN step2: 无 AC-*.json,跳过 WRITE-SET 检测"
      warn_count=$((warn_count+1))
    else
      # 提取 snapshot(JSON 数组)
      snapshot_json="$(grep -oE '"write_set_snapshot":\[[^]]*\]' "$ev_dir/$first_ac_ev" | sed 's/.*://')"
      # 解析当前任务卡 WRITE-SET
      current_ws=""
      in_ws=0
      while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
          "## WRITE-SET") in_ws=1; continue ;;
          "## "*) [ "$in_ws" = "1" ] && break ;;
        esac
        [ "$in_ws" = "1" ] || continue
        [[ "$line" =~ ^-[[:space:]]+([^[:space:]].+) ]] || continue
        path="${BASH_REMATCH[1]}"
        # 与 verify 一致的元数据过滤
        case "$path" in
          engine/tasks/*|engine/decisions/*|engine/changes/*|engine/evidence/*|engine/domains/*|engine/archive/*) continue ;;
          engine/CONTEXT.md|engine/HANDOFF.md|engine/ENGINE_MAP.md|engine/handoff-archive-*) continue ;;
          VERSION|engine/VERSION|plugin/VERSION|plugin/manifest.json|CHANGELOG.md) continue ;;
        esac
        [ -f "$ROOT/$path" ] || continue
        current_ws+="$path"$'\n'
      done < "$task_file"
      # 比对(snapshot vs current,只比代码文件)
      snapshot_paths="$(printf '%s' "$snapshot_json" | tr ',' '\n' | sed 's/[][]//g;s/"//g' | LC_ALL=C sort)"
      current_paths="$(printf '%s' "$current_ws" | LC_ALL=C sort)"
      added="$(comm -13 <(printf '%s' "$snapshot_paths") <(printf '%s' "$current_paths"))"
      removed="$(comm -23 <(printf '%s' "$snapshot_paths") <(printf '%s' "$current_paths"))"
      if [ -n "$added" ] || [ -n "$removed" ]; then
        echo "  WARN step2: WRITE-SET changed since evidence"
        [ -n "$added" ] && echo "    added: $(echo "$added" | tr '\n' ' ')"
        [ -n "$removed" ] && echo "    removed: $(echo "$removed" | tr '\n' ' ')"
        warn_count=$((warn_count+1))
      else
        echo "  OK   step2: WRITE-SET 无变化"
      fi
    fi
  fi

  # ========== 步骤 3: 代码指纹比对 ==========
  if [ $step1_fail -eq 1 ]; then
    echo "  SKIP step3: (unverified - manifest 失败)"
  elif [ $legacy_evidence -eq 1 ]; then
    echo "  SKIP step3: (legacy evidence - 迁移期跳过)"
  else
    first_ac_ev="$(cd "$ev_dir" && ls AC-*.json 2>/dev/null | LC_ALL=C sort | head -1)"
    if [ -z "$first_ac_ev" ]; then
      echo "  WARN step3: 无 AC-*.json,跳过代码指纹比对"
    else
      # 提取 code_fingerprint 字典(path -> blob_sha)
      cf_json="$(grep -oE '"code_fingerprint":\{[^}]*\}' "$ev_dir/$first_ac_ev" | sed 's/"code_fingerprint"://')"
      had_drift=0
      # 逐个文件比对
      while IFS= read -r pair; do
        [ -n "$pair" ] || continue
        # pair shape: {"path":"sha"} or "path":"sha" — use awk -F'"' for
        # reliable extraction. cut/sed left a trailing '}' on stored_sha
        # when the JSON object had no comma (single-entry case).
        path="$(printf '%s' "$pair" | awk -F'"' '{print $2}')"
        stored_sha="$(printf '%s' "$pair" | awk -F'"' '{print $4}')"
        current_sha="$(cd "$ROOT" && git ls-files -s "$path" 2>/dev/null | awk '{print $2}')"
        if [ -z "$current_sha" ]; then
          echo "  DRIFT step3: $tid file deleted (path: $path)"
          drift_count=$((drift_count+1))
          had_drift=1
        elif [ "$current_sha" != "$stored_sha" ]; then
          echo "  DRIFT step3: $tid code changed ($path: stored=${stored_sha:0:12}.. current=${current_sha:0:12}..)"
          drift_count=$((drift_count+1))
          had_drift=1
        fi
      done < <(printf '%s' "$cf_json" | tr ',' '\n' | grep '"')
      if [ $had_drift -eq 0 ]; then
        echo "  OK   step3: 代码指纹一致"
      fi
    fi
  fi
done

echo ""
echo "【drift-check 汇总】tamper=$tamper_count drift=$drift_count warn=$warn_count"
if [ $tamper_count -gt 0 ]; then
  exit 1
elif [ $drift_count -gt 0 ]; then
  exit 1
else
  exit 0
fi
