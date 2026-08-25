# Error Report - gsmtc-playback-parser-red

## Metadata

- Level: **L1**
- Track: **C**
- Topic: gsmtc-playback-parser-red
- Recorded: 2026-08-24T18:14:54Z
- Session: .harness/journal/sessions/20260825-0024-C-windows-bilibili-media-release.md
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

cmake --build exited 1

## 2. Evidence

```
[1/4] Automatic MOC and UIC for target timearc_windows_audio_title_policy_test
[2/3] Building C object CMakeFiles/timearc_windows_audio_title_policy_test.dir/tests/windows_audio_title_policy_test.c.obj
FAILED: CMakeFiles/timearc_windows_audio_title_policy_test.dir/tests/windows_audio_title_policy_test.c.obj
D:\TimeArc\QT\Tools\mingw1310_64\bin\gcc.exe  -ID:/TimeArc/time-arc/build/timearc_windows_audio_title_policy_test_autogen/include -ID:/TimeArc/time-arc/src/include -ID:/TimeArc/time-arc/src/service/shared -ID:/TimeArc/time-arc/src/service/windows/platform -O3 -DNDEBUG -std=gnu11 -MD -MT CMakeFiles/timearc_windows_audio_title_policy_test.dir/tests/windows_audio_title_policy_test.c.obj -MF CMakeFiles\timearc_windows_audio_title_policy_test.dir\tests\windows_audio_title_policy_test.c.obj.d -o CMakeFiles/timearc_windows_audio_title_policy_test.dir/tests/windows_audio_title_policy_test.c.obj -c D:/TimeArc/time-arc/tests/windows_audio_title_policy_test.c
D:/TimeArc/time-arc/tests/windows_audio_title_policy_test.c:5:1: error: unknown type name 'TimeArcWinPlaybackState'
    5 | TimeArcWinPlaybackState timearc_win_parse_playback_status(
      | ^~~~~~~~~~~~~~~~~~~~~~~
D:/TimeArc/time-arc/tests/windows_audio_title_policy_test.c: In function 'test_playback_status_parser_is_conservative':
D:/TimeArc/time-arc/tests/windows_audio_title_policy_test.c:9:3: warning: implicit declaration of function 'assert' [-Wimplicit-function-declaration]
    9 |   assert(timearc_win_parse_playback_status("Playing") ==
      |   ^~~~~~
D:/TimeArc/time-arc/tests/windows_audio_title_policy_test.c:1:1: note: 'assert' is defined in header '<assert.h>'; did you forget to '#include <assert.h>'?
  +++ |+#include <assert.h>
    1 | #ifdef NDEBUG
D:/TimeArc/time-arc/tests/windows_audio_title_policy_test.c:10:10: error: 'TIMEARC_WIN_PLAYBACK_PLAYING' undeclared (first use in this function)
   10 |          TIMEARC_WIN_PLAYBACK_PLAYING);
      |          ^~~~~~~~~~~~~~~~~~~~~~~~~~~~
D:/TimeArc/time-arc/tests/windows_audio_title_policy_test.c:10:10: note: each undeclared identifier is reported only once for each function it appears in
D:/TimeArc/time-arc/tests/windows_audio_title_policy_test.c:14:10: error: 'TIMEARC_WIN_PLAYBACK_NOT_PLAYING' undeclared (first use in this function)
   14 |          TIMEARC_WIN_PLAYBACK_NOT_PLAYING);
      |          ^~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
D:/TimeArc/time-arc/tests/windows_audio_title_policy_test.c:20:10: error: 'TIMEARC_WIN_PLAYBACK_UNKNOWN' undeclared (first use in this function)
   20 |          TIMEARC_WIN_PLAYBACK_UNKNOWN);
      |          ^~~~~~~~~~~~~~~~~~~~~~~~~~~~
D:/TimeArc/time-arc/tests/windows_audio_title_policy_test.c:23:44: error: 'NULL' undeclared (first use in this function)
   23 |   assert(timearc_win_parse_playback_status(NULL) ==
      |                                            ^~~~
D:/TimeArc/time-arc/tests/windows_audio_title_policy_test.c:1:1: note: 'NULL' is defined in header '<stddef.h>'; did you forget to '#include <stddef.h>'?
  +++ |+#include <stddef.h>
    1 | #ifdef NDEBUG
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
