# Error Report - service-output-location-assumption

## Metadata

- Level: **L3**
- Track: **C**
- Topic: service-output-location-assumption
- Recorded: 2026-07-12T09:20:12Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

Assumed the service binary would be emitted under build/src/service from its CMake subdirectory; user confirmed the Windows build emits only build/time-arc-service.exe, ruling out the deployment hypothesis.

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
