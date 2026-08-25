# Error Report - windows-native-icon-build

## Metadata

- Level: **L1**
- Track: **C**
- Topic: windows-native-icon-build
- Recorded: 2026-08-25T05:28:22Z
- Session: .harness/journal/sessions/20260825-1317-C-windows-native-icon.md
- Platform: n-a
- Tooling: harness build wrapper, CMake/Ninja, MinGW windres

## 1. What happened

cmake --build exited 1

## 2. Evidence

```
[1/230] Automatic MOC and UIC for target timearc_resource_bundle_smoke
[2/229] Automatic MOC and UIC for target timearc_windows_foreground_state_test
[3/227] Automatic MOC and UIC for target timearc_windows_audio_tracker_test
[4/225] Linking C executable time-arc-service.exe
[5/225] Automatic MOC and UIC for target timearc_windows_audio_title_policy_test
[6/224] Automatic MOC and UIC for target timearc_db_smoke
[7/223] Automatic MOC and UIC for target timearc_pomodoro_test
[8/222] Automatic MOC and UIC for target time-arc
[9/221] Linking CXX executable timearc_resource_bundle_smoke.exe
[10/221] Running AUTOMOC file extraction for target time-arc
[11/125] Linking CXX executable timearc_windows_audio_title_policy_test.exe
[12/125] Building CXX object CMakeFiles/timearc_pomodoro_test.dir/src/services/calendar_manager.cpp.obj
[13/125] Building CXX object CMakeFiles/time-arc.dir/src/services/timer_manager.cpp.obj
[14/125] Building RC object CMakeFiles/time-arc.dir/resources/bundle/windows/TimeArc.rc.obj
FAILED: CMakeFiles/time-arc.dir/resources/bundle/windows/TimeArc.rc.obj
F:\TimeArc\QT\Tools\mingw1310_64\bin\windres.exe -O coff -DMINGW_HAS_SECURE_API=1 -DQT_CORE_LIB -DQT_GUI_LIB -DQT_NEEDS_QMAIN -DQT_NETWORK_LIB -DQT_NO_DEBUG -DQT_OPENGL_LIB -DQT_QMLINTEGRATION_LIB -DQT_QML_LIB -DQT_QUICK_LIB -DQT_SQL_LIB -DQT_SVG_LIB -DQT_WIDGETS_LIB -DUNICODE -DWIN32 -DWIN64 -D_ENABLE_EXTENDED_ALIGNED_STORAGE -D_UNICODE -D_WIN64 -I D:/TimeArc/time-arc/build/time-arc_autogen/include -I D:/TimeArc/time-arc/src -I D:/TimeArc/time-arc/src/services -I D:/TimeArc/time-arc -I D:/TimeArc/time-arc/thirdparty/sqlite3 -I D:/TimeArc/time-arc/thirdparty/parson -I D:/TimeArc/QT/6.11.0/mingw_64/include/QtQml -I D:/TimeArc/QT/6.11.0/mingw_64/include -I D:/TimeArc/QT/6.11.0/mingw_64/include/QtCore -I D:/TimeArc/QT/6.11.0/mingw_64/mkspecs/win32-g++ -I D:/TimeArc/QT/6.11.0/mingw_64/include/QtQmlIntegration -I D:/TimeArc/QT/6.11.0/mingw_64/include/QtNetwork -I D:/TimeArc/QT/6.11.0/mingw_64/include/QtQuick -I D:/TimeArc/QT/6.11.0/mingw_64/ininja: fatal: ReadFile: The handle is invalid.


nclude/QtGui -I D:/TimeArc/QT/6.11.0/mingw_64/include/QtOpenGL -I D:/TimeArc/QT/6.11.0/mingw_64/include/QtSvg -I D:/TimeArc/QT/6.11.0/mingw_64/include/QtSql -I D:/TimeArc/QT/6.11.0/mingw_64/include/QtWidgets  D:/TimeArc/time-arc/resources/bundle/windows/TimeArc.rc CMakeFiles/time-arc.dir/resources/bundle/windows/TimeArc.rc.obj
CreateProcess failed: The system cannot find the file specified.
```

## 3. Root cause

- Immediate cause: the first retry still used stale F: RC compiler metadata.
- Underlying cause: setting the cache variable alone does not regenerate CMake's compiler-information file.
- Why the harness/checklists did not prevent it: the hidden metadata/cache distinction only became visible when windres ran.

## 4. Fix

- Files changed: generated build metadata only
- Short description: delete the stale RC compiler information file, reconfigure, and rebuild successfully.
- Commit:

## 5. Prevention

Documented in this error report; no production code workaround is appropriate.
