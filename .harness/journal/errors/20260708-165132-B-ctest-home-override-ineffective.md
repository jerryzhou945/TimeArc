# Error Report - ctest-home-override-ineffective

## Metadata

- Level: **L3**
- Track: **B**
- Topic: ctest-home-override-ineffective
- Recorded: 2026-07-08T16:51:32Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

Setting HOME to /private/tmp did not move macOS QStandardPaths AppDataLocation for the db smoke test inside the sandbox.

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
