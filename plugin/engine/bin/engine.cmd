@echo off
rem Engine System CLI shim (forwards --kind/--print/-Kind and other args to engine.ps1)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0engine.ps1" %*
