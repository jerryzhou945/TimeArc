# Error Report - incomplete-test-surface

## Metadata

- Level: **L3**
- Track: **B**
- Topic: incomplete-test-surface
- Recorded: 2026-08-25T17:39:58Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

Reported '33/33 tests pass' from a tests/*_test.py glob, which is 33 of the 44 files in tests/. It silently excluded the three CMake-registered ctest targets, and one of them (timearc_db_smoke) was FAILING because of this session's own change: the mobile app-name fallback table was romanised, breaking 'Mobile friendly app naming'. Two of the 33 'passes' are also skips. Fixed the failure, ran ctest (3/3), and enumerated what genuinely cannot run here (4 Node tests, 3 WIN32-gated C tests, 1 PowerShell).

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
