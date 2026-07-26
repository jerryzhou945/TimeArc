# Mobile Seasonal Report QML Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate the approved seasonal monthly-report web prototype into production mobile QML backed by truthful Android usage data, deterministic narrative copy, and unified share posters.

**Architecture:** A focused C++ `MobileUsageInsightEngine` converts daily aggregates and observed sessions into a structured `MonthlyReportModel`; `MobileUsageService` owns repository queries and exposes that model to QML. QML separates the season scene, month profile, six story pages, and share posters so visual changes never alter facts. Android extends its idempotent sync window so current and previous month evidence exists locally.

**Tech Stack:** Qt 6 Core/QML/Quick, C++17, Android Java `UsageStats`/`UsageEvents`, SQLite through existing repositories, Python static tests, local JPEG resources.

## Global Constraints

- Work directly in `D:\TimeArc\time-arc`; do not create a worktree.
- Keep service-owned SQLite, sampler behavior, frozen C ABI, and desktop UI unchanged.
- Production QML must not load network images or generate unsupported facts.
- Build only with `.local-python\Python312\python.exe .harness/tools/build.py`.
- After every Qt/QML run, execute `.local-python\Python312\python.exe .harness/tools/scan_qt_log.py`.
- Before every commit, execute `.local-python\Python312\python.exe .harness/tools/harness_check.py`.
- Use deterministic copy; identical input must produce identical output.
- Use observed sessions for absolute “longest” claims; estimated or incomplete evidence must downgrade wording.
- Support reduced motion and 44×44 minimum touch targets.

---

### Task 1: Structured Monthly Insight Engine

**Files:**
- Create: `src/services/mobile/mobile_usage_insight_engine.h`
- Create: `src/services/mobile/mobile_usage_insight_engine.cpp`
- Modify: `src/CMakeLists.txt`
- Modify: `tests/db_smoke.cpp`

**Interfaces:**
- Consumes: `QVariantList dailyRows`, `QVariantList sessions`, `QVariantList previousRows`, and `QDate month`.
- Produces: `MobileUsageInsightEngine::buildMonthlyReport(...) -> QVariantMap` with `summary`, `insights`, `topApps`, `companion`, `ranking`, `coverage`, and `share`.

- [ ] **Step 1: Add failing smoke assertions for multidimensional facts**

Add a fixed March dataset to `tests/db_smoke.cpp` and assert:

```cpp
const QVariantMap report = MobileUsageInsightEngine::buildMonthlyReport(
    QDate(2026, 3, 1), insightDailyRows, insightSessions, previousRows);
if (report.value(QStringLiteral("monthKey")).toString() !=
        QStringLiteral("2026-03") ||
    report.value(QStringLiteral("activeDays")).toInt() != 7 ||
    report.value(QStringLiteral("longestStreakDays")).toInt() != 7) {
  return fail(QStringLiteral("Monthly insight calendar facts failed."));
}
const QVariantList insights = report.value(QStringLiteral("insights")).toList();
if (insights.isEmpty() ||
    insights.first().toMap().value(QStringLiteral("kind")).toString().isEmpty()) {
  return fail(QStringLiteral("Monthly insight candidates were not selected."));
}
```

- [ ] **Step 2: Run the smoke target and verify RED**

Run:

```powershell
.local-python\Python312\python.exe .harness/tools/build.py
```

Expected: compile failure because `MobileUsageInsightEngine` does not exist.

- [ ] **Step 3: Define the engine interface**

Create:

```cpp
class MobileUsageInsightEngine {
 public:
  static QVariantMap buildMonthlyReport(const QDate& month,
                                        const QVariantList& dailyRows,
                                        const QVariantList& sessions,
                                        const QVariantList& previousRows);
};
```

Add private helpers in the `.cpp` for active dates, streaks, time segments, observed longest session, late-night evidence, app co-occurrence, month delta, deterministic scoring, and formatted duration.

- [ ] **Step 4: Implement structured candidates and truthful downgrade rules**

Each selected insight must contain:

```cpp
{
  {"kind", "longestSession"},
  {"headline", "2 小时 14 分"},
  {"body", "3 月 18 日 18:42，最长的一次已观测记录从暮色里开始。"},
  {"evidenceDate", "2026-03-18"},
  {"confidence", "observed"},
  {"shareSafe", true}
}
```

