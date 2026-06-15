# Error Report - rg-access-denied

## Metadata

- Level: **L3**
- Track: **C**
- Topic: rg-access-denied
- Recorded: 2026-06-15T05:11:52Z
- Session: `.harness/journal/sessions/20260615-1312-C-ui-stats-memorylake-language-followups.md`
- Platform: Windows PowerShell
- Tooling: `rg`, PowerShell `Select-String`

## 1. What happened

rg.exe failed with Access is denied while searching UI regression code; falling back to PowerShell Select-String.

## 2. Evidence

PowerShell reported `Program 'rg.exe' failed to run: Access is denied`.

## 3. Root cause

- Immediate cause: local `rg.exe` could not be launched.
- Underlying cause: environment-specific executable access issue.
- Why the harness/checklists did not prevent it: tool availability is checked by
  use, not preflight.

## 4. Fix

- Files changed: none.
- Short description: used `Select-String` fallback for this session.
- Commit: n/a

## 5. Prevention

One-off environment issue; no harness change.

## 6. Lessons for agents (L3)

- Wrong assumption: `rg` was runnable because it is normally preferred.
- Earlier signal available: none before first search.
- Rule file to update: none.
