# Error Report - qt-log-rotate-sandbox-denied

## Metadata

- Level: **L3**
- Track: **C**
- Topic: qt-log-rotate-sandbox-denied
- Recorded: 2026-06-14T09:41:46Z
- Session: (unknown)
- Platform: Windows desktop
- Tooling: `scan_qt_log.py`, approved `Move-Item`

## 1. What happened

scan_qt_log.py could read and record the external Qt log but failed to rotate it under sandbox restrictions; manually moved the log with approval

## 2. Evidence

```
scan_qt_log.py: rotate failed: [WinError 5] Access denied:
`C:\Users\Lenovo\AppData\Local\TimeArc\logs\harness-qt.log`
```

## 3. Root cause

- Immediate cause: the harness scanner attempted to rename a log outside the workspace under sandboxed permissions.
- Underlying cause: runtime logs live under `%LOCALAPPDATA%`, while the workspace write root is `D:\TimeArc\time-arc`.
- Why the harness/checklists did not prevent it: scan failures are recorded only after a Qt run, and the tool does not distinguish warning findings from rotate failure.

## 4. Fix

- Files changed: none.
- Short description: manually moved the stale log with approval, then reran a clean app launch; no Qt log was produced.
- Commit: not applicable.

## 5. Prevention

Potential harness upgrade: let `scan_qt_log.py` support a workspace-local consumed copy or truncate fallback when rotate is denied.

## 6. Lessons for agents (L3)

- Wrong assumption: scan_qt_log.py could rotate an external runtime log from the sandbox.
- Earlier signal available: the writable root is limited to the repository.
- Rule file to update: none; tool-level improvement is enough.
