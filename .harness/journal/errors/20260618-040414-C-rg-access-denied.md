# Error Report - rg-access-denied

## Metadata

- Level: **L3**
- Track: **C**
- Topic: rg-access-denied
- Recorded: 2026-06-18T04:04:14Z
- Session: (unknown)
- Platform: n-a
- Tooling: PowerShell, ripgrep

## 1. What happened

ripgrep failed with Access denied while scanning QML for residual English-mode Chinese copy; falling back to PowerShell Select-String.

## 2. Evidence

```
Program 'rg.exe' failed to run: Access is denied.
```

## 3. Root cause

- Immediate cause: `rg.exe` was not executable in this environment.
- Underlying cause: Local tool availability/permissions can vary independently
  of the repository.
- Why the harness/checklists did not prevent it: This is an environment/tooling
  issue, not project state.

## 4. Fix

- Files changed: none for product code.
- Short description: Fell back to PowerShell `Select-String` scans.
- Commit: pending

## 5. Prevention

One-off, no harness change needed.

## 6. Lessons for agents (L3)

- Wrong assumption: `rg` was available because it is normally preferred.
- Earlier signal available: none before the failed invocation.
- Rule file to update: none.
