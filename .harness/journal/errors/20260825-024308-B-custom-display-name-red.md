# Error Report - custom-display-name-red

## Metadata

- Level: **L1**
- Track: **B**
- Topic: custom-display-name-red
- Recorded: 2026-08-25T02:43:08Z
- Session: .harness/journal/sessions/20260825-1040-B-custom-app-display-name.md
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

cmake --build exited 1

## 2. Evidence

```
[1/4] Automatic MOC and UIC for target timearc_db_smoke
[2/3] Building CXX object CMakeFiles/timearc_db_smoke.dir/tests/db_smoke.cpp.obj
FAILED: CMakeFiles/timearc_db_smoke.dir/tests/db_smoke.cpp.obj
D:\TimeArc\QT\Tools\mingw1310_64\bin\g++.exe -DMINGW_HAS_SECURE_API=1 -DQT_CORE_LIB -DQT_NO_DEBUG -DQT_SQL_LIB -DUNICODE -DWIN32 -DWIN64 -D_ENABLE_EXTENDED_ALIGNED_STORAGE -D_UNICODE -D_WIN64 -ID:/TimeArc/time-arc/build/timearc_db_smoke_autogen/include -ID:/TimeArc/time-arc/src -ID:/TimeArc/time-arc/src/services -isystem D:/TimeArc/QT/6.11.0/mingw_64/include/QtCore -isystem D:/TimeArc/QT/6.11.0/mingw_64/include -isystem D:/TimeArc/QT/6.11.0/mingw_64/mkspecs/win32-g++ -isystem D:/TimeArc/QT/6.11.0/mingw_64/include/QtSql -O3 -DNDEBUG -std=gnu++17 -MD -MT CMakeFiles/timearc_db_smoke.dir/tests/db_smoke.cpp.obj -MF CMakeFiles\timearc_db_smoke.dir\tests\db_smoke.cpp.obj.d -o CMakeFiles/timearc_db_smoke.dir/tests/db_smoke.cpp.obj -c D:/TimeArc/time-arc/tests/db_smoke.cpp
D:/TimeArc/time-arc/tests/db_smoke.cpp: In function 'int main(int, char**)':
D:/TimeArc/time-arc/tests/db_smoke.cpp:507:58: error: 'applyDisplayName' is not a member of 'TimeArc::AppIdentityPolicy'
  507 |   const auto renamedChrome = TimeArc::AppIdentityPolicy::applyDisplayName(
      |                                                          ^~~~~~~~~~~~~~~~
D:/TimeArc/time-arc/tests/db_smoke.cpp:515:58: error: 'applyDisplayName' is not a member of 'TimeArc::AppIdentityPolicy'
  515 |   const auto defaultChrome = TimeArc::AppIdentityPolicy::applyDisplayName(
      |                                                          ^~~~~~~~~~~~~~~~
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
