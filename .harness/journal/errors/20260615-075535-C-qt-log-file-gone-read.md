# Error Report - qt-log-file-gone-read

## Metadata

- Level: **L3**
- Track: **C**
- Topic: qt-log-file-gone-read
- Recorded: 2026-06-15T07:55:35Z
- Session: (unknown)
- Platform: n-a
- Tooling: PowerShell, scan_qt_log.py

## 1. What happened

After scan_qt_log recorded warnings, attempted to read the harness Qt log path directly, but the file no longer existed; existing error reports contain the warning details.

## 2. Evidence

```
Get-Content C:\Users\Lenovo\AppData\Local\TimeArc\logs\harness-qt.log
failed after scan_qt_log had already consumed/rotated the relevant log state.
```

## 3. Root cause

- Immediate cause: Tried to inspect the raw harness Qt log path after relying on
  `scan_qt_log.py`.
- Underlying cause: Assumed the log file would remain available after scan output
  and auto error report creation.
- Why the harness/checklists did not prevent it: This was an auxiliary diagnostic
  command after the real warning had already been recorded.

## 4. Fix

- Files changed: none for product code.
- Short description: Used the generated error reports as the durable warning
  evidence, then fixed the underlying `GlassComboBox` warning.
- Commit: pending

## 5. Prevention

One-off command mistake; rely on `scan_qt_log.py` output and generated reports as
the source of truth.

## 6. Lessons for agents (L3)

- Wrong assumption: The raw log file would be present after the scan.
- Earlier signal available: `scan_qt_log.py` had already emitted and recorded the
  warning.
- Rule file to update: none.
