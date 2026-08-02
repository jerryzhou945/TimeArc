# Android Realtime Edge Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Android app icons genuinely rounded, extend TimeArc behind HarmonyOS system bars, and refresh correctly partitioned current-day usage every time the app becomes active.

**Architecture:** A thin `TimeArcActivity` owns Android lifecycle work while retaining Qt's default theme. Android UsageStats are imported one local day at a time into replaceable aggregate rows, and a native completion callback refreshes QML only after persistence. QML uses the existing GPU rounded-frame mask instead of rectangular clipping.

**Tech Stack:** Qt 6.11/QML, C++17, JNI, Java 17, AndroidX Core 1.17, WorkManager 2.9.1, SQLite, Python static regressions, CTest.

## Global Constraints

- Keep `QtActivity`'s default Android theme; no `android:theme` attribute may be added.
- Keep `PACKAGE_USAGE_STATS`, WorkManager periodic sync, ABI `arm64-v8a`, and package `com.timearc.app`.
- Do not modify the desktop service database, service schema, or frozen CMake/contract files.
- Dark mode owns this repair; light-mode visual tuning is deferred.
- Work directly in `D:\TimeArc\time-arc`; do not create a worktree.

---

### Task 1: Genuine rounded application icons

**Files:**
- Modify: `tests/mobile_qml_static_test.py`
- Modify: `qml/mobile/components/MobileAppIcon.qml`

**Interfaces:**
- Consumes: `MobileRoundedFrame.radius` and its `MultiEffect` mask.
- Produces: `MobileAppIcon` with a 22% rounded-square mask for loaded images and fallbacks.

- [ ] **Step 1: Write the failing mask regression**

Add assertions that `MobileAppIcon.qml` instantiates `MobileRoundedFrame`, sets `radius: root.cornerRadius`, and no longer relies on a nested `Rectangle`'s `clip: true` to round `iconImage`.

- [ ] **Step 2: Run the regression and verify RED**

Run: `.local-python\Python312\python.exe tests\mobile_qml_static_test.py`

Expected: FAIL because the real rounded mask is absent.

- [ ] **Step 3: Replace rectangular clipping with the existing mask**

Keep the outer tonal background, then render fallback and `Image` content inside:

```qml
MobileRoundedFrame {
    anchors.fill: parent
    radius: root.cornerRadius

    Rectangle { anchors.fill: parent; color: root.theme.surfaceRaised }
    Image {
        id: iconImage
        anchors.fill: parent
        anchors.margins: 3
        fillMode: Image.PreserveAspectCrop
    }
}
```

- [ ] **Step 4: Run the regression and verify GREEN**

Run: `.local-python\Python312\python.exe tests\mobile_qml_static_test.py`

Expected: PASS.

- [ ] **Step 5: Commit the independently reversible UI fix**

```powershell
git add qml/mobile/components/MobileAppIcon.qml tests/mobile_qml_static_test.py
git commit -m "Fix rounded Android app icon masks"
```

### Task 2: Lifecycle-owned HarmonyOS edge-to-edge

**Files:**
- Create: `android/src/main/java/com/timearc/mobile/ui/TimeArcActivity.java`
- Modify: `android/AndroidManifest.xml`
- Modify: `android/src/main/java/com/timearc/mobile/ui/MobileUiBridge.java`
- Modify: `tests/android_launch_experience_static_test.py`

**Interfaces:**
- Consumes: `MobileUiBridge.configureEdgeToEdge(Context, boolean)` and `UsageSyncScheduler.enqueueImmediateSync(Context)`.
- Produces: `TimeArcActivity extends QtActivity`, with `onCreate`/`onResume` lifecycle hooks and no custom theme.

- [ ] **Step 1: Write failing lifecycle and manifest regressions**

Assert that the manifest names `com.timearc.mobile.ui.TimeArcActivity`, the Activity has no theme attribute, `TimeArcActivity` extends Qt's binding Activity, and both lifecycle paths call edge-to-edge while `onResume` queues immediate sync. Assert the bridge applies `LAYOUT_STABLE`, `LAYOUT_FULLSCREEN`, `LAYOUT_HIDE_NAVIGATION`, transparent bars, and cutout short-edge mode.

- [ ] **Step 2: Run the regression and verify RED**

Run: `.local-python\Python312\python.exe tests\android_launch_experience_static_test.py`

Expected: FAIL because `TimeArcActivity.java` does not exist.

- [ ] **Step 3: Implement the lifecycle Activity without a theme**

Create a final Activity that calls `super`, then:

```java
MobileUiBridge.configureEdgeToEdge(this, false);
UsageSyncScheduler.enqueueImmediateSync(this);
```

Reapply edge-to-edge from both `onCreate` and `onResume`; queue sync only from `onResume`. In the bridge, add legacy layout visibility flags and `LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES` alongside `WindowCompat.setDecorFitsSystemWindows(false)`.

- [ ] **Step 4: Run launch and existing usage regressions**

Run: `.local-python\Python312\python.exe tests\android_launch_experience_static_test.py`

Run: `.local-python\Python312\python.exe tests\android_usage_static_test.py`

Expected: both PASS.

- [ ] **Step 5: Commit the independently reversible lifecycle fix**

```powershell
git add android/AndroidManifest.xml android/src/main/java/com/timearc/mobile/ui tests/android_launch_experience_static_test.py
git commit -m "Fix HarmonyOS edge-to-edge lifecycle"
```

### Task 3: Per-day realtime UsageStats replacement

