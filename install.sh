#!/usr/bin/env bash
# Engine System installer
# Usage: bash <(curl -sSL https://raw.githubusercontent.com/elysiayunchen/engine_system/main/install.sh)
# Or:    bash install.sh [--update]

set -euo pipefail
INSTALL_SCRIPT="install.sh"
on_error() { echo "[${INSTALL_SCRIPT}] error on line $1" >&2; exit 1; }
trap 'on_error ${LINENO}' ERR

REPO="elysiayunchen/engine_system"
BRANCH="main"
PLUGIN_DIR="plugin"
UPDATE_MODE=false
VERSION_TAG=""
LOCAL_PATH=""
LOCAL_DIR=""

# Parse flags
while [[ $# -gt 0 ]]; do
  case $1 in
    --update) UPDATE_MODE=true; shift ;;
    --version)
      VERSION_TAG="$2"
      # Normalize: strip leading 'v' if present for internal use
      VERSION_TAG="${VERSION_TAG#v}"
      shift 2
      ;;
    --local)
      LOCAL_PATH="$2"
      # Extract tarball to temp dir if it's a file
      if [[ -f "$LOCAL_PATH" ]]; then
        LOCAL_DIR="$(mktemp -d)"
        tar xzf "$LOCAL_PATH" -C "$LOCAL_DIR"
        echo -e "  Extracted offline package: $LOCAL_PATH"
      elif [[ -d "$LOCAL_PATH" ]]; then
        LOCAL_DIR="$LOCAL_PATH"
      else
        echo "Error: --local path not found: $LOCAL_PATH" >&2
        exit 1
      fi
      shift 2
      ;;
    --help|-h)
      echo "Usage: bash install.sh [--update] [--version TAG] [--local PATH]"
      echo ""
      echo "Options:"
      echo "  --update         Update mode: overwrite tooling, preserve engine/*.md"
      echo "  --version TAG    Install a specific version (e.g. --version 6.0.1)"
      echo "                   Tries GitHub Release first, falls back to raw content"
      echo "  --local PATH     Install from local tarball or directory (no network)"
      echo "  --help, -h       Show this help"
      exit 0
      ;;
    *) echo "Unknown option: $1 (try --help)" >&2; exit 1 ;;
  esac
done

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
RESET='\033[0m'

echo ""
echo -e "${CYAN}Engine System installer${RESET}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check for required tools
if ! command -v curl &>/dev/null && ! command -v wget &>/dev/null; then
  echo "Error: curl or wget is required." >&2
  exit 1
fi

# Decide download method
download() {
  local url="$1" dest="$2"
  if command -v curl &>/dev/null; then
    curl -sSL "$url" -o "$dest"
  else
    wget -qO "$dest" "$url"
  fi
}

# Download with release-first fallback (when --version is specified)
download_versioned() {
  local src="$1" dest="$2"
  local release_url="https://github.com/${REPO}/releases/download/v${VERSION_TAG}/${PLUGIN_DIR}/${src}"
  local raw_url="${BASE_URL}/${src}"

  if command -v curl &>/dev/null; then
    local http_code
    http_code=$(curl -sSL -w "%{http_code}" -o "$dest" "$release_url" 2>/dev/null || echo "000")
    if [[ "$http_code" == "200" ]]; then
      return 0
    fi
    # Release artifact not found — fallback to raw content
    curl -sSL "$raw_url" -o "$dest"
  else
    if wget -q --spider "$release_url" 2>/dev/null; then
      wget -qO "$dest" "$release_url"
    else
      wget -qO "$dest" "$raw_url"
    fi
  fi
}

