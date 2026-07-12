# Error Report - ctest-qstandardpaths-sandbox

## Metadata

- Level: **L2**
- Track: **B**
- Topic: ctest-qstandardpaths-sandbox
- Recorded: 2026-07-08T15:58:33Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

ctest timearc_db_smoke failed in sandbox because Qt test mode tried to create ~/.qttest database directories outside the writable workspace.

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
