# T-053 progress — v6.13.1 engine-verify.ps1 预防性修复

> Task: T-053 | Status: done | Lane: engine-runtime

## Timeline

- 2026-07-29: 调查 PS dist-stale 门禁现状,发现 PS 版 pre-commit 不存在。用户选"先修 verify bug 再评估"。
- 2026-07-29: 复现 bug → 当前 TRAE 环境不复现(疑似 safe_rm_alias.ps1 已修)。用户选"预防性修复"。
- 2026-07-29: 建任务卡 T-053,修复 engine-verify.ps1 行 107 + plugin 镜像,写测试,verify 7/7 PASS。

## Key Decisions

- 修复方案:`Remove-Item Env:VAR` → `[Environment]::SetEnvironmentVariable('VAR', $null, 'Process')`(.NET 原生方法,绕过 PowerShell provider 机制)。
- 不从零新建 pre-commit.ps1(Git hook 走 sh 版,ps1 版实际不被调用,学术价值>实际价值)。

## Completion

7/7 AC PASS。`scripts/check.sh` CHECK PASSED。
