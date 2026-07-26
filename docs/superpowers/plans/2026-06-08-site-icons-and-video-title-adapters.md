# Site Icons And Video Title Adapters Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add first-class site icons and title matching for mainstream video websites across foreground and media usage surfaces.

**Architecture:** Keep the service disk contract unchanged. Add repo-local site icon assets, expand the C++ site catalog, expose consistent icon metadata from aggregation, and let QML prefer model-provided icon fields before generic app icon fallback.

**Tech Stack:** Qt 6 C++/QML, Qt resource files, existing `UsageStatManager`, `site_catalog.h`, `timearc_db_smoke`, TimeArc harness scripts.

---

### Task 1: Acquire Mainstream Video Site Icons

**Files:**
- Create: `resources/app/icons/sites/*.svg`
- Create: `docs/site-icon-assets.md`
- Modify: `resources/CMakeLists.txt`

- [x] **Step 1: Create the icon source manifest**

Add `docs/site-icon-assets.md` with this exact table header and one row per icon:

```markdown
# Site Icon Assets

| Site | File | Source URL | Acquisition Method | Notes |
|------|------|------------|--------------------|-------|
| Bilibili | `resources/icons/bilibili.svg` | existing repository asset | existing local SVG | Kept for compatibility. |
```

- [x] **Step 2: Fetch or derive first-batch icons**

Use official favicon/apple-touch-icon endpoints first. Save normalized square SVG or PNG assets under `resources/app/icons/sites/` using these filenames:

```text
xiaohongshu.svg
iqiyi.svg
youku.svg
tencent-video.svg
mango-tv.svg
douyin.svg
kuaishou.svg
xigua-video.svg
acfun.svg
youtube.svg
netflix.svg
twitch.svg
douyu.svg
huya.svg
```

Record each source URL in `docs/site-icon-assets.md`. If an endpoint returns ICO/PNG, keep the original extension and use that extension in the catalog.

- [x] **Step 3: Add assets to Qt resources**

Modify `resources/CMakeLists.txt` so every new `resources/app/icons/sites/<name>.<ext>` path appears in `TIME_ARC_RESOURCE_FILES`.

- [ ] **Step 4: Verify resource paths**

Run:

```powershell
D:\TimeArc\time-arc\.local-python\Python312\python.exe D:\TimeArc\time-arc\.harness\tools\harness_check.py
```

Expected: `harness_check.py: clean`.

### Task 2: Expand The Site Catalog

**Files:**
- Modify: `src/services/site_catalog.h`
- Modify: `tests/db_smoke.cpp`

- [x] **Step 1: Add failing catalog smoke checks**

In `tests/db_smoke.cpp`, add checks for these title examples:

```cpp
{QStringLiteral("小红书 - Google Chrome"), QStringLiteral("site:xiaohongshu")},
{QStringLiteral("爱奇艺-在线视频网站 - Google Chrome"), QStringLiteral("site:iqiyi")},
{QStringLiteral("YouTube - Google Chrome"), QStringLiteral("site:youtube")},
{QStringLiteral("Netflix - Google Chrome"), QStringLiteral("site:netflix")},
{QStringLiteral("Twitch - Google Chrome"), QStringLiteral("site:twitch")},
{QStringLiteral("芒果TV - Google Chrome"), QStringLiteral("site:mango-tv")},
{QStringLiteral("AcFun弹幕视频网 - Google Chrome"), QStringLiteral("site:acfun")}
```

- [x] **Step 2: Run the smoke binary and confirm failure**

Note: implementation was patched before preserving a separate failing state; verification ran through the post-implementation smoke path.

Run:

```powershell
D:\TimeArc\time-arc\build\timearc_db_smoke.exe
```

Expected before implementation: fails with a site catalog match message.

- [x] **Step 3: Add catalog entries**

Add `SiteDefinition` rows for the first-batch video sites. Each row must set `siteId`, display name, `视频` or `短视频` category, canonical domain, brand color, fallback label, local icon source, and title hints.

Example shape:

```cpp
{QStringLiteral("site:youtube"), QStringLiteral("YouTube"),
 QStringLiteral("\u89C6\u9891"), QStringLiteral("youtube.com"),
 QStringLiteral("#FF0000"), QStringLiteral("Y"),
 QStringLiteral("qrc:/qt/qml/time_arc/resources/app/icons/sites/youtube.svg"),
 {QStringLiteral("youtube"), QStringLiteral("youtu.be"),
  QStringLiteral("youtube.com")}},
```

