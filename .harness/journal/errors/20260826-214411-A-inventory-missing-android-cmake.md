# Error Report - inventory-missing-android-cmake

## Metadata

- Level: **L3**
- Track: **A**
- Topic: inventory-missing-android-cmake
- Recorded: 2026-08-26T21:44:11Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

Source inventory assumed android/CMakeLists.txt existed; Android is integrated from the top-level CMake and Gradle wrapper instead. No files were changed.

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
