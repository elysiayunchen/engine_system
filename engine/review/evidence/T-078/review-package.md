# Code Review Package: T-078

> generated: 2026-08-01T14:21:05Z
> package_sha256: 692dbc8041b03fc4e902e936a6be1ac732a1e0b64cf65415b0899f9da5f64945
> head_commit: 21b75af9ded1c64ba517340121e5a45662b5d062
> packaged_by: Elysia:5198
> task: 修复 GitHub issue #25：验收命令的 coverage fail-under 与声明环境缺依赖不能继续和产品行为失败共用一个 `status=fail`。新增 acceptance preflight，保留冻结命令结果，另行记录行为诊断结果、环境状态和 coverage 状态；`blocked` 不计为 PASS。
> scope: 4e9d1688..21b75af9, 2 code files

## 1. Task Context

### GOAL
修复 GitHub issue #25：验收命令的 coverage fail-under 与声明环境缺依赖不能继续和产品行为失败共用一个 `status=fail`。新增 acceptance preflight，保留冻结命令结果，另行记录行为诊断结果、环境状态和 coverage 状态；`blocked` 不计为 PASS。

### WRITE-SET
- engine/scripts/engine-verify.sh
- engine/scripts/engine-verify.ps1
- plugin/engine/scripts/engine-verify.sh
- plugin/engine/scripts/engine-verify.ps1
- engine/bin/engine
- engine/bin/engine.ps1
- plugin/bin/engine
- plugin/bin/engine.ps1
- tests/workstream/test_acceptance_preflight.sh
- tests/workstream/test_acceptance_preflight.ps1
- engine/tasks/T-078.md
- engine/tasks/T-078/progress.md
- engine/evidence/T-078/AC-1.json
- engine/evidence/T-078/AC-2.json
- engine/evidence/T-078/AC-3.json
- engine/evidence/T-078/AC-4.json
- engine/evidence/T-078/AC-5.json
- engine/evidence/T-078/AC-6.json
- engine/evidence/T-078/AC-7.json
- engine/evidence/T-078/CLOSE.json
- engine/evidence/T-078/GATE.json
- engine/evidence/T-078/MANIFEST.json
- engine/evidence/T-078/PROVE.json
- engine/evidence/T-078/checkpoint.md
- engine/evidence/T-078/prove-assertions.json
- engine/evidence/T-078/prove-package.md

### CONSTRAINTS


### AC
AC: AC-1 acceptance preflight CLI + `engine verify T-NNN --preflight` alias | verify: bash tests/workstream/test_acceptance_preflight.sh
AC: AC-2 coverage threshold failure is `blocked`, keeps command_exit=1, records behavior_exit=0 and coverage_status | verify: bash tests/workstream/test_acceptance_preflight.sh
AC: AC-3 missing dependency/environment is `blocked`, records environment_status=blocked and does not count PASS | verify: bash tests/workstream/test_acceptance_preflight.sh
AC: AC-4 ordinary behavior failure remains `fail` and has distinct command_exit/behavior_exit fields | verify: bash tests/workstream/test_acceptance_preflight.sh
AC: AC-5 explicit `--no-cov` and per-AC `coverage: no-cov` policy are accepted and recorded | verify: bash tests/workstream/test_acceptance_preflight.sh
AC: AC-6 PowerShell semantic twin and plugin mirrors are present | verify: bash tests/workstream/test_acceptance_preflight.sh
AC: AC-7 existing full `engine verify` behavior remains compatible | verify: bash tests/behavior-verify/run-verify-tests.sh

## 2. Code Changes (diff)