**Files:**
- Modify: `android/src/main/java/com/timearc/mobile/usage/AndroidUsageNativeBridge.java`
- Modify: `android/src/main/java/com/timearc/mobile/usage/UsageSyncWorker.java`
- Modify: `src/services/mobile/android_usage_jni_bridge.cpp`
- Modify: `src/services/mobile/mobile_usage_repository.h`
- Modify: `src/services/mobile/mobile_usage_repository.cpp`
- Modify: `src/services/mobile/mobile_usage_service.h`
- Modify: `src/services/mobile/mobile_usage_service.cpp`
- Modify: `qml/mobile/MobileAppShell.qml`
- Modify: `tests/android_usage_static_test.py`
- Modify: `tests/db_smoke.cpp`

**Interfaces:**
- Produces: `MobileUsageRepository::clearDailyUsageSummaries(deviceId, dateLocal, source) -> bool`.
- Produces: Java `nativeSyncFinished(boolean success)` and C++ `MobileUsageService::notifyAndroidSyncFinished(bool)`.
- Consumes: unique WorkManager immediate work triggered by `TimeArcActivity.onResume`.

- [ ] **Step 1: Write failing daily-partition, replacement, and completion tests**

The static test must require a Calendar loop advancing one day at a time, a completion callback after both aggregate and session imports, and no single call that stores the previous-month-to-now aggregate. The DB smoke test inserts a stale Android aggregate row and an unrelated source/session, calls `clearDailyUsageSummaries`, then asserts only the target aggregate row is removed.

- [ ] **Step 2: Run both regressions and verify RED**

Run: `.local-python\Python312\python.exe tests\android_usage_static_test.py`

Run: `ctest --test-dir build -R timearc_db_smoke --output-on-failure`

Expected: static FAIL for missing daily loop/callback; DB smoke cannot compile until the repository API exists.

- [ ] **Step 3: Implement narrow aggregate replacement**

Add `clearDailyUsageSummaries` with a parameterized delete restricted to `platform='android'`, normalized device, exact ISO date, and normalized source. In JNI, clear the day before processing its DTO array, including the zero-record case, then upsert the day's records.

- [ ] **Step 4: Partition worker imports by local day**

From the first day of the previous month through `System.currentTimeMillis()`, calculate `[dayStart, min(nextDayStart, now))` and call `syncAggregatedUsage` once per window. Sync recent sessions once. Call `AndroidUsageNativeBridge.notifySyncFinished(success)` before returning success or retry.

- [ ] **Step 5: Deliver completion to the live Qt service**

Register the one live `MobileUsageService` as a guarded pointer on Android. JNI queues `notifyAndroidSyncFinished(success)` onto its Qt thread. Success sets status to `synced` and emits `dataChanged`; failure sets `retrying` without claiming refreshed data. Remove the eager `dataChanged` emission from `requestImmediateSync`.

- [ ] **Step 6: Sync on every Qt foreground transition as fallback**

In `MobileAppShell.qml`, observe `Qt.application.state`; when it becomes `Qt.ApplicationActive`, run the same access check and request immediate sync. This supplements the Activity hook and keeps mobile preview guarded.

- [ ] **Step 7: Build and run GREEN verification**

Run: `.local-python\Python312\python.exe .harness\tools\build.py`

Run: `ctest --test-dir build --output-on-failure`

Run: `.local-python\Python312\python.exe tests\android_usage_static_test.py`

Expected: Windows build succeeds, CTest 4/4 PASS, static usage checks PASS.

- [ ] **Step 8: Commit the realtime data fix**

```powershell
git add android/src/main/java/com/timearc/mobile/usage src/services/mobile qml/mobile/MobileAppShell.qml tests/android_usage_static_test.py tests/db_smoke.cpp
git commit -m "Fix Android daily realtime usage sync"
```

### Task 4: Android package and completion evidence

**Files:**
- Modify: `docs/android-realtime-edge-fix-progress.md`
- Create: `docs/android-realtime-edge-fix-report.md`
- Modify: `.harness/journal/errors/20260802-043258-C-android-mobile-regressions.md`
- Modify: `.harness/journal/sessions/20260802-1232-C-android-mobile-regressions.md`
- Modify: `docs/implementation-backlog.md`
- Modify: `.harness/state/open-issues.md`

**Interfaces:**
- Produces: signed arm64 debug APK under `dist/` and a SHA-256 handoff.

- [ ] **Step 1: Build Android UI and APK through Harness**

Run the Harness wrapper for `time-arc`, then `time-arc_make_apk` in `build-android-arm64_v8a`.

- [ ] **Step 2: Verify the package**

Use Android build-tools to verify v2 signing, package `com.timearc.app`, ABI `arm64-v8a`, `PACKAGE_USAGE_STATS`, the custom Activity class, and absence of `android:theme` on that Activity.

- [ ] **Step 3: Copy and hash the deliverable**

Copy the generated APK to `dist/TimeArc-1.0-android-arm64-v8a-realtime-edge-debug.apk` and calculate SHA-256.

- [ ] **Step 4: Update reports and Harness evidence**

Record Completed, Incomplete, Verification, Next, and Risks. The remaining incomplete item must be Pura 90 Pro visual/data verification after installation.

- [ ] **Step 5: Run final gates and commit**

Run `git diff --check`, all three mobile static tests, CTest, and `.harness/tools/harness_check.py`, then commit with:

```powershell
git commit -m "Fix Android mobile regression verification"
```
