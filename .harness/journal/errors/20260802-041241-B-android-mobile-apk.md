# Error Report - android-mobile-apk

## Metadata

- Level: **L1**
- Track: **B**
- Topic: android-mobile-apk
- Recorded: 2026-08-02T04:12:41Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

cmake --build exited 1

## 2. Evidence

```
Generating Android Package
  Input file: D:/TimeArc/time-arc/build-android-arm64_v8a/android-time-arc-deployment-settings.json
  Output directory: D:/TimeArc/time-arc/build-android-arm64_v8a/android-build/
  Application binary: TimeArc
  Android build platform: android-36
  Install to device: No
Warning: QML import could not be resolved in any of the import paths: QtQuick.Controls.Windows
Warning: QML import could not be resolved in any of the import paths: QtQuick.Controls.macOS
Warning: QML import could not be resolved in any of the import paths: QtQuick.Controls.iOS
Warning: QML import could not be resolved in any of the import paths: QtQuick.NativeStyle
Warning: QML import could not be resolved in any of the import paths: QtQuick.Controls.Windows.impl
Downloading https://services.gradle.org/distributions/gradle-9.3.1-bin.zip

Exception in thread "main" java.net.SocketException: Permission denied: no further information
	at java.base/sun.nio.ch.Net.pollConnect(Native Method)
	at java.base/sun.nio.ch.Net.pollConnectNow(Net.java:672)
	at java.base/sun.nio.ch.NioSocketImpl.timedFinishConnect(NioSocketImpl.java:539)
	at java.base/sun.nio.ch.NioSocketImpl.connect(NioSocketImpl.java:594)
	at java.base/java.net.SocksSocketImpl.connect(SocksSocketImpl.java:327)
	at java.base/java.net.Socket.connect(Socket.java:633)
	at java.base/sun.security.ssl.SSLSocketImpl.connect(SSLSocketImpl.java:299)
	at java.base/sun.net.NetworkClient.doConnect(NetworkClient.java:178)
	at java.base/sun.net.www.http.HttpClient.openServer(HttpClient.java:498)
	at java.base/sun.net.www.http.HttpClient.openServer(HttpClient.java:603)
	at java.base/sun.net.www.protocol.https.HttpsClient.<init>(HttpsClient.java:264)
	at java.base/sun.net.www.protocol.https.HttpsClient.New(HttpsClient.java:378)
	at java.base/sun.net.www.protocol.https.AbstractDelegateHttpsURLConnection.getNewHttpClient(AbstractDelegateHttpsURLConnection.java:189)
	at java.base/sun.net.www.protocol.http.HttpURLConnection.plainConnect0(HttpURLConnection.java:1242)
	at java.base/sun.net.www.protocol.http.HttpURLConnection.plainConnect(HttpURLConnection.java:1128)
	at java.base/sun.net.www.protocol.https.AbstractDelegateHttpsURLConnection.connect(AbstractDelegateHttpsURLConnection.java:175)
	at java.base/sun.net.www.protocol.http.HttpURLConnection.getInputStream0(HttpURLConnection.java:1665)
	at java.base/sun.net.www.protocol.http.HttpURLConnection.getInputStream(HttpURLConnection.java:1589)
	at java.base/java.net.HttpURLConnection.getResponseCode(HttpURLConnection.java:529)
	at java.base/sun.net.www.protocol.https.HttpsURLConnectionImpl.getResponseCode(HttpsURLConnectionImpl.java:308)
	at org.gradle.wrapper.Install.forceFetch(SourceFile:2)
	at org.gradle.wrapper.Install$1.call(SourceFile:8)
	at org.gradle.wrapper.GradleWrapperMain.main(SourceFile:67)
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
