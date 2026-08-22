# Error Report - test-cmake-path-assumption

## Metadata

- Level: **L3**
- Track: **C**
- Topic: test-cmake-path-assumption
- Recorded: 2026-08-22T03:24:28Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

Included nonexistent tests/CMakeLists.txt in a diagnostic Select-String command; test targets are declared elsewhere, so the lookup is repeated only on existing CMake files.

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
