# Error Report - sqlite-live-query-console-encoding

## Metadata

- Level: **L3**
- Track: **C**
- Topic: sqlite-live-query-console-encoding
- Recorded: 2026-08-22T03:26:43Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

The corrected SQLite probe reached real rows but Windows GBK stdout could not encode a Unicode window-title character; retrying with UTF-8 stdout before using the evidence.

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
