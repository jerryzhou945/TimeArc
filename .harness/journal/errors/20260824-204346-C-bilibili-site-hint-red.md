# Error Report - bilibili-site-hint-red

## Metadata

- Level: **L1**
- Track: **C**
- Topic: bilibili-site-hint-red
- Recorded: 2026-08-24T20:43:46Z
- Session: .harness/journal/sessions/20260825-0430-C-bilibili-site-attribution.md
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

cmake --build exited 1

## 2. Evidence

```
[1/4] Automatic MOC and UIC for target timearc_windows_audio_title_policy_test
[2/3] Building C object CMakeFiles/timearc_windows_audio_title_policy_test.dir/tests/windows_audio_title_policy_test.c.obj
[3/3] Linking CXX executable timearc_windows_audio_title_policy_test.exe
FAILED: timearc_windows_audio_title_policy_test.exe
C:\WINDOWS\system32\cmd.exe /C "cd . && D:\TimeArc\QT\Tools\mingw1310_64\bin\g++.exe -O3 -DNDEBUG  CMakeFiles/timearc_windows_audio_title_policy_test.dir/timearc_windows_audio_title_policy_test_autogen/mocs_compilation.cpp.obj CMakeFiles/timearc_windows_audio_title_policy_test.dir/tests/windows_audio_title_policy_test.c.obj CMakeFiles/timearc_windows_audio_title_policy_test.dir/src/service/windows/platform/audio_win.c.obj CMakeFiles/timearc_windows_audio_title_policy_test.dir/src/service/windows/platform/active_app_win.c.obj CMakeFiles/timearc_windows_audio_title_policy_test.dir/src/service/windows/platform/app_identity.c.obj -o timearc_windows_audio_title_policy_test.exe -Wl,--out-implib,libtimearc_windows_audio_title_policy_test.dll.a -Wl,--major-image-version,0,--minor-image-version,0  -luser32  -lpsapi  -lole32  -luuid  -lkernel32 -luser32 -lgdi32 -lwinspool -lshell32 -lole32 -loleaut32 -luuid -lcomdlg32 -ladvapi32 && cd ."
D:/TimeArc/QT/Tools/mingw1310_64/bin/../lib/gcc/x86_64-w64-mingw32/13.1.0/../../../../x86_64-w64-mingw32/bin/ld.exe: CMakeFiles/timearc_windows_audio_title_policy_test.dir/tests/windows_audio_title_policy_test.c.obj:windows_audio_title_policy_test.c:(.text.startup+0x390): undefined reference to `timearc_win_observe_browser_site_hint'

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
