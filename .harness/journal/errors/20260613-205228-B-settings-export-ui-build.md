# Error Report - settings-export-ui-build

## Metadata

- Level: **L1**
- Track: **B**
- Topic: settings-export-ui-build
- Recorded: 2026-06-13T20:52:28Z
- Session: `.harness/journal/sessions/20260614-0440-B-alpha-polish-g1-g4.md`
- Platform: windows
- Tooling: harness build.py, CMake/Ninja/MinGW

## 1. What happened

cmake --build exited 1

## 2. Evidence

```
[1/7] Copying time-arc qml sources into build dir
[2/7] Running qmlimportscanner for time-arc
[3/7] Running rcc for resource time-arc_raw_qml_0
[4/7] Generating .rcc/qmlcache/time-arc_qml/desktop/pages/DesktopProfilePage_qml.cpp, .rcc/qmlcache/time-arc_qml/desktop/pages/DesktopProfilePage_qml.cpp.aotstats
[5/7] Building CXX object CMakeFiles/time-arc.dir/build/.qt/rcc/qrc_time-arc_raw_qml_0.cpp.obj
FAILED: CMakeFiles/time-arc.dir/build/.qt/rcc/qrc_time-arc_raw_qml_0.cpp.obj 
D:\TimeArc\QT\Tools\mingw1310_64\bin\g++.exe -DMINGW_HAS_SECURE_API=1 -DQT_CORE_LIB -DQT_GUI_LIB -DQT_NEEDS_QMAIN -DQT_NETWORK_LIB -DQT_NO_DEBUG -DQT_OPENGL_LIB -DQT_QMLINTEGRATION_LIB -DQT_QML_LIB -DQT_QUICK_LIB -DQT_SQL_LIB -DQT_SVG_LIB -DQT_WIDGETS_LIB -DUNICODE -DWIN32 -DWIN64 -D_ENABLE_EXTENDED_ALIGNED_STORAGE -D_UNICODE -D_WIN64 -ID:/TimeArc/time-arc/build/time-arc_autogen/include -ID:/TimeArc/time-arc/src -ID:/TimeArc/time-arc/src/services -ID:/TimeArc/time-arc -ID:/TimeArc/time-arc/thirdparty/sqlite3 -ID:/TimeArc/time-arc/thirdparty/parson -isystem D:/TimeArc/QT/6.11.0/mingw_64/include/QtQml -isystem D:/TimeArc/QT/6.11.0/mingw_64/include -isystem D:/TimeArc/QT/6.11.0/mingw_64/include/QtCore -isystem D:/TimeArc/QT/6.11.0/mingw_64/mkspecs/win32-g++ -isystem D:/TimeArc/QT/6.11.0/mingw_64/include/QtQmlIntegration -isystem D:/TimeArc/QT/6.11.0/mingw_64/include/QtNetwork -isystem D:/TimeArc/QT/6.11.0/mingw_64/include/QtQuick -isystem D:/TimeArc/QT/6.11.0/mingw_64/include/QtGui -isystem D:/TimeArc/QT/6.11.0/mingw_64/include/QtOpenGL -isystem D:/TimeArc/QT/6.11.0/mingw_64/include/QtSvg -isystem D:/TimeArc/QT/6.11.0/mingw_64/include/QtSql -isystem D:/TimeArc/QT/6.11.0/mingw_64/include/QtWidgets -std=gnu++17 -MD -MT CMakeFiles/time-arc.dir/build/.qt/rcc/qrc_time-arc_raw_qml_0.cpp.obj -MF CMakeFiles\time-arc.dir\build\.qt\rcc\qrc_time-arc_raw_qml_0.cpp.obj.d -o CMakeFiles/time-arc.dir/build/.qt/rcc/qrc_time-arc_raw_qml_0.cpp.obj -c D:/TimeArc/time-arc/build/.qt/rcc/qrc_time-arc_raw_qml_0.cpp
[6/7] Building CXX object CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/desktop/pages/DesktopProfilePage_qml.cpp.obj
FAILED: CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/desktop/pages/DesktopProfilePage_qml.cpp.obj 
D:\TimeArc\QT\Tools\mingw1310_64\bin\g++.exe -DMINGW_HAS_SECURE_API=1 -DQT_CORE_LIB -DQT_GUI_LIB -DQT_NEEDS_QMAIN -DQT_NETWORK_LIB -DQT_NO_DEBUG -DQT_OPENGL_LIB -DQT_QMLINTEGRATION_LIB -DQT_QML_LIB -DQT_QUICK_LIB -DQT_SQL_LIB -DQT_SVG_LIB -DQT_WIDGETS_LIB -DUNICODE -DWIN32 -DWIN64 -D_ENABLE_EXTENDED_ALIGNED_STORAGE -D_UNICODE -D_WIN64 -ID:/TimeArc/time-arc/build/time-arc_autogen/include -ID:/TimeArc/time-arc/src -ID:/TimeArc/time-arc/src/services -ID:/TimeArc/time-arc -ID:/TimeArc/time-arc/thirdparty/sqlite3 -ID:/TimeArc/time-arc/thirdparty/parson -isystem D:/TimeArc/QT/6.11.0/mingw_64/include/QtQml -isystem D:/TimeArc/QT/6.11.0/mingw_64/include -isystem D:/TimeArc/QT/6.11.0/mingw_64/include/QtCore -isystem D:/TimeArc/QT/6.11.0/mingw_64/mkspecs/win32-g++ -isystem D:/TimeArc/QT/6.11.0/mingw_64/include/QtQmlIntegration -isystem D:/TimeArc/QT/6.11.0/mingw_64/include/QtNetwork -isystem D:/TimeArc/QT/6.11.0/mingw_64/include/QtQuick -isystem D:/TimeArc/QT/6.11.0/mingw_64/include/QtGui -isystem D:/TimeArc/QT/6.11.0/mingw_64/include/QtOpenGL -isystem D:/TimeArc/QT/6.11.0/mingw_64/include/QtSvg -isystem D:/TimeArc/QT/6.11.0/mingw_64/include/QtSql -isystem D:/TimeArc/QT/6.11.0/mingw_64/include/QtWidgets -std=gnu++17 -MD -MT CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/desktop/pages/DesktopProfilePage_qml.cpp.obj -MF CMakeFiles\time-arc.dir\build\.rcc\qmlcache\time-arc_qml\desktop\pages\DesktopProfilePage_qml.cpp.obj.d -o CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/desktop/pages/DesktopProfilePage_qml.cpp.obj -c D:/TimeArc/time-arc/build/.rcc/qmlcache/time-arc_qml/desktop/pages/DesktopProfilePage_qml.cpp
ninja: build stopped: subcommand failed.
```

## 3. Root cause

- Immediate cause: g++ compilation of generated QML/resource C++ exited 1 without diagnostics.
- Underlying cause: the already-running Codex process inherited stale F-drive Qt/MinGW entries ahead of D-drive toolchain paths; adding D-drive MinGW/Qt/CMake/Ninja first made a C++ smoke compile and harness build pass.
- Why the harness/checklists did not prevent it: the earlier PATH repair only added CMake, not the full MinGW/Qt runtime path needed by compiler subprocesses.

## 4. Fix

- Files changed: User PATH outside git; no source fix required for this build error.
- Short description: put `D:\TimeArc\QT\Tools\mingw1310_64\bin`, `D:\TimeArc\QT\6.11.0\mingw_64\bin`, CMake, and Ninja before stale F-drive paths.
- Commit: pending commit.

## 5. Prevention

One-off environment repair; no harness change.
