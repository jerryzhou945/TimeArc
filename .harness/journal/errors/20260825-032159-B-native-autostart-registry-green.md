# Error Report - native-autostart-registry-green

## Metadata

- Level: **L1**
- Track: **B**
- Topic: native-autostart-registry-green
- Recorded: 2026-08-25T03:21:59Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

cmake --build exited 1

## 2. Evidence

```
[1/198] Automatic MOC and UIC for target time-arc
[2/197] Automatic MOC and UIC for target timearc_db_smoke
[3/196] Automatic MOC and UIC for target timearc_pomodoro_test
[4/195] Running AUTOMOC file extraction for target time-arc
[5/10] Building CXX object CMakeFiles/timearc_db_smoke.dir/src/services/settings_repository.cpp.obj
[6/10] Building CXX object CMakeFiles/timearc_pomodoro_test.dir/src/services/settings_repository.cpp.obj
[7/10] Linking CXX executable timearc_db_smoke.exe
[8/10] Linking CXX executable timearc_pomodoro_test.exe
[9/10] Building CXX object CMakeFiles/time-arc.dir/src/services/settings_repository.cpp.obj
[10/10] Linking CXX executable TimeArc.exe
FAILED: TimeArc.exe
C:\WINDOWS\system32\cmd.exe /C "cd . && D:\TimeArc\QT\Tools\mingw1310_64\bin\g++.exe -O3 -DNDEBUG -mwindows @CMakeFiles\time-arc.rsp -o TimeArc.exe -Wl,--out-implib,libTimeArc.dll.a -Wl,--major-image-version,0,--minor-image-version,0 && C:\WINDOWS\system32\cmd.exe /C "cd /D D:\TimeArc\time-arc\build && D:\TimeArc\QT\Tools\CMake_64\bin\cmake.exe -E make_directory D:/TimeArc/time-arc/build/assets && D:\TimeArc\QT\Tools\CMake_64\bin\cmake.exe -E remove -f D:/TimeArc/time-arc/build/assets/timearc-gui-assets.rcc && cd /D D:\TimeArc\time-arc\build && D:\TimeArc\QT\Tools\CMake_64\bin\cmake.exe -E copy_if_different D:/TimeArc/time-arc/build/timearc-backgrounds.rcc D:/TimeArc/time-arc/build/assets/timearc-backgrounds.rcc && cd /D D:\TimeArc\time-arc\build && D:\TimeArc\QT\Tools\CMake_64\bin\cmake.exe -E copy_if_different D:/TimeArc/time-arc/build/timearc-site-icons.rcc D:/TimeArc/time-arc/build/assets/timearc-site-icons.rcc && cd /D D:\TimeArc\time-arc\build && D:\TimeArc\QT\Tools\CMake_64\bin\cmake.exe -E copy_if_different D:/TimeArc/time-arc/build/timearc-monthly-recap.rcc D:/TimeArc/time-arc/build/assets/timearc-monthly-recap.rcc""
D:/TimeArc/QT/Tools/mingw1310_64/bin/../lib/gcc/x86_64-w64-mingw32/13.1.0/../../../../x86_64-w64-mingw32/bin/ld.exe: cannot open output file TimeArc.exe: Permission denied

collect2.exe: error: ld returned 1 exit status
ninja: build stopped: subcommand failed.
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
