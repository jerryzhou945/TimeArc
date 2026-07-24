# Mobile Report Release, Avatar Refresh, and APK Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix avatar refresh, gate reports at the next-month 08:00 release,
add an unseen-report badge, remove fake status chrome, and deliver an APK.

**Architecture:** `MobileUsageService` owns deterministic local-time release
keys and exact released-month aggregation. QML owns seen-state persistence and
presentation. `MobileUiService` remains the avatar file owner.

**Tech Stack:** Qt 6/QML, C++17, SettingsRepository, Python static tests,
GitHub PR workflow, Android Gradle/Qt deployment tools.

## Global Constraints

- July 2026 becomes visible only at 2026-08-01 08:00 local time.
- Do not expose an in-progress current-month report.
- Do not add fake phone status data.
- APK must be built from merged `dev`.

---

### Task 1: Avatar refresh regression

**Files:**
- Modify: `tests/mobile_ui_static_test.py`
- Modify: `qml/mobile/pages/MobileSettingsPage.qml`

- [ ] Add failing assertions for `avatarSource`, `onAvatarChanged`, forced
  reassignment, and visible feedback.
- [ ] Run the static test and confirm failure.
- [ ] Implement explicit source refresh and selection feedback.
- [ ] Re-run the static test and confirm success.

### Task 2: Released-month service policy

**Files:**
- Modify: `tests/mobile_ui_static_test.py`
- Modify: `src/services/mobile/mobile_usage_service.h`
- Modify: `src/services/mobile/mobile_usage_service.cpp`
- Modify: `qml/mobile/pages/MobileHistoryPage.qml`

- [ ] Add failing assertions for release APIs, 08:00 boundary logic, exact
  monthly range, and released-month QML consumption.
- [ ] Run the static test and confirm failure.
- [ ] Implement latest month/year keys and report release status.
- [ ] Aggregate the latest released month and update Memory Lake.
- [ ] Re-run the static test and confirm success.

### Task 3: Report badge and status chrome

**Files:**
- Modify: `tests/mobile_ui_static_test.py`
- Modify: `qml/mobile/components/MobileStatusBar.qml`
- Modify: `qml/mobile/components/MobileTabButton.qml`
- Modify: `qml/mobile/MobileTheme.qml`
- Modify: `qml/mobile/MobileAppShell.qml`

- [ ] Add failing assertions for zero-height chrome and the report badge.
- [ ] Run the static test and confirm failure.
- [ ] Add release-token seen state and a red History-tab dot.
- [ ] Re-run the static test and confirm success.

### Task 4: Verify and integrate

**Files:**
- Modify: `README.md`
- Modify: session record and harness logs as required.

- [ ] Document the report release schedule.
- [ ] Run mobile/Android static checks, CTest, harness build, and harness check.
- [ ] Launch mobile preview and scan its Qt log after closing.
- [ ] Push, create a PR, merge to `dev`, and delete the feature branch.

### Task 5: Android package

- [ ] Inspect the configured Qt Android kit, SDK, NDK, JDK, and build scripts.
- [ ] Build an installable APK from merged `dev`.
- [ ] Verify the APK exists and report its exact path, size, and signing type.

