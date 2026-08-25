# Error Report - release-defaults-game-clock-red

## Metadata

- Level: **L1**
- Track: **B**
- Topic: release-defaults-game-clock-red
- Recorded: 2026-08-25T03:09:22Z
- Session: .harness/journal/sessions/20260825-1057-B-release-defaults-game-clock.md
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

cmake --build exited 1

## 2. Evidence

```
[1/8] Automatic MOC and UIC for target timearc_windows_foreground_state_test
[2/7] Automatic MOC and UIC for target timearc_db_smoke
[3/6] Building C object CMakeFiles/timearc_windows_foreground_state_test.dir/tests/windows_foreground_state_test.c.obj
In file included from D:/TimeArc/time-arc/tests/windows_foreground_state_test.c:4:
D:/TimeArc/time-arc/tests/windows_foreground_state_test.c: In function 'test_foreground_game_identity_is_specific_to_main_game':
D:/TimeArc/time-arc/tests/windows_foreground_state_test.c:360:10: warning: implicit declaration of function 'timearc_win_is_foreground_game' [-Wimplicit-function-declaration]
  360 |   assert(timearc_win_is_foreground_game(
      |          ^~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
[4/6] Linking CXX executable timearc_windows_foreground_state_test.exe
FAILED: timearc_windows_foreground_state_test.exe
C:\WINDOWS\system32\cmd.exe /C "cd . && D:\TimeArc\QT\Tools\mingw1310_64\bin\g++.exe -O3 -DNDEBUG  CMakeFiles/timearc_windows_foreground_state_test.dir/timearc_windows_foreground_state_test_autogen/mocs_compilation.cpp.obj CMakeFiles/timearc_windows_foreground_state_test.dir/tests/windows_foreground_state_test.c.obj CMakeFiles/timearc_windows_foreground_state_test.dir/src/service/windows/platform/app_identity.c.obj CMakeFiles/timearc_windows_foreground_state_test.dir/src/service/windows/tracker/foreground_state.c.obj CMakeFiles/timearc_windows_foreground_state_test.dir/src/service/windows/platform/idle_win.c.obj CMakeFiles/timearc_windows_foreground_state_test.dir/src/service/windows/platform/process_activity_win.c.obj -o timearc_windows_foreground_state_test.exe -Wl,--out-implib,libtimearc_windows_foreground_state_test.dll.a -Wl,--major-image-version,0,--minor-image-version,0  -luser32  -lkernel32 -luser32 -lgdi32 -lwinspool -lshell32 -lole32 -loleaut32 -luuid -lcomdlg32 -ladvapi32 && cd ."
D:/TimeArc/QT/Tools/mingw1310_64/bin/../lib/gcc/x86_64-w64-mingw32/13.1.0/../../../../x86_64-w64-mingw32/bin/ld.exe: CMakeFiles/timearc_windows_foreground_state_test.dir/tests/windows_foreground_state_test.c.obj:windows_foreground_state_test.c:(.text.startup+0x1c7): undefined reference to `timearc_win_is_foreground_game'
D:/TimeArc/QT/Tools/mingw1310_64/bin/../lib/gcc/x86_64-w64-mingw32/13.1.0/../../../../x86_64-w64-mingw32/bin/ld.exe: CMakeFiles/timearc_windows_foreground_state_test.dir/tests/windows_foreground_state_test.c.obj:windows_foreground_state_test.c:(.text.startup+0x1db): undefined reference to `timearc_win_is_foreground_game'
D:/TimeArc/QT/Tools/mingw1310_64/bin/../lib/gcc/x86_64-w64-mingw32/13.1.0/../../../../x86_64-w64-mingw32/bin/ld.exe: CMakeFiles/timearc_windows_foreground_state_test.dir/tests/windows_foreground_state_test.c.obj:windows_foreground_state_test.c:(.text.startup+0x1ef): undefined reference to `timearc_win_is_foreground_game'
D:/TimeArc/QT/Tools/mingw1310_64/bin/../lib/gcc/x86_64-w64-mingw32/13.1.0/../../../../x86_64-w64-mingw32/bin/ld.exe: CMakeFiles/timearc_windows_foreground_state_test.dir/tests/windows_foreground_state_test.c.obj:windows_foreground_state_test.c:(.text.startup+0x203): undefined reference to `timearc_win_is_foreground_game'
D:/TimeArc/QT/Tools/mingw1310_64/bin/../lib/gcc/x86_64-w64-mingw32/13.1.0/../../../../x86_64-w64-mingw32/bin/ld.exe: CMakeFiles/timearc_windows_foreground_state_test.dir/tests/windows_foreground_state_test.c.obj:windows_foreground_state_test.c:(.text.startup+0x217): undefined reference to `timearc_win_is_foreground_game'

D:/TimeArc/QT/Tools/mingw1310_64/bin/../lib/gcc/x86_64-w64-mingw32/13.1.0/../../../../x86_64-w64-mingw32/bin/ld.exe: CMakeFiles/timearc_windows_foreground_state_test.dir/tests/windows_foreground_state_test.c.obj:windows_foreground_state_test.c:(.text.startup+0x22b): more undefined references to `timearc_win_is_foreground_game' follow

collect2.exe: error: ld returned 1 exit status
[5/6] Building CXX object CMakeFiles/timearc_db_smoke.dir/tests/db_smoke.cpp.obj
FAILED: CMakeFiles/timearc_db_smoke.dir/tests/db_smoke.cpp.obj
D:\TimeArc\QT\Tools\mingw1310_64\bin\g++.exe -DMINGW_HAS_SECURE_API=1 -DQT_CORE_LIB -DQT_NO_DEBUG -DQT_SQL_LIB -DUNICODE -DWIN32 -DWIN64 -D_ENABLE_EXTENDED_ALIGNED_STORAGE -D_UNICODE -D_WIN64 -ID:/TimeArc/time-arc/build/timearc_db_smoke_autogen/include -ID:/TimeArc/time-arc/src -ID:/TimeArc/time-arc/src/services -isystem D:/TimeArc/QT/6.11.0/mingw_64/include/QtCore -isystem D:/TimeArc/QT/6.11.0/mingw_64/include -isystem D:/TimeArc/QT/6.11.0/mingw_64/mkspecs/win32-g++ -isystem D:/TimeArc/QT/6.11.0/mingw_64/include/QtSql -O3 -DNDEBUG -std=gnu++17 -MD -MT CMakeFiles/timearc_db_smoke.dir/tests/db_smoke.cpp.obj -MF CMakeFiles\timearc_db_smoke.dir\tests\db_smoke.cpp.obj.d -o CMakeFiles/timearc_db_smoke.dir/tests/db_smoke.cpp.obj -c D:/TimeArc/time-arc/tests/db_smoke.cpp
D:/TimeArc/time-arc/tests/db_smoke.cpp:27:10: fatal error: services/autostart_default_policy.h: No such file or directory
   27 | #include "services/autostart_default_policy.h"
      |          ^~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
compilation terminated.

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
