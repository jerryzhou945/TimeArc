# Error Report - settings-export-ui-build-verbose

## Metadata

- Level: **L1**
- Track: **B**
- Topic: settings-export-ui-build-verbose
- Recorded: 2026-06-13T20:52:57Z
- Session: `.harness/journal/sessions/20260614-0440-B-alpha-polish-g1-g4.md`
- Platform: windows
- Tooling: harness build.py with `-- -v -j1`

## 1. What happened

cmake --build exited 1

## 2. Evidence

```
Change Dir: 'D:/TimeArc/time-arc/build'

Run Build Command(s): D:\TimeArc\QT\Tools\Ninja\ninja.exe -v -j 1
[1/3] D:\TimeArc\QT\Tools\mingw1310_64\bin\g++.exe -DMINGW_HAS_SECURE_API=1 -DQT_CORE_LIB -DQT_GUI_LIB -DQT_NEEDS_QMAIN -DQT_NETWORK_LIB -DQT_NO_DEBUG -DQT_OPENGL_LIB -DQT_QMLINTEGRATION_LIB -DQT_QML_LIB -DQT_QUICK_LIB -DQT_SQL_LIB -DQT_SVG_LIB -DQT_WIDGETS_LIB -DUNICODE -DWIN32 -DWIN64 -D_ENABLE_EXTENDED_ALIGNED_STORAGE -D_UNICODE -D_WIN64 -ID:/TimeArc/time-arc/build/time-arc_autogen/include -ID:/TimeArc/time-arc/src -ID:/TimeArc/time-arc/src/services -ID:/TimeArc/time-arc -ID:/TimeArc/time-arc/thirdparty/sqlite3 -ID:/TimeArc/time-arc/thirdparty/parson -isystem D:/TimeArc/QT/6.11.0/mingw_64/include/QtQml -isystem D:/TimeArc/QT/6.11.0/mingw_64/include -isystem D:/TimeArc/QT/6.11.0/mingw_64/include/QtCore -isystem D:/TimeArc/QT/6.11.0/mingw_64/mkspecs/win32-g++ -isystem D:/TimeArc/QT/6.11.0/mingw_64/include/QtQmlIntegration -isystem D:/TimeArc/QT/6.11.0/mingw_64/include/QtNetwork -isystem D:/TimeArc/QT/6.11.0/mingw_64/include/QtQuick -isystem D:/TimeArc/QT/6.11.0/mingw_64/include/QtGui -isystem D:/TimeArc/QT/6.11.0/mingw_64/include/QtOpenGL -isystem D:/TimeArc/QT/6.11.0/mingw_64/include/QtSvg -isystem D:/TimeArc/QT/6.11.0/mingw_64/include/QtSql -isystem D:/TimeArc/QT/6.11.0/mingw_64/include/QtWidgets -std=gnu++17 -MD -MT CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/desktop/pages/DesktopProfilePage_qml.cpp.obj -MF CMakeFiles\time-arc.dir\build\.rcc\qmlcache\time-arc_qml\desktop\pages\DesktopProfilePage_qml.cpp.obj.d -o CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/desktop/pages/DesktopProfilePage_qml.cpp.obj -c D:/TimeArc/time-arc/build/.rcc/qmlcache/time-arc_qml/desktop/pages/DesktopProfilePage_qml.cpp
FAILED: CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/desktop/pages/DesktopProfilePage_qml.cpp.obj 
D:\TimeArc\QT\Tools\mingw1310_64\bin\g++.exe -DMINGW_HAS_SECURE_API=1 -DQT_CORE_LIB -DQT_GUI_LIB -DQT_NEEDS_QMAIN -DQT_NETWORK_LIB -DQT_NO_DEBUG -DQT_OPENGL_LIB -DQT_QMLINTEGRATION_LIB -DQT_QML_LIB -DQT_QUICK_LIB -DQT_SQL_LIB -DQT_SVG_LIB -DQT_WIDGETS_LIB -DUNICODE -DWIN32 -DWIN64 -D_ENABLE_EXTENDED_ALIGNED_STORAGE -D_UNICODE -D_WIN64 -ID:/TimeArc/time-arc/build/time-arc_autogen/include -ID:/TimeArc/time-arc/src -ID:/TimeArc/time-arc/src/services -ID:/TimeArc/time-arc -ID:/TimeArc/time-arc/thirdparty/sqlite3 -ID:/TimeArc/time-arc/thirdparty/parson -isystem D:/TimeArc/QT/6.11.0/mingw_64/include/QtQml -isystem D:/TimeArc/QT/6.11.0/mingw_64/include -isystem D:/TimeArc/QT/6.11.0/mingw_64/include/QtCore -isystem D:/TimeArc/QT/6.11.0/mingw_64/mkspecs/win32-g++ -isystem D:/TimeArc/QT/6.11.0/mingw_64/include/QtQmlIntegration -isystem D:/TimeArc/QT/6.11.0/mingw_64/include/QtNetwork -isystem D:/TimeArc/QT/6.11.0/mingw_64/include/QtQuick -isystem D:/TimeArc/QT/6.11.0/mingw_64/include/QtGui -isystem D:/TimeArc/QT/6.11.0/mingw_64/include/QtOpenGL -isystem D:/TimeArc/QT/6.11.0/mingw_64/include/QtSvg -isystem D:/TimeArc/QT/6.11.0/mingw_64/include/QtSql -isystem D:/TimeArc/QT/6.11.0/mingw_64/include/QtWidgets -std=gnu++17 -MD -MT CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/desktop/pages/DesktopProfilePage_qml.cpp.obj -MF CMakeFiles\time-arc.dir\build\.rcc\qmlcache\time-arc_qml\desktop\pages\DesktopProfilePage_qml.cpp.obj.d -o CMakeFiles/time-arc.dir/build/.rcc/qmlcache/time-arc_qml/desktop/pages/DesktopProfilePage_qml.cpp.obj -c D:/TimeArc/time-arc/build/.rcc/qmlcache/time-arc_qml/desktop/pages/DesktopProfilePage_qml.cpp
ninja: build stopped: subcommand failed.

```

## 3. Root cause

- Immediate cause: single-job verbose build reproduced the same generated-QML g++ exit 1 with no compiler diagnostics.
- Underlying cause: stale F-drive Qt/MinGW paths in the inherited process PATH interfered with compiler subprocesses; D-drive toolchain-first PATH fixed the build.
- Why the harness/checklists did not prevent it: process-level PATH drift is outside repo checks.

## 4. Fix

- Files changed: none in source.
- Short description: confirmed this was toolchain PATH drift, not a QML syntax error.
- Commit: pending commit.

## 5. Prevention

One-off diagnostic duplicate of `settings-export-ui-build`; no harness change.
