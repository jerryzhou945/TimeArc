# Error Report - android-launch-apk

## Metadata

- Level: **L1**
- Track: **B**
- Topic: android-launch-apk
- Recorded: 2026-08-02T01:49:11Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

cmake --build exited 1

## 2. Evidence

```
package="com.timearc.app" found in source AndroidManifest.xml: D:\TimeArc\time-arc\build-android-arm64_v8a\android-build\AndroidManifest.xml.
Setting the namespace via the package attribute in the source AndroidManifest.xml is no longer supported, and the value is ignored.
Recommendation: remove package="com.timearc.app" from the source AndroidManifest.xml: D:\TimeArc\time-arc\build-android-arm64_v8a\android-build\AndroidManifest.xml.

> Task :processDebugManifest
> Task :processDebugJavaRes NO-SOURCE
> Task :mergeDebugJavaResource UP-TO-DATE
> Task :checkDebugDuplicateClasses UP-TO-DATE
> Task :mergeExtDexDebug UP-TO-DATE
> Task :mergeLibDexDebug UP-TO-DATE
> Task :mergeDebugJniLibFolders
> Task :validateSigningDebug UP-TO-DATE
> Task :writeDebugAppMetadata UP-TO-DATE
> Task :writeDebugSigningConfigVersions UP-TO-DATE
> Task :processDebugManifestForPackage
> Task :processDebugResources FAILED
> Task :mergeDebugNativeLibs

FAILURE: Build failed with an exception.

* What went wrong:
Execution failed for task ':processDebugResources'.
> A failure occurred while executing com.android.build.gradle.internal.res.LinkApplicationAndroidResourcesTask$TaskAction
   > Android resource linking failed
     com.timearc.app-mergeDebugResources-18:/values-v31/values-v31.xml:7: error: style attribute 'android:attr/postSplashScreenTheme' not found.
     error: failed linking references.


* Try:
> Run with --stacktrace option to get the stack trace.
> Run with --info or --debug option to get more log output.
> Run with --scan to get full insights from a Build Scan (powered by Develocity).
> Get more help at https://help.gradle.org.

BUILD FAILED in 29s
29 actionable tasks: 13 executed, 16 up-to-date
Building the android package failed!
  -- For more information, run this command with --verbose.
The maximum path length that can be processed by Gradle on Windows is 260 characters.
Consider moving your project to reduce its path length.
The following files have too long paths:
D:/TimeArc/time-arc/build-android-arm64_v8a/android-build/src/main/java/com/timearc/mobile/ui/MobileUiBridge.java
D:/TimeArc/time-arc/build-android-arm64_v8a/android-build/src/main/java/com/timearc/mobile/ui/QqZoneAdapter.java
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

- Immediate cause:
- Underlying cause:
- Why the harness/checklists did not prevent it:

## 4. Fix

- Files changed:
- Short description:
- Commit:

## 5. Prevention

Concrete harness upgrade, or 'one-off, no harness change'.
