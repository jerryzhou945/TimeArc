# Error Report - concatenated-sed-range

## Metadata

- Level: **L3**
- Track: **B**
- Topic: concatenated-sed-range
- Recorded: 2026-07-18T12:09:21Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

Used one sed line range across multiple files, so the requested later sections were counted over the concatenated stream and inspection output was misleading.

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
