@echo off
rem Engine System CLI shim (forwards --kind/--print/-Kind, --force/assume-coordinator/tombstone, merge-workstream/--session-id, disable-multi-session, and other args to engine.ps1)
rem v6.11.4 (D-030/T-042) AC-3: prefer pwsh (PS 7) over powershell (PS 5.1) - PS 5.1 miscounts lines in LF-only .ps1 with here-strings (issue #9)
where pwsh >nul 2>&1
if %errorlevel% equ 0 (
  pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0engine.ps1" %*
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0engine.ps1" %*
)