Selection order is score descending with a stable `kind` tie-breaker. Select at most three kinds and prevent duplicate categories.

- [ ] **Step 5: Build and run database smoke**

Run:

```powershell
.local-python\Python312\python.exe .harness/tools/build.py
ctest --test-dir build --output-on-failure
```

Expected: build succeeds and `timearc_db_smoke` passes.

- [ ] **Step 6: Commit the engine**

```powershell
git add src/services/mobile/mobile_usage_insight_engine.h src/services/mobile/mobile_usage_insight_engine.cpp src/CMakeLists.txt tests/db_smoke.cpp
git commit -m "feat: add monthly usage insight engine"
```

---

### Task 2: Monthly Report Service Model

**Files:**
- Modify: `src/services/mobile/mobile_usage_service.h`
- Modify: `src/services/mobile/mobile_usage_service.cpp`
- Modify: `tests/db_smoke.cpp`
- Modify: `tests/mobile_ui_static_test.py`

**Interfaces:**
- Consumes: repository daily rows for target and previous months plus session rows for the target month.
- Produces: `Q_INVOKABLE QVariantMap getMonthlyReport(const QString& monthKey)` and makes `getMemoryLakeForCurrentMonth()` reuse it.

- [ ] **Step 1: Add failing service assertions**

Add:

```cpp
const QVariantMap serviceReport =
    mobileUsageService.getMonthlyReport(QStringLiteral("2026-06"));
if (serviceReport.value(QStringLiteral("monthKey")).toString() !=
        QStringLiteral("2026-06") ||
    !serviceReport.contains(QStringLiteral("profile")) ||
    !serviceReport.contains(QStringLiteral("pages"))) {
  return fail(QStringLiteral("Monthly report service model failed."));
}
```

Add a Python static assertion that production QML calls `getMonthlyReport`.

- [ ] **Step 2: Run tests and verify RED**

Run:

```powershell
.local-python\Python312\python.exe .harness/tools/build.py
.local-python\Python312\python.exe tests/mobile_ui_static_test.py
```

Expected: C++ compile failure and static test failure for the missing method.

- [ ] **Step 3: Add the service API and month parsing**

Add:

```cpp
Q_INVOKABLE QVariantMap getMonthlyReport(const QString& monthKey);
```

Accept `yyyy-MM`; invalid input falls back to the current local month. Query:

- target daily rows from month start through month end/current day;
- previous month daily rows;
- sessions using local month start/end converted to Unix seconds.

- [ ] **Step 4: Adapt the engine result to QML pages**

Add a `profile` map containing `month`, `season`, `sceneSource`, `accent`,
`accentInk`, `particleKind`, `layoutVariant`, and `copyTone`. Add a six-entry
`pages` list with stable page kinds:

```cpp
{"cover", "overview", "highlight", "companion", "ranking", "share"}
```

Keep preview data inside `--mobile-preview` QML paths only; Android service
results must never be replaced by fake data.

- [ ] **Step 5: Preserve Memory Lake compatibility**

`getMemoryLakeForCurrentMonth()` returns its existing `moments` and `topApps`
keys while setting its `report` value to the new structured monthly report.

- [ ] **Step 6: Build and test**

Run:

```powershell
.local-python\Python312\python.exe .harness/tools/build.py
ctest --test-dir build --output-on-failure
.local-python\Python312\python.exe tests/mobile_ui_static_test.py
```

Expected: all pass.

- [ ] **Step 7: Commit the service model**

```powershell
git add src/services/mobile/mobile_usage_service.h src/services/mobile/mobile_usage_service.cpp tests/db_smoke.cpp tests/mobile_ui_static_test.py
git commit -m "feat: expose structured monthly reports"
```

---

### Task 3: Android Monthly Backfill

**Files:**
- Modify: `android/src/main/java/com/timearc/mobile/usage/UsageSyncWorker.java`
- Modify: `tests/android_usage_static_test.py`

**Interfaces:**
- Consumes: existing `AndroidUsageNativeBridge.syncAggregatedUsage` and `syncRecentSessions`.
- Produces: idempotent aggregate coverage for current plus previous month and a best-effort 35-day session window.

- [ ] **Step 1: Add failing static checks**

Assert:

