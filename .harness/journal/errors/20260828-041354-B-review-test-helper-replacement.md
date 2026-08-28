# Error Report - review-test-helper-replacement

## Metadata

- Level: **L1**
- Track: **B**
- Topic: review-test-helper-replacement
- Recorded: 2026-08-28T04:13:54Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

Mechanical replacement also rewrote the assertPlainDeepEqual helper body, creating recursion; restore its single call to assert.deepStrictEqual before running tests.

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
