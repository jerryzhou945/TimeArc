# TimeArc Mobile QML Time Album Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the approved four-tab TimeArc mobile UI in QML with calendar-correct Android usage summaries, one global wallpaper, a non-stacked flip-card carousel, period rankings, Memory Lake stories, and privacy-safe image sharing.

**Architecture:** Keep collectors and the service-owned SQLite contract unchanged. Extend `MobileUsageService` for presentation-safe aggregation, add one UI-private `MobileUiService` for wallpaper/share files and Android intents, and compose persistent QML pages over one shell-owned wallpaper layer.

**Tech Stack:** Qt 6.8, C++17/QObject, Qt Quick/QML, Android Java 17/JNI, AndroidX FileProvider, SQLite-backed repositories, Python static checks, existing C++ database smoke test.

## Global Constraints

- Background collectors, `timearc_service.db`, `data_bridge.h`, database paths, and service write ownership must not change.
- Home renders one complete centered card only; adjacent cards never overlap or show duplicate transparent layers.
- Wallpaper is copied to app-private storage, rendered once by `MobileAppShell`, and uses `Image.PreserveAspectCrop` without pre-upscaling.
- Statistics exposes exactly four entry ranges: week, month, year, all.
- App labels prefer the Android label; common package fallback names are Chinese consumer names; raw package names stay off primary UI.
- App icons prefer `appIconPath`; a deterministic initial tile is the final fallback.
- Share output never contains package names, raw window titles, contacts, URLs, or device identifiers.
- Monthly artwork is QML/Canvas generated and contains no third-party photographs.
- Every touch target is at least 44×44 QML pixels and light/dark text targets WCAG 2.2 AA.
- No new third-party dependency is introduced.

---

## File Map

**Data and platform**

- Modify `src/services/mobile/mobile_usage_service.{h,cpp}` — calendar ranges, friendly names, per-app evidence and Memory Lake model.
- Create `src/services/mobile/mobile_ui_service.{h,cpp}` — wallpaper import/state, share paths and Android handoff.
- Modify `src/main.cpp` — construct and expose `mobileUiService`.
- Modify frozen `src/CMakeLists.txt` — register the two new C++ source files.
- Create `android/src/main/java/com/timearc/mobile/ui/MobileUiBridge.java` — content-URI copy and FileProvider share intent.

**QML**

- Modify `qml/mobile/MobileTheme.qml` and `qml/mobile/MobileAppShell.qml` — tokens, global wallpaper and persistent pages.
- Create `qml/mobile/components/MobileGlassPanel.qml`.
- Create `qml/mobile/components/MobileAppIcon.qml`.
- Create `qml/mobile/components/MobileUsageRankRow.qml`.
- Rewrite `qml/mobile/components/MobileFlipCard.qml`.
- Create `qml/mobile/components/MobileShareOverlay.qml`.
- Create `qml/mobile/components/MobileMonthlyStory.qml`.
- Rewrite all four files under `qml/mobile/pages/`.
- Modify `qml/CMakeLists.txt` — register new QML files.

**Tests and documentation**

- Modify `tests/db_smoke.cpp`.
- Create `tests/mobile_ui_static_test.py`.
- Create `.harness/journal/sessions/20260719-0315-B-mobile-ui-service-cmake.md` before touching frozen CMake.
- Update `README.md`, `docs/implementation-backlog.md`, `.harness/state/open-issues.md`.
- Create `docs/mobile-qml-time-album-implementation-report.md`.

---

### Task 1: Protect the frozen build manifest and add failing contracts

**Files:**

- Create: `.harness/journal/sessions/20260719-0315-B-mobile-ui-service-cmake.md`
- Modify: `tests/db_smoke.cpp`
- Create: `tests/mobile_ui_static_test.py`

**Interfaces:**

- Consumes: existing `MobileUsageService`, mobile QML file layout, Android manifest/provider.
- Produces: executable assertions for new C++ fields and static assertions for all new UI/platform seams.

- [ ] **Step 1: File the frozen-file change proposal**

Write a completed proposal naming only `src/CMakeLists.txt`. State that the
producer process is unaffected, the UI target gains `mobile_ui_service.cpp`,
there is no on-disk migration, rollback is a code revert, and verification is
the database smoke test plus mobile preview.