```python
assert "RECENT_SESSION_LOOKBACK_DAYS = 35" in worker
assert "startOfPreviousMonthMs" in worker
assert "syncAggregatedUsage" in worker
```

- [ ] **Step 2: Run static test and verify RED**

Run:

```powershell
.local-python\Python312\python.exe tests/android_usage_static_test.py
```

Expected: failure because the worker still uses three days and today-only aggregates.

- [ ] **Step 3: Extend bounded lookback**

Change the worker to:

```java
private static final int RECENT_SESSION_LOOKBACK_DAYS = 35;

private static long startOfPreviousMonthMs() {
    Calendar calendar = Calendar.getInstance();
    calendar.set(Calendar.DAY_OF_MONTH, 1);
    calendar.add(Calendar.MONTH, -1);
    calendar.set(Calendar.HOUR_OF_DAY, 0);
    calendar.set(Calendar.MINUTE, 0);
    calendar.set(Calendar.SECOND, 0);
    calendar.set(Calendar.MILLISECOND, 0);
    return calendar.getTimeInMillis();
}
```

Use `startOfPreviousMonthMs()` for aggregate sync. Keep current native
idempotent upserts and return `Result.retry()` if either bounded sync fails.

- [ ] **Step 4: Run Android static test**

Run:

```powershell
.local-python\Python312\python.exe tests/android_usage_static_test.py
```

Expected: pass.

- [ ] **Step 5: Commit Android backfill**

```powershell
git add android/src/main/java/com/timearc/mobile/usage/UsageSyncWorker.java tests/android_usage_static_test.py
git commit -m "feat: backfill monthly Android usage evidence"
```

---

### Task 4: Twelve Local Month Scene Assets and Profiles

**Files:**
- Create: `resources/features/monthly-recap/month-01.jpg` through `month-12.jpg`
- Create: `qml/mobile/components/MobileMonthProfiles.js`
- Create: `qml/mobile/components/MobileSeasonScene.qml`
- Modify: `resources/CMakeLists.txt`
- Modify: `qml/CMakeLists.txt`
- Modify: `tests/mobile_ui_static_test.py`

**Interfaces:**
- Consumes: `monthNumber`, `pageIndex`, `reducedMotion`.
- Produces: `MobileMonthProfiles.profile(monthNumber)` and a scene component with `sourceReady`, `accentColor`, and seasonal particle rendering.

- [ ] **Step 1: Add failing static checks for all assets and profiles**

Add Python assertions that all twelve resource paths exist, are listed in
`resources/CMakeLists.txt`, and that `MobileMonthProfiles.js` contains twelve
unique `sceneSource` values.

- [ ] **Step 2: Run static test and verify RED**

Run:

```powershell
.local-python\Python312\python.exe tests/mobile_ui_static_test.py
```

Expected: failure for missing assets and components.

- [ ] **Step 3: Produce and optimize twelve original scenes**

Use the four approved seasonal anchor images as style references. Generate
eight missing month scenes, then resize/crop each runtime asset to a consistent
portrait ratio and encode JPEG at a visually lossless quality. Verify no image
contains text, UI, people, logos, borders, or contact-sheet elements.

- [ ] **Step 4: Define twelve month profiles**

`MobileMonthProfiles.profile(month)` returns:

```javascript
{
    month: 3,
    season: "spring",
    sceneSource: "qrc:/time_arc/resources/features/monthly-recap/month-03.jpg",
    accent: "#CFE8B0",
    accentInk: "#233529",
    particleKind: "rain",
    particleCount: 34,
    layoutVariant: "spring-rain",
    copyTone: "after-rain"
}
```

- [ ] **Step 5: Implement `MobileSeasonScene.qml`**

Use one `Image` with `fillMode: Image.PreserveAspectCrop`, one adaptive veil,
and reusable particle delegates. Rain uses independent narrow rectangles with
different lengths, durations, and delays; no repeating texture is permitted.
Disable loops when `reducedMotion` is true.

- [ ] **Step 6: Run static checks**

Run:

```powershell
.local-python\Python312\python.exe tests/mobile_ui_static_test.py
```

Expected: pass for asset/profile/scene checks.

- [ ] **Step 7: Commit scenes and profiles**

