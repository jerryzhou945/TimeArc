# Change Proposal - Android package source

## Metadata

- Author: Codex
- Track: **B (Feature)**
- Date: 2026-06-29 07:16 (local)
- Session goal: Wire the Android package source directory and Gradle dependency
  template so mobile usage sync can build into an Android APK.
- Branch: `codex/mobile-usage-ui-sync`

## Frozen files touched

- `CMakeLists.txt` - set `QT_ANDROID_PACKAGE_SOURCE_DIR` on the `time-arc`
  target when building for Android.

## Motivation

The Android usage Java sources and manifest currently live under `android/`,
but Qt will not package them unless the target declares the Android package
source directory. WorkManager also needs a Gradle dependency declared in the
Android template.

## Impact

Windows/macOS/Linux desktop builds are unchanged because the property is guarded
by `if(ANDROID)`. Android builds copy the repo-local `android/` package source
template and compile Java from `src/main/java`.

## Rollback

Remove the guarded CMake property and Android Gradle template.

## Verification

- Static test asserts `QT_ANDROID_PACKAGE_SOURCE_DIR`, WorkManager dependency,
  and `src/main/java` source path.
- Desktop harness build remains green.
