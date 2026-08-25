# Error Report - bilibili-site-attribution

## Metadata

- Level: **L1**
- Track: **C**
- Topic: bilibili-site-attribution
- Recorded: 2026-08-24T20:45:04Z
- Session: .harness/journal/sessions/20260825-0430-C-bilibili-site-attribution.md
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

cmake --build exited 1

## 2. Evidence

```
[1/10] Building C object src/service/CMakeFiles/time_arc_service.dir/windows/tracker/audio_tracker.c.obj
[2/10] Building C object CMakeFiles/timearc_windows_audio_tracker_test.dir/src/service/windows/tracker/audio_tracker.c.obj
[3/10] Automatic MOC and UIC for target timearc_windows_audio_title_policy_test
[4/9] Building C object CMakeFiles/timearc_windows_audio_title_policy_test.dir/tests/windows_audio_title_policy_test.c.obj
[5/9] Linking CXX executable timearc_windows_audio_tracker_test.exe
[6/9] Building C object CMakeFiles/timearc_windows_audio_title_policy_test.dir/src/service/windows/platform/audio_win.c.obj
[7/9] Building C object src/service/CMakeFiles/time_arc_service.dir/windows/platform/audio_win.c.obj
[8/9] Linking C executable time-arc-service.exe
FAILED: time-arc-service.exe
C:\WINDOWS\system32\cmd.exe /C "cd . && D:\TimeArc\QT\Tools\mingw1310_64\bin\gcc.exe -O3 -DNDEBUG  src/service/CMakeFiles/time_arc_service.dir/windows/main.c.obj src/service/CMakeFiles/time_arc_service.dir/windows/service_config.c.obj src/service/CMakeFiles/time_arc_service.dir/windows/tracker/usage_tracker.c.obj src/service/CMakeFiles/time_arc_service.dir/windows/tracker/foreground_state.c.obj src/service/CMakeFiles/time_arc_service.dir/windows/tracker/audio_tracker.c.obj src/service/CMakeFiles/time_arc_service.dir/windows/platform/active_app_win.c.obj src/service/CMakeFiles/time_arc_service.dir/windows/platform/app_identity.c.obj src/service/CMakeFiles/time_arc_service.dir/windows/platform/audio_win.c.obj src/service/CMakeFiles/time_arc_service.dir/windows/platform/idle_win.c.obj src/service/CMakeFiles/time_arc_service.dir/windows/platform/process_activity_win.c.obj src/service/CMakeFiles/time_arc_service.dir/windows/service/win_service.c.obj src/service/CMakeFiles/time_arc_service.dir/shared/data_bridge.c.obj src/service/CMakeFiles/time_arc_service.dir/shared/database_storage.c.obj src/service/CMakeFiles/time_arc_service.dir/shared/database_path.c.obj -o time-arc-service.exe -Wl,--out-implib,src\service\libtime-arc-service.dll.a -Wl,--major-image-version,0,--minor-image-version,0  thirdparty/sqlite3/libtime-arc-sqlite3.a  thirdparty/parson/libtime-arc-parson.a  -luser32  -lpsapi  -lole32  -luuid  -lkernel32 -luser32 -lgdi32 -lwinspool -lshell32 -lole32 -loleaut32 -luuid -lcomdlg32 -ladvapi32 && cd ."
D:/TimeArc/QT/Tools/mingw1310_64/bin/../lib/gcc/x86_64-w64-mingw32/13.1.0/../../../../x86_64-w64-mingw32/bin/ld.exe: cannot open output file time-arc-service.exe: Permission denied

collect2.exe: error: ld returned 1 exit status
[9/9] Linking CXX executable timearc_windows_audio_title_policy_test.exe
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
