# Error Report - rg-access-denied-copy-heatmap

## Metadata

- Level: **L3**
- Track: **C**
- Topic: rg-access-denied-copy-heatmap
- Recorded: 2026-06-18T06:36:42Z
- Session: (unknown)
- Platform: n-a
- Tooling: ripgrep, PowerShell

## 1. What happened

ripgrep failed with Access denied while locating remaining English copy and heatmap code; falling back to PowerShell Select-String.

## 2. Evidence

```
Program 'rg.exe' failed to run: Access is denied.
```

## 3. Root cause

- Immediate cause: `rg.exe` was not executable in this environment.
- Underlying cause: Local tool permissions vary independently from the repo.
- Why the harness/checklists did not prevent it: This is environment/tooling
  state, not source state.

## 4. Fix

- Files changed: none for product code.
- Short description: Fell back to `Get-ChildItem | Select-String`.
- Commit: pending

## 5. Prevention

One-off, no harness change needed.

## 6. Lessons for agents (L3)

- Wrong assumption: `rg` was available because it is normally preferred.
- Earlier signal available: Previous sessions had the same local access issue.
- Rule file to update: none.
