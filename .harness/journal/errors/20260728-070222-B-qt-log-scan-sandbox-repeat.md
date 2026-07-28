# Error Report - qt-log-scan-sandbox-repeat

## Metadata

- Level: **L3**
- Track: **B**
- Topic: qt-log-scan-sandbox-repeat
- Recorded: 2026-07-28T07:02:22Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

Post-run scan re-read stale prior macOS launch warnings and could not rotate the external harness log because the sandbox cannot rename files under Library/Application Support.

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
