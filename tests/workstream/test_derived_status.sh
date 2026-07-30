#!/usr/bin/env bash
# Test: derived status panel + trust-level injection (T-067, v6.19.0, D-038c/d)
#
# Validates engine-context.sh render_derived_status() + trust-label injection
# and engine-doctor.sh check_derived_status(). Scenarios:
#
#   S1: engine-context outputs "Derived Status" segment with T1 trust
#   S2: engine-context injects [T2 legacy]/[T2 declared-only]/[T3] labels
#   S3: doctor check_derived_status PASS when legacy annotation present
#   S4: doctor check_derived_status WARN when legacy annotation missing
#   S5: doctor WARNs on tag/VERSION mismatch
#   S6: T2 legacy-evidence trust when no code_fingerprint
#
# Pattern follows test_drift_check.sh (T-066): mock ROOT + git init.
# Doctor check is tested by sourcing the function directly (avoids set -e exits).

set -uo pipefail

echo "[test_derived_status.sh] T-067 derived status + trust labels (D-038c/d)"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

REAL_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CTX_SH="$REAL_ROOT/engine/scripts/engine-context.sh"
DOC_SH="$REAL_ROOT/engine/scripts/engine-doctor.sh"
[ -f "$CTX_SH" ] || { echo "FATAL: $CTX_SH not found"; exit 2; }
[ -f "$DOC_SH" ] || { echo "FATAL: $DOC_SH not found"; exit 2; }

PASS=0
FAIL=0
ok()   { echo "  PASS $1"; PASS=$((PASS+1)); }
bad() { echo "  FAIL $1"; FAIL=$((FAIL+1)); }

# Doctor helpers (standalone, for testing check_derived_status in isolation).
# Must be named pass/warn/fail to match what check_derived_status() calls.
fail_count=0
warn_count=0
fail() { fail_count=$((fail_count+1)); printf 'FAIL %s\n' "$1"; }
warn() { warn_count=$((warn_count+1)); printf 'WARN %s\n' "$1"; }
pass() { printf 'PASS %s\n' "$1"; }

# Source check_derived_status from doctor script.
eval "$(sed -n '/^check_derived_status()/,/^}/p' "$DOC_SH")"

# Setup a mock repo with done task + multi-anchor evidence.
# Args: <tag> <engine_version> <legacy_annotation_present:0|1> <code_fp_present:0|1>
setup_repo() {
  local tag="$1" eng_ver="$2" has_legacy="$3" has_codefp="$4"
  MOCK_ROOT="$TMPDIR/repo"
  rm -rf "$MOCK_ROOT"
  mkdir -p "$MOCK_ROOT/engine/tasks" "$MOCK_ROOT/engine/evidence/T-999" "$MOCK_ROOT/engine/scripts" "$MOCK_ROOT/src"
  printf '%s\n' "$eng_ver" > "$MOCK_ROOT/engine/VERSION"
  cat > "$MOCK_ROOT/engine/tasks/T-999.md" <<'EOF'
# T-999: test fixture
> status: done | lane: engine-runtime

## WRITE-SET
- src/foo.py

AC: AC-1 | verify: true
EOF
  echo "print('hello')" > "$MOCK_ROOT/src/foo.py"
  if [ "$has_codefp" = "1" ]; then
    cat > "$MOCK_ROOT/engine/evidence/T-999/AC-1.json" <<'EOF'
{"ac":"AC-1","verify":"true","status":"pass","exit":0,"output_fingerprint":"sha256:abc","code_fingerprint":{"src/foo.py":"1234567890abcdef"},"write_set_snapshot":["src/foo.py"],"verified_against_commit":"PLACEHOLDER","write_provenance":{"writer":"engine-verify","commit":"PLACEHOLDER","timestamp":"2026-07-30T00:00:00Z","argv":"engine verify T-999"},"timestamp":"2026-07-30T00:00:00Z"}
EOF
  else
    cat > "$MOCK_ROOT/engine/evidence/T-999/AC-1.json" <<'EOF'
{"ac":"AC-1","verify":"true","status":"pass","exit":0,"fingerprint":"sha256:abc","timestamp":"2026-07-30T00:00:00Z"}
EOF
  fi
  if [ "$has_legacy" = "1" ]; then
    cat > "$MOCK_ROOT/engine/CONTEXT.md" <<'EOF'
# CONTEXT — test

## 状态面板

<!-- legacy: status-panel (double-write transition, v6.19.0~v6.20.0) -->

| 维度 | 状态 |
|------|------|
| 上次完成 | vTEST |

## 当前假设 / 决策（本轮拍板）

- decision A

## 待验证

- item X
EOF
  else
    cat > "$MOCK_ROOT/engine/CONTEXT.md" <<'EOF'
# CONTEXT — test

## 状态面板

| 维度 | 状态 |
|------|------|
| 上次完成 | vTEST |

## 当前假设 / 决策（本轮拍板）

- decision A

## 待验证

- item X
EOF
  fi
  ( cd "$MOCK_ROOT" && git init -q && git add -A && git -c user.email=t@t -c user.name=t commit -qm "fixture" )
  if [ "$has_codefp" = "1" ]; then
    local head_sha
    head_sha="$(cd "$MOCK_ROOT" && git rev-parse HEAD)"
    sed -i "s/PLACEHOLDER/$head_sha/g" "$MOCK_ROOT/engine/evidence/T-999/AC-1.json"
    ( cd "$MOCK_ROOT" && git add -A && git -c user.email=t@t -c user.name=t commit -qm "evidence fixup" )
  fi
  if [ -n "$tag" ]; then
    ( cd "$MOCK_ROOT" && git tag "$tag" )
  fi
}

