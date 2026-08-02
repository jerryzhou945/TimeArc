# Error Report - android-realtime-edge-apk

## Metadata

- Level: **L1**
- Track: **C**
- Topic: android-realtime-edge-apk
- Recorded: 2026-08-02T05:02:13Z
- Session: 20260802-1232-C-android-mobile-regressions
- Platform: Android arm64-v8a
- Tooling: Gradle / javac / Qt 6.11

## 1. What happened

cmake --build exited 1

## 2. Evidence

```
                               ^
  D:\TimeArc\time-arc\build-android-arm64_v8a\android-build\src\main\java\com\timearc\mobile\ui\MobileUiBridge.java:50: 警告: [deprecation] View中的SYSTEM_UI_FLAG_LAYOUT_STABLE已过时
                              | View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                                    ^
  D:\TimeArc\time-arc\build-android-arm64_v8a\android-build\src\main\java\com\timearc\mobile\ui\MobileUiBridge.java:51: 警告: [deprecation] View中的SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN已过时
                              | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                                    ^
  D:\TimeArc\time-arc\build-android-arm64_v8a\android-build\src\main\java\com\timearc\mobile\ui\MobileUiBridge.java:52: 警告: [deprecation] View中的SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION已过时
                              | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION);
                                    ^
  D:\TimeArc\time-arc\build-android-arm64_v8a\android-build\src\main\java\com\timearc\mobile\ui\MobileUiBridge.java:48: 警告: [deprecation] View中的setSystemUiVisibility(int)已过时
              decorView.setSystemUiVisibility(
                       ^
  D:\TimeArc\time-arc\build-android-arm64_v8a\android-build\src\main\java\com\timearc\mobile\ui\MobileUiBridge.java:60: 警告: [deprecation] Window中的setStatusBarColor(int)已过时
              window.setStatusBarColor(Color.TRANSPARENT);
                    ^
  D:\TimeArc\time-arc\build-android-arm64_v8a\android-build\src\main\java\com\timearc\mobile\ui\MobileUiBridge.java:61: 警告: [deprecation] Window中的setNavigationBarColor(int)已过时
              window.setNavigationBarColor(Color.TRANSPARENT);
                    ^
  D:\TimeArc\time-arc\build-android-arm64_v8a\android-build\src\main\java\com\timearc\mobile\ui\TimeArcActivity.java:13: 错误: TimeArcActivity中的onCreate(Bundle)无法覆盖QtActivity中的onCreate(Bundle)
      protected void onCreate(Bundle savedInstanceState) {
                     ^
    正在尝试分配更低的访问权限; 以前为public
  1 个错误
  9 个警告

* Try:
> Check your code and dependencies to fix the compilation error(s)
> Run with --scan to get full insights from a Build Scan (powered by Develocity).

BUILD FAILED in 9s
7 actionable tasks: 1 executed, 6 up-to-date
Building the android package failed!
  -- For more information, run this command with --verbose.
The maximum path length that can be processed by Gradle on Windows is 260 characters.
Consider moving your project to reduce its path length.
The following files have too long paths:
D:/TimeArc/time-arc/build-android-arm64_v8a/android-build/src/main/java/com/timearc/mobile/ui/MobileUiBridge.java
D:/TimeArc/time-arc/build-android-arm64_v8a/android-build/src/main/java/com/timearc/mobile/ui/QqZoneAdapter.java
D:/TimeArc/time-arc/build-android-arm64_v8a/android-build/src/main/java/com/timearc/mobile/ui/TimeArcActivity.java
D:/TimeArc/time-arc/build-android-arm64_v8a/android-build/src/main/java/com/timearc/mobile/ui/WeChatMomentsAdapter.java
D:/TimeArc/time-arc/build-android-arm64_v8a/android-build/src/main/java/com/timearc/mobile/usage/AndroidAppMetadataResolver.java
D:/TimeArc/time-arc/build-android-arm64_v8a/android-build/src/main/java/com/timearc/mobile/usage/AndroidUsageNativeBridge.java
D:/TimeArc/time-arc/build-android-arm64_v8a/android-build/src/main/java/com/timearc/mobile/usage/UsageAccessBridge.java
D:/TimeArc/time-arc/build-android-arm64_v8a/android-build/src/main/java/com/timearc/mobile/usage/UsageEventsReader.java
D:/TimeArc/time-arc/build-android-arm64_v8a/android-build/src/main/java/com/timearc/mobile/usage/UsageRecordDto.java
D:/TimeArc/time-arc/build-android-arm64_v8a/android-build/src/main/java/com/timearc/mobile/usage/UsageSessionDto.java

D:/TimeArc/time-arc/build-android-arm64_v8a/android-build/src/main/java/com/timearc/mobile/usage/UsageStatsReader.java

D:/TimeArc/time-arc/build-android-arm64_v8a/android-build/src/main/java/com/timearc/mobile/usage/UsageSyncScheduler.java

D:/TimeArc/time-arc/build-android-arm64_v8a/android-build/src/main/java/com/timearc/mobile/usage/UsageSyncWorker.java.

ninja: build stopped: subcommand failed.
```

## 3. Root cause

- Immediate cause: `TimeArcActivity.onCreate(Bundle)` reduced the inherited public method to protected visibility.
- Underlying cause: the first static regression encoded Android Activity's usual protected signature instead of QtActivity's public override.
- Why the harness/checklists did not prevent it: Java compilation occurs only in the APK target, not the native Android UI target.

## 4. Fix

- Files changed: `TimeArcActivity.java`, `android_launch_experience_static_test.py`.
- Short description: keep the override public and retain the lifecycle behavior.
- Commit: pending verification commit.

## 5. Prevention

Keep the APK javac target in final Android verification; static source checks cannot validate inherited Java visibility.
