# Error Report - android-launch-apk

## Metadata

- Level: **L1**
- Track: **B**
- Topic: android-launch-apk
- Recorded: 2026-08-02T01:43:52Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

cmake --build exited 1

## 2. Evidence

```
[0/1] Re-running CMake...
-- Android toolchain file within NDK detected: D:\Tools\Android\Sdk\ndk\27.2.12479018/build/cmake/android.toolchain.cmake
-- Configuring 'time-arc' for the following Android ABIs: arm64-v8a (default)
-- Found android platform plugin at: D:/TimeArc/QT/6.11.0/android_arm64_v8a/plugins/platforms/libplugins_platforms_qtforandroid_arm64-v8a.so
-- Configuring done (34.7s)
CMake Error:
  Running

   'D:/TimeArc/QT/Tools/Ninja/ninja.exe' '-C' 'D:/TimeArc/time-arc/build-android-arm64_v8a' '-t' 'restat' 'build.ninja'

  failed with:

   ninja: error: failed recompaction: Permission denied



-- Generating done (1.7s)
CMake Generate step failed.  Build files cannot be regenerated correctly.
ninja: error: rebuilding 'build.ninja': subcommand failed
FAILED: build.ninja
D:\TimeArc\QT\Tools\CMake_64\bin\cmake.exe --regenerate-during-build -SD:\TimeArc\time-arc -BD:\TimeArc\time-arc\build-android-arm64_v8a
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
