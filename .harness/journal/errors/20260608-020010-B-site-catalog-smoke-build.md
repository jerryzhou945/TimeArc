# Error Report - site-catalog-smoke-build

## Metadata

- Level: **L1**
- Track: **B**
- Topic: site-catalog-smoke-build
- Recorded: 2026-06-08T02:00:10Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

cmake --build exited 1

## 2. Evidence

```
[0/1] Re-running CMake...
-- Could NOT find WrapVulkanHeaders (missing: Vulkan_INCLUDE_DIR) 
-- Could NOT find WrapVulkanHeaders (missing: Vulkan_INCLUDE_DIR) 
CMake Warning (dev) at D:/TimeArc/QT/6.11.0/mingw_64/lib/cmake/Qt6Qml/Qt6QmlMacros.cmake:3747 (message):
  qml/desktop/components/AppVisual.js is not an ECMAScript module and also
  doesn't contain '.pragma library'.  It will be re-evaluated in the context
  of every QML document that explicitly or implicitly imports time_arc.  Set
  its QT_QML_SKIP_QMLDIR_ENTRY source file property to FALSE if you really
  want this to happen.  Set it to TRUE to prevent it.
Call Stack (most recent call first):
  D:/TimeArc/QT/6.11.0/mingw_64/lib/cmake/Qt6Qml/Qt6QmlMacros.cmake:1035 (qt6_target_qml_sources)
  D:/TimeArc/QT/6.11.0/mingw_64/lib/cmake/Qt6Qml/Qt6QmlMacros.cmake:1507 (qt6_add_qml_module)
  CMakeLists.txt:33 (qt_add_qml_module)
This warning is for project developers.  Use -Wno-dev to suppress it.

CMake Warning (dev) at D:/TimeArc/QT/6.11.0/mingw_64/lib/cmake/Qt6Qml/Qt6QmlMacros.cmake:3747 (message):
  qml/desktop/components/TagPalette.js is not an ECMAScript module and also
  doesn't contain '.pragma library'.  It will be re-evaluated in the context
  of every QML document that explicitly or implicitly imports time_arc.  Set
  its QT_QML_SKIP_QMLDIR_ENTRY source file property to FALSE if you really
  want this to happen.  Set it to TRUE to prevent it.
Call Stack (most recent call first):
  D:/TimeArc/QT/6.11.0/mingw_64/lib/cmake/Qt6Qml/Qt6QmlMacros.cmake:1035 (qt6_target_qml_sources)
  D:/TimeArc/QT/6.11.0/mingw_64/lib/cmake/Qt6Qml/Qt6QmlMacros.cmake:1507 (qt6_add_qml_module)
  CMakeLists.txt:33 (qt_add_qml_module)
This warning is for project developers.  Use -Wno-dev to suppress it.

-- Configuring done (3.2s)
-- Generating done (0.5s)
-- Build files have been written to: D:/TimeArc/time-arc/build
[1/5] Automatic MOC and UIC for target timearc_db_smoke
[2/4] Building CXX object CMakeFiles/timearc_db_smoke.dir/tests/db_smoke.cpp.obj
FAILED: CMakeFiles/timearc_db_smoke.dir/tests/db_smoke.cpp.obj 
D:\TimeArc\QT\Tools\mingw1310_64\bin\g++.exe -DMINGW_HAS_SECURE_API=1 -DQT_CORE_LIB -DQT_NO_DEBUG -DQT_SQL_LIB -DUNICODE -DWIN32 -DWIN64 -D_ENABLE_EXTENDED_ALIGNED_STORAGE -D_UNICODE -D_WIN64 -ID:/TimeArc/time-arc/build/timearc_db_smoke_autogen/include -ID:/TimeArc/time-arc/src -ID:/TimeArc/time-arc/src/services -isystem D:/TimeArc/QT/6.11.0/mingw_64/include/QtCore -isystem D:/TimeArc/QT/6.11.0/mingw_64/include -isystem D:/TimeArc/QT/6.11.0/mingw_64/mkspecs/win32-g++ -isystem D:/TimeArc/QT/6.11.0/mingw_64/include/QtSql -std=gnu++17 -MD -MT CMakeFiles/timearc_db_smoke.dir/tests/db_smoke.cpp.obj -MF CMakeFiles\timearc_db_smoke.dir\tests\db_smoke.cpp.obj.d -o CMakeFiles/timearc_db_smoke.dir/tests/db_smoke.cpp.obj -c D:/TimeArc/time-arc/tests/db_smoke.cpp
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
