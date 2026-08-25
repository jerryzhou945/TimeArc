# Error Report - dead-materialize-removal-broke-fixture

## Metadata

- Level: **L1**
- Track: **B**
- Topic: dead-materialize-removal-broke-fixture
- Recorded: 2026-08-25T12:55:52Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

Removed the now-callerless free materialize() helper during an audit; a grep over src/ and qml/ showed no users, but tests/db_smoke.cpp still called it for the store/reload round-trip. Build caught it. Reminder: dead-code greps must include tests/, not just the shipped tree.

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
