# Android Launcher Icon and Launch Experience Implementation Plan

**Goal:** Ship a branded Android launcher icon, native splash, bounded QML
launch animation, and an installable APK.

**Architecture:** Android resources own launcher/splash integration;
`MobileAppShell` owns a presentation-only QML reveal. No service or database
contract changes.

**Tech stack:** Android XML/resources, Qt 6 QML, Python static tests, CMake,
Gradle/Qt Android packaging, project harness.

## Progress

- [x] Task 1: Add RED static coverage for Android resources and launch behavior.
- [x] Task 2: Generate and review the TimeArc mobile icon master.
- [x] Task 3: Produce adaptive, round, and legacy launcher resources.
- [x] Task 4: Implement native splash themes and bounded QML reveal.
- [x] Task 5: Run targeted tests, harness build, CTest, and APK packaging.
- [-] Task 6: Document, commit, push, PR, merge to `dev`, and clean the branch.

## Task details

### Task 1: Tests first

Create `tests/android_launch_experience_static_test.py`. Assert explicit
manifest icon/theme references, required resource files, adaptive-icon layers,
QML component registration, a finite animation, and a reduced-motion bypass.
Run it before production edits and retain the expected failure as RED evidence.

### Task 2: Icon master

Use GPT Image to reinterpret the existing TimeArc mark as a 1024×1024 mobile
icon. Preserve the glyph and cyan/violet identity; remove all text and keep the
full mark inside the adaptive safe zone. Inspect the output at full size and at
launcher size before accepting it.

### Task 3: Android icon resources

Derive foreground/background and legacy mipmap outputs from the approved master.
Add `mipmap-anydpi-v26` adaptive definitions plus standard/round fallbacks. Use
reproducible local conversion only; do not add an image-processing dependency.

### Task 4: Splash and QML transition

Add base and API 31+ theme resources, reference them from the manifest, and add
`MobileLaunchOverlay.qml`. Register the component in `qml/CMakeLists.txt` and
wire it into `MobileAppShell.qml` after theme preferences load. Keep duration
below 1.2 seconds and skip motion when `reducedMotion` is true.

### Task 5: Verification and APK

Run the new RED/GREEN static test, existing Android/mobile UI tests, project
build through `.harness/tools/build.py`, CTest, `git diff --check`, and
`.harness/tools/harness_check.py`. Assemble the available Android ABI APK using
the repository's Qt/Gradle pipeline, inspect its archive and package metadata,
and launch it on a connected device/emulator when available.

### Task 6: Delivery

Write the Chinese completion report, update backlog/open issues, commit the
coherent feature, push `codex/android-launch-experience`, open a PR to `dev`,
verify its changed-file scope, merge it, update local `dev`, delete the merged
branch, and provide the absolute APK path plus HarmonyOS compatibility notes.
