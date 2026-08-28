# Error Report - codex-timing-apply-patch-wrapper

## Metadata

- Level: **L3**
- Track: **C**
- Topic: codex-timing-apply-patch-wrapper
- Recorded: 2026-08-27T21:08:56Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

The apply_patch.bat fallback truncated the multiline patch argument and rejected it before any file change; retrying the same apply-patch engine directly.

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