### tests/workstream/test_acceptance_preflight.sh
```diff
diff --git a/tests/workstream/test_acceptance_preflight.sh b/tests/workstream/test_acceptance_preflight.sh
new file mode 100644
index 0000000..474bf79
--- /dev/null
+++ b/tests/workstream/test_acceptance_preflight.sh
@@ -0,0 +1,141 @@
+#!/usr/bin/env bash
+# T-078 / issue #25: acceptance preflight separates harness failures from behavior.
+
+set -u
+
+HERE="$(cd "$(dirname "$0")" && pwd)"
+ROOT_REPO="$(cd "$HERE/../.." && pwd)"
+VERIFY_SH="$ROOT_REPO/engine/scripts/engine-verify.sh"
+CLI_SH="$ROOT_REPO/engine/bin/engine"
+TMP_ROOT="$(mktemp -d)"
+trap 'rm -rf "$TMP_ROOT"' EXIT
+
+pass=0
+fail=0
+
+assert_rc() {
+  local name="$1" expected="$2" actual="$3"
+  if [ "$expected" -eq "$actual" ]; then
+    echo "PASS  $name (exit=$actual)"
+    pass=$((pass+1))
+  else
+    echo "FAIL  $name (expected exit=$expected got=$actual)"
+    fail=$((fail+1))
+  fi
+}
+
+assert_file_has() {
+  local name="$1" file="$2" pattern="$3"
+  if grep -Eq "$pattern" "$file"; then
+    echo "PASS  $name"
+    pass=$((pass+1))
+  else
+    echo "FAIL  $name (pattern not found: $pattern)"
+    fail=$((fail+1))
+  fi
+}
+
+assert_files_equal() {
+  local name="$1" left="$2" right="$3"
+  if cmp -s "$left" "$right"; then
+    echo "PASS  $name"
+    pass=$((pass+1))
+  else
+    echo "FAIL  $name ($left differs from $right)"
+    fail=$((fail+1))
+  fi
+}
+
+REPO="$TMP_ROOT/repo"
+mkdir -p "$REPO/engine/tasks" "$REPO/engine/scripts" "$REPO/engine/bin" "$REPO/engine/evidence" "$REPO/bin"
+cp "$VERIFY_SH" "$REPO/engine/scripts/engine-verify.sh"
+cp "$CLI_SH" "$REPO/engine/bin/engine"
+chmod +x "$REPO/engine/scripts/engine-verify.sh" "$REPO/engine/bin/engine"
+
+cat > "$REPO/engine/tasks/T-TEST.md" <<'CARD'
+# T-TEST: acceptance preflight fixture
+
+## WRITE-SET
+
+- src/not-yet-created.sh
+
+## AC
+
+AC: AC-1 coverage harness | verify: pytest -q | coverage: auto
+AC: AC-2 missing dependency | verify: bash -c 'echo "ModuleNotFoundError: No module named missing" >&2; exit 1'
+AC: AC-3 behavior failure | verify: bash -c 'exit 9' | behavior: bash -c 'exit 7'
+AC: AC-4 no coverage policy | verify: pytest -q --no-cov | coverage: no-cov
+CARD
+
+# Deterministic pytest stand-in: the frozen command fails only because of the
+# repository coverage threshold; the diagnostic command passes with --no-cov.
+cat > "$REPO/bin/pytest" <<'PYTEST'
+#!/usr/bin/env bash
+case " $* " in
+  *" --no-cov "*) echo "behavior passed"; exit 0 ;;
+  *) echo "FAIL Required test coverage of 80% not reached" >&2; exit 1 ;;
+esac
+PYTEST
+chmod +x "$REPO/bin/pytest"
+
+export PATH="$REPO/bin:$PATH"
+export CLAUDE_PROJECT_DIR="$REPO"
+
+echo "=== acceptance preflight behavior classification ==="
+OUTPUT="$TMP_ROOT/verify.out"
+bash "$VERIFY_SH" T-TEST --preflight >"$OUTPUT" 2>&1
+rc=$?
+assert_rc "preflight returns non-zero for blocked/fail ACs" 1 "$rc"
+
+EVIDENCE="$REPO/engine/evidence/T-TEST"
+assert_file_has "coverage result is blocked" "$EVIDENCE/AC-1.json" '"status":"blocked"'
+assert_file_has "coverage keeps command_exit=1" "$EVIDENCE/AC-1.json" '"command_exit":1'
+assert_file_has "coverage behavior diagnostic passes" "$EVIDENCE/AC-1.json" '"behavior_exit":0'
+assert_file_has "coverage failure is classified" "$EVIDENCE/AC-1.json" '"coverage_status":"failed_threshold"'
+assert_file_has "coverage policy defaults to auto" "$EVIDENCE/AC-1.json" '"coverage_policy":"auto"'
+
+assert_file_has "missing dependency is blocked" "$EVIDENCE/AC-2.json" '"status":"blocked"'
+assert_file_has "missing dependency is classified" "$EVIDENCE/AC-2.json" '"environment_status":"blocked"'
+if grep -q '"status":"pass"' "$EVIDENCE/AC-2.json"; then
+  echo "FAIL  missing dependency cannot be PASS"
+  fail=$((fail+1))
+else
+  echo "PASS  missing dependency cannot be PASS"
+  pass=$((pass+1))
+fi
+
+assert_file_has "ordinary behavior failure remains fail" "$EVIDENCE/AC-3.json" '"status":"fail"'
+assert_file_has "ordinary command exit is retained" "$EVIDENCE/AC-3.json" '"command_exit":9'
+assert_file_has "ordinary behavior exit is separate" "$EVIDENCE/AC-3.json" '"behavior_exit":7'
+
+assert_file_has "per-AC no-cov policy is recorded" "$EVIDENCE/AC-4.json" '"coverage_policy":"no-cov"'
+assert_file_has "per-AC no-cov disables coverage" "$EVIDENCE/AC-4.json" '"coverage_status":"disabled"'
+
+echo "=== CLI aliases ==="
+CLI_OUTPUT="$TMP_ROOT/cli.out"
+(cd "$REPO" && ./engine/bin/engine acceptance-preflight T-TEST --no-cov >"$CLI_OUTPUT" 2>&1)
+cli_rc=$?
+assert_rc "acceptance-preflight CLI is wired" 1 "$cli_rc"
+assert_file_has "CLI --no-cov is recorded" "$EVIDENCE/AC-1.json" '"coverage_policy":"no-cov"'
+assert_file_has "CLI invokes preflight mode" "$EVIDENCE/AC-1.json" '"preflight":true'
+
+(cd "$REPO" && ./engine/bin/engine verify T-TEST --preflight >"$CLI_OUTPUT" 2>&1)
+alias_rc=$?
+assert_rc "verify --preflight alias is wired" 1 "$alias_rc"
+
+echo "=== mirror parity ==="
+assert_files_equal "bash engine/plugin mirror" "$ROOT_REPO/engine/scripts/engine-verify.sh" "$ROOT_REPO/plugin/engine/scripts/engine-verify.sh"
+assert_files_equal "powershell engine/plugin mirror" "$ROOT_REPO/engine/scripts/engine-verify.ps1" "$ROOT_REPO/plugin/engine/scripts/engine-verify.ps1"
+assert_files_equal "bash CLI engine/plugin mirror" "$ROOT_REPO/engine/bin/engine" "$ROOT_REPO/plugin/bin/engine"
+assert_files_equal "powershell CLI engine/plugin mirror" "$ROOT_REPO/engine/bin/engine.ps1" "$ROOT_REPO/plugin/bin/engine.ps1"
+
+if command -v pwsh >/dev/null 2>&1; then
+  pwsh -NoProfile -ExecutionPolicy Bypass -File "$HERE/test_acceptance_preflight.ps1" >"$TMP_ROOT/ps.out" 2>&1
+  ps_rc=$?
+  assert_rc "PowerShell preflight smoke test" 0 "$ps_rc"
+else
+  echo "SKIP  PowerShell preflight smoke test (pwsh unavailable)"
+fi
+
+echo "=== RESULTS: $pass passed, $fail failed ==="
+[ "$fail" -eq 0 ]
```

