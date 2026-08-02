# T-088 worker handoff

- Patch the workflow to use `fetch-depth: 0` for Linux and Windows checks.
- Keep all installer and manifest source sets equal; update manifest hashes after hook changes.
- Verify `tests/task-card/run-task-tests.sh` and the SessionStart hook line cap before commit.
