# Session: Site Icons And Video Title Adapters

## Goal

Continue website icon acquisition and mainstream video-site title adaptation so foreground and media usage can both show site identity, title-derived grouping, and local icons.

## Track

B Feature.

## Service side

The service contract stays unchanged. Windows foreground/audio sampling continues to emit `window_title` through JSONL/current and SQLite media title fields. No schema, C ABI, path, or storage frozen file is touched.

## UI side

The UI consumes existing title-like fields and maps them through an expanded site catalog. Aggregation output will include local `qrc:` icon sources when repo assets exist, favicon/cache status when implemented, and text fallback when no icon is available.

## Expected files

- `docs/superpowers/specs/2026-06-08-site-icons-and-video-title-adapters-design.md`
- `docs/superpowers/plans/2026-06-08-site-icons-and-video-title-adapters.md`
- `docs/mainland-site-tracking.md`
- `docs/site-icon-assets.md`
- `resources/icons/sites/*`
- `resources/CMakeLists.txt`
- `src/services/site_catalog.h`
- `src/services/usage_stat_manager.cpp`
- `qml/desktop/components/AppVisual.js`
- `qml/desktop/pages/DesktopHomePage.qml`
- `qml/desktop/pages/DesktopStatsPage.qml`
- `qml/desktop/memorylake/UsageRankList.qml`
- `tests/db_smoke.cpp`

## Rule files

- `.harness/rules/01-architecture.md`
- `.harness/rules/03-data-contract.md`
- `.harness/rules/04-ui-conventions.md`
- `.harness/rules/05-build-system.md`
- `.harness/rules/06-licensing.md`

## Do not touch

No service schema, `data_bridge.h`, `usage_paths.*`, top-level CMake, or service CMake changes.

## Plan

Write Superpowers design and implementation plan first, including explicit icon acquisition before catalog/code changes. Then implement task-by-task after plan review.

## Output

- Added site icon assets under `resources/icons/sites/`.
- Added `docs/site-icon-assets.md` with source URLs.
- Expanded `site_catalog.h` for mainstream video sites.
- Renamed the UI-side browser matcher to title semantics for foreground/audio title-like fields.
- Updated Home, Stats, and Memory Lake ranking to prefer backend `iconSource`, `iconLabel`, and `brandColor`.

## Verification

- `build.py -- --target timearc_db_smoke`: pass with CMake, MinGW bin on PATH.
- `build\timearc_db_smoke.exe`: pass with Qt and MinGW runtime on PATH.
- `build.py -- --target time-arc`: pass.

## Manual Smoke

Launch app, open Chrome/Edge to Bilibili, Xiaohongshu, iQIYI, YouTube, or Netflix. Let service record foreground/media titles, refresh Home/Stats, and verify the row groups as `site:*` with the site icon instead of the browser icon.
