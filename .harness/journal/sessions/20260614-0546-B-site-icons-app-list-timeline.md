# Session Log - site-icons-app-list-timeline

## Metadata

- Agent / Author: Codex
- Track: **B (Feature)**
- Date: 2026-06-14 05:46 -> in progress (local)
- Branch: codex/site-icons-app-list-timeline
- Baseline commit: d538611

## Goal

Fix the site/icon/app-list/TimeRiver polish issues reported from the latest alpha UI screenshots.

## Service side

No service writer or disk schema changes. The service already emits Chrome foreground sessions and audio media sessions into SQLite; this session only changes UI-side read aggregation and local static icon resources.

## UI side

The UI will resolve known site identities from both foreground window titles and audio media titles, consume high-resolution qrc site icons, show a cleaner high-frequency settings app list, reduce dense TimeRiver label clutter, and use a white Memory Lake navigation icon.

## Expected files

- `src/services/usage_stat_manager.cpp`, `src/services/site_catalog.h`, `tests/db_smoke.cpp`
- `qml/desktop/components/AppVisual.js`, `qml/desktop/pages/DesktopProfilePage.qml`, `qml/desktop/memorylake/TimeRiver.qml`, `qml/desktop/DesktopAppShell.qml`
- `resources/CMakeLists.txt`, `resources/icons/sites/*`, `resources/icons/recap_white.svg`
- `docs/site-icon-assets.md`, `docs/mainland-site-tracking.md`, `docs/implementation-backlog.md`, `docs/site-icons-app-list-timeline-report.md`

## What actually happened

- 05:46 - Preflight passed on Track B and created branch `codex/site-icons-app-list-timeline`.
- 05:47 - SQLite evidence showed `frontmost_sessions` had `douyin.com/...` and `小红书 - ... - Google Chrome`; `media_sessions` had a Douyin media title. The UI aggregation must preserve these as `site:*`.
- 05:47 - Two inspection command mistakes were recorded in the error journal.

## Outcome

One of: **partial** until all planned commits land.
