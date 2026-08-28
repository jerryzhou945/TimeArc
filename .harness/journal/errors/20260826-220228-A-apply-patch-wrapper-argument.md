# Error Report - apply-patch-wrapper-argument

## Metadata

- Level: **L3**
- Track: **A**
- Topic: apply-patch-wrapper-argument
- Recorded: 2026-08-26T22:02:28Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

Two retries through apply_patch.bat lost the multiline patch terminator in cmd argument handling; invoking the underlying Codex apply-patch entry directly preserved UTF-8 newlines and succeeded.

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