- [ ] **Step 2: Add failing deterministic range and evidence checks**

Add the following checks after the existing `MobileUsageService` dashboard
assertions in `tests/db_smoke.cpp`:

```cpp
if (MobileUsageService::startDateForRange(
        QStringLiteral("week"), QDate(2026, 7, 19)) != QDate(2026, 7, 13) ||
    MobileUsageService::startDateForRange(
        QStringLiteral("month"), QDate(2026, 7, 19)) != QDate(2026, 7, 1) ||
    MobileUsageService::startDateForRange(
        QStringLiteral("year"), QDate(2026, 7, 19)) != QDate(2026, 1, 1)) {
  return fail(QStringLiteral("Mobile calendar range semantics failed."));
}
if (MobileUsageService::friendlyDisplayName(
        QStringLiteral("com.xingin.xhs"), QString()) !=
        QStringLiteral("小红书") ||
    MobileUsageService::friendlyDisplayName(
        QStringLiteral("com.tencent.mm"), QStringLiteral("微信")) !=
        QStringLiteral("微信")) {
  return fail(QStringLiteral("Mobile friendly app naming failed."));
}
const QVariantMap spotifyEvidence = multiDayApps.at(1).toMap();
if (spotifyEvidence.value(QStringLiteral("firstDateLocal")).toString() !=
        QStringLiteral("2026-06-29") ||
    spotifyEvidence.value(QStringLiteral("recordedDays")).toInt() != 2 ||
    spotifyEvidence.value(QStringLiteral("spanDays")).toInt() != 2 ||
    spotifyEvidence.value(QStringLiteral("relativePct")).toInt() <= 0) {
  return fail(QStringLiteral("Mobile app evidence aggregation failed."));
}
```

- [ ] **Step 3: Add a failing mobile UI static check**

Create `tests/mobile_ui_static_test.py` with `read()` and `require()` helpers
matching `tests/android_usage_static_test.py`, then assert:

```python
require(read("src/main.cpp"), '"mobileUiService"', "QML mobile UI service")
require(read("src/services/mobile/mobile_ui_service.h"),
        "Q_PROPERTY(QString wallpaperUrl", "wallpaper property")
require(read("src/services/mobile/mobile_ui_service.h"),
        "Q_INVOKABLE bool importWallpaper", "wallpaper import")
require(read("src/services/mobile/mobile_ui_service.h"),
        "Q_INVOKABLE bool shareImage", "share handoff")
require(read("android/src/main/java/com/timearc/mobile/ui/MobileUiBridge.java"),
        "FileProvider.getUriForFile", "Android FileProvider share")
require(read("qml/mobile/MobileAppShell.qml"),
        "Image.PreserveAspectCrop", "single shell wallpaper crop")
require(read("qml/mobile/pages/MobileStatsPage.qml"),
        '["week", "month", "year", "all"]', "four statistics ranges")
require(read("qml/mobile/components/MobileAppIcon.qml"),
        "appIconPath", "real app icon")
require(read("qml/mobile/components/MobileShareOverlay.qml"),
        "grabToImage", "shared preview/export component")
```

- [ ] **Step 4: Run the checks and verify RED**

Run:

```powershell
.\.local-python\Python312\python.exe tests\mobile_ui_static_test.py
python .harness/tools/build.py
```

Expected: the static check fails because `mobile_ui_service.h` does not exist;
the database smoke build fails because the new public service methods/fields
are not implemented. Record both expected failures according to the Harness.

- [ ] **Step 5: Commit the tests and proposal**

```powershell
git add -- tests/db_smoke.cpp tests/mobile_ui_static_test.py .harness/journal/sessions/20260719-0315-B-mobile-ui-service-cmake.md
git commit -m "Add mobile time album contracts"
```

---

### Task 2: Make Android usage models calendar-correct and presentation-safe

**Files:**

- Modify: `src/services/mobile/mobile_usage_service.h`
- Modify: `src/services/mobile/mobile_usage_service.cpp`
- Test: `tests/db_smoke.cpp`

**Interfaces:**

- Produces:
  - `static QDate startDateForRange(const QString&, const QDate&)`
  - `static QString friendlyDisplayName(const QString&, const QString&)`
  - `QVariantMap getDashboardForRange(const QString&)`
  - `QVariantMap getMemoryLakeForCurrentMonth()`
  - app fields `firstDateLocal`, `recordedDays`, `spanDays`, `relativePct`,
    `storyText`, `conversionText`.

