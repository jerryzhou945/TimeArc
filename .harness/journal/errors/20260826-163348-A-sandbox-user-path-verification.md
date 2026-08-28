# Error Report - sandbox-user-path-verification

## Metadata

- Level: **L2**
- Track: **A**
- Topic: sandbox-user-path-verification
- Recorded: 2026-08-26T16:33:48Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

Non-escalated PATH verification ran as CodexSandboxOffline rather than the desktop user cangc and could not write that sandbox registry hive; elevated read confirmed all entries under cangc.

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
