# Error Report - shell-path-not-reloaded

## Metadata

- Level: **L3**
- Track: **C**
- Topic: shell-path-not-reloaded
- Recorded: 2026-06-13T20:07:50Z
- Session: `.harness/journal/sessions/20260614-0403-C-cmake-d-drive-path.md`
- Platform: windows
- Tooling: PowerShell child process environment

## 1. What happened

After writing User PATH, a new tool-launched PowerShell still did not see cmake because the parent Codex process environment was not reloaded; using per-command PATH prefix for this session.

## 2. Evidence

```
After writing User PATH, a new tool-launched shell still reported:
cmake : The term 'cmake' is not recognized as the name of a cmdlet...
```

## 3. Root cause

- Immediate cause: Codex-launched PowerShell inherited PATH from the already-running parent process.
- Underlying cause: User PATH changes do not retroactively update the parent process environment.
- Why the harness/checklists did not prevent it: this is host-process behavior outside the repo.

## 4. Fix

- Files changed: none in source.
- Short description: used a per-command PATH prefix for this Codex session.
- Commit: none by user request.

## 5. Prevention

One-off environment behavior; no harness change.

## 6. Lessons for agents (L3)

- Wrong assumption: new tool shells would reload User PATH after `SetEnvironmentVariable`.
- Earlier signal available: Codex runs shell commands under an already-running parent process.
- Rule file to update: none.