- [ ] **Step 1: Expose deterministic helpers and the Memory Lake model**

Move `startDateForRange` to the public section with `QDate` return type, add
`friendlyDisplayName`, and declare:

```cpp
Q_INVOKABLE QVariantMap getMemoryLakeForCurrentMonth();
static QDate startDateForRange(const QString& range, const QDate& today);
static QString friendlyDisplayName(const QString& packageName,
                                   const QString& currentLabel);
```

- [ ] **Step 2: Implement calendar ranges and common app names**

Use Monday-based weeks, first-of-month, first-of-year and `1970-01-01` for
all-time. Add exact fallback mappings for WeChat, QQ, Xiaohongshu, Bilibili,
NetEase Cloud Music, Douyin, Chrome, Edge, Spotify, YouTube and VS Code package
identifiers. Return a non-package current label unchanged.

- [ ] **Step 3: Aggregate truthful per-app evidence**

While iterating daily rows, maintain a `QSet<QString>` of dates per app and the
lexicographically earliest ISO date. After sorting, add:

```cpp
row.insert(QStringLiteral("firstDateLocal"), firstDate);
row.insert(QStringLiteral("recordedDays"), dates.size());
row.insert(QStringLiteral("spanDays"),
           QDate::fromString(firstDate, Qt::ISODate).daysTo(endDate) + 1);
row.insert(QStringLiteral("relativePct"),
           leaderSec > 0 ? qRound(seconds * 100.0 / leaderSec) : 0);
```

Generate `storyText` only from duration, rank and recorded days. Generate
`conversionText` with a four-minute-song duration conversion prefixed by
`若换算为每首 4 分钟`.

- [ ] **Step 4: Build the current-month Memory Lake model**

Return a map containing `report`, `moments`, and `topApps`. The report includes
calendar month label, date range, total duration, active days, app count and a
data-grounded summary. `moments` contains at most five entries derived from
the top apps and their recorded-day evidence.

- [ ] **Step 5: Run GREEN verification**

Run:

```powershell
python .harness/tools/build.py
ctest --test-dir build --output-on-failure
```

Expected: build succeeds and `timearc_db_smoke` passes the new calendar,
friendly-name and evidence assertions.

- [ ] **Step 6: Commit**

```powershell
git add -- src/services/mobile/mobile_usage_service.h src/services/mobile/mobile_usage_service.cpp tests/db_smoke.cpp
git commit -m "Extend mobile usage presentation facts"
```

---

### Task 3: Add reliable wallpaper storage and Android image sharing

**Files:**

- Create: `src/services/mobile/mobile_ui_service.h`
- Create: `src/services/mobile/mobile_ui_service.cpp`
- Create: `android/src/main/java/com/timearc/mobile/ui/MobileUiBridge.java`
- Modify: `src/CMakeLists.txt`
- Modify: `src/main.cpp`
- Test: `tests/mobile_ui_static_test.py`

**Interfaces:**

- `MobileUiService(SettingsRepository*, QObject*)`
- Properties: `wallpaperUrl`, `lastError`, `lastSavedImagePath`.
- Invokables: `importWallpaper(QUrl)`, `clearWallpaper()`,
  `createShareImagePath(QString)`, `shareImage(QUrl, QString)`.

- [ ] **Step 1: Add the focused QObject**

Implement app-private directories under `QStandardPaths::AppDataLocation`:
`mobile/wallpaper` and `mobile/share`. Import into a temporary file, verify it
is non-empty, then atomically replace the saved wallpaper and persist
`mobile_wallpaper_path` through `SettingsRepository`. Failed imports keep the
old path and set a Chinese `lastError`.

- [ ] **Step 2: Handle Android content URIs and sharing**

Create `MobileUiBridge` with:

```java
public static boolean copyUriToFile(Context context, String uri, String path)
public static boolean shareImage(Context context, String path, String title)
```

`copyUriToFile` streams from `ContentResolver.openInputStream` to the requested
private file. `shareImage` uses
`FileProvider.getUriForFile(context, context.getPackageName() + ".qtprovider", file)`,
`Intent.ACTION_SEND`, `image/png`, and
`Intent.FLAG_GRANT_READ_URI_PERMISSION`.

