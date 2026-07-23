#!/usr/bin/env bash
# Test: parse_task_patterns YAML frontmatter + case-insensitive parsing (T-043, v6.11.5)
#
# Validates the extended parse_task_patterns in engine/scripts/githooks/pre-commit:
#   - YAML frontmatter `field:` multi-line indented list (between --- delimiters)
#   - markdown `## field` section (case-insensitive header)
#   - inline single-line `field: a, b`
#   - case-mixed call (uppercase WRITE-SET) vs lowercase frontmatter `write-set:`
#   - frontmatter boundary: body `field:` text outside --- block must NOT match
#
# Black-box test: parse_task_patterns is extracted verbatim from pre-commit
# (lines 35-77) so the test exercises the real parser logic without invoking git.

set -euo pipefail

# parse_task_patterns — verbatim copy from engine/scripts/githooks/pre-commit (L35-77).
# Do not edit independently; sync with pre-commit when the parser changes.
parse_task_patterns() {
  _field="$1"; _file="$2"
  _inline="$(grep "^${_field}:" "$_file" 2>/dev/null | head -1 | sed "s/^${_field}:[[:space:]]*//;s/\r$//")"
  if [ -n "$_inline" ]; then
    printf '%s' "$_inline"
    return 0
  fi
  awk -v field="$_field" '
    BEGIN { in_section=0; in_frontmatter_block=0; in_frontmatter_field=0; out=""; field_lc=tolower(field) }
    {
      sub(/\r$/, "")
      # YAML frontmatter block boundary (--- open/close)
      if ($0 ~ /^---[[:space:]]*$/) {
        in_frontmatter_block = !in_frontmatter_block
        in_frontmatter_field = 0
        next
      }
      line_lc = tolower($0)
      # markdown section header (## field, case-insensitive)
      if (line_lc ~ "^##[[:space:]]+" field_lc "[[:space:]]*$") { in_section=1; in_frontmatter_field=0; next }
      if (in_section && $0 ~ "^##[[:space:]]+") { exit }
      # YAML frontmatter field header (field:, case-insensitive, only inside frontmatter_block)
      if (in_frontmatter_block && line_lc ~ "^" field_lc ":$") {
        in_frontmatter_field=1; in_section=0; next
      }
      # frontmatter field exit: non-indented non-empty line
      if (in_frontmatter_field && $0 !~ /^[[:space:]]/ && $0 != "") { in_frontmatter_field=0 }
      # collect frontmatter field list items (indented - entries)
      if (in_frontmatter_field && $0 ~ /^[[:space:]]+-[[:space:]]+/) {
        sub(/^[[:space:]]+-[[:space:]]+/, "")
        sub(/[[:space:]]+\(.*/, "")
        if ($0 != "") out = (out == "" ? $0 : out "," $0)
        next
      }
      # collect markdown section list items (original logic)
      if (in_section && $0 ~ "^-[[:space:]]+") {
        sub(/^-[[:space:]]+/, "")
        sub(/[[:space:]]+\(.*/, "")
        if ($0 != "") out = (out == "" ? $0 : out "," $0)
      }
    }
    END { print out }
  ' "$_file" 2>/dev/null
}

HERE="$(cd "$(dirname "$0")" && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

pass=0
fail=0
ok() { echo "PASS  $1"; pass=$((pass + 1)); }
bad() { echo "FAIL  $1"; fail=$((fail + 1)); }

# assert_eq <label> <actual> <expected>
assert_eq() {
  if [ "$2" = "$3" ]; then ok "$1"; else
    echo "  expected: [$3]"
    echo "  actual:   [$2]"
    bad "$1"
  fi
}

echo "[test_precommit_yaml_frontmatter.sh] T-043 parse_task_patterns YAML+case"

# --------------------------------------------------------------------------
# Scenario 1: YAML frontmatter multi-line write-set (lowercase field, uppercase call)
# --------------------------------------------------------------------------
f1="$TMP_ROOT/T-100.md"
cat > "$f1" <<'EOF'
---
write-set:
  - src/main.c
  - src/util.c (note)
  - docs/api.md
---
# T-100
> status: active
GOAL: frontmatter multi-line card
EOF
out1="$(parse_task_patterns WRITE-SET "$f1")"
assert_eq "S1 YAML frontmatter multi-line" "$out1" "src/main.c,src/util.c,docs/api.md"

# --------------------------------------------------------------------------
# Scenario 2: markdown ## WRITE-SET section (original format, still works)
# --------------------------------------------------------------------------
f2="$TMP_ROOT/T-101.md"
cat > "$f2" <<'EOF'
# T-101
> status: active | lane: main
GOAL: markdown section card
WRITE-SET:
## WRITE-SET
- src/a.py
- src/b.py (legacy)
## FORBIDDEN
- evil/path
EOF
out2="$(parse_task_patterns WRITE-SET "$f2")"
assert_eq "S2 markdown ## WRITE-SET section" "$out2" "src/a.py,src/b.py"

# --------------------------------------------------------------------------
# Scenario 3: inline single-line WRITE-SET: a, b (inline grep branch)
# --------------------------------------------------------------------------
f3="$TMP_ROOT/T-102.md"
cat > "$f3" <<'EOF'
# T-102
> status: active
GOAL: inline single-line card
WRITE-SET: src/x.ts, src/y.ts, src/z.ts
EOF
out3="$(parse_task_patterns WRITE-SET "$f3")"
assert_eq "S3 inline single-line" "$out3" "src/x.ts, src/y.ts, src/z.ts"

# --------------------------------------------------------------------------
# Scenario 4: case-mixed — lowercase frontmatter `write-set:` vs uppercase CALL.
# Also verifies uppercase field header `WRITE-SET:` is matched by lowercase call.
# --------------------------------------------------------------------------
f4="$TMP_ROOT/T-103.md"
cat > "$f4" <<'EOF'
---
WRITE-SET:
  - alpha.go
  - beta.go
---
# T-103
> status: active
GOAL: uppercase frontmatter field, lowercase call
EOF
out4a="$(parse_task_patterns write-set "$f4")"
assert_eq "S4a uppercase frontmatter vs lowercase call" "$out4a" "alpha.go,beta.go"
out4b="$(parse_task_patterns WRITE-SET "$f4")"
assert_eq "S4b uppercase frontmatter vs uppercase call" "$out4b" "alpha.go,beta.go"

# --------------------------------------------------------------------------
# Scenario 5: frontmatter boundary — body `write-set:` line OUTSIDE --- block
# must NOT be collected. Card has a real frontmatter write-set; body decoy
# `write-set: body-decoy` and a stray `- not-a-path` must be ignored.
# --------------------------------------------------------------------------
f5="$TMP_ROOT/T-104.md"
cat > "$f5" <<'EOF'
---
write-set:
  - real/frontmatter.go
---
# T-104
> status: active
GOAL: boundary guard card
## Notes
write-set: body-decoy
- not-a-path
EOF
out5="$(parse_task_patterns WRITE-SET "$f5")"
assert_eq "S5 body decoy not collected" "$out5" "real/frontmatter.go"

# --------------------------------------------------------------------------
# Scenario 6 (bonus): card with NO write-set at all — body has `write-set:`
# text but no --- block. Parser must return empty (no false positive).
# --------------------------------------------------------------------------
f6="$TMP_ROOT/T-105.md"
cat > "$f6" <<'EOF'
# T-105
> status: active
GOAL: no write-set, body decoy only
## Notes
write-set: should-not-match
- definitely-not-a-path
EOF
out6="$(parse_task_patterns WRITE-SET "$f6")"
assert_eq "S6 no-frontmatter body decoy -> empty" "$out6" ""

echo ""
echo "parse_task_patterns result: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
