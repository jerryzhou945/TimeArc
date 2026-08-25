# Error Report - sqlite-media-column-assumption

## Metadata

- Level: **L3**
- Track: **C**
- Topic: sqlite-media-column-assumption
- Recorded: 2026-08-24T16:26:41Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

Read-only live DB probe assumed a playback_sec column, but current media_sessions stores duration as end_unix_sec minus start_unix_sec; rerunning from PRAGMA evidence.

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