### tests/workstream/test_acceptance_preflight.ps1
```diff
diff --git a/tests/workstream/test_acceptance_preflight.ps1 b/tests/workstream/test_acceptance_preflight.ps1
new file mode 100644
index 0000000..db23416
--- /dev/null
+++ b/tests/workstream/test_acceptance_preflight.ps1
@@ -0,0 +1,28 @@
+# T-078 / issue #25: PowerShell acceptance-preflight smoke test.
+
+$ErrorActionPreference = 'Stop'
+$Root = Split-Path (Split-Path $PSScriptRoot)
+$pass = 0
+$fail = 0
+
+function Assert-True {
+  param([string]$Name, [bool]$Condition)
+  if ($Condition) { Write-Output "PASS  $Name"; $script:pass++ }
+  else { Write-Output "FAIL  $Name"; $script:fail++ }
+}
+
+Assert-True 'PowerShell verifier exists' (Test-Path (Join-Path $Root 'engine/scripts/engine-verify.ps1'))
+Assert-True 'plugin PowerShell verifier mirrors engine' ((Get-FileHash (Join-Path $Root 'engine/scripts/engine-verify.ps1')).Hash -eq (Get-FileHash (Join-Path $Root 'plugin/engine/scripts/engine-verify.ps1')).Hash)
+Assert-True 'PowerShell CLI mirrors engine' ((Get-FileHash (Join-Path $Root 'engine/bin/engine.ps1')).Hash -eq (Get-FileHash (Join-Path $Root 'plugin/bin/engine.ps1')).Hash)
+
+$tokens = $null
+$parseErrors = $null
+[System.Management.Automation.Language.Parser]::ParseFile((Join-Path $Root 'engine/scripts/engine-verify.ps1'), [ref]$tokens, [ref]$parseErrors) | Out-Null
+Assert-True 'PowerShell verifier parses' ($parseErrors.Count -eq 0)
+
+$task = Join-Path $Root 'engine/tasks/T-078.md'
+$taskText = Get-Content -Raw -Path $task -Encoding UTF8
+Assert-True 'task card exposes preflight ACs' ($taskText -match 'acceptance preflight' -and $taskText -match 'coverage: no-cov')
+
+Write-Output "=== RESULTS: $pass passed, $fail failed ==="
+if ($fail -ne 0) { exit 1 }
```


