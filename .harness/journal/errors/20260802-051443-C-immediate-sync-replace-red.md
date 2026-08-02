# Error Report - immediate-sync-replace-red

## Metadata

- Level: **L3**
- Track: **C**
- Topic: immediate-sync-replace-red
- Recorded: 2026-08-02T05:14:43Z
- Session: (unknown)
- Platform: n-a
- Tooling: android_usage_static_test.py / WorkManager

## 1. What happened

Expected TDD RED: usage static test rejects ExistingWorkPolicy.REPLACE because resume can cancel active daily backfill

## 2. Evidence

```
AssertionError: missing resume sync coalescing without cancelling active work: ExistingWorkPolicy.KEEP
```

## 3. Root cause

- Immediate cause: the new regression intentionally failed while the scheduler still used REPLACE.
- Underlying cause: repeated Activity resumes could cancel a running daily backfill before its completion callback.
- Why the harness/checklists did not prevent it: the cancellation policy was not covered until the merge review identified the lifecycle race.

## 4. Fix

- Files changed: UsageSyncScheduler.java and tests/android_usage_static_test.py.
- Short description: changed unique immediate work to KEEP so resumes coalesce without cancelling active persistence.
- Commit: pending verification commit.

## 5. Prevention

The static regression now forbids REPLACE on the immediate daily backfill.

## 6. Lessons for agents (L3)

- Wrong assumption: that replacing a unique foreground-sync job was harmless.
- Earlier signal available: the job now spans daily partitions and only refreshes after completion.
- Rule file to update: none; regression coverage is the appropriate prevention.
