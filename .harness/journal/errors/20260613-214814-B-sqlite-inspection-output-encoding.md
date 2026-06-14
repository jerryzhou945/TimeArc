# Error Report - sqlite-inspection-output-encoding

## Metadata

- Level: **L3**
- Track: **B**
- Topic: sqlite-inspection-output-encoding
- Recorded: 2026-06-13T21:48:14Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

SQLite inspection printed media rows containing emoji to a GBK PowerShell stream and then queried table-specific columns incorrectly; rerunning with PYTHONIOENCODING=utf-8 and table-specific queries.

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
