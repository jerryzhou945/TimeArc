# Error Report - sqlite-app-column-assumption

## Metadata

- Level: **L3**
- Track: **C**
- Topic: sqlite-app-column-assumption
- Recorded: 2026-08-24T16:26:51Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

Second read-only live DB probe assumed apps.app_name/app_id without reading the apps schema first; switching to PRAGMA-first query construction.

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
