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
  # 检查 status:done(与 Doctor 相同的可选 frontmatter 引导符)
  if grep -qE '^[[:space:]]*(>[[:space:]]*)?status:[[:space:]]*done([[:space:]]|$)' "$tf"; then
    done_cards+=("$tid")
  fi
done

if [ ${#done_cards[@]} -eq 0 ]; then
  echo "[drift-check] 无 done 卡,跳过"
  exit 0
fi

first_ac_file() {
  local evidence_dir="$1" candidate
  for candidate in "$evidence_dir"/AC-*.json; do
    [ -f "$candidate" ] || continue
    printf '%s' "${candidate##*/}"
    return 0
  done
  return 0
}

manifest_hash_re='"evidence_manifest_sha256":"sha256:([^"]*)"'
writer_re='"writer":"([^"]*)"'
commit_re='"commit":"([^"]*)"'
snapshot_re='"write_set_snapshot":\[([^]]*)\]'
fingerprint_object_re='"code_fingerprint":\{([^}]*)\}'
fingerprint_pair_re='"([^"]+)":"([^"]+)"'

drift_count=0
tamper_count=0
warn_count=0

# Snapshot the index once. The old per-fingerprint `git ls-files -s` call made
# a full historical scan pay Git Bash process-startup cost for every file on
# every done card (especially expensive on Windows). The cache preserves the
# exact index-blob comparison while making it one Git invocation per scan.
declare -A git_blob_cache=()
declare -A git_commit_exists_cache=()
declare -A head_task_done_cache=()
head_commit="unknown"
if command -v git >/dev/null 2>&1; then
  head_commit="$(cd "$ROOT" && git rev-parse HEAD 2>/dev/null || echo "unknown")"
  while IFS= read -r git_record; do
    git_rest="${git_record#* }"
    git_sha="${git_rest%% *}"
    git_rest="${git_rest#* }"
    git_path="${git_rest#*$'\t'}"
    [ -n "$git_path" ] || continue
    git_blob_cache["$git_path"]="$git_sha"
  done < <(cd "$ROOT" && git ls-files -s 2>/dev/null)
  while IFS=: read -r _ head_task_path _ _; do
    [ -n "$head_task_path" ] || continue
    head_task_name="${head_task_path##*/}"
    head_task_name="${head_task_name%.md}"
    head_task_done_cache["$head_task_name"]=1
  done < <(git -C "$ROOT" grep -n -E '^[[:space:]]*(>[[:space:]]*)?status:[[:space:]]*done' HEAD -- 'engine/tasks/T-*.md' 2>/dev/null || true)
fi

git_commit_exists() {
  local commit="$1" result
  if [[ -n "${git_commit_exists_cache[$commit]+present}" ]]; then
    [[ "${git_commit_exists_cache[$commit]}" == "1" ]]
    return
  fi
  if (cd "$ROOT" && git cat-file -e "$commit^{commit}" 2>/dev/null); then
    result=1
  else
    result=0
  fi
  git_commit_exists_cache["$commit"]="$result"
  [[ "$result" == "1" ]]
}

head_task_was_done() {
  local tid="$1"
  [[ -n "${head_task_done_cache[$tid]+present}" ]]
}

for tid in "${done_cards[@]}"; do
  ev_dir="$ENGINE_DIR/evidence/$tid"
  [ -d "$ev_dir" ] || { echo "WARN: $tid done 但 evidence 目录不存在"; warn_count=$((warn_count+1)); continue; }
  task_file="$ENGINE_DIR/tasks/$tid.md"

  echo "── $tid ──"

  # ========== 步骤 1: 完整性自证 ==========
  manifest_file="$ev_dir/MANIFEST.json"
  step1_fail=0
  legacy_evidence=0
  historical_snapshot=0

  if [ ! -f "$manifest_file" ]; then
    # v6.18.0 (D-038d 迁移期): legacy evidence 没有 MANIFEST.json。区分两种情况:
    #   (a) AC-*.json 也不含 write_provenance 字段 → 真·legacy,迁移期 WARN,跳过
    #   (b) AC-*.json 含 write_provenance 但 MANIFEST 缺失 → MANIFEST 被删,FAIL tamper
    first_ac_for_legacy="$(first_ac_file "$ev_dir")"
    if [ -z "$first_ac_for_legacy" ]; then
      echo "  WARN step1: legacy evidence (no MANIFEST, no AC evidence) - 迁移期跳过,信任级 T2"
      warn_count=$((warn_count+1))
      legacy_evidence=1
    elif ! grep -q '"write_provenance"' "$ev_dir/$first_ac_for_legacy" 2>/dev/null; then
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
    manifest_files=()
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      manifest_files+=("$ev_dir/$f")
    done < <(cd "$ev_dir" && find . -maxdepth 1 -type f \( -name '*.json' -o -name 'checkpoint.md' \) ! -name 'MANIFEST.json' -printf '%f\n' 2>/dev/null | LC_ALL=C sort)
    if [ "${#manifest_files[@]}" -gt 0 ]; then
      # Hash all files in one sha256sum invocation. Evidence filenames are
      # generated AC-NNN/MANIFEST/checkpoint names, so the output path has no
      # whitespace and can be safely reduced to its basename in-process.
      while read -r fhash fpath; do
        [ -n "$fpath" ] || continue
        fpath="${fpath##*/}"
        manifest_content+="${fpath}:${fhash}"$'\n'
      done < <(sha256sum "${manifest_files[@]}")
    fi
    read -r recomputed_hash _ < <(printf '%s' "$manifest_content" | sha256sum)
    manifest_text="$(<"$manifest_file")"
    stored_hash=""
    if [[ "$manifest_text" =~ $manifest_hash_re ]]; then
      stored_hash="${BASH_REMATCH[1]}"
    fi
    if [ "$recomputed_hash" != "$stored_hash" ]; then
      echo "  FAIL step1: evidence tampered (manifest mismatch: stored=${stored_hash:0:12}.. recomputed=${recomputed_hash:0:12}..)"
      tamper_count=$((tamper_count+1))
      step1_fail=1
    fi

    # 校验 write_provenance
    prov_writer=""
    prov_commit=""
    if [[ "$manifest_text" =~ $writer_re ]]; then
      prov_writer="${BASH_REMATCH[1]}"
    fi
    if [[ "$manifest_text" =~ $commit_re ]]; then
      prov_commit="${BASH_REMATCH[1]}"
    fi
    # Verify and prove both write the task manifest during their lifecycle
    # stages; accept only these two engine-owned writers.
    if [ "$prov_writer" != "engine-verify" ] && [ "$prov_writer" != "engine-prove" ]; then
      echo "  FAIL step1: invalid provenance.writer (expected engine-verify or engine-prove, got $prov_writer)"
      tamper_count=$((tamper_count+1))
      step1_fail=1
    fi
    if [ -z "$prov_commit" ]; then
      echo "  FAIL step1: provenance.commit missing"
      tamper_count=$((tamper_count+1))
      step1_fail=1
    elif ! git_commit_exists "$prov_commit"; then
      # Old done cards may point at commits from short-lived worker branches
      # that are no longer advertised by the remote. That is historical
      # provenance loss, not evidence mutation; keep it visible as T2 WARN.
      # A card that was not done in HEAD remains a hard failure.
      if head_task_was_done "$tid"; then
        echo "  WARN step1: legacy evidence provenance.commit mismatch (unreachable historical commit; got $prov_commit)"
        warn_count=$((warn_count+1))
        historical_snapshot=1
      else
        echo "  FAIL step1: provenance.commit mismatch (not a reachable commit; got $prov_commit)"
        tamper_count=$((tamper_count+1))
        step1_fail=1
      fi
    elif [ "$prov_commit" != "$head_commit" ]; then
      # A done card can legitimately retain evidence generated at the commit
      # immediately before its status transition, or at an older historical
      # commit. The manifest has already self-verified, so report this as an
      # explicit legacy snapshot warning while keeping code-fingerprint drift
      # visible below. A current active/newly-done card remains a hard failure.
      if head_task_was_done "$tid"; then
        echo "  WARN step1: legacy evidence provenance.commit mismatch (HEAD=$head_commit, snapshot=$prov_commit)"
        warn_count=$((warn_count+1))
        historical_snapshot=1
      else
        echo "  FAIL step1: provenance.commit mismatch (expected HEAD=$head_commit, got $prov_commit)"
        tamper_count=$((tamper_count+1))
        step1_fail=1
      fi
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
    first_ac_ev="$(first_ac_file "$ev_dir")"
    if [ -z "$first_ac_ev" ]; then
      echo "  WARN step2: 无 AC-*.json,跳过 WRITE-SET 检测"
      warn_count=$((warn_count+1))
    else
      # 提取 snapshot(JSON 数组)
      ac_content="$(<"$ev_dir/$first_ac_ev")"
      snapshot_json=""
      if [[ "$ac_content" =~ $snapshot_re ]]; then
        snapshot_json="[${BASH_REMATCH[1]}]"
      fi
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
          engine/tasks/*|engine/decisions/*|engine/changes/*|engine/evidence/*|engine/review/evidence/*|engine/domains/*|engine/archive/*) continue ;;
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
    first_ac_ev="$(first_ac_file "$ev_dir")"
    if [ -z "$first_ac_ev" ]; then
      echo "  WARN step3: 无 AC-*.json,跳过代码指纹比对"
    else
      # 提取 code_fingerprint 字典(path -> blob_sha)
      ac_content="$(<"$ev_dir/$first_ac_ev")"
      cf_json=""
      if [[ "$ac_content" =~ $fingerprint_object_re ]]; then
        cf_json="{${BASH_REMATCH[1]}}"
      fi
      had_drift=0
      # 逐个文件比对
      cf_body="${cf_json#\{}"; cf_body="${cf_body%\}}"
      IFS=',' read -r -a cf_pairs <<< "$cf_body"
      for pair in "${cf_pairs[@]}"; do
        [ -n "$pair" ] || continue
        if [[ "$pair" =~ $fingerprint_pair_re ]]; then
          path="${BASH_REMATCH[1]}"
          stored_sha="${BASH_REMATCH[2]}"
        else
          continue
        fi
        # WRITE-SET globs are metadata coverage, not concrete code files.
        # They are integrity-checked by MANIFEST; never report a glob as a
        # deleted code file during the fingerprint pass.
        [[ "$path" == *"*"* || "$path" == *"?"* ]] && continue
        current_sha="${git_blob_cache[$path]-}"
        if [ -z "$current_sha" ]; then
          if [ "$historical_snapshot" -eq 1 ]; then
            echo "  WARN legacy step3: $tid file deleted after evidence snapshot (path: $path)"
            warn_count=$((warn_count+1))
          else
            echo "  DRIFT step3: $tid file deleted (path: $path)"
            drift_count=$((drift_count+1))
          fi
          had_drift=1
        elif [ "$current_sha" != "$stored_sha" ]; then
          if [ "$historical_snapshot" -eq 1 ]; then
            echo "  WARN legacy step3: $tid code changed after evidence snapshot ($path: stored=${stored_sha:0:12}.. current=${current_sha:0:12}..)"
            warn_count=$((warn_count+1))
          else
            echo "  DRIFT step3: $tid code changed ($path: stored=${stored_sha:0:12}.. current=${current_sha:0:12}..)"
            drift_count=$((drift_count+1))
          fi
          had_drift=1
        fi
      done
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
