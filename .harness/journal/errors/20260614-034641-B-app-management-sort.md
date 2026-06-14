# Error Report - app-management-sort

## Metadata

- Level: **L1**
- Track: **B**
- Topic: app-management-sort
- Recorded: 2026-06-14T03:46:41Z
- Session: `.harness/journal/sessions/20260614-1120-B-app-list-icons-highres.md`
- Platform: Windows
- Tooling: `.harness/tools/build.py`

## 1. What happened

The full build failed at the final link step with `cannot open output file
TimeArc.exe: Permission denied`.

## 2. Evidence

```text
[147/147] Linking CXX executable TimeArc.exe
ld.exe: cannot open output file TimeArc.exe: Permission denied
collect2.exe: error: ld returned 1 exit status
```

## 3. Root cause

- Immediate cause: `build/TimeArc.exe` was still running.
- Underlying cause: the local GUI test process held the linker output file.
- Why the harness/checklists did not prevent it: the harness cannot detect a
  manually launched GUI process before linking.

## 4. Fix

- Files changed: none.
- Short description: confirmed the running process path, stopped the local
  `build/TimeArc.exe`, and reran the full build successfully.
- Commit: pending.

## 5. Prevention

One-off local process lock; no harness change.
