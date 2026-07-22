@echo off
rem Engine System CLI shim (forwards --kind/--print/-Kind, --force/assume-coordinator/tombstone, merge-workstream/--session-id, disable-multi-session, and other args to engine.ps1)
rem v6.11.1 (D-029/T-038) AC-5: workstream kind=subagent -> engine/workstreams/T-NNN/agents/a-<id>/; kind=session -> engine/workstreams/T-NNN/sessions/s-<id>/
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0engine.ps1" %*
