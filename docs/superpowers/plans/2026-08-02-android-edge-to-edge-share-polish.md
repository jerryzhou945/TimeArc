# Android Edge-to-Edge and Share Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship an Android/HarmonyOS mobile UI that draws edge-to-edge, renders every app icon with consistent rounded corners, resolves Huawei launcher metadata, and presents polished responsive share previews.

**Architecture:** Keep the known-good default QtActivity theme and configure Android system bars at runtime through `MobileUiBridge`. Normalize Android metadata before persistence and again at the C++ presentation boundary for old rows. Centralize SVG rendering and app-icon masking in reusable QML components, then rebuild both share flows around safe-area-aware responsive posters.

**Tech Stack:** Qt 6/QML, C++17, Android Java, AndroidX Core, Material Symbols Rounded SVG, Python static tests, CMake qrc resources.

## Global Constraints

- Do not bind a custom theme to `QtActivity`; the default Activity theme is the confirmed HarmonyOS-compatible startup path.
- Keep restored Usage Access permissions and WorkManager scheduling unchanged.
- Draw backgrounds edge-to-edge while preserving visible system status and gesture indicators.
- Store original package identifiers unchanged; normalization is metadata/presentation-only.
- Vendor only selected SVG assets and surface their Apache-2.0 license offline.

---

### Task 1: Runtime Edge-to-Edge Window Contract

**Files:**
- Modify: `android/src/main/java/com/timearc/mobile/ui/MobileUiBridge.java`
- Modify: `src/services/mobile/mobile_ui_service.cpp`
- Modify: `qml/main.qml`
- Modify: `qml/mobile/MobileAppShell.qml`
- Modify: `tests/android_launch_experience_static_test.py`

**Interfaces:**
- Produces: `MobileUiBridge.configureEdgeToEdge(Context, boolean)` and safe-area-aware QML shell geometry.

- [ ] Add a failing static test requiring transparent system bars, `WindowCompat.setDecorFitsSystemWindows(window, false)`, navigation contrast disablement, and no Activity theme binding.
- [ ] Run `python tests/android_launch_experience_static_test.py`; expect failure for the missing runtime API.
- [ ] Implement `configureEdgeToEdge`, call it after `MobileUiService` initialization, and make QML backgrounds fill the root while interactive content consumes `SafeArea.margins`.
- [ ] Re-run the static test and mobile QML smoke; expect pass with no manifest theme regression.

### Task 2: Licensed SVG Icon System

**Files:**
- Create: `resources/app/icons/mobile/*.svg`
- Create: `resources/licenses/material-symbols-apache-2.0.txt`
- Create: `qml/mobile/components/MobileSymbolIcon.qml`
- Modify: `resources/CMakeLists.txt`
- Modify: `qml/mobile/pages/MobileSettingsPage.qml`
- Modify: `qml/mobile/components/MobileShareActionBar.qml`
- Modify: `qml/desktop/pages/DesktopProfilePage.qml`
- Modify: `.harness/rules/06-licensing.md`
- Modify: `README.md`

**Interfaces:**
- Produces: `MobileSymbolIcon { name; size; color }` backed by qrc SVG assets.

- [ ] Add a static test that rejects Unicode icon marks and requires each settings/share action to reference a named SVG.
- [ ] Run the test; expect failure on `mark` and glyph-based settings mapping.
- [ ] Vendor the selected Rounded SVGs, register qrc aliases, implement `MobileSymbolIcon`, and replace glyphs in settings/share actions.
- [ ] Add Apache-2.0 text and update the offline license inventory; re-run the test and harness license checks.

### Task 3: Rounded App Icons and Huawei Metadata

**Files:**
- Modify: `android/src/main/java/com/timearc/mobile/usage/AndroidAppMetadataResolver.java`
- Modify: `src/services/mobile/mobile_usage_service.cpp`
- Modify: `qml/mobile/components/MobileAppIcon.qml`
- Modify: `tests/android_usage_static_test.py`
- Modify: `tests/db_smoke.cpp`

**Interfaces:**
- Produces: normalized base-package lookup, “华为桌面” mapping, category fallback name/icon hint, and a 22%-radius QML icon mask.

- [ ] Add tests for `com.huawei.android.launcher.LauncherApplication`, known Huawei labels, class-suffix stripping, and rounded clipping.
- [ ] Run Android static and DB smoke tests; expect failure for missing normalization/mapping.
- [ ] Normalize PackageManager lookup candidates, add the C++ legacy-row mapping, and update `MobileAppIcon` to clip all images with a consistent rounded mask and semantic Home fallback.
- [ ] Re-run Android static and DB smoke tests; expect friendly labels and no raw package text.

### Task 4: Responsive Single-App Share Preview

**Files:**
- Modify: `qml/mobile/components/MobileShareOverlay.qml`
- Modify: `qml/mobile/components/MobileRankingShareOverlay.qml`
- Modify: `qml/mobile/MobileAppShell.qml`
- Test: `tests/mobile_qml_static_test.py`

**Interfaces:**
- Consumes: `MobileSymbolIcon` and normalized `MobileAppIcon`.
- Produces: a full-window safe-area share overlay and responsive 9:16 single-app poster.

- [ ] Add static assertions for full-window overlay parenting, bounded poster size, two-line app-name wrapping, and absence of raw package fields.
- [ ] Run the static test; expect failure on the current fixed oversized sheet.
- [ ] Rebuild header, poster hierarchy, feedback, and action placement; ensure the overlay is above the tab bar and the export item has deterministic dimensions.
- [ ] Run QML static tests and a mobile-preview smoke at phone width; expect no clipping or QML warnings.

### Task 5: Responsive Monthly Share Preview

**Files:**
- Modify: `qml/mobile/components/monthly/MonthlySharePage.qml`
- Modify: `qml/mobile/components/MobileShareActionBar.qml`
- Test: `tests/mobile_qml_static_test.py`

**Interfaces:**
- Consumes: the shared action bar and normalized monthly report names.
- Produces: a responsive seasonal poster without nested glass-card layout.

- [ ] Add assertions for safe-area sheet bounds, seasonal art, bottom gradient facts, and bounded report text.
- [ ] Run the test; expect failure on the nested report card structure.
- [ ] Replace the nested card with a poster-first composition and keep action buttons reachable above the gesture inset.
- [ ] Re-run QML tests and mobile preview; expect a balanced poster and no raw Huawei identifier.

### Task 6: Integration, APK, and Documentation

**Files:**
- Modify: `docs/android-mobile-edge-to-edge-share-polish-report.md`
- Modify: `docs/android-mobile-polish-progress.md`
- Modify: `docs/implementation-backlog.md`
- Modify: `.harness/state/open-issues.md`
- Modify: `.harness/journal/sessions/20260802-1117-B-android-mobile-polish.md`

**Interfaces:**
- Produces: verified APK and a rollback-ready completion report.

- [ ] Run all targeted Python/static tests and DB smoke.
- [ ] Build through `.harness/tools/build.py`, then build/package the Android arm64 APK using the repository Android script.
- [ ] Launch mobile preview, scan Qt logs with `.harness/tools/scan_qt_log.py`, and record screenshots/limitations.
- [ ] Run `.harness/tools/harness_check.py`, update the five-field progress/session report, and commit in independently revertible phases.

