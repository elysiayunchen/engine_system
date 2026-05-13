#!/usr/bin/env bash
# engine-system installer
# Usage: bash <(curl -sSL https://raw.githubusercontent.com/elysiayunchen/engine-system/main/install.sh)
# Or:    bash install.sh [--update]

set -e

REPO="elysiayunchen/engine-system"
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
echo -e "${CYAN}engine-system installer${RESET}"
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
  ".claude/commands/add-pitfall.md:.claude/commands/add-pitfall.md:true"
  ".claude/commands/engine-status.md:.claude/commands/engine-status.md:true"
  "CLAUDE.md:CLAUDE.md:true"
  "engine/README.md:engine/README.md:false"
)

# Create directories
mkdir -p .claude/commands engine

install_count=0
skip_count=0

for entry in "${FILES[@]}"; do
  IFS=':' read -r src dest protect <<< "$entry"
  url="${BASE_URL}/${src}"

  # In update mode, skip protected files if they already exist
  if $UPDATE_MODE && [[ "$protect" == "false" ]] && [[ -f "$dest" ]]; then
    echo -e "  ${YELLOW}skip${RESET}  $dest (user data, not overwritten)"
    ((skip_count++))
    continue
  fi

  # In update mode, always overwrite plugin files (commands, CLAUDE.md)
  if $UPDATE_MODE && [[ "$protect" == "true" ]]; then
    download "$url" "$dest"
    echo -e "  ${GREEN}updated${RESET} $dest"
    ((install_count++))
    continue
  fi

  # Fresh install: don't overwrite existing user engine files
  if [[ -f "$dest" ]] && [[ "$dest" == engine/*.md ]] && [[ "$dest" != "engine/README.md" ]]; then
    echo -e "  ${YELLOW}skip${RESET}  $dest (already exists)"
    ((skip_count++))
    continue
  fi

  download "$url" "$dest"
  echo -e "  ${GREEN}✓${RESET} $dest"
  ((install_count++))
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}Done.${RESET} $install_count files installed, $skip_count skipped."
echo ""

if $UPDATE_MODE; then
  echo "Plugin updated. Your engine/*.md files were not touched."
else
  echo "Next steps:"
  echo ""
  echo "  Option A — Claude Code (recommended):"
  echo "    Open Claude Code in this project, then type:  /engine-init"
  echo ""
  echo "  Option B — Web Claude:"
  echo "    Copy the contents of .claude/commands/engine-init.md"
  echo "    Paste into claude.ai to start the interview."
  echo ""
  echo "  After init, use these commands in Claude Code:"
  echo "    /engine-update   — sync state after each session"
  echo "    /add-pitfall     — record a bug or footgun immediately"
  echo "    /engine-status   — print current project snapshot"
fi
echo ""
