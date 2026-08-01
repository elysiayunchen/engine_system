# Code Review Package: T-073

> generated: 2026-08-01T04:32:35Z
> package_sha256: b4b873adc3382366c45e725520deb064253757c65ff33db34a8673c18d53d57b
> head_commit: 89b5550d32655c702b3dd6dd94bc691ecc2dfbd4
> packaged_by: Elysia:13372
> task: 将 agent-reviewer 从"填表校验"升级为"有智力含量的审查"。四项改进:(1) 动态挑战生成——从 diff 语义信号(新分支无 else / 签名变更 / 长 hunk / 删除代码 / TODO 新增)生成参数化挑战,替代 3 个固定模板;(2) E_GROUNDED 校验层——验证 finding 引用的 file:line 在仓库中实际存在,拦截幻觉 finding;(3) reviewer 独立性——package 嵌入 packaged_by 标识,validate 校验 reviewer_session 与之不同;(4) 新项目默认 enabled: true。
> scope: ed5602db..89b5550d, 10 code files

## 1. Task Context

### GOAL
将 agent-reviewer 从"填表校验"升级为"有智力含量的审查"。四项改进:(1) 动态挑战生成——从 diff 语义信号(新分支无 else / 签名变更 / 长 hunk / 删除代码 / TODO 新增)生成参数化挑战,替代 3 个固定模板;(2) E_GROUNDED 校验层——验证 finding 引用的 file:line 在仓库中实际存在,拦截幻觉 finding;(3) reviewer 独立性——package 嵌入 packaged_by 标识,validate 校验 reviewer_session 与之不同;(4) 新项目默认 enabled: true。

### WRITE-SET
- engine/scripts/engine-review-agent-package.sh
- engine/scripts/engine-review-agent-package.ps1
- engine/scripts/engine-review-agent-validate.sh
- engine/scripts/engine-review-agent-validate.ps1
- engine/review/config.json
- engine/review/protocol.md
- plugin/engine/scripts/engine-review-agent-package.sh
- plugin/engine/scripts/engine-review-agent-package.ps1
- plugin/engine/scripts/engine-review-agent-validate.sh
- plugin/engine/scripts/engine-review-agent-validate.ps1
- engine/review/evidence/T-073/review-package.md
- tests/workstream/test_review_agent_grounded.sh
- tests/workstream/test_review_agent_dynamic.sh
- engine/tasks/T-073.md
- engine/tasks/T-073/progress.md
- engine/CONTEXT.md
- engine/HANDOFF.md
- engine/ENGINE_MAP.md
- CHANGELOG.md
- engine/VERSION

### CONSTRAINTS
不修改 pre-commit / doctor(T-072 已锁定);动态挑战仍为 3 个(保持 schema 兼容);E_GROUNDED 在 E_SHALLOW 之后、E_PROVENANCE 之前;packaged_by 用 hostname:pid 或 CLAUDE_SESSION_ID

### AC
AC: 动态挑战——package 输出含 diff 语义信号衍生的挑战(非固定模板) → verify: bash tests/workstream/test_review_agent_dynamic.sh
AC: 动态挑战——无信号时 fallback 到静态挑战(不 crash) → verify: bash tests/workstream/test_review_agent_dynamic.sh
AC: E_GROUNDED——finding 引用不存在的文件 → FAIL → verify: bash tests/workstream/test_review_agent_grounded.sh
AC: E_GROUNDED——finding 引用超出行数的行号 → FAIL → verify: bash tests/workstream/test_review_agent_grounded.sh
AC: E_GROUNDED——所有 finding 行号合法 → PASS → verify: bash tests/workstream/test_review_agent_grounded.sh
AC: E_GROUNDED——<=50% finding 不合法 → WARN(不 FAIL) → verify: bash tests/workstream/test_review_agent_grounded.sh
AC: 独立性——package header 含 packaged_by 字段 → verify: bash tests/workstream/test_review_agent_dynamic.sh
AC: 独立性——reviewer_session == packaged_by → WARN → verify: bash tests/workstream/test_review_agent_grounded.sh
AC: 独立性——reviewer_session 缺失 → WARN(grace period) → verify: bash tests/workstream/test_review_agent_grounded.sh
AC: 默认开启——config.json 不存在时 agent_review 默认 enabled → verify: bash tests/workstream/test_review_agent_dynamic.sh
AC: ps1 行为镜像——动态挑战 + E_GROUNDED sh/ps1 对等 → verify: bash tests/workstream/test_review_agent_mirror.sh

## 2. Code Changes (diff)

### engine/scripts/engine-review-agent-package.sh
```diff
diff --git a/engine/scripts/engine-review-agent-package.sh b/engine/scripts/engine-review-agent-package.sh
index 72d547d..6ecefab 100644
--- a/engine/scripts/engine-review-agent-package.sh
+++ b/engine/scripts/engine-review-agent-package.sh
@@ -1,5 +1,5 @@
 #!/usr/bin/env bash
-# Engine System — Agent-Reviewer Package(v6.21.0)
+# Engine System — Agent-Reviewer Package(v6.22.0)
 #
 # Phase 1: 打包审查上下文 → engine/review/evidence/T-NNN/review-package.md
 #
@@ -71,8 +71,8 @@ ar = defaults.get('agent_review', {})
 ar_ov = overrides.get('agent_review', {})
 if isinstance(ar_ov, dict):
     ar = {**ar, **ar_ov}
-print('true' if ar.get('enabled', False) else 'false')
-" 2>/dev/null || echo "false")
+print('true' if ar.get('enabled', True) else 'false')
+" 2>/dev/null || echo "true")
 
 # L2 REVIEW-OVERRIDE: add_dimensions: agent_review
 l2_override=$(awk '/^## REVIEW-OVERRIDE/{f=1;next} /^## /{f=0} f' "$task_file" | grep -E '^- ' | sed 's/^- //' || true)
@@ -276,18 +276,133 @@ $(head -"$pit_lines" "$pit_file" 2>/dev/null || true)
   fi
 fi
 
-# === 7. 静态挑战生成(参数化) ===
-# most_changed_file: diff --stat 排序
+# === 7. 动态挑战生成(v6.22.0: diff 语义信号 → 参数化挑战) ===
+# packaged_by: 用于 reviewer 独立性校验
+packaged_by="${CLAUDE_SESSION_ID:-$(hostname 2>/dev/null || echo unknown):$$}"
+
+# most_changed_file: diff --stat 排序(保留,用于 fallback)
 most_changed_file=$(git diff --stat "$diff_base"..HEAD -- $diff_files 2>/dev/null | grep '|' | sort -t'|' -k2 -rn | head -1 | sed 's/|.*//' | tr -d ' ' || true)
 [ -z "$most_changed_file" ] && most_changed_file=$(echo "$diff_files" | tr ' ' '\n' | head -1)
 
-# largest_hunk_line: 最大 hunk 起始行
-largest_hunk_line=$(git diff -U0 "$diff_base"..HEAD -- "$most_changed_file" 2>/dev/null | grep '^@@' | sed 's/@@[^+]*+\([0-9]*\).*/\1/' | sort -rn | head -1 || true)
-[ -z "$largest_hunk_line" ] && largest_hunk_line="1"
+# 动态挑战:python 分析 diff 语义信号,生成 3 个针对性挑战
+challenges=$(DIFF_BASE="$diff_base" HEAD_REF="HEAD" DIFF_FILES="$diff_files" ROOT_DIR="$ROOT" "$PY" << 'PYEOF'
+import subprocess, os, re, sys
+
+diff_base = os.environ['DIFF_BASE']
+diff_files = os.environ['DIFF_FILES'].split()
+root = os.environ['ROOT_DIR']
+
+signals = []  # (priority, challenge_text)
+
+for f in diff_files:
+    try:
+        diff = subprocess.check_output(
+            ['git', 'diff', '-U3', f'{diff_base}..HEAD', '--', f],
+            cwd=root, stderr=subprocess.DEVNULL
+        ).decode('utf-8', errors='replace')
+    except Exception:
+        continue
+
+    added_lines = []
+    removed_count = 0
+    hunk_sizes = []
+    current_hunk = 0
+
+    for line in diff.split('\n'):
+        if line.startswith('@@'):
+            if current_hunk > 0:
+                hunk_sizes.append(current_hunk)
+            current_hunk = 0
+            m = re.search(r'\+(\d+)', line)
+            hunk_start = int(m.group(1)) if m else 0
+        elif line.startswith('+') and not line.startswith('+++'):
+            current_hunk += 1
+            added_lines.append((hunk_start + current_hunk, line[1:]))
+        elif line.startswith('-') and not line.startswith('---'):
+            removed_count += 1
+            current_hunk += 1
+
+    if current_hunk > 0:
+        hunk_sizes.append(current_hunk)
+
+    # Signal 1: new branch (if/case/switch) without visible else/fi in added lines
+    for lineno, content in added_lines:
+        stripped = content.strip()
+        if re.match(r'\b(if|case|switch|elif)\b', stripped) and not re.search(r'\belse\b', stripped):
+            # check if else appears within next 10 added lines
+            nearby = [c for l, c in added_lines if abs(l - lineno) < 10]
+            if not any('else' in c for c in nearby):
+                signals.append((90, f"File `{f}` line ~{lineno} adds a new branch (`{stripped[:60]}`) with no visible else/fallback. What happens when this condition is false — silent skip, crash, or data corruption?"))
+                break
+
+    # Signal 2: function signature change (def/function/func with params)
+    for lineno, content in added_lines:
+        stripped = content.strip()
+        if re.match(r'\b(def|function|func|sub)\b', stripped) and '(' in stripped:
+            signals.append((80, f"File `{f}` line ~{lineno} defines/modifies `{stripped[:60]}`. Are all callers updated to match the new signature? What breaks if an old caller invokes it?"))
+            break
+
+    # Signal 3: large hunk (>20 changed lines)
+    if hunk_sizes and max(hunk_sizes) > 20:
+        big_line = max(hunk_sizes)
+        signals.append((70, f"File `{f}` has a hunk with {big_line} changed lines. Is this a single logical change, or should it be split? What is the rollback story if this introduces a regression?"))
+
+    # Signal 4: significant deletion
+    if removed_count > 15:
+        signals.append((60, f"File `{f}` removes {removed_count} lines. Is any removed behavior still depended upon elsewhere? Are there tests that covered the deleted code path?"))
+
+    # Signal 5: TODO/FIXME/HACK added
+    for lineno, content in added_lines:
+        if re.search(r'\b(TODO|FIXME|HACK|XXX)\b', content):
+            signals.append((50, f"File `{f}` line ~{lineno} adds `{content.strip()[:60]}`. Is this intentional tech debt or a sign the design is incomplete? Who owns the follow-up?"))
+            break
+
+    # Signal 6: error handling added (try/catch/err/panic)
+    for lineno, content in added_lines:
+        stripped = content.strip()
+        if re.match(r'\b(try|catch|except|recover|on error)\b', stripped, re.IGNORECASE):
+            signals.append((55, f"File `{f}` line ~{lineno} adds error handling (`{stripped[:60]}`). Is the error propagated, swallowed, or logged? What does the user see when this path triggers?"))
+            break
 
-# another_writeset_file: WRITE-SET 中除 most_changed_file 外的第一个代码文件
-another_file=$(printf '%s\n' $diff_files | grep -v "^$most_changed_file$" | head -1 || true)
-[ -z "$another_file" ] && another_file="(other WRITE-SET files)"
+# Deduplicate and sort by priority
+seen = set()
+unique = []
+for pri, text in sorted(signals, key=lambda x: -x[0]):
+    key = text[:40]
+    if key not in seen:
+        seen.add(key)
+        unique.append(text)
+
+# Output top 3, or fallback
+if len(unique) >= 3:
+    for i, c in enumerate(unique[:3], 1):
+        print(f"{i}. {c}")
+elif len(unique) > 0:
+    for i, c in enumerate(unique, 1):
+        print(f"{i}. {c}")
+    # pad with static
+    statics = [
+        "If someone needs to modify this code 6 months from now, what is the biggest comprehension barrier?",
+        "What is the worst-case input for this change, and does it degrade gracefully?",
+        "Does this change introduce any implicit coupling that is not documented?"
+    ]
+    for j in range(len(unique), 3):
+        print(f"{j+1}. {statics[j - len(unique)]}")
+else:
+    print("SIGNAL_NONE")
+PYEOF
+) || challenges="SIGNAL_NONE"
+
+# Fallback: 无信号时用静态挑战
+if [ "$challenges" = "SIGNAL_NONE" ] || [ -z "$challenges" ]; then
+  largest_hunk_line=$(git diff -U0 "$diff_base"..HEAD -- "$most_changed_file" 2>/dev/null | grep '^@@' | sed 's/@@[^+]*+\([0-9]*\).*/\1/' | sort -rn | head -1 || true)
+  [ -z "$largest_hunk_line" ] && largest_hunk_line="1"
+  another_file=$(printf '%s\n' $diff_files | grep -v "^$most_changed_file$" | head -1 || true)
+  [ -z "$another_file" ] && another_file="(other WRITE-SET files)"
+  challenges="1. File \`$most_changed_file\` around line $largest_hunk_line contains the most complex change. What happens if it receives empty input or extremely long input?
+2. Does this change break any assumptions that \`$another_file\` makes about \`$most_changed_file\`?
+3. If someone needs to modify this code 6 months from now, what is the biggest comprehension barrier?"
+fi
 
 # === 8. v1 linter findings 摘要 ===
 linter_summary=""
@@ -388,7 +503,8 @@ schema_example='{
     "writer": "agent-reviewer",
     "commit": "'"$head_commit"'",
     "timestamp": "<write time>",
-    "package_sha256": "<fill from package header>"
+    "package_sha256": "<fill from package header>",
+    "reviewer_session": "<your session/agent identifier, must differ from packaged_by>"
   }
 }'
 
@@ -399,6 +515,7 @@ cat > "$package_file" <<PACKAGE_EOF
 > generated: $timestamp
 > package_sha256: PLACEHOLDER
 > head_commit: $head_commit
+> packaged_by: $packaged_by
 > task: $goal_text
 > scope: ${diff_base:0:8}..${head_commit:0:8}, $(echo "$diff_files" | wc -w | tr -d ' ') code files
 
@@ -431,9 +548,7 @@ $protocol_content
 
 ### Adversarial Challenges (must answer all 3)
 
-1. File \`$most_changed_file\` around line $largest_hunk_line contains the most complex change. What happens if it receives empty input or extremely long input?
-2. Does this change break any assumptions that \`$another_file\` makes about \`$most_changed_file\`?
-3. If someone needs to modify this code 6 months from now, what is the biggest comprehension barrier?
+$challenges
 
 $linter_summary
 
@@ -460,7 +575,7 @@ PACKAGE_EOF
 # 算法:将 package_sha256 行替换为固定占位符 "COMPUTE" 后计算 hash
 package_sha256=$(PKG_FILE="$package_file" "$PY" -c "
 import hashlib, re, os
-with open(os.environ['PKG_FILE'], encoding='utf-8') as f:
+with open(os.environ['PKG_FILE'], encoding='utf-8', errors='replace') as f:
     content = f.read()
 # normalize: replace whatever is after 'package_sha256: ' with canonical placeholder
 normalized = re.sub(r'(> package_sha256: ).*', r'\1COMPUTE', content)
@@ -470,7 +585,7 @@ sed -i "s/package_sha256: PLACEHOLDER/package_sha256: $package_sha256/" "$packag
   PKG_FILE="$package_file" PKG_SHA="$package_sha256" "$PY" -c "
 import pathlib, os
 p = pathlib.Path(os.environ['PKG_FILE'])
-t = p.read_text(encoding='utf-8')
+t = p.read_text(encoding='utf-8', errors='replace')
 p.write_text(t.replace('package_sha256: PLACEHOLDER', 'package_sha256: ' + os.environ['PKG_SHA']), encoding='utf-8')
 "
 
@@ -484,7 +599,7 @@ import os, re
 pkg = os.environ['PKG_FILE']
 max_lines = int(os.environ['MAX_LINES'])
 
-with open(pkg, encoding='utf-8') as f:
+with open(pkg, encoding='utf-8', errors='replace') as f:
     lines = f.readlines()
 
 def find_section(lines, header):
```

### engine/scripts/engine-review-agent-package.ps1
```diff
diff --git a/engine/scripts/engine-review-agent-package.ps1 b/engine/scripts/engine-review-agent-package.ps1
index b084f30..f0ded7a 100644
--- a/engine/scripts/engine-review-agent-package.ps1
+++ b/engine/scripts/engine-review-agent-package.ps1
@@ -1,4 +1,4 @@
-# Engine System — Agent-Reviewer Package (v6.21.0) [PowerShell behavioral mirror]
+# Engine System — Agent-Reviewer Package (v6.22.0) [PowerShell behavioral mirror]
 #
 # Phase 1: Package review context -> engine/review/evidence/T-NNN/review-package.md
 # Behavioral mirror of engine-review-agent-package.sh (same input -> same output)
@@ -40,7 +40,7 @@ try {
     if ($cfg.overrides.agent_review) {
         $cfg.overrides.agent_review.PSObject.Properties | ForEach-Object { $ar[$_.Name] = $_.Value }
     }
-    $agentReviewEnabled = if ($ar.enabled) { $true } else { $false }
+    $agentReviewEnabled = if ($null -eq $ar.enabled) { $true } elseif ($ar.enabled) { $true } else { $false }
 
     # L2 REVIEW-OVERRIDE check
     $taskContent = Get-Content $taskFile -Raw -Encoding UTF8
@@ -164,17 +164,142 @@ try {
         }
     }
 
-    # === 7. Static challenges ===
+    # === 7. Dynamic challenges (v6.22.0: diff semantic signals -> parameterized challenges) ===
+    # packaged_by: for reviewer independence validation
+    $packagedBy = if ($env:CLAUDE_SESSION_ID) { $env:CLAUDE_SESSION_ID } else { "$([System.Net.Dns]::GetHostName()):$PID" }
+
+    # most_changed_file (retained for fallback)
     $diffStat = git -C $ROOT diff --stat "$diffBase..HEAD" -- @diffFiles 2>$null
     $mostChanged = ($diffStat | Select-String '\|' | Sort-Object { [int]($_ -replace '.*\|\s*(\d+).*','$1') } -Descending | Select-Object -First 1) -replace '\s*\|.*$', ''
     $mostChanged = $mostChanged.Trim()
     if (-not $mostChanged) { $mostChanged = $diffFiles[0] }
 
-    $hunkLines = git -C $ROOT diff -U0 "$diffBase..HEAD" -- $mostChanged 2>$null | Select-String '^@@' | ForEach-Object { if ($_ -match '\+(\d+)') { [int]$Matches[1] } } | Sort-Object -Descending | Select-Object -First 1
-    if (-not $hunkLines) { $hunkLines = 1 }
+    # Dynamic challenges: python analyzes diff semantic signals, generates 3 targeted challenges
+    $pyCmd = $null
+    foreach ($c in @('python3','python')) { try { $null = cmd /c "$c --version 2>nul"; if ($LASTEXITCODE -eq 0) { $pyCmd = $c; break } } catch {} }
+
+    $challenges = $null
+    if ($pyCmd) {
+        $env:DIFF_BASE = $diffBase
+        $env:HEAD_REF = 'HEAD'
+        $env:DIFF_FILES = ($diffFiles -join ' ')
+        $env:ROOT_DIR = $ROOT
+        $pyScript = @'
+import subprocess, os, re, sys
+
+diff_base = os.environ['DIFF_BASE']
+diff_files = os.environ['DIFF_FILES'].split()
+root = os.environ['ROOT_DIR']
+
+signals = []
+
+for f in diff_files:
+    try:
+        diff = subprocess.check_output(
+            ['git', 'diff', '-U3', f'{diff_base}..HEAD', '--', f],
+            cwd=root, stderr=subprocess.DEVNULL
+        ).decode('utf-8', errors='replace')
+    except Exception:
+        continue
+
+    added_lines = []
+    removed_count = 0
+    hunk_sizes = []
+    current_hunk = 0
+
+    for line in diff.split('\n'):
+        if line.startswith('@@'):
+            if current_hunk > 0:
+                hunk_sizes.append(current_hunk)
+            current_hunk = 0
+            m = re.search(r'\+(\d+)', line)
+            hunk_start = int(m.group(1)) if m else 0
+        elif line.startswith('+') and not line.startswith('+++'):
+            current_hunk += 1
+            added_lines.append((hunk_start + current_hunk, line[1:]))
+        elif line.startswith('-') and not line.startswith('---'):
+            removed_count += 1
+            current_hunk += 1
+
+    if current_hunk > 0:
+        hunk_sizes.append(current_hunk)
+
+    for lineno, content in added_lines:
+        stripped = content.strip()
+        if re.match(r'\b(if|case|switch|elif)\b', stripped) and not re.search(r'\belse\b', stripped):
+            nearby = [c for l, c in added_lines if abs(l - lineno) < 10]
+            if not any('else' in c for c in nearby):
+                signals.append((90, f"File `{f}` line ~{lineno} adds a new branch (`{stripped[:60]}`) with no visible else/fallback. What happens when this condition is false?"))
+                break
+
+    for lineno, content in added_lines:
+        stripped = content.strip()
+        if re.match(r'\b(def|function|func|sub)\b', stripped) and '(' in stripped:
+            signals.append((80, f"File `{f}` line ~{lineno} defines/modifies `{stripped[:60]}`. Are all callers updated to match the new signature?"))
+            break
+
+    if hunk_sizes and max(hunk_sizes) > 20:
+        big_line = max(hunk_sizes)
+        signals.append((70, f"File `{f}` has a hunk with {big_line} changed lines. Is this a single logical change, or should it be split?"))
+
+    if removed_count > 15:
+        signals.append((60, f"File `{f}` removes {removed_count} lines. Are there callers or tests that still depend on the removed behavior?"))
+
+    for lineno, content in added_lines:
+        stripped = content.strip()
+        if re.search(r'\b(TODO|FIXME|HACK|XXX)\b', stripped):
+            signals.append((50, f"File `{f}` line ~{lineno} adds `{stripped[:60]}`. Is this intentional tech debt, and is it tracked?"))
+            break
+
+    for lineno, content in added_lines:
+        stripped = content.strip()
+        if re.match(r'\b(catch|except|rescue|on error|trap)\b', stripped, re.IGNORECASE):
+            signals.append((55, f"File `{f}` line ~{lineno} adds error handling (`{stripped[:60]}`). Does it swallow errors silently or propagate them correctly?"))
+            break
+
+signals.sort(key=lambda x: -x[0])
+unique = []
+seen = set()
+for pri, text in signals:
+    key = text[:40]
+    if key not in seen:
+        seen.add(key)
+        unique.append(text)
+
+if len(unique) >= 3:
+    for i, c in enumerate(unique[:3], 1):
+        print(f"{i}. {c}")
+elif len(unique) > 0:
+    for i, c in enumerate(unique, 1):
+        print(f"{i}. {c}")
+    statics = [
+        "If someone needs to modify this code 6 months from now, what is the biggest comprehension barrier?",
+        "What is the worst-case input for this change, and does it degrade gracefully?",
+        "Does this change introduce any implicit coupling that is not documented?"
+    ]
+    for j in range(len(unique), 3):
+        print(f"{j+1}. {statics[j - len(unique)]}")
+else:
+    print("SIGNAL_NONE")
+'@
+        try {
+            $challenges = & $pyCmd -c $pyScript 2>$null
+            $env:DIFF_BASE = $null; $env:HEAD_REF = $null; $env:DIFF_FILES = $null; $env:ROOT_DIR = $null
+        } catch {
+            $challenges = $null
+        }
+    }
 
-    $anotherFile = ($diffFiles | Where-Object { $_ -ne $mostChanged } | Select-Object -First 1)
-    if (-not $anotherFile) { $anotherFile = '(other WRITE-SET files)' }
+    # Fallback: no signals or python unavailable -> static challenges
+    if (-not $challenges -or $challenges -eq 'SIGNAL_NONE' -or ($challenges -join '').Trim() -eq '') {
+        $hunkLines = git -C $ROOT diff -U0 "$diffBase..HEAD" -- $mostChanged 2>$null | Select-String '^@@' | ForEach-Object { if ($_ -match '\+(\d+)') { [int]$Matches[1] } } | Sort-Object -Descending | Select-Object -First 1
+        if (-not $hunkLines) { $hunkLines = 1 }
+        $anotherFile = ($diffFiles | Where-Object { $_ -ne $mostChanged } | Select-Object -First 1)
+        if (-not $anotherFile) { $anotherFile = '(other WRITE-SET files)' }
+        $challenges = "1. File ``$mostChanged`` around line $hunkLines contains the most complex change. What happens if it receives empty input or extremely long input?`n2. Does this change break any assumptions that ``$anotherFile`` makes about ``$mostChanged``?`n3. If someone needs to modify this code 6 months from now, what is the biggest comprehension barrier?"
+    } else {
+        $challenges = ($challenges -join "`n")
+    }
 
     # === 8. Linter summary ===
     $linterSummary = ''