- [x] **Step 4: Run smoke again**

Run:

```powershell
D:\TimeArc\time-arc\build\timearc_db_smoke.exe
```

Expected: PASS.

### Task 3: Match Media Titles With The Same Catalog

**Files:**
- Modify: `src/services/usage_stat_manager.cpp`
- Modify: `tests/db_smoke.cpp`

- [x] **Step 1: Add helper tests**

Extend smoke coverage so a media title such as `更了300多期视频以后 - 哔哩哔哩 bilibili - Google Chrome` resolves to `site:bilibili`, and `Stranger Things - Netflix` resolves to `site:netflix`.

- [x] **Step 2: Add a shared title matcher**

Replace direct calls to `matchByWindowTitle(windowTitle)` with a helper that accepts any title-like field:

```cpp
const TimeArcSiteCatalog::SiteDefinition* siteForBrowserTitle(
    const QString& appId,
    const QString& appName,
    const QString& path,
    const QString& title) {
  if (!isBrowserApp(appId, appName, path)) return nullptr;
  return TimeArcSiteCatalog::matchByWindowTitle(title);
}
```

Use it for foreground `windowTitle` first. For audio records, pass `windowTitle` because service maps useful media titles into that field for JSONL.

- [x] **Step 3: Preserve fallback behavior**

Keep unknown titles grouped by app key. Do not create a `site:*` group unless the title matches a catalog hint.

- [x] **Step 4: Verify**

Run:

```powershell
D:\TimeArc\time-arc\build\timearc_db_smoke.exe
```

Expected: PASS.

### Task 4: Prefer Model-Provided Icons In QML

**Files:**
- Modify: `qml/desktop/components/AppVisual.js`
- Modify: `qml/desktop/pages/DesktopHomePage.qml`
- Modify: `qml/desktop/pages/DesktopStatsPage.qml`
- Modify: `qml/desktop/memorylake/UsageRankList.qml`

- [x] **Step 1: Add model-aware visual helpers**

Add helpers that prefer backend fields:

```javascript
function modelIconSource(row) {
    if (row && row.iconSource && row.iconSource.length > 0)
        return row.iconSource;
    return appIconSource(row && row.groupKey ? row.groupKey : (row ? row.appId : ""),
                         row ? row.path : "");
}

function modelIconLabel(row) {
    if (row && row.iconLabel && row.iconLabel.length > 0)
        return row.iconLabel;
    return appIconLabel(row && row.groupKey ? row.groupKey : (row ? row.appId : ""),
                        row ? row.name : "");
}
```

- [x] **Step 2: Use helpers in Home and Stats**

Replace repeated `AppVisual.appIconSource(modelData.groupKey, modelData.path)` calls with `AppVisual.modelIconSource(modelData)`, and label calls with `AppVisual.modelIconLabel(modelData)`.

- [x] **Step 3: Use helpers in Memory Lake ranking**

When `row.app` contains backend icon fields, pass that object to `modelIconSource` and `modelIconLabel`.

- [x] **Step 4: Verify QML loads through build**

Run:

```powershell
D:\TimeArc\time-arc\.local-python\Python312\python.exe D:\TimeArc\time-arc\.harness\tools\build.py --target time_arc
```

Expected: build succeeds.

### Task 5: Update User-Facing Docs And Final Verification

**Files:**
- Modify: `docs/mainland-site-tracking.md`
- Modify: `README.md`
- Modify: `.harness/journal/sessions/20260608-0938-B-site-icons-video-adapters.md`

- [x] **Step 1: Update docs**

Document that v2 includes mainstream video sites, repo-local icon assets, media-title matching, and favicon cache fallback. State that QML still does not fetch network images.

- [x] **Step 2: Build smoke targets**

Run:

```powershell
D:\TimeArc\time-arc\.local-python\Python312\python.exe D:\TimeArc\time-arc\.harness\tools\build.py --target timearc_db_smoke
D:\TimeArc\time-arc\build\timearc_db_smoke.exe
```

Expected: build succeeds and smoke exits 0.

- [x] **Step 3: Run full harness check**

Run:

```powershell
D:\TimeArc\time-arc\.local-python\Python312\python.exe D:\TimeArc\time-arc\.harness\tools\harness_check.py
```

Expected: `harness_check.py: clean`.