# S1: engine-context outputs "Derived Status" segment with T1 trust
setup_repo "v9.9.9" "9.9.9" "1" "1"
out="$(bash "$CTX_SH" "$MOCK_ROOT" 2>/dev/null)"
if echo "$out" | grep -q "Derived Status"; then
  ok "S1: 'Derived Status' segment present"
else
  bad "S1: 'Derived Status' segment missing"
fi
if echo "$out" | grep -q "T1 (structural"; then
  ok "S1: trust level T1 (structural) for code_fingerprint evidence"
else
  bad "S1: expected T1 trust, got: $(echo "$out" | grep -i 'trust')"
fi

# S2: trust labels injected for CONTEXT.md sections
if echo "$out" | grep -q '\[T2 legacy\]'; then
  ok "S2: [T2 legacy] label injected for status panel"
else
  bad "S2: [T2 legacy] label missing"
fi
if echo "$out" | grep -q '\[T2 declared-only\]'; then
  ok "S2: [T2 declared-only] label injected for decisions"
else
  bad "S2: [T2 declared-only] label missing"
fi
if echo "$out" | grep -q '\[T3 unverified\]'; then
  ok "S2: [T3 unverified] label injected for pending"
else
  bad "S2: [T3 unverified] label missing"
fi

# S3: doctor check_derived_status PASS when legacy annotation present
setup_repo "v9.9.9" "9.9.9" "1" "1"
ROOT="$MOCK_ROOT"
ENGINE_DIR="$MOCK_ROOT/engine"
doc_out="$(check_derived_status 2>/dev/null)"
if echo "$doc_out" | grep -q 'PASS.*legacy annotation'; then
  ok "S3: doctor PASS on legacy annotation present"
else
  bad "S3: doctor should PASS on legacy annotation. Output: $doc_out"
fi

# S4: doctor WARN when legacy annotation missing
setup_repo "v9.9.9" "9.9.9" "0" "1"
ROOT="$MOCK_ROOT"
ENGINE_DIR="$MOCK_ROOT/engine"
doc_out="$(check_derived_status 2>/dev/null)"
if echo "$doc_out" | grep -q 'WARN.*legacy.*status-panel'; then
  ok "S4: doctor WARN on missing legacy annotation"
else
  bad "S4: doctor should WARN on missing legacy annotation. Output: $doc_out"
fi

# S5: doctor WARN on tag/VERSION mismatch
setup_repo "v9.9.9" "8.8.8" "1" "1"
ROOT="$MOCK_ROOT"
ENGINE_DIR="$MOCK_ROOT/engine"
doc_out="$(check_derived_status 2>/dev/null)"
if echo "$doc_out" | grep -q 'WARN.*tag.VERSION mismatch'; then
  ok "S5: doctor WARN on tag/VERSION mismatch"
else
  bad "S5: doctor should WARN on tag/VERSION mismatch. Output: $doc_out"
fi

# S6: T2 legacy-evidence trust when no code_fingerprint
setup_repo "v9.9.9" "9.9.9" "1" "0"
out="$(bash "$CTX_SH" "$MOCK_ROOT" 2>/dev/null)"
if echo "$out" | grep -q "T2 (legacy-evidence"; then
  ok "S6: T2 (legacy-evidence) trust when no code_fingerprint"
else
  bad "S6: expected T2 legacy-evidence, got: $(echo "$out" | grep -i 'trust')"
fi

echo ""
echo "Results: $PASS pass, $FAIL fail"
[ "$FAIL" -eq 0 ] || exit 1