- [ ] **Step 3: Register the service**

Add the new `.h/.cpp` only to `TIME_ARC_APP_SOURCES` in frozen
`src/CMakeLists.txt`. Construct it with `SettingsRepository` in `src/main.cpp`
and expose it as the `mobileUiService` context property.

- [ ] **Step 4: Run the static check**

Run:

```powershell
.\.local-python\Python312\python.exe tests\mobile_ui_static_test.py
```

Expected: it now advances past the C++/Java assertions and fails at the first
missing QML component.

- [ ] **Step 5: Build**

Run `python .harness/tools/build.py`.

Expected: Windows desktop/mobile-preview build succeeds; Android-only JNI
branches remain gated by `Q_OS_ANDROID`.

- [ ] **Step 6: Commit**

```powershell
git add -- src/CMakeLists.txt src/main.cpp src/services/mobile/mobile_ui_service.h src/services/mobile/mobile_ui_service.cpp android/src/main/java/com/timearc/mobile/ui/MobileUiBridge.java
git commit -m "Add mobile wallpaper and share service"
```

---

### Task 4: Build the persistent wallpaper shell and shared visual vocabulary

**Files:**

- Modify: `qml/mobile/MobileTheme.qml`
- Modify: `qml/mobile/MobileAppShell.qml`
- Modify: `qml/mobile/components/MobileTabButton.qml`
- Create: `qml/mobile/components/MobileGlassPanel.qml`
- Create: `qml/mobile/components/MobileAppIcon.qml`
- Create: `qml/mobile/components/MobileUsageRankRow.qml`
- Modify: `qml/CMakeLists.txt`

**Interfaces:**

- `MobileAppIcon`: `app`, `size`, `radius`, `theme`.
- `MobileUsageRankRow`: `app`, `rank`, `theme`, `showSharePct`.
- `MobileGlassPanel`: `theme`, `wallpaperActive`, `lightOpacity`, `darkOpacity`.
- Pages receive `theme`, `wallpaperActive`; Settings also receives wallpaper actions.

- [ ] **Step 1: Expand theme tokens**

Add wallpaper veils, glass fills, memory-brown colors, progress track/fill,
44px control height, 16px card radius, motion durations and a
`surface(wallpaperActive, emphasis)` helper. Retain full light/dark parity.

- [ ] **Step 2: Make the shell own one wallpaper**

Replace the page `Loader` with four persistent page items whose `visible`
state follows `currentTab`. Place one `Image` below them:

```qml
Image {
    anchors.fill: parent
    source: mobileUiService ? mobileUiService.wallpaperUrl : ""
    fillMode: Image.PreserveAspectCrop
    visible: source.toString().length > 0
    asynchronous: true
    cache: false
}
```

Pages remain transparent over the wallpaper; the shell provides a solid
theme background below the image.

- [ ] **Step 3: Implement shared app icon and ranking row**

`MobileAppIcon` first loads `app.appIconPath`, then shows a theme-aware initial
tile. `MobileUsageRankRow` presents icon, friendly `displayName`,
`durationText`, optional `sharePct`, and a bar whose width is
`relativePct / 100`.

- [ ] **Step 4: Register new QML files and run static GREEN**

Update `qml/CMakeLists.txt`, run:

```powershell
.\.local-python\Python312\python.exe tests\mobile_ui_static_test.py
.\.local-python\Python312\python.exe tests\android_usage_static_test.py
```

Expected: both scripts pass.

- [ ] **Step 5: Commit**

```powershell
git add -- qml/mobile/MobileTheme.qml qml/mobile/MobileAppShell.qml qml/mobile/components/MobileTabButton.qml qml/mobile/components/MobileGlassPanel.qml qml/mobile/components/MobileAppIcon.qml qml/mobile/components/MobileUsageRankRow.qml qml/CMakeLists.txt tests/mobile_ui_static_test.py
git commit -m "Build mobile wallpaper shell"
```

---

### Task 5: Implement the single-card Home and unified share preview

**Files:**

- Rewrite: `qml/mobile/components/MobileFlipCard.qml`
- Create: `qml/mobile/components/MobileShareOverlay.qml`
- Rewrite: `qml/mobile/pages/MobileHomePage.qml`
- Modify: `qml/CMakeLists.txt`

