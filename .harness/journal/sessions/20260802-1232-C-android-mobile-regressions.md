# Android mobile regressions

Goal: fix rounded app-icon rendering, HarmonyOS edge-to-edge system bars, and current-day Android usage refresh without restoring the incompatible custom Activity theme.

Related error report(s): `../errors/20260802-043258-C-android-mobile-regressions.md`. Expected files: Android Activity/UI/usage bridges, mobile usage repository/JNI/service, `MobileAppIcon.qml`, targeted tests, and reports. Frozen files and the desktop service contract are out of scope.

- Completed: real rounded mask, lifecycle edge-to-edge, per-day aggregate repair, completion-driven refresh, and signed APK.
- Incomplete: Pura 90 Pro Zhuoyitong visual/data verification.
- Verification: Windows build, CTest 4/4, Android UI/APK builds, static regressions, v2 signature, package/ABI/permission/manifest checks passed.
- Next: install `TimeArc-1.0-android-arm64-v8a-realtime-edge-debug.apk` and verify system bars, ChatGPT icon corners, and today's duration.
- Risks: compatibility-container system bars and repaired on-device UsageStats still require real-device evidence.
