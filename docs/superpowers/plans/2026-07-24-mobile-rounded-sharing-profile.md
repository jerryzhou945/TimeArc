# Mobile Rounded Sharing and Personal Archive Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply true rounded masks to share artwork and add a locally
persistent personal time archive to the mobile Profile tab.

**Architecture:** A reusable QML mask component owns rounded composition for
posters and avatars. `MobileUiService` persists only the avatar file path and
QML consumes aggregate usage data directly from `MobileUsageService`.

**Tech Stack:** Qt 6 QML, QtQuick.Effects, C++17, SettingsRepository, Python
static tests, TimeArc harness.

## Global Constraints

- Do not change the service database schema or automatic-usage disk contract.
- Do not upload or automatically include the avatar in shared images.
- Build only through `.harness/tools/build.py`.
- Keep all visible fallback copy Chinese and evidence-based.

---

### Task 1: True rounded frame

**Files:**
- Create: `qml/mobile/components/MobileRoundedFrame.qml`
- Modify: `qml/CMakeLists.txt`
- Modify: `tests/mobile_ui_static_test.py`

**Interfaces:**
- Produces: `radius`, `border`, and default `content` properties.
- Depends on: `QtQuick.Effects.MultiEffect`.

- [ ] Add failing assertions for the new component and QML registration.
- [ ] Run the static test and confirm the missing-component failure.
- [ ] Implement the layer and rounded mask.
- [ ] Re-run the static test and confirm success.

### Task 2: Rounded app and monthly share surfaces

**Files:**
- Modify: `qml/mobile/components/MobileShareOverlay.qml`
- Modify: `qml/mobile/components/monthly/MonthlySharePage.qml`
- Modify: `tests/mobile_ui_static_test.py`

**Interfaces:**
- Consumes: `MobileRoundedFrame`.
- Preserves: `shareRequested(channel, monthlyPoster)` and 1080 × 1920 export.

- [ ] Add failing assertions for both frame consumers and `monthlyShareSheet`.
- [ ] Run the static test and confirm failure.
- [ ] Replace poster rectangles with masked frames and add the neutral monthly
  bottom sheet.
- [ ] Re-run the static test and confirm success.

### Task 3: Local avatar service

**Files:**
- Modify: `src/services/mobile/mobile_ui_service.h`
- Modify: `src/services/mobile/mobile_ui_service.cpp`
- Modify: `tests/mobile_ui_static_test.py`

**Interfaces:**
- Produces: `avatarUrl`, `importAvatar(QUrl)`, `clearAvatar()`,
  and `avatarChanged()`.
- Persists: `mobile_profile_avatar_path`.

- [ ] Add failing service-contract assertions.
- [ ] Run the static test and confirm failure.
- [ ] Implement versioned avatar import, replacement cleanup, and clear.
- [ ] Re-run the static test and confirm success.

### Task 4: Profile archive UI

**Files:**
- Modify: `qml/mobile/pages/MobileSettingsPage.qml`
- Modify: `tests/mobile_ui_static_test.py`
- Modify: `README.md`

**Interfaces:**
- Consumes: `mobileUiService.avatarUrl` and
  `mobileUsageService.getDashboardForRange("all")`.
- Computes: inclusive companionship days from `firstDateLocal`.

- [ ] Add failing assertions for avatar picker and three evidence facts.
- [ ] Run the static test and confirm failure.
- [ ] Implement the profile archive panel and refresh connections.
- [ ] Document local avatar behavior in README.
- [ ] Re-run static checks and confirm success.

### Task 5: Build and preview

**Files:**
- Modify only harness logs/session record as required.

- [ ] Run mobile and Android static checks.
- [ ] Run CTest.
- [ ] Build through the harness.
- [ ] Run `harness_check.py`.
- [ ] Launch Mobile preview and inspect both sharing surfaces and Profile.
- [ ] Scan the Qt log after the preview exits.

