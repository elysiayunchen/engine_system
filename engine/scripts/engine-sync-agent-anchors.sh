#!/usr/bin/env bash
# Engine System — sync cross-agent bootloader anchors
#
# Creates or updates thin Engine System pointers for agent tools that do not read
# AGENTS.md directly. Existing user content is preserved outside the managed block.

set -u

ROOT="${1:-${CLAUDE_PROJECT_DIR:-$PWD}}"
MAP="$ROOT/engine/ENGINE_MAP.md"
MARK_START="<!-- ENGINE_SYSTEM_SYNC_START -->"
MARK_END="<!-- ENGINE_SYSTEM_SYNC_END -->"

[ -f "$MAP" ] || {
  echo "engine/ENGINE_MAP.md not found. Run /engine-init first."
  exit 1
}

mkdir -p "$ROOT/.github" "$ROOT/.cursor/rules" 2>/dev/null || true

managed_block() {
  cat <<'EOF'
<!-- ENGINE_SYSTEM_SYNC_START -->
# Engine System

Read `engine/ENGINE_MAP.md` before editing. Follow the session protocol in `AGENTS.md`:
run the path-driven read-gate before edits, write incremental updates to `engine/CONTEXT.md`
and `engine/HANDOFF.md` after meaningful code changes, and keep shared engine-file writes
single-writer.
<!-- ENGINE_SYSTEM_SYNC_END -->
EOF
}

upsert_markdown_block() {
  local file="$1"
  local header="${2:-}"
  local tmp
  tmp="$(mktemp)"

  if [ ! -f "$file" ]; then
    {
      [ -n "$header" ] && printf '%s\n\n' "$header"
      managed_block
    } > "$file"
    echo "created ${file#$ROOT/}"
    return
  fi

  if grep -F "$MARK_START" "$file" >/dev/null 2>&1 && grep -F "$MARK_END" "$file" >/dev/null 2>&1; then
    block_tmp="$(mktemp)"
    managed_block > "$block_tmp"
    awk -v start="$MARK_START" -v end="$MARK_END" -v block="$block_tmp" '
      $0 == start {
        while ((getline line < block) > 0) print line
        close(block)
        skip=1
        next
      }
      $0 == end { skip=0; next }
      !skip { print }
    ' "$file" > "$tmp"
    mv "$tmp" "$file"
    rm -f "$block_tmp" 2>/dev/null || true
    echo "updated ${file#$ROOT/}"
    return
  fi

  {
    cat "$file"
    printf '\n\n'
    managed_block
  } > "$tmp"
  mv "$tmp" "$file"
  echo "appended ${file#$ROOT/}"
}

upsert_markdown_block "$ROOT/.github/copilot-instructions.md"
upsert_markdown_block "$ROOT/.cursor/rules/engine.md" "---"$'\n'"description: Engine System bootloader"$'\n'"alwaysApply: true"$'\n'"---"
upsert_markdown_block "$ROOT/GEMINI.md"
upsert_markdown_block "$ROOT/.clinerules"
upsert_markdown_block "$ROOT/.roorules"

aider_file="$ROOT/.aider.conf.yml"
if [ ! -f "$aider_file" ]; then
  cat > "$aider_file" <<'EOF'
# Engine System managed starter config.
read:
  - AGENTS.md
  - engine/ENGINE_MAP.md
  - engine/CONTEXT.md
  - engine/HANDOFF.md
EOF
  echo "created .aider.conf.yml"
else
  echo "keep .aider.conf.yml (already exists; add AGENTS.md and engine/ENGINE_MAP.md to read: if desired)"
fi

exit 0