## 3. Surrounding Context


## 4. Domain Knowledge
### Domain: project-meta — INVENTORY
# INVENTORY — project-meta
> Last updated: 2026-07-29 | 域级功能索引 | 5 列 ≤120 行,见 contract/src/20-file-templates.md FILE 14

| Feature | Entry file | Public API | Status | Last verified |
|---------|-----------|------------|--------|---------------|
| 任务卡格式契约 | engine/tasks/README.md | parse_task_card(id) | stable | 2026-07-19 |
| 决策台账 | engine/decisions/README.md | parse_decision(id) | stable | 2026-07-19 |
| 受保护路径声明 | engine/decisions/rules.json | protected_paths() | stable | 2026-07-19 |
| 变更胶囊格式 | engine/changes/CHANGE-2026-07-19-04.md | parse_capsule(file) | stable | 2026-07-19 |
| 域路由联邦表 | engine/domains/federation.json | resolve_domain(path) | stable | 2026-07-19 |
| 行为技能路由表 | engine/domains/routing.json | route_behavior(intent) | stable | 2026-07-19 |
| 项目地图 | engine/ENGINE_MAP.md | load_engine_map() | stable | 2026-07-19 |
| 当前状态面板 | engine/CONTEXT.md | read_status_panel() | stable | 2026-07-19 |
| 会话交接 | engine/HANDOFF.md | read_resume_point() | stable | 2026-07-19 |
| Agent 适配器 | engine/AGENT_ADAPTERS.md | list_adapters() | stable | 2026-07-19 |
| 任务级 progress.md 模板 | engine/skeleton/progress.md | instantiate_progress(tid) | stable | 2026-07-19 |
| 域级 INVENTORY 模板 | engine/skeleton/domains/INVENTORY.md | instantiate_inventory(domain) | stable | 2026-07-19 |
| HANDOFF 历史归档 | engine/handoff-archive-2026-07.md | search_archive(date) | stable | 2026-07-19 |
| 引擎根引导器 | AGENTS.md | read_session_protocol() | stable | 2026-07-19 |
| Claude 引导器 | CLAUDE.md | read_quick_start() | stable | 2026-07-19 |
| migrator bump 提示测试(sh) | tests/update-flow/test_migrator_bump_prompt.sh | test_migrator_bump_prompt_sh() | stable | 2026-07-29 |
| migrator bump 提示测试(ps1) | tests/update-flow/test_migrator_bump_prompt.ps1 | test_migrator_bump_prompt_ps1() | stable | 2026-07-29 |
| Agent review CLI regression | tests/workstream/test_review_agent_cli.sh | test_review_agent_cli_sh() | stable | 2026-08-01 |
| Agent review package regression | tests/workstream/test_review_agent_package.sh | test_review_agent_package_sh() | stable | 2026-08-01 |
| Agent review validator regression | tests/workstream/test_review_agent_validate.sh | test_review_agent_validate_sh() | stable | 2026-08-01 |
| Agent review config regression | tests/workstream/test_review_agent_config.sh | test_review_agent_config_sh() | stable | 2026-08-01 |
| Agent review mirror regression | tests/workstream/test_review_agent_mirror.sh | test_review_agent_mirror_sh() | stable | 2026-08-01 |
| Agent reviewer design specification | docs/superpowers/specs/2026-07-31-agent-reviewer-design.md | agent_reviewer_design_spec() | stable | 2026-08-01 |
| Agent review gate regression | tests/workstream/test_review_agent_gate.sh | test_review_agent_gate_sh() | stable | 2026-08-01 |
| Doctor agent review regression | tests/workstream/test_doctor_agent_review.sh | test_doctor_agent_review_sh() | stable | 2026-08-01 |
| Grounded review regression | tests/workstream/test_review_agent_grounded.sh | test_review_agent_grounded_sh() | stable | 2026-08-01 |
| Dynamic review regression | tests/workstream/test_review_agent_dynamic.sh | test_review_agent_dynamic_sh() | stable | 2026-08-01 |
| Prove inference regression | tests/workstream/test_prove_infer.sh | test_prove_infer_sh() | stable | 2026-08-01 |
| Prove execution regression | tests/workstream/test_prove_execute.sh | test_prove_execute_sh() | stable | 2026-08-01 |
| Acceptance preflight regression(sh) | tests/workstream/test_acceptance_preflight.sh | test_acceptance_preflight_sh() | stable | 2026-08-01 |
| Acceptance preflight regression(ps1) | tests/workstream/test_acceptance_preflight.ps1 | test_acceptance_preflight_ps1() | stable | 2026-08-01 |

