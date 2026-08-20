# Error Report - desktop-static-android-activity

## Metadata

- Level: **L3**
- Track: **C**
- Topic: desktop-static-android-activity
- Recorded: 2026-08-20T00:31:31Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

Full Python static suite found desktop_ux_static_test still expecting QtActivity after Android adopted TimeArcActivity; targeted Windows tests passed. Inspecting whether the test is stale before changing it.

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
