# Error Report - cmake-not-in-path

## Metadata

- Level: **L1**
- Track: **C**
- Topic: cmake-not-in-path
- Recorded: 2026-06-13T20:06:41Z
- Session: `.harness/journal/sessions/20260614-0403-C-cmake-d-drive-path.md`
- Platform: windows
- Tooling: PowerShell, Qt CMake 3.30.5 on D:

## 1. What happened

cmake was not discoverable from PATH; D-drive Qt CMake exists but User PATH only contained D:\TimeArc\Git\cmd.

## 2. Evidence

```
where.exe cmake
INFO: Could not find files for the given pattern(s).

D-drive candidates found:
D:\TimeArc\QT\Tools\CMake_64\bin\cmake.exe
D:\TimeArc\CMake\bin\cmake.exe
```

## 3. Root cause

- Immediate cause: `cmake` was not on PATH for harness `build.py`.
- Underlying cause: the toolchain now lives on D:, but User PATH only had `D:\TimeArc\Git\cmd`.
- Why the harness/checklists did not prevent it: the harness assumes `cmake` is discoverable.

## 4. Fix

- Files changed: User PATH outside git; `build/CMakeCache.txt` under ignored build output.
- Short description: added Qt CMake bin to User PATH and refreshed the build cache's RC compiler path.
- Commit: none by user request.

## 5. Prevention

One-off environment repair; no harness change.