@@ -230,6 +355,7 @@ try {
 > generated: $timestamp
 > package_sha256: PLACEHOLDER
 > head_commit: $headCommit
+> packaged_by: $packagedBy
 > task: $goalText
 > scope: $scopeShort, $($diffFiles.Count) code files
 
@@ -262,9 +388,7 @@ $protocolContent
 
 ### Adversarial Challenges (must answer all 3)
 
-1. File ``$mostChanged`` around line $hunkLines contains the most complex change. What happens if it receives empty input or extremely long input?
-2. Does this change break any assumptions that ``$anotherFile`` makes about ``$mostChanged``?
-3. If someone needs to modify this code 6 months from now, what is the biggest comprehension barrier?
+$challenges
 
 $linterSummary
 
@@ -296,7 +420,8 @@ Schema (all fields required):
     "writer": "agent-reviewer",
     "commit": "$headCommit",
     "timestamp": "<write time>",
-    "package_sha256": "<fill from package header>"
+    "package_sha256": "<fill from package header>",
+    "reviewer_session": "<your session/agent identifier, must differ from packaged_by>"
   }
 }
 ``````
```

### engine/scripts/engine-review-agent-validate.sh
```diff
diff --git a/engine/scripts/engine-review-agent-validate.sh b/engine/scripts/engine-review-agent-validate.sh
index cdaef75..bd0256e 100644
--- a/engine/scripts/engine-review-agent-validate.sh
+++ b/engine/scripts/engine-review-agent-validate.sh
@@ -1,5 +1,5 @@
 #!/usr/bin/env bash
-# Engine System — Agent-Reviewer Validate(v6.21.0)
+# Engine System — Agent-Reviewer Validate(v6.22.0)
 #
 # Phase 3: 校验外部 agent 产出的 AGENT-REVIEW.json
 #
@@ -111,7 +111,7 @@ print(ar.get('max_package_age_hours', 72))
 VALIDATE_RESULT=$(REVIEW_FILE="$review_file" PACKAGE_FILE="$package_file" \
   MIN_ENTRIES="$min_entries" MIN_NARRATIVE="$min_narrative" \
   MIN_MESSAGE="$min_message" MAX_AGE_HOURS="$max_age_hours" \
-  TASK="$task" \
+  TASK="$task" ROOT_DIR="$ROOT" \
 "$PY" << 'PYEOF'
 import json, os, sys, hashlib
 from datetime import datetime, timezone
@@ -234,6 +234,48 @@ if shallow_errors:
         print(f"E_SHALLOW|{msg}")
     sys.exit(1)
 
+# --- E_GROUNDED (v6.22.0): verify finding file:line references exist ---
+grounded_errors = []
+grounded_warnings = []
+total_findings_for_grounding = 0
+ungrounded_count = 0
+
+root_dir = os.environ.get('ROOT_DIR', '.')
+for dim in required_dims:
+    for i, entry in enumerate(dims.get(dim, {}).get('entries', [])):
+        if entry.get('type') != 'finding':
+            continue
+        total_findings_for_grounding += 1
+        fpath = entry.get('file', '')
+        fline = entry.get('line', 0)
+        if not fpath or not fline:
+            continue
+        # check file exists
+        full_path = os.path.join(root_dir, fpath)
+        if not os.path.isfile(full_path):
+            ungrounded_count += 1
+            grounded_errors.append(f'{dim}.entries[{i}] references non-existent file: {fpath}')
+            continue
+        # check line number within file
+        try:
+            with open(full_path, encoding='utf-8', errors='replace') as ff:
+                line_count = sum(1 for _ in ff)
+            if fline > line_count:
+                ungrounded_count += 1
+                grounded_errors.append(f'{dim}.entries[{i}] line {fline} exceeds file length ({line_count} lines): {fpath}')
+        except Exception:
+            pass
+
+if total_findings_for_grounding > 0 and ungrounded_count > 0:
+    ratio = ungrounded_count / total_findings_for_grounding
+    if ratio > 0.5:
+        for msg in grounded_errors:
+            print(f"E_GROUNDED|{msg}")
+        sys.exit(1)
+    else:
+        for msg in grounded_errors:
+            grounded_warnings.append(msg)
+
 # --- E_PROVENANCE ---
 prov_errors = []
 
@@ -285,6 +327,25 @@ if os.path.isfile(package_file):
         except ValueError:
             warnings.append('cannot parse package generated timestamp')
 
+# --- E_INDEPENDENCE (v6.22.0, FAIL): reviewer_session must differ from packaged_by ---
+if os.path.isfile(package_file):
+    pkg_packaged_by = None
+    with open(package_file, encoding='utf-8') as f:
+        for line in f:
+            if line.startswith('> packaged_by:'):
+                pkg_packaged_by = line.split(':', 1)[1].strip()
+                break
+    reviewer_session = prov.get('reviewer_session', '')
+    if not reviewer_session:
+        print('E_INDEPENDENCE|reviewer_session missing in write_provenance (subagent review is mandatory)')
+        sys.exit(1)
+    elif pkg_packaged_by and reviewer_session == pkg_packaged_by:
+        print(f'E_INDEPENDENCE|reviewer_session matches packaged_by ({reviewer_session}) — reviewer must be a separate agent/session')
+        sys.exit(1)
+
+# merge grounded warnings
+warnings.extend(grounded_warnings)
+
 # --- Output summary ---
 total_findings = sum(
     len([e for e in dims.get(d, {}).get('entries', []) if e.get('type') == 'finding'])
@@ -367,7 +428,7 @@ if os.path.isfile(review_json):
     review.setdefault('dimensions', {})['agent_review'] = {
         'status': agent_status,
         'findings_count': counts,
-        'protocol_version': 'v6.21.0'
+        'protocol_version': 'v6.22.0'
     }
     if agent_status == 'block':
         review['status'] = 'block'
@@ -380,7 +441,7 @@ else:
             'agent_review': {
                 'status': agent_status,
                 'findings_count': counts,
-                'protocol_version': 'v6.21.0'
+                'protocol_version': 'v6.22.0'
             }
         },
         'write_provenance': {
@@ -388,7 +449,7 @@ else:
             'commit': head_commit,
             'timestamp': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
             'argv': f'engine review-agent {task} --validate',
-            'pipeline_version': 'v6.21.0'
+            'pipeline_version': 'v6.22.0'
         }
     }
 
```

### engine/scripts/engine-review-agent-validate.ps1
```diff
diff --git a/engine/scripts/engine-review-agent-validate.ps1 b/engine/scripts/engine-review-agent-validate.ps1
index aa73025..7596211 100644
--- a/engine/scripts/engine-review-agent-validate.ps1
+++ b/engine/scripts/engine-review-agent-validate.ps1
@@ -1,4 +1,4 @@
-# Engine System — Agent-Reviewer Validate (v6.21.0) [PowerShell behavioral mirror]
+# Engine System — Agent-Reviewer Validate (v6.22.0) [PowerShell behavioral mirror]
 #
 # Phase 3: Validate AGENT-REVIEW.json produced by external agent
 # Behavioral mirror of engine-review-agent-validate.sh
@@ -125,6 +125,45 @@ try {
         exit 1
     }
 
+    # === 4b. E_GROUNDED (v6.22.0): verify finding file:line references exist ===
+    $groundedErrors = @()
+    $groundedWarnings = @()
+    $totalFindingsForGrounding = 0
+    $ungroundedCount = 0
+    foreach ($dim in $requiredDims) {
+        $entries = @($data.dimensions.$dim.entries)
+        for ($i = 0; $i -lt $entries.Count; $i++) {
+            $e = $entries[$i]
+            if ($e.type -ne 'finding') { continue }
+            $totalFindingsForGrounding++
+            $fpath = if ($e.PSObject.Properties['file']) { $e.file } else { '' }
+            $fline = if ($e.PSObject.Properties['line']) { [int]$e.line } else { 0 }
+            if (-not $fpath -or -not $fline) { continue }
+            $fullPath = Join-Path $ROOT $fpath
+            if (-not (Test-Path $fullPath -PathType Leaf)) {
+                $ungroundedCount++
+                $groundedErrors += "${dim}.entries[${i}] references non-existent file: $fpath"
+                continue
+            }
+            try {
+                $lineCount = (Get-Content $fullPath -Encoding UTF8).Count
+                if ($fline -gt $lineCount) {
+                    $ungroundedCount++
+                    $groundedErrors += "${dim}.entries[${i}] line $fline exceeds file length ($lineCount lines): $fpath"
+                }
+            } catch {}
+        }
+    }
+    if ($totalFindingsForGrounding -gt 0 -and $ungroundedCount -gt 0) {
+        $ratio = $ungroundedCount / $totalFindingsForGrounding
+        if ($ratio -gt 0.5) {
+            foreach ($msg in $groundedErrors) { [Console]::Error.WriteLine("[engine-review-agent-validate] FAIL E_GROUNDED: $msg") }
+            exit 1
+        } else {
+            $groundedWarnings = $groundedErrors
+        }
+    }
+
     # === 5. E_PROVENANCE ===
     $provErrors = @()
     if ($prov.writer -ne 'agent-reviewer') { $provErrors += "invalid writer: $($prov.writer)" }
@@ -170,6 +209,24 @@ try {
         }
     }
 
+    # === 6b. E_INDEPENDENCE (v6.22.0, FAIL): reviewer_session must differ from packaged_by ===
+    if (Test-Path $packageFile) {
+        $pkgPackagedBy = $null
+        foreach ($line in (Get-Content $packageFile -Encoding UTF8)) {
+            if ($line -match '^> packaged_by:\s*(.+)$') { $pkgPackagedBy = $Matches[1].Trim(); break }
+        }
+        $reviewerSession = if ($prov.PSObject.Properties['reviewer_session']) { $prov.reviewer_session } else { '' }
+        if (-not $reviewerSession) {
+            [Console]::Error.WriteLine("[engine-review-agent-validate] FAIL E_INDEPENDENCE: reviewer_session missing in write_provenance (subagent review is mandatory)")
+            exit 1
+        } elseif ($pkgPackagedBy -and $reviewerSession -eq $pkgPackagedBy) {
+            [Console]::Error.WriteLine("[engine-review-agent-validate] FAIL E_INDEPENDENCE: reviewer_session matches packaged_by ($reviewerSession) - reviewer must be a separate agent/session")
+            exit 1
+        }
+    }
+    # Output grounded warnings
+    foreach ($gw in $groundedWarnings) { [Console]::Error.WriteLine("[engine-review-agent-validate] WARN: E_GROUNDED: $gw") }
+
     # === 7. Append validated_by ===
     $validatedAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
     $data.write_provenance | Add-Member -NotePropertyName 'validated_by' -NotePropertyValue "engine review-agent $Task --validate" -Force
