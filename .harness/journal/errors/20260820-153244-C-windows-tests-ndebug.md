# Error Report - windows-tests-ndebug

## Metadata

- Level: **L2**
- Track: **C**
- Topic: windows-tests-ndebug
- Recorded: 2026-08-20T15:32:44Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

Release build defined NDEBUG, compiling every assert and the new regression call out of windows_foreground_state_test; force assertions active in this test translation unit

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
