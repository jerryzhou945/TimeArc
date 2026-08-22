# Error Report - qt-log-rotate-running

## Metadata

- Level: **L3**
- Track: **C**
- Topic: qt-log-rotate-running
- Recorded: 2026-08-22T05:00:15Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

Qt log scan detected the runtime warning but could not rotate the log while TimeArc still held it open; stopped the UI before the verification scan.

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
