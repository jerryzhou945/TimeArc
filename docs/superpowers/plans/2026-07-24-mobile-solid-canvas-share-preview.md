# Mobile Solid Canvas and Share Preview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Improve the wallpaper-free mobile canvas and make monthly/app sharing use balanced rounded previews.

**Architecture:** Add theme-owned default-canvas tokens and render them once in
`MobileAppShell`. Recompose the Memory Lake report entry without changing its
data. Give `MonthlySharePage` ownership of the poster item and pass that item to
`MobileMonthlyStory` for export, matching the existing app-poster capture flow.

**Tech Stack:** Qt 6, QML, Python static UI tests, TimeArc build harness.

## Global Constraints

- No new bitmap assets.
- No changes to usage data, privacy filtering, or Android share routing.
- Default-background and wallpaper modes must both remain readable.
- All interactive actions retain a minimum 44 px target.

---

### Task 1: Default atmospheric canvas and wallpaper prompt

**Files:**
- Modify: `tests/mobile_ui_static_test.py`
- Modify: `qml/mobile/MobileTheme.qml`
- Modify: `qml/mobile/MobileAppShell.qml`
- Modify: `qml/mobile/pages/MobileHomePage.qml`

**Interfaces:**
- Consumes: `mobileUiService.importWallpaper()` and `wallpaperActive`.
- Produces: theme tokens `defaultCanvasTop`, `defaultCanvasMiddle`, and
  `defaultCanvasBottom`.

- [ ] Write static assertions for the three theme tokens, shell gradient, and
  wallpaper prompt guarded by `!root.wallpaperActive`.
- [ ] Run `tests/mobile_ui_static_test.py` and verify the new assertions fail.
- [ ] Implement the gradient and prompt using the existing wallpaper service.
- [ ] Re-run the static test and verify it passes.
- [ ] Commit the task.

### Task 2: Balanced monthly entry

**Files:**
- Modify: `tests/mobile_ui_static_test.py`
- Modify: `qml/mobile/pages/MobileHistoryPage.qml`

**Interfaces:**
- Consumes: `coverProfile`, `report`, and `monthlyStory.open()`.
- Produces: `reportFooter` with a right-aligned 44 px open action.

- [ ] Add assertions for a single glass plane and `reportFooter`.
- [ ] Run the static test and verify failure.
- [ ] Recompose the entry while keeping its 18 px clipped outer rectangle.
- [ ] Run the static test and verify success.
- [ ] Commit the task.

### Task 3: Rounded monthly and app share previews

**Files:**
- Modify: `tests/mobile_ui_static_test.py`
- Modify: `qml/mobile/components/monthly/MonthlySharePage.qml`
- Modify: `qml/mobile/components/MobileMonthlyStory.qml`
- Modify: `qml/mobile/components/MobileShareOverlay.qml`

**Interfaces:**
- `MonthlySharePage` emits `shareRequested(string channel, var previewItem)`.
- `MobileMonthlyStory.exportReport(string channel, var previewItem)` captures
  `previewItem` at 1080 × 1920.
- Both preview posters expose `radius: 22`.

- [ ] Add assertions for `monthlyPoster`, preview-item signal flow, and the
  common poster radius.
- [ ] Run the static test and verify failure.
- [ ] Build the explicit monthly poster and update capture routing.
- [ ] Refine the app poster frame and shared radius.
- [ ] Run the static test and verify success.
- [ ] Commit the task.

### Task 4: Verify and preview

**Files:**
- Modify only harness-generated logs and session records as required.

- [ ] Run the mobile and Android static checks.
- [ ] Run CTest.
- [ ] Build with `.harness/tools/build.py`.
- [ ] Run `.harness/tools/harness_check.py`.
- [ ] Launch the Mobile preview and visually inspect default and sharing states.
- [ ] After the preview exits, run `.harness/tools/scan_qt_log.py`.

