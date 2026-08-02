# Error Report - git-index-lock-after-log-stash

## Metadata

- Level: **L3**
- Track: **B**
- Topic: git-index-lock-after-log-stash
- Recorded: 2026-08-02T02:11:11Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

A residual git process from the build-log stash holds .git/index.lock, preventing unstaging; verify exact lock and stop only the identified residual git PIDs.

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
