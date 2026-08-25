# Error Report - sqlite-generated-column-misread

## Metadata

- Level: **L3**
- Track: **C**
- Topic: sqlite-generated-column-misread
- Recorded: 2026-08-24T16:29:11Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

Misread PRAGMA table_info as proving generated duration_sec was absent; source and table_xinfo show the column is valid, so no statistics SQL fix is needed.

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
