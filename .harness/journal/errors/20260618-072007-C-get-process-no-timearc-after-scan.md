# Error Report - get-process-no-timearc-after-scan

## Metadata

- Level: **L3**
- Track: **C**
- Topic: get-process-no-timearc-after-scan
- Recorded: 2026-06-18T07:20:07Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

Get-Process TimeArc returned non-zero while checking for a process holding the Qt harness log after scan_qt_log rotate failed

## 2. Evidence

```
Get-Process : Cannot find a process with the name "TimeArc".
```

## 3. Root cause

- Immediate cause: `Get-Process TimeArc` exits non-zero when no process exists.
- Underlying cause: I used it as a check after the hidden smoke process had
  already exited.
- Why the harness/checklists did not prevent it: this is a PowerShell command
  behavior footgun, not a product issue.

## 4. Fix

- Files changed: none.
- Short description: recorded the command outcome; no product code change.
- Commit: pending.

## 5. Prevention

Use a non-throwing process query pattern when absence is expected.

## 6. Lessons for agents (L3)

- Wrong assumption:
- Earlier signal available:
- Rule file to update:
