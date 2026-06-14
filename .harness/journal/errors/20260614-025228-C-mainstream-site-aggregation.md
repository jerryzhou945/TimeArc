# Error Report - mainstream-site-aggregation

## Metadata

- Level: **L1**
- Track: **C**
- Topic: mainstream-site-aggregation
- Recorded: 2026-06-14T02:52:28Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

cmake --build exited 1

## 2. Evidence

```
[1/4] Automatic MOC and UIC for target timearc_db_smoke
[2/3] Building CXX object CMakeFiles/timearc_db_smoke.dir/tests/db_smoke.cpp.obj
FAILED: CMakeFiles/timearc_db_smoke.dir/tests/db_smoke.cpp.obj 
D:\TimeArc\QT\Tools\mingw1310_64\bin\g++.exe -DMINGW_HAS_SECURE_API=1 -DQT_CORE_LIB -DQT_NO_DEBUG -DQT_SQL_LIB -DUNICODE -DWIN32 -DWIN64 -D_ENABLE_EXTENDED_ALIGNED_STORAGE -D_UNICODE -D_WIN64 -ID:/TimeArc/time-arc/build/timearc_db_smoke_autogen/include -ID:/TimeArc/time-arc/src -ID:/TimeArc/time-arc/src/services -isystem D:/TimeArc/QT/6.11.0/mingw_64/include/QtCore -isystem D:/TimeArc/QT/6.11.0/mingw_64/include -isystem D:/TimeArc/QT/6.11.0/mingw_64/mkspecs/win32-g++ -isystem D:/TimeArc/QT/6.11.0/mingw_64/include/QtSql -std=gnu++17 -MD -MT CMakeFiles/timearc_db_smoke.dir/tests/db_smoke.cpp.obj -MF CMakeFiles\timearc_db_smoke.dir\tests\db_smoke.cpp.obj.d -o CMakeFiles/timearc_db_smoke.dir/tests/db_smoke.cpp.obj -c D:/TimeArc/time-arc/tests/db_smoke.cpp
D:/TimeArc/time-arc/tests/db_smoke.cpp: In function 'int main(int, char**)':
D:/TimeArc/time-arc/tests/db_smoke.cpp:453:29: error: 'matchBrowserHostedActivity' is not a member of 'TimeArcSiteCatalog'
  453 |         TimeArcSiteCatalog::matchBrowserHostedActivity(
      |                             ^~~~~~~~~~~~~~~~~~~~~~~~~~
D:/TimeArc/time-arc/tests/db_smoke.cpp:461:27: error: 'matchBrowserHostedActivity' is not a member of 'TimeArcSiteCatalog'
  461 |   if (TimeArcSiteCatalog::matchBrowserHostedActivity(
      |                           ^~~~~~~~~~~~~~~~~~~~~~~~~~
ninja: build stopped: subcommand failed.
```

## 3. Root cause

- Immediate cause: TDD red test referenced the new
  `TimeArcSiteCatalog::matchBrowserHostedActivity` helper before it existed.
- Underlying cause: Browser-hosted site splitting was not exposed as a
  separately testable catalog helper.
- Why the harness/checklists did not prevent it: This was an intentional red
  step before implementing the helper.

## 4. Fix

- Files changed: `src/services/site_catalog.h`, `src/services/usage_stat_manager.cpp`,
  `tests/db_smoke.cpp`.
- Short description: Added the helper and made activity grouping prefer catalog
  site matches before generic browser app adapters.
- Commit: pending.

## 5. Prevention

One-off TDD red step; no harness change.