### Domain: project-meta — PITFALLS
# project-meta — 陷阱与检索配方

> 项目运营记忆域的非显然行为。新增陷阱时登记 rg recipe,归档不等于遗忘。

## 陷阱

- **P001 任务卡 status 必须用 `status:.*active` 匹配**:grep 行内匹配,字段格式 `> status: active | lane:...`。来源:S1。
- **P002 FORBIDDEN 优先于 WRITE-SET**:路径同时命中两者时,按 FORBIDDEN 拦截(架构师否决权优先)。来源:S1 task-card 测试。
- **P003 无 active 任务卡时回退 v5.6 行为**:门禁不要求任务卡存在;兼容存量项目。来源:S1 向后兼容设计。
- **P004 决策 scope 用 glob,逗号分隔**:pre-commit 用 `case` 模式匹配校验 scope 覆盖。来源:S1 pre-commit。

## 检索配方

```bash
rg "status:.*active" engine/tasks/                            # 找活跃任务卡
rg "status:.*proposed" engine/decisions/                      # 找待拍板决策
ls engine/changes/CHANGE-*.md | sort -r | head -3             # 最近胶囊
rg "verify:" engine/tasks/                                    # AC 验证命令
rg "protected_paths" engine/decisions/rules.json              # 受保护路径
```


## 5. Review Protocol

# Code Review Protocol (L0 Default)

You are reviewing code changes for a task governed by an Engine System task card.
Your review must be thorough, specific, and actionable.

## Review Dimensions (5, all required)

### 1. Correctness
Look for: logic errors, off-by-one, null/undefined handling, race conditions,
deadlocks, infinite loops, incorrect state transitions, wrong return values,
uninitialized variables, broken error propagation.

### 2. Design
Look for: unnecessary abstraction layers, missing abstraction, SRP violations,
tight coupling, god functions (>50 lines doing multiple things), circular
dependencies, config scattered across files, hardcoded values that should be configurable.

### 3. Consistency (cross-file)
Look for: interface changes not propagated to callers, naming inconsistencies,
mirror/parity violations (sh vs ps1, engine vs plugin), import/require mismatches,
schema changes without migration, documentation drift from implementation.

### 4. Readability
Look for: unclear naming, deep nesting (>3 levels), missing comments on complex
logic, dead code, magic numbers, overly clever one-liners, inconsistent formatting,
functions that require reading implementation to understand contract.

### 5. Completeness
Look for: missing error handling, untested edge cases, missing input validation,
no timeout/retry for external calls, missing cleanup (resources/locks/temp files),
incomplete documentation for public APIs, missing logging for debuggability.

## Output Rules

- Every dimension MUST have at least 1 entry (finding or strength).
- If a dimension has no issues, add a "strength" entry explaining WHY it is good.
- Every finding.message must be >= 20 characters and specific (cite line numbers).
- Every finding should include a suggestion for how to fix it.
- Answer all 3 adversarial challenges with substantive analysis (>= 30 chars each).
- Your overall_assessment + 5 summaries must total >= 200 characters.
- Use severity honestly: critical = will cause data loss/security breach/crash in
  production; high = likely bug or significant maintainability issue; medium = code
  smell or minor issue; low = style preference; info = observation/strength.
