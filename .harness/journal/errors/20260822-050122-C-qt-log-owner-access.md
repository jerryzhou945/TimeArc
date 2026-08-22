# Error Report - qt-log-owner-access

## Metadata

- Level: **L3**
- Track: **C**
- Topic: qt-log-owner-access
- Recorded: 2026-08-22T05:01:22Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

Qt log rotation remained access denied after stopping both processes because the elevated app created a log the managed shell cannot rename; reran the scanner with elevated approval.

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
