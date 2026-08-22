# Error Report - generated-log-double-cr

## Metadata

- Level: **L3**
- Track: **C**
- Topic: generated-log-double-cr
- Recorded: 2026-08-22T06:12:41Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

Generated Windows build logs contained doubled carriage returns, so trimming spaces and tabs alone did not satisfy diff-check; normalized added journal text to LF before rechecking.

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