- status = "block" ONLY if you found at least one critical issue that MUST be fixed
  before merge. Use "concerns" for high-severity issues that the architect might
  accept. Use "pass" when no high/critical issues exist.

## Provenance & Independence (v6.22.0)

- `write_provenance.reviewer_session`: your session/agent identifier. MUST differ
  from the package header's `packaged_by` value (the session that generated the
  package). This ensures the reviewer is independent from the packager.
- `packaged_by` (package header): identifies who generated the review package.
  Format: `<session-id>` or `<hostname>:<pid>`.
- **Subagent review is mandatory.** A missing `reviewer_session` or one that
  matches `packaged_by` will cause validation to FAIL with E_INDEPENDENCE.
  The review MUST be performed by a separate agent session from the one that
  packaged the review context.

## Grounding Requirement (v6.22.0)

- Every finding with `file` and `line` fields will be validated for existence:
  the referenced file must exist in the repository, and the line number must not
  exceed the file's actual length.
- If more than 50% of your findings reference non-existent locations, validation
  FAILS with E_GROUNDED. If 50% or fewer are ungrounded, a WARN is issued but
  validation still passes.
- Always verify file paths and line numbers against the actual diff before citing
  them in findings.

### Adversarial Challenges (must answer all 3)

1. File `tests/workstream/test_acceptance_preflight.sh` line ~75 adds a new branch (`case " $* " in`) with no visible else/fallback. What happens when this condition is false — silent skip, crash, or data corruption?
2. If someone needs to modify this code 6 months from now, what is the biggest comprehension barrier?
3. What is the worst-case input for this change, and does it degrade gracefully?



### Multi-Perspective Lenses (v6.23.0, T-076)

Conduct your review through 3 distinct cognitive lenses. For each lens, actively search for issues specific to that perspective:

1. **Correctness lens**: Logic errors, off-by-one, wrong variable, missing return, broken control flow, incorrect assumptions about input/output contracts.
2. **Security lens**: Injection vectors (shell/SQL/path), permission bypasses, unvalidated input, data leakage, unsafe deserialization, hardcoded secrets.
3. **Edge-case lens**: Empty/null inputs, boundary values, concurrent access, resource exhaustion, platform-specific behavior (CRLF, encoding, path separators).

Tag each finding's id with its lens: e.g. , , .
At least 1 finding per lens is expected (use type="strength" + severity="info" if genuinely clean).

## 6. Output Format (strict)

Write your review to: `engine/review/evidence/T-078/AGENT-REVIEW.json`

Schema (all fields required):
```json
{
  "task": "T-078",
  "timestamp": "<ISO-8601>",
  "reviewer": {"type": "agent", "model": "<optional>"},
  "status": "pass|concerns|block",
  "dimensions": {
    "correctness": {"entries": [{"id": "agent-correctness-<file>:<line>", "severity": "high", "type": "finding", "file": "<path>", "line": 42, "message": "<>=20 chars>", "suggestion": "<optional>"}], "summary": "<1-2 sentences>"},
    "design": {"entries": [...], "summary": "..."},
    "consistency": {"entries": [...], "summary": "..."},
    "readability": {"entries": [...], "summary": "..."},
    "completeness": {"entries": [...], "summary": "..."}
  },
  "adversarial_responses": [
    {"challenge": "<question 1>", "response": "<>=30 chars>"},
    {"challenge": "<question 2>", "response": "<>=30 chars>"},
    {"challenge": "<question 3>", "response": "<>=30 chars>"}
  ],
  "overall_assessment": "<2-3 sentences, >=200 chars total with summaries>",
  "write_provenance": {
    "writer": "agent-reviewer",
    "commit": "21b75af9ded1c64ba517340121e5a45662b5d062",
    "timestamp": "<write time>",
    "package_sha256": "<fill from package header>",
    "reviewer_session": "<your session/agent identifier, must differ from packaged_by>"
  }
}
```

**Important**:
- `write_provenance.commit`: copy the `head_commit` value from this package header
- `write_provenance.package_sha256`: copy the `package_sha256` value from this package header
- Each finding.message >= 20 characters
- Each dimension must have >= 1 entry (use type="strength" + severity="info" if no issues found)
- Exactly 3 adversarial_responses, each response >= 30 characters
- severity values: critical | high | medium | low | info
- status: "pass" (no critical/high) | "concerns" (has high, acceptable) | "block" (has critical)
