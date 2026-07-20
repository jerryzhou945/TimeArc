# Mobile QML Visual Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the runnable mobile QML match the approved HTML prototype's full-wallpaper, transparent time-album layout while retaining real Android data and icon support.

**Architecture:** `MobileAppShell` continues to own one `PreserveAspectCrop` wallpaper. Shared theme tokens and thin presentation components provide the same transparent hierarchy to every persistent page; pages consume the existing `MobileUsageService` models and use clearly marked preview rows only when the desktop preview has no mobile records.

**Tech Stack:** Qt 6, QML/Qt Quick, existing C++ mobile services, Python static contract tests, Harness build and QML log scanner.

## Global Constraints

- Do not modify the service database, Android UsageStats collector, schema, or C ABI.
- Use runtime icon paths and `image://appicon/`; do not bundle third-party app icons.
- A wallpaper is instantiated once in `MobileAppShell` with `Image.PreserveAspectCrop`.
- Without a wallpaper, use theme solid color plus the same transparent hierarchy.
- Body text must remain readable in both light and dark modes.
- Keep one centered Home card with no stacked neighboring cards.
- Do not expose package names, window titles, contacts, URLs, or device identifiers.

---

### Task 1: Lock the visual contract

**Files:**
- Modify: `tests/mobile_ui_static_test.py`
- Test: `tests/mobile_ui_static_test.py`

**Interfaces:**
- Consumes: QML source files as UTF-8 text.
- Produces: assertions for shared wallpaper ownership, transparent tokens, timeline dates, preview fallback, and icon-led statistics.

- [ ] **Step 1: Write failing assertions**

Add assertions that require `contentClear`, `contentWash`, and `timelineLine`
tokens; verify all four pages receive `wallpaperActive`; require Statistics and
Memory Lake to use the shared timeline row and `MobileAppIcon`; require the
preview fallback to be gated by the absence of the runtime service.

- [ ] **Step 2: Verify RED**

Run:

```powershell
.\.local-python\Python312\python.exe tests\mobile_ui_static_test.py
```

Expected: FAIL because the new transparent/timeline contract is absent.

- [ ] **Step 3: Keep each assertion structural**

Assertions inspect component/property names and disallow page-owned wallpaper
`Image` instances. They must not depend on pixel screenshots or machine data.

### Task 2: Unify wallpaper, ink, and transparent layers

**Files:**
- Modify: `qml/mobile/MobileTheme.qml`
- Modify: `qml/mobile/MobileAppShell.qml`
- Modify: `qml/mobile/components/MobileGlassPanel.qml`

**Interfaces:**
- Produces: `contentClear`, `contentWash`, `contentStrong`, `timelineLine`,
  `wallpaperInk`, and `wallpaperMuted` theme properties.
- Consumes: `wallpaperActive`, `isDark`, and existing navigation state.

- [ ] **Step 1: Add adaptive transparent tokens**

Define near-clear page, wash, strong, separator, and wallpaper text tokens.
`panelColor(wallpaperActive, strong)` must use these tokens and avoid returning
an opaque surface while a wallpaper is active.

- [ ] **Step 2: Make the shell veil consistent**

Keep exactly one wallpaper `Image`; use the same light veil on all pages, with
only a small Home/non-Home opacity difference. Keep the bottom navigation
translucent and use a top hairline rather than a boxed border.

- [ ] **Step 3: Verify GREEN for theme assertions**

Run the static test and expect all theme/shell assertions to pass.

### Task 3: Align Home with the approved cover

**Files:**
- Modify: `qml/mobile/pages/MobileHomePage.qml`
- Modify: `qml/mobile/components/MobileFlipCard.qml`

**Interfaces:**
- Consumes: `totalDashboard`, real app model, `wallpaperActive`.
- Produces: one centered flip card, transparent three-fact strip, icon-led front, time encyclopedia back.

- [ ] **Step 1: Rebuild the top hierarchy**

Use a compact TimeArc toolbar followed by one transparent fact strip containing
only start date, cumulative duration, and recorded days. Use 16/13/11 pixel
type tiers and thin separators.

