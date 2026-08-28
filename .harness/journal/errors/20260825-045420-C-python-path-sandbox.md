# Error Report - python-path-sandbox

## Metadata

- Level: **L3**
- Track: **C**
- Topic: python-path-sandbox
- Recorded: 2026-08-25T04:54:20Z
- Session: .harness/journal/sessions/20260825-1254-C-installer-execution.md
- Platform: windows
- Tooling: managed Codex sandbox, repository-local Python 3.12

## 1. What happened

System Python invocation exited silently in the managed sandbox; switched to the repository-local Python runtime

## 2. Evidence

```
python .harness/tools/preflight.py --track C
exit_code: 1, output: empty

.local-python\Python312\python.exe .harness/tools/preflight.py --track C
exit_code: 0, harness_check.py: clean
```

## 3. Root cause

- Immediate cause: the external user-profile Python executable could not run successfully in the managed sandbox.
- Underlying cause: the command used `python` instead of the repository-local runtime already supplied for harness work.
- Why the harness/checklists did not prevent it: the first combined command did not surface the intermediate exit code, and the result was initially read as successful.

## 4. Fix

- Files changed: journal only
- Short description: use `.local-python\Python312\python.exe` for this session's harness commands.
- Commit: pending

## 5. Prevention

One-off environment issue; no harness change needed because the repository-local runtime is already available.

## 6. Lessons for agents (L3)

- Wrong assumption: a combined PowerShell command implied the first process had succeeded because later reads produced output.
- Earlier signal available: the direct tool result reported `exit_code: 1` and empty output.
- Rule file to update: none; check individual gate exit codes rather than chaining a mandatory gate with reads.
