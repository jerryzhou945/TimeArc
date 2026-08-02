# Error Report - harmony-zhuoyitong-startup-exit

## Metadata

- Level: **L2**
- Track: **C**
- Topic: harmony-zhuoyitong-startup-exit
- Recorded: 2026-08-02T02:31:09Z
- Session: (unknown)
- Platform: Pura 90 Pro / HarmonyOS / Zhuoyitong Android compatibility
- Tooling: Qt 6.11 Android arm64-v8a, AndroidX WorkManager 2.9.1

## 1. What happened

TimeArc APK shows launch background for about one second then exits on Pura 90 Pro when installed through Zhuoyitong

## 2. Evidence

User reproduction: install the debug APK through Zhuoyitong, tap TimeArc, see
the native launch background for about one second, then return to the launcher.
No device log was available. Source tracing showed AndroidX Startup ran before
Qt's first frame and QML immediately called Usage Access and WorkManager paths.

## 3. Root cause

- Immediate cause: Android framework-dependent initialization ran before the
  first durable QML frame and could propagate compatibility failures.
- Underlying cause: WorkManager used process-start AndroidX initialization;
  Usage Access probing and permission-Activity launch were also eager and JNI
  calls did not convert Java exceptions into a safe failure state.
- Why the harness/checklists did not prevent it: build/static checks do not
  exercise third-party Android compatibility containers, and no HarmonyOS
  device was attached during the original Android release.

## 4. Fix

- Files changed: Android manifest/bridges, mobile usage service, mobile shell,
  Android startup configuration, static test, and supporting documentation.
- Short description: remove process-start AndroidX initialization, initialize
  WorkManager lazily, delay Usage Access onboarding, guard Java/JNI boundaries,
  and force the Android OpenGL backend.
- Commit: pending commit

## 5. Prevention

The Android usage static test now locks the lazy-initialization, delayed-
onboarding, JNI exception-clearing, and OpenGL backend contracts. Physical
Zhuoyitong verification remains a release-device gate.
