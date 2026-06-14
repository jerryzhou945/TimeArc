# Error Report - site-icons-red-test

## Metadata

- Level: **L1**
- Track: **B**
- Topic: site-icons-red-test
- Recorded: 2026-06-14T00:42:57Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

cmake --build exited 1

## 2. Evidence

```
[1/4] Automatic MOC and UIC for target timearc_db_smoke
[2/3] Building CXX object CMakeFiles/timearc_db_smoke.dir/tests/db_smoke.cpp.obj
[3/3] Linking CXX executable timearc_db_smoke.exe
FAILED: timearc_db_smoke.exe 
C:\WINDOWS\system32\cmd.exe /C "cd . && D:\TimeArc\QT\Tools\mingw1310_64\bin\g++.exe   CMakeFiles/timearc_db_smoke.dir/timearc_db_smoke_autogen/mocs_compilation.cpp.obj CMakeFiles/timearc_db_smoke.dir/tests/db_smoke.cpp.obj CMakeFiles/timearc_db_smoke.dir/src/services/app_repository.cpp.obj CMakeFiles/timearc_db_smoke.dir/src/services/daily_card_service.cpp.obj CMakeFiles/timearc_db_smoke.dir/src/services/database_manager.cpp.obj CMakeFiles/timearc_db_smoke.dir/src/services/frontmost_session_repository.cpp.obj CMakeFiles/timearc_db_smoke.dir/src/services/manual_project_repository.cpp.obj CMakeFiles/timearc_db_smoke.dir/src/services/media_session_repository.cpp.obj CMakeFiles/timearc_db_smoke.dir/src/services/settings_repository.cpp.obj CMakeFiles/timearc_db_smoke.dir/src/services/stats_service.cpp.obj CMakeFiles/timearc_db_smoke.dir/src/services/calendar_manager.cpp.obj CMakeFiles/timearc_db_smoke.dir/src/services/project_manager.cpp.obj -o timearc_db_smoke.exe -Wl,--out-implib,libtimearc_db_smoke.dll.a -Wl,--major-image-version,0,--minor-image-version,0  D:/TimeArc/QT/6.11.0/mingw_64/lib/libQt6Sql.a  D:/TimeArc/QT/6.11.0/mingw_64/lib/libQt6Core.a  -lmpr  -luserenv  -lkernel32 -luser32 -lgdi32 -lwinspool -lshell32 -lole32 -loleaut32 -luuid -lcomdlg32 -ladvapi32 && cd ."
D:/TimeArc/QT/Tools/mingw1310_64/bin/../lib/gcc/x86_64-w64-mingw32/13.1.0/../../../../x86_64-w64-mingw32/bin/ld.exe: CMakeFiles/timearc_db_smoke.dir/tests/db_smoke.cpp.obj:db_smoke.cpp:(.text+0xd269): undefined reference to `UsageStatManager::UsageStatManager(QObject*)'
D:/TimeArc/QT/Tools/mingw1310_64/bin/../lib/gcc/x86_64-w64-mingw32/13.1.0/../../../../x86_64-w64-mingw32/bin/ld.exe: CMakeFiles/timearc_db_smoke.dir/tests/db_smoke.cpp.obj:db_smoke.cpp:(.text+0xd2d1): undefined reference to `UsageStatManager::activeSoftwareForRange(QString const&) const'
D:/TimeArc/QT/Tools/mingw1310_64/bin/../lib/gcc/x86_64-w64-mingw32/13.1.0/../../../../x86_64-w64-mingw32/bin/ld.exe: CMakeFiles/timearc_db_smoke.dir/tests/db_smoke.cpp.obj:db_smoke.cpp:(.rdata$.refptr._ZTV16UsageStatManager[.refptr._ZTV16UsageStatManager]+0x0): undefined reference to `vtable for UsageStatManager'

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
