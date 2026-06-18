# Error Report - dist-missing-probe

## Metadata

- Level: **L3**
- Track: **B**
- Topic: dist-missing-probe
- Recorded: 2026-06-18T16:04:22Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

Probed dist/ directly before checking existence; Get-ChildItem failed because release output directory does not exist yet.

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
