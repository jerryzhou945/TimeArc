# Error Report - stats-test-ten-minute-expectation

## Metadata

- Level: **L1**
- Track: **B**
- Topic: stats-test-ten-minute-expectation
- Recorded: 2026-08-28T04:01:52Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

Stats ring test still expected the former 0.8-degree edge padding for a noon-straddling arc; production correctly used the new 5-degree/10-minute display floor.

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
