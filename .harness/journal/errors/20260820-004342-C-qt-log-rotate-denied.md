# Error Report - qt-log-rotate-denied

## Metadata

- Level: **L3**
- Track: **C**
- Topic: qt-log-rotate-denied
- Recorded: 2026-08-20T00:43:42Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

scan_qt_log read the user profile log but could not rotate it because a running TimeArc process holds the file; do not stop the user's app, verify with an isolated test log.

## 2. Evidence

```
(paste relevant log excerpt here)
```

## 3. Root cause

- Immediate cause:
- Underlying cause:
- Why the harness/checklists did not prevent it:

## 4. Fix

- Files changed:
- Short description:
- Commit:

## 5. Prevention

Concrete harness upgrade, or 'one-off, no harness change'.

## 6. Lessons for agents (L3)

- Wrong assumption:
- Earlier signal available:
- Rule file to update:
