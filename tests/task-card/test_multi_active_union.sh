#!/usr/bin/env bash
# T-048 AC-1 (D-035 RC-1/RC-5): pre-commit union gating + per-card protected exemption.
#
# With two active cards, the old gate validated every staged path against the
# lexicographically first card, blocking the second agent's commits entirely.
# v6.12.0: per-path union across all governing cards; each card exempts its own
# files from the protected-path check; decision cards commit freely (bootstrap).

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
PRE_COMMIT="$REPO_ROOT/plugin/engine/scripts/githooks/pre-commit"

pass=0
fail=0
ok() { echo "PASS  $1"; pass=$((pass + 1)); }
bad() { echo "FAIL  $1"; fail=$((fail + 1)); }

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

new_fixture() {
  d="$(mktemp -d "$TMP_ROOT/repo.XXXXXX")"
  git -C "$d" init -q
  git -C "$d" config user.email mu@test
  git -C "$d" config user.name mu
  git -C "$d" config core.autocrlf false
  git -C "$d" config commit.gpgsign false
  mkdir -p "$d/engine/tasks" "$d/engine/decisions" "$d/src/a" "$d/src/b"
  printf '<!-- contract-version: 6.12.0 -->\n' > "$d/AGENTS.md"
  printf 'ctx\n' > "$d/engine/CONTEXT.md"
  cat > "$d/engine/decisions/rules.json" <<'EOF'
{
  "protected_paths": [
    "engine/decisions/**",
    "engine/tasks/**",
    "SECRET.md"
  ]
}
EOF
  cat > "$d/engine/tasks/T-100.md" <<'EOF'
# T-100
> status: active | lane: a | decision: none | domain: root
GOAL: first
WRITE-SET: src/a/**, engine/tasks/T-100.md, engine/CONTEXT.md
FORBIDDEN: src/b/**
AC: AC-1 t | verify: true
EOF
  cat > "$d/engine/tasks/T-101.md" <<'EOF'
# T-101
> status: active | lane: b | decision: none | domain: root
GOAL: second
WRITE-SET: src/b/**, engine/tasks/T-101.md, engine/workstreams/T-101/**
AC: AC-1 t | verify: true
EOF
  git -C "$d" add -A
  git -C "$d" commit -qm init
  printf '%s\n' "$d"
}

run_pc() { # $1=repo
  ( cd "$1" && CLAUDE_PROJECT_DIR="$1" sh "$PRE_COMMIT" ) >/dev/null 2>&1
}

echo "=== pre-commit multi-active union (sh) ==="

# P1: staging a file in the SECOND card's WRITE-SET passes (plus its shard as write-back)
r="$(new_fixture)"
echo x > "$r/src/b/f.txt"
mkdir -p "$r/engine/workstreams/T-101/w1"
echo wb > "$r/engine/workstreams/T-101/w1/HANDOFF.md"
git -C "$r" add src/b/f.txt engine/workstreams/T-101/w1/HANDOFF.md
if run_pc "$r"; then ok "P1 second card's path + shard write-back commits"; else bad "P1 blocked"; fi
git -C "$r" reset -q

# P2: file outside every card blocked
mkdir -p "$r/src/c"; echo y > "$r/src/c/g.txt"
git -C "$r" add src/c/g.txt
if run_pc "$r"; then bad "P2 outside-all passed"; else ok "P2 outside-all blocked"; fi
git -C "$r" reset -q

# P3: lex-later card commits ITSELF although engine/tasks/** is protected
printf '\nnote\n' >> "$r/engine/tasks/T-101.md"
git -C "$r" add engine/tasks/T-101.md
if run_pc "$r"; then ok "P3 lex-later active card commits itself"; else bad "P3 blocked"; fi
git -C "$r" reset -q; git -C "$r" checkout -q -- engine/tasks/T-101.md

# P4: NEW active card bootstraps while others are active
cat > "$r/engine/tasks/T-102.md" <<'EOF'
# T-102
> status: active | lane: c | decision: none | domain: root
GOAL: third
WRITE-SET: src/z/**, engine/tasks/T-102.md
AC: AC-1 t | verify: true
EOF
git -C "$r" add engine/tasks/T-102.md
if run_pc "$r"; then ok "P4 new card bootstraps alongside active cards"; else bad "P4 blocked"; fi
git -C "$r" reset -q; rm -f "$r/engine/tasks/T-102.md"

# P5: decision card commits freely (bootstrap channel)
printf '# D-900\n> status: proposed | scope: none\n' > "$r/engine/decisions/D-900.md"
git -C "$r" add engine/decisions/D-900.md
if run_pc "$r"; then ok "P5 decision card bootstrap"; else bad "P5 blocked"; fi
git -C "$r" reset -q; rm -f "$r/engine/decisions/D-900.md"

# P6: foreign PAUSED card edit still requires a decision (blocked)
cat > "$r/engine/tasks/T-099.md" <<'EOF'
# T-099
> status: paused | lane: z | decision: none | domain: root
GOAL: parked
WRITE-SET: src/q/**
AC: AC-1 t | verify: true
EOF
git -C "$r" add engine/tasks/T-099.md
if run_pc "$r"; then bad "P6 paused foreign card passed"; else ok "P6 paused foreign card blocked (needs decision)"; fi
git -C "$r" reset -q; rm -f "$r/engine/tasks/T-099.md"

# P7: protected non-card path needs an approved covering decision
echo s > "$r/SECRET.md"
git -C "$r" add SECRET.md
if run_pc "$r"; then bad "P7a unprotected commit passed"; else ok "P7a protected path without decision blocked"; fi
# now give T-101 an approved decision whose scope covers SECRET.md + put SECRET.md in its WRITE-SET
cat > "$r/engine/decisions/D-050.md" <<'EOF'
# D-050
> status: approved | scope: SECRET.md | expiry: none
EOF
sed -i.bak 's|^WRITE-SET: src/b/\*\*.*|WRITE-SET: src/b/**, engine/tasks/T-101.md, engine/workstreams/T-101/**, SECRET.md|; s|decision: none|decision: D-050|' "$r/engine/tasks/T-101.md" && rm -f "$r/engine/tasks/T-101.md.bak"
mkdir -p "$r/engine/workstreams/T-101/w1"
echo wb2 > "$r/engine/workstreams/T-101/w1/HANDOFF.md"
git -C "$r" add engine/workstreams/T-101/w1/HANDOFF.md
if run_pc "$r"; then ok "P7b covering card's approved decision unlocks protected path"; else bad "P7b still blocked"; fi
git -C "$r" reset -q

# P8: one card's FORBIDDEN does not veto the other card's WRITE-SET at commit
r2="$(new_fixture)"
echo x > "$r2/src/b/h.txt"
mkdir -p "$r2/engine/workstreams/T-101/w1"
echo wb > "$r2/engine/workstreams/T-101/w1/CONTEXT.md"
git -C "$r2" add src/b/h.txt engine/workstreams/T-101/w1/CONTEXT.md
if run_pc "$r2"; then ok "P8 cross-card FORBIDDEN not applied"; else bad "P8 blocked"; fi

echo ""
echo "multi_active_union result: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