```powershell
git add resources/mobile/monthly qml/mobile/components/MobileMonthProfiles.js qml/mobile/components/MobileSeasonScene.qml resources/CMakeLists.txt qml/CMakeLists.txt tests/mobile_ui_static_test.py
git commit -m "feat: add twelve seasonal month scenes"
```

---

### Task 5: Six-Page QML Monthly Story

**Files:**
- Create: `qml/mobile/components/monthly/MonthlyCoverPage.qml`
- Create: `qml/mobile/components/monthly/MonthlyOverviewPage.qml`
- Create: `qml/mobile/components/monthly/MonthlyHighlightPage.qml`
- Create: `qml/mobile/components/monthly/MonthlyCompanionPage.qml`
- Create: `qml/mobile/components/monthly/MonthlyRankingPage.qml`
- Create: `qml/mobile/components/monthly/MonthlySharePage.qml`
- Rewrite: `qml/mobile/components/MobileMonthlyStory.qml`
- Modify: `qml/mobile/pages/MobileHistoryPage.qml`
- Modify: `qml/CMakeLists.txt`
- Modify: `tests/mobile_ui_static_test.py`

**Interfaces:**
- Consumes: `MonthlyReportModel`, `theme`, and `reducedMotion`.
- Produces: full-screen six-page story with `open(monthKey)`, `close()`, `next()`, `previous()`, and `shareRequested(reportModel)`.

- [ ] **Step 1: Add failing structural tests**

Assert six page components are registered, `MobileMonthlyStory` uses
`MobileSeasonScene`, page count is six, touch zones are at least 44 pixels,
and reduced-motion logic is present.

- [ ] **Step 2: Run static test and verify RED**

Run:

```powershell
.local-python\Python312\python.exe tests/mobile_ui_static_test.py
```

Expected: missing component assertions fail.

- [ ] **Step 3: Implement shared page contract**

Every page component exposes:

```qml
required property var report
required property var profile
required property var theme
property bool reducedMotion: false
```

Use month `layoutVariant` to alter alignment, metric placement, evidence
position, ranking cadence, and text width without duplicating business logic.

- [ ] **Step 4: Rewrite story container**

The container owns:

- the single `MobileSeasonScene`;
- six `Loader` or persistent page instances;
- progress segments;
- close and left/right touch regions;
- horizontal swipe handling;
- 350–550 ms ease-out transitions;
- an instant/fade-only reduced-motion state.

- [ ] **Step 5: Connect Memory Lake**

`MobileHistoryPage` asks `mobileUsageService.getMonthlyReport(monthKey)` before
opening. Preview mode may use a structured preview model; production Android
uses only service output.

- [ ] **Step 6: Run static test, build, and preview**

Run:

```powershell
.local-python\Python312\python.exe tests/mobile_ui_static_test.py
.local-python\Python312\python.exe .harness/tools/build.py
.\build\TimeArc.exe --mobile-preview
```

Manually inspect all twelve months and six pages. After closing the preview:

```powershell
.local-python\Python312\python.exe .harness/tools/scan_qt_log.py
```

Expected: no QML warnings and no clipped text at 390×844.

- [ ] **Step 7: Commit the story UI**

```powershell
git add qml/mobile/components/monthly qml/mobile/components/MobileMonthlyStory.qml qml/mobile/pages/MobileHistoryPage.qml qml/CMakeLists.txt tests/mobile_ui_static_test.py
git commit -m "feat: migrate seasonal monthly story to QML"
```

---

### Task 6: Unified App, Ranking, and Monthly Share Posters

**Files:**
- Create: `qml/mobile/components/share/MobileMonthlyReportPoster.qml`
- Create: `qml/mobile/components/share/MobileAppTimePoster.qml`
- Create: `qml/mobile/components/share/MobilePeriodRankingPoster.qml`
- Rewrite: `qml/mobile/components/MobileShareOverlay.qml`
- Modify: `qml/mobile/components/MobileFlipCard.qml`
- Modify: `qml/mobile/pages/MobileHomePage.qml`
- Modify: `qml/mobile/pages/MobileStatsPage.qml`
- Modify: `qml/mobile/components/MobileMonthlyStory.qml`
- Modify: `qml/CMakeLists.txt`
- Modify: `tests/mobile_ui_static_test.py`

