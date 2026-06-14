# Error Report - mainstream-site-aggregation

## Metadata

- Level: **L1**
- Track: **C**
- Topic: mainstream-site-aggregation
- Recorded: 2026-06-14T02:55:57Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

cmake --build exited 1

## 2. Evidence

```
[1/142] Automatic MOC and UIC for target time-arc
[2/141] Running AUTOMOC file extraction for target time-arc
[3/4] Building CXX object CMakeFiles/time-arc.dir/src/services/usage_stat_manager.cpp.obj
[4/4] Linking CXX executable TimeArc.exe
FAILED: TimeArc.exe 
C:\WINDOWS\system32\cmd.exe /C "cd . && D:\TimeArc\QT\Tools\mingw1310_64\bin\g++.exe  -mwindows @CMakeFiles\time-arc.rsp -o TimeArc.exe -Wl,--out-implib,libTimeArc.dll.a -Wl,--major-image-version,0,--minor-image-version,0 && cd ."
D:/TimeArc/QT/Tools/mingw1310_64/bin/../lib/gcc/x86_64-w64-mingw32/13.1.0/../../../../x86_64-w64-mingw32/bin/ld.exe: cannot open output file TimeArc.exe: Permission denied

collect2.exe: error: ld returned 1 exit status
ninja: build stopped: subcommand failed.
```

## 3. Root cause

- Immediate cause: Windows could not overwrite `build/TimeArc.exe` during link.
- Underlying cause: A local TimeArc test process was still running from the
  build output directory.
- Why the harness/checklists did not prevent it: The harness cannot know when a
  manually launched GUI process is holding the linker output file.

## 4. Fix

- Files changed: none.
- Short description: Confirmed the running process path, stopped that local test
  process, then reran the full harness build successfully.
- Commit: pending.

## 5. Prevention

One-off local process lock; no harness change.
