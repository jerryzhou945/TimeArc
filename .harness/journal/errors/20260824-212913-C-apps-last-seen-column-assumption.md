# Error Report - apps-last-seen-column-assumption

## Metadata

- Level: **L3**
- Track: **C**
- Topic: apps-last-seen-column-assumption
- Recorded: 2026-08-24T21:29:13Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

Live timing diagnostic assumed apps.last_seen_unix_sec exists; inspect the SQLite schema and query the actual column.

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
