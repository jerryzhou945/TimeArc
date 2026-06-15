# Error Report - process-check-nonzero

## Metadata

- Level: **L3**
- Track: **C**
- Topic: process-check-nonzero
- Recorded: 2026-06-15T05:31:18Z
- Session: `.harness/journal/sessions/20260615-1312-C-ui-stats-memorylake-language-followups.md`
- Platform: Windows PowerShell
- Tooling: `Stop-Process`, `Get-Process`

## 1. What happened

After stopping TimeArc, the follow-up Get-Process check returned non-zero because no process remained; the process stop itself succeeded.

## 2. Evidence

The combined stop/check command returned non-zero after no `TimeArc` process
remained.

## 3. Root cause

- Immediate cause: verification command treated "no process found" as failure.
- Underlying cause: the command combined cleanup and absence check.
- Why the harness/checklists did not prevent it: shell command shape issue.

## 4. Fix

- Files changed: none.
- Short description: process was stopped successfully; build was rerun.
- Commit: n/a

## 5. Prevention

One-off command shape issue; no harness change.

## 6. Lessons for agents (L3)

- Wrong assumption: no-process verification would exit cleanly.
- Earlier signal available: PowerShell command behavior.
- Rule file to update: none.
