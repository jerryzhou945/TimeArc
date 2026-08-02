# Android mobile regressions

Goal: fix rounded app-icon rendering, HarmonyOS edge-to-edge system bars, and current-day Android usage refresh without restoring the incompatible custom Activity theme.

Related error report(s): `../errors/20260802-043258-C-android-mobile-regressions.md`. Expected files: Android Activity/UI/usage bridges, mobile usage repository/JNI/service, `MobileAppIcon.qml`, targeted tests, and reports. Frozen files and the desktop service contract are out of scope.

- Completed: root causes reproduced from code and the Pura 90 Pro screenshots; design approved as approach A.
- Incomplete: implementation, device APK, and Pura 90 Pro verification.
- Verification: preflight Track C and harness checks passed before coding.
- Next: write failing regressions, implement each fix, build Windows/Android, and package the APK.
- Risks: a custom theme must not return; Android daily repair must replace only mobile aggregate rows and preserve sessions.
