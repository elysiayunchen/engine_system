# engine/checks/ — Project-Custom Doctor Checks

Place executable `check-*.sh` / `check-*.ps1` (FAIL) or `warn-*.sh` / `warn-*.ps1` (WARN) scripts here.
Doctor discovers and runs them after all built-in checks. Stdout becomes the result message.

**Conventions:**
- `check-*.sh` / `check-*.ps1` — exit non-zero → FAIL
- `warn-*.sh` / `warn-*.ps1` — exit non-zero → WARN
- Exit 0 → PASS, stdout can include optional detail

**Example:**
```bash
#!/usr/bin/env bash
# check-branch-name.sh — enforce branch naming convention
BRANCH=$(git branch --show-current)
if [[ "$BRANCH" =~ ^(feature|fix|chore)/ ]]; then
  echo "Branch name OK: $BRANCH"
  exit 0
fi
echo "Branch '$BRANCH' does not match (feature|fix|chore)/*"
exit 1
```

Engine v6.3+ supports this directory. Remove or add scripts as your project needs.
