# Error Report - categorization-settings-not-null

## Metadata

- Level: **L2**
- Track: **B**
- Topic: categorization-settings-not-null
- Recorded: 2026-08-25T08:59:11Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

restoreAllDefaults() wrote QString() to the settings row to mean 'follow defaults', but settings.value is NOT NULL and a null QString binds as SQL NULL, so the write was rejected and restore silently failed. Caught by the new manager lifecycle test. Now writes an empty string, which every reader already treats as FOLLOWING.

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