- [ ] **Step 2: Preserve one-card paging**

Keep `ListView.SnapOneItem`; ensure delegate width equals the centered content
width and no neighboring delegate overlaps or scales beneath the current card.

- [ ] **Step 3: Reduce card paint**

With a wallpaper, make the front base nearly clear, keep one subtle edge, and
use a lower text gradient only. Keep the real icon and factual back content.
Without a wallpaper, use a restrained translucent solid fallback.

- [ ] **Step 4: Run the static test**

Expected: Home layout and one-card contract PASS.

### Task 4: Convert Statistics to an icon-led time stream

**Files:**
- Modify: `qml/mobile/pages/MobileStatsPage.qml`
- Modify: `qml/mobile/components/MobileUsageRankRow.qml`

**Interfaces:**
- Consumes: `getDashboardForRange("week"|"month"|"year"|"all")`.
- Produces: four range entries and range-detail rankings with icon, friendly name, duration, and relative progress.

- [ ] **Step 1: Add preview-only fallback data**

When `mobileUsageService` is unavailable in desktop preview, expose common
friendly sample apps and explicit sample durations. When the service exists,
always render its returned model, including an honest empty state.

- [ ] **Step 2: Use Memory Lake row grammar**

Each range begins with a compact date/range marker, then a narrative title,
supporting fact, real/fallback app icon, total duration, and a separator.
Remove repeated opaque range cards.

- [ ] **Step 3: Flatten detail rankings**

Rows use no card background. Keep icon, name, duration, supporting percentage,
and a clear horizontal progress line whose width uses `relativePct`.

- [ ] **Step 4: Run the static test**

Expected: Statistics timeline, icon, period, and progress assertions PASS.

### Task 5: Align Memory Lake and Settings

**Files:**
- Modify: `qml/mobile/pages/MobileHistoryPage.qml`
- Modify: `qml/mobile/pages/MobileSettingsPage.qml`

**Interfaces:**
- Consumes: current monthly report, moments, settings repository, wallpaper service.
- Produces: transparent dated moment stream, transparent month archive, and wallpaper-visible settings groups.

- [ ] **Step 1: Refine Memory Lake dates**

Use a 48-pixel date rail with day and Chinese month label; keep title, story,
icons, and separator on the wallpaper with no dark row rectangle.

- [ ] **Step 2: Flatten report archive**

Keep the original Canvas report cover, but present archive months as transparent
timeline rows with month code, total time, record days, and a chevron.

- [ ] **Step 3: Make settings groups translucent**

Settings grouping surfaces use the same shared panel tokens. No page-sized
opaque rectangle may cover the wallpaper.

- [ ] **Step 4: Run the static test**

Expected: all QML visual contract assertions PASS.

### Task 6: Build and visual verification

**Files:**
- Update: `.harness/journal/sessions/20260720-1102-B-mobile-qml-visual-parity.md`

**Interfaces:**
- Consumes: built `TimeArc.exe`.
- Produces: verified 390×844 preview and clean QML log scan.

- [ ] **Step 1: Build through Harness**

```powershell
.\.local-python\Python312\python.exe .harness\tools\build.py
```

Expected: `build.py: success`.

- [ ] **Step 2: Run automated tests**

```powershell
ctest --test-dir build --output-on-failure
.\.local-python\Python312\python.exe tests\mobile_ui_static_test.py
.\.local-python\Python312\python.exe tests\android_usage_static_test.py
```

Expected: all tests PASS.

- [ ] **Step 3: Launch the visible preview**

Start `build\TimeArc.exe --mobile-preview`, inspect Home, Statistics, Memory
Lake, Settings, wallpaper/light/dark combinations, card flip, and range detail.

- [ ] **Step 4: Scan QML logs**

```powershell
.\.local-python\Python312\python.exe .harness\tools\scan_qt_log.py --track B
```

Expected: no new QML warnings or runtime errors.

- [ ] **Step 5: Run the commit gate**

```powershell
.\.local-python\Python312\python.exe .harness\tools\harness_check.py
```

Expected: `harness_check.py: clean`.
