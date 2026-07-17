@echo off
rem Engine System - Windows C-layer dispatch shim ("engine-hook.cmd 调度垫片")
rem
rem Claude Code on Windows runs hook commands via cmd.exe, where `bash` is often
rem NOT on PATH even when Git for Windows is installed (its installer only puts
rem Git\cmd -- i.e. git.exe -- on PATH by default). A settings.json that says
rem "bash engine/scripts/engine-hook-stop.sh" then dies silently and the whole
rem C-layer (self-maintenance hooks) goes mute. This shim makes dispatch honest:
rem   1) bash on PATH               -> canonical .sh implementation
rem   2) Git for Windows bash.exe   -> same .sh, found at standard install paths
rem   3) PowerShell twin (.ps1)     -> last resort, decision-identical by contract
rem
rem Usage: engine-hook.cmd <session-start|stop|session-end> [--guard|--pre-tool-use]
rem stdin (hook JSON payload) and the exit code pass through untouched.

setlocal
set "HERE=%~dp0"
set "NAME=%~1"
set "MODE=%~2"
if "%NAME%"=="" exit /b 0

where bash >nul 2>nul
if errorlevel 1 goto find_gitbash
if defined MODE (bash "%HERE%engine-hook-%NAME%.sh" "%MODE%") else (bash "%HERE%engine-hook-%NAME%.sh")
exit /b %errorlevel%

:find_gitbash
set "GITBASH="
if exist "%ProgramFiles%\Git\bin\bash.exe" set "GITBASH=%ProgramFiles%\Git\bin\bash.exe"
if not defined GITBASH if exist "%LocalAppData%\Programs\Git\bin\bash.exe" set "GITBASH=%LocalAppData%\Programs\Git\bin\bash.exe"
if not defined GITBASH goto find_ps
if defined MODE ("%GITBASH%" "%HERE%engine-hook-%NAME%.sh" "%MODE%") else ("%GITBASH%" "%HERE%engine-hook-%NAME%.sh")
exit /b %errorlevel%

:find_ps
if defined MODE (powershell -NoProfile -ExecutionPolicy Bypass -File "%HERE%engine-hook-%NAME%.ps1" -Mode "%MODE%") else (powershell -NoProfile -ExecutionPolicy Bypass -File "%HERE%engine-hook-%NAME%.ps1")
exit /b %errorlevel%