**Interfaces:**

- `MobileFlipCard`: `theme`, `app`, `wallpaperActive`, `selected`,
  `flipped`; signals `shareRequested(var app)` and `permissionRequested()`.
- `MobileShareOverlay`: `theme`, `app`, `dateRange`, `anonymous`,
  `opened`; method `openFor(app, range)`.

- [ ] **Step 1: Rewrite the card**

The front has one icon, app name, duration, share percentage, story and one
progress bar. With wallpaper, the main face is almost clear and only the copy
zone uses a vertical readability gradient. The warm-brown back shows first
date, recorded days, span days, cumulative duration and conversion copy.
Use a 240ms Y-axis rotation and disable the rotation when reduced motion is
enabled.

- [ ] **Step 2: Replace Home with a non-stacked snap carousel**

Use a horizontal `ListView` with delegate width equal to the viewport minus
40px, `spacing: 40`, `snapMode: ListView.SnapOneItem`, and clipping enabled.
No transform, negative spacing, `z` stacking or visible neighbor content is
allowed. Preserve `currentIndex` and per-app flip state.

- [ ] **Step 3: Add the archive fact strip**

Show only start date, cumulative recorded time and recorded usage days from
the all-time dashboard. Remove avatar, profile badge, rank and shortcut rows.

- [ ] **Step 4: Implement one share component**

Build a 1080:1920-ratio preview item containing app icon/name, main duration,
date range, story, two facts and conversion. Anonymous mode replaces app
identity with “一段被记住的时间”. Use:

```qml
poster.grabToImage(function(result) {
    const path = mobileUiService.createShareImagePath(app.displayName)
    if (result.saveToFile(path))
        mobileUiService.shareImage(path, "分享时间纪念卡")
})
```

Keep the overlay open and expose an inline retry error if save/share fails.

- [ ] **Step 5: Build and smoke Home**

Run `python .harness/tools/build.py`, launch with `--mobile-preview`, verify
390×844 in light/dark and wallpaper/no-wallpaper states, then run
`python .harness/tools/scan_qt_log.py`.

- [ ] **Step 6: Commit**

```powershell
git add -- qml/mobile/components/MobileFlipCard.qml qml/mobile/components/MobileShareOverlay.qml qml/mobile/pages/MobileHomePage.qml qml/CMakeLists.txt
git commit -m "Implement mobile memory cards and sharing"
```

---

### Task 6: Implement the four-entry statistics experience

**Files:**

- Rewrite: `qml/mobile/pages/MobileStatsPage.qml`
- Reuse: `qml/mobile/components/MobileUsageRankRow.qml`

**Interfaces:**

- Range keys are exactly `["week", "month", "year", "all"]`.
- Page state: `detailOpen`, `selectedRange`, `dashboards`.
- Functions: `loadOverview()`, `openRange(key)`, `closeRange()`.

- [ ] **Step 1: Build the range overview**

Render four tappable functional sections for 本周、本月、今年、总计. Each
shows total time, active days, date range and the leading app icon/name.
Use varied editorial rows rather than four identical bordered metric cards.

- [ ] **Step 2: Build range detail**

On tap, replace the overview content with a header/back action and a
`MobileUsageRankRow` list. Every row shows a real icon, friendly name, exact
duration and leader-relative progress. Keep the actual `sharePct` as text.

- [ ] **Step 3: Add empty/loading states**

Keep the four entries visible with “暂无记录”; the detail page explains how to
enable access or sync without exposing implementation names.

- [ ] **Step 4: Build and validate all ranges**

Run build, open each period in mobile preview, verify back navigation and
state preservation, then scan the Qt log.

- [ ] **Step 5: Commit**

```powershell
git add -- qml/mobile/pages/MobileStatsPage.qml
git commit -m "Implement mobile period statistics"
```

---

### Task 7: Implement Memory Lake, monthly story, and mobile settings

**Files:**

- Create: `qml/mobile/components/MobileMonthlyStory.qml`
- Rewrite: `qml/mobile/pages/MobileHistoryPage.qml`
- Rewrite: `qml/mobile/pages/MobileSettingsPage.qml`
- Modify: `qml/CMakeLists.txt`

**Interfaces:**

