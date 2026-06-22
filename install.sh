#!/usr/bin/env bash
# Engine System installer
# Usage: bash <(curl -sSL https://raw.githubusercontent.com/elysiayunchen/engine_system/main/install.sh)
# Or:    bash install.sh [--update]

set -e

REPO="elysiayunchen/engine_system"
BRANCH="main"
PLUGIN_DIR="plugin"
UPDATE_MODE=false

# Parse flags
for arg in "$@"; do
  case $arg in
    --update) UPDATE_MODE=true ;;
  esac
done

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

BASE_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/${PLUGIN_DIR}"

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
  "engine/scripts/engine-doctor.sh:engine/scripts/engine-doctor.sh:true"
  "engine/scripts/engine-doctor.ps1:engine/scripts/engine-doctor.ps1:true"
  "engine/scripts/engine-hook-session-start.sh:engine/scripts/engine-hook-session-start.sh:true"
  "engine/scripts/engine-hook-session-start.ps1:engine/scripts/engine-hook-session-start.ps1:true"
  "engine/scripts/engine-hook-stop.sh:engine/scripts/engine-hook-stop.sh:true"
  "engine/scripts/engine-hook-stop.ps1:engine/scripts/engine-hook-stop.ps1:true"
  "engine/scripts/engine-hook-session-end.sh:engine/scripts/engine-hook-session-end.sh:true"
  "engine/scripts/engine-hook-session-end.ps1:engine/scripts/engine-hook-session-end.ps1:true"
  "engine/scripts/engine-sync-agent-anchors.sh:engine/scripts/engine-sync-agent-anchors.sh:true"
  "engine/scripts/engine-sync-agent-anchors.ps1:engine/scripts/engine-sync-agent-anchors.ps1:true"
  "engine/scripts/engine-migrate-contract.sh:engine/scripts/engine-migrate-contract.sh:true"
  "engine/scripts/engine-migrate-contract.ps1:engine/scripts/engine-migrate-contract.ps1:true"
  "engine/scripts/githooks/pre-commit:engine/scripts/githooks/pre-commit:true"
  "bin/engine:engine/bin/engine:true"
  "bin/engine.ps1:engine/bin/engine.ps1:true"
  "bin/engine.cmd:engine/bin/engine.cmd:true"
  ".claude/settings.json:.claude/settings.json:false"
)

# Create directories
mkdir -p .claude/commands engine engine/scripts engine/scripts/githooks engine/bin engine/.cache

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
    download "$url" "$dest"
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

  download "$url" "$dest"
  echo -e "  ${GREEN}✓${RESET} $dest"
  ((install_count += 1))
done

cli_src="engine/bin/engine"
cli_dest="${HOME:-}/.local/bin/engine"
if [[ -n "${HOME:-}" && -f "$cli_src" ]]; then
  mkdir -p "$(dirname "$cli_dest")"
  cp "$cli_src" "$cli_dest"
  chmod +x "$cli_dest" 2>/dev/null || true
  echo -e "  ${GREEN}✓${RESET} $cli_dest (CLI: engine update)"
  ((install_count += 1))
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
  echo "Next steps:"
  echo ""
  echo "  Option A — Claude Code (recommended):"
  echo "    Open Claude Code in this project, then type:  /engine-init"
  echo "    Claude interviews you, picks a profile (WEB-FULL / CLI-LEAN),"
  echo "    and writes engine/ENGINE_MAP.md + all engine files to disk."
  echo ""
  echo "  Option B — Web Claude:"
  echo "    Copy the contents of .claude/commands/engine-init.md"
  echo "    Paste into claude.ai to start the interview."
  echo ""
  echo "  After init, use these commands in Claude Code:"
  echo "    /engine-update     — sync state + handoff after each session"
  echo "    /add-pitfall       — record a bug or footgun immediately"
  echo "    /engine-status     — print current project snapshot"
  echo "    /engine-ingest     — file a new plan (design doc) into engine/plans/"
  echo "    /engine-extend     — register a new authority engine file type"
  echo "    /engine-doctor     — validate engine registry, anchors, plans, budgets"
  echo "    /engine-sync       — update Engine System tooling, then reconcile engine files"
  echo "    /engine-reconcile  — audit engine files vs real code, fix drift"
  echo ""
  echo "  Terminal updater:"
  echo "    engine update      — fetch latest Engine System tooling from remote"
fi
echo ""
