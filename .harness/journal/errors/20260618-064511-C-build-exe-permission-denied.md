# Error Report - build-exe-permission-denied

## Metadata

- Level: **L1**
- Track: **C**
- Topic: build-exe-permission-denied
- Recorded: 2026-06-18T06:45:11Z
- Session: (unknown)
- Platform: n-a
- Tooling: harness build.py, linker

## 1. What happened

Build failed at link because TimeArc.exe could not be overwritten: permission denied, likely a running TimeArc process.

## 2. Evidence

```
ld.exe: cannot open output file TimeArc.exe: Permission denied
```

## 3. Root cause

- Immediate cause: A running `TimeArc` process held `build/TimeArc.exe`.
- Underlying cause: The previous app run did not fully exit before relink.
- Why the harness/checklists did not prevent it: Build gates cannot overwrite a
  locked Windows executable.

## 4. Fix

- Files changed: none for product code.
- Short description: Stopped the running `TimeArc` process and reran
  `.harness/tools/build.py` successfully.
- Commit: pending

## 5. Prevention

One-off local process issue; check for running `TimeArc` before rebuild when
linking fails with permission denied.