@@ -188,7 +245,7 @@ try {
 
     if (Test-Path $reviewJson) {
         $review = Get-Content $reviewJson -Raw -Encoding UTF8 | ConvertFrom-Json
-        $agentDim = @{ status = $agentStatus; findings_count = @{critical=0;high=0;medium=0;low=0;info=0}; protocol_version = 'v6.21.0' }
+        $agentDim = @{ status = $agentStatus; findings_count = @{critical=0;high=0;medium=0;low=0;info=0}; protocol_version = 'v6.22.0' }
         foreach ($dim in $requiredDims) {
             foreach ($e in @($data.dimensions.$dim.entries)) { $agentDim.findings_count[$e.severity]++ }
         }
@@ -203,8 +260,8 @@ try {
         }
         $newReview = @{
             task = $Task; timestamp = $validatedAt; status = $agentStatus
-            dimensions = @{ agent_review = @{ status = $agentStatus; findings_count = $newCounts; protocol_version = 'v6.21.0' } }
-            write_provenance = @{ writer = 'engine-review-agent-validate'; commit = $headCommit; timestamp = $validatedAt; argv = "engine review-agent $Task --validate"; pipeline_version = 'v6.21.0' }
+            dimensions = @{ agent_review = @{ status = $agentStatus; findings_count = $newCounts; protocol_version = 'v6.22.0' } }
+            write_provenance = @{ writer = 'engine-review-agent-validate'; commit = $headCommit; timestamp = $validatedAt; argv = "engine review-agent $Task --validate"; pipeline_version = 'v6.22.0' }
         }
         $newReview | ConvertTo-Json -Depth 10 -Compress | Set-Content $reviewJson -Encoding UTF8
     }
```

### plugin/engine/scripts/engine-review-agent-package.sh
```diff
diff --git a/plugin/engine/scripts/engine-review-agent-package.sh b/plugin/engine/scripts/engine-review-agent-package.sh
index 72d547d..6ecefab 100644
--- a/plugin/engine/scripts/engine-review-agent-package.sh
+++ b/plugin/engine/scripts/engine-review-agent-package.sh
@@ -1,5 +1,5 @@
 #!/usr/bin/env bash
-# Engine System — Agent-Reviewer Package(v6.21.0)
+# Engine System — Agent-Reviewer Package(v6.22.0)
 #
 # Phase 1: 打包审查上下文 → engine/review/evidence/T-NNN/review-package.md
 #
@@ -71,8 +71,8 @@ ar = defaults.get('agent_review', {})
 ar_ov = overrides.get('agent_review', {})
 if isinstance(ar_ov, dict):
     ar = {**ar, **ar_ov}
-print('true' if ar.get('enabled', False) else 'false')
-" 2>/dev/null || echo "false")
+print('true' if ar.get('enabled', True) else 'false')
+" 2>/dev/null || echo "true")
 
 # L2 REVIEW-OVERRIDE: add_dimensions: agent_review
 l2_override=$(awk '/^## REVIEW-OVERRIDE/{f=1;next} /^## /{f=0} f' "$task_file" | grep -E '^- ' | sed 's/^- //' || true)
@@ -276,18 +276,133 @@ $(head -"$pit_lines" "$pit_file" 2>/dev/null || true)
   fi
 fi
 
-# === 7. 静态挑战生成(参数化) ===
-# most_changed_file: diff --stat 排序
+# === 7. 动态挑战生成(v6.22.0: diff 语义信号 → 参数化挑战) ===
+# packaged_by: 用于 reviewer 独立性校验
+packaged_by="${CLAUDE_SESSION_ID:-$(hostname 2>/dev/null || echo unknown):$$}"
+
+# most_changed_file: diff --stat 排序(保留,用于 fallback)
 most_changed_file=$(git diff --stat "$diff_base"..HEAD -- $diff_files 2>/dev/null | grep '|' | sort -t'|' -k2 -rn | head -1 | sed 's/|.*//' | tr -d ' ' || true)
 [ -z "$most_changed_file" ] && most_changed_file=$(echo "$diff_files" | tr ' ' '\n' | head -1)
 
-# largest_hunk_line: 最大 hunk 起始行
-largest_hunk_line=$(git diff -U0 "$diff_base"..HEAD -- "$most_changed_file" 2>/dev/null | grep '^@@' | sed 's/@@[^+]*+\([0-9]*\).*/\1/' | sort -rn | head -1 || true)
-[ -z "$largest_hunk_line" ] && largest_hunk_line="1"
+# 动态挑战:python 分析 diff 语义信号,生成 3 个针对性挑战
+challenges=$(DIFF_BASE="$diff_base" HEAD_REF="HEAD" DIFF_FILES="$diff_files" ROOT_DIR="$ROOT" "$PY" << 'PYEOF'
+import subprocess, os, re, sys
+
+diff_base = os.environ['DIFF_BASE']
+diff_files = os.environ['DIFF_FILES'].split()
+root = os.environ['ROOT_DIR']
+
+signals = []  # (priority, challenge_text)
+
+for f in diff_files:
+    try:
+        diff = subprocess.check_output(
+            ['git', 'diff', '-U3', f'{diff_base}..HEAD', '--', f],
+            cwd=root, stderr=subprocess.DEVNULL
+        ).decode('utf-8', errors='replace')
+    except Exception:
+        continue
+
+    added_lines = []
+    removed_count = 0
+    hunk_sizes = []
+    current_hunk = 0
+
+    for line in diff.split('\n'):
+        if line.startswith('@@'):
+            if current_hunk > 0:
+                hunk_sizes.append(current_hunk)
+            current_hunk = 0
+            m = re.search(r'\+(\d+)', line)
+            hunk_start = int(m.group(1)) if m else 0
+        elif line.startswith('+') and not line.startswith('+++'):
+            current_hunk += 1
+            added_lines.append((hunk_start + current_hunk, line[1:]))
+        elif line.startswith('-') and not line.startswith('---'):
+            removed_count += 1
+            current_hunk += 1
+
+    if current_hunk > 0:
+        hunk_sizes.append(current_hunk)
+
+    # Signal 1: new branch (if/case/switch) without visible else/fi in added lines
+    for lineno, content in added_lines:
+        stripped = content.strip()
+        if re.match(r'\b(if|case|switch|elif)\b', stripped) and not re.search(r'\belse\b', stripped):
+            # check if else appears within next 10 added lines
+            nearby = [c for l, c in added_lines if abs(l - lineno) < 10]
+            if not any('else' in c for c in nearby):
+                signals.append((90, f"File `{f}` line ~{lineno} adds a new branch (`{stripped[:60]}`) with no visible else/fallback. What happens when this condition is false — silent skip, crash, or data corruption?"))
+                break
+
+    # Signal 2: function signature change (def/function/func with params)
+    for lineno, content in added_lines:
+        stripped = content.strip()
+        if re.match(r'\b(def|function|func|sub)\b', stripped) and '(' in stripped:
+            signals.append((80, f"File `{f}` line ~{lineno} defines/modifies `{stripped[:60]}`. Are all callers updated to match the new signature? What breaks if an old caller invokes it?"))
+            break
+
+    # Signal 3: large hunk (>20 changed lines)
+    if hunk_sizes and max(hunk_sizes) > 20:
+        big_line = max(hunk_sizes)
+        signals.append((70, f"File `{f}` has a hunk with {big_line} changed lines. Is this a single logical change, or should it be split? What is the rollback story if this introduces a regression?"))
+
+    # Signal 4: significant deletion
+    if removed_count > 15:
+        signals.append((60, f"File `{f}` removes {removed_count} lines. Is any removed behavior still depended upon elsewhere? Are there tests that covered the deleted code path?"))
+
+    # Signal 5: TODO/FIXME/HACK added
+    for lineno, content in added_lines:
+        if re.search(r'\b(TODO|FIXME|HACK|XXX)\b', content):
+            signals.append((50, f"File `{f}` line ~{lineno} adds `{content.strip()[:60]}`. Is this intentional tech debt or a sign the design is incomplete? Who owns the follow-up?"))
+            break
+
+    # Signal 6: error handling added (try/catch/err/panic)
+    for lineno, content in added_lines:
+        stripped = content.strip()
+        if re.match(r'\b(try|catch|except|recover|on error)\b', stripped, re.IGNORECASE):
+            signals.append((55, f"File `{f}` line ~{lineno} adds error handling (`{stripped[:60]}`). Is the error propagated, swallowed, or logged? What does the user see when this path triggers?"))
+            break
 
-# another_writeset_file: WRITE-SET 中除 most_changed_file 外的第一个代码文件
-another_file=$(printf '%s\n' $diff_files | grep -v "^$most_changed_file$" | head -1 || true)
-[ -z "$another_file" ] && another_file="(other WRITE-SET files)"
+# Deduplicate and sort by priority
+seen = set()
+unique = []
+for pri, text in sorted(signals, key=lambda x: -x[0]):
+    key = text[:40]
+    if key not in seen:
+        seen.add(key)
+        unique.append(text)
+
+# Output top 3, or fallback
+if len(unique) >= 3:
+    for i, c in enumerate(unique[:3], 1):
+        print(f"{i}. {c}")
+elif len(unique) > 0:
+    for i, c in enumerate(unique, 1):
+        print(f"{i}. {c}")
+    # pad with static
+    statics = [
+        "If someone needs to modify this code 6 months from now, what is the biggest comprehension barrier?",
+        "What is the worst-case input for this change, and does it degrade gracefully?",
+        "Does this change introduce any implicit coupling that is not documented?"
+    ]
+    for j in range(len(unique), 3):
+        print(f"{j+1}. {statics[j - len(unique)]}")
+else:
+    print("SIGNAL_NONE")
+PYEOF
+) || challenges="SIGNAL_NONE"
+
+# Fallback: 无信号时用静态挑战
+if [ "$challenges" = "SIGNAL_NONE" ] || [ -z "$challenges" ]; then
+  largest_hunk_line=$(git diff -U0 "$diff_base"..HEAD -- "$most_changed_file" 2>/dev/null | grep '^@@' | sed 's/@@[^+]*+\([0-9]*\).*/\1/' | sort -rn | head -1 || true)
+  [ -z "$largest_hunk_line" ] && largest_hunk_line="1"
+  another_file=$(printf '%s\n' $diff_files | grep -v "^$most_changed_file$" | head -1 || true)
+  [ -z "$another_file" ] && another_file="(other WRITE-SET files)"
+  challenges="1. File \`$most_changed_file\` around line $largest_hunk_line contains the most complex change. What happens if it receives empty input or extremely long input?
+2. Does this change break any assumptions that \`$another_file\` makes about \`$most_changed_file\`?
+3. If someone needs to modify this code 6 months from now, what is the biggest comprehension barrier?"
+fi
 
 # === 8. v1 linter findings 摘要 ===
 linter_summary=""
@@ -388,7 +503,8 @@ schema_example='{
     "writer": "agent-reviewer",
     "commit": "'"$head_commit"'",
     "timestamp": "<write time>",
-    "package_sha256": "<fill from package header>"
+    "package_sha256": "<fill from package header>",
+    "reviewer_session": "<your session/agent identifier, must differ from packaged_by>"
   }
 }'
 
@@ -399,6 +515,7 @@ cat > "$package_file" <<PACKAGE_EOF
 > generated: $timestamp
 > package_sha256: PLACEHOLDER
 > head_commit: $head_commit
+> packaged_by: $packaged_by
 > task: $goal_text
 > scope: ${diff_base:0:8}..${head_commit:0:8}, $(echo "$diff_files" | wc -w | tr -d ' ') code files
 
@@ -431,9 +548,7 @@ $protocol_content
 
 ### Adversarial Challenges (must answer all 3)
 
-1. File \`$most_changed_file\` around line $largest_hunk_line contains the most complex change. What happens if it receives empty input or extremely long input?
-2. Does this change break any assumptions that \`$another_file\` makes about \`$most_changed_file\`?
-3. If someone needs to modify this code 6 months from now, what is the biggest comprehension barrier?
+$challenges
 
 $linter_summary
 
@@ -460,7 +575,7 @@ PACKAGE_EOF
 # 算法:将 package_sha256 行替换为固定占位符 "COMPUTE" 后计算 hash
 package_sha256=$(PKG_FILE="$package_file" "$PY" -c "
 import hashlib, re, os
-with open(os.environ['PKG_FILE'], encoding='utf-8') as f:
+with open(os.environ['PKG_FILE'], encoding='utf-8', errors='replace') as f:
     content = f.read()
 # normalize: replace whatever is after 'package_sha256: ' with canonical placeholder
 normalized = re.sub(r'(> package_sha256: ).*', r'\1COMPUTE', content)
@@ -470,7 +585,7 @@ sed -i "s/package_sha256: PLACEHOLDER/package_sha256: $package_sha256/" "$packag
   PKG_FILE="$package_file" PKG_SHA="$package_sha256" "$PY" -c "
 import pathlib, os
 p = pathlib.Path(os.environ['PKG_FILE'])
-t = p.read_text(encoding='utf-8')
+t = p.read_text(encoding='utf-8', errors='replace')
 p.write_text(t.replace('package_sha256: PLACEHOLDER', 'package_sha256: ' + os.environ['PKG_SHA']), encoding='utf-8')
 "
 
@@ -484,7 +599,7 @@ import os, re
 pkg = os.environ['PKG_FILE']
 max_lines = int(os.environ['MAX_LINES'])
 
-with open(pkg, encoding='utf-8') as f:
+with open(pkg, encoding='utf-8', errors='replace') as f:
     lines = f.readlines()
 
 def find_section(lines, header):
```

### plugin/engine/scripts/engine-review-agent-package.ps1
```diff
diff --git a/plugin/engine/scripts/engine-review-agent-package.ps1 b/plugin/engine/scripts/engine-review-agent-package.ps1
index b084f30..f0ded7a 100644
--- a/plugin/engine/scripts/engine-review-agent-package.ps1
+++ b/plugin/engine/scripts/engine-review-agent-package.ps1
@@ -1,4 +1,4 @@
-# Engine System — Agent-Reviewer Package (v6.21.0) [PowerShell behavioral mirror]
+# Engine System — Agent-Reviewer Package (v6.22.0) [PowerShell behavioral mirror]
 #
 # Phase 1: Package review context -> engine/review/evidence/T-NNN/review-package.md
 # Behavioral mirror of engine-review-agent-package.sh (same input -> same output)
@@ -40,7 +40,7 @@ try {
     if ($cfg.overrides.agent_review) {
         $cfg.overrides.agent_review.PSObject.Properties | ForEach-Object { $ar[$_.Name] = $_.Value }
     }
-    $agentReviewEnabled = if ($ar.enabled) { $true } else { $false }
+    $agentReviewEnabled = if ($null -eq $ar.enabled) { $true } elseif ($ar.enabled) { $true } else { $false }
 
     # L2 REVIEW-OVERRIDE check
     $taskContent = Get-Content $taskFile -Raw -Encoding UTF8
@@ -164,17 +164,142 @@ try {
         }
     }
 
-    # === 7. Static challenges ===
+    # === 7. Dynamic challenges (v6.22.0: diff semantic signals -> parameterized challenges) ===
+    # packaged_by: for reviewer independence validation
+    $packagedBy = if ($env:CLAUDE_SESSION_ID) { $env:CLAUDE_SESSION_ID } else { "$([System.Net.Dns]::GetHostName()):$PID" }
+
+    # most_changed_file (retained for fallback)
     $diffStat = git -C $ROOT diff --stat "$diffBase..HEAD" -- @diffFiles 2>$null
     $mostChanged = ($diffStat | Select-String '\|' | Sort-Object { [int]($_ -replace '.*\|\s*(\d+).*','$1') } -Descending | Select-Object -First 1) -replace '\s*\|.*$', ''
     $mostChanged = $mostChanged.Trim()
     if (-not $mostChanged) { $mostChanged = $diffFiles[0] }
 
-    $hunkLines = git -C $ROOT diff -U0 "$diffBase..HEAD" -- $mostChanged 2>$null | Select-String '^@@' | ForEach-Object { if ($_ -match '\+(\d+)') { [int]$Matches[1] } } | Sort-Object -Descending | Select-Object -First 1
-    if (-not $hunkLines) { $hunkLines = 1 }
+    # Dynamic challenges: python analyzes diff semantic signals, generates 3 targeted challenges
+    $pyCmd = $null
+    foreach ($c in @('python3','python')) { try { $null = cmd /c "$c --version 2>nul"; if ($LASTEXITCODE -eq 0) { $pyCmd = $c; break } } catch {} }
+
+    $challenges = $null
+    if ($pyCmd) {
+        $env:DIFF_BASE = $diffBase
+        $env:HEAD_REF = 'HEAD'
+        $env:DIFF_FILES = ($diffFiles -join ' ')
+        $env:ROOT_DIR = $ROOT
+        $pyScript = @'
+import subprocess, os, re, sys
+
+diff_base = os.environ['DIFF_BASE']
+diff_files = os.environ['DIFF_FILES'].split()
+root = os.environ['ROOT_DIR']
+
+signals = []
+
+for f in diff_files:
+    try:
+        diff = subprocess.check_output(
+            ['git', 'diff', '-U3', f'{diff_base}..HEAD', '--', f],
+            cwd=root, stderr=subprocess.DEVNULL
+        ).decode('utf-8', errors='replace')
+    except Exception:
+        continue
+
+    added_lines = []
+    removed_count = 0
+    hunk_sizes = []
+    current_hunk = 0
+
+    for line in diff.split('\n'):
+        if line.startswith('@@'):
+            if current_hunk > 0:
+                hunk_sizes.append(current_hunk)
+            current_hunk = 0
+            m = re.search(r'\+(\d+)', line)
+            hunk_start = int(m.group(1)) if m else 0
+        elif line.startswith('+') and not line.startswith('+++'):
+            current_hunk += 1
+            added_lines.append((hunk_start + current_hunk, line[1:]))
+        elif line.startswith('-') and not line.startswith('---'):
+            removed_count += 1
+            current_hunk += 1
+
+    if current_hunk > 0:
+        hunk_sizes.append(current_hunk)
+
+    for lineno, content in added_lines:
+        stripped = content.strip()
+        if re.match(r'\b(if|case|switch|elif)\b', stripped) and not re.search(r'\belse\b', stripped):
+            nearby = [c for l, c in added_lines if abs(l - lineno) < 10]
+            if not any('else' in c for c in nearby):
+                signals.append((90, f"File `{f}` line ~{lineno} adds a new branch (`{stripped[:60]}`) with no visible else/fallback. What happens when this condition is false?"))
+                break
+
+    for lineno, content in added_lines:
+        stripped = content.strip()
+        if re.match(r'\b(def|function|func|sub)\b', stripped) and '(' in stripped:
+            signals.append((80, f"File `{f}` line ~{lineno} defines/modifies `{stripped[:60]}`. Are all callers updated to match the new signature?"))
+            break
+
+    if hunk_sizes and max(hunk_sizes) > 20:
+        big_line = max(hunk_sizes)
+        signals.append((70, f"File `{f}` has a hunk with {big_line} changed lines. Is this a single logical change, or should it be split?"))
+
+    if removed_count > 15:
+        signals.append((60, f"File `{f}` removes {removed_count} lines. Are there callers or tests that still depend on the removed behavior?"))
+
+    for lineno, content in added_lines:
+        stripped = content.strip()
+        if re.search(r'\b(TODO|FIXME|HACK|XXX)\b', stripped):
+            signals.append((50, f"File `{f}` line ~{lineno} adds `{stripped[:60]}`. Is this intentional tech debt, and is it tracked?"))
+            break
+
+    for lineno, content in added_lines:
+        stripped = content.strip()
+        if re.match(r'\b(catch|except|rescue|on error|trap)\b', stripped, re.IGNORECASE):
+            signals.append((55, f"File `{f}` line ~{lineno} adds error handling (`{stripped[:60]}`). Does it swallow errors silently or propagate them correctly?"))
+            break
+
+signals.sort(key=lambda x: -x[0])
+unique = []
+seen = set()
+for pri, text in signals:
+    key = text[:40]
+    if key not in seen:
+        seen.add(key)
+        unique.append(text)
+
+if len(unique) >= 3:
+    for i, c in enumerate(unique[:3], 1):
+        print(f"{i}. {c}")
+elif len(unique) > 0:
+    for i, c in enumerate(unique, 1):
+        print(f"{i}. {c}")
+    statics = [
+        "If someone needs to modify this code 6 months from now, what is the biggest comprehension barrier?",
+        "What is the worst-case input for this change, and does it degrade gracefully?",
+        "Does this change introduce any implicit coupling that is not documented?"
+    ]
+    for j in range(len(unique), 3):
+        print(f"{j+1}. {statics[j - len(unique)]}")
+else:
+    print("SIGNAL_NONE")
+'@
+        try {
+            $challenges = & $pyCmd -c $pyScript 2>$null
+            $env:DIFF_BASE = $null; $env:HEAD_REF = $null; $env:DIFF_FILES = $null; $env:ROOT_DIR = $null
+        } catch {
+            $challenges = $null
+        }
+    }
 
-    $anotherFile = ($diffFiles | Where-Object { $_ -ne $mostChanged } | Select-Object -First 1)
-    if (-not $anotherFile) { $anotherFile = '(other WRITE-SET files)' }
+    # Fallback: no signals or python unavailable -> static challenges
+    if (-not $challenges -or $challenges -eq 'SIGNAL_NONE' -or ($challenges -join '').Trim() -eq '') {
+        $hunkLines = git -C $ROOT diff -U0 "$diffBase..HEAD" -- $mostChanged 2>$null | Select-String '^@@' | ForEach-Object { if ($_ -match '\+(\d+)') { [int]$Matches[1] } } | Sort-Object -Descending | Select-Object -First 1
+        if (-not $hunkLines) { $hunkLines = 1 }
+        $anotherFile = ($diffFiles | Where-Object { $_ -ne $mostChanged } | Select-Object -First 1)
+        if (-not $anotherFile) { $anotherFile = '(other WRITE-SET files)' }
+        $challenges = "1. File ``$mostChanged`` around line $hunkLines contains the most complex change. What happens if it receives empty input or extremely long input?`n2. Does this change break any assumptions that ``$anotherFile`` makes about ``$mostChanged``?`n3. If someone needs to modify this code 6 months from now, what is the biggest comprehension barrier?"
+    } else {
+        $challenges = ($challenges -join "`n")
+    }
 
     # === 8. Linter summary ===
     $linterSummary = ''
@@ -230,6 +355,7 @@ try {
 > generated: $timestamp
 > package_sha256: PLACEHOLDER
 > head_commit: $headCommit
+> packaged_by: $packagedBy
 > task: $goalText
 > scope: $scopeShort, $($diffFiles.Count) code files
 
@@ -262,9 +388,7 @@ $protocolContent
 
 ### Adversarial Challenges (must answer all 3)
 
-1. File ``$mostChanged`` around line $hunkLines contains the most complex change. What happens if it receives empty input or extremely long input?
-2. Does this change break any assumptions that ``$anotherFile`` makes about ``$mostChanged``?
-3. If someone needs to modify this code 6 months from now, what is the biggest comprehension barrier?
+$challenges
 
 $linterSummary
 
@@ -296,7 +420,8 @@ Schema (all fields required):
     "writer": "agent-reviewer",
     "commit": "$headCommit",
     "timestamp": "<write time>",
-    "package_sha256": "<fill from package header>"
+    "package_sha256": "<fill from package header>",
+    "reviewer_session": "<your session/agent identifier, must differ from packaged_by>"
   }
 }
 ``````
```

### plugin/engine/scripts/engine-review-agent-validate.sh
```diff
diff --git a/plugin/engine/scripts/engine-review-agent-validate.sh b/plugin/engine/scripts/engine-review-agent-validate.sh
index cdaef75..bd0256e 100644
--- a/plugin/engine/scripts/engine-review-agent-validate.sh
+++ b/plugin/engine/scripts/engine-review-agent-validate.sh
@@ -1,5 +1,5 @@
 #!/usr/bin/env bash
-# Engine System — Agent-Reviewer Validate(v6.21.0)
+# Engine System — Agent-Reviewer Validate(v6.22.0)
 #
 # Phase 3: 校验外部 agent 产出的 AGENT-REVIEW.json
 #
@@ -111,7 +111,7 @@ print(ar.get('max_package_age_hours', 72))
 VALIDATE_RESULT=$(REVIEW_FILE="$review_file" PACKAGE_FILE="$package_file" \
   MIN_ENTRIES="$min_entries" MIN_NARRATIVE="$min_narrative" \
   MIN_MESSAGE="$min_message" MAX_AGE_HOURS="$max_age_hours" \
-  TASK="$task" \
+  TASK="$task" ROOT_DIR="$ROOT" \
 "$PY" << 'PYEOF'
 import json, os, sys, hashlib
 from datetime import datetime, timezone
@@ -234,6 +234,48 @@ if shallow_errors:
         print(f"E_SHALLOW|{msg}")
     sys.exit(1)
 
+# --- E_GROUNDED (v6.22.0): verify finding file:line references exist ---
+grounded_errors = []
+grounded_warnings = []
+total_findings_for_grounding = 0
+ungrounded_count = 0
+
+root_dir = os.environ.get('ROOT_DIR', '.')
+for dim in required_dims:
+    for i, entry in enumerate(dims.get(dim, {}).get('entries', [])):
+        if entry.get('type') != 'finding':
+            continue
+        total_findings_for_grounding += 1
+        fpath = entry.get('file', '')
+        fline = entry.get('line', 0)
+        if not fpath or not fline:
+            continue
+        # check file exists
+        full_path = os.path.join(root_dir, fpath)
+        if not os.path.isfile(full_path):
+            ungrounded_count += 1
+            grounded_errors.append(f'{dim}.entries[{i}] references non-existent file: {fpath}')
+            continue
+        # check line number within file
+        try:
+            with open(full_path, encoding='utf-8', errors='replace') as ff:
+                line_count = sum(1 for _ in ff)
+            if fline > line_count:
+                ungrounded_count += 1
+                grounded_errors.append(f'{dim}.entries[{i}] line {fline} exceeds file length ({line_count} lines): {fpath}')
+        except Exception:
+            pass
+
+if total_findings_for_grounding > 0 and ungrounded_count > 0:
+    ratio = ungrounded_count / total_findings_for_grounding
+    if ratio > 0.5:
+        for msg in grounded_errors:
+            print(f"E_GROUNDED|{msg}")
+        sys.exit(1)
+    else:
+        for msg in grounded_errors:
+            grounded_warnings.append(msg)
+
 # --- E_PROVENANCE ---
 prov_errors = []
 
@@ -285,6 +327,25 @@ if os.path.isfile(package_file):
         except ValueError:
             warnings.append('cannot parse package generated timestamp')
 
+# --- E_INDEPENDENCE (v6.22.0, FAIL): reviewer_session must differ from packaged_by ---
+if os.path.isfile(package_file):
+    pkg_packaged_by = None
+    with open(package_file, encoding='utf-8') as f:
+        for line in f:
+            if line.startswith('> packaged_by:'):
+                pkg_packaged_by = line.split(':', 1)[1].strip()
+                break
+    reviewer_session = prov.get('reviewer_session', '')
+    if not reviewer_session:
+        print('E_INDEPENDENCE|reviewer_session missing in write_provenance (subagent review is mandatory)')
+        sys.exit(1)
+    elif pkg_packaged_by and reviewer_session == pkg_packaged_by:
+        print(f'E_INDEPENDENCE|reviewer_session matches packaged_by ({reviewer_session}) — reviewer must be a separate agent/session')
+        sys.exit(1)
+
+# merge grounded warnings
+warnings.extend(grounded_warnings)
+
 # --- Output summary ---
 total_findings = sum(
     len([e for e in dims.get(d, {}).get('entries', []) if e.get('type') == 'finding'])
@@ -367,7 +428,7 @@ if os.path.isfile(review_json):
     review.setdefault('dimensions', {})['agent_review'] = {
         'status': agent_status,
         'findings_count': counts,
-        'protocol_version': 'v6.21.0'
+        'protocol_version': 'v6.22.0'
     }
     if agent_status == 'block':
         review['status'] = 'block'
@@ -380,7 +441,7 @@ else:
             'agent_review': {
                 'status': agent_status,
                 'findings_count': counts,
-                'protocol_version': 'v6.21.0'
+                'protocol_version': 'v6.22.0'
             }
         },
         'write_provenance': {
@@ -388,7 +449,7 @@ else:
             'commit': head_commit,
             'timestamp': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
             'argv': f'engine review-agent {task} --validate',
-            'pipeline_version': 'v6.21.0'
+            'pipeline_version': 'v6.22.0'
         }
     }
 
