# Error Report - multiple-media-tabs-red

## Metadata

- Level: **L1**
- Track: **C**
- Topic: multiple-media-tabs-red
- Recorded: 2026-08-24T18:41:00Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

cmake --build exited 1

## 2. Evidence

```
[1/10] Building C object CMakeFiles/timearc_windows_audio_tracker_test.dir/src/service/windows/tracker/audio_tracker.c.obj
[2/10] Building C object src/service/CMakeFiles/time_arc_service.dir/windows/tracker/audio_tracker.c.obj
[3/10] Automatic MOC and UIC for target timearc_windows_audio_title_policy_test
[4/9] Linking CXX executable timearc_windows_audio_tracker_test.exe
[5/9] Building C object CMakeFiles/timearc_windows_audio_title_policy_test.dir/tests/windows_audio_title_policy_test.c.obj
[6/9] Building C object CMakeFiles/timearc_windows_audio_title_policy_test.dir/src/service/windows/platform/audio_win.c.obj
[7/9] Building C object src/service/CMakeFiles/time_arc_service.dir/windows/platform/audio_win.c.obj
[8/9] Linking CXX executable timearc_windows_audio_title_policy_test.exe
FAILED: timearc_windows_audio_title_policy_test.exe
C:\WINDOWS\system32\cmd.exe /C "cd . && D:\TimeArc\QT\Tools\mingw1310_64\bin\g++.exe -O3 -DNDEBUG  CMakeFiles/timearc_windows_audio_title_policy_test.dir/timearc_windows_audio_title_policy_test_autogen/mocs_compilation.cpp.obj CMakeFiles/timearc_windows_audio_title_policy_test.dir/tests/windows_audio_title_policy_test.c.obj CMakeFiles/timearc_windows_audio_title_policy_test.dir/src/service/windows/platform/audio_win.c.obj CMakeFiles/timearc_windows_audio_title_policy_test.dir/src/service/windows/platform/active_app_win.c.obj CMakeFiles/timearc_windows_audio_title_policy_test.dir/src/service/windows/platform/app_identity.c.obj -o timearc_windows_audio_title_policy_test.exe -Wl,--out-implib,libtimearc_windows_audio_title_policy_test.dll.a -Wl,--major-image-version,0,--minor-image-version,0  -luser32  -lpsapi  -lole32  -luuid  -lkernel32 -luser32 -lgdi32 -lwinspool -lshell32 -lole32 -loleaut32 -luuid -lcomdlg32 -ladvapi32 && cd ."
D:/TimeArc/QT/Tools/mingw1310_64/bin/../lib/gcc/x86_64-w64-mingw32/13.1.0/../../../../x86_64-w64-mingw32/bin/ld.exe: CMakeFiles/timearc_windows_audio_title_policy_test.dir/tests/windows_audio_title_policy_test.c.obj:windows_audio_title_policy_test.c:(.text.startup+0xb8): undefined reference to `timearc_win_merge_playback_state'
D:/TimeArc/QT/Tools/mingw1310_64/bin/../lib/gcc/x86_64-w64-mingw32/13.1.0/../../../../x86_64-w64-mingw32/bin/ld.exe: CMakeFiles/timearc_windows_audio_title_policy_test.dir/tests/windows_audio_title_policy_test.c.obj:windows_audio_title_policy_test.c:(.text.startup+0xd0): undefined reference to `timearc_win_merge_playback_state'

D:/TimeArc/QT/Tools/mingw1310_64/bin/../lib/gcc/x86_64-w64-mingw32/13.1.0/../../../../x86_64-w64-mingw32/bin/ld.exe: CMakeFiles/timearc_windows_audio_title_policy_test.dir/tests/windows_audio_title_policy_test.c.obj:windows_audio_title_policy_test.c:(.text.startup+0xe8): undefined reference to `timearc_win_merge_playback_state'

collect2.exe: error: ld returned 1 exit status
[9/9] Linking C executable time-arc-service.exe
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
