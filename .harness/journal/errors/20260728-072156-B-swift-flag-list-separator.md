# Error Report - swift-flag-list-separator

## Metadata

- Level: **L3**
- Track: **B**
- Topic: swift-flag-list-separator
- Recorded: 2026-07-28T07:21:56Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

Configured CMAKE_Swift_FLAGS with a semicolon, which CMake emitted as a shell separator and caused the build to miss the module-cache-path argument.

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