- `MobileMonthlyStory`: `theme`, `model`, `opened`, `currentPage`; signals
  `closed()` and `shareRequested(var report)`.
- History consumes `mobileUsageService.getMemoryLakeForCurrentMonth()`.
- Settings invokes `mobileUiService.importWallpaper`,
  `mobileUiService.clearWallpaper`, and existing access/sync APIs.

- [ ] **Step 1: Build original seasonal artwork**

Use QML `Canvas` and simple Qt Quick shapes for four calendar-season palettes.
Draw abstract leaves/rain/light/snow; do not load an image source. The report
cover includes month, active days, total duration, lead app and one story.

- [ ] **Step 2: Build “最近被记住”**

Render three to five flat timeline entries from the `moments` model. Each has
a date/range label, one poetic evidence sentence, duration/recorded-day copy,
and up to two real app icons.

- [ ] **Step 3: Build the five-page monthly story**

Pages are cover, overview, leading apps, time distribution and share. Use
manual next/previous taps, visible progress segments and a persistent close
button. No autoplay.

- [ ] **Step 4: Finish mobile settings**

Add real access state, immediate sync, auto-sync, light/dark, local wallpaper
choose/reset, default anonymous sharing and privacy copy. Use
`QtQuick.Dialogs.FileDialog` for desktop preview and Android document picker;
pass the selected URL to `MobileUiService`. Persist toggles with
`SettingsRepository`.

- [ ] **Step 5: Build and runtime-test**

Run build; verify original report art, story navigation, wallpaper import and
reset across all tabs, theme parity, permission action and sync feedback;
scan the Qt log.

- [ ] **Step 6: Commit**

```powershell
git add -- qml/mobile/components/MobileMonthlyStory.qml qml/mobile/pages/MobileHistoryPage.qml qml/mobile/pages/MobileSettingsPage.qml qml/CMakeLists.txt
git commit -m "Complete mobile Memory Lake and settings"
```

---

### Task 8: Harden, document, and verify the complete feature

**Files:**

- Modify: `README.md`
- Modify: `docs/implementation-backlog.md`
- Modify: `.harness/state/open-issues.md`
- Create: `docs/mobile-qml-time-album-implementation-report.md`
- Modify: `.harness/journal/sessions/20260719-0231-B-mobile-qml-ui.md`

**Interfaces:**

- Produces a reviewable feature branch with a Chinese completion report and
  reproducible verification evidence.

- [ ] **Step 1: Run static and C++ verification**

```powershell
.\.local-python\Python312\python.exe tests\mobile_ui_static_test.py
.\.local-python\Python312\python.exe tests\android_usage_static_test.py
python .harness/tools/build.py
ctest --test-dir build --output-on-failure
```

Expected: all commands pass.

- [ ] **Step 2: Run mobile preview QA**

Launch the built app with `--mobile-preview` at 390×844. Exercise all four
tabs, every statistics period, Home swipe/flip/share, report pages, theme
toggle, wallpaper import/reset, permission/sync empty states, then run:

```powershell
.\.local-python\Python312\python.exe .harness/tools/scan_qt_log.py
```

Expected: no new QML warning or critical report.

- [ ] **Step 3: Run Android verification**

Build the existing Android arm64 configuration through the project build
wrapper or documented Android command, install on a device/emulator, grant
Usage Access, sync, confirm real app labels/icons, import a gallery image,
restart, and share a PNG through the system chooser.

- [ ] **Step 4: Update docs**

Document goal, changed files, verification, known gaps and rollback in the
Chinese report. Mark “mobile Memory Lake equivalent” complete, retain any
device-specific sharing limitation as a scoped open issue, and update README
mobile capabilities.

- [ ] **Step 5: Close the session and run the final gate**

Set the session outcome to `done`, list commits and the manual smoke path, then:

```powershell
.\.local-python\Python312\python.exe .harness/tools/harness_check.py
git status --short
git diff --check
```

Expected: Harness clean, no whitespace errors, and only intended branch files.

- [ ] **Step 6: Commit documentation**

```powershell
git add -- README.md docs/implementation-backlog.md docs/mobile-qml-time-album-implementation-report.md .harness/state/open-issues.md .harness/journal/sessions/20260719-0231-B-mobile-qml-ui.md
git commit -m "Document mobile QML time album"
```

