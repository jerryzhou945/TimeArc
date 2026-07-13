# Error Report - sqlite-cli-missing

## Metadata

- Level: **L3**
- Track: **C**
- Topic: sqlite-cli-missing
- Recorded: 2026-07-12T09:24:01Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

Direct inspection of copied timearc_service.db could not use sqlite3 because the CLI is not installed; switching to Python stdlib sqlite3 in read-only mode.

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
