# Error Report - frozen-hash-drift

## Metadata

- Level: **L2**
- Track: **B**
- Topic: frozen-hash-drift
- Recorded: 2026-07-09T09:34:43Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

harness_check failed after database_path rename because frozen-file hashes are stale for renamed files plus pre-existing data_bridge.h and usage_record.h edits.

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
