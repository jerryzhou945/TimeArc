# Error Report - harmony-safe-start-still-exits

## Metadata

- Level: **L2**
- Track: **C**
- Topic: harmony-safe-start-still-exits
- Recorded: 2026-08-02T02:56:16Z
- Session: `.harness/journal/sessions/20260802-1053-C-harmony-theme-isolation.md`
- Platform: Pura 90 Pro / HarmonyOS / Zhuoyitong
- Tooling: aapt 36.1.0, apkanalyzer, apksigner, SHA-256 native comparison

## 1. What happened

Pura 90 Pro still black-screened for one second and exited with the safe-start APK; the removed Usage Access and AndroidX startup paths were not the root cause

## 2. Evidence

The user installed the safe-start APK and observed the same one-second black
screen followed by process exit. The July 4 working APK has the same SDK, ABI,
signer and byte-identical Qt Core/platform libraries. It also contains the
WorkManager AndroidX Startup provider and eager Usage Access flow.

## 3. Root cause

- Immediate cause: removing/delaying timing integration did not change the
  startup failure.
- Underlying cause: the prior root-cause hypothesis was wrong. The strongest
  remaining isolated startup difference is the custom `TimeArcLaunchTheme`
  bound to `QtActivity`; physical-device confirmation is pending.
- Why the harness/checklists did not prevent it: only Zhuoyitong device
  execution distinguishes the two manifests; build and desktop preview pass.

## 4. Fix

- Files changed: Android manifest, restored timing bridge/service/QML files,
  launch/usage static tests and comparison documentation.
- Short description: restore the complete timing path and remove only the
  custom Activity theme binding while retaining current icons and QML UI.
- Commit: pending commit

## 5. Prevention

The launch static test now rejects a custom theme binding on `QtActivity`.
The July 4 APK is retained as a known-working compatibility reference.
