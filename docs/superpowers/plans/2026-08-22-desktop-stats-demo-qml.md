# Desktop Stats Demo QML Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the desktop statistics card grid with the approved desktop demo structure while preserving real TimeArc data, themes, period navigation, export, and privacy behavior.

**Architecture:** Keep `UsageStatManager` as the read-only source and derive day-clock, Top ranking, and full-library view models inside `DesktopStatsPage.qml`. Add focused QML components for the day clock, timeline, and all-app library; use `AppVisual.js` and `image://appicon/` for real app icons. Do not change the service, SQLite schema, mobile UI, or homepage.

**Tech Stack:** Qt 6 QML, Canvas, existing MemoryLake style tokens, UsageStatManager QVariant APIs, Qt Test/static source regression checks.

**Spec:** `docs/stats-daily-prototype-report-2026-08-21.md`

## Global Constraints

- Desktop only; homepage and mobile pages remain unchanged.
- Daily view is the default and owns the application clock.
- Week/month/year retain one primary trend and compact supporting facts.
- Top ranking remains an overview; the full app library shows every retained app and lifetime time.
- App icons come from existing adapters or `image://appicon/`; no embedded per-app production assets.
- All colors and cursor shapes use existing desktop theme and platform cursor contracts.
- Service-owned SQLite remains read-only from the UI.

---

### Task 1: View-model contract

**Files:**
- Create: `qml/desktop/pages/StatsViewModel.js`
- Modify: `qml/desktop/pages/DesktopStatsPage.qml`
- Modify: `qml/CMakeLists.txt`
- Create: `tests/stats_view_model_test.js`

**Interfaces:**
- Consumes: `activeSoftwareForWindow`, `foregroundSegmentsForWindow`, `allApps`, `recordsGeneration`.
- Produces: `vmClockSegments`, `vmLibraryRows`, `vmLifetimeTotalSec`, `StatsViewModel.buildClockSegments()`, `StatsViewModel.buildAppLibrary()`.

- [-] **Step 1: Write a failing view-model behavior test**

Use literal sessions and app totals to assert AM/PM clipping, exact clock angles, period/lifetime merging, inactive historical apps, query filtering, and period/lifetime/name sorting.

- [ ] **Step 2: Run the test and verify the missing contract fails**

Run: `node tests\stats_view_model_test.js`

- [ ] **Step 3: Add minimal day-window and app-library model functions**

Add day handling to `rangeWord`, `rangeLabel`, `periodWindow`, and `rebuild`; merge period rows with lifetime `allApps()` rows by `groupKey` and filter/sort from UI state.

- [ ] **Step 4: Run the view-model test until the model contract passes**

Run: `node tests\stats_view_model_test.js`

### Task 2: Daily application clock

**Files:**
- Modify: `qml/desktop/pages/DesktopStatsPage.qml`
- Test: `tests/stats_view_model_test.js`

**Interfaces:**
- Consumes: `vmClockSegments`, `clockHalf`, `AppVisual.modelIconSource()`.
- Produces: `StatsApplicationClock` with Canvas sectors, icon overlays, AM/PM switching, hover focus, and center details.

- [ ] **Step 1: Extend the failing model test for app metadata and clipped sector identity**
- [ ] **Step 2: Run the test and confirm failure is caused by missing clock metadata**
- [ ] **Step 3: Implement the clock component using theme tokens and one dial-wide hit tester**
- [ ] **Step 4: Run the static test and QML syntax build**

### Task 3: Timeline and full app library

**Files:**
- Modify: `qml/desktop/pages/DesktopStatsPage.qml`
- Test: `tests/stats_view_model_test.js`

**Interfaces:**
- Consumes: `vmSegments`, `vmLibraryRows`, `libraryQuery`, `librarySort`, `showInactiveApps`.
- Produces: `StatsDayTimeline` and `StatsAppLibrary` with search, period/lifetime/name sorting, inactive toggle, per-app period time, share, lifetime time, category, icon, and last-record state.

- [ ] **Step 1: Add failing assertions for complete-library filters and both time values**
- [ ] **Step 2: Run and confirm failure**
- [ ] **Step 3: Implement desktop table/list presentation without Top truncation**
- [ ] **Step 4: Run the static and existing prototype tests**

### Task 4: Page composition and range parity

**Files:**
- Modify: `qml/desktop/pages/DesktopStatsPage.qml`
- Test: `tests/stats_view_model_test.js`

**Interfaces:**
- Consumes: existing week/month/year charts, metrics, export, theme and period navigation.
- Produces: daily 2:1 clock/composition row, timeline/ranking row, aggregate range sections, and shared full app library.

- [ ] **Step 1: Add failing assertions that daily and aggregate layouts coexist**
- [ ] **Step 2: Replace the old default card-grid composition while preserving aggregate components**
- [ ] **Step 3: Update report/export fields for day and full app totals**
- [ ] **Step 4: Run static tests and build through `.harness/tools/build.py`**

### Task 5: Runtime and visual verification

**Files:**
- Modify: `docs/stats-daily-prototype-report-2026-08-21.md`
- Modify: `.harness/journal/sessions/20260822-1040-B-stats-qml-migration.md`

**Interfaces:**
- Consumes: built `TimeArc.exe` and Qt runtime log.
- Produces: verified desktop screenshots/log scan and a documented handoff for the separate timer-debug session.

- [ ] **Step 1: Launch TimeArc, open statistics, exercise day/week/month/year, AM/PM, search and sorting**
- [ ] **Step 2: Run `.harness/tools/scan_qt_log.py` and record any runtime errors**
- [ ] **Step 3: Run all related tests, `git diff --check`, and `harness_check.py`**
- [ ] **Step 4: Document remaining timer defects without mixing their fixes into this Track B diff**
