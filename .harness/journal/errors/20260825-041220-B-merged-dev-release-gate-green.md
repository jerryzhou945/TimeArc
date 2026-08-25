# Error Report - merged-dev-release-gate-green

## Metadata

- Level: **L1**
- Track: **B**
- Topic: merged-dev-release-gate-green
- Recorded: 2026-08-25T04:12:20Z
- Session: .harness/journal/sessions/20260825-1143-B-release-readme-package-sync.md
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

cmake --build exited 1

## 2. Evidence

```
[1/200] Linking C executable time-arc-service.exe
[2/200] Linking CXX executable timearc_pomodoro_test.exe
[3/200] Linking CXX executable timearc_db_smoke.exe
[4/200] Automatic MOC and UIC for target time-arc
[5/200] Running AUTOMOC file extraction for target time-arc
[6/200] Running rcc for resource time-arc_raw_qml_0
[7/200] Running moc --collect-json for target time-arc
[8/30] Generating .rcc/qmlcache/time-arc_qml/desktop/pages/StatsViewModel_js.cpp
[9/30] Generating .rcc/qmlcache/time-arc_qml/desktop/components/AppVisual_js.cpp
[10/30] Generating .rcc/qmlcache/time-arc_qml/desktop/components/I18n_js.cpp
[11/30] Generating .rcc/qmlcache/time-arc_qml/desktop/MacMenuBar_qml.cpp, .rcc/qmlcache/time-arc_qml/desktop/MacMenuBar_qml.cpp.aotstats
[12/30] Generating .rcc/qmlcache/time-arc_qml/desktop/DesktopAppShell_qml.cpp, .rcc/qmlcache/time-arc_qml/desktop/DesktopAppShell_qml.cpp.aotstats
[13/30] Generating .rcc/qmlcache/time-arc_qml/desktop/pages/DesktopProfilePage_qml.cpp, .rcc/qmlcache/time-arc_qml/desktop/pages/DesktopProfilePage_qml.cpp.aotstats
[14/30] Generating .rcc/qmlcache/time-arc_qml/desktop/pages/DesktopStatsPage_qml.cpp, .rcc/qmlcache/time-arc_qml/desktop/pages/DesktopStatsPage_qml.cpp.aotstats
[15/30] Building CXX object CMakeFiles/time-arc.dir/build/.qt/rcc/qrc_time-arc_raw_qml_0.cpp.obj
[16/30] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/desktop/components/AppVisual_js.cpp.obj
[17/30] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/desktop/components/I18n_js.cpp.obj
[18/30] Building CXX object CMakeFiles/time-arc.dir/src/services/calendar_manager.cpp.obj
[19/30] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/desktop/pages/StatsViewModel_js.cpp.obj
[20/30] Building CXX object CMakeFiles/time-arc.dir/src/services/pomodoro_manager.cpp.obj
[21/30] Building CXX object CMakeFiles/time-arc.dir/src/services/mobile/mobile_ui_service.cpp.obj
[22/30] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/desktop/MacMenuBar_qml.cpp.obj
[23/30] Building CXX object CMakeFiles/time-arc.dir/time-arc_autogen/mocs_compilation.cpp.obj
[24/30] Building CXX object CMakeFiles/time-arc.dir/src/services/settings_repository.cpp.obj
[25/30] Building CXX object CMakeFiles/time-arc.dir/src/main.cpp.obj
[26/30] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/desktop/DesktopAppShell_qml.cpp.obj
[27/30] Building CXX object CMakeFiles/time-arc.dir/src/services/usage_stat_manager.cpp.obj
[28/30] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/desktop/pages/DesktopProfilePage_qml.cpp.obj
[29/30] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/desktop/pages/DesktopStatsPage_qml.cpp.obj
[30/30] Linking CXX executable TimeArc.exe
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