**Interfaces:**
- Consumes: one `MobileShareStoryModel` with `kind`, `title`, `period`, `hero`, `facts`, `apps`, `backgroundSource`, and `anonymous`.
- Produces: one visible preview and one exported image from the same component tree.

- [ ] **Step 1: Add failing share structure checks**

Assert all three poster components exist; Home opens `kind: "app"`, Stats opens
`kind: "ranking"`, and monthly story opens `kind: "monthly"`.

- [ ] **Step 2: Run static test and verify RED**

Run:

```powershell
.local-python\Python312\python.exe tests/mobile_ui_static_test.py
```

Expected: missing poster and kind assertions fail.

- [ ] **Step 3: Implement poster variants**

Use current month scene for monthly share and user wallpaper for app/ranking
share. If no wallpaper exists, use the theme solid background. Show actual
application icons through `MobileAppIcon`; wait for Ready before export.

- [ ] **Step 4: Preserve privacy**

When `anonymous` is true:

```qml
displayName: qsTr("某个应用")
iconVisible: false
```

Never pass package names, raw window titles, device identifiers, or contacts
into `MobileShareStoryModel`.

- [ ] **Step 5: Connect all entry points**

- App card back: one-tap app poster.
- Week/month/year/all statistics detail: one-tap ranking poster.
- Monthly report page six: one-tap monthly poster.

The UI offers one recommended layout per share kind, not a style chooser.

- [ ] **Step 6: Build and manually test export**

Run:

```powershell
.local-python\Python312\python.exe tests/mobile_ui_static_test.py
.local-python\Python312\python.exe .harness/tools/build.py
.\build\TimeArc.exe --mobile-preview
```

Export each kind, verify the saved image matches preview, then run:

```powershell
.local-python\Python312\python.exe .harness/tools/scan_qt_log.py
```

Expected: no warnings, real icons have no abbreviation underneath, anonymous
mode removes app identity.

- [ ] **Step 7: Commit share posters**

```powershell
git add qml/mobile/components/share qml/mobile/components/MobileShareOverlay.qml qml/mobile/components/MobileFlipCard.qml qml/mobile/components/MobileMonthlyStory.qml qml/mobile/pages/MobileHomePage.qml qml/mobile/pages/MobileStatsPage.qml qml/CMakeLists.txt tests/mobile_ui_static_test.py
git commit -m "feat: add unified mobile story sharing"
```

---

### Task 7: Final Verification and Session Handoff

**Files:**
- Modify: `.harness/journal/sessions/20260723-0925-B-mobile-seasonal-report-qml.md`
- Modify only if behavior changed: `docs/superpowers/specs/2026-07-23-mobile-seasonal-report-qml-design.md`

**Interfaces:**
- Consumes: all completed tasks.
- Produces: verified build evidence and an accurate session record.

- [ ] **Step 1: Run all static and native tests**

```powershell
.local-python\Python312\python.exe tests/mobile_ui_static_test.py
.local-python\Python312\python.exe tests/android_usage_static_test.py
.local-python\Python312\python.exe .harness/tools/build.py
ctest --test-dir build --output-on-failure
```

Expected: every command exits zero.

- [ ] **Step 2: Run QML preview and scan logs**

```powershell
.\build\TimeArc.exe --mobile-preview
.local-python\Python312\python.exe .harness/tools/scan_qt_log.py
```

Inspect Home, Stats, Memory Lake, Settings, all twelve monthly themes, reduced
motion, light/dark wallpaper combinations, and all share outputs.

- [ ] **Step 3: Validate Android-specific source and package**

Build the configured Android target through the project-supported workflow if
the local Qt Android toolchain is available. Confirm usage permission, manual
sync, current/previous month totals, real labels/icons, observed-session copy,
and system share.

- [ ] **Step 4: Update the session record**

Replace `Pending implementation` with actual files, build log, test output,
runtime PID, Qt log scan, Android limitations, and any intentionally deferred
items.

- [ ] **Step 5: Run final harness check**

```powershell
.local-python\Python312\python.exe .harness/tools/harness_check.py
```

Expected: `harness_check.py: clean`.

- [ ] **Step 6: Commit verification record**

```powershell
git add .harness/journal/sessions/20260723-0925-B-mobile-seasonal-report-qml.md
git commit -m "docs: record seasonal mobile report verification"
```