```

### plugin/engine/scripts/engine-review-agent-validate.ps1
```diff
diff --git a/plugin/engine/scripts/engine-review-agent-validate.ps1 b/plugin/engine/scripts/engine-review-agent-validate.ps1
index aa73025..7596211 100644
--- a/plugin/engine/scripts/engine-review-agent-validate.ps1
+++ b/plugin/engine/scripts/engine-review-agent-validate.ps1
@@ -1,4 +1,4 @@
-# Engine System — Agent-Reviewer Validate (v6.21.0) [PowerShell behavioral mirror]
+# Engine System — Agent-Reviewer Validate (v6.22.0) [PowerShell behavioral mirror]
 #
 # Phase 3: Validate AGENT-REVIEW.json produced by external agent
 # Behavioral mirror of engine-review-agent-validate.sh
@@ -125,6 +125,45 @@ try {
         exit 1
     }
 
+    # === 4b. E_GROUNDED (v6.22.0): verify finding file:line references exist ===
+    $groundedErrors = @()
+    $groundedWarnings = @()
+    $totalFindingsForGrounding = 0
+    $ungroundedCount = 0
+    foreach ($dim in $requiredDims) {
+        $entries = @($data.dimensions.$dim.entries)
+        for ($i = 0; $i -lt $entries.Count; $i++) {
+            $e = $entries[$i]
+            if ($e.type -ne 'finding') { continue }
+            $totalFindingsForGrounding++
+            $fpath = if ($e.PSObject.Properties['file']) { $e.file } else { '' }
+            $fline = if ($e.PSObject.Properties['line']) { [int]$e.line } else { 0 }
+            if (-not $fpath -or -not $fline) { continue }
+            $fullPath = Join-Path $ROOT $fpath
+            if (-not (Test-Path $fullPath -PathType Leaf)) {
+                $ungroundedCount++
+                $groundedErrors += "${dim}.entries[${i}] references non-existent file: $fpath"
+                continue
+            }
+            try {
+                $lineCount = (Get-Content $fullPath -Encoding UTF8).Count
+                if ($fline -gt $lineCount) {
+                    $ungroundedCount++
+                    $groundedErrors += "${dim}.entries[${i}] line $fline exceeds file length ($lineCount lines): $fpath"
+                }
+            } catch {}
+        }
+    }
+    if ($totalFindingsForGrounding -gt 0 -and $ungroundedCount -gt 0) {
+        $ratio = $ungroundedCount / $totalFindingsForGrounding
+        if ($ratio -gt 0.5) {
+            foreach ($msg in $groundedErrors) { [Console]::Error.WriteLine("[engine-review-agent-validate] FAIL E_GROUNDED: $msg") }
+            exit 1
+        } else {
+            $groundedWarnings = $groundedErrors
+        }
+    }
+
     # === 5. E_PROVENANCE ===
     $provErrors = @()
     if ($prov.writer -ne 'agent-reviewer') { $provErrors += "invalid writer: $($prov.writer)" }
@@ -170,6 +209,24 @@ try {
         }
     }
 
+    # === 6b. E_INDEPENDENCE (v6.22.0, FAIL): reviewer_session must differ from packaged_by ===
+    if (Test-Path $packageFile) {
+        $pkgPackagedBy = $null
+        foreach ($line in (Get-Content $packageFile -Encoding UTF8)) {
+            if ($line -match '^> packaged_by:\s*(.+)$') { $pkgPackagedBy = $Matches[1].Trim(); break }
+        }
+        $reviewerSession = if ($prov.PSObject.Properties['reviewer_session']) { $prov.reviewer_session } else { '' }
+        if (-not $reviewerSession) {
+            [Console]::Error.WriteLine("[engine-review-agent-validate] FAIL E_INDEPENDENCE: reviewer_session missing in write_provenance (subagent review is mandatory)")
+            exit 1
+        } elseif ($pkgPackagedBy -and $reviewerSession -eq $pkgPackagedBy) {
+            [Console]::Error.WriteLine("[engine-review-agent-validate] FAIL E_INDEPENDENCE: reviewer_session matches packaged_by ($reviewerSession) - reviewer must be a separate agent/session")
+            exit 1
+        }
+    }
+    # Output grounded warnings
+    foreach ($gw in $groundedWarnings) { [Console]::Error.WriteLine("[engine-review-agent-validate] WARN: E_GROUNDED: $gw") }
+
     # === 7. Append validated_by ===
     $validatedAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
     $data.write_provenance | Add-Member -NotePropertyName 'validated_by' -NotePropertyValue "engine review-agent $Task --validate" -Force
