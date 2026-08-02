# Session Log — harmony-theme-isolation

## Metadata

- Agent / Author: Codex
- Track: **C (Debug)**
- Date: 2026-08-02 10:53 → 11:04 (Asia/Shanghai)
- Branch: `codex/harmony-safe-start`
- Baseline commit: `02a26cea`

## Goal

Restore the current Android timing flow and isolate the custom QtActivity launch theme while preserving the latest UI and features.

## Plan

- Compare the July 4 working APK with the current failing APK.
- Restore eager Usage Access and WorkManager behavior.
- Remove only the custom Activity theme binding, then rebuild and verify.

## What actually happened

- 10:53 — User confirmed the safe-start APK still exits after one black second; see [`../errors/20260802-025616-C-harmony-safe-start-still-exits.md`](../errors/20260802-025616-C-harmony-safe-start-still-exits.md).
- 10:55 — APK comparison found identical SDK/ABI/signature and byte-identical Qt Core/platform libraries. The working APK includes AndroidX Startup and eager timing permissions.
- 10:56 — The strongest manifest difference is the new `TimeArcLaunchTheme` binding on `QtActivity`; the working APK uses Qt's default Activity theme.
- 10:59 — Restored timing/permission sources exactly to baseline `98885e3d`, removed only the Activity theme binding, and built the Android APK.
- 11:02 — Verified merged Manifest, v2 signature and matching artifact hash; Windows build, relevant static tests and CTest 4/4 passed.

## Outcome

**done**

- Completed: APK comparison, restored timing flow, default-theme isolation, regression test, Android/Windows builds and packaged APK.
- Incomplete: Pura 90 Pro physical-device result only.
- Verification: `aapt`, `apkanalyzer`, `apksigner`, native SHA-256 comparison, Android/Windows builds, relevant static tests, CTest 4/4.
- Next: Install `TimeArc-1.0-android-arm64-v8a-harmony-default-theme-debug.apk` through Zhuoyitong.
- Risks: If the theme-isolation APK still exits, the next boundary is current app/QML initialization rather than Qt or Android framework dependencies.
- Commits landed: None.
- Files touched: Android manifest/timing path, launch/usage tests, reports and journals.
- Frozen files touched: n.
- Follow-ups spun out to `../state/open-issues.md`: Physical-device confirmation remains.

## Notes for the next agent

The July 4 APK SHA-256 is `8BC86D687C13B8A8DBE106E8F1CD29CC8F50E0F5C1B343E2E5CBC10E5AC55DB4`.
