# Error Report - powershell-python-heredoc

## Metadata

- Level: **L3**
- Track: **C**
- Topic: powershell-python-heredoc
- Recorded: 2026-06-13T20:08:55Z
- Session: `.harness/journal/sessions/20260614-0403-C-cmake-d-drive-path.md`
- Platform: windows
- Tooling: PowerShell plus bundled Python

## 1. What happened

Tried to run python with bash-style heredoc in PowerShell while counting backlog items; rerunning with PowerShell here-string.

## 2. Evidence

```
PowerShell rejected:
python.exe - <<'PY'
with "Missing file specification after redirection operator."
```

## 3. Root cause

- Immediate cause: used bash-style heredoc syntax in PowerShell.
- Underlying cause: muscle-memory command style mismatch.
- Why the harness/checklists did not prevent it: this was an ad hoc analysis command.

## 4. Fix

- Files changed: none in source.
- Short description: reran the script with a PowerShell here-string piped to Python.
- Commit: none by user request.

## 5. Prevention

One-off command typo; no harness change.

## 6. Lessons for agents (L3)

- Wrong assumption: bash heredoc syntax would work in PowerShell.
- Earlier signal available: shell context is PowerShell.
- Rule file to update: none.
