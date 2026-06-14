# Error Report - build-output-locked-timearc

## Metadata

- Level: **L1**
- Track: **C**
- Topic: build-output-locked-timearc
- Recorded: 2026-06-14T09:18:23Z
- Session: (unknown)
- Platform: Windows desktop
- Tooling: `.local-python\Python312\python.exe .harness/tools/build.py`

## 1. What happened

Build failed because running TimeArc.exe locked the output binary; stop the app before relinking

## 2. Evidence

```
ld.exe: cannot open output file TimeArc.exe: Permission denied
```

## 3. Root cause

- Immediate cause: a running `TimeArc.exe` process held the output binary open.
- Underlying cause: Windows linker cannot overwrite an executable while it is running.
- Why the harness/checklists did not prevent it: the app had been left open from a prior manual run.

## 4. Fix

- Files changed: none.
- Short description: stopped the running `TimeArc` process and reran the build successfully.
- Commit: not applicable.

## 5. Prevention

One-off local runtime state; no harness change needed.
