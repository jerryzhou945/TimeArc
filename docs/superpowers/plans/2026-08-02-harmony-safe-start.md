# HarmonyOS Safe Start Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an arm64-v8a APK that survives unavailable Android framework services in HarmonyOS Zhuoyitong and reaches the TimeArc mobile shell.

**Architecture:** Move Android-only work behind the first rendered frame, disable WorkManager's process-start initializer, and convert platform failures into boolean/status results across Java and JNI. Force the conservative OpenGL Qt Quick backend on Android before application construction.

**Tech Stack:** Qt 6.11/QML, C++ JNI, Java 17, AndroidX WorkManager 2.9.1, Python static tests.

## Global Constraints

- Work directly in `D:\TimeArc\time-arc`; do not create a Git worktree.
- Preserve normal Android usage collection when its APIs are available.
- Unsupported Usage Access or WorkManager behavior must not terminate the UI process.
- Do not change frozen CMake or service data-contract files.

---

### Task 1: Add failing safe-start contract tests

**Files:**
- Modify: `tests/android_usage_static_test.py`

**Interfaces:**
- Consumes: Android manifest, QML startup shell, Java bridges, C++ JNI caller.
- Produces: static assertions for delayed onboarding, lazy WorkManager initialization, boolean scheduler results, and JNI exception clearing.

- [x] Add exact source-contract assertions.
- [x] Run `python tests/android_usage_static_test.py` and confirm it fails against the current startup implementation.

### Task 2: Implement platform-safe startup

**Files:**
- Modify: `android/AndroidManifest.xml`
- Modify: `android/src/main/java/com/timearc/mobile/usage/UsageAccessBridge.java`
- Modify: `android/src/main/java/com/timearc/mobile/usage/UsageSyncScheduler.java`
- Modify: `src/main.cpp`
- Modify: `src/services/mobile/mobile_usage_service.cpp`
- Modify: `qml/mobile/MobileAppShell.qml`

**Interfaces:**
- Consumes: `MobileUsageService::{refreshUsageAccessState,openUsageAccessSettings,requestImmediateSync}`.
- Produces: Java `boolean enqueueImmediateSync(Context)` and `boolean enqueuePeriodicSync(Context)` that never propagate platform failures.

- [x] Remove the WorkManager AndroidX Startup initializer through manifest merge metadata.
- [x] Add guarded/lazy Java bridge behavior and resolvable settings intent checks.
- [x] Check and clear JNI exceptions and propagate boolean failure into service status.
- [x] Delay onboarding until the launch overlay finishes and remove automatic permission-Activity launch.
- [x] Set `QSG_RHI_BACKEND=opengl` before constructing `QGuiApplication` on Android.
- [x] Run the static test and confirm it passes.

### Task 3: Verify and package

**Files:**
- Modify: Android/compatibility documentation and Track C journal records.
- Create: `dist/TimeArc-1.0-android-arm64-v8a-harmony-safe-debug.apk`

**Interfaces:**
- Consumes: repository build harness and Android SDK tooling.
- Produces: installable debug APK plus SHA-256 checksum and explicit device-test caveat.

- [x] Run all targeted static tests.
- [x] Build through `.harness/tools/build.py`, including the Android APK target.
- [x] Run CTest and `harness_check.py`.
- [x] Inspect APK package, SDK, ABI, and signing information.
- [x] Copy the verified APK to `dist/` and calculate SHA-256.
