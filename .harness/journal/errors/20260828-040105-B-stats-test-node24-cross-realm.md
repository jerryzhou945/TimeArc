# Error Report - stats-test-node24-cross-realm

## Metadata

- Level: **L1**
- Track: **B**
- Topic: stats-test-node24-cross-realm
- Recorded: 2026-08-28T04:01:05Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

stats_view_model_test failed at deepStrictEqual with identical array values under Node 24 because VM-context arrays have different prototypes; production output matched expected.

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