# Verify SHA256 checksums against manifest (hard-fail on mismatch)
verify_checksums() {
  local manifest_file="$1"
  local verify_count=0
  local fail_count=0
  local failed_files=""
  local skipped_count=0

  [[ -f "$manifest_file" ]] || return 0

  # Read src list with process substitution to avoid subshell scope loss
  local srcs=()
  while IFS= read -r line; do
    srcs+=("$(echo "$line" | sed 's/.*"src"\s*:\s*"\([^"]*\)".*/\1/')")
  done < <(grep -oE '"src"\s*:\s*"[^"]*"' "$manifest_file")

  for src in "${srcs[@]}"; do
    [[ -z "$src" ]] && continue

    local sha256
    sha256="$(grep "\"$src\"" "$manifest_file" | grep -oE '"sha256"\s*:\s*"[^"]*"' | head -1 | sed 's/.*"sha256"\s*:\s*"\([^"]*\)".*/\1/')"
    if [[ -z "$sha256" || "$sha256" == "placeholder" ]]; then
      skipped_count=$((skipped_count + 1))
      echo -e "  ${YELLOW}NOTE${RESET} checksum skipped: $src (no sha256)"
      continue
    fi

    # Map src to dest (same mapping as FILES array)
    local dest_file
    case "$src" in
      engine/*) dest_file="engine/${src#engine/}" ;;
      bin/*)    dest_file="engine/bin/${src#bin/}" ;;
      migrations/*) dest_file="engine/migrations/${src#migrations/}" ;;
      *)        dest_file="$src" ;;
    esac

    # .claude/settings.json is generated/modified by the installer post-download;
    # its on-disk bytes will not match the manifest hash.
    [[ "$dest_file" == ".claude/settings.json" ]] && continue

    [[ -f "$dest_file" ]] || continue

    local actual=""
    if command -v sha256sum &>/dev/null; then
      actual="$(sha256sum "$dest_file" | cut -d' ' -f1)"
    elif command -v shasum &>/dev/null; then
      actual="$(shasum -a 256 "$dest_file" | cut -d' ' -f1)"
    fi
    [[ -z "$actual" ]] && continue

    verify_count=$((verify_count + 1))
    if [[ "$actual" != "$sha256" ]]; then
      echo -e "  ${RED}FAIL${RESET} checksum mismatch: $dest_file (expected ${sha256:0:8}... got ${actual:0:8}...)"
      fail_count=$((fail_count + 1))
      failed_files="$failed_files $dest_file"
    fi
  done

  if [[ "$fail_count" -gt 0 ]]; then
    echo -e "  ${RED}FAIL${RESET} $fail_count file(s) failed checksum verification:$failed_files"
    return 1
  elif [[ "$verify_count" -gt 0 ]]; then
    echo -e "  ${GREEN}✓${RESET} $verify_count file(s) verified (SHA256)"
  else
    echo -e "  ${YELLOW}NOTE${RESET} checksum verification skipped (no verifiable file pairs found)"
  fi
}

# Build BASE_URL — use specified version tag or default branch
if [[ -n "$VERSION_TAG" ]]; then
  BASE_URL="https://raw.githubusercontent.com/${REPO}/v${VERSION_TAG}/${PLUGIN_DIR}"
  echo -e "  Installing version: ${CYAN}v${VERSION_TAG}${RESET}"
else
  BASE_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/${PLUGIN_DIR}"
fi

# Files to install
# Format: "source_path:dest_path:protect_on_update"
FILES=(
  ".claude/commands/engine-init.md:.claude/commands/engine-init.md:true"
  ".claude/commands/engine-update.md:.claude/commands/engine-update.md:true"
  ".claude/commands/engine-status.md:.claude/commands/engine-status.md:true"
  ".claude/commands/add-pitfall.md:.claude/commands/add-pitfall.md:true"
  ".claude/commands/engine-ingest.md:.claude/commands/engine-ingest.md:true"
  ".claude/commands/engine-extend.md:.claude/commands/engine-extend.md:true"
  ".claude/commands/engine-doctor.md:.claude/commands/engine-doctor.md:true"
  ".claude/commands/engine-sync.md:.claude/commands/engine-sync.md:true"
  ".claude/commands/engine-reconcile.md:.claude/commands/engine-reconcile.md:true"
  "CLAUDE.md:CLAUDE.md:true"
  "AGENTS.md:AGENTS.md:true"
  "engine/README.md:engine/README.md:false"
  "engine/README.zh.md:engine/README.zh.md:false"
  "engine/ENGINE_DOCTOR.md:engine/ENGINE_DOCTOR.md:false"
  "engine/prompts/init.md:engine/prompts/init.md:true"
  "engine/scripts/engine-doctor.sh:engine/scripts/engine-doctor.sh:true"
  "engine/scripts/engine-doctor.ps1:engine/scripts/engine-doctor.ps1:true"
  "engine/scripts/engine-hook-session-start.sh:engine/scripts/engine-hook-session-start.sh:true"
  "engine/scripts/engine-hook-session-start.ps1:engine/scripts/engine-hook-session-start.ps1:true"
  "engine/scripts/engine-hook-stop.sh:engine/scripts/engine-hook-stop.sh:true"
  "engine/scripts/engine-hook-stop.ps1:engine/scripts/engine-hook-stop.ps1:true"
  "engine/scripts/engine-hook-session-end.sh:engine/scripts/engine-hook-session-end.sh:true"
  "engine/scripts/engine-hook-session-end.ps1:engine/scripts/engine-hook-session-end.ps1:true"
  "engine/scripts/engine-hook.cmd:engine/scripts/engine-hook.cmd:true"
  "engine/scripts/engine-sync-agent-anchors.sh:engine/scripts/engine-sync-agent-anchors.sh:true"
  "engine/scripts/engine-sync-agent-anchors.ps1:engine/scripts/engine-sync-agent-anchors.ps1:true"
  "engine/scripts/engine-migrate-contract.sh:engine/scripts/engine-migrate-contract.sh:true"
  "engine/scripts/engine-migrate-contract.ps1:engine/scripts/engine-migrate-contract.ps1:true"
  "engine/scripts/engine-verify.sh:engine/scripts/engine-verify.sh:true"
  "engine/scripts/engine-verify.ps1:engine/scripts/engine-verify.ps1:true"
  "engine/scripts/githooks/pre-commit:engine/scripts/githooks/pre-commit:true"
  "bin/engine:engine/bin/engine:true"
  "bin/engine.ps1:engine/bin/engine.ps1:true"
  "bin/engine.cmd:engine/bin/engine.cmd:true"
  "VERSION:engine/VERSION:true"
  "engine/scripts/engine-check-update.sh:engine/scripts/engine-check-update.sh:true"
  "engine/scripts/engine-check-update.ps1:engine/scripts/engine-check-update.ps1:true"
  "migrations/v6.0.sh:engine/migrations/v6.0.sh:true"
  "migrations/v6.0.ps1:engine/migrations/v6.0.ps1:true"
  "engine/skeleton/ENGINE_MAP.md:engine/ENGINE_MAP.md:false"
  "engine/skeleton/CONTEXT.md:engine/CONTEXT.md:false"
  "engine/skeleton/HANDOFF.md:engine/HANDOFF.md:false"
  ".claude/settings.json:.claude/settings.json:false"
)

# Create directories
mkdir -p .claude/commands engine engine/scripts engine/scripts/githooks engine/bin engine/migrations engine/prompts engine/.cache

install_count=0
skip_count=0

for entry in "${FILES[@]}"; do
  IFS=':' read -r src dest protect <<< "$entry"
  url="${BASE_URL}/${src}"

  # Root anchor files (CLAUDE.md / AGENTS.md): never clobber an existing one, in any mode.
  # .claude/settings.json: same rule — don't overwrite an existing one.
  # A brand-new project gets the starter bootloader; an existing file is preserved so that
  # /engine-init can absorb its rules first, and /engine-reconcile keeps it in sync after.
  if { [[ "$dest" == "CLAUDE.md" ]] || [[ "$dest" == "AGENTS.md" ]] || [[ "$dest" == ".claude/settings.json" ]]; } && [[ -f "$dest" ]]; then
    echo -e "  ${YELLOW}keep${RESET}  $dest (已存在，保留；运行 /engine-sync 合并 hooks 字段)"
    ((skip_count += 1))
    continue
  fi

  # In update mode, skip protected files if they already exist
  if $UPDATE_MODE && [[ "$protect" == "false" ]] && [[ -f "$dest" ]]; then
    echo -e "  ${YELLOW}skip${RESET}  $dest (user data, not overwritten)"
    ((skip_count += 1))
    continue
  fi

  # In update mode, always overwrite plugin files (commands, CLAUDE.md, AGENTS.md)
  if $UPDATE_MODE && [[ "$protect" == "true" ]]; then
    if [[ -n "$LOCAL_DIR" ]]; then
      cp "$LOCAL_DIR/$src" "$dest"
      [[ -s "$dest" ]] || { echo -e "  ${RED}FAIL${RESET} $dest (copy failed, file empty or missing)" >&2; exit 1; }
    elif [[ -n "$VERSION_TAG" ]]; then
      download_versioned "$src" "$dest"
      [[ -s "$dest" ]] || { echo -e "  ${RED}FAIL${RESET} $dest (download failed, file empty or missing)" >&2; exit 1; }
    else
      download "$url" "$dest"
      [[ -s "$dest" ]] || { echo -e "  ${RED}FAIL${RESET} $dest (download failed, file empty or missing)" >&2; exit 1; }
    fi
    echo -e "  ${GREEN}updated${RESET} $dest"
    ((install_count += 1))
    continue
  fi

  # Fresh install: don't overwrite existing user engine files
  if [[ -f "$dest" ]] && [[ "$dest" == engine/*.md ]] && [[ "$dest" != "engine/README.md" ]]; then
    echo -e "  ${YELLOW}skip${RESET}  $dest (already exists)"
    ((skip_count += 1))
    continue
  fi

  if [[ -n "$LOCAL_DIR" ]]; then
    cp "$LOCAL_DIR/$src" "$dest"
    [[ -s "$dest" ]] || { echo -e "  ${RED}FAIL${RESET} $dest (copy failed, file empty or missing)" >&2; exit 1; }
  elif [[ -n "$VERSION_TAG" ]]; then
    download_versioned "$src" "$dest"
    [[ -s "$dest" ]] || { echo -e "  ${RED}FAIL${RESET} $dest (download failed, file empty or missing)" >&2; exit 1; }
  else
    download "$url" "$dest"
    [[ -s "$dest" ]] || { echo -e "  ${RED}FAIL${RESET} $dest (download failed, file empty or missing)" >&2; exit 1; }
  fi
  echo -e "  ${GREEN}✓${RESET} $dest"
  ((install_count += 1))
done

# Install CLI shims to user PATH. On Windows, bash/ps1/cmd all get copied so
# the command works from Git Bash, PowerShell, and CMD alike.
cli_src="engine/bin/engine"
cli_dest="${HOME:-}/.local/bin/engine"
if [[ -n "${HOME:-}" && -f "$cli_src" ]]; then
  mkdir -p "$(dirname "$cli_dest")"
  cp "$cli_src" "$cli_dest"
  chmod +x "$cli_dest" 2>/dev/null || true
  echo -e "  ${GREEN}✓${RESET} $cli_dest (CLI: engine)"
  ((install_count += 1))
  # Windows companions: .cmd (dispatcher) + .ps1 (powershell script)
  for ext in cmd ps1; do
    if [[ -f "${cli_src}.${ext}" ]]; then
      cp "${cli_src}.${ext}" "${cli_dest}.${ext}"
      echo -e "  ${GREEN}✓${RESET} ${cli_dest}.${ext}"
      ((install_count += 1))
    fi
  done
  case ":$PATH:" in
    *":$(dirname "$cli_dest"):"*) ;;
    *) echo -e "  ${YELLOW}note${RESET} add $(dirname "$cli_dest") to PATH to run: engine update" ;;
  esac
fi

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git_dir="$(git rev-parse --git-dir 2>/dev/null || true)"
  if [[ -n "$git_dir" ]]; then
    mkdir -p "$git_dir/hooks"
    if [[ -f "$git_dir/hooks/pre-commit" ]]; then
      echo -e "  ${YELLOW}keep${RESET}  $git_dir/hooks/pre-commit (已存在；如需 B 层门禁，请手动合并 engine/scripts/githooks/pre-commit)"
      ((skip_count += 1))
    elif [[ -f "engine/scripts/githooks/pre-commit" ]]; then
      cp "engine/scripts/githooks/pre-commit" "$git_dir/hooks/pre-commit"
      chmod +x "$git_dir/hooks/pre-commit" 2>/dev/null || true
      echo -e "  ${GREEN}✓${RESET} $git_dir/hooks/pre-commit"
      ((install_count += 1))
    fi
  fi
fi

# Windows(MINGW/MSYS/Cygwin):Claude Code 用 cmd.exe 执行 hooks,而 Git for Windows
# 默认只把 Git\cmd(git.exe)加进系统 PATH——`bash` 在 cmd 里经常找不到,C 层会静默哑火。
# 把 hook 命令换成 engine-hook.cmd 调度垫片:垫片仍优先找 bash(行为与 Unix 完全一致),
# 找不到才退 PowerShell 孪生实现。只改写本安装器铺设的命令形态,不碰用户自定义 hooks。
case "$(uname -s 2>/dev/null)" in
  MINGW*|MSYS*|CYGWIN*)
    if [[ -f .claude/settings.json ]] && grep -q 'bash engine/scripts/engine-hook-' .claude/settings.json; then
      sed -i.engine-bak \
        -e 's|bash engine/scripts/engine-hook-session-start\.sh|engine\\\\scripts\\\\engine-hook.cmd session-start|' \
        -e 's|bash engine/scripts/engine-hook-stop\.sh|engine\\\\scripts\\\\engine-hook.cmd stop|' \
        -e 's|bash engine/scripts/engine-hook-session-end\.sh|engine\\\\scripts\\\\engine-hook.cmd session-end|' \
        .claude/settings.json && rm -f .claude/settings.json.engine-bak
      echo -e "  ${GREEN}✓${RESET} .claude/settings.json (Windows: hooks 改经 engine-hook.cmd 调度垫片)"
    fi
    ;;
esac

# L0 宪法 (runtime-law.md): session-start hook 注入前 40 行对抗漂移。
# 从仓库根拉取(contract compile 产物),放项目根。fresh + update 都覆盖(引擎产物,非项目记忆)。
if [[ -n "$LOCAL_DIR" ]] && [[ -f "$LOCAL_DIR/runtime-law.md" ]]; then
  cp "$LOCAL_DIR/runtime-law.md" "runtime-law.md"
elif [[ -n "$VERSION_TAG" ]]; then
  download "https://raw.githubusercontent.com/${REPO}/v${VERSION_TAG}/runtime-law.md" "runtime-law.md"
else
  download "https://raw.githubusercontent.com/${REPO}/${BRANCH}/runtime-law.md" "runtime-law.md"
fi
echo -e "  ${GREEN}✓${RESET} runtime-law.md (L0 constitution)"

# Verify SHA256 checksums (hard-fail on mismatch; only when --version is specified, skip for --local)
if [[ -n "$VERSION_TAG" ]] && [[ -z "$LOCAL_DIR" ]]; then
  download "https://raw.githubusercontent.com/${REPO}/v${VERSION_TAG}/${PLUGIN_DIR}/manifest.json" ".manifest-check.json" 2>/dev/null || true
  if [[ -f ".manifest-check.json" ]]; then
    if ! verify_checksums ".manifest-check.json"; then
      rm -f ".manifest-check.json"
      exit 1
    fi
    rm -f ".manifest-check.json"
  fi
fi

# 创建 v6 数据层目录结构(tasks/decisions/domains/changes/evidence)
if [ -f "engine/scripts/engine-migrate-contract.sh" ]; then
  bash "engine/scripts/engine-migrate-contract.sh" "." 2>/dev/null || true
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}Done.${RESET} $install_count files installed, $skip_count skipped."
echo ""

if $UPDATE_MODE; then
  echo "Plugin updated. Your engine/*.md project memory was not overwritten."
  echo "Next: open your AI agent in this project and run /engine-sync."
  echo "/engine-sync runs engine-migrate-contract.* to write the current managed contract block"
  echo "into old engine files while preserving project-specific memory."
  echo "That contract covers self-maintenance, change capsules, acceptance evidence,"
  echo "Doctor parity, and other current Engine System mechanisms."
  echo "Future remote updates can use: engine update"
else
  echo "═══ 引擎已安装 ═══"
  echo "下一步(选一):"
  echo "  Claude Code  → /engine-init"
  echo "  其他 agent   → engine init"
  echo "  终端         → engine init"
  echo ""
  echo "engine init 会引导 agent 采访你的项目,生成 ENGINE_MAP / CONTEXT / SYSTEM / ARCHITECTURE。"
fi
echo ""