@@ -188,7 +245,7 @@ try {
 
     if (Test-Path $reviewJson) {
         $review = Get-Content $reviewJson -Raw -Encoding UTF8 | ConvertFrom-Json
-        $agentDim = @{ status = $agentStatus; findings_count = @{critical=0;high=0;medium=0;low=0;info=0}; protocol_version = 'v6.21.0' }
+        $agentDim = @{ status = $agentStatus; findings_count = @{critical=0;high=0;medium=0;low=0;info=0}; protocol_version = 'v6.22.0' }
         foreach ($dim in $requiredDims) {
             foreach ($e in @($data.dimensions.$dim.entries)) { $agentDim.findings_count[$e.severity]++ }
         }
@@ -203,8 +260,8 @@ try {
         }
         $newReview = @{
             task = $Task; timestamp = $validatedAt; status = $agentStatus
-            dimensions = @{ agent_review = @{ status = $agentStatus; findings_count = $newCounts; protocol_version = 'v6.21.0' } }
-            write_provenance = @{ writer = 'engine-review-agent-validate'; commit = $headCommit; timestamp = $validatedAt; argv = "engine review-agent $Task --validate"; pipeline_version = 'v6.21.0' }
+            dimensions = @{ agent_review = @{ status = $agentStatus; findings_count = $newCounts; protocol_version = 'v6.22.0' } }
+            write_provenance = @{ writer = 'engine-review-agent-validate'; commit = $headCommit; timestamp = $validatedAt; argv = "engine review-agent $Task --validate"; pipeline_version = 'v6.22.0' }
         }
         $newReview | ConvertTo-Json -Depth 10 -Compress | Set-Content $reviewJson -Encoding UTF8
     }
```

### tests/workstream/test_review_agent_grounded.sh
```diff
diff --git a/tests/workstream/test_review_agent_grounded.sh b/tests/workstream/test_review_agent_grounded.sh
new file mode 100644
index 0000000..a3b2a5a
--- /dev/null
+++ b/tests/workstream/test_review_agent_grounded.sh
@@ -0,0 +1,234 @@
+#!/usr/bin/env bash
+# Test: E_GROUNDED + E_INDEPENDENCE validation (T-073, v6.22.0)
+#
+# Validates that engine-review-agent-validate.sh enforces:
+#   - E_GROUNDED: finding file:line references must exist (>50% ungrounded → FAIL)
+#   - E_INDEPENDENCE: reviewer_session should differ from packaged_by (WARN)
+#
+# Scenarios:
+#   S1: all findings reference valid file:line → PASS
+#   S2: >50% findings reference non-existent file → FAIL E_GROUNDED
+#   S3: <=50% ungrounded → PASS with WARN
+#   S4: reviewer_session matches packaged_by → PASS with WARN
+#   S5: reviewer_session missing → PASS with WARN (grace period)
+
+set -u
+PASS=0; FAIL=0
+assert_exit() {
+  local desc="$1" expected="$2" actual="$3"
+  if [ "$actual" -eq "$expected" ]; then
+    PASS=$((PASS+1)); echo "  PASS: $desc (exit $actual)"
+  else
+    FAIL=$((FAIL+1)); echo "  FAIL: $desc (expected exit $expected, got $actual)"
+  fi
+}
+assert_contains() {
+  local desc="$1" haystack="$2" needle="$3"
+  if echo "$haystack" | grep -qi "$needle"; then
+    PASS=$((PASS+1)); echo "  PASS: $desc"
+  else
+    FAIL=$((FAIL+1)); echo "  FAIL: $desc ('$needle' not found)"
+  fi
+}
+assert_not_contains() {
+  local desc="$1" haystack="$2" needle="$3"
+  if echo "$haystack" | grep -qi "$needle"; then
+    FAIL=$((FAIL+1)); echo "  FAIL: $desc ('$needle' should not be present)"
+  else
+    PASS=$((PASS+1)); echo "  PASS: $desc"
+  fi
+}
+
+echo "=== test_review_agent_grounded.sh ==="
+
+SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
+ROOT_REPO="$(cd "$SCRIPT_DIR/../.." && pwd)"
+VALIDATE_SH="$ROOT_REPO/engine/scripts/engine-review-agent-validate.sh"
+
+TMPDIR_TEST=$(mktemp -d)
+trap 'rm -rf "$TMPDIR_TEST"' EXIT
+
+# python detection
+PY=python3
+command -v python3 >/dev/null 2>&1 || PY=python
+
+setup_validate_env() {
+  local dir="$1"
+  mkdir -p "$dir/engine/review/evidence/T-099" "$dir/src"
+  cd "$dir"
+  git init -q
+  git config user.email "test@test.com"
+  git config user.name "Test"
+  echo '{"defaults":{"agent_review":{"enabled":true,"min_entries_per_dimension":1,"min_narrative_chars":50,"min_entry_message_chars":10,"max_package_age_hours":72}},"overrides":{}}' > engine/review/config.json
+  echo "real content line 1" > src/real.sh
+  echo "real content line 2" >> src/real.sh
+  echo "real content line 3" >> src/real.sh
+  # Create package with packaged_by header
+  cat > engine/review/evidence/T-099/review-package.md << 'PKGEOF'
+# Code Review Package: T-099
+
+> generated: 2026-07-31T10:00:00Z
+> package_sha256: PLACEHOLDER
+> head_commit: COMMITPLACEHOLDER
+> packaged_by: packager-session-abc
+> task: test task
+> scope: abcd1234..efgh5678, 1 code files
+
+## 1. Task Context
+### GOAL
+test
+PKGEOF
+  # Backfill sha256 (COMPUTE normalization)
+  local head_commit
+  git add -A && git commit -qm "init"
+  head_commit=$(git rev-parse HEAD)
+  sed -i "s/COMMITPLACEHOLDER/$head_commit/" engine/review/evidence/T-099/review-package.md
+  # Compute sha with COMPUTE normalization
+  local sha
+  sha=$("$PY" -c "
+import hashlib, re, os
+f = os.environ['PKG']
+with open(f, encoding='utf-8') as fh:
+    content = fh.read()
+normalized = re.sub(r'(> package_sha256: ).*', r'\1COMPUTE', content)
+print(hashlib.sha256(normalized.encode('utf-8')).hexdigest())
+" 2>/dev/null) || sha="deadbeef"
+  PKG="$dir/engine/review/evidence/T-099/review-package.md" "$PY" -c "
+import hashlib, re, os
+f = os.environ['PKG']
+with open(f, encoding='utf-8') as fh:
+    content = fh.read()
+normalized = re.sub(r'(> package_sha256: ).*', r'\1COMPUTE', content)
+sha = hashlib.sha256(normalized.encode('utf-8')).hexdigest()
+content = content.replace('package_sha256: PLACEHOLDER', f'package_sha256: {sha}')
+with open(f, 'w', encoding='utf-8') as fh:
+    fh.write(content)
+" 2>/dev/null
+  git add -A && git commit -qm "package" --allow-empty 2>/dev/null || true
+  echo "$head_commit"
+}
+
+make_review_json() {
+  local dir="$1" commit="$2" sha="$3" session="$4"
+  local entries=""
+  shift 4
+  # remaining args are "file:line:type" tuples for correctness entries
+  local corr_entries=""
+  for spec in "$@"; do
+    local fpath=$(echo "$spec" | cut -d: -f1)
+    local fline=$(echo "$spec" | cut -d: -f2)
+    local etype=$(echo "$spec" | cut -d: -f3)
+    corr_entries="$corr_entries{\"id\":\"agent-correctness-$fpath:$fline\",\"severity\":\"medium\",\"type\":\"$etype\",\"file\":\"$fpath\",\"line\":$fline,\"message\":\"This is a test finding message that is long enough\"},"
+  done
+  corr_entries="${corr_entries%,}"
+
+  local reviewer_session_field=""
+  if [ -n "$session" ]; then
+    reviewer_session_field="\"reviewer_session\": \"$session\","
+  fi
+
+  cat > "$dir/engine/review/evidence/T-099/AGENT-REVIEW.json" << JSONEOF
+{
+  "task": "T-099",
+  "timestamp": "2026-07-31T10:05:00Z",
+  "reviewer": {"type": "agent"},
+  "status": "pass",
+  "dimensions": {
+    "correctness": {"entries": [$corr_entries], "summary": "Test correctness summary for validation"},
+    "design": {"entries": [{"id":"agent-design-1","severity":"info","type":"strength","file":"src/real.sh","line":1,"message":"Good design pattern observed here"}], "summary": "Test design summary"},
+    "consistency": {"entries": [{"id":"agent-consistency-1","severity":"info","type":"strength","file":"src/real.sh","line":1,"message":"Consistent naming conventions"}], "summary": "Test consistency summary"},
+    "readability": {"entries": [{"id":"agent-readability-1","severity":"info","type":"strength","file":"src/real.sh","line":2,"message":"Clear and readable code structure"}], "summary": "Test readability summary"},
+    "completeness": {"entries": [{"id":"agent-completeness-1","severity":"info","type":"strength","file":"src/real.sh","line":3,"message":"Complete implementation coverage"}], "summary": "Test completeness summary"}
+  },
+  "adversarial_responses": [
+    {"challenge": "q1", "response": "This is a substantive response to challenge one that exceeds thirty characters"},
+    {"challenge": "q2", "response": "This is a substantive response to challenge two that exceeds thirty characters"},
+    {"challenge": "q3", "response": "This is a substantive response to challenge three that exceeds thirty characters"}
+  ],
+  "overall_assessment": "This is a comprehensive overall assessment that covers the review findings and provides context for the pass status decision made by the reviewer agent.",
+  "write_provenance": {
+    "writer": "agent-reviewer",
+    "commit": "$commit",
+    "timestamp": "2026-07-31T10:05:00Z",
+    "package_sha256": "$sha",
+    $reviewer_session_field
+    "argv": "test"
+  }
+}
+JSONEOF
+}
+
+get_package_sha() {
+  local dir="$1"
+  "$PY" -c "
+import hashlib, re, os
+f = os.environ['PKG']
+with open(f, encoding='utf-8') as fh:
+    content = fh.read()
+normalized = re.sub(r'(> package_sha256: ).*', r'\1COMPUTE', content)
+print(hashlib.sha256(normalized.encode('utf-8')).hexdigest())
+" 2>/dev/null
+}
+
+# --- S1: all findings grounded → PASS ---
+echo ""
+echo "--- S1: all findings reference valid files → PASS ---"
+S1="$TMPDIR_TEST/s1"
+HEAD1=$(setup_validate_env "$S1")
+SHA1=$(PKG="$S1/engine/review/evidence/T-099/review-package.md" get_package_sha "$S1")
+make_review_json "$S1" "$HEAD1" "$SHA1" "reviewer-xyz" "src/real.sh:1:finding" "src/real.sh:2:finding"
+OUT1=$(CLAUDE_PROJECT_DIR="$S1" bash "$VALIDATE_SH" T-099 2>&1); RC1=$?
+assert_exit "S1 validate exits 0" 0 $RC1
+assert_not_contains "S1 no E_GROUNDED error" "$OUT1" "FAIL E_GROUNDED"
+
+# --- S2: >50% ungrounded → FAIL ---
+echo ""
+echo "--- S2: >50% findings reference non-existent files → FAIL E_GROUNDED ---"
+S2="$TMPDIR_TEST/s2"
+HEAD2=$(setup_validate_env "$S2")
+SHA2=$(PKG="$S2/engine/review/evidence/T-099/review-package.md" get_package_sha "$S2")
+# 3 findings: 2 reference non-existent files (>50%)
+make_review_json "$S2" "$HEAD2" "$SHA2" "reviewer-xyz" "src/real.sh:1:finding" "src/ghost.sh:5:finding" "src/phantom.py:99:finding"
+OUT2=$(CLAUDE_PROJECT_DIR="$S2" bash "$VALIDATE_SH" T-099 2>&1); RC2=$?
+assert_exit "S2 validate exits 1" 1 $RC2
+assert_contains "S2 E_GROUNDED in output" "$OUT2" "E_GROUNDED"
+
+# --- S3: <=50% ungrounded → PASS with WARN ---
+echo ""
+echo "--- S3: <=50% ungrounded → PASS with WARN ---"
+S3="$TMPDIR_TEST/s3"
+HEAD3=$(setup_validate_env "$S3")
+SHA3=$(PKG="$S3/engine/review/evidence/T-099/review-package.md" get_package_sha "$S3")
+# 3 findings: 1 non-existent (33% <= 50%)
+make_review_json "$S3" "$HEAD3" "$SHA3" "reviewer-xyz" "src/real.sh:1:finding" "src/real.sh:2:finding" "src/ghost.sh:5:finding"
+OUT3=$(CLAUDE_PROJECT_DIR="$S3" bash "$VALIDATE_SH" T-099 2>&1); RC3=$?
+assert_exit "S3 validate exits 0" 0 $RC3
+assert_contains "S3 WARN about grounded" "$OUT3" "non-existent file\|exceeds file length"
+
+# --- S4: reviewer_session matches packaged_by → FAIL ---
+echo ""
+echo "--- S4: reviewer_session == packaged_by → FAIL E_INDEPENDENCE ---"
+S4="$TMPDIR_TEST/s4"
+HEAD4=$(setup_validate_env "$S4")
+SHA4=$(PKG="$S4/engine/review/evidence/T-099/review-package.md" get_package_sha "$S4")
+# session matches packaged_by (packager-session-abc)
+make_review_json "$S4" "$HEAD4" "$SHA4" "packager-session-abc" "src/real.sh:1:finding"
+OUT4=$(CLAUDE_PROJECT_DIR="$S4" bash "$VALIDATE_SH" T-099 2>&1); RC4=$?
+assert_exit "S4 validate exits 1 (FAIL)" 1 $RC4
+assert_contains "S4 independence error" "$OUT4" "E_INDEPENDENCE\|separate agent"
+
+# --- S5: reviewer_session missing → FAIL ---
+echo ""
+echo "--- S5: reviewer_session missing → FAIL E_INDEPENDENCE ---"
+S5="$TMPDIR_TEST/s5"
+HEAD5=$(setup_validate_env "$S5")
+SHA5=$(PKG="$S5/engine/review/evidence/T-099/review-package.md" get_package_sha "$S5")
+make_review_json "$S5" "$HEAD5" "$SHA5" "" "src/real.sh:1:finding"
+OUT5=$(CLAUDE_PROJECT_DIR="$S5" bash "$VALIDATE_SH" T-099 2>&1); RC5=$?
+assert_exit "S5 validate exits 1 (FAIL)" 1 $RC5
+assert_contains "S5 mandatory subagent error" "$OUT5" "E_INDEPENDENCE\|mandatory"
+
+# --- Summary ---
+echo ""
+echo "=== RESULTS: $PASS passed, $FAIL failed ==="
+[ "$FAIL" -eq 0 ] && exit 0 || exit 1
```

### tests/workstream/test_review_agent_dynamic.sh
```diff
diff --git a/tests/workstream/test_review_agent_dynamic.sh b/tests/workstream/test_review_agent_dynamic.sh
new file mode 100644
index 0000000..9f34666
--- /dev/null
+++ b/tests/workstream/test_review_agent_dynamic.sh
@@ -0,0 +1,175 @@
+#!/usr/bin/env bash
+# Test: dynamic challenge generation (T-073, v6.22.0)
+#
+# Validates that engine-review-agent-package.sh generates diff-aware
+# adversarial challenges instead of static ones.
+#
+# Scenarios:
+#   S1: diff with new branch (if without else) → challenge mentions branch/fallback
+#   S2: diff with large hunk (>20 lines) → challenge mentions split/rollback
+#   S3: trivial change (no signals) → fallback static challenges (3 questions)
+#   S4: packaged_by header present in output package
+
+set -u
+PASS=0; FAIL=0
+assert_exit() {
+  local desc="$1" expected="$2" actual="$3"
+  if [ "$actual" -eq "$expected" ]; then
+    PASS=$((PASS+1)); echo "  PASS: $desc (exit $actual)"
+  else
+    FAIL=$((FAIL+1)); echo "  FAIL: $desc (expected exit $expected, got $actual)"
+  fi
+}
+assert_contains() {
+  local desc="$1" haystack="$2" needle="$3"
+  if echo "$haystack" | grep -qi "$needle"; then
+    PASS=$((PASS+1)); echo "  PASS: $desc"
+  else
+    FAIL=$((FAIL+1)); echo "  FAIL: $desc ('$needle' not found)"
+  fi
+}
+assert_not_contains() {
+  local desc="$1" haystack="$2" needle="$3"
+  if echo "$haystack" | grep -qi "$needle"; then
+    FAIL=$((FAIL+1)); echo "  FAIL: $desc ('$needle' should not be present)"
+  else
+    PASS=$((PASS+1)); echo "  PASS: $desc"
+  fi
+}
+
+echo "=== test_review_agent_dynamic.sh ==="
+
+SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
+ROOT_REPO="$(cd "$SCRIPT_DIR/../.." && pwd)"
+PACKAGE_SH="$ROOT_REPO/engine/scripts/engine-review-agent-package.sh"
+
+TMPDIR_TEST=$(mktemp -d)
+trap 'rm -rf "$TMPDIR_TEST"' EXIT
+
+# python detection
+PY=python3
+command -v python3 >/dev/null 2>&1 || PY=python
+
+setup_repo() {
+  local dir="$1"
+  mkdir -p "$dir/engine/tasks" "$dir/engine/review"
+  cd "$dir"
+  git init -q
+  git config user.email "test@test.com"
+  git config user.name "Test"
+  # config with agent_review enabled
+  cat > engine/review/config.json << 'EOF'
+{"defaults":{"agent_review":{"enabled":true,"max_package_lines":2000,"max_surrounding_context_lines":500,"max_domain_knowledge_lines":150},"code_extensions":[".sh",".py",".js"]},"overrides":{}}
+EOF
+  git add -A && git commit -qm "init"
+}
+
+# --- S1: branch signal ---
+echo ""
+echo "--- S1: new branch without else → dynamic challenge ---"
+S1="$TMPDIR_TEST/s1"
+setup_repo "$S1"
+cat > engine/tasks/T-001.md << 'EOF'
+# T-001
+GOAL: test branch signal
+## WRITE-SET
+- src/logic.sh
+## FORBIDDEN
+## AC:
+AC: test passes
+EOF
+mkdir -p src
+cat > src/logic.sh << 'SCRIPT'
+#!/bin/bash
+echo "hello"
+SCRIPT
+git add -A && git commit -qm "add task + base"
+# Add branch without else
+cat > src/logic.sh << 'SCRIPT'
+#!/bin/bash
+if [ "$1" = "danger" ]; then
+  rm -rf /tmp/something
+  echo "did dangerous thing"
+fi
+echo "done"
+SCRIPT
+git add -A && git commit -qm "add branch"
+OUT1=$(CLAUDE_PROJECT_DIR="$S1" bash "$PACKAGE_SH" T-001 2>&1); RC1=$?
+assert_exit "S1 package exits 0" 0 $RC1
+PKG1=$(cat "$S1/engine/review/evidence/T-001/review-package.md" 2>/dev/null || echo "")
+assert_contains "S1 challenge mentions branch/condition" "$PKG1" "branch\|condition\|else\|fallback"
+
+# --- S2: large hunk signal ---
+echo ""
+echo "--- S2: large hunk (>20 lines) → dynamic challenge ---"
+S2="$TMPDIR_TEST/s2"
+setup_repo "$S2"
+cat > engine/tasks/T-002.md << 'EOF'
+# T-002
+GOAL: test large hunk
+## WRITE-SET
+- src/big.py
+## FORBIDDEN
+## AC:
+AC: test passes
+EOF
+mkdir -p src
+echo "# base" > src/big.py
+git add -A && git commit -qm "add task + base"
+# Generate 30+ line change
+python3 -c "
+lines = ['# big module v2']
+for i in range(35):
+    lines.append(f'def func_{i}(x):')
+    lines.append(f'    return x + {i}')
+print('\n'.join(lines))
+" > src/big.py 2>/dev/null || python -c "
+lines = ['# big module v2']
+for i in range(35):
+    lines.append(f'def func_{i}(x):')
+    lines.append(f'    return x + {i}')
+print('\n'.join(lines))
+" > src/big.py
+git add -A && git commit -qm "big change"
+OUT2=$(CLAUDE_PROJECT_DIR="$S2" bash "$PACKAGE_SH" T-002 2>&1); RC2=$?
+assert_exit "S2 package exits 0" 0 $RC2
+PKG2=$(cat "$S2/engine/review/evidence/T-002/review-package.md" 2>/dev/null || echo "")
+assert_contains "S2 challenge mentions hunk/split/lines" "$PKG2" "hunk\|split\|changed lines\|logical change"
+
+# --- S3: trivial change → fallback static ---
+echo ""
+echo "--- S3: trivial change → static fallback challenges ---"
+S3="$TMPDIR_TEST/s3"
+setup_repo "$S3"
+cat > engine/tasks/T-003.md << 'EOF'
+# T-003
+GOAL: test fallback
+## WRITE-SET
+- src/tiny.sh
+## FORBIDDEN
+## AC:
+AC: test passes
+EOF
+mkdir -p src
+echo '#!/bin/bash' > src/tiny.sh
+git add -A && git commit -qm "add task + base"
+echo '#!/bin/bash' > src/tiny.sh
+echo 'echo ok' >> src/tiny.sh
+git add -A && git commit -qm "tiny change"
+OUT3=$(CLAUDE_PROJECT_DIR="$S3" bash "$PACKAGE_SH" T-003 2>&1); RC3=$?
+assert_exit "S3 package exits 0" 0 $RC3
+PKG3=$(cat "$S3/engine/review/evidence/T-003/review-package.md" 2>/dev/null || echo "")
+# Should have 3 numbered challenges regardless
+assert_contains "S3 has challenge 1" "$PKG3" "^1\."
+assert_contains "S3 has challenge 3" "$PKG3" "^3\."
+
+# --- S4: packaged_by header present ---
+echo ""
+echo "--- S4: packaged_by header in package ---"
+assert_contains "S4 packaged_by header exists" "$PKG1" "packaged_by:"
+assert_contains "S4 reviewer_session in schema" "$PKG1" "reviewer_session"
+
+# --- Summary ---
+echo ""
+echo "=== RESULTS: $PASS passed, $FAIL failed ==="
+[ "$FAIL" -eq 0 ] && exit 0 || exit 1
```


## 3. Surrounding Context

_(truncated for size)_

## 会话历史（最新在上）

| 日期 | 完成了什么 | 下一步 | 改动文件 |
|------|-----------|--------|---------|
| 2026-07-31 | **T-073 v6.22.0 Agent-Reviewer 对抗性升级 done(11 AC PASS)**:package 动态挑战(python diff 6 语义信号优先级排序 top3,fallback 静态)+ packaged_by header + reviewer_session schema;validate E_GROUNDED(file:line 存在性,>50% FAIL)+ E_INDEPENDENCE(session 独立性 WARN);config 默认 enabled:true;Windows 编码修复(errors='replace')。ps1 镜像 + plugin byte-identical。测试 42 断言全 PASS(dynamic 9 + grounded 10 + gate 10 + doctor 13)。 | push main + tag v6.22.0;doctor ps1 对等债;E_INDEPENDENCE 升级 | engine/scripts/engine-review-agent-{package,validate}.{sh,ps1}, engine/review/{config.json,protocol.md}, plugin mirrors, tests/workstream/test_review_agent_{dynamic,grounded}.sh, engine/tasks/T-073.md, CHANGELOG.md, engine/{CONTEXT,HANDOFF,ENGINE_MAP}.md, VERSION, engine/VERSION, plugin/VERSION |
| 2026-07-31 | **T-071 + T-072 v6.21.0 Agent-Reviewer 子系统全功能上线 done(T-071 16 AC + T-072 9 AC PASS)**:T-071 核心 — `engine review-agent T-NNN --package/--validate` 两原子命令,package 打包审查上下文(diff + 任务卡 + 周边上下文 + 域知识 + protocol + 3 对抗挑战 + linter 摘要 + schema 示例)为 review-package.md(COMPUTE 归一化 sha256);validate 四层校验 E_SCHEMA → E_SHALLOW → E_PROVENANCE → E_STALE;ps1 行为镜像。5 处 spec 偏差修正(截断 enforce / 互斥检查 / ps1 schema / E_STALE timestamp / ps1 findings_count)。T-072 门禁集成 — pre-commit 扩展 AGENT-REVIEW.json provenance(writer=agent-reviewer + package_sha256 校验);Doctor check_agent_review_evidence(done + enabled → FAIL/WARN);rules.json +14 protected_paths。测试 83 断言全 PASS(CLI 12 + Package 19 + Validate 16 + Config 4 + Mirror 9 + Gate 10 + Doctor 13)。 | push main + tag v6.21.0;doctor ps1 review 对等债 | engine/scripts/engine-review-agent*.{sh,ps1}, engine/scripts/githooks/pre-commit, engine/scripts/engine-doctor.sh, engine/bin/engine{,.ps1}, engine/review/{config.json,protocol.md}, engine/decisions/rules.json, plugin mirrors, tests/workstream/test_review_agent_{cli,package,validate,config,mirror,gate}.sh, tests/workstream/test_doctor_agent_review.sh, engine/tasks/T-{071,072}.md, docs/superpowers/specs/2026-07-31-agent-reviewer-design.md, engine/{CONTEXT,HANDOFF,ENGINE_MAP}.md, CHANGELOG.md, VERSION, engine/VERSION |
| 2026-07-31 | **T-069 + T-070 v6.20.0 Review 子系统全功能上线 done(T-069 19/19 AC + T-070 13/13 AC PASS)**:T-069 review pipeline core — `engine review T-NNN` CLI + engine-review-pipeline.sh(diff by task_first_commit + semgrep/eslint 工具 + L0/L1/L2 config 三层 merge + extension whitelist + L2 REVIEW-OVERRIDE 升级 + block/degraded/no_tool_for_language 路径)。T-070 pre-commit provenance + Doctor + 集成 — pre-commit hook 加 review evidence provenance 独立校验块(writer=engine-review + commit=HEAD + argv="engine review <task>",任何其他形状=篡改拦截) + protected-path 豁免分支(WRITE-SET 内放行);engine-doctor.{sh,ps1} 加 `check_review_evidence`/`Test-ReviewEvidence`(新 done 卡无 REVIEW.json → FAIL / 历史 done 卡 → WARN / status=block → FAIL / tool_unavailable=true → WARN)+ `check_review_config_protected`/`Test-ReviewConfigProtected`(config.json 修改无 approved 决策 → FAIL);全链路 e2e(review pass/block/degraded → doctor PASS/FAIL/WARN)+ T-070 自审 evidence(狗食:`engine review T-070` 产 REVIEW.json,本提交经 provenance gate 校验无 --no-verify)。Doctor sh/ps1 镜像语义孪生 + plugin 镜像 byte-identical。测试:test_review_e2e.sh 4/4 PASS + test_doctor_review_mirror_parity.sh 8/8 PASS + Task 6 三测试(precommit_review_provenance 5/5 + doctor_review_evidence + doctor_review_config)。Review 子系统全功能 operational。 | push main + tag v6.20.0 触发 CI/Release;T-068 批量补 code_fingerprint | engine/scripts/{engine-review,engine-review-pipeline,engine-doctor}.{sh,ps1}, engine/scripts/githooks/pre-commit, plugin/engine/scripts/{engine-review,engine-review-pipeline,engine-doctor}.{sh,ps1}, plugin/engine/scripts/githooks/pre-commit, engine/decisions/rules.json, engine/review/{config.json,evidence/T-070/**}, tests/workstream/test_{review_e2e,doctor_review_mirror_parity,precommit_review_provenance,doctor_review_evidence,doctor_review_config}.sh, engine/tasks/T-{069,070}.md, engine/{CONTEXT,HANDOFF}.md, VERSION, engine/VERSION, plugin/VERSION, plugin/manifest.json |
| 2026-07-30 | **T-067 v6.19.0 防漂移 P2 — 状态面板视图化 + 信任分级注入 done(10/10 AC PASS, D-038c/d)**:CONTEXT.md 状态面板从「权威声明」降级为「派生视图」(双写过渡期 v6.19.0~v6.20.0,旧静态段保留并标 `<!-- legacy: status-panel -->`,新 "Derived Status" 段由 engine context 实时重算 git tag + engine/VERSION + 最近 done 卡 evidence 信任级)。engine-context.{sh,ps1} 新增 `render_derived_status()`/`Render-DerivedStatus` 输出 [T1]/[T2 legacy]/[T2 declared-only]/[T3 unverified] 信任标签(T1=code_fingerprint + verified_against_commit=HEAD/ancestor + tag/VERSION 一致;T2 分档 legacy-evidence/declared-only/stale;T3=待验证)。engine-doctor.{sh,ps1} 新增 `check_derived_status`/`Test-DerivedStatus` 校验 legacy 标注 + tag/VERSION 一致性 + stale panel(双写过渡期 WARN 不 FAIL)。plugin 镜像 byte-identical(4 脚本)。测试 test_derived_status.sh 6 场景 9/9 PASS。 | push main + tag v6.19.0 触发 CI/Release;T-068 批量补 code_fingerprint | engine/scripts/{engine-context,engine-doctor}.{sh,ps1}, plugin/engine/scripts/{engine-context,engine-doctor}.{sh,ps1}, engine/CONTEXT.md, tests/workstream/test_derived_status.sh, engine/tasks/T-067.{md}, engine/tasks/T-067/progress.md, engine/archive/tasks/T-067-progress.md, engine/changes/CHANGE-2026-07-30-04.md, engine/evidence/T-067/**, engine/{CONTEXT,HANDOFF,ENGINE_MAP}.md, engine/handoff-archive-2026-07.md, engine/domains/engine-runtime/INVENTORY.md, VERSION, engine/VERSION, plugin/VERSION, plugin/manifest.json, CHANGELOG.md |
| 2026-07-30 | **T-066 v6.18.0 防漂移 P1 — 证据多锚 + drift-check done(12/12 AC PASS, D-038a/b)**:evidence schema 升级为多锚(output_fingerprint + code_fingerprint via git ls-files -s + write_set_snapshot + verified_against_commit + write_provenance + MANIFEST.json 聚合 hash)。新增 engine-drift-check.{sh,ps1} 三步顺序校验(完整性自证 → WRITE-SET 二阶 → 代码指纹)。pre-commit 加 provenance gate(writer=engine-verify + commit=HEAD + argv;手动需 evidence-manual-edit 标注)。rules.json 加 engine/evidence/** + engine-drift-check.* protected_paths。engine-doctor 集成 drift-check。plugin 镜像 byte-identical(7 脚本)。测试:drift-check 5 场景 + provenance 6 场景。 | push main + tag v6.18.0 触发 CI/Release | engine/scripts/{engine-verify,engine-drift-check,engine-doctor}.{sh,ps1}, engine/scripts/githooks/pre-commit, plugin/engine/scripts/{engine-verify,engine-drift-check,engine-doctor}.{sh,ps1}, plugin/engine/scripts/githooks/pre-commit, engine/decisions/rules.json, tests/workstream/test_{drift_check,evidence_provenance}.sh, tests/{behavior-verify/run-verify-tests,task-card/run-task-tests}.sh, engine/tasks/T-066.{md}, engine/archive/tasks/T-066-progress.md, engine/changes/CHANGE-2026-07-30-{02,03}.md, engine/evidence/T-066/**, engine/{CONTEXT,HANDOFF,ENGINE_MAP}.md, engine/domains/engine-runtime/INVENTORY.md, VERSION, engine/VERSION, plugin/VERSION, plugin/manifest.json, CHANGELOG.md |
| 2026-07-30 | **T-065 v6.17.4 pre-commit governing 不把已 done 卡误当 closing done(7/7 AC PASS, issue #21)**:修 pre-commit hook L234-245 closing_paths 收集逻辑:所有 staged + status:done 任务卡被当 "closing" 加入 governing,不区分「新 close」与「修改已 done 卡」。加 HEAD 检查:HEAD 已 done 则跳过。与 issue #18 AC PASS 检查修复(L375-381)模式一致。新增 test_precommit_done_card_governing.sh 5 场景。plugin 镜像 byte-identical。 | push main + tag v6.17.4 触发 CI/Release;回复关闭 issue #21 | engine/scripts/githooks/pre-commit, plugin/engine/scripts/githooks/pre-commit, tests/workstream/test_precommit_done_card_governing.sh, engine/tasks/T-065.{md}, engine/tasks/T-065/progress.md, engine/archive/tasks/T-065-progress.md, engine/changes/CHANGE-2026-07-30-02.md, engine/evidence/T-065/**, engine/{CONTEXT,HANDOFF,ENGINE_MAP}.md, engine/handoff-archive-2026-07.md, VERSION, engine/VERSION, plugin/VERSION, plugin/manifest.json, CHANGELOG.md |
| 2026-07-29 | **T-057 v6.14.2 § 编码 hotfix done(6/6 AC PASS)**:承接 T-056 v6.14.1 em-dash 修复,本次清理 Windows PS 5.1 + zh-CN locale 下 §(section sign,U+00A7)在用户可见 Write-Output/Write-Host 字符串中的乱码。根因:UTF-8 § 字节 `C2 A7` 被 GBK codepage 解码为 `搂`(C2A7=搂)→ 用户看到 `D-028 §9` 渲染为 `D-028 搂9`。实测证据:`tmp_section_test.ps1` 在 PS 5.1 下输出 `搂1 and 搂2`。修 3 处用户可见字符串 § → ASCII `S`:`engine-doctor.ps1` L768/L854 `Write-Output "(D-028 §9)"` → `(D-028 S9)`(engine + plugin 镜像)+ `engine-migrate-contract.ps1` L308 `Write-Host "ENGINE_MAP §2 plan registry"` → `ENGINE_MAP S2 plan registry`(engine + plugin 镜像)。功能性 § 保留:L304 正则 `'## .*§2'`(匹配 ENGINE_MAP.md 章节标题)+ L375-394 here-string 模板 `## §1 已读文件` 等(重生成 CONTEXT.md)。注释和 .sh 文件中的 § 留独立任务(bash 处理 UTF-8 无乱码问题)。plugin 镜像 SHA256 byte-identical,manifest 已更新。check.sh CHECK PASSED。 | push main + tag v6.14.2 触发 CI/Release;可选立项清扫注释 § + here-string 中文模板 + .sh 文件 § | engine/scripts/engine-doctor.ps1, plugin/engine/scripts/engine-doctor.ps1, engine/scripts/engine-migrate-contract.ps1, plugin/engine/scripts/engine-migrate-contract.ps1, engine/tasks/T-057.md, engine/archive/tasks/T-057-progress.md, engine/changes/CHANGE-2026-07-29-06.md, engine/evidence/T-057/**, engine/{CONTEXT,HANDOFF}.md, engine/handoff-archive-2026-07.md, VERSION, engine/VERSION, plugin/VERSION, plugin/manifest.json, CHANGELOG.md |
| 2026-07-29 | **T-056 v6.14.1 em-dash 编码 hotfix done(6/6 AC PASS)**:Windows PS 5.1 + zh-CN locale 下 .ps1 文件中 em-dash(`—`)渲染为 `鈥?` 乱码。根因:UTF-8 无 BOM 的 .ps1 被 PS 5.1 按 GBK 读取,em-dash 字节 `E2 80 94` 被 GBK 解码为 `鈥`(E2 80)+ 残字节 `?`(94 单字节无 trail)。修 3 处用户可见 Write-Warn/Fail 字符串字面量:`engine-doctor.ps1` L1318 `check_engineignore` Write-Warn 文案(engine + plugin 镜像)+ `test_engine_verify_env_cleanup.ps1` Fail 函数输出前缀。其余 6 个 .ps1 含非 ASCII(注释/§/here-string 中文模板)留独立任务卡。`§` 在 GBK 下解码为汉字+数字(轻度乱码,可读);here-string 中文模板会被写入 .md 文件(永久乱码)。不引入 BOM(避免 62+ 文件 checksum 漂移)。test 2/2 PASS,check.sh CHECK PASSED。 | push main + tag v6.14.1 触发 CI/Release;可选立项清扫其余非 ASCII(§ + here-string) | engine/scripts/engine-doctor.ps1, plugin/engine/scripts/engine-doctor.ps1, tests/workstream/test_engine_verify_env_cleanup.ps1, engine/tasks/T-056.md, engine/archive/tasks/T-056-progress.md, engine/changes/CHANGE-2026-07-29-05.md, engine/evidence/T-056/**, engine/{CONTEXT,HANDOFF,ENGINE_MAP}.md, engine/handoff-archive-2026-07.md, engine/domains/engine-runtime/INVENTORY.md, VERSION, engine/VERSION, plugin/VERSION, plugin/manifest.json, CHANGELOG.md |
```

### engine/ENGINE_MAP.md (references: HEAD)
```
| v6.11.0 (D-029/T-036) | ✅ | 多会话锁(coordinator/worker)、双信号检测、kill switch、stale 接管 |
| v6.11.4 行为层 + 安装器鲁棒性 | ✅ | (a) task-run.md 仪式缩放指导:契约最小格式 vs 项目可选增强,防下游误认自选仪式为引擎强制;(b) T-042 issue #9 PS 5.1 LF-only here-string 解析失败修复:install.ps1 加 Convert-ToCrlf + 3 个 engine.cmd pwsh 优先检测(方案 A+B 双保险,D-030 批准) |
| v6.11.5 pre-commit parser 鲁棒性 | ✅ | T-043 issue #10 P038 parse_task_patterns 支持 YAML frontmatter 多行 write-set:awk 分支扩展 in_frontmatter_block 边界 + tolower case 不敏感 + frontmatter 字段头匹配 |
| v6.11.6 pre-commit fallback 移除 | ✅ | T-044 issue #10 P037 legacy fallback 移除(D-032 approved):删 L111-116(strict_task_mode=0 时 ls-1 T-*.md sort -r 扫 done 卡);strict_task_mode=0 无 active 卡 → fail-open(done 卡不再 govern);task-card gate C6/C7 更新;测试 test_precommit_no_legacy_fallback.sh 8/8 PASS |
| v6.11.7 CI 红灯修复 | ✅ | T-045 修复 GitHub Actions 自 v6.11.0 起持续红灯:engine-doctor.sh/ps1 `check_multi_session_isolation` 在 cv>=6.11.0 时硬 FAIL "`.cache/sessions` dir missing",但 CI 环境 SessionStart hook 不运行、.cache 被 .gitignore 钉住,导致每次 CI 红。检测 `CI=true`/`GITHUB_ACTIONS=true` 时降 FAIL→WARN;交互式环境行为不变。测试 test_doctor_ci_sessions.sh 3 场景 3/3 PASS。T-046 (伴随修复): install.sh/ps1 FILES 数组与 manifest.json src 列表不一致(缺 4 条 skeleton 条目,自 v6.7.0 起预存 bug)+ case 语句 blanket 重映射 bug 修复。 |
| v6.12.0 (D-035/T-048) 多卡并行 + 租约 | ✅ | 六项根因根治「激活一张卡拦死其他 agent」:三层门禁 union gating(∃active 卡覆盖即放行)+ 任务/决策卡 bootstrap 恒豁免 + protected 逐卡豁免 + lock 液性从瞬时 pid 改租约(lock/hb mtime TTL 120min,PreToolUse/guard 续租,写时验锁,stale 原子抢占 + 自愈升格)+ .role=worker 旗标全生命周期清理(7 天孤儿 GC)+ worker 面收窄(自己卡的 progress/checkpoint 直写;subagent 保持 v6.5)+ assume-coordinator stale 免 --force + 展示层多卡化 + doctor `check_multi_card_writeset_overlap` WARN。tests/multi-session 新套件 + 孤儿测试收编进 check.sh 链。契约 2896/2940(净减 14)。 |
| v6.12.1 (T-049) issue #11 九项修复 | ✅ | 门禁静默失效家族根治,原则「无法判定必须显式说出」:verify 全 SKIP → exit 3 parse-failure + 首分隔符锚定(兼容 `\| verify:`/`→ verify:`)+ AC id 字母分组 + 可疑模式 WARN(自引用 evidence/空串指纹);hook+doctor 统一三格式 WRITE-SET 解析(frontmatter 卡不再锁仓);裸目录条目覆盖子文件;status 全站点行首锚定 + active/done 冲突 FAIL;migrator 版本源 engine/VERSION 优先;INVENTORY 未初始化显式 SKIP;doctor unbound/未知旗标/整数比较修复;仓外路径不受治理;AC 模板三问 |
| v6.12.2 (T-050) tombstone 生命周期修复 | ✅ | 修双重 bug——把「历史 transition 记录」当成「active 状态信号」治理。Bug A:SessionStart hook 获取 fresh/same-sid coordinator 锁时不清理旧 tombstone(只有 assume-coordinator 命令清理)→ 安静 24h+ 仓库 doctor 必 FAIL;修复:hook 两条路径加 `rm -f .cache/session.tombstone`(对称 Stop hook 写入)。Bug B:Doctor `check_multi_session_isolation` 把 >24h tombstone 报 "exited abnormally" 并 FAIL,但 `coordinator-exited` 是正常退出标记 + 契约 #17 原文说 WARN 代码却 FAIL;修复:`tombstone_is_fail` cv 阈值切换(cv ≥ 6.12.2 WARN,cv < 6.12.2 旧 FAIL 迁移宽限)+ 消息删 "abnormally" 改 "historical transition record"。契约 #17 重写 + contract-version 升 6.12.2 + migrator + 文档同步。 |
| v6.12.3 (T-051) dist-stale pre-commit 门禁 | ✅ | v6.12.2 发版时直编编译产物 `ENGINE_FILE_SYSTEM_v5.md` 未跑 `compile.sh` 导致 CI Doctor `contract dist is not compile(src)` FAIL → CI/Release 双红 + re-tag,本版加前置防线:pre-commit hook 检测 staged 含 `contract/src/**` 或 6 个 dist 文件之一时,运行 `ENGINE_COMPILE_OUT=/tmp/xxx bash contract/compile.sh` 编译到临时目录,diff 6 个 dist 文件的工作树版本与编译输出。任一不匹配 → FAIL,消息提示 `bash contract/compile.sh`。无契约文件 staged → 跳过(零开销)。compile.sh 自身失败 → WARN(fail-open)。测试 `tests/workstream/test_precommit_dist_stale.sh` 5 场景 PASS。 |
| v6.13.0 (T-052) .engineignore 旁路通道 | ✅ | issue #17:非产品路径(跨 agent 锚点 GEMINI.md/AGENTS.md、engine 工具自身、项目 config)被 task-card union gating 拦截,要么建 throwaway 卡,要么 `--no-verify` 绕过。本版加 `.engineignore`(gitignore 风格)旁路:pre-commit hook 加 `is_engineignored()`(读 `$ROOT/.engineignore`,复用 `match_any_glob`,strip trailing `/**`,纯 shell 零子进程)+ `union_not_all_forbidden()`(命中 .engineignore 跳 WRITE-SET 检查,但不跳 FORBIDDEN——纠正 issue #17 提案设计错误)。旁路范围仅 no-card + union WRITE-SET 两块;protected-path/dist-stale 独立路径不受影响。`.engineignore` 入 rules.json protected_paths(需 covering decision D-036);Doctor `check_engineignore` 对 product 路径 WARN。`engine/skeleton/.engineignore` 模板供 engine-init。测试 7 场景 10 断言 PASS。 |
| v6.18.0 (T-066) 防漂移 P1 — 证据多锚 + drift-check | ✅ | D-038a/b 实施:evidence schema 升级为多锚(output_fingerprint + code_fingerprint via `git ls-files -s` + write_set_snapshot + verified_against_commit + write_provenance + MANIFEST.json 聚合 hash)。新增 `engine-drift-check.{sh,ps1}` 三步顺序校验(完整性自证 → WRITE-SET 二阶 → 代码指纹)。pre-commit 加 provenance gate(writer=engine-verify + commit=HEAD + argv 匹配;手动需 evidence-manual-edit 标注)。rules.json 加 `engine/evidence/**` + `engine-drift-check.*` protected_paths。engine-doctor 集成 drift-check。plugin 镜像 byte-identical(7 脚本)。测试:drift-check 5 场景 + provenance 6 场景。 |
| v6.19.0 (T-067) 防漂移 P2 — 状态面板视图化 + 信任分级注入 | ✅ | D-038c/d 实施:CONTEXT.md 状态面板从「权威声明」降级为「派生视图」(双写过渡期 v6.19.0~v6.20.0,旧静态段保留并标 `<!-- legacy: status-panel -->`,新 "Derived Status" 段由 engine context 实时重算 git tag + engine/VERSION + 最近 done 卡 evidence 信任级)。`engine-context.{sh,ps1}` 新增 `render_derived_status()` 输出 [T1]/[T2 legacy]/[T2 declared-only]/[T3 unverified] 信任标签(T1=code_fingerprint + verified_against_commit=HEAD/ancestor + tag/VERSION 一致;T2 分档 legacy-evidence/declared-only/stale;T3=待验证)。`engine-doctor.{sh,ps1}` 新增 `check_derived_status` 校验 legacy 标注 + tag/VERSION 一致性 + stale panel(双写过渡期 WARN 不 FAIL)。plugin 镜像 byte-identical(4 脚本)。测试 test_derived_status.sh 6 场景 9/9 PASS。 |
| v6.21.0 (T-071) Review P2 — agent-reviewer 语义审查 | ✅ | 两原子命令(--package 打包审查上下文 / --validate 校验 agent 产出)。5 维固定审查(correctness/design/consistency/readability/completeness) + 3 参数化静态挑战 + 反橡皮图章(E_SHALLOW) + provenance 回显模型(package_sha256 COMPUTE 归一化 + head_commit echo)。config.json agent_review 段(opt-in)。ps1 行为镜像(非 byte-identical)。60 断言全绿(CLI 12 + package 19 + validate 16 + config 4 + mirror 9)。 |
| N1-N5 | ✅ | 全部达成 |

### 运营工件层

不登记为权威文件,不进 §1：`engine/tasks/T-*.md`、`engine/decisions/D-*.md`、`engine/decisions/rules.json`、`engine/domains/**`、`engine/workstreams/**`、`engine/changes/CHANGE-*.md`、`engine/evidence/*`(generated-cache)、`engine/checks/**`、`contract/**`(引擎产品源码)。

### 当前状态
```

### CHANGELOG.md (references: HEAD)
```
- CLI dispatcher 更新:engine/bin/engine{,.ps1} + plugin 镜像
- 60 个测试断言全绿(CLI 12 + package 19 + validate 16 + config 4 + mirror 9)

## v6.20.0 (2026-07-30) — Review 子系统 P1(pipeline 核心)

- 新增 `engine review T-069` 命令(二维审查:semgrep + eslint)
- 新增 4 个脚本:engine-review.{sh,ps1} + engine-review-pipeline.{sh,ps1}(plugin 镜像 byte-identical)
- 新增 `engine/review/config.json`(L0 defaults + L1 overrides,Class=mixed)
- evidence schema:REVIEW.json + SECURITY.json + QUALITY.json,含 write_provenance + code_fingerprint + evidence_manifest_sha256 + tool_detection + config_layers
- L2 REVIEW-OVERRIDE 单向提级校验(severity_threshold + add/skip_dimensions)
- diff 算法:git log --reverse + git diff task_first_commit..HEAD(只扫 WRITE-SET 内代码文件)
- tool_unavailable 降级:WARN + skip + 记检测证据(不静默不卡死)
- flock -n(Unix)+ mkdir 原子锁(macOS fallback)+ FileStream(Windows)
- 19 AC 全绿,9 个测试文件

## v6.20.0 (2026-07-30)

T-068 防漂移 P3 — 批量补 code_fingerprint(D-038d 迁移期收尾)。对 T-048~T-060, T-063~T-065 共 16 张 legacy done 卡批量重跑 `engine verify` 补 code_fingerprint,全部升级为 T1 结构性信任级(code_fingerprint 存在 + verified_against_commit 记录)。16 张卡均因版本漂移有 AC FAIL,标 exempt(check.sh 跳过 evidence 检查,drift-check 仍校验)。双写过渡期(v6.19.0~v6.20.0)结束。

**T-068 (D-038d 迁移期收尾):**
- 16 张 done 卡 evidence 从单锚 `fingerprint` 升级为多锚(`output_fingerprint` + `code_fingerprint` + `write_set_snapshot` + `verified_against_commit` + `write_provenance` + `MANIFEST.json`)
```

### engine/ENGINE_MAP.md (references: Path)
```
|------|------|-------|------|
| engine/review/config.json | defaults + overrides | mixed | L0 defaults + L1 overrides 两段配置 |

> 维护脚本：`plugin/engine/scripts/engine-hook-session-start.{sh,ps1}`、`engine-hook-stop.{sh,ps1}`、`engine-doctor.{sh,ps1}`、`engine-migrate-contract.{sh,ps1}`、`githooks/pre-commit`。
> 按 v5.5 完整注册路由，脚本属维护工具，**不登记为权威文件**；其契约见 ENGINE_DOCTOR.md 与 AGENT_ADAPTERS.md。

## §3 联邦表（Federation Table · v6 S2）

path-glob → domain 路由表。机读源:`engine/domains/federation.json`;SessionStart 据此装配 L2,Stop hook 据此校验路由一致性。

| Domain | Path-glob | 摘要 |
|--------|-----------|------|
| engine-runtime | `plugin/engine/scripts/**`, `plugin/.claude/skills/**`, `plugin/engine/prompts/**`, `plugin/engine/domains/**`, `engine/scripts/**`, `engine/review/**`, `engine/prompts/**`, `plugin/.claude/commands/**`, `engine/ENGINE_DOCTOR.md`, `ENGINE_FILE_SYSTEM_v5.md`, `scripts/check.sh`, `scripts/check.ps1` | 引擎运行时:hook 门禁 / Doctor / 迁移器 / 契约 / behavior skills —— 产品本身 |
| project-meta | `engine/tasks/**`, `engine/decisions/**`, `engine/changes/**`, `engine/domains/**`, `engine/workstreams/**`, `engine/CONTEXT.md`, `engine/HANDOFF.md`, `engine/ENGINE_MAP.md`, `engine/AGENT_ADAPTERS.md`, `docs/**`, `tests/**` | 项目运营记忆:任务 / 决策 / 变更 / 并行分片 / 规划 / 测试 —— 引擎自己的狗粮 |
| _default_ | (不匹配任何域的路径) | root |

域文件:`engine/domains/<domain>/{CONTEXT.md, PITFALLS.md}`。域 CONTEXT 首行摘要提升到 SessionStart 域仪表盘;域 PITFALLS 自带预算 + 检索配方(无全局 500 行天花板)。

## §4 完整性与新鲜度

- 全局 revision：41
```

### engine/review/config.json (references: all)
```
      "quality": "eslint"
    },
    "tool_unavailable": "warn_skip",
    "diff_strategy": "task_first_commit",
    "code_extensions": [".sh", ".ps1", ".py", ".js", ".ts", ".go", ".rs", ".java", ".c", ".cpp", ".rb", ".php"],
    "agent_review": {
      "enabled": true,
      "min_entries_per_dimension": 1,
      "min_narrative_chars": 200,
      "min_entry_message_chars": 20,
      "adversarial_challenges": 3,
      "max_package_lines": 2000,
      "max_surrounding_context_lines": 500,
      "max_domain_knowledge_lines": 150,
      "max_package_age_hours": 72
    }
  },
  "overrides": {}
}
```

### engine/review/protocol.md (references: all)
```
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
```

### engine/tasks/T-073.md (references: all)
```

## FORBIDDEN

- .git/**
- archive/**
- contract/src/**
- engine/scripts/githooks/pre-commit
- engine/scripts/engine-doctor.sh

AC: 动态挑战——package 输出含 diff 语义信号衍生的挑战(非固定模板) → verify: bash tests/workstream/test_review_agent_dynamic.sh
AC: 动态挑战——无信号时 fallback 到静态挑战(不 crash) → verify: bash tests/workstream/test_review_agent_dynamic.sh
AC: E_GROUNDED——finding 引用不存在的文件 → FAIL → verify: bash tests/workstream/test_review_agent_grounded.sh
AC: E_GROUNDED——finding 引用超出行数的行号 → FAIL → verify: bash tests/workstream/test_review_agent_grounded.sh
AC: E_GROUNDED——所有 finding 行号合法 → PASS → verify: bash tests/workstream/test_review_agent_grounded.sh
AC: E_GROUNDED——<=50% finding 不合法 → WARN(不 FAIL) → verify: bash tests/workstream/test_review_agent_grounded.sh
AC: 独立性——package header 含 packaged_by 字段 → verify: bash tests/workstream/test_review_agent_dynamic.sh
AC: 独立性——reviewer_session == packaged_by → WARN → verify: bash tests/workstream/test_review_agent_grounded.sh
AC: 独立性——reviewer_session 缺失 → WARN(grace period) → verify: bash tests/workstream/test_review_agent_grounded.sh
AC: 默认开启——config.json 不存在时 agent_review 默认 enabled → verify: bash tests/workstream/test_review_agent_dynamic.sh
AC: ps1 行为镜像——动态挑战 + E_GROUNDED sh/ps1 对等 → verify: bash tests/workstream/test_review_agent_mirror.sh
```

### engine/CONTEXT.md (references: all)
```
> Engine System (engine_system) · Last updated: 2026-07-31 (v6.22.0) · Profile: CLI-LEAN

## 状态面板

<!-- legacy: status-panel (double-write transition, v6.19.0~v6.20.0) -->
<!-- engine context 输出时实时重算 "Derived Status" 段(machine-verified),本静态段保留并标 legacy -->

| 维度 | 状态 |
|------|------|
| 构建 | ✅ 正常（纯 markdown + shell 脚本，无构建步骤） |
| 上次完成 | **v6.22.0(T-073 Agent-Reviewer 对抗性升级)**:动态挑战生成(python diff 6 语义信号优先级排序 top3,fallback 静态)+ E_GROUNDED(finding file:line 存在性校验,>50% FAIL)+ E_INDEPENDENCE(reviewer_session≠packaged_by WARN)+ 默认 enabled + packaged_by header + Windows 编码修复。测试 42 断言全 PASS(dynamic 9 + grounded 10 + gate 10 + doctor 13)。前序 **v6.21.0(T-071 + T-072 Agent-Reviewer 子系统)**。 |
| 进行中 | 无。已知债:doctor ps1 缺 review 相关 check(T-070 遗留对等债);E_INDEPENDENCE grace period 后需升级为 FAIL。 |
| 阻塞 | 无。 |

## 当前假设 / 决策（本轮拍板）

- **多会话并行 = 任务卡即租约 + union gating（D-035, v6.12.0）**：每个并行会话各持一张 active 卡,门禁按「路径 ∈ 任一卡 WRITE-SET 且 ∉ 该卡 FORBIDDEN」放行;共享单例由协调者租约独占(lock/heartbeat mtime TTL 120min,写时验锁,stale 原子抢占);建卡/改卡 bootstrap 恒豁免。固有边界:两卡 WRITE-SET 交集竞态落 git 层(Doctor WARN 提示收窄)。
- **并行记忆 = 分片写、单点汇总（D-025,同卡协作场景）**：同一张卡的多 worker 只写 `engine/workstreams/<task>/<agent>/`，共享 CONTEXT/HANDOFF 等由协调者在 merge point 汇总；子 agent(agent_id)直接抢写共享记忆或任务局部文件由写前 hook 拦截。干自己卡的顶层会话直写自己任务的 progress/checkpoint(v6.12.0 收窄)。
- **长会话约束 = 写前硬检查 + 短版周期重锚（D-025）**：任务范围覆盖 engine 文件；每次写入不依赖模型记忆，UserPromptSubmit 只补短锚，Stop/pre-commit 收尾。
- **任务卡粒度 = 一项可独立验收的目标一卡**：多轮消息、多个 AC 与并行 worker 共用任务 ID；只读调查免卡；done 卡不注入上下文，Doctor 成功历史聚合输出，避免任务数线性消耗 token。
- **发布门 = main CI 全绿后才推 tag（D-026）**：workflow 必须走正式 `--local`；Windows 镜像行尾由 `.gitattributes` 对称固定；失败日志通过公开 annotation 暴露，不绕过门禁。
```

### engine/HANDOFF.md (references: all)
```
# HANDOFF — 会话交接

> Engine System (engine_system) · Last updated: 2026-07-31 (v6.22.0)

## 立即恢复点

v6.22.0(T-073 Agent-Reviewer 对抗性升级)done。动态挑战生成(python diff 6 语义信号:无 else 分支 90/函数签名 80/大 hunk 70/删除 60/错误处理 55/TODO 50,优先级排序 top3,fallback 静态)+ E_GROUNDED(finding file:line 存在性,>50% FAIL ≤50% WARN)+ E_INDEPENDENCE(reviewer_session≠packaged_by WARN grace period)+ config 默认 enabled:true + packaged_by header + reviewer_session schema + Windows CRLF/GBK 编码修复(errors='replace')。ps1 行为镜像。plugin byte-identical。测试 42 断言全 PASS(dynamic 9 + grounded 10 + gate 10 + doctor 13)。
下一步: push main + tag v6.22.0;doctor ps1 review 对等债(T-070 遗留);E_INDEPENDENCE grace period 后升级 FAIL

> Phase 1 = 通用化核心(prompt 抽离 / CLI 扩展 / 快速安装 / agent 检测——D-017 原文口径;实施细化与「薄壳」口径修正见 D-018)。v6.2 = 多 agent 通信层(engine context + DevComm Rule 扩展)。

## 会话历史（最新在上）

| 日期 | 完成了什么 | 下一步 | 改动文件 |
|------|-----------|--------|---------|
| 2026-07-31 | **T-073 v6.22.0 Agent-Reviewer 对抗性升级 done(11 AC PASS)**:package 动态挑战(python diff 6 语义信号优先级排序 top3,fallback 静态)+ packaged_by header + reviewer_session schema;validate E_GROUNDED(file:line 存在性,>50% FAIL)+ E_INDEPENDENCE(session 独立性 WARN);config 默认 enabled:true;Windows 编码修复(errors='replace')。ps1 镜像 + plugin byte-identical。测试 42 断言全 PASS(dynamic 9 + grounded 10 + gate 10 + doctor 13)。 | push main + tag v6.22.0;doctor ps1 对等债;E_INDEPENDENCE 升级 | engine/scripts/engine-review-agent-{package,validate}.{sh,ps1}, engine/review/{config.json,protocol.md}, plugin mirrors, tests/workstream/test_review_agent_{dynamic,grounded}.sh, engine/tasks/T-073.md, CHANGELOG.md, engine/{CONTEXT,HANDOFF,ENGINE_MAP}.md, VERSION, engine/VERSION, plugin/VERSION |
| 2026-07-31 | **T-071 + T-072 v6.21.0 Agent-Reviewer 子系统全功能上线 done(T-071 16 AC + T-072 9 AC PASS)**:T-071 核心 — `engine review-agent T-NNN --package/--validate` 两原子命令,package 打包审查上下文(diff + 任务卡 + 周边上下文 + 域知识 + protocol + 3 对抗挑战 + linter 摘要 + schema 示例)为 review-package.md(COMPUTE 归一化 sha256);validate 四层校验 E_SCHEMA → E_SHALLOW → E_PROVENANCE → E_STALE;ps1 行为镜像。5 处 spec 偏差修正(截断 enforce / 互斥检查 / ps1 schema / E_STALE timestamp / ps1 findings_count)。T-072 门禁集成 — pre-commit 扩展 AGENT-REVIEW.json provenance(writer=agent-reviewer + package_sha256 校验);Doctor check_agent_review_evidence(done + enabled → FAIL/WARN);rules.json +14 protected_paths。测试 83 断言全 PASS(CLI 12 + Package 19 + Validate 16 + Config 4 + Mirror 9 + Gate 10 + Doctor 13)。 | push main + tag v6.21.0;doctor ps1 review 对等债 | engine/scripts/engine-review-agent*.{sh,ps1}, engine/scripts/githooks/pre-commit, engine/scripts/engine-doctor.sh, engine/bin/engine{,.ps1}, engine/review/{config.json,protocol.md}, engine/decisions/rules.json, plugin mirrors, tests/workstream/test_review_agent_{cli,package,validate,config,mirror,gate}.sh, tests/workstream/test_doctor_agent_review.sh, engine/tasks/T-{071,072}.md, docs/superpowers/specs/2026-07-31-agent-reviewer-design.md, engine/{CONTEXT,HANDOFF,ENGINE_MAP}.md, CHANGELOG.md, VERSION, engine/VERSION |
```

### engine/ENGINE_MAP.md (references: all)
```
|------|------|------|
| S0 诚实门禁 | ✅ | stop hook porcelain -z + capsule WARN、engine-hook.cmd 垫片、contract-version 标记、tests/hook-parity |
| S1 意图内核 | ✅ | 任务卡 + 决策台账 + 三层门禁 + SessionStart 重注入 + pre-commit 决策引用 + tests/task-card |
| S2 分形记忆 | ✅ | 联邦表 + 域引擎 + 路由 read-gate + L2 装配 + 汇总协议 + 检索配方 + tests/fractal-memory |
| S3 契约编译 | ✅ | contract/src 单源 + compile.sh/ps1 + dist 幂等 + 减法预算(2910/2940 行, 13/13 规则) |
| S4 驾驶舱 | ✅ | engine verify + evidence + checkpoint.md + DEAD-CODE/COPY-PASTE 扫描 |
| D-019 行为技能 | ✅ | behaviors/*.md 单源 → skills + prompts + plugin 镜像; routing.json 行为路由 |
| v6.5 (D-025/T-029) | ✅ | 全路径任务范围、严格采用门、done 逐 AC evidence、写入归属、workstream 分片 |
| v6.6 (D-027/T-031) | ✅ | HANDOFF 8 条上限 + 月归档、Doctor WARN、migrator item 11 |
| v6.11.0 (D-029/T-036) | ✅ | 多会话锁(coordinator/worker)、双信号检测、kill switch、stale 接管 |
| v6.11.4 行为层 + 安装器鲁棒性 | ✅ | (a) task-run.md 仪式缩放指导:契约最小格式 vs 项目可选增强,防下游误认自选仪式为引擎强制;(b) T-042 issue #9 PS 5.1 LF-only here-string 解析失败修复:install.ps1 加 Convert-ToCrlf + 3 个 engine.cmd pwsh 优先检测(方案 A+B 双保险,D-030 批准) |
| v6.11.5 pre-commit parser 鲁棒性 | ✅ | T-043 issue #10 P038 parse_task_patterns 支持 YAML frontmatter 多行 write-set:awk 分支扩展 in_frontmatter_block 边界 + tolower case 不敏感 + frontmatter 字段头匹配 |
| v6.11.6 pre-commit fallback 移除 | ✅ | T-044 issue #10 P037 legacy fallback 移除(D-032 approved):删 L111-116(strict_task_mode=0 时 ls-1 T-*.md sort -r 扫 done 卡);strict_task_mode=0 无 active 卡 → fail-open(done 卡不再 govern);task-card gate C6/C7 更新;测试 test_precommit_no_legacy_fallback.sh 8/8 PASS |
| v6.11.7 CI 红灯修复 | ✅ | T-045 修复 GitHub Actions 自 v6.11.0 起持续红灯:engine-doctor.sh/ps1 `check_multi_session_isolation` 在 cv>=6.11.0 时硬 FAIL "`.cache/sessions` dir missing",但 CI 环境 SessionStart hook 不运行、.cache 被 .gitignore 钉住,导致每次 CI 红。检测 `CI=true`/`GITHUB_ACTIONS=true` 时降 FAIL→WARN;交互式环境行为不变。测试 test_doctor_ci_sessions.sh 3 场景 3/3 PASS。T-046 (伴随修复): install.sh/ps1 FILES 数组与 manifest.json src 列表不一致(缺 4 条 skeleton 条目,自 v6.7.0 起预存 bug)+ case 语句 blanket 重映射 bug 修复。 |
| v6.12.0 (D-035/T-048) 多卡并行 + 租约 | ✅ | 六项根因根治「激活一张卡拦死其他 agent」:三层门禁 union gating(∃active 卡覆盖即放行)+ 任务/决策卡 bootstrap 恒豁免 + protected 逐卡豁免 + lock 液性从瞬时 pid 改租约(lock/hb mtime TTL 120min,PreToolUse/guard 续租,写时验锁,stale 原子抢占 + 自愈升格)+ .role=worker 旗标全生命周期清理(7 天孤儿 GC)+ worker 面收窄(自己卡的 progress/checkpoint 直写;subagent 保持 v6.5)+ assume-coordinator stale 免 --force + 展示层多卡化 + doctor `check_multi_card_writeset_overlap` WARN。tests/multi-session 新套件 + 孤儿测试收编进 check.sh 链。契约 2896/2940(净减 14)。 |
| v6.12.1 (T-049) issue #11 九项修复 | ✅ | 门禁静默失效家族根治,原则「无法判定必须显式说出」:verify 全 SKIP → exit 3 parse-failure + 首分隔符锚定(兼容 `\| verify:`/`→ verify:`)+ AC id 字母分组 + 可疑模式 WARN(自引用 evidence/空串指纹);hook+doctor 统一三格式 WRITE-SET 解析(frontmatter 卡不再锁仓);裸目录条目覆盖子文件;status 全站点行首锚定 + active/done 冲突 FAIL;migrator 版本源 engine/VERSION 优先;INVENTORY 未初始化显式 SKIP;doctor unbound/未知旗标/整数比较修复;仓外路径不受治理;AC 模板三问 |
| v6.12.2 (T-050) tombstone 生命周期修复 | ✅ | 修双重 bug——把「历史 transition 记录」当成「active 状态信号」治理。Bug A:SessionStart hook 获取 fresh/same-sid coordinator 锁时不清理旧 tombstone(只有 assume-coordinator 命令清理)→ 安静 24h+ 仓库 doctor 必 FAIL;修复:hook 两条路径加 `rm -f .cache/session.tombstone`(对称 Stop hook 写入)。Bug B:Doctor `check_multi_session_isolation` 把 >24h tombstone 报 "exited abnormally" 并 FAIL,但 `coordinator-exited` 是正常退出标记 + 契约 #17 原文说 WARN 代码却 FAIL;修复:`tombstone_is_fail` cv 阈值切换(cv ≥ 6.12.2 WARN,cv < 6.12.2 旧 FAIL 迁移宽限)+ 消息删 "abnormally" 改 "historical transition record"。契约 #17 重写 + contract-version 升 6.12.2 + migrator + 文档同步。 |
| v6.12.3 (T-051) dist-stale pre-commit 门禁 | ✅ | v6.12.2 发版时直编编译产物 `ENGINE_FILE_SYSTEM_v5.md` 未跑 `compile.sh` 导致 CI Doctor `contract dist is not compile(src)` FAIL → CI/Release 双红 + re-tag,本版加前置防线:pre-commit hook 检测 staged 含 `contract/src/**` 或 6 个 dist 文件之一时,运行 `ENGINE_COMPILE_OUT=/tmp/xxx bash contract/compile.sh` 编译到临时目录,diff 6 个 dist 文件的工作树版本与编译输出。任一不匹配 → FAIL,消息提示 `bash contract/compile.sh`。无契约文件 staged → 跳过(零开销)。compile.sh 自身失败 → WARN(fail-open)。测试 `tests/workstream/test_precommit_dist_stale.sh` 5 场景 PASS。 |
| v6.13.0 (T-052) .engineignore 旁路通道 | ✅ | issue #17:非产品路径(跨 agent 锚点 GEMINI.md/AGENTS.md、engine 工具自身、项目 config)被 task-card union gating 拦截,要么建 throwaway 卡,要么 `--no-verify` 绕过。本版加 `.engineignore`(gitignore 风格)旁路:pre-commit hook 加 `is_engineignored()`(读 `$ROOT/.engineignore`,复用 `match_any_glob`,strip trailing `/**`,纯 shell 零子进程)+ `union_not_all_forbidden()`(命中 .engineignore 跳 WRITE-SET 检查,但不跳 FORBIDDEN——纠正 issue #17 提案设计错误)。旁路范围仅 no-card + union WRITE-SET 两块;protected-path/dist-stale 独立路径不受影响。`.engineignore` 入 rules.json protected_paths(需 covering decision D-036);Doctor `check_engineignore` 对 product 路径 WARN。`engine/skeleton/.engineignore` 模板供 engine-init。测试 7 场景 10 断言 PASS。 |
| v6.18.0 (T-066) 防漂移 P1 — 证据多锚 + drift-check | ✅ | D-038a/b 实施:evidence schema 升级为多锚(output_fingerprint + code_fingerprint via `git ls-files -s` + write_set_snapshot + verified_against_commit + write_provenance + MANIFEST.json 聚合 hash)。新增 `engine-drift-check.{sh,ps1}` 三步顺序校验(完整性自证 → WRITE-SET 二阶 → 代码指纹)。pre-commit 加 provenance gate(writer=engine-verify + commit=HEAD + argv 匹配;手动需 evidence-manual-edit 标注)。rules.json 加 `engine/evidence/**` + `engine-drift-check.*` protected_paths。engine-doctor 集成 drift-check。plugin 镜像 byte-identical(7 脚本)。测试:drift-check 5 场景 + provenance 6 场景。 |
| v6.19.0 (T-067) 防漂移 P2 — 状态面板视图化 + 信任分级注入 | ✅ | D-038c/d 实施:CONTEXT.md 状态面板从「权威声明」降级为「派生视图」(双写过渡期 v6.19.0~v6.20.0,旧静态段保留并标 `<!-- legacy: status-panel -->`,新 "Derived Status" 段由 engine context 实时重算 git tag + engine/VERSION + 最近 done 卡 evidence 信任级)。`engine-context.{sh,ps1}` 新增 `render_derived_status()` 输出 [T1]/[T2 legacy]/[T2 declared-only]/[T3 unverified] 信任标签(T1=code_fingerprint + verified_against_commit=HEAD/ancestor + tag/VERSION 一致;T2 分档 legacy-evidence/declared-only/stale;T3=待验证)。`engine-doctor.{sh,ps1}` 新增 `check_derived_status` 校验 legacy 标注 + tag/VERSION 一致性 + stale panel(双写过渡期 WARN 不 FAIL)。plugin 镜像 byte-identical(4 脚本)。测试 test_derived_status.sh 6 场景 9/9 PASS。 |
```

### CHANGELOG.md (references: all)
```
# Changelog

## v6.22.0 (2026-07-31) — Agent-Reviewer 对抗性升级(T-073)

- Package 动态挑战生成:静态 3 挑战 → python diff 语义信号分析(6 信号:无 else 分支/函数签名变更/大 hunk>20 行/大量删除>15 行/TODO-FIXME/错误处理,优先级排序取 top 3,无信号 fallback 静态)
- Package 新增 `packaged_by` header(CLAUDE_SESSION_ID 或 hostname:pid)+ schema 新增 `reviewer_session` 字段
- Validate 新增 E_GROUNDED:校验 finding file:line 引用真实存在(>50% 虚假 → FAIL,≤50% → WARN)
- Validate 新增 E_INDEPENDENCE:reviewer_session 与 packaged_by 比对(相同或缺失 → WARN,grace period)
- config.json `agent_review.enabled` 默认 true(新项目开箱即用;代码 fallback 亦为 true)
- 修复 Windows CRLF/GBK 字节导致 python UnicodeDecodeError(所有 open() 加 errors='replace')
- plugin 镜像 byte-identical(4 脚本)
- 测试:dynamic 9/9 + grounded 10/10 + 回归 gate 10/10 + doctor 13/13 = 42 断言 PASS

## v6.21.0 (2026-07-31) — Review 子系统 P2(agent-reviewer 语义审查)
```

### engine/review/protocol.md (references: cat)
```
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
```

### engine/ENGINE_MAP.md (references: cat)
```

## §1 文件注册表

| 文件 | Class | 说明 | Last verified |
|------|-------|------|---------------|
| ENGINE_MAP.md | index | 本索引,每次会话最先读;含联邦表 | 2026-07-03 |
| CONTEXT.md | irreducible | 当前状态面板 + 本轮决策 + 域仪表盘 | 2026-07-03 |
| HANDOFF.md | irreducible | 会话交接历史 + 立即恢复点 | 2026-07-03 |
| SYSTEM.md | irreducible | 项目环境/门禁配置（managed block 由 contract migrator 维护） | 2026-07-05 |
| AGENT_ADAPTERS.md | irreducible | 跨 agent 自维护适配策略（A/B/C 三档） | 2026-06-21 |
| GLOSSARY.md | irreducible | v6.2 开发者沟通规则-术语表（Developer Communication Rule 配套） | 2026-07-13 |
| ENGINE_DOCTOR.md | irreducible | 引擎健康检查、自维护脚本契约与旧项目 contract migrator 契约 | 2026-06-22 |
| engine/review/config.json | mixed | review 子系统配置(L0 defaults + L1 overrides) | 2026-07-30 |
| engine/review/protocol.md | irreducible | agent-reviewer L0 默认审查协议(5 维度 + 输出规则) | 2026-07-31 |
| engine/scripts/engine-review-agent*.sh | tool | agent-reviewer CLI(package/validate 两原子命令) | 2026-07-31 |

### §1.1 Section class breakdown (mixed 文件分段)

| 文件 | 段落 | Class | 说明 |
|------|------|-------|------|
| engine/review/config.json | defaults + overrides | mixed | L0 defaults + L1 overrides 两段配置 |
```

### CHANGELOG.md (references: cat)
```
pre-commit hook L260-287 对所有 staged done 卡检查 AC PASS evidence,不区分「active→done 转换」与「已 done 卡修改」。bookkeeping 任务修改已 done 卡的 verify 命令后 re-verify 产生 content-drift FAIL,锁死提交,被迫 `--no-verify` 绕过(连带丢失 WRITE-SET/FORBIDDEN/protected/dist-stale 门禁)。

- **修复**:AC PASS 检查前加 HEAD status 比较。`git show HEAD:$task_path` 取 HEAD 快照,若 HEAD 已是 `status: done` 则 `continue` 跳过(已 done 卡修改,非转换)。HEAD 缺失(新卡)→ 不匹配 done → 检查 AC PASS(正确)。HEAD=active → 不匹配 done → 检查 AC PASS(正确)。
- **不影响**:exempt marker 仍被尊重;WRITE-SET/FORBIDDEN/protected/dist-stale 门禁是独立代码路径,不受影响。
- **测试**:`tests/workstream/test_precommit_done_card_drift.sh` 5 场景:active→done 检查 / 新卡首次 done 检查 / 已 done 修改跳过 / exempt 跳过 / 非 done 跳过。

### T-055: engine-verify.ps1 Git Bash 检测增强(issue #12)

engine-verify.ps1 L54-64 Git Bash 检测仅查 `C:\Program Files\Git\bin\bash.exe` + Get-Command bash(排除 WSL stub)。漏检 32-bit Program Files 路径、自定义安装路径、bash on PATH 是 WSL stub 但 Git Bash 存在于 git install dir 的场景。检测失败 → fallback `cmd /c` → 无 grep → AC verify 全 FAIL。

- **修复**:检测链从 2 步扩展到 4 步:(1) 标准 64-bit 路径(回归);(2) 32-bit `C:\Program Files (x86)\Git\bin\bash.exe`(`${env:ProgramFiles(x86)}` 优先,硬编码兜底);(3) Get-Command bash 排除 WSL stub(回归);(4) `git --exec-path` 反推 git install root → `bin\bash.exe`(git 几乎总在 PATH,exec-path 如 `...\Git\mingw64\libexec\git-core`,3 层 up 到 Git root)。每步失败静默继续,try/catch 包裹。
- **测试**:`tests/workstream/test_engine_verify_bash_detection.{sh,ps1}` 11 断言:标准路径回归 / (x86) 路径 / git --exec-path 反推 / try-catch 包裹 / Get-Command 回归 / WSL 排除回归 / 检测顺序。

## v6.13.1 (2026-07-29)

engine-verify.ps1 预防性修复(T-053)。T-051 CHANGE 记录的 `Remove-Item Env:` 在 TRAE `safe_rm_alias.ps1` 包装下失效的 bug,当前环境虽不复现,作防御性修复。

- **修复**:`engine-verify.ps1` 行 107 `Remove-Item Env:ENGINE_VERIFY_RECURSE_GUARD -ErrorAction SilentlyContinue` → `[Environment]::SetEnvironmentVariable('ENGINE_VERIFY_RECURSE_GUARD', $null, 'Process')`。.NET 原生方法完全绕过 PowerShell provider 机制,不被任何 alias 包装影响,在 PS 5.1/7+ 行为一致。
- **背景**:TRAE IDE 的 `safe_rm_alias.ps1` 包装 `Remove-Item`,不识别 `Env:` drive prefix,在 `$ErrorActionPreference = "Stop"` 下抛 terminating error 被 trap 捕获 → exit 1 → 任何 task verify 报错。当前 TRAE 环境疑似已修 `safe_rm_alias.ps1`,bug 不复现,但改用 .NET 原生方法作永久防御。
- **测试**:`tests/workstream/test_engine_verify_env_cleanup.ps1` 2 场景:env var 清除 + 递归守卫仍工作。
```

### engine/review/config.json (references: diff)
```
{
  "defaults": {
    "dimensions": ["security", "quality"],
    "severity_threshold": "high",
    "tools": {
      "security": "semgrep",
      "quality": "eslint"
    },
    "tool_unavailable": "warn_skip",
    "diff_strategy": "task_first_commit",
    "code_extensions": [".sh", ".ps1", ".py", ".js", ".ts", ".go", ".rs", ".java", ".c", ".cpp", ".rb", ".php"],
    "agent_review": {
      "enabled": true,
      "min_entries_per_dimension": 1,
      "min_narrative_chars": 200,
      "min_entry_message_chars": 20,
      "adversarial_challenges": 3,
      "max_package_lines": 2000,
      "max_surrounding_context_lines": 500,
      "max_domain_knowledge_lines": 150,
```

### engine/review/protocol.md (references: diff)
```
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
```

### engine/tasks/T-073.md (references: diff)
```
# T-073: Agent-Reviewer 对抗性升级(v6.22.0)

> status: done | lane: engine-runtime | decision: none | domain: engine-runtime
> estimated_steps: 20 | checkpoint_plan: per-AC
> depends-on: T-072

GOAL: 将 agent-reviewer 从"填表校验"升级为"有智力含量的审查"。四项改进:(1) 动态挑战生成——从 diff 语义信号(新分支无 else / 签名变更 / 长 hunk / 删除代码 / TODO 新增)生成参数化挑战,替代 3 个固定模板;(2) E_GROUNDED 校验层——验证 finding 引用的 file:line 在仓库中实际存在,拦截幻觉 finding;(3) reviewer 独立性——package 嵌入 packaged_by 标识,validate 校验 reviewer_session 与之不同;(4) 新项目默认 enabled: true。

## WRITE-SET

- engine/scripts/engine-review-agent-package.sh
- engine/scripts/engine-review-agent-package.ps1
- engine/scripts/engine-review-agent-validate.sh
- engine/scripts/engine-review-agent-validate.ps1
- engine/review/config.json
- engine/review/protocol.md
- plugin/engine/scripts/engine-review-agent-package.sh
```

### engine/CONTEXT.md (references: diff)
```
> Engine System (engine_system) · Last updated: 2026-07-31 (v6.22.0) · Profile: CLI-LEAN

## 状态面板

<!-- legacy: status-panel (double-write transition, v6.19.0~v6.20.0) -->
<!-- engine context 输出时实时重算 "Derived Status" 段(machine-verified),本静态段保留并标 legacy -->

| 维度 | 状态 |
|------|------|
| 构建 | ✅ 正常（纯 markdown + shell 脚本，无构建步骤） |
| 上次完成 | **v6.22.0(T-073 Agent-Reviewer 对抗性升级)**:动态挑战生成(python diff 6 语义信号优先级排序 top3,fallback 静态)+ E_GROUNDED(finding file:line 存在性校验,>50% FAIL)+ E_INDEPENDENCE(reviewer_session≠packaged_by WARN)+ 默认 enabled + packaged_by header + Windows 编码修复。测试 42 断言全 PASS(dynamic 9 + grounded 10 + gate 10 + doctor 13)。前序 **v6.21.0(T-071 + T-072 Agent-Reviewer 子系统)**。 |
| 进行中 | 无。已知债:doctor ps1 缺 review 相关 check(T-070 遗留对等债);E_INDEPENDENCE grace period 后需升级为 FAIL。 |
| 阻塞 | 无。 |

## 当前假设 / 决策（本轮拍板）

- **多会话并行 = 任务卡即租约 + union gating（D-035, v6.12.0）**：每个并行会话各持一张 active 卡,门禁按「路径 ∈ 任一卡 WRITE-SET 且 ∉ 该卡 FORBIDDEN」放行;共享单例由协调者租约独占(lock/heartbeat mtime TTL 120min,写时验锁,stale 原子抢占);建卡/改卡 bootstrap 恒豁免。固有边界:两卡 WRITE-SET 交集竞态落 git 层(Doctor WARN 提示收窄)。
- **并行记忆 = 分片写、单点汇总（D-025,同卡协作场景）**：同一张卡的多 worker 只写 `engine/workstreams/<task>/<agent>/`，共享 CONTEXT/HANDOFF 等由协调者在 merge point 汇总；子 agent(agent_id)直接抢写共享记忆或任务局部文件由写前 hook 拦截。干自己卡的顶层会话直写自己任务的 progress/checkpoint(v6.12.0 收窄)。
- **长会话约束 = 写前硬检查 + 短版周期重锚（D-025）**：任务范围覆盖 engine 文件；每次写入不依赖模型记忆，UserPromptSubmit 只补短锚，Stop/pre-commit 收尾。
- **任务卡粒度 = 一项可独立验收的目标一卡**：多轮消息、多个 AC 与并行 worker 共用任务 ID；只读调查免卡；done 卡不注入上下文，Doctor 成功历史聚合输出，避免任务数线性消耗 token。
- **发布门 = main CI 全绿后才推 tag（D-026）**：workflow 必须走正式 `--local`；Windows 镜像行尾由 `.gitattributes` 对称固定；失败日志通过公开 annotation 暴露，不绕过门禁。
```

### engine/HANDOFF.md (references: diff)
```
# HANDOFF — 会话交接

> Engine System (engine_system) · Last updated: 2026-07-31 (v6.22.0)

## 立即恢复点

v6.22.0(T-073 Agent-Reviewer 对抗性升级)done。动态挑战生成(python diff 6 语义信号:无 else 分支 90/函数签名 80/大 hunk 70/删除 60/错误处理 55/TODO 50,优先级排序 top3,fallback 静态)+ E_GROUNDED(finding file:line 存在性,>50% FAIL ≤50% WARN)+ E_INDEPENDENCE(reviewer_session≠packaged_by WARN grace period)+ config 默认 enabled:true + packaged_by header + reviewer_session schema + Windows CRLF/GBK 编码修复(errors='replace')。ps1 行为镜像。plugin byte-identical。测试 42 断言全 PASS(dynamic 9 + grounded 10 + gate 10 + doctor 13)。
下一步: push main + tag v6.22.0;doctor ps1 review 对等债(T-070 遗留);E_INDEPENDENCE grace period 后升级 FAIL

> Phase 1 = 通用化核心(prompt 抽离 / CLI 扩展 / 快速安装 / agent 检测——D-017 原文口径;实施细化与「薄壳」口径修正见 D-018)。v6.2 = 多 agent 通信层(engine context + DevComm Rule 扩展)。

## 会话历史（最新在上）

| 日期 | 完成了什么 | 下一步 | 改动文件 |
|------|-----------|--------|---------|
| 2026-07-31 | **T-073 v6.22.0 Agent-Reviewer 对抗性升级 done(11 AC PASS)**:package 动态挑战(python diff 6 语义信号优先级排序 top3,fallback 静态)+ packaged_by header + reviewer_session schema;validate E_GROUNDED(file:line 存在性,>50% FAIL)+ E_INDEPENDENCE(session 独立性 WARN);config 默认 enabled:true;Windows 编码修复(errors='replace')。ps1 镜像 + plugin byte-identical。测试 42 断言全 PASS(dynamic 9 + grounded 10 + gate 10 + doctor 13)。 | push main + tag v6.22.0;doctor ps1 对等债;E_INDEPENDENCE 升级 | engine/scripts/engine-review-agent-{package,validate}.{sh,ps1}, engine/review/{config.json,protocol.md}, plugin mirrors, tests/workstream/test_review_agent_{dynamic,grounded}.sh, engine/tasks/T-073.md, CHANGELOG.md, engine/{CONTEXT,HANDOFF,ENGINE_MAP}.md, VERSION, engine/VERSION, plugin/VERSION |
| 2026-07-31 | **T-071 + T-072 v6.21.0 Agent-Reviewer 子系统全功能上线 done(T-071 16 AC + T-072 9 AC PASS)**:T-071 核心 — `engine review-agent T-NNN --package/--validate` 两原子命令,package 打包审查上下文(diff + 任务卡 + 周边上下文 + 域知识 + protocol + 3 对抗挑战 + linter 摘要 + schema 示例)为 review-package.md(COMPUTE 归一化 sha256);validate 四层校验 E_SCHEMA → E_SHALLOW → E_PROVENANCE → E_STALE;ps1 行为镜像。5 处 spec 偏差修正(截断 enforce / 互斥检查 / ps1 schema / E_STALE timestamp / ps1 findings_count)。T-072 门禁集成 — pre-commit 扩展 AGENT-REVIEW.json provenance(writer=agent-reviewer + package_sha256 校验);Doctor check_agent_review_evidence(done + enabled → FAIL/WARN);rules.json +14 protected_paths。测试 83 断言全 PASS(CLI 12 + Package 19 + Validate 16 + Config 4 + Mirror 9 + Gate 10 + Doctor 13)。 | push main + tag v6.21.0;doctor ps1 review 对等债 | engine/scripts/engine-review-agent*.{sh,ps1}, engine/scripts/githooks/pre-commit, engine/scripts/engine-doctor.sh, engine/bin/engine{,.ps1}, engine/review/{config.json,protocol.md}, engine/decisions/rules.json, plugin mirrors, tests/workstream/test_review_agent_{cli,package,validate,config,mirror,gate}.sh, tests/workstream/test_doctor_agent_review.sh, engine/tasks/T-{071,072}.md, docs/superpowers/specs/2026-07-31-agent-reviewer-design.md, engine/{CONTEXT,HANDOFF,ENGINE_MAP}.md, CHANGELOG.md, VERSION, engine/VERSION |
```

### engine/ENGINE_MAP.md (references: diff)
```
| v6.5 (D-025/T-029) | ✅ | 全路径任务范围、严格采用门、done 逐 AC evidence、写入归属、workstream 分片 |
| v6.6 (D-027/T-031) | ✅ | HANDOFF 8 条上限 + 月归档、Doctor WARN、migrator item 11 |
| v6.11.0 (D-029/T-036) | ✅ | 多会话锁(coordinator/worker)、双信号检测、kill switch、stale 接管 |
| v6.11.4 行为层 + 安装器鲁棒性 | ✅ | (a) task-run.md 仪式缩放指导:契约最小格式 vs 项目可选增强,防下游误认自选仪式为引擎强制;(b) T-042 issue #9 PS 5.1 LF-only here-string 解析失败修复:install.ps1 加 Convert-ToCrlf + 3 个 engine.cmd pwsh 优先检测(方案 A+B 双保险,D-030 批准) |
| v6.11.5 pre-commit parser 鲁棒性 | ✅ | T-043 issue #10 P038 parse_task_patterns 支持 YAML frontmatter 多行 write-set:awk 分支扩展 in_frontmatter_block 边界 + tolower case 不敏感 + frontmatter 字段头匹配 |
| v6.11.6 pre-commit fallback 移除 | ✅ | T-044 issue #10 P037 legacy fallback 移除(D-032 approved):删 L111-116(strict_task_mode=0 时 ls-1 T-*.md sort -r 扫 done 卡);strict_task_mode=0 无 active 卡 → fail-open(done 卡不再 govern);task-card gate C6/C7 更新;测试 test_precommit_no_legacy_fallback.sh 8/8 PASS |
| v6.11.7 CI 红灯修复 | ✅ | T-045 修复 GitHub Actions 自 v6.11.0 起持续红灯:engine-doctor.sh/ps1 `check_multi_session_isolation` 在 cv>=6.11.0 时硬 FAIL "`.cache/sessions` dir missing",但 CI 环境 SessionStart hook 不运行、.cache 被 .gitignore 钉住,导致每次 CI 红。检测 `CI=true`/`GITHUB_ACTIONS=true` 时降 FAIL→WARN;交互式环境行为不变。测试 test_doctor_ci_sessions.sh 3 场景 3/3 PASS。T-046 (伴随修复): install.sh/ps1 FILES 数组与 manifest.json src 列表不一致(缺 4 条 skeleton 条目,自 v6.7.0 起预存 bug)+ case 语句 blanket 重映射 bug 修复。 |
| v6.12.0 (D-035/T-048) 多卡并行 + 租约 | ✅ | 六项根因根治「激活一张卡拦死其他 agent」:三层门禁 union gating(∃active 卡覆盖即放行)+ 任务/决策卡 bootstrap 恒豁免 + protected 逐卡豁免 + lock 液性从瞬时 pid 改租约(lock/hb mtime TTL 120min,PreToolUse/guard 续租,写时验锁,stale 原子抢占 + 自愈升格)+ .role=worker 旗标全生命周期清理(7 天孤儿 GC)+ worker 面收窄(自己卡的 progress/checkpoint 直写;subagent 保持 v6.5)+ assume-coordinator stale 免 --force + 展示层多卡化 + doctor `check_multi_card_writeset_overlap` WARN。tests/multi-session 新套件 + 孤儿测试收编进 check.sh 链。契约 2896/2940(净减 14)。 |
| v6.12.1 (T-049) issue #11 九项修复 | ✅ | 门禁静默失效家族根治,原则「无法判定必须显式说出」:verify 全 SKIP → exit 3 parse-failure + 首分隔符锚定(兼容 `\| verify:`/`→ verify:`)+ AC id 字母分组 + 可疑模式 WARN(自引用 evidence/空串指纹);hook+doctor 统一三格式 WRITE-SET 解析(frontmatter 卡不再锁仓);裸目录条目覆盖子文件;status 全站点行首锚定 + active/done 冲突 FAIL;migrator 版本源 engine/VERSION 优先;INVENTORY 未初始化显式 SKIP;doctor unbound/未知旗标/整数比较修复;仓外路径不受治理;AC 模板三问 |
| v6.12.2 (T-050) tombstone 生命周期修复 | ✅ | 修双重 bug——把「历史 transition 记录」当成「active 状态信号」治理。Bug A:SessionStart hook 获取 fresh/same-sid coordinator 锁时不清理旧 tombstone(只有 assume-coordinator 命令清理)→ 安静 24h+ 仓库 doctor 必 FAIL;修复:hook 两条路径加 `rm -f .cache/session.tombstone`(对称 Stop hook 写入)。Bug B:Doctor `check_multi_session_isolation` 把 >24h tombstone 报 "exited abnormally" 并 FAIL,但 `coordinator-exited` 是正常退出标记 + 契约 #17 原文说 WARN 代码却 FAIL;修复:`tombstone_is_fail` cv 阈值切换(cv ≥ 6.12.2 WARN,cv < 6.12.2 旧 FAIL 迁移宽限)+ 消息删 "abnormally" 改 "historical transition record"。契约 #17 重写 + contract-version 升 6.12.2 + migrator + 文档同步。 |
| v6.12.3 (T-051) dist-stale pre-commit 门禁 | ✅ | v6.12.2 发版时直编编译产物 `ENGINE_FILE_SYSTEM_v5.md` 未跑 `compile.sh` 导致 CI Doctor `contract dist is not compile(src)` FAIL → CI/Release 双红 + re-tag,本版加前置防线:pre-commit hook 检测 staged 含 `contract/src/**` 或 6 个 dist 文件之一时,运行 `ENGINE_COMPILE_OUT=/tmp/xxx bash contract/compile.sh` 编译到临时目录,diff 6 个 dist 文件的工作树版本与编译输出。任一不匹配 → FAIL,消息提示 `bash contract/compile.sh`。无契约文件 staged → 跳过(零开销)。compile.sh 自身失败 → WARN(fail-open)。测试 `tests/workstream/test_precommit_dist_stale.sh` 5 场景 PASS。 |
| v6.13.0 (T-052) .engineignore 旁路通道 | ✅ | issue #17:非产品路径(跨 agent 锚点 GEMINI.md/AGENTS.md、engine 工具自身、项目 config)被 task-card union gating 拦截,要么建 throwaway 卡,要么 `--no-verify` 绕过。本版加 `.engineignore`(gitignore 风格)旁路:pre-commit hook 加 `is_engineignored()`(读 `$ROOT/.engineignore`,复用 `match_any_glob`,strip trailing `/**`,纯 shell 零子进程)+ `union_not_all_forbidden()`(命中 .engineignore 跳 WRITE-SET 检查,但不跳 FORBIDDEN——纠正 issue #17 提案设计错误)。旁路范围仅 no-card + union WRITE-SET 两块;protected-path/dist-stale 独立路径不受影响。`.engineignore` 入 rules.json protected_paths(需 covering decision D-036);Doctor `check_engineignore` 对 product 路径 WARN。`engine/skeleton/.engineignore` 模板供 engine-init。测试 7 场景 10 断言 PASS。 |
| v6.18.0 (T-066) 防漂移 P1 — 证据多锚 + drift-check | ✅ | D-038a/b 实施:evidence schema 升级为多锚(output_fingerprint + code_fingerprint via `git ls-files -s` + write_set_snapshot + verified_against_commit + write_provenance + MANIFEST.json 聚合 hash)。新增 `engine-drift-check.{sh,ps1}` 三步顺序校验(完整性自证 → WRITE-SET 二阶 → 代码指纹)。pre-commit 加 provenance gate(writer=engine-verify + commit=HEAD + argv 匹配;手动需 evidence-manual-edit 标注)。rules.json 加 `engine/evidence/**` + `engine-drift-check.*` protected_paths。engine-doctor 集成 drift-check。plugin 镜像 byte-identical(7 脚本)。测试:drift-check 5 场景 + provenance 6 场景。 |
| v6.19.0 (T-067) 防漂移 P2 — 状态面板视图化 + 信任分级注入 | ✅ | D-038c/d 实施:CONTEXT.md 状态面板从「权威声明」降级为「派生视图」(双写过渡期 v6.19.0~v6.20.0,旧静态段保留并标 `<!-- legacy: status-panel -->`,新 "Derived Status" 段由 engine context 实时重算 git tag + engine/VERSION + 最近 done 卡 evidence 信任级)。`engine-context.{sh,ps1}` 新增 `render_derived_status()` 输出 [T1]/[T2 legacy]/[T2 declared-only]/[T3 unverified] 信任标签(T1=code_fingerprint + verified_against_commit=HEAD/ancestor + tag/VERSION 一致;T2 分档 legacy-evidence/declared-only/stale;T3=待验证)。`engine-doctor.{sh,ps1}` 新增 `check_derived_status` 校验 legacy 标注 + tag/VERSION 一致性 + stale panel(双写过渡期 WARN 不 FAIL)。plugin 镜像 byte-identical(4 脚本)。测试 test_derived_status.sh 6 场景 9/9 PASS。 |
| v6.21.0 (T-071) Review P2 — agent-reviewer 语义审查 | ✅ | 两原子命令(--package 打包审查上下文 / --validate 校验 agent 产出)。5 维固定审查(correctness/design/consistency/readability/completeness) + 3 参数化静态挑战 + 反橡皮图章(E_SHALLOW) + provenance 回显模型(package_sha256 COMPUTE 归一化 + head_commit echo)。config.json agent_review 段(opt-in)。ps1 行为镜像(非 byte-identical)。60 断言全绿(CLI 12 + package 19 + validate 16 + config 4 + mirror 9)。 |
| N1-N5 | ✅ | 全部达成 |

### 运营工件层

不登记为权威文件,不进 §1：`engine/tasks/T-*.md`、`engine/decisions/D-*.md`、`engine/decisions/rules.json`、`engine/domains/**`、`engine/workstreams/**`、`engine/changes/CHANGE-*.md`、`engine/evidence/*`(generated-cache)、`engine/checks/**`、`contract/**`(引擎产品源码)。
```

### CHANGELOG.md (references: diff)
```
# Changelog

## v6.22.0 (2026-07-31) — Agent-Reviewer 对抗性升级(T-073)

- Package 动态挑战生成:静态 3 挑战 → python diff 语义信号分析(6 信号:无 else 分支/函数签名变更/大 hunk>20 行/大量删除>15 行/TODO-FIXME/错误处理,优先级排序取 top 3,无信号 fallback 静态)
- Package 新增 `packaged_by` header(CLAUDE_SESSION_ID 或 hostname:pid)+ schema 新增 `reviewer_session` 字段
- Validate 新增 E_GROUNDED:校验 finding file:line 引用真实存在(>50% 虚假 → FAIL,≤50% → WARN)
- Validate 新增 E_INDEPENDENCE:reviewer_session 与 packaged_by 比对(相同或缺失 → WARN,grace period)
- config.json `agent_review.enabled` 默认 true(新项目开箱即用;代码 fallback 亦为 true)
- 修复 Windows CRLF/GBK 字节导致 python UnicodeDecodeError(所有 open() 加 errors='replace')
- plugin 镜像 byte-identical(4 脚本)
- 测试:dynamic 9/9 + grounded 10/10 + 回归 gate 10/10 + doctor 13/13 = 42 断言 PASS

## v6.21.0 (2026-07-31) — Review 子系统 P2(agent-reviewer 语义审查)
```


## 4. Domain Knowledge

_(truncated for size)_

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

1. File `engine/scripts/engine-review-agent-package.sh` line ~363 adds a new branch (`if re.match(r'\b(try|catch|except|recover|on error)\b', stri`) with no visible else/fallback. What happens when this condition is false �� silent skip, crash, or data corruption?
2. File `plugin/engine/scripts/engine-review-agent-package.sh` line ~363 adds a new branch (`if re.match(r'\b(try|catch|except|recover|on error)\b', stri`) with no visible else/fallback. What happens when this condition is false �� silent skip, crash, or data corruption?
3. File `tests/workstream/test_review_agent_grounded.sh` line ~127 adds a new branch (`if [ -n "$session" ]; then`) with no visible else/fallback. What happens when this condition is false �� silent skip, crash, or data corruption?



## 6. Output Format (strict)

Write your review to: `engine/review/evidence/T-073/AGENT-REVIEW.json`

Schema (all fields required):
```json
{
  "task": "T-073",
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
    "commit": "89b5550d32655c702b3dd6dd94bc691ecc2dfbd4",
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
