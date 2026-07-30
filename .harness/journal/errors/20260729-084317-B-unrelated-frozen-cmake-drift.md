# Error Report - unrelated-frozen-cmake-drift

## Metadata

- Level: **L3**
- Track: **B**
- Topic: unrelated-frozen-cmake-drift
- Recorded: 2026-07-29T08:43:17Z
- Session: (unknown)
- Platform: macOS
- Tooling: `.harness/tools/harness_check.py`, Git

## 1. What happened

Final harness check found an unrelated concurrent CMakeLists.txt frozen-file hash mismatch; this task did not edit that file

## 2. Evidence

```
[pass 2] frozen-file hashes
  DRIFT: CMakeLists.txt: hash mismatch
```

## 3. Root cause

- Immediate cause: committed `CMakeLists.txt` content no longer matches the
  harness's recorded frozen hash.
- Underlying cause: an unrelated concurrent commit added the macOS bundle
  identifier while this task was running.
- Why the harness/checklists did not prevent it: this session's preflight ran
  before that concurrent commit landed.

## 4. Fix

- Files changed: none by this task
- Short description: Preserved the concurrent change and reported the drift;
  resolving its frozen-file proposal/hash belongs to that change's owner.
- Commit: not applicable

## 5. Prevention

The concurrent frozen-file change must update its proposal and recorded hash.

## 6. Lessons for agents (L3)

- Wrong assumption: repository frozen-file state would remain stable through
  final validation.
- Earlier signal available: none; preflight passed before the concurrent commit.
- Rule file to update: none.
