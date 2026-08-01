# Engine System — Mermaid 任务状态画布(v6.25.0 / T-082)
#
# 纯证据派生，无 LLM，无持久化（view not state）。
# 从 engine/evidence/T-NNN/AC-N.json 实时读取状态，生成 Mermaid flowchart。
#
# 用法:
#   powershell engine/scripts/engine-canvas.ps1 [T-NNN]
#   --guard   输出一行摘要（CANVAS: T-NNN M/N AC PASS）
#   无参数    对所有 active 任务生成画布
#
# 集成点: SessionStart（Active Task Card 之后）、Guard（一行摘要）
# 安全: fail-open，任何错误静默退出 0。

param(
    [string]$Mode = "full"
)

try {

$ROOT = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { $PWD.Path }
$ENGINE_DIR = Join-Path $ROOT "engine"

if (-not (Test-Path $ENGINE_DIR -PathType Container)) { exit 0 }

# ─── 辅助函数 ───────────────────────────────────────────────────────────────────────

# 从 AC-N.json 提取 status 字段（ConvertFrom-Json，不依赖 jq）
function Get-AcStatus {
    param([string]$FilePath)
    if (-not (Test-Path $FilePath -PathType Leaf)) { return "none" }
    try {
        $json = Get-Content $FilePath -Raw -ErrorAction Stop | ConvertFrom-Json
        if ($null -ne $json.status -and $json.status -ne '') { return [string]$json.status }
        return "none"
    } catch {
        return "none"
    }
}

# 从任务卡提取 GOAL 段第一行（截断 80 字符）
function Get-TaskGoal {
    param([string]$CardPath)
    $lines = Get-Content $CardPath -ErrorAction SilentlyContinue
    if (-not $lines) { return "" }
    $inGoal = $false
    foreach ($line in $lines) {
        if ($line -match '^## GOAL') { $inGoal = $true; continue }
        if ($inGoal) {
            if ($line -match '^## ') { break }
            if ($line.Trim() -eq '') { continue }
            $goal = $line.Trim()
            if ($goal.Length -gt 80) { $goal = $goal.Substring(0, 80) }
            return $goal
        }
    }
    return ""
}

# 从任务卡提取 AC 编号列表（复用 engine-verify 的 4 种格式）
function Get-AcIds {
    param([string]$CardPath)
    $content = Get-Content $CardPath -Raw -ErrorAction SilentlyContinue
    if (-not $content) { return @() }
    $found = [regex]::Matches($content, 'AC-[A-Za-z]*[0-9]+(?:\.[0-9]+)*') |
        ForEach-Object { $_.Value }
    if (-not $found) { return @() }
    # sort -t'-' -k2 -V | uniq — version-sort on numeric part after AC-
    $sorted = $found | Sort-Object {
        $numPart = $_ -replace '^AC-[A-Za-z]*', ''
        ($numPart -split '\.' | ForEach-Object { $_.PadLeft(10, '0') }) -join '.'
    } -Unique
    return @($sorted)
}

# 从 GATE.json 提取 status
function Get-GateStatus {
    param([string]$Task)
    $gateFile = Join-Path $ENGINE_DIR (Join-Path "evidence" (Join-Path $Task "GATE.json"))
    if (-not (Test-Path $gateFile -PathType Leaf)) { return "none" }
    try {
        $json = Get-Content $gateFile -Raw -ErrorAction Stop | ConvertFrom-Json
        if ($null -ne $json.status -and $json.status -ne '') { return [string]$json.status }
        return "none"
    } catch {
        return "none"
    }
}

# ─── 画布生成 ───────────────────────────────────────────────────────────────────────

function Write-Canvas {
    param([string]$Task)
    $card = Join-Path $ENGINE_DIR (Join-Path "tasks" "$Task.md")
    $evidenceDir = Join-Path $ENGINE_DIR (Join-Path "evidence" $Task)

    if (-not (Test-Path $card -PathType Leaf)) { return }

    # 卡片状态
    # 兼容两种格式: "status: active" 和 "> status: active | lane: ..."
    $cardLines = Get-Content $card -ErrorAction SilentlyContinue
    $cardStatus = ""
    foreach ($line in $cardLines) {
        if ($line -match '^>\s*status:\s*([^|]*)') {
            $cardStatus = $Matches[1].TrimEnd()
            break
        }
    }
    if ($cardStatus -eq '') {
        foreach ($line in $cardLines) {
            if ($line -match '^status:\s*(.*)') {
                $cardStatus = $Matches[1].Trim()
                break
            }
        }
    }

    $goal = Get-TaskGoal $card
    $gStatus = Get-GateStatus $Task

    # 收集 AC 列表
    $acIds = Get-AcIds $card
    if ($acIds.Count -eq 0) { return }

    $total = 0
    $passCount = 0
    $nodeLines = [System.Collections.Generic.List[string]]::new()
    $styleLines = [System.Collections.Generic.List[string]]::new()
    $edgeLines = [System.Collections.Generic.List[string]]::new()
    $prevId = ""
    $firstTodoFound = $false
    $idx = 0

    foreach ($acId in $acIds) {
        if ([string]::IsNullOrEmpty($acId)) { continue }
        $idx++
        $total++

        $statusFile = Join-Path $evidenceDir "$acId.json"
        $rawStatus = Get-AcStatus $statusFile
        $nodeStatus = ""
        $color = ""
        $summary = ""

        if ([string]::Equals($rawStatus, "pass", [System.StringComparison]::Ordinal)) {
            $nodeStatus = "done"
            $color = "#9f9"
            $passCount++
            # 提取时间戳作摘要
            $summary = "PASS"
            try {
                $json = Get-Content $statusFile -Raw -ErrorAction Stop | ConvertFrom-Json
                if ($null -ne $json.timestamp -and $json.timestamp -ne '') {
                    $ts = [string]$json.timestamp
                    if ($ts.Length -gt 10) { $ts = $ts.Substring(0, 10) }
                    $summary = "PASS @ $ts"
                }
            } catch { }
        }
        elseif ([string]::Equals($rawStatus, "fail", [System.StringComparison]::Ordinal)) {
            $nodeStatus = "blocked"
            $color = "#f99"
            $summary = "FAIL"
        }
        elseif ([string]::Equals($rawStatus, "blocked", [System.StringComparison]::Ordinal)) {
            $nodeStatus = "blocked"
            $color = "#f99"
            $summary = "blocked"
        }
        else {
            # todo — 第一个 todo（前面全是 done）推断为 doing
            if (-not $firstTodoFound) {
                $firstTodoFound = $true
                # 检查是否前面全是 done（passCount == idx-1）
                if ($passCount -eq ($idx - 1) -and $passCount -gt 0) {
                    $nodeStatus = "doing"
                    $color = "#ff9"
                    $summary = "in progress"
                } else {
                    $nodeStatus = "todo"
                    $color = "#f9f"
                    $summary = "no evidence"
                }
            } else {
                $nodeStatus = "todo"
                $color = "#f9f"
                $summary = "no evidence"
            }
        }

        $nodeId = "AC$idx"
        # 节点文本（Mermaid 内不能有无转义双引号）
        $label = "${acId}<br/>status: ${nodeStatus}<br/>summary: $summary"
        $nodeLines.Add("    ${nodeId}[`"$label`"]")
        $styleLines.Add("    style $nodeId fill:${color},stroke:#333")

        # 边
        if ($prevId -ne "") {
            $edgeLines.Add("    $prevId --> $nodeId")
        }
        $prevId = $nodeId
    }

    if ($total -eq 0) { return }

    # >8 AC 时纵向布局
    $direction = "LR"
    if ($total -gt 8) { $direction = "TD" }

    # 输出 Mermaid
    Write-Output "%%{taskGoal: `"$goal`", progress: `"$passCount/$total`", cardStatus: `"$cardStatus`", gateStatus: `"$gStatus`"}%%"
    Write-Output "graph $direction"
    foreach ($n in $nodeLines) { Write-Output $n }
    foreach ($e in $edgeLines) { Write-Output $e }
    foreach ($s in $styleLines) { Write-Output $s }
}

# ─── Guard 一行摘要 ──────────────────────────────────────────────────────────────────

function Write-GuardSummary {
    param([string]$Task)
    $card = Join-Path $ENGINE_DIR (Join-Path "tasks" "$Task.md")
    $evidenceDir = Join-Path $ENGINE_DIR (Join-Path "evidence" $Task)

    if (-not (Test-Path $card -PathType Leaf)) { return }

    $acIds = Get-AcIds $card
    if ($acIds.Count -eq 0) { return }

    $total = 0
    $passCount = 0
    foreach ($acId in $acIds) {
        if ([string]::IsNullOrEmpty($acId)) { continue }
        $total++
        $rawStatus = Get-AcStatus (Join-Path $evidenceDir "$acId.json")
        if ([string]::Equals($rawStatus, "pass", [System.StringComparison]::Ordinal)) {
            $passCount++
        }
    }

    Write-Output "CANVAS: $Task $passCount/$total AC PASS"
}

# ─── 主入口 ────────────────────────────────────────────────────────────────────────

function Find-ActiveTasks {
    $tasksDir = Join-Path $ENGINE_DIR "tasks"
    if (-not (Test-Path $tasksDir -PathType Container)) { return @() }
    $taskFiles = Get-ChildItem -Path $tasksDir -Filter "T-*.md" -File -ErrorAction SilentlyContinue
    if (-not $taskFiles) { return @() }
    $active = [System.Collections.Generic.List[string]]::new()
    foreach ($f in $taskFiles) {
        $taskId = $f.BaseName
        $lines = Get-Content $f.FullName -ErrorAction SilentlyContinue
        if (-not $lines) { continue }
        foreach ($line in $lines) {
            # 兼容 "status: active" 和 "> status: active | ..."
            if ($line -match '^status:\s*active') {
                $active.Add($taskId)
                break
            }
            if ($line -match '^>\s*status:\s*active') {
                $active.Add($taskId)
                break
            }
        }
    }
    return $active
}

if ([string]::Equals($Mode, "--guard", [System.StringComparison]::Ordinal)) {
    # 一行摘要模式
    $tasks = Find-ActiveTasks
    if ($tasks.Count -eq 0) { exit 0 }
    foreach ($t in $tasks) {
        Write-GuardSummary $t
    }
}
elseif ($Mode -match '^T-') {
    # 指定任务
    Write-Output '```mermaid'
    Write-Canvas $Mode
    Write-Output '```'
}
else {
    # 全部 active 任务
    $tasks = Find-ActiveTasks
    if ($tasks.Count -eq 0) { exit 0 }
    foreach ($t in $tasks) {
        Write-Output '```mermaid'
        Write-Canvas $t
        Write-Output '```'
        Write-Output ""
    }
}

exit 0

} catch {
    # fail-open: 任何未预期错误不阻断宿主 hook
    exit 0
}
